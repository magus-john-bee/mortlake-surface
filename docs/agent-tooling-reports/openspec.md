# OpenSpec — usage research for pi + Hermes + mortlake

Upstream: https://github.com/Fission-AI/OpenSpec — researched 2026-10-19 from repo HEAD (default branch), `docs/` + `docs-lab/` (site source for openspec.dev), `src/core/templates/` and `src/core/command-generation/adapters/`. npm `@fission-ai/openspec` v1.14.3 (published 2026-10-17; actively maintained).

## 1. What it is

OpenSpec is a spec-driven-development layer for AI coding assistants: a CLI plus a per-repo `openspec/` folder of plain Markdown (`specs/` = system truth, `changes/<name>/` = in-flight proposal+spec-deltas+design+tasks, `changes/archive/` = history). The CLI is a pure state machine (no LLM, no API keys, no network required) — it scaffolds changes, resolves an artifact dependency DAG, validates Markdown structure, and merges delta specs on archive; your existing agent does all the writing, guided by skill/command files OpenSpec generates per tool. It ships first-class adapters for **both pi and Hermes** (plus 35+ other tools: Claude Code, Cursor, Codex, opencode, …).

## 2. Install / config prerequisites

- **Runtime**: Node.js ≥ 20.19.0. Install: `npm i -g @fission-ai/openspec@latest`, `brew install openspec`, or Nix (repo ships `flake.nix` with `overlays.default` exposing `openspec`; works on x86_64/aarch64 Linux+Darwin).
- **No keys, no env required.** Only env vars are telemetry opt-outs: `OPENSPEC_TELEMETRY=0` or `DO_NOT_TRACK=1` (telemetry is on by default — command names + version only, auto-off in CI; `openspec config set telemetry.enabled false` disables globally).
- **Per-repo init** (run at repo root, interactive tool picker):
  ```bash
  cd mortlake && openspec init            # picker
  openspec init --tools pi,hermes        # non-interactive
  ```
  This writes:
  - `openspec/` — `config.yaml`, empty `specs/`, `changes/archive/`
  - Tool files: **pi** → `.pi/skills/openspec-*/SKILL.md` + `.pi/prompts/opsx-<id>.md`; **hermes** → `.hermes/skills/openspec-*/SKILL.md`; shared → `.agents/skills/…`
- **Per-machine global config** (`~/.config/openspec/config.json`, edited via `openspec config`): profile (workflow set) and delivery (skills / commands / both, default both). Change with `openspec config profile` then `openspec update` in each repo to regenerate tool files.
- **Project config** `openspec/config.yaml` (optional but recommended):
  ```yaml
  schema: spec-driven        # default; artifact DAG definition
  context: |                 # ≤50KB project context injected into all artifact instructions
    Tech stack: NixOS flake-parts (dendritic), wrapper-modules ...
  rules:                     # per-artifact rules (ids: proposal, specs, design, tasks)
    specs:
      - Use Given/When/Then scenarios
  ```
- **Hermes gotcha (documented by OpenSpec itself)**: Hermes loads skills only from `~/.hermes/skills/` by default. To use project-local OpenSpec skills you must add the repo's `.hermes/skills/` to `skills.external_dirs` in `~/.hermes/config.yaml`. (Source: `src/core/config.ts` Hermes entry `setupNote` + footnote in `docs/supported-tools.md`.)

## 3. Core commands an agent actually uses

The generated skills drive the agent through this loop (from `src/core/templates/workflows/propose.ts`):

```bash
openspec context --json                          # resolve root: {root.path} | no_openspec_root
openspec new change "add-auth"                   # scaffold openspec/changes/add-auth/ (+ .openspec.yaml)
openspec new change "x" --schema mortlake-flow   # non-default schema
openspec status --change "add-auth" --json       # artifact DAG: status/ready/blocked + requires edges + applyRequires
openspec instructions specs --change "add-auth" --json
#   → { context, rules, template, instruction, resolvedOutputPath, dependencies }
openspec instructions apply --change "add-auth" --json   # apply-phase task list + progress
```

Reading / QA / lifecycle:

```bash
openspec list                       # active changes
openspec show <change>              # print artifacts
openspec validate                   # lint specs/changes structure (delta hygiene)
openspec validate --archived --report full
openspec archive add-auth --yes     # merge delta specs → openspec/specs/, move folder to changes/archive/YYYY-MM-DD-*/
openspec view                       # local dashboard (status of all changes)
```

