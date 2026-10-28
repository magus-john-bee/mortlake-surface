# Publish-surface — jehoel is the sole publisher of the public surface repo
# (aven RDC-MJRJ, openspec publish-surface-radicle-trigger).
#
# The timer polls canonical main's ref in the local radicle storage (plain
# git — storage refs need no RAD_PASSPHRASE, only git-remote-rad signs) and
# runs the publisher whenever it differs from the last-published sha.
# Failed runs write no state, so the next tick retries the same sha; the
# journal is the failure surface. This replaced the GitHub Actions trigger
# (publish-surface.yml, retired by the same change); deploy-site.yml still
# ships and Pages keeps firing from surface-repo pushes.
#
# The RID is deliberately absent from this file: modules/ ships in the
# public surface. PUBLISH_SOURCE reaches the unit through the sops-rendered
# env below, and the ritual recipe (`just publish-surface`) sources the
# same env file.
{
  flake.nixosModules.publish-surface =
    {
      config,
      pkgs,
      ...
    }:
    let
      # Byte-verbatim copy of the repo script with git+nix pinned into its
      # PATH — single source, no drift between the timer and the ritual
      # recipe, and the store copy runs from any context (systemd units get
      # no system PATH for these). checkPhase is off: the pipeline's own
      # gates audit the script where it matters.
      publishScript = pkgs.writeShellApplication {
        name = "publish-surface";
        runtimeInputs = [
          pkgs.git
          pkgs.nix
        ];
        checkPhase = ":";
        text = builtins.readFile ../../scripts/publish-surface.sh;
      };
    in
    {
      sops = {
        secrets = {
          "surface-gh-pat-for-jehoel" = {
            sopsFile = ./secrets.yaml;
          };
          "mortlake-radicle-rid" = {
            sopsFile = ./secrets.yaml;
          };
        };

        # EnvironmentFile for both the service and the just recipe. Owner
        # john:users 0400 — the service runs as john and the recipe runs from
        # john's shell.
        templates."publish-surface-env" = {
          content = ''
            SURFACE_PAT=${config.sops.placeholder."surface-gh-pat-for-jehoel"}
            PUBLISH_SOURCE=/home/john/.radicle/storage/${config.sops.placeholder."mortlake-radicle-rid"}
            PUBLISH_STATE_FILE=/home/john/.local/state/publish-surface/last-published
          '';
          owner = "john";
          group = "users";
          mode = "0400";
        };
      };

      systemd.services.publish-surface = {
        description = "Publish public surface from canonical main";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          User = "john";
          Group = "users";
          EnvironmentFile = [ config.sops.templates."publish-surface-env".path ];
          ExecStart = "${publishScript}/bin/publish-surface";
        };
      };

      systemd.timers.publish-surface = {
        description = "Poll canonical main and publish the public surface";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          # OnStartupSec, not OnBootSec: boot-relative timers fire instantly
          # on a machine that has been up longer than the interval — the
          # first run belongs one interval after the timer's own start.
          OnStartupSec = "5min";
          OnUnitActiveSec = "5min";
          Persistent = true;
        };
      };

      # IMPERATIVE (once, before the first publish can succeed): mint the
      # surface PAT and file both sops keys, then rebuild jehoel.
      # 1. Fine-grained PAT under the magus account: repository access to
      #    magus-john-bee/mortlake-surface ONLY, contents: read+write.
      # 2. sops set modules/features/secrets.yaml \
      #      '["surface-gh-pat-for-jehoel"]' '<pat>'
      #    rid="$(cd ~/src/mortlake && rad inspect)"  # prints rad:<rid>
      #    sops set modules/features/secrets.yaml \
      #      '["mortlake-radicle-rid"]' "${rid#rad:}"
      # 3. Rebuild; `journalctl -u publish-surface -f` shows the first run.
      #    Until the keys exist the service fails on the rendered env — the
      #    surface simply stays at its last CI-published commit.
    };
}
