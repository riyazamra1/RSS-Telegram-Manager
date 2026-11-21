#!/usr/bin/env bash
# Termux-only age X25519 identity setup.
# Generates keys through the official filippo.io/age Go library, bypassing
# the broken age-keygen executable observed on some Termux builds.
set -euo pipefail
umask 077

command -v go >/dev/null 2>&1 || { echo "Go is required (pkg install golang)." >&2; exit 1; }
command -v age >/dev/null 2>&1 || { echo "age is required (pkg install age)." >&2; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "OpenSSL is required (pkg install openssl-tool)." >&2; exit 1; }

DIR="$HOME/rss-secure"
IDENTITY="$DIR/rss-telegram-manager-age-identity.txt"
RECIPIENTS="$DIR/RECIPIENTS"
BACKUP="$DIR/rss-telegram-manager-age-identity.txt.enc"
PASS="$DIR/key-passphrase.txt"

mkdir -p "$DIR"
chmod 700 "$DIR"

for f in "$IDENTITY" "$RECIPIENTS" "$BACKUP"; do
  if [ -e "$f" ]; then
    echo "STOP: $f already exists. Nothing was overwritten." >&2
    exit 1
  fi
done
if [ ! -s "$PASS" ]; then
  echo "STOP: The local passphrase file is missing or empty." >&2
  exit 1
fi
chmod 600 "$PASS"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/go.mod" <<'EOF'
module rss-telegram-manager-key-setup

go 1.24.0

require filippo.io/age v1.3.2
EOF

cat > "$TMP/main.go" <<'EOF'
package main

import (
	"fmt"
	"os"

	"filippo.io/age"
)

func main() {
	identityPath := os.Getenv("IDENTITY_PATH")
	recipientsPath := os.Getenv("RECIPIENTS_PATH")
	if identityPath == "" || recipientsPath == "" {
		fmt.Fprintln(os.Stderr, "keygen configuration is missing")
		os.Exit(2)
	}
	identity, err := age.GenerateX25519Identity()
	if err != nil {
		fmt.Fprintln(os.Stderr, "key generation failed:", err)
		os.Exit(1)
	}
	if err := os.WriteFile(identityPath, []byte(identity.String()+"\n"), 0600); err != nil {
		fmt.Fprintln(os.Stderr, "cannot write private identity:", err)
		os.Exit(1)
	}
	if err := os.WriteFile(recipientsPath, []byte(identity.Recipient().String()+"\n"), 0644); err != nil {
		_ = os.Remove(identityPath)
		fmt.Fprintln(os.Stderr, "cannot write public recipient:", err)
		os.Exit(1)
	}
}
EOF

(
  cd "$TMP"
  echo "RSS-TM-KEY-SETUP v3: executing repository Go source"
  IDENTITY_PATH="$IDENTITY" RECIPIENTS_PATH="$RECIPIENTS" GOTOOLCHAIN=local go run -mod=mod "$TMP/main.go"
)

chmod 600 "$IDENTITY"
chmod 644 "$RECIPIENTS"

# Create a passphrase-encrypted recovery copy of the private identity.
openssl enc -aes-256-cbc -salt -pbkdf2 -iter 600000 \
  -in "$IDENTITY" -out "$BACKUP" -pass "file:$PASS"
chmod 600 "$BACKUP"

# Verify the encrypted backup can be recovered with the locally stored passphrase.
openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 \
  -in "$BACKUP" -out "$TMP/identity-recovered.txt" -pass "file:$PASS"
cmp -s "$IDENTITY" "$TMP/identity-recovered.txt"

# Verify actual age encryption and decryption with the generated identity.
printf '%s\n' "RSS Telegram Manager encryption verification" > "$TMP/test.txt"
age -R "$RECIPIENTS" -o "$TMP/test.txt.age" "$TMP/test.txt"
age -d -i "$IDENTITY" -o "$TMP/test-recovered.txt" "$TMP/test.txt.age"
cmp -s "$TMP/test.txt" "$TMP/test-recovered.txt"

echo "AGE IDENTITY GENERATED AND VERIFIED"
echo "Private identity: stored locally with mode 600"
echo "Encrypted recovery copy: created and verified"
echo "Passphrase file: retained locally with mode 600"
echo "Age encrypt/decrypt test: PASSED"
echo
echo "PUBLIC RECIPIENT (safe to publish):"
cat "$RECIPIENTS"
echo
echo "Do not share the private identity, encrypted backup, or passphrase."
echo "Back up the encrypted identity and passphrase separately before relying on them."