Custom workflows + multi-repo:

```bash
openspec schemas                    # list artifact schemas
openspec schema fork spec-driven mortlake-flow   # custom DAG + templates in openspec/schemas/
openspec store setup                # planning lives in its own git repo (beta)
openspec store register ~/openspec/team-plans    # per-machine join
openspec status --store team-plans  # any command takes --store
```

In chat, the user-facing entry points are skills/commands pi generates: `/opsx-propose`, `/opsx-apply` (pi spells slash commands by prompt filename; Claude-style tools use `/opsx:propose`). Skills can also auto-trigger from plain language ("propose a change to …") via their SKILL.md descriptions.

## 4. Skills / snippets the project itself ships

All agent instruction content is **generated at init/update** from `src/core/templates/workflows/*.ts` (propose, apply-change, archive-change, sync-specs, update-change, explore, new/continue/ff, verify, bulk-archive, onboard). Core six (default profile): `openspec-explore`, `openspec-propose`, `openspec-apply-change`, `openspec-update-change`, `openspec-sync-specs`, `openspec-archive-change`. Six optional: `new`, `continue`, `ff`, `verify`, `bulk-archive`, `onboard`. Full contracts: `docs-lab/reference/skills.md`.

Notable shipped patterns worth copying:

- **Planning boundary** (top of every propose/continue template): *"This workflow creates planning artifacts only. The user request … authorizes planning only, even if it asks to build or fix something. Do not edit project code. After the planning artifacts are complete, stop."*
- **Status-is-file-existence rule**: "`status` is file-existence only … writing `tasks.md` early marks `tasks` done while `specs` was never written. Use each artifact's `requires` edges, not its `status`, to build the required set." Agents re-run `openspec status --json` after each artifact.
- **Context/rules hygiene**: "`context` and `rules` are constraints for YOU, not content for the file — do NOT copy them into the artifact."
- **Re-read from disk**: "always re-read [dependency artifacts] from disk, even if you saw them earlier in the conversation (the user may have edited them)."
- **Root guard** (`src/core/templates/workflows/project-root.ts`): if no `openspec/` root resolves, auto-selected skills drop OpenSpec silently; explicitly-invoked ones stop and offer `init` / `--store` / continue-without — never auto-init.
- **Pi adapter** (`src/core/command-generation/adapters/pi.ts`): skills → `.pi/skills/openspec-*/SKILL.md`; commands → `.pi/prompts/opsx-<id>.md` with `description:` frontmatter and `$@` injected as "Provided arguments" under the `**Input**` heading. Filename minus `.md` = slash command.
- The repo **dogfoods itself**: `openspec/specs/` + `openspec/changes/` (incl. deep `archive/` back to 2025-01) are live examples at scale; maintainer-only skills live in `.agents/skills/` (draft-openspec-docs, write-openspec-docs, verify-openspec-docs, release-openspec). Root `AGENTS.md` in the repo is **empty** — generated per-tool skills carry all instructions; OpenSpec does not require you to maintain an AGENTS.md section for it.

## 5. How to prepare an agent to use it well

