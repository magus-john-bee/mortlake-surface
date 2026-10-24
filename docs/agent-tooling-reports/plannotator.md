# Plannotator + plannotator-tui — usage research for agent wiring

Task: AT-N055 · 2026-10-19 · Sources: github.com/backnotprop/plannotator (main, MIT/Apache-2), github.com/plannotator/plannotator-tui (v0.9.4, 2026-09-25, MIT), docs.plannotator.ai (serves llms.txt).

## 1. What it is

**Plannotator** (backnotprop/plannotator) is a local browser-based review surface for AI coding agents (Claude Code, Codex, Copilot CLI, Gemini CLI, OpenCode, Kiro, Droid, Amp, **Pi**). It intercepts agent plans through host hooks, opens them in a browser annotation UI, and returns the human's approve/deny-with-annotations decision to the agent. It also does code review (git/jj/GitButler/p4 diffs, GitHub/GitLab PRs) and annotation of arbitrary markdown/HTML/URLs/folders. Single `plannotator` binary (Bun-compiled), data local under `~/.plannotator`.

**plannotator-tui** (plannotator/plannotator-tui) is the terminal-only sibling: a single static Rust binary (ratatui) that renders a Markdown file or folder in the terminal, lets you select text and mark it 💬 comment / 👍 looks good / ✗ delete, then hands the review to a coding agent as **numbered feedback** — via clipboard (OSC 52), via a Herdr pane (delivered as the agent's next user message), or headless via stdout. Annotations persist in the shared Plannotator data dir in the "Workspaces" wire JSON, so terminal and browser reviews compound. `last` mode reads agent transcripts directly (Claude Code, Codex, pi, Oh My Pi, Copilot, Droid, **Hermes CLI**, OpenCode).

## 2. Install/config prerequisites

**Main app (browser flows):**
```bash
curl -fsSL https://plannotator.ai/install.sh | bash      # binary → ~/.local/bin + per-agent hooks/skills
# --minimal → binary only, no hooks/skills; --version vX.Y.Z pins
plannotator uninstall [--purge]                           # removal
```
For **Pi specifically** the installer is not needed: `pi install npm:@plannotator/pi-extension` (requires Pi ≥ 0.79.1). Update: `pi update --extensions`. Plan mode: `pi --plan`, `/plannotator-plan-mode`, or `Ctrl+Alt+P`.

Config layers (main app): env vars > `~/.plannotator/config.json` > UI cookies. Key env: `PLANNOTATOR_DATA_DIR` (default `~/.plannotator`; XDG fallback), `PLANNOTATOR_REMOTE`/`PLANNOTATOR_PORT` (SSH mode, fixed port 19432), `PLANNOTATOR_BROWSER=none` (no browser, URL printed to stderr — useful headless), `PLANNOTATOR_AGENT_TOOL=1` (enables the `plannotator` tool for pi; off by default because it costs ~780 tokens/request; on by default in Oh My Pi), `PLANNOTATOR_ORIGIN=pi` (override agent detection from wrappers).

Pi extension phase config: `~/.pi/agent/plannotator.json` (global) and `<cwd>/.pi/plannotator.json` (project) overriding a built-in base — controls per-phase model/thinking/activeTools/instructions (`${planFilePath}`, `${todoList}`) for planning/executing phases, and `executionMode: "external"` which emits a `plannotator:plan-approved` event instead of executing in-session. Pi 0.79+ project-trust prompts apply to `.pi/plannotator.json`.

**TUI:** `brew trust plannotator/tap && brew install plannotator/tap/plannotator-tui`, or `cargo install plannotator-tui`, or prebuilt release binaries (macOS/Linux/Windows + SHA256SUMS). No config required; optional `~/.config/plannotator-tui/config.toml` (`[herdr] placement`, `[ui] theme`); `plannotator-tui config` prints effective values; `PLANNOTATOR_DATA_DIR` and `PLANNOTATOR_TUI_THEME`/`PLANNOTATOR_TUI_PLACEMENT` env overrides. Herdr bundle: `herdr plugin install plannotator/herdr-annotate`.

No API keys are needed for core use (all local). Optional: `JINA_API_KEY` (URL annotation rate limits), `PLANNOTATOR_BITBUCKET_TOKEN` (Bitbucket PRs), AI providers for Ask AI.

## 3. Core commands an agent actually uses

**Main CLI** (from the shipped `plannotator` knowledge skill — stdout is the interface; session blocks until the human decides, so use long/no timeout or background):

```bash
plannotator annotate docs/plan.md --gate --json            # gated review of a plan/spec FILE
plannotator annotate spec.md mock.html notes.md            # multi-file → one review, one decision
plannotator annotate docs/                                 # folder browser
plannotator annotate report.md --gate --json --require-approval --result-file /tmp/decision.json
#   exit 0 = approved (only success), 1 = not approved (record still written), 2 = gate failure
plannotator review [--base <ref>] [DIR | PR_URL]           # local diff / PR review; jj+p4 auto-detected
plannotator review --patch-file reading.diff               # static diff, no repo needed
plannotator last / annotate-last --stdin                   # annotate own last message
plannotator sessions [--open 1]                            # list/reopen live sessions
plannotator archive                                        # read-only browser of past decisions
plannotator <cmd> --help                                   # usage without launching anything
```
- Plaintext stdout: empty on close, "The user approved." on approve, else the feedback text. `--json`: `{decision: approved|annotated|dismissed, feedback}`. Never run bare `plannotator` (that's the hook entry, expects hook JSON on stdin).
- **Pi tool path** (when `PLANNOTATOR_AGENT_TOOL=1`): agent calls the `plannotator` tool with `{action: "annotate", target: "notes.md", gate: true}` — returns at once with a session id (`pn-3f2a9c`); the agent ends its turn and the decision arrives later as a message starting `Plannotator: notes.md (pn-3f2a9c) — Feedback · 2 comments.` Also `list`/`close` actions. Plan submission in pi plan mode goes through the injected `plannotator_submit_plan` tool.
- **Question blocks** embed decision points in the reviewed doc: `:::question` / `:::question-multi` / `:::question-text` with `- [ ]` choices and a `Recommended:` line; answers come back at the top of the feedback.
- **External Annotations API**: any script can POST annotations into a live session — `curl -X POST http://localhost:PORT/api/external-annotations -d '{"source":"my-tool","type":"COMMENT","originalText":"…","text":"…"}'` (SSE broadcast; code-review shape uses `filePath`/`lineStart`/`lineEnd`).

**TUI:**
```bash
plannotator-tui docs/plan.md          # one file
plannotator-tui docs                  # folder: file tree, per-file note counts
plannotator-tui last [--newest]       # picker over the parent agent's recent replies (--host/--pid/--session override)
# headless / agent-facing:
plannotator-tui --export docs/plan.md                       # all active notes → stdout (nothing marked sent)
plannotator-tui --annotate docs/plan.md "quoted text" "comment body" [comment|looks_good|delete] [--occurrence N]
plannotator-tui --annotate-block docs/plan.md 12 "note on block 12"
plannotator-tui --snapshot docs/plan.md                    # one rendered frame as text
# herdr integration:
plannotator-tui herdr open docs/plans/auth.md              # opens beside the agent pane; feedback → that pane
plannotator-tui herdr last --newest
plannotator-tui herdr terminal [--lines N] [--print]
```
Keys (essence): mouse-drag or `v`+hjkl to select → `a` looks good / `c` comment / `d` delete; `E` send new annotations (clipboard, or Herdr pane delivery with `S` = send+close); file/folder reviews have `R` resend all, `F` finish/archive, `H` archive browser; `q` quit. Feedback format is numbered markdown:

```
# Annotations on docs/plans/auth.md
## Annotation 1 (line 12)
Comment on: "Rotate the token on every…"
> Rotation on every privilege change will log people out…
```

## 4. Skills/AGENTS the projects themselves ship

**Main repo** (`apps/skills/`, agentskills.io format; core ones installed to `~/.claude/skills` + `~/.agents/skills`):
- `apps/skills/core/plannotator/SKILL.md` — the knowledge layer: full CLI reference (choose-the-command table, session model, exit codes, `:::question` authoring guide, env vars, external-annotations contract, Inbox usage). Rule of the skill: "If you have a `plannotator` tool, always use it" and "Never run bare `plannotator` yourself."
- `apps/skills/core/plannotator-review|plannotator-annotate|plannotator-last/SKILL.md` — thin launchers for the three common actions (+ `agents/openai.yaml` frontiers).
- `apps/skills/extra/` — `plannotator-compound` (map-reduce research over denied plans), `plannotator-setup-goal`, `plannotator-visual-explainer` (HTML plan/diagram generators). Not default-installed.
- Root `AGENTS.md` — monorepo engineering map (Bun server vs Pi `node:http` server parity rule, project structure, env vars).
- `.agents/skills/{release,review-renovate,update-deps}/` — repo-maintenance skills, not user-facing.
- Host glue: `apps/pi-extension/README.md` (406 lines — the deep pi integration doc), `apps/copilot/commands/*.md`, `apps/gemini/commands/*.toml`, `apps/kiro-cli/skills/*`.

**TUI repo:**
- `skills/plannotator-tui/SKILL.md` — the agent contract (quoted in full essence): only inside Herdr (`HERDR_ENV=1`); **write the document to a file, don't paste it in chat**; run `plannotator-tui herdr open docs/plans/auth.md`; **end your turn** — "Do not wait, poll, or read the pane"; feedback arrives as the next user message as numbered annotations; "Address every item, then continue." Also prints files as OSC 8 `file://` hyperlinks so Ctrl-click opens them in the TUI. Includes the raw `herdr plugin pane open …` fallback with `PLANNOTATOR_TUI_DELIVER_TO="$HERDR_PANE_ID"`.
- `AGENTS.md` — engineering rules (schema crate purity, Workspaces wire shape as data contract, lints).
- `herdr/herdr-plugin.toml` — plugin manifest: `open`/`last`/`terminal` actions, `file://*.md` link handler.
- `docs/decisions.md` — design record (host detection rules = Plannotator's `last` implementation).

**Annotation storage contract** (both tools, shared): `~/.plannotator/clients/plannotator-tui/annotations/<project>/<slug>/annotations.json` where `<project>` = git repo name and `<slug>` = basename + 8 hex of sha256 of the path. JSON is the Workspaces wire shape (`Annotation{id, document_id, anchor{block_id, start_offset, end_offset, original_text, …}, body, author, state: open|resolved, replies[], …}`; body capped 8 KiB). "Any agent can read it" — this is the file protocol for machine consumption. Feedback history: every successful send also appends to `{data_dir}/feedback/<project>/index.jsonl` + Markdown under `records/`.

## 5. How to prepare an agent to use it well

- **Make plans plannotator-friendly = make them a file.** Write plans/specs as Markdown on disk (stable path, under 2 MB/file), with `- [ ]` checklists for steps; don't dump the plan into chat. In pi plan mode the agent writes the plan file anywhere in the cwd and calls `plannotator_submit_plan` with the path — the browser review opens automatically; iterate until approved; on resubmission a Plan Diff shows what changed.
- **Feedback handling**: returned feedback is numbered, each item anchored to a quoted selection with a line number. The agent's job is to address every item in the same conversation, then continue (TUI skill wording: "Address every item, then continue."). Approval-with-notes = guidance, not change requests; classify outcome only by `decision`, never by parsing message text.
- **Blocking semantics**: CLI sessions block until the human decides (can be an hour+ on a big PR). Launch with long/no timeout or in background; killing the process = no feedback. Pi tool path is non-blocking: call the tool, end turn, decision arrives as a later message.
- **Questions, not monologues**: embed `:::question` blocks with context lines, 2–4 terse choices with reasons, and a `Recommended:` line; ~8 max per round; `- [x]` marks settled; on resubmit either check the chosen answer or drop the block and state the decision in prose.
- **openspec/spec-kit fit** (their own docs say it): spec-driven frameworks emit `spec.md`/`plan.md`/`tasks.md` per change; wire a PostToolUse(Write) hook with `plannotator annotate <path> --gate --json` so each artifact gets a human gate before the agent builds from it. Folder review (`plannotator annotate openspec/changes/<id>/` or `plannotator-tui openspec/`) covers a whole change's artifacts in one review.
- **Self-annotation is possible**: `plannotator-tui --annotate file.md "quote" "I'm unsure about X" comment` lets an agent pre-flag its own weak points before handing the file over; `--export` reads back all active notes headlessly.
- Gotchas: don't print a preamble right before `last`/`annotate-last` (it targets the latest rendered message, so your preamble becomes the annotated text); `.env` files are deliberately refused by annotate; don't tell the user they can "approve" a plain (non-`--gate`) annotate session; source code belongs to `review`, not `annotate`.

## 6. Gaps/risks for our use

- **No file-watch delivery for the TUI**: outside Herdr, TUI feedback reaches the agent only via clipboard paste (human action) or headless `--export`. There's no daemon the agent can poll except the annotations.json file itself (which *is* stable and documented — a workable protocol, but you write the glue).
- **NixOS install**: main binary comes from a curl|bash installer (Bun-compiled executable into `~/.local/bin`) — untested posture on NixOS, no nixpkgs package, no flake in either repo. TUI prebuilt Linux binaries are gnu-linked (need nix-ld or patchelf on NixOS); `cargo install plannotator-tui` or a mortlake `buildRustPackage` wrapper is the clean path (v0.9.4, crates.io).
- **pi extension token cost**: the `plannotator` tool is off by default on pi for a reason (~780 tokens with every request). Slash commands + plan mode work without it; enable the tool only if the open-list-close flow is worth the tokens.
- **Browser dependency**: the main app's value is the browser UI; on a headless mortlake host or over SSH you need `PLANNOTATOR_REMOTE=1` + port forward, or Tailscale serve (`--tailscale`), or just use the TUI.
- **Phone-home**: no telemetry, but each app surface checks GitHub for the latest release on load with no opt-out; git reviews may `git ls-remote` the origin (opt-out: `PLANNOTATOR_GIT_REMOTE_CHECK=0`).
- **Network-feature sprawl**: Jina Reader for URLs, share links, paste service, Workspaces (hosted) — fine to leave off; `PLANNOTATOR_SHARE=disabled` if paranoid.
- **Hermes host support in the TUI reads `~/.hermes/state.db` (SQLite, sessions/messages schema, read-only)** — if our Hermes matches that layout, `plannotator-tui last` works against Hermes sessions natively (session id via Herdr's `agent_session`); otherwise it silently isn't a host. Worth one test.
- Version churn is fast (main repo releases ~monthly; TUI at 0.9.x with skills still marked "Draft; not yet wired into an installer").

## 7. Recommendation for mortlake wiring + skill authoring

1. **Two-tool split**: treat the TUI as the default review surface for terminal work (static binary, no browser, NixOS-friendly via cargo/buildRustPackage, Hermes/pi transcript support), and the main app as the heavyweight for plan-mode gating and code review where a browser exists (jehoel has one; mortlake mostly doesn't).
2. **Mortlake packaging**: package `plannotator-tui` as a small flake package (`cargo build --release` from the 0.9.4 tag, or `pkgs.rustPlatform.buildRustPackage`); leave the main `plannotator` binary as an optional home-manager/`~/.local/bin` install on jehoel only, since the curl installer and Bun runtime are a poor fit for mortlake hosts.
3. **Skill authoring** (feeds AT-XMVW): author a `plannotator` skill in our library modeled on their shipped ones, adapted to our stack: (a) plans/specs go to a file under `openspec/changes/<id>/` or `docs/plans/`, never pasted in chat; (b) for review, call `plannotator-tui --export` on the file if notes already exist, else surface the file path (OSC 8 hyperlink) and stop; (c) feedback arrives as `# Annotations on <path>` numbered blocks — address every item, then continue; (d) `:::question` blocks for decisions; (e) the shared annotations.json path as the machine-readable side channel. Quote their TUI SKILL.md's "end your turn; do not wait, poll, or read the pane" rule verbatim — it's the core contract.
4. **AGENTS.md line items** (for the rewrite): "When you produce a plan or spec for review: write it to `<path>`, offer it via plannotator (TUI or browser), end your turn, and treat returned numbered annotations as the work queue." Plus the pi plan-mode note (`pi --plan` / `plannotator_submit_plan` / `executionMode: external` handoff event if aven or another orchestrator should own execution).
5. **Skip/defer**: Inbox, share portals, guided reviews, Workspaces — hosted/product surfaces; Obsidian/Bear plan saving could matter later given the sb.otwell.dev vault, but isn't load-bearing now.

—
Report: /tmp/agent-reports/plannotator.md · Sources: both READMEs, pi-extension README, external-annotations-api.md, core skill SKILL.md ×4, TUI SKILL.md + herdr-plugin.toml + schema crate, docs.plannotator.ai/llms.txt, hook-integration/annotate-gates guides, v0.9.4 release assets.
