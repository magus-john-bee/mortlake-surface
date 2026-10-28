# Repo initialization is manual (initialize = false; restic 0.17+ treats
# re-init as fatal). For a new host's bucket:
#   sudo restic-<host> init
# The wrapper sources the sops env template automatically.
#
# Uriel (was thoth) — being decommissioned; its restic config + B2 keys
# were removed when the sops keys were dropped; it no longer
# imports this module. Raphael has no backup provisioned (its corpus-era
# puck-* sops keys are gone); when it needs restic, create a
# bucket + raphael-* keys and add a hostConfig entry.
_: {
  flake.nixosModules.restic =
    {
      config,
      pkgs,
      ...
    }:
    let
      inherit (config.sops) secrets templates;
      p = config.sops.placeholder;
      inherit (config.networking) hostName;

      secrets-opts = {
        owner = "john";
        sopsFile = ./secrets.yaml;
      };

      hostConfig = {
        # Jehoel — server + desktop.
        # Paths previously self-registered by service modules via
        # mortlake.restic.paths; now listed here directly.
        jehoel = {
          name = "jehoel";
          repository = "s3:s3.us-east-005.backblazeb2.com/jehoel-restic";
          passwordSecret = "jehoel-restic-password";
          envTemplate = "jehoel-restic-b2-env";
          paths = [
            # SSH host keys (sops-nix age key source for secrets.yaml)
            # + machine-id
            "/persistent/etc"
            "/home/john/data"
            "/home/john/vault"
            "/home/john/src"
            "/home/john/.ssh"
            # Shell history DB
            "/home/john/.local/share/atuin"
            # Aven task DB (db.sqlite + WAL) and the sync-server storage
            # (server/sync-server.sqlite) — the sync server itself holds
            # only ciphertext, so this host's copy is the only real backup
            # until other devices join sync.
            "/home/john/.local/state/aven"
            # pi/prime-agent session transcripts — canonical source for the
            # funes pi spool (the memory itself is derived).
            "/home/john/.pi"
            # Radicle node: DID key, node database, tracked repo storage
            "/home/john/.radicle"
            # Hermes gateway state: state.db, sessions,
            # skills, cron jobs, scripts, watcher-state. The pm tool store
            # (tools/), caches, and logs are replaceable and excluded below.
            "/var/lib/hermes"
            # funes cross-agent episodic memory (Lance dataset + spool);
            # rebuildable from transcripts, but transcripts can be lost —
            # back the memory itself.
            "/var/lib/funes"
            # gno declarative memory + vault search. The memoryManaged
            # collection (/var/lib/gno/memory) is canonical markdown and
            # config/ is tiny; the SQLite index (data/) rebuilds from the
            # facts and the model downloads (cache/) re-fetch — both
            # excluded below.
            "/var/lib/gno"
            "/var/lib/jellyfin"
            "/var/lib/transmission"
            "/var/lib/mealie"
            # Syncthing hub: device identity/config AND the keepass vault
            # (vault/ + its staggered-version history ride along).
            "/var/lib/syncthing"
          ];
          # Media and downloaded data are replaceable; configs, metadata,
          # torrent files (.config/transmission-daemon/torrents) and
          # fast-resume state are small and included.
          exclude = [
            "*.tmp"
            "/var/lib/hermes/.hermes/tools"
            "/var/lib/hermes/.hermes/cache"
            "/var/lib/hermes/.hermes/logs"
            "/var/lib/hermes/.hermes/installs"
            "/var/lib/gno/data"
            "/var/lib/gno/cache"
            "/var/lib/jellyfin/library"
            "/var/lib/jellyfin/transcodes"
            "/var/lib/transmission/Downloads"
            "/var/lib/transmission/.incomplete"
          ];
        };
      };

      cfg = hostConfig.${hostName} or (throw "restic: no backup config for host '${hostName}'");
    in
    {
      config = {
        sops = {
          secrets = {
            "jehoel-restic-password" = secrets-opts;
            "jehoel-b2-access-key-id" = secrets-opts;
            "jehoel-b2-secret-access-key" = secrets-opts;
          };
          templates."jehoel-restic-b2-env".content = ''
            AWS_ACCESS_KEY_ID=${p.jehoel-b2-access-key-id}
            AWS_SECRET_ACCESS_KEY=${p.jehoel-b2-secret-access-key}
          '';
          templates."jehoel-restic-b2-env".owner = "john";
        };

        services.restic.backups.${cfg.name} = {
          inherit (cfg) repository;
          passwordFile = secrets."${cfg.passwordSecret}".path;
          environmentFile = templates."${cfg.envTemplate}".path;

          inherit (cfg) paths;
          inherit (cfg) exclude;

          initialize = false;

          extraBackupArgs = [ "--verbose" ];

          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            RandomizedDelaySec = "30m";
          };

          createWrapper = true;
        };

        # Run as root (the NixOS default). Root reads all backup paths,
        # all sops secrets (bypasses file perms), and the cache directory
        # without permission issues. The `restic-<host>` wrapper still works
        # for manual use: `sudo restic-jehoel snapshots`.
        # Previous User=john override caused: polkit access denied on
        # systemd-inhibit, cache permission denied panics, and would fail
        # on any root-owned backup path.

        environment.systemPackages = [ pkgs.restic ];
      };
    };
}
