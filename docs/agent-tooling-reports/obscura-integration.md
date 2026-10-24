# Obscura wiring: skill verification + hermes integration — AT-1QM5

Date: 2026-10-19. Live checks on jehoel against installed `obscura 0.2.2`
(`/run/current-system/sw/bin/obscura`, the mortlake flake wrapper over nixpkgs
`pkgs.obscura` 0.2.2). Upstream data fetched from GitHub (h4ckf0r0day/obscura,
NousResearch/hermes-agent, SGavrl/hermes-plugin-obscura, NixOS/nixpkgs) on
2026-10-19. Binary side (`modules/features/obscura.nix`, wrapper with
`OBSCURA_ALLOW_PRIVATE_NETWORK:=1` default) was already done and is unchanged.

---

## 1. What obscura is (context, one paragraph)

Rust headless browser for agents (h4ckf0r0day/obscura, Apache-2.0, independent
of Lightpanda): real V8 JS, CDP-compatible (`serve`), one-shot CLI (`fetch`,
`scrape`), and a built-in MCP server (`obscura mcp`) exposing ~37 browser tools
over stdio or HTTP. nixpkgs packages it with `render` + `stealth` features on
(verified in `pkgs/by-name/ob/obscura/package.nix`), so screenshots, PDF, and
`--stealth` all work in our build.

## 2. Skill verification — `skills/obscura/SKILL.md` vs installed 0.2.2

Verified 2026-10-19 by running `obscura --help`, `<subcmd> --help` for all four
subcommands, and a live MCP stdio handshake against the installed wrapper.

**Accurate (no change needed):**
- Command surface: `fetch`, `scrape`, `serve`, `mcp` — all present.
- `fetch`: `--dump` values exactly `html|text|links|markdown|original|assets|cookies`
  with the documented semantics (original = raw binary-safe body; assets =
  JSON-lines sub-resource URLs; cookies = jar incl. HttpOnly); `--wait` adaptive
  5s cap default, explicit value = fixed delay; `--wait-until` default `load`;
  `--timeout` default 30; `--selector`; `-e/--eval`; `--file` batch = raw fetch +
  one JSON status line per URL; `--concurrency` batch-only (default 1);
  `-s/--screenshot` (render feature — on in nixpkgs); `-o/--output`.
- `scrape`: `--format` default `json`, `-e/--eval`, `--concurrency` default 10.
- `serve`: `--host` default 127.0.0.1, `--port` default 9222, `--workers`
  default 1, `--max-connections` default 128 with 503-refuse (not queue),
  `--allow-file-access` off by default.
- `mcp`: `--http`, `--host` default 127.0.0.1, `--port` default 3000.
- `--proxy`, `--stealth`, `--obey-robots` (fetch+scrape only), and
  `--allow-private-network` are global as described.
- Playwright `connectOverCDP` example and the DuckDuckGo-over-Google note: fine.

**Drift found (2 items, both minor):**
1. **`--user-agent` is NOT on `scrape` in 0.2.2.** The skill's global-flags line
   says `--proxy, --user-agent, --stealth, --obey-robots, --allow-private-network`
   are "also on serve/scrape/mcp" — true for fetch/serve/mcp, but `scrape
   --help` in 0.2.2 lists no `--user-agent`. Fix the line to "`--user-agent`
   (fetch/serve/mcp, not scrape)".
