#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

CONFIG_OWNER="${JW_CONFIG_OWNER:-jwsky}"
CONFIG_REPO="${JW_CONFIG_REPO:-jwscript}"
CONFIG_REF="${JW_CONFIG_REF:-main}"
PROFILE="${1:-default}"
DISABLE_PASSWORD_LOGIN="${JW_DISABLE_PASSWORD_LOGIN:-1}"
PRINT_PASSWORD="${JW_PRINT_PASSWORD:-0}"
API_URL="${GITHUB_API_URL:-https://api.github.com}"

log() {
  printf '\n[ss-bootstrap] %s\n' "$*" >&2
}

die() {
  printf '\n[ss-bootstrap] ERROR: %s\n' "$*" >&2
  exit 1
}

need_root() {
  if [ "${EUID}" -ne 0 ]; then
    die "Run with sudo, for example: curl -fsSL ... | sudo bash -s -- default"
  fi
}

validate_profile() {
  case "$PROFILE" in
    ""|*/*|*..*)
      die "Invalid profile name: $PROFILE"
      ;;
  esac

  if ! printf '%s' "$PROFILE" | grep -Eq '^[A-Za-z0-9._-]+$'; then
    die "Invalid profile name: $PROFILE"
  fi
}

load_os_release() {
  if [ ! -r /etc/os-release ]; then
    die "Cannot read /etc/os-release"
  fi

  # shellcheck disable=SC1091
  . /etc/os-release

  if [ "${ID:-}" != "ubuntu" ]; then
    die "This installer is intended for Ubuntu. Detected: ${PRETTY_NAME:-unknown}"
  fi

  case "${VERSION_ID:-}" in
    24.*|26.*)
      log "Detected ${PRETTY_NAME:-Ubuntu}"
      ;;
    *)
      log "Detected ${PRETTY_NAME:-Ubuntu}; continuing, but Ubuntu 24/26 is the tested target."
      ;;
  esac
}

install_packages() {
  export DEBIAN_FRONTEND=noninteractive

  log "Installing required system packages."
  apt-get update
  apt-get install -y ca-certificates curl iproute2 openssh-server

  if ! apt-cache show shadowsocks-libev >/dev/null 2>&1; then
    log "shadowsocks-libev is not visible in apt; enabling Ubuntu universe."
    apt-get install -y software-properties-common
    add-apt-repository -y universe
    apt-get update
  fi

  apt-get install -y shadowsocks-libev
}

read_token() {
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    GH_TOKEN="$GITHUB_TOKEN"
    return
  fi

  if [ ! -r /dev/tty ]; then
    die "No TTY available for reading the GitHub token."
  fi

  printf 'GitHub token for %s/%s (Contents: Read-only): ' "$CONFIG_OWNER" "$CONFIG_REPO" > /dev/tty
  IFS= read -r -s GH_TOKEN < /dev/tty
  printf '\n' > /dev/tty

  if [ -z "$GH_TOKEN" ]; then
    die "GitHub token is empty."
  fi
}

github_raw() {
  local path="$1"
  local url="${API_URL}/repos/${CONFIG_OWNER}/${CONFIG_REPO}/contents/${path}?ref=${CONFIG_REF}"

  curl -fsSL --retry 3 --connect-timeout 10 --config - "$url" <<EOF
header = "Authorization: Bearer ${GH_TOKEN}"
header = "Accept: application/vnd.github.raw+json"
header = "X-GitHub-Api-Version: 2022-11-28"
EOF
}

fetch_required() {
  local path="$1"
  local dest="$2"

  if ! github_raw "$path" > "$dest"; then
    die "Failed to fetch required config: $path"
  fi
}

fetch_optional() {
  local path="$1"
  local dest="$2"
  local fallback="$3"

  if ! github_raw "$path" > "$dest" 2>/dev/null; then
    printf '%s\n' "$fallback" > "$dest"
  fi
}

first_value() {
  sed -e 's/\r$//' -e '/^[[:space:]]*$/d' "$1" | head -n 1
}

validate_port() {
  local name="$1"
  local value="$2"

  if ! printf '%s' "$value" | grep -Eq '^[0-9]+$'; then
    die "$name must be a number: $value"
  fi

  if [ "$value" -lt 1 ] || [ "$value" -gt 65535 ]; then
    die "$name must be between 1 and 65535: $value"
  fi
}

validate_profile_values() {
  validate_port ss_port "$SS_PORT"
  validate_port ss_local_port "$SS_LOCAL_PORT"

  if ! printf '%s' "$SS_TIMEOUT" | grep -Eq '^[0-9]+$'; then
    die "ss_timeout must be a number: $SS_TIMEOUT"
  fi

  if [ -z "$SS_PASSWORD" ]; then
    die "ss_password is empty."
  fi

  if ! printf '%s' "$SS_METHOD" | grep -Eq '^[A-Za-z0-9._-]+$'; then
    die "ss_method contains unsupported characters: $SS_METHOD"
  fi

  case "$SS_FAST_OPEN" in
    true|false)
      ;;
    1)
      SS_FAST_OPEN=true
      ;;
    0)
      SS_FAST_OPEN=false
      ;;
    *)
      die "ss_fast_open must be true or false."
      ;;
  esac
}

load_profile() {
  local tmp="$1"
  local base="profiles/${PROFILE}"

  log "Loading private config profile: ${CONFIG_OWNER}/${CONFIG_REPO}:${CONFIG_REF}/${base}"
  fetch_required "${base}/authorized_keys" "${tmp}/authorized_keys"
  fetch_required "${base}/ss_port" "${tmp}/ss_port"
  fetch_required "${base}/ss_password" "${tmp}/ss_password"
  fetch_optional "${base}/ss_method" "${tmp}/ss_method" "chacha20-ietf"
  fetch_optional "${base}/ss_timeout" "${tmp}/ss_timeout" "86400"
  fetch_optional "${base}/ss_local_port" "${tmp}/ss_local_port" "1080"
  fetch_optional "${base}/ss_fast_open" "${tmp}/ss_fast_open" "true"
  fetch_optional "${base}/bind_ip" "${tmp}/bind_ip" "auto"

  SS_PORT="$(first_value "${tmp}/ss_port")"
  SS_PASSWORD="$(first_value "${tmp}/ss_password")"
  SS_METHOD="$(first_value "${tmp}/ss_method")"
  SS_TIMEOUT="$(first_value "${tmp}/ss_timeout")"
  SS_LOCAL_PORT="$(first_value "${tmp}/ss_local_port")"
  SS_FAST_OPEN="$(first_value "${tmp}/ss_fast_open")"
  CONFIG_BIND_IP="$(first_value "${tmp}/bind_ip")"

  unset GH_TOKEN
  validate_profile_values
}

target_user_home() {
  TARGET_USER="${JW_TARGET_USER:-${SUDO_USER:-root}}"
  if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
    TARGET_USER=root
    TARGET_HOME=/root
    TARGET_GROUP=root
    return
  fi

  TARGET_HOME="$(getent passwd "$TARGET_USER" | awk -F: '{print $6}')"
  TARGET_GROUP="$(id -gn "$TARGET_USER")"

  if [ -z "$TARGET_HOME" ] || [ ! -d "$TARGET_HOME" ]; then
    die "Cannot find home directory for target user: $TARGET_USER"
  fi
}

install_authorized_keys() {
  local keys_file="$1"
  local ssh_dir="${TARGET_HOME}/.ssh"
  local auth_file="${ssh_dir}/authorized_keys"
  local clean_keys

  clean_keys="$(mktemp)"
  sed -e 's/\r$//' -e '/^[[:space:]]*$/d' "$keys_file" > "$clean_keys"

  if [ ! -s "$clean_keys" ]; then
    die "authorized_keys is empty."
  fi

  install -d -m 700 -o "$TARGET_USER" -g "$TARGET_GROUP" "$ssh_dir"
  touch "$auth_file"
  chown "$TARGET_USER:$TARGET_GROUP" "$auth_file"
  chmod 600 "$auth_file"

  while IFS= read -r key_line; do
    key_type="${key_line%% *}"
    case "$key_type" in
      ssh-rsa|ssh-ed25519|ecdsa-sha2-*|sk-ssh-ed25519@openssh.com|sk-ecdsa-sha2-nistp256@openssh.com)
        ;;
      *)
        rm -f "$clean_keys"
        die "Unsupported authorized_keys line: $key_type"
        ;;
    esac

    if ! grep -qxF "$key_line" "$auth_file"; then
      printf '%s\n' "$key_line" >> "$auth_file"
    fi
  done < "$clean_keys"

  rm -f "$clean_keys"
  chown "$TARGET_USER:$TARGET_GROUP" "$auth_file"
  chmod 600 "$auth_file"

  log "Installed SSH public key for user: $TARGET_USER"
}

sshd_bin() {
  command -v sshd 2>/dev/null || printf '/usr/sbin/sshd\n'
}

prepend_sshd_include_if_needed() {
  local conf="/etc/ssh/sshd_config"
  local first_active
  local tmp

  first_active="$(awk 'NF && $1 !~ /^#/ {print; exit}' "$conf" 2>/dev/null || true)"
  case "$first_active" in
    Include\ /etc/ssh/sshd_config.d/\*.conf*)
      return
      ;;
  esac

  log "Ensuring sshd_config reads drop-in files before later global settings."
  cp -a "$conf" "${conf}.bak.jwbootstrap.$(date +%Y%m%d%H%M%S)"
  tmp="$(mktemp)"
  {
    printf 'Include /etc/ssh/sshd_config.d/*.conf\n'
    cat "$conf"
  } > "$tmp"
  cat "$tmp" > "$conf"
  rm -f "$tmp"
}

comment_global_sshd_conflicts() {
  local conf="/etc/ssh/sshd_config"
  local tmp

  log "Commenting earlier global SSH settings that prevent hardening from taking effect."
  cp -a "$conf" "${conf}.bak.jwbootstrap.$(date +%Y%m%d%H%M%S)"
  tmp="$(mktemp)"
  awk '
    BEGIN { IGNORECASE = 1; in_match = 0 }
    /^[[:space:]]*Match[[:space:]]/ { in_match = 1 }
    !in_match && /^[[:space:]]*(PasswordAuthentication|KbdInteractiveAuthentication|ChallengeResponseAuthentication|PubkeyAuthentication|PermitRootLogin)[[:space:]]+/ {
      print "# jw-bootstrap disabled duplicate: " $0
      next
    }
    { print }
  ' "$conf" > "$tmp"
  cat "$tmp" > "$conf"
  rm -f "$tmp"
}

write_sshd_hardening() {
  install -d -m 755 /etc/ssh/sshd_config.d
  prepend_sshd_include_if_needed

  cat > /etc/ssh/sshd_config.d/00-jw-hardening.conf <<'EOF'
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
EOF

  chmod 644 /etc/ssh/sshd_config.d/00-jw-hardening.conf
}

effective_sshd_value() {
  local key="$1"
  local bin
  bin="$(sshd_bin)"
  mkdir -p /run/sshd
  "$bin" -T 2>/dev/null | awk -v key="$key" '$1 == key {print $2; exit}'
}

sshd_hardening_is_effective() {
  [ "$(effective_sshd_value pubkeyauthentication)" = "yes" ] &&
    [ "$(effective_sshd_value passwordauthentication)" = "no" ] &&
    [ "$(effective_sshd_value kbdinteractiveauthentication)" = "no" ]
}

harden_sshd() {
  local bin

  if [ "$DISABLE_PASSWORD_LOGIN" != "1" ]; then
    log "Skipping password-login hardening because JW_DISABLE_PASSWORD_LOGIN is not 1."
    return
  fi

  write_sshd_hardening
  bin="$(sshd_bin)"
  mkdir -p /run/sshd
  "$bin" -t

  if ! sshd_hardening_is_effective; then
    comment_global_sshd_conflicts
    prepend_sshd_include_if_needed
    "$bin" -t
  fi

  if ! sshd_hardening_is_effective; then
    die "SSH hardening did not become effective. Refusing to reload sshd."
  fi

  if command -v systemctl >/dev/null 2>&1; then
    systemctl reload ssh 2>/dev/null || systemctl restart ssh
  else
    service ssh reload 2>/dev/null || service ssh restart
  fi

  log "SSH password login disabled; public key login enabled."
}

is_local_ipv4() {
  local candidate="$1"
  [ -n "$candidate" ] || return 1
  ip -o -4 addr show | awk '{sub(/\/.*/, "", $4); print $4}' | grep -Fxq "$candidate"
}

