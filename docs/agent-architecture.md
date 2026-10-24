# Agent Architecture

Confirmed architecture for coding agents, memory, and skills across all hosts.

## Roles

| Agent | Host(s) | Role |
|-------|---------|------|
| **Pi** (pi.dev) | Uriel (primary), Jehoel, Raphael | Primary coding agent. User interacts with Pi directly. herdr multiplexes parallel Pi sessions. |
| **Hermes** | Uriel only | Discord-connected assistant (same as this one). MCP-enabled. |
| **Codex** | Uriel | Secondary, heavy coding only. Skeleton deployment. |

## Memory

There is currently no shared agent-memory server. The previous attempt — a shared Cognee instance on uriel (`cognee.otwell.dev`) — was decommissioned 2026-10-02: it was fully wired at the infra level but never ended up used, and its Nix modules and sops secrets have been deleted.

Current state:

- **Hermes** runs its built-in MEMORY.md/USER.md provider.
- **Pi / prime-agent** have no cross-agent memory backend.
- **Planned successor path for shared memory:** icm + qmd.

## Intelligence Stack (Pi — CLI-first, no MCP)

| Tool | Function | How Pi calls it |
|------|----------|-----------------|
| neuledge/context | Library/framework docs | CLI `context` command |
| codebase-memory-mcp | Codebase graph (symbols, calls, dependencies) | CLI or MCP server (Pi uses CLI) |
| GitMCP | Fallback docs for GitHub repos | CLI |

## Hermes MCP Servers (Uriel only)

Hermes keeps MCP servers that Pi can't use:
- codebase-memory
- context (neuledge)
- exa (web search)
- nixos
- gitmcp

## Skills — Two Parallel Systems

### Canonical shared skills (`~/src/mortlake/skills/`)
- 69 SKILL.md files currently
- **Source of truth for all code agents** — both Pi and Hermes read from here
- Version-controlled in mortlake repo
- Covers: NixOS patterns, debugging, research, SRS, note-taking, autonomous agents, etc.
- Both Pi and Hermes configured to load skills from this directory

### Hermes self-managed skills (`~/.hermes/skills/`)
- Hermes' native skill system — editable by Hermes at runtime (I can create/patch/delete these)
- Runs **in parallel** to the canonical skills
- For Hermes-specific operational skills that don't apply to Pi (Hermes tool workflows, platform-specific behaviors)
- Not shared with Pi

### Pi skills/extensions
- All Pi settings, skills, and extensions live in `~/src/mortlake/`
- Pi skills directory: `.pi/skills/` (project-local, read from mortlake)
- Pi prompts: `.pi/prompts/` (slash commands)
- Pi extensions: installed via `pi install`, configured in mortlake-managed config

## Pi Config in Mortlake

Pi needs a NixOS module (`modules/features/pi-agent.nix` or similar) that:
- Installs Pi CLI (pi.dev npm package or equivalent)
- Points Pi's config/skills/extensions at mortlake paths
- Configures herdr integration (lifecycle hooks)
- Persists Pi state directories (sessions, caches)
- Shares the `mortlake/skills/` directory with Hermes

## What Needs Updating in PLAN.md

1. **Add `pi-agent.nix` module** — Not currently in PLAN.md. Needs to be in Phase 3 or 4 (package/tooling tier).
2. **Skills config** — Ensure Hermes module's `skills.config.external_dirs` includes `~/src/mortlake/skills/`. Pi module points at the same directory.
