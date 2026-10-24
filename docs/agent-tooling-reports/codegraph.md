# CodeGraph — research for mortlake agent wiring

Upstream: https://github.com/colbymchenry/codegraph · v1.6.2 (2026-10-03, latest release) · MIT · npm `@colbymchenry/codegraph`
Docs site: https://colbymchenry.github.io/codegraph/ (no llms.txt — 404; README + repo docs are the index)
Researched 2026-10-19 via `gh api` against README, repo tree, AGENTS.md, docs/AGENTS.md, `src/installer/instructions-template.ts`, `src/mcp/server-instructions.ts`, `src/installer/targets/hermes.ts`, `src/bin/codegraph.ts`, `.claude/skills/*`.

## 1. What it is

CodeGraph is a local-first semantic code-intelligence tool: a Rust-kernel/tree-sitter extraction pipeline parses a codebase into a SQLite knowledge graph of every symbol, call/import/inheritance edge, and file (FTS5 full-text search on top), and exposes it to AI coding agents so they stop doing grep/glob/read discovery loops. The pitch is "surgical context": one query returns the relevant symbols' verbatim line-numbered source grouped by file, plus the call paths between them (including synthesized dynamic-dispatch hops — callbacks, React re-renders, interface→impl) and a blast-radius summary of what a change affects. It is consumed either as an MCP server exposing a single tool (`codegraph_explore`) or as a plain CLI (`codegraph explore "<query>"` prints the identical output — explicit design goal, documented in the installer template for "non-MCP harnesses"). 100% local, no keys, no external services; 30+ languages with **full Nix support including NixOS module option wiring** and full Terraform — both directly relevant to mortlake.

Their own benchmarks (7 repos × 4 runs, Claude Opus 4.8, CLI blocked in both arms, 0/28 contamination): 88% fewer tool calls, 53% faster, 62% fewer tokens, 44% cheaper, zero file reads on all seven. Honest caveat they publish themselves: residual context occupancy is ~80% *higher* than a grep/read agent at session end (67k vs 18k resident tokens on VS Code) — one dense payload stays in the window where many small results churn and evict.

## 2. Install / config prerequisites

- **No keys, no API, no account.** Nothing to authenticate. Telemetry is anonymous usage counters, asked at install; off via `codegraph telemetry off`, `CODEGRAPH_TELEMETRY=0`, or `DO_NOT_TRACK=1`.
- **Install the CLI** (three routes):
  - `curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh` — self-contained bundle (its own Node runtime, nothing to compile) into `~/.codegraph/versions/<v>/`, symlink at `~/.local/bin/codegraph` (overridable `CODEGRAPH_INSTALL_DIR` / `CODEGRAPH_BIN_DIR`).
  - `npm i -g @colbymchenry/codegraph`.
  - `npx @colbymchenry/codegraph` (download-and-run).
  - Upgrade in place: `codegraph upgrade [--check|<version>]`.
- **`codegraph install`** wires the *MCP server* into detected agents (Claude Code, Cursor, Codex, opencode, **Hermes Agent** via `$HERMES_HOME/config.yaml` `mcp_servers` + `platform_toolsets.cli`, Gemini, Antigravity, Kiro, Copilot) and writes a marker-fenced block into each agent's instructions file. **pi is not a target and pi has no MCP — for pi you skip this step entirely** and rely on the CLI, or hand-write the snippet (§4) into AGENTS.md / a skill. The installer never indexes anything.
- **Per project:** `codegraph init` in the repo root — creates `.codegraph/` and builds the full graph in one step. `codegraph uninit` / `codegraph index --force` / `codegraph sync` / `codegraph status` manage it.
- **Optional `codegraph.json`** at project root: `exclude`/`include` (gitignore-style), `deprioritize` (rank-only demotion of e.g. `scripts/`), `extensions` (map custom extensions to a language id). Otherwise zero-config: honors `.gitignore`, skips `node_modules`/`dist`/`vendor`/etc. and files >1 MB by default.
- Notable env vars: `CODEGRAPH_NO_DAEMON=1` (no shared background daemon), `CODEGRAPH_DIR` (custom index dir name), `CODEGRAPH_WATCH_DEBOUNCE_MS`, `CODEGRAPH_MCP_TOOLS` (re-list narrow MCP tools), `CODEGRAPH_TELEMETRY=0` / `DO_NOT_TRACK=1`, `CODEGRAPH_EXPLORE_DEDUP=1`, `CODEGRAPH_WAL_VALVE_MB` / `CODEGRAPH_WAL_HEAL_MB`.

