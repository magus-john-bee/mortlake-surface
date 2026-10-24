# Context Hub (chub) — usage & skills research

Task AT-GGMR · 2026-10-19 · upstream: `andrewyng/context-hub` (CLI npm `@aisuite/chub`, latest 0.1.4) + `andrewyng/context-hub-skill`
All CLI behavior below **verified empirically** against `npx @aisuite/chub@latest` (= 0.1.4) in a sandboxed `CHUB_DIR`.

## 1. What it is

Context Hub is Andrew Ng's registry + CLI for curated, versioned, language-specific, LLM-optimized API docs ("what to know") and a small set of agent skills ("how to do it"). The `chub` CLI searches/fetches from a CDN-backed registry (`cdn.aichub.org/v1`, content lives as markdown in the repo: 1,711 `DOC.md` under 622 org namespaces, refreshed through 2026-05-29) with a local cache at `~/.chub/`. MIT, ~14k stars, 141 open issues; designed so *agents* (not humans) run `search` → `get --lang` before writing code against third-party APIs, then persist local `annotate` notes and send `feedback` to doc authors.

## 2. Install / config prerequisites

- **No API keys.** Needs Node ≥ 18 + network to `cdn.aichub.org` (and `api.aichub.org` for telemetry/feedback).
- Install: `npm install -g @aisuite/chub` — or zero-install `npx -y @aisuite/chub` per call (what our vendored skill does; correct choice on NixOS where global npm installs are awkward; not packaged in nixpkgs).
- No init command. Optional config at `~/.chub/config.yaml`; `CHUB_DIR` env overrides the whole data dir (cache, `annotations/`, `client_id`).
- Config file (verified fields from `cli/src/lib/config.js` + `docs/cli-reference.md`):

```yaml
sources:
  - name: community
    url: https://cdn.aichub.org/v1
  - name: internal          # BYOD: local registry built with `chub build`
    path: /path/to/.chub-local
source: "official,maintainer,community"   # trust policy
refresh_interval: 21600                   # code default 6h (docs example says 86400)
telemetry: false                          # default TRUE — PostHog analytics
feedback: true                            # default TRUE — sends ratings/comments
help_url: false                           # disable remotely-updated help text
```

- **Privacy defaults matter:** telemetry is ON by default (`CHUB_TELEMETRY=0` to opt out) and sends raw search queries (up to 1,000 chars) + result IDs + a persistent `client_id`. `chub feedback` sends comments to maintainers (`CHUB_FEEDBACK=0` disables).
- `chub update` refreshes the registry cache (`--full` for offline bundle); `chub cache status|clear` manages it.

## 3. Core commands an agent actually uses

```bash
# discovery
chub search "stripe payments" --json     # fuzzy; pick best `id` from results
chub search stripe/api --json            # exact id → full detail (versions, files, sizes)
chub search --tags automation --lang py --limit 20

# fetch (multi-id OK)
chub get openai/chat --lang py           # python variant of a multi-lang doc
chub get playwright-community/login-flows          # skill — no --lang needed, auto-detected
chub get stripe/api -o .context/         # save to file instead of stdout
chub get acme/widgets --file references/advanced.md # incremental: only named reference file
chub get acme/widgets --full             # everything (default = entry point + footer listing additionalFiles)

# learn / give back
chub annotate stripe/api "Webhook verify needs raw body"   # local, persists at ~/.chub/annotations/
chub annotate <id> | --list | --clear                       # view / list / remove
chub feedback stripe/api up --label accurate "Clear examples"

# piping pattern (from official docs)
ID=$(chub search "stripe" --json | jq -r '.results[0].id'); chub get "$ID" -o .context/stripe.md
```

MCP: the package ships a second binary `chub-mcp` (stdio server, tools `chub_search`, `chub_get`, `chub_list`, `chub_annotate`, `chub_feedback`; `withAnnotations: true` param mirrors the unreleased CLI flag).

## 4. Skills / snippets the project itself ships