2. **Omissions (additive, worth one skill line each):** `-q/--quiet`
   (fetch/scrape/serve — suppress logs; useful on pages that flood per-page
   warnings, upstream #264), global `-v/--verbose`, `--storage-dir <DIR>`
   (persistent cookies/profile dir, see upstream
   docs/Persist-cookies-and-storage.md), and `--v8-flags` (pass raw V8 flags,
   e.g. heap sizing).

Nothing in the skill is wrong enough to mislead an agent today; the two items
above are the whole delta.

**Version status (2026-10-19):** nixpkgs pins 0.2.2; upstream latest is v0.2.5
(2026-10-17); no open nixpkgs bump PR (last merged: 0.2.0→0.2.2, #556899).
0.2.3+ adds MCP HTTP auth/origin hardening (only matters for off-loopback
`--http`), 0.2.5 improves snapshot element refs, `browser_evaluate` promise
semantics, and adds `browser_wait_for_function`. Loopback/stdio use is
unaffected; no action needed until the next nixpkgs bump.

**Live MCP verification (2026-10-19):** `initialize` + `tools/list` over stdio
through the wrapper succeeded: `serverInfo: obscura-mcp 0.2.2`, protocol
2024-11-05, 37 tools — navigate/snapshot/click/fill/type/press_key/select_option/
evaluate/wait_for/wait_for_text/network_requests/console_messages/close/
markdown/links/interactive_elements/back/forward/reload/get|set|clear_cookies/
detect_forms/fill_form/scroll/get_attribute/count/extract/search/
tab_new|list|switch|close/storage_state/set_storage_state/screenshot/pdf.
(Tabs + cookies + storage-state are already in 0.2.2 — the README's fuller tool
table mostly describes 0.2.5.)

## 3. Hermes-side integration — decision

Two viable surfaces, both verified against upstream sources today:

**Option A — MCP server (RECOMMENDED).** Add one entry to
`services.hermes-agent.mcpServers` in `modules/features/hermes.nix`, exactly the
pattern already used there (codebase-memory, context, nixos, gitmcp, exa). The
NixOS module (NousResearch/hermes-agent `nix/moduleCommon.nix`, fetched
2026-10-19) supports per-server `command`, `args`, **`env`**, `url`, `headers`,
`auth`, `enabled`, `timeout`, `connect_timeout`, `tools.include/exclude`, and
merges them into `settings.mcp_servers`. Hermes namespaces MCP tools
`mcp__obscura__browser_navigate` etc. (`tools/mcp_tool_schema.py`), so there is
no collision with hermes' native `browser_*` tools even if that toolset is ever
enabled. Stdio transport verified live (above).

Proposed change (NOT applied — this session makes no repo edits):

```nix
# modules/features/hermes.nix — inside services.hermes-agent.mcpServers { }
obscura = {
  command = "${pkgs.obscura}/bin/obscura";
  args = [ "mcp" ];
  # Mortlake default (mirrors obscura.nix's wrapper): allow loopback/RFC1918
  # so hermes can browse sb.otwell.dev / taskdog.otwell.dev. Absolute store
  # path, so the gateway's pinned service PATH is irrelevant here.
  env.OBSCURA_ALLOW_PRIVATE_NETWORK = "1";
  enabled = true;
};
```

Optionally also one line in `systemd.services.hermes-agent.environment`:
`OBSCURA_ALLOW_PRIVATE_NETWORK = "1";` — covers hermes terminal-toolset shells
invoking `obscura` by name against LAN URLs (the skill, loaded via
`skills.external_dirs`, teaches exactly that). Without it, CLI calls from the
gateway hit the SSRF block (0.2.2 CLI errors do explain the opt-in, so an agent
can self-recover, but default-on is the established mortlake posture). If the
service-wide env is set, the per-server `env` is redundant but harmless.

**Option B — browser-provider plugin (defer).** Upstream README links
`SGavrl/hermes-plugin-obscura` (fetched 2026-10-19): a hermes
BrowserProvider that spawns `obscura serve` per session (or connects via
`OBSCURA_CDP_URL`) and routes hermes' **native browser toolset** through CDP —
`hermes plugins install SGavrl/hermes-plugin-obscura --enable` plus
`browser.cloud_provider: "obscura"` in config.yaml. Deferred because:
- The native `browser` toolset is NOT in mortlake's `enabled-toolsets`
  (hermes.nix) — the plugin routes tools we don't currently expose.
- Plugin *install* is imperative (`hermes plugins install`); declarative
  `plugins.enabled` only works after files land under HERMES_HOME (the funes
  precedent in hermes.nix). Extra state outside the rebuild.
- MCP (Option A) already delivers the interactive-browsing capability
  declaratively, verified live.
Revisit B only if hermes should get native `browser_vision`/in-tool screenshots
through its own toolset UX.

**Concurrency caveat (applies to A):** the MCP server holds ONE live browser
session — "current page" semantics. Concurrent hermes sessions (discord + cron +
kanban workers) would share it. Mitigations already in 0.2.2: `browser_tab_*`
tools (each tab keeps its runtime; switching preserves state) and per-session
spawn is impossible over one stdio pipe — heavy parallel work should stay on
`scrape`/`--file` batch CLI (skill already routes that). For a shared
multi-client HTTP MCP later, run `obscura mcp --http` as its own service and
point hermes' `url` at it — but then mind 0.2.3+ auth requirements
(`OBSCURA_MCP_TOKEN`, origin allowlist) that 0.2.2 lacks; keep it loopback.

## 4. Pi — confirmed: needs nothing

- Binary already on pi agents' PATH via `packages.nix` (all flake packages
  installed on every host): `which obscura` → `/run/current-system/sw/bin/obscura`
  (verified live 2026-10-19).
- The skill is tier-1 shared: `/home/john/.agents/skills/obscura/SKILL.md`
  resolves to `/home/john/src/mortlake/skills/obscura/SKILL.md` (same file;
  hermes reads the same dir via `skills.external_dirs`). One source, all agents.
- pi has an MCP surface (`~/.pi/agent/mcp.json`, currently exa) — wiring
  obscura there is possible later via the same stdio shape, but unnecessary:
  the skill's placement is CLI-first and pi agents exec the CLI directly.
- Incidental observation (out of scope, flag only): `~/.pi/agent/mcp.json`
  stores the exa API key in plaintext. Not an obscura issue; noting since seen.

## 5. Gaps / risks for our use

- **nixpkgs lag:** 0.2.2 vs upstream 0.2.5 (2026-10-17). No security exposure
  for loopback stdio; the 0.2.3 HTTP-auth hardening matters only if an
  off-loopback MCP/CDP endpoint is ever published — don't, on 0.2.2.
- **Shared MCP session** across concurrent hermes sessions (above); tabs
  mitigate, batch CLI avoids.
- **`--user-agent` absent on `scrape`** (skill drift #1) — an agent following
  the skill verbatim on scrape gets a claptrap error; trivial skill fix.
- **Hermes MCP tool timeout** defaults to 120s per the module docs; obscura's
  own nav ceiling is `OBSCURA_NAV_TIMEOUT_MS` (30s default) — compatible, no
  tuning needed.
- **SSRF default vs LAN posture:** every non-wrapper invocation (hermes
  service children, remote SSH shells into other hosts) starts blocked for
  private networks; the skill documents the escape hatch, the wiring in §3
  pre-opens it where hermes runs.

## 6. Recommendation (mortlake wiring + skill authoring)

1. **Wire hermes MCP now** — apply the `mcpServers.obscura` block from §3
   (one entry + optional service env line), rebuild jehoel, then verify from a
   hermes session that `mcp__obscura__browser_navigate` appears (e.g. ask
   hermes to snapshot `http://sb.otwell.dev`). Defer Option B (CDP plugin).
2. **Patch the skill** (tier-1, `mortlake/skills/obscura/SKILL.md`): fix the
   `--user-agent` global-flags line (not on scrape), add `-q/--quiet`,
   `--storage-dir`, `--v8-flags`; optionally one line on `obscura mcp` tool
   surface + tabs for multi-page interactive work.
3. **Do nothing for pi.**
4. Optional follow-up: a nixpkgs bump PR 0.2.2→0.2.5 (none open as of
   2026-10-19) — low urgency.

---

### Provenance appendix (all fetched/verified 2026-10-19)

- Live: `obscura --version` → 0.2.2; `--help` all subcommands; MCP stdio
  `initialize`/`tools/list` handshake (stderr clean).
- h4ckf0r0day/obscura: README (MCP section, Claude Desktop config), releases
  v0.2.3/v0.2.4/v0.2.5 notes, docs/Use-the-MCP-server.md,
  docs/Environment-variables.md, git tree (516 paths, no CHANGELOG file).
- NixOS/nixpkgs: `pkgs/by-name/ob/obscura/package.nix` (0.2.2, buildFeatures
  render+stealth); PR search (no open bump).
- NousResearch/hermes-agent: `toolsets.py` (native browser toolset exists,
  currently not enabled in mortlake), `nix/moduleCommon.nix` (mcpServerType
  incl. `env`; mcpServersToConfig), `nix/nixosModules.nix`, tree (21,701
  paths), `tools/mcp_tool_schema.py` (`mcp__server__tool` naming).
- SGavrl/hermes-plugin-obscura: README (install, config, env vars, CDP modes).
- Local: `modules/features/hermes.nix`, `modules/features/obscura.nix`,
  skill path resolution, `~/.pi/agent/mcp.json` surface.
- Working files kept in /tmp/agent-reports/: obscura-readme.md,
  obscura-tree.txt, hermes-tree.txt, hermes-nixos-module.nix,
  hermes-moduleCommon.nix, obscura-hermes-plugin-readme.md.
