# RSS Telegram Manager — source encryption

This repository is public. Application source must be encrypted before it is added to Git.
The encryption format is **age** (authenticated public-key encryption). Only the public
recipient is stored in this repository. The matching private identity must remain outside
the repository and be held in a protected GitHub Actions environment secret for CI.

## Security boundaries

- Do not commit plaintext application source, decrypted archives, private identities,
  bot tokens, API credentials, or production data.
- Encryption protects source at rest in Git; it does not make a running application,
  compiled binary, API, or deployed behavior impossible to inspect or reverse engineer.
- Anyone with access to the private identity can decrypt the source. Keep a secure offline
  backup of that identity. Losing it means the encrypted source cannot be recovered.
- Never expose the identity to pull-request workflows, forks, untrusted branches, logs,
  artifacts, caches, or third-party actions.
- The secure workflow is manual-only, restricted to the main branch, and uses the
  `rss-telegram-secure-build` GitHub Environment. Configure that environment with required
  reviewers and add the secret there **only after** protection is configured.
- The workflow currently verifies decryption and archive readability only. It does not
  build or deploy the application. No source archive or private key is present yet.

## Prerequisites

Install the official `age` command-line utility on your trusted development computer.
Use a current, verified release from the official age project. Do not download binaries
from unofficial mirrors.

## 1. Generate a key pair

**Android / Termux:** the packaged `age-keygen` command can fail on some Termux builds.
Use the repository's Termux helper instead. It generates a native age X25519 identity
through the official Go age library, creates a passphrase-encrypted recovery copy, and
runs an actual encryption/decryption verification:

```sh
pkg install golang age openssl-tool -y
mkdir -p "$HOME/rss-secure"
curl -fsSLo "$HOME/rss-secure/setup-keys-termux.sh" \
  https://raw.githubusercontent.com/riyazamra1/RSS-Telegram-Manager/main/security/setup-keys-termux.sh
bash "$HOME/rss-secure/setup-keys-termux.sh"
```

The helper stores the private identity, encrypted recovery copy, passphrase file, and
public recipient under `~/rss-secure/`. It does not overwrite the earlier SSH test files.
Keep the private identity secret. Back up the encrypted recovery copy and passphrase
separately before relying on them.

**Linux / macOS / Windows with a trusted shell:** from the repository root, run:

```sh
./security/setup-keys.sh
```

The script creates the private identity under
`~/.config/rss-telegram-manager/identity.txt` with restrictive permissions and writes
the public recipient to `security/RECIPIENTS`. The identity is never written into this
repository. Keep a secure offline backup of the identity.

Commit only `security/RECIPIENTS` (the public recipient). Verify that the private identity
is outside the repository before proceeding.

## 2. Encrypt proprietary source

Run:

```sh
./security/encrypt.sh /absolute/path/to/private-source
```

This creates `protected-source/source.tar.gz.age`. Inspect the source directory first and
remove secrets, credentials, customer data, local configuration, and generated files.
The encryption script excludes common local secret and build directories, but this is not
a substitute for reviewing the source tree.

Commit only the resulting `.age` ciphertext. Never commit the original directory or
unencrypted archive.

## 3. Configure protected CI

In GitHub repository Settings → Environments, create or configure
`rss-telegram-secure-build` **before adding any secret**:

1. Require at least one trusted reviewer for deployments to this environment.
2. Restrict deployment branches to `main`.
3. Do not permit untrusted collaborators to approve their own deployments.
4. Add an environment secret named `RSS_TELEGRAM_AGE_IDENTITY` containing the complete
   private identity file contents. Do not paste it into an issue, chat, commit, or log.

The workflow is manual-only and checks that it is running from `main`. It must not be
changed to decrypt on `pull_request`, `pull_request_target`, or untrusted branch events.
Review workflow changes before approving an environment deployment.

## 4. Local decryption

On a trusted machine only:

```sh
./security/decrypt.sh protected-source/source.tar.gz.age /secure/path/source.tar.gz
```

The destination must not already exist. Keep decrypted source on encrypted storage and
remove temporary plaintext copies when finished.

## Key rotation and recovery

Keep at least one offline, access-controlled backup of the private identity. To rotate,
generate a new identity, add its public recipient to `security/RECIPIENTS`, re-encrypt
the source for the new recipient, verify decryption with the new identity, then remove
the old recipient and retire the old identity only after backup/recovery checks pass.
Never delete the only working identity before verifying the replacement.

## Incident response

If plaintext source or a private key is ever committed, assume it is exposed. Revoke/rotate
affected credentials, remove the material from all Git refs and history, and assess forks,
clones, caches, artifacts, and logs. Deleting the latest file alone does not erase Git
history.

## Current implementation status

This repository foundation provides key generation, encryption/decryption scripts, ignore
rules, and a manual protected-CI decryption verification workflow. It does not yet include
the Telegram application source, a ciphertext archive, CI secrets, environment reviewers,
or a production build/deployment pipeline.
