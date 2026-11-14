# Gno — declarative memory + vault search (gmickel/gno, MIT).
# Bun + vendored native llama.cpp from numtide/llm-agents.nix; binary cache
# declared in nix-qol.nix. Facts are markdown files in a memoryManaged
# collection (gno remember writes facts/<date>/mem-<id>.md with memory:
# frontmatter); the SQLite index under the data dir is disposable. The
# memory contract: remember is dry-run by default, scopes are mandatory,
# nothing is deleted — facts change only by hash-checked supersession.
#
# Topology (ledger: ~/vault/sb/agent-tooling.md, declarative slot;
# deployment spike): ONE neutral state dir per
# host so the hermes gateway (HOME = /var/lib/hermes), john's shells, and
# MCP clients all resolve the same config/index. Gno relocates via three
# env vars (GNO_CONFIG_DIR / GNO_DATA_DIR / GNO_CACHE_DIR) — session-wide
# here, plus the hermes-agent service environment. Null keeps per-user
# XDG paths (~/.config/gno, ~/.local/share/gno).
#
# The memoryManaged collection PATH is deliberately NOT set here — it is
# the #132 placement decision. Expected shape: inside ~/vault so the fact
# files travel via Syncthing (single-writer host: jehoel writes, others
# read), configured in the shared index.yml at bootstrap.
#
# Posture:
#   - No daemon (guardrail: everything in the memory stack is
#     pull-on-demand). `gno daemon` exists (watch/sync/embed loop +
#     resident MCP) — opt in later only if reindex lag actually hurts.
#   - Model downloads stay enabled (GNO_OFFLINE unset): BM25 recall works
#     immediately; embedding models for the vector leg background in at
#     the first `gno embed`. They land in the shared cache dir — one
#     download per host, not per user.
#   - Hermes provider (integrations/hermes-gno-memory in the gno source,
#     pins gno >= 1.41.0): imperative one-time bootstrap, not declared
#     here — copy into $HERMES_HOME/plugins/gno/, write
#     $HERMES_HOME/gno/config.json (scopes REQUIRED, no implicit global
#     scope), then activate. Declarative activation (memory.provider in
#     hermes.nix) lands only after the plugin files exist, same ordering
#     the funes plugin used.
{ inputs, ... }:
{
  flake.nixosModules.gno =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.gno;
    in
    {
      options.services.gno.stateDir = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "/var/lib/gno";
        description = ''
          Shared gno state for every user on this host: config (index.yml,
          writable — setup and connector commands edit it), the derived
          SQLite index, and the model cache. Neutral by design: one index
          shared by shells, the hermes gateway, and MCP clients. Null keeps
          per-user XDG paths.
        '';
      };

      config = lib.mkMerge [
        {
          environment.systemPackages = [
            inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.gno
          ];
        }
        (lib.mkIf (cfg.stateDir != null) {
          # Session-scoped so john's shells and MCP clients resolve the
          # same config/index as everything else.
          environment.sessionVariables = {
            GNO_CONFIG_DIR = "${cfg.stateDir}/config";
            GNO_DATA_DIR = "${cfg.stateDir}/data";
            GNO_CACHE_DIR = "${cfg.stateDir}/cache";
          };

          # Ownership rides the preservation entry itself (funes lesson):
          # a bare string makes preservation emit a root:root tmpfiles rule.
          # john-owned serves both john's shells and the gateway, which
          # runs as john with HOME=/var/lib/hermes.
          preservation.preserveAt."/persistent".directories = [
            {
              directory = cfg.stateDir;
              user = "john";
              group = "users";
            }
          ];
        })
        (lib.mkIf (cfg.stateDir != null && config.services ? hermes-agent) {
          # The gateway's HOME points at the hermes state dir, not john's
          # passwd home — carry the gno paths in the service environment so
          # the memory provider's `gno recall/remember` subprocesses resolve
          # the same state as everyone else.
          systemd.services.hermes-agent.environment = {
            GNO_CONFIG_DIR = "${cfg.stateDir}/config";
            GNO_DATA_DIR = "${cfg.stateDir}/data";
            GNO_CACHE_DIR = "${cfg.stateDir}/cache";
          };

          # The gateway unit runs ProtectSystem=strict, which mounts the
          # whole hierarchy read-only inside the service's private mount
          # namespace; upstream ReadWritePaths covers only the hermes state
          # dir + workspace. Without the gno state dir punched writable,
          # `gno recall` dies with sqlite "unable to open database file"
          # on a healthy rw host mount. NixOS list-merges this onto the
          # unit's existing ReadWritePaths.
          systemd.services.hermes-agent.serviceConfig.ReadWritePaths = [
            cfg.stateDir
          ];
        })
      ];
    };
}
