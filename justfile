# ── Nix config evaluation ──────────────────────────────────

eval host:
    nix eval --json --show-trace .#nixosConfigurations.{{ host }}.config.system.build.toplevel.drvPath

dry host:
    nixos-rebuild dry-build --flake .#{{ host }} --show-trace

# ── Linting ────────────────────────────────────────────────

lint:
    #!/usr/bin/env bash
    set -euo pipefail
    fail=0
    echo "Running nix fmt..."
    nix fmt -- --fail-on-change || fail=1
    echo "Running statix check..."
    statix check . || fail=1
    echo "Running deadnix..."
    deadnix --fail . || fail=1
    echo "Linting new/changed skills (MD043 template)..."
    just lint-skills || fail=1
    exit $fail

# Lint only ADDED SKILL.md files vs the recorded baseline. Policy
# (2026-10-16): new skills must conform to the template at birth; legacy
# skills are migrated to it deliberately, as their own units ("fix as we
# go") — incidental edits do not force a template rewrite mid-task.
# Bump the baseline ONLY for bulk skill imports.
skill-lint-base := ""

lint-skills:
    #!/usr/bin/env bash
    set -euo pipefail
    base="{{ skill-lint-base }}"
    [ -z "$base" ] && base=$(cat scripts/.skill-lint-baseline 2>/dev/null || echo origin/main)
    if ! git cat-file -e "$base" 2>/dev/null; then echo "skill lint: base $base not found, skipping"; exit 0; fi
    mapfile -t changed < <(
      git diff --name-only --diff-filter=A "$base" -- 'skills/**/SKILL.md' '.agents/skills/**/SKILL.md'
      git ls-files --others --exclude-standard -- 'skills/**/SKILL.md' '.agents/skills/**/SKILL.md'
    )
    if [ ${#changed[@]} -eq 0 ]; then echo "no changed skills"; exit 0; fi
    exec markdownlint-cli2 "${changed[@]}"

lint-fix:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Fixing with nix fmt..."
    nix fmt
    echo "Fixing with statix..."
    statix fix .
    echo "Fixing with deadnix..."
    deadnix --edit .
    echo "Lint fix complete"

# jj-land message: lint-gated jj commit (fixers → full gate → commit; push stays manual)
jj-land message:
    #!/usr/bin/env bash
    set -euo pipefail
    # Fixers run first so nix fmt's --fail-on-change doesn't abort with
    # unapplied fixes; the commit then includes whatever they changed.
    [ -d .jj ] || { echo "jj-land: not a jj repo (no .jj/)" >&2; exit 1; }
    just lint-fix
    just lint
    msg="{{ message }}"
    jj commit -m "$msg"
    echo "Committed: $msg"
    echo "Push is manual: jj bookmark set main -r @- && jj git push"

# ── Agent skills ───────────────────────────────────────────

sync-feynman-skills:
    #!/usr/bin/env bash
    set -euo pipefail
    # Feynman skills are a vendor sync (feynman.is) — tier 2 since the
    # 2026-11 curation: search-only in the archive, never auto-loaded.
    target="/home/john/src/skills-tmp/skill-archive/feynman"
    rm -rf "$target"
    curl -fsSL https://feynman.is/install-skills | bash -s -- --dir "$target"
    printf '%s\n' 'prompts/' 'AGENTS.md' 'CONTRIBUTING.md' > "$target/.fdignore"
    (cd /home/john/src/skills-tmp && ./scripts/skills-index.sh)
    count=$(find "$target" -name 'SKILL.md' | wc -l)
    echo "Synced $count feynman skills to the archive (tier 2); commit skills-tmp"

# ── Publish surface ────────────────────────────────────────

# Force-publish the public surface from current canonical main (RDC-MJRJ):
# the same script publish-surface.timer runs, without the sha guard.
# jehoel-only — needs the sops-rendered env (modules/features/publish-surface.nix).
publish-surface:
    #!/usr/bin/env bash
    set -euo pipefail
    set -a
    source /run/secrets/rendered/publish-surface-env
    set +a
    scripts/publish-surface.sh --force

# ── Personal sites ─────────────────────────────────────────

build-resume variant="generalist":
    cd sites/dev-resume && python3 scripts/build-resume.py {{ variant }} && hugo --minify

resume-variants:
    cd sites/dev-resume && python3 scripts/build-resume.py

# ── pi-tracer extension ────────────────────────────────────

# The extension's only check: byte-level protobuf assertions, plus the
# python schema round-trip when the Phoenix venv is present (skip otherwise).
pi-tracer-selftest:
    cd pi-extensions/pi-tracer && bun tests/selftest.ts
