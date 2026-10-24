# Transmission — torrent client with done scripts that act on completed
# torrents from allowed trackers. Tracker patterns come from sops (not
# hardcoded) so the repo can stay public and which trackers qualify is
# not recorded anywhere in git.
#  - share trackers   → copy into the Syncthing share directory
#  - library trackers → symlink (file or top-level dir) into the Jellyfin
#                        library; the download stays in transmission's dir.
# Transmission only supports a single script-torrent-done-filename, so one
# dispatcher invokes both handlers; each skips quietly when its tracker
# doesn't match or its action is already done.
_: {
  flake.nixosModules.transmission =
    { pkgs, config, ... }:
    let
      transmissionPort = 9091;
      transmissionPeerPort = 51413;
      syncthingStDir = "/var/lib/syncthing/st";
      jellyfinLibraryDir = "/var/lib/jellyfin/library";

      # Tracker patterns rendered by sops — not hardcoded in the Nix store.
      sharePatternFile = config.sops.templates."transmission-tracker-pattern".path;
      libraryPatternFile = config.sops.templates."transmission-media-tracker-pattern".path;

      # Shared prelude: resolve the finished path and bail if it vanished.
      commonPrelude = ''
        torrent_path="''${TR_TORRENT_DIR}/''${TR_TORRENT_NAME}"

        if [[ ! -e "$torrent_path" ]]; then
          echo "''${0##*/}: path does not exist: $torrent_path" >&2
          exit 0
        fi
      '';

      copyTorrentToSyncthing = pkgs.writeShellApplication {
        name = "copy-torrent-to-syncthing";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
        ];
        text = ''
          set -euo pipefail

          ${commonPrelude}

          # Only act on torrents from the allowed tracker.
          # Pattern comes from sops-rendered file (not in the Nix store).
          if [[ -z "''${TR_TORRENT_TRACKERS:-}" ]] || ! grep -Eiqf "${sharePatternFile}" <<< "$TR_TORRENT_TRACKERS"; then
            echo "''${0##*/}: not from allowed tracker, skipping" >&2
            exit 0
          fi

          mkdir -p "${syncthingStDir}"

          if [[ -f "$torrent_path" ]]; then
            cp -a "$torrent_path" "${syncthingStDir}/"
            echo "''${0##*/}: copied $torrent_path to ${syncthingStDir}/"
          else
            dest="${syncthingStDir}/''${TR_TORRENT_NAME}"
            if [[ -e "$dest" ]]; then
              echo "''${0##*/}: destination already exists, skipping: $dest" >&2
              exit 0
            fi
            cp -a "$torrent_path" "${syncthingStDir}/"
            echo "''${0##*/}: copied $torrent_path to ${syncthingStDir}/"
          fi
        '';
      };

      linkTorrentToJellyfin = pkgs.writeShellApplication {
        name = "link-torrent-to-jellyfin";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
        ];
        text = ''
          set -euo pipefail

          ${commonPrelude}

          # Only act on torrents from the allowed library trackers.
          # Pattern comes from sops-rendered file (not in the Nix store).
          if [[ -z "''${TR_TORRENT_TRACKERS:-}" ]] || ! grep -Eiqf "${libraryPatternFile}" <<< "$TR_TORRENT_TRACKERS"; then
            echo "''${0##*/}: not from allowed tracker, skipping" >&2
            exit 0
          fi

          # Symlink the file or the top-level directory, whichever this
          # torrent is. Absolute target so the link works from anywhere
          # (Jellyfin resolves it as an unprivileged reader).
          mkdir -p "${jellyfinLibraryDir}"
          dest="${jellyfinLibraryDir}/''${TR_TORRENT_NAME}"

          if [[ -L "$dest" ]]; then
            echo "''${0##*/}: symlink already exists, skipping: $dest" >&2
            exit 0
          fi

          if [[ -e "$dest" ]]; then
            echo "''${0##*/}: non-symlink destination already exists, skipping: $dest" >&2
            exit 0
          fi

          ln -s "$torrent_path" "$dest"
          echo "''${0##*/}: linked $torrent_path -> $dest"
        '';
      };

      # Transmission runs a single done script — dispatch to both handlers.
      # Each handler exits 0 on skip, so one never masks the other's result.
      torrentDoneDispatcher = pkgs.writeShellApplication {
        name = "torrent-done-dispatcher";
        runtimeInputs = [ ];
        text = ''
          set -uo pipefail

          status=0
          "${copyTorrentToSyncthing}/bin/copy-torrent-to-syncthing" || status=1
          "${linkTorrentToJellyfin}/bin/link-torrent-to-jellyfin" || status=1
          exit $status
        '';
      };
    in
    {
      # Tracker patterns — encrypted, not visible in Nix store or repo
      sops.secrets = {
        "torrent-tracker-pattern" = {
          owner = "john";
          sopsFile = ./secrets.yaml;
        };

        "media-tracker-pattern" = {
          owner = "john";
          sopsFile = ./secrets.yaml;
        };
      };

      sops.templates = {
        "transmission-tracker-pattern" = {
          content = "${config.sops.placeholder.torrent-tracker-pattern}";
          owner = "john";
        };

        "transmission-media-tracker-pattern" = {
          content = "${config.sops.placeholder.media-tracker-pattern}";
          owner = "john";
        };
      };

      services.transmission = {
        enable = true;
        package = pkgs.transmission_4;
        openRPCPort = true;
        user = "john";
        settings = {
          peer-port = transmissionPeerPort;
          rpc-port = transmissionPort;
          rpc-authentication-required = false;
          rpc-bind-address = "0.0.0.0";
          rpc-whitelist-enabled = true;
          rpc-host-whitelist-enabled = false;
          rpc-whitelist = "127.0.0.1,192.168.*.*,10.*.*.*";
          watch-dir-enabled = false;
          script-torrent-done-enabled = true;
          # A single dispatcher fans out to both done scripts; each skips
          # independently when its tracker doesn't match.
          script-torrent-done-filename = "${torrentDoneDispatcher}/bin/torrent-done-dispatcher";
        };
      };

      # Tailnet-only web UI: the split-DNS name resolves on the tailnet and
      # nginx refuses public sources outright (transmission is never exposed
      # to the internet; TLS is the wildcard DNS-01 cert). The proxy hits
      # 127.0.0.1, which the RPC whitelist allows
      # passwordlessly — the tailnet gate IS the auth.
      services.nginx.virtualHosts."transmission.otwell.dev" = {
        forceSSL = true;
        useACMEHost = "otwell.dev";
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString transmissionPort}";
          extraConfig = ''
            allow 100.64.0.0/10;
            deny all;
          '';
        };
      };

      systemd.services.transmission = {
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        # The unit is ProtectSystem=strict upstream; the done script writes
        # to the Syncthing share and the Jellyfin library via these binds.
        serviceConfig.BindPaths = [
          "${syncthingStDir}"
          "${jellyfinLibraryDir}"
        ];
      };

      networking.firewall.allowedTCPPorts = [
        transmissionPort
        transmissionPeerPort
      ];

      # Transmission state — owned by the service user/group declared above.
      preservation.preserveAt."/persistent".directories = [
        {
          directory = "/var/lib/transmission";
          user = "john";
          group = "users";
        }
      ];
    };
}
