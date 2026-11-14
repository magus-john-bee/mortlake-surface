# Funes — cross-agent episodic memory (huggingface/funes, Apache-2.0).
# Rust single binary from numtide/llm-agents.nix; binary cache declared in
# nix-qol.nix. Indexes agent session transcripts into a local Lance dataset
# (BM25 + vector, rerank) with exact session/turn provenance; the memory is
# a disposable derived artifact — raw text lives in the rows.
#
# Topology (ledger: ~/vault/sb/agent-tooling.md, episodic slot):
# ONE memory per host at a NEUTRAL path — services.funes.memoryHome,
# default /var/lib/funes, john-owned. The gateway is pointed at it through
# the hermes-agent service environment (FUNES_HOME); shells, hook workers,
# and the pi extension get the same value via the session variable. Null
# keeps per-user ~/.funes memories. FUNES_HOME relocates only the
# memory/state; integrations (~/.funes/agents), install id, and the HF
# model cache stay per-user under each real home.
#
# Posture, from the ledger's measured gotchas:
#   - LOCAL-ONLY: no `funes bind` — no push hook exists unbound, nothing
#     publishes. Only network is the one-time embedder download (HF cache)
#     and the integration-catalog fetch during `funes add`.
#   - Telemetry off by default (FUNES_NO_TELEMETRY=1 wrapper env).
#   - funes has NO config file. v1.9.0 dropped the half-life decay
#     flag — old-decision recall needs no workaround; scope by date
#     with `--since/--until` when wanted.
#   - The hermes per-turn hook is BETA — installed by `funes add hermes`,
#     under observation. The plugin itself is enabled declaratively in
#     hermes.nix settings: the imperative `hermes plugins enable` path is
#     broken under uv2nix builds (admission wants <site-packages>/uv.lock).
#
# Bootstrap (imperative, one-time, per user home):
#   funes add hermes     # plugin -> ~/.hermes/plugins/funes/, first index
#   funes add pi         # extension into pi's config, converter + index
#   funes status         # recall reading own memory yet?
#   Run `funes add <agent>` from the agent user's OWN login shell — a
#   foreign $HOME (e.g. the gateway's /var/lib/hermes) installs under the
#   wrong home and leaves the agent's config pointing at nothing; the spool
#   then goes dry silently (observed on pi and jehoel). No drain job exists
#   by design: each integration's per-turn detached hook sweeps its whole
#   pending spool (idempotently, lock-tolerant) whenever the agent runs, so
#   an agent's tail waits only until its next session. Manual full drain:
#   `funes index --harness <id> --yes`.
# Removal: `funes remove <agent>` (memory and transcripts untouched).
{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.funes = inputs.wrapper-modules.lib.wrapPackage (_: {
        inherit pkgs;
        package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.funes;
        env.FUNES_NO_TELEMETRY = "1";
      });
    };

  flake.nixosModules.funes =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.funes;
    in
    {
      options.services.funes.memoryHome = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "/var/lib/funes";
        description = ''
          Shared FUNES_HOME for every user on this host (memory + indexing
          state; per-agent integration files stay under each user's real
          home). Neutral by design: the memory is a cross-agent resource,
          not any one agent's state. Null keeps per-user ~/.funes memories.
        '';
      };

      config = lib.mkMerge [
        {
          environment.systemPackages = [
            inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.funes
          ];

          # Memory, per-source state, installed integrations, install id, and
          # the HF model cache (embedder/reranker) all live under the user home;
          # FUNES_HOME relocates only the memory — keep the whole dir persistent.
          preservation.preserveAt."/persistent".users.john.directories = [
            ".funes"
            ".cache/huggingface"
          ];
        }
        (lib.mkIf (cfg.memoryHome != null) {
          # Session-scoped so john's shells, hook workers finding funes on
          # PATH, and the pi extension all resolve the same memory.
          environment.sessionVariables.FUNES_HOME = cfg.memoryHome;

          # Ownership rides the preservation entry itself: a bare string
          # makes preservation emit its own tmpfiles rule defaulting the
          # backing dir to root:root, which fights any separate rule.
          preservation.preserveAt."/persistent".directories = [
            {
              directory = cfg.memoryHome;
              user = "john";
              group = "users";
            }
          ];
        })
        (lib.mkIf (cfg.memoryHome != null && config.services ? hermes-agent) {
          # The gateway's HOME points at the hermes state dir, not john's
          # passwd home — carry the memory path in the service environment
          # so plugin hook workers resolve the same memory as everyone else.
          systemd.services.hermes-agent.environment.FUNES_HOME = cfg.memoryHome;

          # The funes plugin's per-turn hook (funes-index.sh) shells out to
          # `funes`, but the service PATH is pinned store paths and never
          # includes /run/current-system/sw/bin, where this module's
          # systemPackages put the wrapper — the same trap gno hit (aff4b81).
          # From install day onward every run aborted with "funes not found;
          # skipping" (funes-sync.log), stranding converted turns in the
          # spool: the converter kept writing $FUNES_HOME/spool/hermes while
          # nothing ever drained it. The same PATH also reaches pi sessions
          # launched from the gateway env, whose funes extension spawns the
          # binary the same way.
          systemd.services.hermes-agent.path = [
            inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.funes
          ];
        })
      ];
    };
}
