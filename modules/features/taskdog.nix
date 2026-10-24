# Taskdog — terminal task manager with CLI/TUI + REST API server.
# uv2nix-built venv from github:Kohei-Wada/taskdog.
#
# Topology: ONE server (jehoel), everything else connects to it over
# https://taskdog.otwell.dev (nginx + ACME in front, API-key auth).
# The venv ships taskdog (CLI/TUI), taskdog-server, and taskdog-mcp,
# so every client host gets the full binary set from the same package.
#
# Roles (opt in from host configuration.nix):
#   services.taskdog.server.enable = true  → systemd user service (john,
#     127.0.0.1:8000), nginx vhost, auth keys, hourly SQLite snapshots.
#   services.taskdog.client.enable = true  → cli.toml symlink pointing at
#     the central server with this host's API key (hostname-switched).
#
# Hermes (jehoel) additionally gets TASKDOG_API_* env vars via the
# hermes-env sops template in hermes.nix — env beats cli.toml, so the
# agent talks to the central server regardless of HOME.
#
# GTD workflow conventions live in the archived gtd-taskdog skill
# (skills-tmp/skill-archive/note-taking/gtd-taskdog).
{
  inputs,
  ...
}:
{
  flake.nixosModules.taskdog =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (pkgs.stdenv.hostPlatform) system;
      taskdog = inputs.taskdog.packages.${system}.default;

      domain = "taskdog.otwell.dev";

      p = config.sops.placeholder;

      # One named key per consumer; all live in server.toml on the
      # server. Clients only deploy their own host's key.
      clientKeyForHost = {
        jehoel = "taskdog-api-key-jehoel";
        raphael = "taskdog-api-key-raphael";
      };
      clientKeySecret =
        clientKeyForHost.${config.networking.hostName}
          or (throw "taskdog: no client API key mapped for host '${config.networking.hostName}'");

      # Snapshots via taskdog's native `db backup` (server-side VACUUM INTO
      # — transactionally consistent even under WAL; verified in
      # taskdog_core sqlite_backup_store.py). Called over localhost with
      # jehoel's own key so it works even before public DNS exists.
      # Hourly kept 24h, first-of-day promoted to daily kept 14d.
      snapshotScript = pkgs.writeShellScript "taskdog-snapshot" ''
        set -eu
        D="$HOME/.local/share/taskdog/backups"
        ${pkgs.coreutils}/bin/mkdir -p "$D"
        H=$(${pkgs.coreutils}/bin/date +%Y%m%d%H)
        DY=$(${pkgs.coreutils}/bin/date +%Y%m%d)
        F="$D/hourly-$H.db"
        if [ ! -f "$F" ]; then
          TASKDOG_API_BASE_URL=http://127.0.0.1:8000 \
          TASKDOG_API_KEY=$(${pkgs.coreutils}/bin/cat ${
            config.sops.secrets."taskdog-api-key-jehoel".path
          }) \
          ${taskdog}/bin/taskdog db backup -o "$F"
        fi
        if [ ! -f "$D/daily-$DY.db" ]; then
          L=$(${pkgs.coreutils}/bin/ls -1t "$D"/hourly-*.db | ${pkgs.coreutils}/bin/head -1)
          ${pkgs.coreutils}/bin/cp "$L" "$D/daily-$DY.db"
        fi
        ${pkgs.findutils}/bin/find "$D" -name 'hourly-*.db' -mmin +1440 -delete
        ${pkgs.findutils}/bin/find "$D" -name 'daily-*.db' -mtime +14 -delete
      '';

      secretOpts = {
        owner = "john";
        sopsFile = ./secrets.yaml;
      };
    in
    {
      options.services.taskdog = {
        server.enable = lib.mkEnableOption "the taskdog REST API server (one host only; jehoel)";
        client.enable = lib.mkEnableOption "taskdog CLI/TUI configured against the central server";
      };

      config = lib.mkMerge [
        (lib.mkIf (config.services.taskdog.server.enable || config.services.taskdog.client.enable) {
          environment.systemPackages = [ taskdog ];

          # Clients deploy only their own key; the server needs all four
          # (its own + every client's, for server.toml).
          sops.secrets =
            (lib.optionalAttrs config.services.taskdog.client.enable {
              ${clientKeySecret} = secretOpts;
            })
            // (lib.optionalAttrs config.services.taskdog.server.enable (
              builtins.listToAttrs (
                map (name: {
                  inherit name;
                  value = secretOpts;
                }) (builtins.attrValues clientKeyForHost ++ [ "taskdog-api-key-hermes" ])
              )
            ));
        })

        # ── Server (jehoel) ───────────────────────────────────────────────
        (lib.mkIf config.services.taskdog.server.enable {
          # server.toml — whole-file secret (multiple named keys cannot be
          # expressed via env vars). Symlinked into ~/.config/taskdog/.
          sops.templates."taskdog-server-toml" = {
            content = ''
              [auth]
              enabled = true

              [[auth.api_keys]]
              name = "jehoel"
              key = "${p.taskdog-api-key-jehoel}"

              [[auth.api_keys]]
              name = "raphael"
              key = "${p.taskdog-api-key-raphael}"

              [[auth.api_keys]]
              name = "hermes"
              key = "${p.taskdog-api-key-hermes}"
            '';
            owner = "john";
          };

          # ~/.config is tmpfs — recreate the symlink on every activation.
          system.activationScripts.taskdog-server-config.text = ''
            install -d -m 700 -o john -g users /home/john/.config/taskdog
            ln -sfn ${config.sops.templates."taskdog-server-toml".path} /home/john/.config/taskdog/server.toml
            chown -h john:users /home/john/.config/taskdog/server.toml
          '';

          # WebSocket (/ws, TUI live updates) rides the same
          # location as plain HTTP.
          #
          services.nginx.virtualHosts."${domain}" = lib.mkIf config.services.nginx.enable {
            forceSSL = true;
            enableACME = true;
            locations."/.well-known/acme-challenge".root = "/var/lib/acme/acme-challenge";
            locations."/" = {
              proxyPass = "http://127.0.0.1:8000";
              proxyWebsockets = true;
            };
          };

          systemd = {
            user = {
              services.taskdog-server = {
                description = "Taskdog REST API server";
                after = [ "network.target" ];
                wantedBy = [ "default.target" ];
                serviceConfig = {
                  ExecStart = "${taskdog}/bin/taskdog-server --host 127.0.0.1 --port 8000";
                  Restart = "on-failure";
                  RestartSec = 5;
                };
                # US holiday awareness for the optimizer (env > config file).
                environment.TASKDOG_REGION_COUNTRY = "US";
              };

              # Hourly WAL-safe DB snapshots (restic stays the canonical backup;
              # this gives intra-day point-in-time until B2 is re-enabled, and
              # history finer than daily snapshots afterwards).
              services.taskdog-snapshot = {
                description = "Taskdog SQLite snapshot (WAL-safe backup API)";
                serviceConfig.Type = "oneshot";
                script = "${snapshotScript}";
              };

              timers.taskdog-snapshot = {
                description = "Hourly taskdog DB snapshot";
                wantedBy = [ "timers.target" ];
                timerConfig = {
                  OnCalendar = "hourly";
                  Persistent = true;
                };
              };
            };
          };

          # Persist DB + notes + snapshots across rebuilds.
          preservation.preserveAt."/persistent".users.john.directories = [
            ".local/share/taskdog"
          ];
        })

        # ── Client (any host, incl. jehoel itself) ─────────────────────────
        (lib.mkIf config.services.taskdog.client.enable {
          sops.templates."taskdog-cli-toml" = {
            content = ''
              # Managed by mortlake — do not edit (recreated on activation).
              [api]
              base_url = "https://${domain}"
              api_key = "${p.${clientKeySecret}}"

              [ui]
              theme = "textual-dark"
            '';
            owner = "john";
          };

          system.activationScripts.taskdog-client-config.text = ''
            install -d -m 700 -o john -g users /home/john/.config/taskdog
            ln -sfn ${config.sops.templates."taskdog-cli-toml".path} /home/john/.config/taskdog/cli.toml
            chown -h john:users /home/john/.config/taskdog/cli.toml
          '';
        })
      ];
    };
}
