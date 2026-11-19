#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT="$(cd -- "$(dirname -- -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rss-telegram-manager"
IDENTITY="$CONFIG_DIR/identity.txt"
RECIPIENTS="$ROOT/security/RECIPIENTS"

command -v age-keygen >/dev/null 2>&1 || {
  printf '%s\n' "ERROR: age-keygen is not installed. Install the official age package first." >&2
  exit 1
}

if [[ -e "$IDENTITY" || -e "$RECIPIENTS" ]]; then
  printf '%s\n' "ERROR: Identity or recipient file already exists. Back it up and handle rotation manually." >&2
  exit 1
fi

mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"
age-keygen -o "$IDENTITY"
chmod 600 "$IDENTITY"

recipient="$(sed -n 's/^# public key: //p' "$IDENTITY" | head -n 1)"
if [[ ! "$recipient" =~ ^age1[0-9a-z]+$ ]]; then
  rm -f -- "$IDENTITY"
  printf '%s\n' "ERROR: Could not validate the generated public recipient." >&2
  exit 1
fi

printf '%s\n' "$recipient" > "$RECIPIENTS"
chmod 644 "$RECIPIENTS"
printf 'Private identity: %s\n' "$IDENTITY"
printf 'Public recipient: %s\n' "$RECIPIENTS"
printf '%s\n' "Back up the private identity offline. Commit only security/RECIPIENTS."
