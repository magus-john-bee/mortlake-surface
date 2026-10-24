# Collie — mobile PWA over the herdr agent herd (AltanS/collie, llm-agents).
#
# A small Bun bridge serves the PWA + JSON API on loopback:8787 and dials
# herdr's unix socket (~/.config/herdr/herdr.sock — default matches). The
# browser polls /api/snapshot; replies are POSTs that type into live panes.
# Remote shell by design — two independent gates in front: the tailnet
# (both doors are tailnet-only — nginx on the split-DNS name refuses every
# non-tailnet source, and the tailscale serve path on jehoel's ts.net name
# is unreachable off the tailnet) + collie's always-on device pairing.
# Deep dive: docs/agent-tooling-reports/collie.md.
#
# IMPERATIVE (one-time, after first deploy): pair the phone —
#   collie pair    # prints code + QR; phone: Settings → Paired devices
{ inputs, ... }:
{
  flake.nixosModules.collie =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      colliePkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.collie;
    in
    {
      # CLI on PATH for admin verbs (collie pair / devices / doctor) — same
      # single-user shape as herdrPkg in herdr.nix.
      environment.systemPackages = [ colliePkg ];

      # Declarative env (tmpfs home; re-provisioned every activation).
      # Both ingress doors are tailnet-only: nginx on collie.otwell.dev
      # (split-DNS name) and tailscale serve on the ts.net name.
      # Host header must pass through unchanged (see vhost below).
      system.activationScripts.collie-env.text = ''
        install -D -m 0644 -o john -g users /dev/null /home/john/.config/collie/.env
        cat > /home/john/.config/collie/.env <<'EOF'
        COLLIE_SKIP_SERVE=1
        COLLIE_MUX=herdr
        COLLIE_PORT=8787
        COLLIE_PUBLIC_HOSTS=collie.otwell.dev,jehoel.cassowary-mooneye.ts.net
        COLLIE_ALLOWED_ORIGINS=https://collie.otwell.dev,https://jehoel.cassowary-mooneye.ts.net:8443
        COLLIE_PUBLIC_URL=https://jehoel.cassowary-mooneye.ts.net:8443
        EOF
        chown john:users /home/john/.config/collie/.env
      '';

      systemd.user.services.collie = {
        description = "Collie (herdr mobile PWA bridge)";
        wantedBy = [ "default.target" ];
        # Ordering only (no Wants — collie runs fine while herdr is down;
        # it just shows no panes): if the herdr-server unit exists, start
        # after it so the first phone poll sees a dialable socket.
        after = [ "herdr-server.service" ];
        # Upstream unit: a phone-only operator cannot reset a failed unit.
        startLimitIntervalSec = 0;
        serviceConfig = {
          Type = "simple";
          WorkingDirectory = "${colliePkg}/lib/collie";
          ExecStart = "${colliePkg}/bin/collie _exec-bridge";
          # leading '-': an absent .env is not fatal (upstream unit semantics)
          EnvironmentFile = "-%h/.config/collie/.env";
          Restart = "on-failure";
          RestartSec = "5";
          NoNewPrivileges = true;
          PrivateTmp = true;
        };
      };

      # Pairing tokens + audit log must survive reboots (else re-pair every
      # boot). Dir-level only — no per-file bind mounts (herdr plugins.json
      # rename lesson).
      preservation.preserveAt."/persistent".users.john.directories = [
        ".local/state/collie"
        ".config/collie"
      ];

      # Tailnet-only vhost (transmission.nix pattern): collie.otwell.dev
      # carries no public DNS record (ddclient list) — it resolves only on
      # the tailnet via split-DNS (tailnet-dns.nix), and nginx refuses every
      # other source outright. TLS is the wildcard DNS-01 cert. The tailnet
      # gate IS the auth — pairing still guards the bridge itself.
      services.nginx.virtualHosts."collie.otwell.dev" = lib.mkIf config.services.nginx.enable {
        forceSSL = true;
        useACMEHost = "otwell.dev";
        locations."/" = {
          proxyPass = "http://127.0.0.1:8787";
          extraConfig = ''
            # nginx.nix's recommendedProxySettings include already sets
            # Host $host + X-Forwarded-For/Proto in this location. Re-declaring
            # any of them here sends DUPLICATE headers; Bun joins duplicate
            # Host values ("a.example, a.example"), which fails collie's
            # host allowlist.
            client_max_body_size 25m;
            allow 100.64.0.0/10;
            deny all;
          '';
        };
      };
    };
}