- **`cli/skills/get-api-docs/SKILL.md`** (packaged inside the npm tarball). The canonical agent skill: 4 steps — (1) ensure `chub` exists (`npm i -g @aisuite/chub` if missing), (2) `chub search "<keywords>" --json`, (3) `chub get <id> --lang py|js|ts`, (4) use docs, then `annotate` gotchas + `feedback`. Two notable design choices: *"If this file and `chub --help` ever disagree, follow `chub --help`"* — i.e. remote, version-keyed help text is the source of truth; and install instructions `cp $(npm root -g)/@aisuite/chub/skills/get-api-docs/SKILL.md <agent-skill-dir>/get-api-docs.md` (Claude: `.claude/skills/` or `~/.claude/skills/`; Cursor: `.cursor/rules/`).
- **`andrewyng/context-hub-skill` repo** (created 2026-04-22): standalone `skills/context-hub/SKILL.md` installable via the open `skills` CLI: `npx skills add andrewyng/context-hub-skill --skill context-hub -g -a claude-code -a cursor -a codex -y`. Same flow, plus "always leave feedback after using an entry" as step 5 and the same help-is-truth rule.
- **Registry skill content** (the "skills" the registry itself distributes, `chub get <id>` fetches these as plain SKILL.md): only 9 real ones today — `playwright-community/login-flows`, `flutter/skills/state-management/{bloc-cubit,riverpod}`, `landingai/skills/ade/{document-extraction,document-workflows}`, `olakai/skills/{integrate,new-project}`, `sourceparts/skills/electronics-sourcing`. Verified fetchable; frontmatter + prose + code, no install step.
- **Community pi packages** (relevant to our harness): `JeancarloBarrios/pi-context-hub` (npm `pi-context-hub`, `pi install npm:pi-context-hub` — tools `chub_search/chub_get/chub_annotate/chub_feedback`, `/chub` command, bundles its own get-api-docs skill) and `RingCanary/pi-context-hub` (single `context_hub` tool + `/chub` + turn-level system-prompt hinting). Both are thin wrappers over the same CLI.
- **Docs worth quoting for AGENTS.md authoring:** `docs/byod-guide.md` (build private docs/skills → `chub build` → local `path:` source; `internal:id` prefixing for collisions), `docs/design.md` (docs vs skills taxonomy and why), `docs/cli-reference.md` (full command/flag reference + piping patterns), `docs/feedback-and-annotations.md` (annotation trust model).

## 5. How to prepare an agent to use it well

