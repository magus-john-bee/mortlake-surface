# Radicle — private canonical node on jehoel (aven RDC-JPT3, openspec
# provision-radicle-node).
#
# Topology: radicle-node (P2P replication, port 8776, LAN/tailnet reachable,
# never port-forwarded — outbound-only behind home NAT) + radicle-httpd
# (read-only HTTP API on loopback) behind the rad.otwell.dev vhost, which is
# tailnet-only. httpd serves a read-only view of EVERYTHING the node tracks,
# so it must never be exposed beyond the tailnet; external collaboration is
# seed-mediated and out of scope for this module.
#
# Identity: the key pair lives in ~/.radicle (preserved + restic-backed);
# the passphrase that protects it reaches the node non-interactively via
# RAD_PASSPHRASE. nixpkgs marks radicle-node insecure (inter-node traffic is
# unencrypted/unauthenticated — upstream protocol state); permitted in
# modules/hosts/jehoel/default.nix for this tailnet-only, outbound-only use.
{
  flake.nixosModules.radicle =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      httpdPort = 8080;
    in
    {
      # The derivation ships rad, radicle-node, and git-remote-rad; the
      # daemon ExecStarts pin the same package.
      environment.systemPackages = [ pkgs.radicle-node ];

      sops.secrets."radicle-passphrase" = {
        sopsFile = ./secrets.yaml;
      };

      # EnvironmentFile content must be KEY=value lines; the raw secret is
      # just the passphrase, so it goes through a template.
      sops.templates."radicle-node-env".content = ''
        RAD_PASSPHRASE=${config.sops.placeholder."radicle-passphrase"}
      '';

      systemd.services.radicle-node = {
        description = "Radicle node — P2P replication and sync (private canonical)";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        environment.RAD_HOME = "/home/john/.radicle";
        serviceConfig = {
          User = "john";
          Group = "users";
          ExecStart = "${pkgs.radicle-node}/bin/radicle-node --log-logger systemd";
          EnvironmentFile = [ config.sops.templates."radicle-node-env".path ];
          Restart = "on-failure";
        };
      };

      systemd.services.radicle-httpd = {
        description = "Radicle HTTP API — read-only view of node storage";
        after = [ "radicle-node.service" ];
        wantedBy = [ "multi-user.target" ];
        environment.RAD_HOME = "/home/john/.radicle";
        serviceConfig = {
          User = "john";
          Group = "users";
          ExecStart = "${pkgs.radicle-httpd}/bin/radicle-httpd --listen 127.0.0.1:${toString httpdPort}";
          Restart = "on-failure";
        };
      };

      # DID key, node database, and tracked repo storage — everything the
      # identity depends on.
      preservation.preserveAt."/persistent".users.john.directories = [ ".radicle" ];

      # Tailnet-only vhost (sb.otwell.dev pattern): no public DNS record, so
      # the name resolves only via tailnet split-DNS; nginx refuses every
      # other source. The tailnet IS the boundary.
      services.nginx.virtualHosts."rad.otwell.dev" = lib.mkIf config.services.nginx.enable {
        forceSSL = true;
        useACMEHost = "otwell.dev";
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString httpdPort}";
          extraConfig = ''
            allow 100.64.0.0/10;
            deny all;
          '';
        };
      };

      # IMPERATIVE (once, after this module first activates and services are
      # running): bootstrap the radicle identity and private-canonical policy.
      # 1. File the passphrase (sops key `radicle-passphrase`) in Keepass —
      #    losing it orphans the restic-backed key pair.
      # 2. Create the identity:
      #      RAD_PASSPHRASE="$(sops -d --extract '["radicle-passphrase"]' \
      #        modules/features/secrets.yaml)" rad auth --alias jehoel
      # 3. Private-canonical policy — only explicitly tracked repos replicate:
      #      rad config set node.policy block
      #    (or `rad config edit` on older CLIs)
      # 4. Verify: `rad self` resolves the DID; `rad config get node.policy`
      #    reports block.
    };
}
