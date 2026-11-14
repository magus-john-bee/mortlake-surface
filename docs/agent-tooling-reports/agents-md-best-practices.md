# AGENTS.md and Skill Authoring Best Practices — Reference Report

Task: AT-M4AB (blocks AT-XMVW "Rewrite global-agents.md into polished AGENTS.md + SOUL.md content + skill extraction plan")
Date: 2026-10-19

## 1. What it is

Two complementary open standards define how coding agents receive standing
instructions and on-demand expertise: **AGENTS.md** (agents.md, stewarded by the
Agentic AI Foundation under the Linux Foundation; emerged from OpenAI Codex,
Amp, Google Jules, Cursor, Factory; 60k+ examples on GitHub) is a plain-Markdown
convention for repository/user instruction files that agents read before doing
any work, with nearest-file-wins precedence. **Agent Skills**
(agentskills.io, Anthropic-originated, also in `anthropics/skills` repo as
`./spec`) is a folder format — `SKILL.md` with YAML frontmatter plus optional
`scripts/`, `references/`, `assets/` — built entirely around *progressive
disclosure*: only `name` + `description` sit in the system prompt at startup;
the body loads when a task matches; bundled files load only when referenced.
Pi implements both: AGENTS.md/CLAUDE.md context files and the Agent Skills
spec (pi `docs/skills.md`, `docs/configuration.md`).

## 2. Install/config prerequisites

No keys, no services. What each consumer needs:

- **AGENTS.md**: just a file. Pi loads `<agent-dir>/AGENTS.md` (or
  `AGENTS.override.md` / `CLAUDE.md`; agent dir defaults to `~/.pi/agent`,
  override with `PI_CODING_AGENT_DIR`) plus context files from the working
  directory and its parents. Codex reads `~/.codex/AGENTS.md` (or
  `AGENTS.override.md`), then walks project root → cwd, one file per directory,
  concatenating root-down so closer files override; combined cap
  `project_doc_max_bytes` = 32 KiB default; alternate filenames via
  `project_doc_fallback_filenames` in `~/.codex/config.toml`.
  (developers.openai.com/codex/guides/agents-md)
- **Skills (pi)**: drop a `SKILL.md`-containing directory into
  `~/.agents/skills/` (user), `.agents/skills/` (project, discovered from cwd
  through ancestors, stopping at repo root), `<agent-dir>/skills/`, or
  `.pi/skills/`. Discovery is recursive over directories containing
  `SKILL.md`. No registration step.
- **Validation**: `skills-ref validate ./my-skill` from the agentskills
  reference library checks frontmatter/naming. Pi: run from a discoverable
  location and check startup diagnostics; `/reload` after edits; `/skill:name`
  to force-load.

## 3. Core commands an agent actually uses

There is no CLI for AGENTS.md — the agent's "use" of it is reading it before
work. For skills, the operative mechanics (pi):

```text
/skill:pdf-tools                          # force-load a skill the model didn't auto-trigger
/skill:pdf-tools extract report.pdf       # force-load + append an argument as a user request
/reload                                   # re-scan after editing a skill mid-session
```

Codex verification patterns (adaptable to pi as plain prompts):

```bash
codex --ask-for-approval never "Summarize the current instructions."   # audit what loaded
codex --cd services/payments "List the instruction sources you loaded."
```

Skill-authoring loop (agentskills.io quickstart/best-practices + skill-creator):
draft `SKILL.md` → write ~20 trigger eval queries (8-10 should-trigger,
8-10 near-miss should-not-trigger) in `evals/evals.json` → run each 3×, measure
trigger rate (pass > 0.5) → revise description → keep a 60/40 train/validation
split to avoid overfitting → `skills-ref validate`.

## 4. Skills/AGENTS snippets the projects themselves ship

- `anthropics/skills` — reference implementation repo:
  - `skills/skill-creator/SKILL.md` — the meta-skill for authoring skills.
    Key shipped guidance, verbatim points: three-level progressive disclosure
    ("Metadata (name + description) — always in context (~100 words); SKILL.md
    body — in context whenever skill triggers (<500 lines ideal); Bundled
    resources — as needed"); "Keep SKILL.md under 500 lines; if approaching
    this limit, add an additional layer of hierarchy along with clear pointers
    about where the model should go next"; "For large reference files (>300
    lines), include a table of contents"; descriptions should be "a little bit
    pushy" — "...use this skill whenever the user mentions dashboards... even
    if they don't explicitly ask for a 'dashboard'" (counteracts observed
    under-triggering); prefer imperative form; "explain to the model why things
    are important in lieu of heavy-handed musty MUSTs"; evals in
    `evals/evals.json`.
  - `template/SKILL.md` — minimal two-field skeleton (`name`,
    `description` only).
  - `./spec` — Agent Skills spec; `skills/docx|pdf|pptx|xlsx` — production
    document skills (source-available) demonstrating complex script bundling.