- **Workflow placement**: explore (optional think-mode, writes nothing) → propose (plan only) → **human reviews plan** (specs/ is the highest-value read) → apply in a **fresh context** (works through `tasks.md` checkboxes, resumable at first unchecked box — "progress lives in the checkboxes; there is no hidden state") → archive (merges deltas into `specs/`, prompts to sync first). `update` revises artifacts mid-flight without touching code; `sync` merges deltas early when a parallel change builds on them.
- **Teach the boundary discipline**: propose/continue/ff/sync/archive/update never edit code; apply never re-plans silently (it pauses on unclear tasks). This is what makes specs trustworthy — don't coach agents to bypass it.
- **Teach the CLI loop, not the file layout**: the sanctioned flow is `context → new change → status → instructions per artifact → write → status`. Templates explicitly say the `instruction` field from `openspec instructions` is authoritative "even for familiar artifact names."
- Gotchas: `openspec init` is interactive unless `--tools`; legacy `/openspec:*` commands still exist (don't mix metaphors with `/opsx-*`); profile/delivery settings are **per-machine globals** — codify them (e.g., Nix-managed `config.json`) so pi on jehoel and elsewhere agree; `openspec update` after every CLI upgrade to refresh generated skills; stores/worksets are beta.
- The skills' own docs note they expect **high-reasoning models** and a clean context window for apply.

## 6. Gaps / risks for our use

- **Nix packaging**: upstream flake exists but wraps the npm package; for mortlake (NixOS, flake-parts) you'd add it as a flake input/overlay or `nodePackages` — must land on PATH for both pi sessions and Hermes. Not in nixpkgs-stable necessarily (unverified).
- **Two-repo topology (staging → canonical promotion)**: repo-local `openspec/` means specs live in whichever checkout ran init; the staging mirror flow means specs must promote with code or you get drift. A **store** (separate planning repo) is the upstream answer for multi-repo, but it's beta.
- **Hermes on jehoel**: project-local `.hermes/skills/` requires a manual `~/.hermes/config.yaml` `skills.external_dirs` edit — outside declarative NixOS management unless we template it; Hermes skills are conversational invocations (`/openspec-propose`), no command files generated.
- **validate is structural, not semantic**: it lints Markdown/ delta hygiene (ADDED/MODIFIED/REMOVED/RENAMED requirement headers), not requirement quality; `verify` skill (optional profile) is the LLM-side check.
- Telemetry on by default (trivial to disable, but do it deliberately for the home lab).
- `.pi/`, `.hermes/`, `.agents/` generated dirs add repo noise; delivery=schools-only (`openspec config set delivery skills`) avoids duplicate command files.
- Slight overlap with aven (task tracking) and with the AGENTS.md/global-agents work (AT-XMVW): OpenSpec's `tasks.md` is a per-change implementation checklist, not a task manager — keep aven for intent-level tasks; keep OpenSpec out of the AGENTS.md core (its skills self-describe).
- Betas move fast: 12 workflows, custom schemas, stores — pin the CLI version per repo generation (`openspec update` changes generated files).

## 7. Recommendation for mortlake wiring + skill authoring

1. **Wire-up**: add `openspec` to jehoel's env via flake input or npm-global; `openspec config set telemetry.enabled false` once; `openspec config profile` → enable `verify` (core + verify is a good set), delivery `skills` only.
2. **Init in both mortlake checkouts** (staging and canonical) with `--tools pi,hermes`; commit `openspec/`, `.pi/skills/`, `.hermes/skills/`. Generated skills then **are** the pi skill surface — no hand authoring needed for the core loop. For Hermes, add the repo `.hermes/skills` path to `~/.hermes/config.yaml` `skills.external_dirs` (declaratively if Hermes config is templated on jehoel).
3. **Shared specs with John**: the committed `openspec/` folder is the sharing mechanism — pi (interactive) and Hermes (assistant) both read/write the same change folders in the repo; John reviews `proposal.md`/`specs/` as PRs. Sync specs only via `openspec sync`/`archive` so merges stay structured.
4. **Fill `openspec/config.yaml` context** with mortlake's dendritic conventions (self vs self', import-tree, wrapper-modules, sops) and per-artifact rules — this is where repo-specific judgment belongs, not in a forked skill.
5. **Author a thin mortlake wrapper skill** (our three-tier library, not OpenSpec's generated dirs) covering: when to propose vs direct edit (brownfield policy: spec for behavior changes, skip for mechanical bumps), the staging→canonical promotion interplay (change folder promotes with the code PR; never archive on staging only), and "use `/opsx-*` prompt templates in pi". Optionally later: `openspec schema fork spec-driven mortlake-flow` if promotion needs a dedicated artifact — defer until the default DAG proves insufficient.
6. **Don't duplicate**: no aven↔OpenSpec sync; no AGENTS.md section re-explaining OpenSpec (generated skills carry it) — at most one line pointing at `openspec/changes/` for current work.

— researched via `gh api` against Fission-AI/OpenSpec@HEAD (v1.14.3 era) + openspec.dev llms.txt; primary sources: README.md, docs/opsx.md, docs/supported-tools.md, docs-lab/{start/setup,start/quickstart,reference/skills,reference/cli,customize/profiles,customize/project-config,multi-repo/stores}.md, src/core/config.ts, src/core/command-generation/adapters/pi.ts, src/core/templates/workflows/propose.ts.
