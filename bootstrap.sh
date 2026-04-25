#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

OWNER="${JW_OWNER:-jwsky}"
REPO="${JW_REPO:-jwscript}"
REF="${JW_REF:-main}"
API_URL="${GITHUB_API_URL:-https://api.github.com}"

die() {
  printf '\n[bootstrap] ERROR: %s\n' "$*" >&2
  exit 1
}

need_root() {
  if [ "${EUID}" -ne 0 ]; then
    die "Run with sudo."
  fi
}

read_token() {
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    TOKEN="$GITHUB_TOKEN"
    return
  fi

  if [ ! -r /dev/tty ]; then
    die "No TTY available for reading the token."
  fi

  printf 'Token: ' > /dev/tty
  IFS= read -r -s TOKEN < /dev/tty
  printf '\n' > /dev/tty

  if [ -z "$TOKEN" ]; then
    die "Empty token."
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
