{ self, ... }:
{
  flake.nixosModules.jehoelConfiguration =
    { pkgs, lib, ... }:
    {
      imports = [
        self.nixosModules.jehoelHardware
        self.nixosModules.jehoelDisko
        self.nixosModules.preservation-common
        self.nixosModules.clock
        self.nixosModules.network
        self.nixosModules.packages
        self.nixosModules.john
        self.nixosModules.nix-qol
        self.nixosModules.nrs
        self.nixosModules.sops
        self.nixosModules.gh
        self.nixosModules.git
        self.nixosModules.funes
        self.nixosModules.gno
        self.nixosModules.zsh
        self.nixosModules.atuin
        self.nixosModules.intellishell
        self.nixosModules.helix
        self.nixosModules.zellij
        self.nixosModules.dev-dirs
        self.nixosModules.restic
        self.nixosModules.nerd-fonts

        # Server role
        self.nixosModules.nginx
        self.nixosModules.jellyfin
        self.nixosModules.transmission
        self.nixosModules.mealie
        self.nixosModules.syncthing-lead
        self.nixosModules.dd-client
        # Wildcard *.otwell.dev cert (DNS-01/Porkbun) for tailnet-only
        # vhosts — private names have no public DNS records, so HTTP-01
        # renewal is impossible for them.
        self.nixosModules.acme-wildcard
        self.nixosModules.nix-serve

        # Desktop role
        self.nixosModules.niri
        self.nixosModules.greetd
        self.nixosModules.ghostty
        self.nixosModules.chromium
        self.nixosModules.nyxt
        self.nixosModules.keepass
        self.nixosModules.email
        self.nixosModules.sound
        self.nixosModules.printing

        # AI tooling
        self.nixosModules.pi
        # pi memory against the shared gno store (recall injection +
        # gno_remember); inert without services.gno below.
        self.nixosModules.pi-gno
        self.nixosModules.herdr
        self.nixosModules.taskdog
        # aven (taskdog successor; migration pending) + td (per-repo
        # session handoff) — from llm-agents.nix. Agent-side integration
        # (skill install, prime extension) is the skills/AGENTS backlog
        # (taskdog #138).
        self.nixosModules.aven
        self.nixosModules.td
        # Agent CLI tooling from llm-agents.nix: codegraph, chub
        # (context-hub), openspec, plannotator(+tui). See
        # modules/features/agent-tools.nix for the per-tool rationale.
        self.nixosModules.agent-tools
        # jj-first VCS: wrapped with /etc/jj/config.toml identity (jj does
        # not read the wrapped git config; ~/.config/jj is tmpfs).
        self.nixosModules.jj
        # Collie — mobile PWA over the herdr herd (collie.otwell.dev):
        # loopback bridge + nginx basic-auth vhost; phone pairs once.
        self.nixosModules.collie
        # Tailscale mesh — collie's tailnet ingress replaces the public path.
        self.nixosModules.tailscale
        self.nixosModules.tailnet-dns
        self.nixosModules.silverbullet

        # Hermes + ebay-deletion (decommission runbook:
        # docs/uriel-decommission-tasker-heartbeat.md).
        self.nixosModules.hermes
        self.nixosModules.ebayDeletion
      ];

      services = {

        # Taskdog: server + client on jehoel (taskdog.otwell.dev).
        # SilverBullet likewise (sb.otwell.dev).
        taskdog = {
          client.enable = true;
          server.enable = true;
        };

        # IMPERATIVE (one-time, already done 2026-10-19): aven sync server
        # bootstrap before first start:
        #   runuser -u john -- env HOME=/home/john aven server setup \
        #     --url https://aven.otwell.dev
        aven-sync.enable = true;

        # Client daemon: jehoel is the first paired device (the taskdog
        # migration host); raphael enables this when it pairs.
        aven-daemon.enable = true;

        hermes-agent.enable = true;
        ebayDeletion.enable = true;
      };

      networking = {
        hostName = "jehoel";
        useDHCP = lib.mkDefault true;
        networkmanager.enable = true;
      };

      networking.firewall.allowedTCPPorts = [
        22
        80
        443
      ];

      environment.systemPackages = with pkgs; [
        ffmpeg
        yt-dlp
        magic-wormhole
      ];

      # TV output toggles for the phantom HDMI display (fiber HDMI holds HPD
      # forever; niri keeps it off at startup by EDID — see niri.nix). The
      # niri IPC socket name changes each session, so resolve it at runtime.
      # Audio is unaffected either way (HDMI sink is independent of the niri
      # output state — verified live with playback during output-off).
      # CAVEAT: these hardcode the connector name — `niri msg` cannot match
      # by EDID. If the bar ever moves to a different connector, update the
      # name here (check `niri msg outputs`); the startup default in niri.nix
      # is EDID-matched and immune.
      environment.shellAliases =
        let
          niriMsg = "niri msg";
          withSocket = ''NIRI_SOCKET="$(ls -t /run/user/$(id -u)/niri.*.sock 2>/dev/null | head -1)" XDG_RUNTIME_DIR=/run/user/$(id -u) ${niriMsg}'';
        in
        {
          tv-is-on = "${withSocket} output HDMI-A-1 on";
          tv-is-off = "${withSocket} output HDMI-A-1 off";
        };

      preservation.preserveAt."/persistent" = {
        directories = [
          "/var/lib/bluetooth"
          "/var/lib/acme"
          "/var/lib/nginx"
          # Hermes state (sessions, cron jobs, skills, memory) — pre-staged
          # for the cutover; hermes-state-sync fills it at migration time.
          "/var/lib/hermes"
          "/etc/NetworkManager/system-connections"
        ];

        users.john.directories = [ "data" ];
      };

      # No post-build-hook here: this host RUNS the cache (nix-serve reads
      # straight from the local store), so pushing to itself is a no-op that
      # just burns an SSH round-trip (and fails host-key verification) per
      # build. Clients (raphael, thoth) push here; jehoel only serves.

      system.stateVersion = "25.11";
    };
}
