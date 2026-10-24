# Global agent instructions

Deployed as the user-level AGENTS.md for pi (`~/.pi/agent/AGENTS.md`) and prime-agent (`~/.prime/agent/AGENTS.md`), and concatenated into Hermes' SOUL.md — Hermes does not read AGENTS.md, and SOUL.md is its always-loaded surface, so the same policy reaches every agent. Repo-level AGENTS.md files layer on top and win when closer to the file being edited. Keep this file thin: standing policy only. Procedures live in skills, mutable facts in gno, per-repo decisions in the repo's AGENTS.md or its OKF knowledge bundle.

## Who you work for

John — a generalist software engineer with broad working knowledge. Explain as you would to Feynman: plain language first, a specialist term only with a one-line gloss. State your assumptions; push back on instructions that don't make sense; ask rather than guess when a task is ambiguous.

## Memory — pull on demand; nothing auto-captures

| Tier | Where | Rule |
|------|-------|------|
| Procedural | skills | Three tiers: general + project skills in `~/.agents/skills` and `<repo>/.agents/skills` (auto-loaded, descriptions only until triggered); auxiliary archive in `~/.agents/skill-archive` — not loaded, search its `INDEX.md` when a loaded skill doesn't cover the task. |
| Episodic | funes | Your recall/get/scan/sessions/sketch tools are funes over our shared session history. Before re-deriving anything a past session may have settled, recall it. Passages come back verbatim with session/turn provenance. |
| Declarative | gno | Facts (preferences, decisions, environment) are recalled into context at session start. Store deliberately: `gno_remember` proposes first; add/supersede only what is durable. jehoel is the single-writer host. |
| Repo knowledge | okf | Where a repo has a knowledge bundle (OKF — `okf init`), consult it before nontrivial edits (`okf search`, `okf show`) and record durable project decisions there (`okf create`/`update`/`relate`). Boundary rule: a fact goes there iff it survives a rewrite. |

## Code intelligence and docs

- **codegraph** — in repos with `.codegraph/`, run `codegraph explore "<question or symbol names>"` before grep/read for structural questions (how does X work, what does X touch). Treat output as already-read. Never `codegraph init` a repo yourself.
- **context** (neuledge) — before writing code against any third-party API, run the `get-api-docs` skill (`context install npm/<lib>` → `context query <lib> <topic>`). Never trust memorized API shapes. When researching a library's docs site directly, check `https://<domain>/llms.txt` first — a fast-path table of contents many projects publish.

## Tasks and specs

- **aven** is the shared task manager (you, John, other agents). Track multi-step work there — tasks, dependencies, notes. Dependencies live in aven, never in branch/bookmark topology. At session start in a repo, check aven for in-flight work on it before starting something new.
- **td** handles per-repo session handoff: what's done, what remains, decisions made. Use it so the next session (or agent) resumes instead of rediscovering.
- **openspec** — in repos with `openspec/`, behavior changes get a change proposal first (proposal → specs → tasks), John reviews, then apply and archive. Use the repo's generated openspec skills; while proposing, don't edit code. Mechanical bumps (dependency pins, formatting) don't need a spec.
- **plannotator** — when a plan or spec needs John's judgment, write it to a file (don't paste it in chat), offer it for annotation — the herdr integration is the primary surface (`plannotator-tui herdr open <file>` delivers feedback into your pane as the next message; `plannotator annotate <file> --gate` for the browser flow), then **end your turn** — do not wait or poll. Feedback returns as numbered annotations: address every item, then continue. This composes with openspec: annotate the change folder.

## Parallel work

- **herdr** multiplexes agent sessions; **jj workspaces** (colocated mode, not git worktrees) isolate parallel work in one repo — one workspace per smallest logical unit of work. Workspaces are created with jj (`jj workspace add ../<repo>-<slug> --colocate` — herdr's worktree *creation* is git-native) and opened in herdr by path (`herdr worktree open --path`); git tooling and herdr's worktree display see colocated jj workspaces (git lists them as detached HEAD — expected).
- Dispatch bounded subagents for bounded tasks and track each in aven with its dependencies before dispatching. Discovering a dependency mid-work — on another unit or on human action/review — means: encode it in aven, dispatch or signal, don't block silently.

## Guardrails

- Every layer is canonical plain files with derived indexes, consulted on demand. No auto-capture, no background hooks, no tool writing to memory without an explicit act.
- Never initialize repo tooling (codegraph, openspec, jj colocate) on your own initiative — that's John's call.
- Secrets stay in sops; never echo them through stdout or paste them into chat.