**Index storage:** `.codegraph/codegraph.db` — SQLite with FTS5, WAL mode, via Node's built-in `node:sqlite` (bundled runtime always ≥22.5). One live writer per project (`writer.pid`, `daemon.sock` under `.codegraph/`); extra MCP clients proxy to the shared daemon. Freshness: native file watcher (inotify/FSEvents) with 2s debounce runs under the MCP server/daemon; MCP reconnect does `(size, mtime)`+hash catch-up; query-time drift detection flags "changed on disk after last sync" files and serves their *current* full source rather than stale slices. Pure-CLI sessions have **no watcher** — pre-flight `codegraph sync` is the documented pattern when scripting outside an agent session.

## 3. Core commands an agent actually uses

All read commands resolve the nearest `.codegraph/` walking up from cwd, or take `-p/--path <project>`. On an unindexed path, `explore` exits 1 with an explicit "continue with your usual tools; indexing is the user's decision, do not run it yourself" message — clean degradation, by design.

```bash
# The one command that matters — same output as the codegraph_explore MCP tool:
codegraph explore "how does a request reach the database"
codegraph explore "mutateElement renderScene"          # flow: name both endpoints
codegraph explore src/resolver.ts                       # named file → current line-numbered source
codegraph explore "AppWeb.Format.group" --max-files 5   # qualified names (dots/::/slashes OK)

# Narrower structural queries (CLI equivalents of the unlisted MCP tools):
codegraph query "UserService" --kind class --limit 20 --json
codegraph node fmt.fromString                          # one symbol: source + callers
codegraph node src/main.rs                             # ...or read a file with line numbers
codegraph callers handleRequest --json
codegraph callees parseConfig --limit 10
codegraph impact launchAgent --depth 3 --json          # blast radius before editing
codegraph affected $(git diff --name-only HEAD)        # tests affected by changed files
codegraph files --filter "src/**" --json

# Maintenance / hygiene:
codegraph init                    # once per project
codegraph sync                    # pre-flight in CLI-only sessions (cheap incremental)
codegraph status                  # stats + "### Pending sync:" section naming stale files
codegraph daemon                  # list/stop background daemons (non-TTY: prints list)
codegraph telemetry off
codegraph upgrade --check
```

`codegraph context <task> --format json` (ContextBuilder: task-relevant symbols + relationships + code blocks) also exists as a CLI/lib surface. Library embedding: `import CodeGraph from '@colbymchenry/codegraph'` — `init/open`, `indexAll`, `searchNodes`, `getCallers`, `getImpactRadius`, `buildContext`, `watch` (needs Node ≥22.5 for `node:sqlite`).

## 4. Skills / AGENTS snippets the project itself ships

1. **`src/installer/instructions-template.ts`** — `CODEGRAPH_INSTRUCTIONS_BLOCK`, the marker-fenced (`<!-- CODEGRAPH_START/END -->`) section `codegraph install` writes into CLAUDE.md / AGENTS.md / GEMINI.md. Deliberately short (read every turn; the full playbook lives in the MCP initialize response). Key content, quoted:

   > In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:
   > - **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
   > - **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.
   >
   > If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.

   The comment block explains *why* it exists: MCP initialize guidance never reaches Task-tool subagents or non-MCP harnesses — measured 1-of-9 subagent adoption without it, consistent adoption with it. The wording is conditional ("in repositories indexed by…") because a global install writes it into user-scope files that also cover unindexed repos.

