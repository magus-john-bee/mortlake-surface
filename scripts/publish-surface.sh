#!/usr/bin/env bash
# Publish the public surface (magus-john-bee/mortlake-surface) from the
# private canonical's main: an allow-listed snapshot, machine-gated, and
# force-pushed as a single orphan commit per release.
#
# Extracted from the retired .github/workflows/publish-surface.yml when the
# publication trigger moved to jehoel (RDC-MJRJ). The publish-surface.timer
# runs this whenever canonical main (radicle storage, via PUBLISH_SOURCE)
# differs from the last-published sha; `just publish-surface` runs it with
# --force from the merge ritual. Publication means public: every run of
# this script is a publish event.
#
# Gates, in order:
#   1. The snapshot is ENUMERATED (allow-list below) — new private content
#      cannot ship by default; a path must be explicitly listed to ever ship.
#   2. Deny-list audit — defense in depth against renames landing private
#      content under a listed dir.
#   3. `nix flake check --no-build` against the SNAPSHOT — a surface that
#      doesn't eval can never be published.
#
# Env:
#   PUBLISH_SOURCE       git-dir of the canonical (radicle storage on jehoel;
#                        wired by the systemd unit via sops-rendered env)
#   SURFACE_PAT          fine-grained PAT, contents:write on the surface repo
#   PUBLISH_STATE_FILE   last-published sha (default under ~/.local/state)
set -euo pipefail

force=0
if [ "${1:-}" = "--force" ]; then force=1; fi

: "${PUBLISH_SOURCE:?PUBLISH_SOURCE (canonical git-dir) must be set}"
STATE_FILE="${PUBLISH_STATE_FILE:-$HOME/.local/state/publish-surface/last-published}"

src_sha="$(git --git-dir="$PUBLISH_SOURCE" rev-parse refs/heads/main)"
echo "publish-surface: canonical main = $src_sha"

if [ "$force" -eq 0 ] && [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "$src_sha" ]; then
  echo "publish-surface: $src_sha already published; nothing to do"
  exit 0
fi

: "${SURFACE_PAT:?SURFACE_PAT must be set to publish}"

WORK="$(mktemp -d)"
DEST="$(mktemp -d)"
trap 'rm -rf "$WORK" "$DEST"' EXIT

# Work from the pinned sha, never a moving ref: clone the local git-dir and
# detach. The working checkout is not read — it may be mid-merge.
git clone --quiet --no-checkout "$PUBLISH_SOURCE" "$WORK"
git -C "$WORK" -c advice.detachedHead=false checkout --quiet "$src_sha"

# ── THE ALLOW-LIST — public surface, enumerated ──
mkdir -p "$DEST/.github/workflows"
cp "$WORK/flake.nix" "$WORK/flake.lock" "$WORK/README.md" "$WORK/AGENTS.md" \
  "$WORK/justfile" "$WORK/.gitignore" "$WORK/.sops.yaml" "$DEST/" 2>/dev/null || true
for d in modules templates scripts docs data; do
  [ -e "$WORK/$d" ] && cp -r "$WORK/$d" "$DEST/"
done
# Resume site without build artifacts:
mkdir -p "$DEST/sites"
cp -r "$WORK/sites/dev-resume" "$DEST/sites/dev-resume"
rm -rf "$DEST/sites/dev-resume/node_modules" "$DEST/sites/dev-resume/public" \
  "$DEST/sites/dev-resume/resources" "$DEST/sites/dev-resume/.hugo_build.lock" \
  "$DEST/sites/dev-resume/hugo_stats.json"
# Deploy-site workflow ships (Pages deploy continues to work from the
# surface repo); no publish workflow ships.
cp "$WORK/.github/workflows/deploy-site.yml" "$DEST/.github/workflows/"
echo "publish-surface: snapshot = $(find "$DEST" -type f | wc -l) files"

# ── Surface audit — refuse private paths ──
# Hard failure if any deny-listed path made it into the snapshot.
if find "$DEST" \( -path '*/skills/*' -o -path '*/skill-archive/*' -o -path '*/android/*' \) | grep -q .; then
  echo "::error::private path leaked into the public snapshot" >&2
  exit 1
fi
if find "$DEST" -name 'secrets.yaml' | grep -qv 'modules/features/secrets.yaml'; then
  echo "::error::unexpected secrets file in snapshot" >&2
  exit 1
fi

# The hermes-agent input's eval reads uv.lock out of a BUILT source tree
# (uv2nix loadWorkspace over cleanSourceWith) — the filtered source path
# only exists after a build. Realize the package once from the SNAPSHOT so
# the eval-time read succeeds, then check.
cd "$DEST"
git init -q .
git add -A
nix --accept-flake-config build --no-link \
  ".#nixosConfigurations.jehoel.config.services.hermes-agent.package" 2>/dev/null ||
  nix --accept-flake-config build --no-link \
    github:NousResearch/hermes-agent#packages.x86_64-linux.default
nix --accept-flake-config flake check --no-build

# ── Publish orphan snapshot ──
# One commit per release; history is intentionally a single orphan commit.
# The PAT rides the push URL only — never written to a config file.
git -c user.name="publish-bot" -c user.email="publish-bot@users.noreply.github.com" \
  commit -q --allow-empty -m "snapshot: mortlake public surface @ $src_sha

Auto-published from the private canonical repo. History is
intentionally a single orphan commit per release."
git branch -M main
# Credential helpers are reset for this push: the scoped SURFACE_PAT rides
# the URL, and john's global `gh auth git-credential` helper must not
# override it (or fail trying — gh is not on the service PATH).
git -c credential.helper= push --quiet --force \
  "https://x-access-token:${SURFACE_PAT}@github.com/magus-john-bee/mortlake-surface.git" main
echo "publish-surface: published $(git rev-parse --short HEAD) from $src_sha"

mkdir -p "$(dirname "$STATE_FILE")"
echo "$src_sha" >"$STATE_FILE"
