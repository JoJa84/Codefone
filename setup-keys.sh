#!/usr/bin/env bash
# setup-keys.sh — first-boot helper for provisioning a fresh Codefone VM.
#
# Runs INSIDE the Debian VM. Bootstraps SSH access from the operator's PC so
# the main `codefone-setup.sh` can take over. Idempotent: safe to re-run.
#
# Usage (on-device, inside the Terminal app):
#   bash setup-keys.sh  <operator_pubkey>
# or, piping the key:
#   echo "ssh-ed25519 AAAA..." | bash setup-keys.sh
#
# Historically `codefone-setup.sh` tried to curl this from GitHub raw during
# first-boot. That's fragile — the file now lives in-repo so the full bootstrap
# is self-contained (see Codex review 2026-04-19).
set -euo pipefail

PUBKEY="${1:-}"
if [ -z "$PUBKEY" ] && [ ! -t 0 ]; then
  PUBKEY=$(cat)
fi
if [ -z "$PUBKEY" ]; then
  echo "usage: bash setup-keys.sh <operator_pubkey>" >&2
  echo "       or pipe the key via stdin" >&2
  exit 1
fi

echo "[setup-keys] Ensuring openssh-server + Port 2222"
sudo apt update -qq >/dev/null
sudo apt install -y -qq openssh-server >/dev/null
grep -q '^Port 2222' /etc/ssh/sshd_config || \
  echo 'Port 2222' | sudo tee -a /etc/ssh/sshd_config >/dev/null
grep -q '^PasswordAuthentication no' /etc/ssh/sshd_config || \
  echo 'PasswordAuthentication no' | sudo tee -a /etc/ssh/sshd_config >/dev/null
sudo systemctl restart ssh 2>/dev/null || sudo systemctl restart sshd 2>/dev/null || true

echo "[setup-keys] Installing operator's public key"
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
if ! grep -qF "$PUBKEY" ~/.ssh/authorized_keys 2>/dev/null; then
  echo "$PUBKEY" >> ~/.ssh/authorized_keys
fi

echo "[setup-keys] Done. PC can now ssh -p 2222 droid@<vm-ip>"