- `openai/codex` — `docs/agents_md.md` and `docs/skills.md` are stubs pointing
  at developers.openai.com/codex/guides/agents-md (the real guidance, fetched
  above: discovery chain, override files, 32 KiB cap, `## Code Review Rules`
  section convention — "Keep rules concise, explain the behavior to flag and
  any safe path or exception, and reserve formatting and lint checks for CI").
- agents.md sample AGENTS.md (on site): three short sections — "Dev
  environment tips" (exact commands: `pnpm dlx turbo run where <project>`,
  `pnpm install --filter`), "Testing instructions" (exact test/lint commands +
  "The commit should pass all tests before you merge"), "PR instructions"
  (title format + pre-commit gates). Note the pattern: every line is either an
  exact command or an exact policy; zero prose explanation.
- agentskills.io ships its own llms.txt doc index (`/llms.txt`, append `.md` to
  any page URL) — worth imitating for mortlake doc surfaces.

## 5. How to prepare an agent to use it well

### What belongs in AGENTS.md (always-in-context, keep tight)

- Exact build/test/lint/deploy commands, exact PR/commit conventions,
  hard safety rails ("never deploy without X"), repo map pointers,
  environment gotchas that apply to *every* task in that tree.
- agents.md FAQ: no required fields, plain Markdown, living documentation;
  conflict resolution = "closest AGENTS.md to the edited file wins; explicit
  user chat prompts override everything." Nested AGENTS.md per package for
  monorepos (openai/codex itself has ~88).
- Codex bounds the whole chain at 32 KiB — treat ~1-2 pages per file as the
  real budget; anything task-shaped is context-window theft on every session.

### What belongs in a skill (loaded only on trigger)

- Anything procedural, domain-specific, or longer than a few lines:
  workflows, tool APIs, runbook patterns, output templates, bundled scripts.
- Skill-quality rules (agentskills.io best-practices + spec):
  - **Description = the whole routing mechanism.** Both *what it does* and
    *when to use it*, imperative, keyword-rich, "even if they don't explicitly
    mention X"; ≤1024 chars. Bad: "Helps with PDFs." Good: "Extracts text and
    tables from PDF files... Use when working with PDF documents or when the
    user mentions PDFs, forms, or document extraction."
  - **Progressive disclosure budget**: SKILL.md body <500 lines / <5000 tokens;
    metadata ~100 tokens; heavy material in `references/` (with a ToC if
    >300 lines) referenced one level deep, each reference told *when* to load
    it ("Read references/api-errors.md if the API returns non-200") — a
    conditional pointer beats a generic "see references/".
  - **Add what the agent lacks, omit what it knows** — cut anything where the
    answer to "would the agent get this wrong without this?" is no.
  - **Gotchas sections are the highest-value content** — concrete corrections
    of assumptions (the `users.deleted_at` soft-delete, the `user_id`/`uid`/
    `accountId` triple-naming example). Add a gotcha every time you correct
    the agent.
  - **Provide defaults, not menus**; be prescriptive only where fragile
    ("Run exactly this sequence... Do not modify the command"); favor
    reusable procedures over instance-specific answers.
  - Patterns that ship: checklists for multi-step work, validation loops
    (edit → `scripts/validate.py` → fix → repeat), plan-validate-execute for
    destructive ops, output templates (agents pattern-match concrete
    structures far better than prose descriptions of format).
  - **Skills are grounded in real expertise** — extract from a hands-on
    session or synthesize from runbooks/incident history; generic
    LLM-generated skills are the named pitfall. Then "refine with real
    execution": read traces, not just outputs.

### What belongs in memory (gno) instead

Neither file is for *facts that change* — host state, credentials, decisions,
preferences. AGENTS.md is instructions ("how to work here"); skills are
procedures ("how to do X"); memory is state ("what was decided/what exists").
A fact in AGENTS.md rots silently and burns context in every session; a
workflow in memory is invisible until recalled. Split test: standing
instruction → AGENTS.md; task-shaped procedure → skill; mutable fact/decision
→ gno.

## 6. Gaps/risks for our use

