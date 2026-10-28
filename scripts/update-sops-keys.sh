#!/usr/bin/env bash
# update-sops-keys — re-encrypt sops secret files after adding/removing a host key.
#
# After editing .sops.yaml (adding a new machine's age key to creation_rules),
# run this to re-encrypt all secret files so the new machine can decrypt them.
#
# Usage:
#   nix run .#update-sops-keys
set -euo pipefail

SECRET_FILES=(
  "modules/features/secrets.yaml"
)

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
cd "$REPO_ROOT"

for f in "${SECRET_FILES[@]}"; do
  if [ -f "$f" ]; then
    echo "Updating keys for $f..."
    sops updatekeys "$f"
  fi
done

echo "Done. Commit the updated secret files."