default_route_ip() {
  ip -4 route get 1.1.1.1 2>/dev/null |
    awk '{for (i=1; i<=NF; i++) if ($i == "src") {print $(i+1); exit}}'
}

public_ipv4() {
  curl -4 -fsSL --connect-timeout 5 https://api.ipify.org 2>/dev/null ||
    curl -4 -fsSL --connect-timeout 5 https://ifconfig.me/ip 2>/dev/null ||
    true
}

select_bind_ip() {
  PUBLIC_IP="$(public_ipv4)"
  ROUTE_IP="$(default_route_ip)"

  if [ -n "$CONFIG_BIND_IP" ] && [ "$CONFIG_BIND_IP" != "auto" ]; then
    if ! is_local_ipv4 "$CONFIG_BIND_IP"; then
      die "Configured bind_ip is not present on this server: $CONFIG_BIND_IP"
    fi
    BIND_IP="$CONFIG_BIND_IP"
  elif [ -n "$PUBLIC_IP" ] && is_local_ipv4 "$PUBLIC_IP"; then
    BIND_IP="$PUBLIC_IP"
  elif [ -n "$ROUTE_IP" ]; then
    BIND_IP="$ROUTE_IP"
  else
    BIND_IP="0.0.0.0"
  fi

  CLIENT_SERVER="$PUBLIC_IP"
  if [ -z "$CLIENT_SERVER" ]; then
    CLIENT_SERVER="$BIND_IP"
  fi

  log "Shadowsocks bind IP: ${BIND_IP}; client server IP: ${CLIENT_SERVER}"
}

