#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RECIPIENTS="$ROOT/security/RECIPIENTS"
SOURCE="${1:-}"
OUTPUT="${2:-$ROOT/protected-source/source.tar.gz.age}"

if [[ -z "$SOURCE" || ! -d "$SOURCE" ]]; then
  printf 'Usage: %s /absolute/path/to/private-source [output.age]\n' "$0" >&2
  exit 2
fi
command -v age >/dev/null 2>&1 || { printf '%s\n' "ERROR: age is not installed." >&2; exit 1; }
command -v tar >/dev/null 2>&1 || { printf '%s\n' "ERROR: tar is not installed." >&2; exit 1; }
[[ -s "$RECIPIENTS" ]] || { printf '%s\n' "ERROR: security/RECIPIENTS is missing or empty." >&2; exit 1; }

SOURCE="$(cd -- "$SOURCE" && pwd -P)"
OUTPUT_DIR="$(dirname -- "$OUTPUT")"
mkdir -p -- "$OUTPUT_DIR"
OUTPUT_DIR="$(cd -- "$OUTPUT_DIR" && pwd -P)"
OUTPUT="$OUTPUT_DIR/$(basename -- "$OUTPUT")"

if [[ "$SOURCE" == "$ROOT" || "$SOURCE" == "$ROOT/"* || "$OUTPUT" == "$SOURCE/"* ]]; then
  printf '%s\n' "ERROR: Source must be outside this repository and output must not be inside the source directory." >&2
  exit 1
fi
if [[ -e "$OUTPUT" ]]; then
  printf 'ERROR: Output already exists; refusing to overwrite: %s\n' "$OUTPUT" >&2
  exit 1
fi

SOURCE_PARENT="$(dirname -- "$SOURCE")"
SOURCE_NAME="$(basename -- "$SOURCE")"
tar --exclude=.git --exclude=node_modules --exclude=.venv --exclude=venv \
    --exclude=.env --exclude=.env.* --exclude='*.pem' --exclude='*.key' \
    --exclude='*.agekey' --exclude='*.identity' \
    -C "$SOURCE_PARENT" -czf - "$SOURCE_NAME" | age -R "$RECIPIENTS" -o "$OUTPUT"

chmod 600 "$OUTPUT"
printf 'Encrypted archive created: %s\n' "$OUTPUT"
printf '%s\n' "Review and commit only the .age file. Do not add the plaintext source directory."
