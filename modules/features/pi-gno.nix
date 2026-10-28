# Pi <-> gno bridge: shared declarative memory for pi.
#
# Ports the hermes-gno-memory provider shape to pi as a TypeScript
# extension (modules/features/pi-gno/extension/index.ts):
#   - before_agent_start hook runs `gno recall --json` with the prompt and
#     injects recalled facts as a per-run custom message (pi's pre-prompt
#     channel; hermes uses its provider prefetch slot)
#   - a gno_remember tool with propose/add/supersede gating (supersede
#     needs predecessor uri + contentHash) and recall-receipt fencing
#
# pi's extension API (jiti, no build step, no npm deps — the extension
# shells out to the gno binary) makes this fully declarative: the source
# dir is symlinked into pi's user extensions directory, which pi loads
# unconditionally (no settings.json surgery).
#
# Env: pi runs as a normal interactive process under john, so the gno.nix
# session variables (GNO_CONFIG_DIR/DATA_DIR/CACHE_DIR -> /var/lib/gno)
# and PATH (gno via environmentPackages) reach it from any login shell,
# including panes spawned by herdr. Launch paths without them are NOT
# wired here; the extension fails visibly on a missing GNO_CONFIG_DIR
# rather than silently touching a per-user store.
#
# Inert on hosts without services.gno (raphael runs pi but no store).
_: {
  flake.nixosModules.pi-gno =
    { config, lib, ... }:
    {
      config = lib.mkIf ((config.services ? gno) && config.services.gno.stateDir != null) {
        systemd.tmpfiles.rules = [
          "d /home/john/.pi/agent/extensions 0755 john users - -"
          "L+ /home/john/.pi/agent/extensions/gno-memory - - - - ${./pi-gno/extension}"
        ];
      };
    };
}