- **Trigger placement:** fire on "write code against any external API/SDK/library", "latest docs/API behavior", or explicit "chub". That's exactly our vendored `software-development/get-api-docs` skill's description — keep it; it's better adapted than upstream's (npx invocation, llms.txt + Exa fallback chain, pitfalls list).
- **Workflow:** `search --json` → pick `id` → `get --lang <lang>` → code from the doc, not memory → annotate environment-specific gotchas (`chub annotate`), optionally feedback.
- **Verified gotchas on 0.1.4** (beyond our skill's existing notes):
  - `--version` is documented but errors (`unknown option '--version'`) — get version from output header instead (our skill already says this; still true).
  - **`--with-annotations` is documented but NOT shipped** — `chub get <id> --with-annotations` → `unknown option`. Worse: default `chub get` output doesn't even mention that an annotation exists (no pointer line). On the current release, annotations are effectively **write-only**; the only read path is `chub annotate <id>` / `annotate --list`. Docs describe unreleased behavior.
  - Multi-language docs fetched without `--lang` print an interactive chooser — always pass `--lang` in non-interactive contexts (single-variant docs auto-infer; the flag is harmless).
  - Annotations **do persist across npx sessions** (stored in `$CHUB_DIR`/`~/.chub/annotations/`, not the package cache) — our skill's "npx ephemerality" caveat is outdated; the real caveat is the missing `--with-annotations` read path.
  - Every `chub get` appends a feedback nag footer (labels list + "do NOT include code/architecture in feedback") — harmless, actually useful agent guidance.
  - `chub help` output is **remotely mutable** for a given binary version (`help_url` fetch from the CDN, "can be revised over time to tune prompting"). Treat as untrusted-ish; set `help_url: false` for determinism.
  - Stale results → `chub update`; cache TTL 6h.

## 6. Gaps / risks for our use

- **Maintenance plateau:** CLI 0.1.4 released 2026-04-27; last repo push 2026-05-31 (~6 months quiet as of 2026-10-19); content frozen at 2026-05-29. Not dead like ProContext, but docs-vs-binary drift (above) shows release hygiene slipping. Pin the version; don't assume flags exist without checking.
- **Telemetry/privacy:** default-on analytics ship raw agent queries + persistent client_id to api.aichub.org; feedback sends free-text comments. On mortlake agents this can leak internal identifiers. Set `telemetry: false` (or `CHUB_TELEMETRY=0`) declaratively; keep `feedback` explicit-only.
- **Remote-mutable help** = a remotely-updatable prompt surface for any agent told to obey `chub help` verbatim (both official skills encode that rule). Low risk, but disable `help_url` if we want hermetic behavior.
- **Registry shape:** doc-heavy, Python/JS-centric; only 9 skills. No auth/private-content story yet (`docs/private-content.md` is "coming soon") — BYOD via `chub build` + local source path works today but is fully manual.
- **Coverage risk:** curated docs can lag real APIs (e.g. octokit entry last updated 2026-03-01); the skill's llms.txt/Exa fallback chain stays necessary.
- **~/.chub state:** cache + annotations + client_id live in the home dir — needs persistence on NixOS (preservation) or a pinned `CHUB_DIR`.

## 7. Recommendation for mortlake wiring + skill authoring

1. **Don't install globally; wrap.** No nixpkgs package. Add a tiny wrapper (`chub` → `npx -y @aisuite/chub@0.1.4`) via our wrapper-modules pattern so agents (and the skill) can call `chub` naturally while the version stays pinned; revisit pin when a 0.1.5+ lands with `--with-annotations`.
2. **Declarative config:** manage `~/.chub/config.yaml` (or a persisted `CHUB_DIR`) with `telemetry: false`, `feedback: true` (explicit action only), optionally `help_url: false`, and list the community CDN source. Ensure the dir is preserved (annotations are the durable value).
3. **Skip MCP and the community pi packages for now.** `chub-mcp` and `pi-context-hub` wrap the same CLI our bash tool already runs; the skill path is one moving part fewer. Revisit only if agents show friction with npx latency.
4. **Skill authoring — update our vendored `get-api-docs`:**
   - Correct the annotation caveat: persistence works under npx; the real gap is no read path in `chub get` on 0.1.4 — instruct agents to re-read notes via `chub annotate <id>` after fetch, and to keep annotating (the data is forward-compatible).
   - Add incremental fetch (`--file references/x.md`, `--full`) and `-o .context/` to save-token guidance.
   - Add `chub update` as the stale-cache step.
   - Add feedback as **optional, ask-or-cheap** rather than upstream's "always" (we run telemetry-off; feedback is a deliberate send).
   - Keep the llms.txt → Exa fallback chain and the `--lang`-always rule — both still right.
5. **For the global AGENTS.md rewrite (AT-XMVW):** one line in the tooling section — "before coding against any third-party API, run the get-api-docs skill (chub: search → get --lang); never trust memorized API shapes." Point to the skill, don't inline the chub command set.
6. **Future option:** mortlake internal API docs (taskdog, hermes, dionysus…) could be authored as `DOC.md` trees and served via `chub build` + local source — same search UX for private content, no publishing. Cheap to pilot later; not a dependency for this wiring.

Raw artifacts kept alongside: `chub-main-readme.md`, `chub-cli-reference.md`, `chub-tree.txt` (full repo tree).
