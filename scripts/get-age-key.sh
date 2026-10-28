#!/usr/bin/env bash
# get-age-key — print this machine's sops age public key.
#
# Derives the age public key from the SSH host key (same mechanism sops-nix uses).
# The output goes in .sops.yaml under keys: with a descriptive anchor.
#
# Usage:
#   nix run .#get-age-key               # prints the age public key
#   nix run .#get-age-key | pbcopy       # copy to clipboard
#
# The SSH host private key is only readable by root, so sudo is required
# for the private key path. The PUBLIC key (what we actually need for .sops.yaml)
# is world-readable, so no sudo needed for the common case.
set -euo pipefail

SSH_HOST_KEY_PUB="/etc/ssh/ssh_host_ed25519_key.pub"

# Try the standard NixOS path first, then the tmpfs-root persistent path
if [ ! -f "$SSH_HOST_KEY_PUB" ]; then
  SSH_HOST_KEY_PUB="/persistent/etc/ssh/ssh_host_ed25519_key.pub"
fi

if [ ! -f "$SSH_HOST_KEY_PUB" ]; then
  echo "Error: SSH host key not found at /etc/ssh/ or /persistent/etc/ssh/" >&2
  echo "Is this a mortlake machine with sops-nix configured?" >&2
  exit 1
fi

ssh-to-age <"$SSH_HOST_KEY_PUB"