2. **`src/mcp/server-instructions.ts`** — `SERVER_INSTRUCTIONS`, the full playbook delivered in the MCP `initialize` response (system-prompt level). This is the richest agent-prep text the project ships. Headlines: explore is **Read-equivalent** (same `<n>\t<line>` shape, safe to Edit from) and should be called *before and while* editing, not just for questions; one call usually answers the whole question; name symbols/files to get current source; flow queries name both endpoints ("`mutateElement renderScene`"); suggested call counts are advisory, never a quota. Anti-patterns: don't re-verify with grep (full AST parse underneath); don't grep/Read first; don't reconstruct flows by hand; obey the staleness banner (⚠️ → Read those specific files; unflagged files stay trustworthy); unindexed project → stop calling for the session and use built-ins, never self-init. Limitations stated plainly: index lags writes ~1s; cross-file resolution is best-effort name matching (ambiguous calls → multiple candidates); lexical not semantic matching (empty result reports word matches + did-you-mean names); no correctness validation — compiler/tests still own that.

3. **`AGENTS.md` + `docs/AGENTS.md`** (repo root) — guidance for agents working *on* codegraph itself: build/test commands, layered architecture (ExtractionOrchestrator → ReferenceResolver → GraphQueryManager → ContextBuilder), NodeKind/EdgeKind vocabulary, and a required validation methodology per language/framework (small/medium/large repos, ≥3 flow prompts, deterministic probes + A/B with the CLI blocked in both arms, Sonnet-high-effort as the deliberate floor model). Interesting as an exemplar of rigorous retrieval-tool evaluation, not user-facing.

4. **`.claude/skills/add-lang/SKILL.md` and `.claude/skills/agent-eval/SKILL.md`** — contributor workflow skills (add a tree-sitter language end-to-end; run the with/without benchmark harness). Again dev-facing, not shipped to users.

Note what does *not* exist: no pi target, no generic "how to use codegraph" SKILL.md for end users, no llms.txt. The two snippets above are the entire shipped guidance surface, and the second one (server instructions) is the source to mine for a pi skill.

## 5. How to prepare an agent to use it well

- **Placement: before the discovery loop, not after.** The single biggest behavioral requirement is ordering — `explore` replaces the initial grep/glob/read crawl for *structural* questions ("how does X work", "what/where is X", "how does X reach Y", pre-edit impact). Raw Read/Grep stay for what the graph doesn't index: configs, docs, prose, exact-string hunts.
- **Query shapes to teach:** natural-language question; a bag of symbol/file names; a *pair* of names for flow questions. Qualified names with dots/`::`/slashes work. Exact names matter — flow endpoints are never fuzzy-matched; on a miss, retry with the did-you-mean suggestion the empty result prints.
- **Trust discipline:** treat returned source as already-Read (it is verbatim, line-numbered, Edit-safe); don't re-grep to verify; after edits, watch for the ⚠️ staleness banner and Read only the named files.
- **Freshness in CLI-only mode (pi's mode):** no watcher runs unless the daemon is up. A pi skill should pre-flight `codegraph sync` at session start and after the agent creates/deletes files (query-time drift detection covers mid-session edits to *existing* files by serving current source, but new files won't exist in the index until sync). `codegraph status` is the cheap check ("Pending sync" section).
- **Gate everything on `[ -d .codegraph ]`** in the repo root; unindexed → fall back silently, and *never* run `codegraph init` on the user's behalf (upstream's own rule, enforced in the CLI's error text).
- **Context budget:** their own measurement says explore leaves ~80% more resident context than grep/read churn. Fine on large windows; on long sessions, prefer targeted `node`/`callers` CLI calls when you need one fact, and keep `explore` for flows/surveys.
- **Subagent steerage:** upstream measured that subagents which don't see the MCP guidance almost never reach for the tools (1/9). pi's equivalent risk: skills loaded only by the primary agent won't reach spawned workers — the snippet/skill must be global, not project-local-and-hidden.

## 6. Gaps / risks for our use

