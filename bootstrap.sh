#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

OWNER="${JW_OWNER:-jwsky}"
REPO="${JW_REPO:-jwscript}"
REF="${JW_REF:-main}"
API_URL="${GITHUB_API_URL:-https://api.github.com}"
JWAUTH_URL="${JWAUTH_URL:-https://s.theucd.com/jwauth/}"

die() {
  printf '\n[bootstrap] ERROR: %s\n' "$*" >&2
  exit 1
}

need_root() {
  if [ "${EUID}" -ne 0 ]; then
    die "Run with sudo."
  fi
}

# Read either a 6-digit TOTP code or a raw GitHub token from /dev/tty.
# Auto-detects which is which: if the input is exactly 6 digits we exchange
# it via the jwauth bridge; anything else is treated as a raw token (so the
# manual PAT path still works if the bridge is down).
read_token() {
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    TOKEN="$GITHUB_TOKEN"
    return
  fi

  if [ ! -r /dev/tty ]; then
    die "No TTY available. Set GITHUB_TOKEN env var instead."
  fi

  local input
  printf 'Auth (6-digit TOTP, or paste a GitHub token): ' > /dev/tty
  IFS= read -r -s input < /dev/tty
  printf '\n' > /dev/tty

  if [ -z "$input" ]; then
    die "Empty input."
  fi

  if printf '%s' "$input" | grep -Eq '^[0-9]{6}$'; then
    printf '[bootstrap] Exchanging TOTP via %s ...\n' "$JWAUTH_URL" >&2
    local resp http
    # Use --write-out to capture HTTP status; -f is omitted so we can read
    # the JSON body even on 4xx (the bridge returns useful error messages).
    resp="$(curl -sS --connect-timeout 10 --max-time 30 \
            --write-out '\n[HTTP %{http_code}]' \
            -X POST "$JWAUTH_URL" \
            --data-urlencode "code=$input" 2>&1)" \
        || die "Auth bridge unreachable: $resp\n      Re-run and paste a manual GitHub PAT instead of the 6-digit code."
    http="$(printf '%s' "$resp" | sed -n 's/.*\[HTTP \([0-9]*\)\]$/\1/p' | tail -1)"
    if [ "$http" != "200" ]; then
      die "Auth bridge returned HTTP $http: $(printf '%s' "$resp" | sed -e 's/\[HTTP [0-9]*\]$//')"
    fi
    TOKEN="$(printf '%s' "$resp" | sed -n 's/.*"token":[[:space:]]*"\([^"]*\)".*/\1/p')"
    if [ -z "$TOKEN" ]; then
      die "Auth bridge returned no token. Response: $resp"
    fi
    printf '[bootstrap] Got token from bridge.\n' >&2
  else
    # Treat input as a raw GitHub token (PAT or installation token).
    TOKEN="$input"
  fi
}

pick_workdir() {
  if [ -d /dev/shm ] && [ -w /dev/shm ]; then
    WORK="$(mktemp -d -p /dev/shm jw.XXXXXX)"
  else
    WORK="$(mktemp -d -t jw.XXXXXX)"
  fi
}

fetch_and_extract() {
  local url="${API_URL}/repos/${OWNER}/${REPO}/tarball/${REF}"

  curl -fsSL --retry 3 --connect-timeout 10 --config - "$url" <<EOF | tar -xz --strip-components=1 -C "$WORK"
header = "Authorization: Bearer ${TOKEN}"
header = "Accept: application/vnd.github+json"
header = "X-GitHub-Api-Version: 2022-11-28"
EOF
}

main() {
  need_root
  read_token
  pick_workdir
  trap 'rm -rf "$WORK"' EXIT INT TERM

  fetch_and_extract
  unset TOKEN

  local entry="${WORK}/menu.sh"
  if [ ! -f "$entry" ]; then
    die "menu.sh not found in downloaded payload."
  fi

  exec env JW_WORK="$WORK" bash "$entry" "$@"
}

main "$@"