json_escape() {
  sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

write_shadowsocks_config() {
  local password_json
  local method_json
  local tmp_config

  select_bind_ip
  password_json="$(printf '%s' "$SS_PASSWORD" | json_escape)"
  method_json="$(printf '%s' "$SS_METHOD" | json_escape)"
  tmp_config="$(mktemp)"

  cat > "$tmp_config" <<EOF
{
    "server":"${BIND_IP}",
    "mode":"tcp_and_udp",
    "server_port":${SS_PORT},
    "local_port":${SS_LOCAL_PORT},
    "password":"${password_json}",
    "timeout":${SS_TIMEOUT},
    "method":"${method_json}",
    "fast_open": ${SS_FAST_OPEN}
}
EOF

  install -d -m 755 /etc/shadowsocks-libev
  install -o root -g root -m 600 "$tmp_config" /etc/shadowsocks-libev/config.json
  rm -f "$tmp_config"

  if [ "$SS_FAST_OPEN" = "true" ]; then
    printf 'net.ipv4.tcp_fastopen = 3\n' > /etc/sysctl.d/99-shadowsocks-tcp-fastopen.conf
    sysctl -p /etc/sysctl.d/99-shadowsocks-tcp-fastopen.conf >/dev/null 2>&1 || true
  fi

  log "Wrote /etc/shadowsocks-libev/config.json with root-only permissions."
}

restart_shadowsocks() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable shadowsocks-libev >/dev/null 2>&1 || true
    systemctl restart shadowsocks-libev
    systemctl --no-pager --full status shadowsocks-libev
  else
    service shadowsocks-libev restart
    service shadowsocks-libev status
  fi
}

print_summary() {
  cat <<EOF

Done.

Client connection:
  server: ${CLIENT_SERVER}
  port: ${SS_PORT}
  method: ${SS_METHOD}
  password: $(if [ "$PRINT_PASSWORD" = "1" ]; then printf '%s' "$SS_PASSWORD"; else printf '<stored in private profile and /etc/shadowsocks-libev/config.json>'; fi)

SSH:
  user: ${TARGET_USER}
  password login: disabled
  key file on your computer: ~/.ssh/luo_common_rsa

EOF
}

main() {
  need_root
  validate_profile
  load_os_release
  install_packages

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  read_token
  load_profile "$tmp_dir"
  target_user_home
  install_authorized_keys "${tmp_dir}/authorized_keys"
  harden_sshd
  write_shadowsocks_config
  restart_shadowsocks
  print_summary
}

main "$@"