- **Spec is young and soft**: agentskills.io `allowed-tools` is explicitly
  experimental; pi warns on invalid fields rather than rejecting them;
  name/dirname matching is enforced by the spec but not by pi — portability
  discipline is on us.
- **Under-triggering is the documented failure mode** (Anthropic: "Claude has
  a tendency to undertrigger skills"). pi's mitigation is manual
  `/skill:name`; pi also warns "a model might fail to load a relevant skill."
  Critical procedures that MUST run should not rely on auto-triggering —
  either force via `/skill:name`, reference them from AGENTS.md by name, or
  keep them in AGENTS.md.
- **Trigger quality is unmeasured until you eval it** — the eval-loop
  methodology (20 queries, 3 runs, train/validation split) is real work per
  skill; budget it only for skills where a miss is costly. The mortlake
  three-tier library (skill-crafting skill) already encodes tiering +
  markdownlint gate + SkillOpt tempering; this report's description-eval loop
  is the piece to fold into that.
- **Prompt-injection surface**: skills and AGENTS.md are executable
  instructions; Anthropic explicitly warns to audit skills from untrusted
  sources (bundled scripts, network calls). Project `.agents/skills/` in pi
  loads without trust gating — pin down which repos may ship project skills.
- **AGENTS.md sprawl**: 32 KiB Codex cap is a hard truncation, silent from
  the agent's perspective; pi has no documented equivalent cap but the
  context cost is per-session regardless. Multiple nested files compose
  root-down; a global file + repo file + package file can stack
  contradictions (nearest-wins is per-implementer, not guaranteed
  cross-tool).
- **Cross-tool variance**: Codex supports `AGENTS.override.md`, fallback
  filenames, `--cd` scoping; pi supports `AGENTS.override.md` same-directory
  replacement and CLAUDE.md aliases; Claude Code historically keys off
  CLAUDE.md. Portable core = plain `AGENTS.md`, no exotic features.

## 7. Recommendation for mortlake wiring + skill authoring

**Wiring (feeds AT-XMVW):**

1. Keep three strictly-scoped layers, mirroring the standards' own structure:
   - `<agent-dir>/AGENTS.md` (pi user level, replaces today's global-agents.md
     growth): who the user is, working agreements, cross-repo conventions,
     pointers to skills — target ~1 page. SOUL.md content (persona/values)
     belongs in pi's `APPEND_SYSTEM.md`, *not* AGENTS.md: it is system-prompt
     material, not repo instructions, and pi gives it a dedicated file.
   - Repo-root `AGENTS.md` in mortlake: exact just/`nixos-rebuild`/lint
     commands, PR/staging-promotion rules, dendritic-pattern pointers,
     hard rails. Nested per-host or per-service AGENTS.md only when a subtree
     genuinely diverges (the monorepo pattern).
   - `AGENTS.override.md` reserved for temporary experiments, per Codex's own
     usage; delete when done.
2. Extraction plan for AT-XMVW: run the "would the agent get this wrong
   without it?" test over global-agents.md content. Standing universal rules
   → trimmed AGENTS.md. Task-shaped procedure (dendritic debugging, sops
   workflow, deploy drill, …) → one skill each, with the existing corpus
   skills as the tier-1 home and the archive for tier 2. Mutable facts →
   gno, not markdown.
3. Adopt the spec's numbers as review gates: description ≤1024 chars with
   what+when+pushy phrasing; body <500 lines; references >300 lines get a
   ToC; every reference has a conditional load trigger. Fold the 20-query
   trigger eval into the skill-crafting gate for tier-1 candidates.

**Authoring:** for each extracted skill, follow the anthropics/skills
`template/SKILL.md` skeleton, frontmatter `name`+`description` only (name =
directory name), gotchas section first-class, defaults-not-menus, scripts in
`scripts/` for anything deterministic (per Anthropic: code over
token-generation for deterministic ops), evals in `evals/evals.json`. Steal
structural patterns from `anthropics/skills/skills/skill-creator/SKILL.md`
directly — it is the canonical worked example.

**Sources:** agents.md (site incl. FAQ + sample); developers.openai.com/codex/guides/agents-md.md;
agentskills.io/specification.md, /skill-creation/best-practices.md,
/skill-creation/optimizing-descriptions.md, /llms.txt;
github.com/anthropics/skills (README, skills/skill-creator/SKILL.md,
template/SKILL.md); anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills;
pi docs: skills.md, configuration.md (local,
/nix/store/wxhdhlgzfl4iabzxl1kxhwiyykn40ckx-pi-coding-agent-1.2.0/lib/node_modules/pi-monorepo/docs/).
