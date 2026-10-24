# Aven — local-first task manager for power users and agents (raine/aven).
# Rust + SQLite from numtide/llm-agents.nix (not in nixpkgs). Replaces
# taskdog over time: taskdog stays live until its tasks are migrated,
# then the taskdog.nix module retires.
#
# Split of concerns (ledger: ~/vault/sb/agent-tooling.md):
#   aven = personal/cross-project task tracking (the taskdog job)
#   td   = per-repo session handoff (marcus/td, td.nix)
#
# Config: fully declarative — the co-located aven-config.yaml is
# symlinked to ~/.config/aven/config.yaml at activation (taskdog
# cli.toml pattern). NOT in preservation: runtime writes replace the
# symlink and are discarded at the next switch/reboot. When the first
# device pairs for sync (taskdog migration), set sync.enabled: true in
# aven-config.yaml; the client-side `aven daemon install` step (systemd
# user unit in ~/.config/systemd/user/) should become a declarative
# unit here rather than an imperative install — same for raphael.
#
# Data: one SQLite db per host at ~/.local/state/aven/db.sqlite (plus WAL
# sidecars), preserved below. Repositories map to
# projects (Jira-style IDs); workspaces can route directories. `aven
# doctor` from a directory shows the active db/workspace/project.
#
# Multi-device: E2E-encrypted sync through a self-hosted `aven server`
# (same binary). Topology follows the taskdog precedent — server on jehoel
# behind nginx (aven.otwell.dev), phones pair via the aven mobile apps.
# The server stores ciphertext only; it is NOT a backup.
#
# Agent-side integration (aven skill install --agent pi, the aven-prime.ts
# pi session extension, hermes guidance) is deliberately NOT wired here —
# it belongs to the skills/AGENTS.md backlog (taskdog #138), to land
# together with the gtd-* skill rewrite when taskdog migrates.
#
# One-time imperative step on jehoel (before the service first starts):
#   runuser -u john -- env HOME=/home/john aven server setup \
#     --url https://aven.otwell.dev
# `server setup` prepares the storage with the public URL baked in and
# prints a setup invitation (expires in 1h; re-run for a fresh one when
# the first device — the taskdog migration host — is ready to claim sync).
# Without setup the service restart-loops ("prepare storage with server
# setup first").
{
  inputs,
  ...
}:
{
  flake.nixosModules.aven =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.aven-sync;
      cfg-daemon = config.services.aven-daemon;
      inherit (pkgs.stdenv.hostPlatform) system;
      aven = inputs.llm-agents.packages.${system}.aven;

      domain = "aven.otwell.dev";
    in
    {
      options.services.aven-sync.enable = lib.mkEnableOption "the aven sync server (one host only; jehoel)";
      options.services.aven-daemon.enable = lib.mkEnableOption "the aven client sync daemon (any host paired with aven.otwell.dev)";

      config = lib.mkMerge [
        {
          environment.systemPackages = [ aven ];

          # db.sqlite + WAL sidecars, sync server storage, attachments.
          # Config is NOT here — see the declarative symlink below.
          preservation.preserveAt."/persistent".users.john.directories = [
            ".local/state/aven"
          ];

          # Declarative config: co-located aven-config.yaml → store →
          # ~/.config/aven/config.yaml. Recreated every activation
          # (~/.config is tmpfs), so runtime config writes never outlive
          # a switch.
          system.activationScripts.aven-config.text = ''
            install -d -m 700 -o john -g users /home/john/.config/aven
            ln -sfn ${./aven-config.yaml} /home/john/.config/aven/config.yaml
            chown -h john:users /home/john/.config/aven/config.yaml
          '';
        }

        (lib.mkIf cfg.enable {
          # User service like taskdog-server (linger is on for john, so it
          # starts at boot). No StateDirectory=: as a user unit HOME is set,
          # so storage lands at ~/.local/state/aven/server/sync-server.sqlite
          # — the exact path `aven server setup` writes from john's shell.
          systemd.user.services.aven-sync = {
            description = "Aven sync server (E2E-encrypted task sync)";
            after = [ "network.target" ];
            wantedBy = [ "default.target" ];
            serviceConfig = {
              ExecStart = "${aven}/bin/aven server --bind 127.0.0.1:3746";
              Restart = "on-failure";
              RestartSec = "5";
            };
          };

          # Upstream nginx guidance (aventasks.dev/sync/setup): encrypted
          # image chunks and bootstrap batches up to 4 MiB plus framing, and
          # proxy timeouts above aven's 35s request deadline.
          services.nginx.virtualHosts."${domain}" = lib.mkIf config.services.nginx.enable {
            forceSSL = true;
            enableACME = true;
            locations."/.well-known/acme-challenge".root = "/var/lib/acme/acme-challenge";
            locations."/" = {
              proxyPass = "http://127.0.0.1:3746";
              extraConfig = ''
                client_max_body_size 8m;
                proxy_send_timeout 40s;
                proxy_read_timeout 40s;
              '';
            };
          };
        })
        # Client-side background sync — declarative replacement for
        # `aven daemon install` (which writes ~/.config/systemd/user/
        # aven-daemon.service imperatively; unit shape mirrored from it:
        # Restart=always/30s, no start limit, default.target). Requires
        # sync.enabled=true in aven-config.yaml and a paired database
        # (`aven sync setup`); enable per host as it pairs.
        (lib.mkIf cfg-daemon.enable {
          systemd.user.services.aven-daemon = {
            description = "Aven sync daemon";
            after = [ "network.target" ];
            wantedBy = [ "default.target" ];
            startLimitIntervalSec = 0;
            serviceConfig = {
              ExecStart = "${aven}/bin/aven daemon";
              Restart = "always";
              RestartSec = "30";
            };
          };
        })
      ];
    };
}