- **NixOS packaging is the main wiring risk.** The self-contained bundle ships a prebuilt Node runtime — a dynamically-linked binary that won't run unpatched on NixOS outside nix-ld. Untested here; the npm route (`nodePackages` / a wrapped env / `npx` from a node env) is likely the clean path. Needs a short spike; version churn is fast (v1.6.2 is ~2 weeks old) so wrap the version.
- **No MCP in pi** — fine by design (CLI parity is explicit and the snippet's "Shell (always works)" line exists exactly for us), but we lose the always-on watcher/auto-sync and the initialize-time guidance injection; both must be replaced by skill discipline (§5).
- **CLI-only sessions have no background sync** for newly created files (drift detection covers modified ones); an undisciplined agent can query a stale graph after heavy refactors.
- **Resolution is best-effort name matching**, explore matching is lexical not semantic, and data-flow/locals are a deliberate non-goal ("the def-use frontier"). NixOS *module option wiring* is claimed (config writes link to the `options.*` declaring module) — impressive if it holds on mortlake's flake-parts + import-tree layout (auto-discovery via `import-tree` may or may not produce the `imports = [ ./x.nix ]` shapes it keys on; unvalidated).
- **Residual context occupancy** (~80% higher than grep/read at session end) is a real cost on long sessions; mitigations are the narrow CLI commands and `--max-files`.
- **Telemetry defaults to on** (anonymous counts, asked at install). For mortlake hosts: set `CODEGRAPH_TELEMETRY=0` / `DO_NOT_TRACK=1` in the wrapper.
- **One writer per project** / daemon lock semantics: multiple concurrent agent sessions on one repo should share the daemon or use `CODEGRAPH_NO_DAEMON=1` single-writer mode; SQLite-on-network-share and WSL caveats documented but not our case.
- `.codegraph/` must land in mortlake's `.gitignore` (it's a per-checkout index, not committable state).
- Pre-1.0-style velocity: bench methodology and tool surface have churned within 2026 (single-tool surface is itself a recent consolidation); expect `codegraph upgrade` to matter.

## 7. Recommendation for mortlake wiring + skill authoring

**Wiring (mortlake):**
1. Spike (30 min): get `codegraph` v1.6.2 running on NixOS — prefer the npm package inside a small wrapped env (`buildNpmPackage`-ish or `nodePackages.@colbymchenry/codegraph` + wrapper) over the curl bundle; bake `CODEGRAPH_TELEMETRY=0` into the wrapper. Fallback: bundle + nix-ld.
2. `codegraph init` on mortlake (and hermes repo); add `.codegraph/` to `.gitignore`; run `codegraph status` to sanity-check symbol counts; specifically validate the Nix extraction on flake-parts/`import-tree` shapes — if option wiring works there, "where is `options.services.foo` declared / what writes it" becomes a one-hop query, which is a genuine force multiplier for dendritic-pattern work.
3. Optional: a `codegraph sync` pre-flight in the agent session bootstrap (or a low-frequency timer/cron while repos are being edited), since pi sessions are CLI-only.

**Skill authoring (global pi skill, e.g. `codegraph-code-intelligence`):** distill `src/mcp/server-instructions.ts` + the installer block into CLI-first form:
- Trigger: any codebase-understanding or locate-code task; first step is `[ -d .codegraph ]` check — absent → normal grep/read flow, never self-init, never mention it again.
- Core rule: `codegraph explore "<question|names>"` BEFORE grep/Read; output is verbatim Edit-safe source — treat as already-read; don't re-verify with grep.
- Patterns: flow questions name both endpoints; named file/symbol = current source read; `impact` before nontrivial edits; `callers/callees/query --json` when scripting or when one fact suffices; `affected` for test selection.
- Hygiene: `codegraph sync` at session start and after creating/deleting files; obey ⚠️ banners; unindexed path in a multi-repo session → `-p` or fall back.
- Keep it short (upstream's own lesson: the block is read every turn; they cut duplication deliberately).

**Verdict:** adopt for agent-driven work in indexed repos — the CLI surface makes it pi-compatible today, Nix/Terraform support matches our stack, and the failure modes (unindexed → clean fallback; stale → flagged) are well-designed. The two real costs are the NixOS packaging spike and skill-level sync discipline; neither is structural.
