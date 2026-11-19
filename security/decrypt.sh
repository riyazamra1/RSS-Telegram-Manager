#!/usr/bin/env bash
set -euo pipefail
umask 077

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rss-telegram-manager"
IDENTITY="${AGE_IDENTITY_FILE:-$CONFIG_DIR/identity.txt}"
INPUT="${1:-}"
OUTPUT="${2:-}"

if [[ -z "$INPUT" || -z "$OUTPUT" || ! -f "$INPUT" ]]; then
  printf 'Usage: %s encrypted-file.age /secure/new/output-file\n' "$0" >&2
  exit 2
fi
command -v age >/dev/null 2>&1 || { printf '%s\n' "ERROR: age is not installed." >&2; exit 1; }
[[ -f "$IDENTITY" ]] || { printf 'ERROR: Private identity not found: %s\n' "$IDENTITY" >&2; exit 1; }
[[ ! -e "$OUTPUT" ]] || { printf 'ERROR: Destination exists; refusing to overwrite: %s\n' "$OUTPUT" >&2; exit 1; }

OUTPUT_DIR="$(dirname -- "$OUTPUT")"
mkdir -p -- "$OUTPUT_DIR"
OUTPUT_DIR="$(cd -- "$OUTPUT_DIR" && pwd -P)"
OUTPUT="$OUTPUT_DIR/$(basename -- "$OUTPUT")"
age -d -i "$IDENTITY" -o "$OUTPUT" "$INPUT"
chmod 600 "$OUTPUT"
printf 'Decryption completed: %s\n' "$OUTPUT"
printf '%s\n' "Keep this plaintext file on trusted encrypted storage only."
