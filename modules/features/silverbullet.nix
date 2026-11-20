# SilverBullet — self-hosted PKM web app (https://silverbullet.md).
#
# Topology: loopback service on 127.0.0.1:3000 behind the sb.otwell.dev
# nginx vhost (nginx + ACME in front), on jehoel since the
# retired-Hetzner-VPS cutover.
# Auth: NONE — no SB_USER, no SB_AUTH_TOKEN (silverbullet serves with
# no login screen when no credentials are set). The vhost is
# tailnet-only (no public DNS record; nginx refuses non-tailnet
# sources), and the space is also restic-backed. Agents hitting the
# HTTP API need no Bearer token from the tailnet/loopback.
#
# Space: plain markdown at /home/john/vault/sb — inside the vault bind
# mount, which is already tmpfs-persisted and restic-backed. vault/sb
# is a standalone git repo (hand-pushed fallback mirror at the magus
# account; no automation). The service runs as john so it can read and
# write the home-dir space natively.
let
  port = 3000;
  spaceDir = "/home/john/vault/sb";
in
_: {
  flake.nixosModules.silverbullet =
    {
      config,
      lib,
      ...
    }:
    {
      services.silverbullet = {
        enable = true;
        listenAddress = "127.0.0.1";
        listenPort = port;
        inherit spaceDir;
        user = "john";
        group = "users";
      };

      # Tailnet-only vhost: no public DNS record (ddclient list) — the
      # name resolves only on the tailnet via split-DNS, and nginx
      # refuses every other source outright. The tailnet IS the auth.
      # nginx vhost — sb.otwell.dev (WebSocket proxy to loopback:3000).
      #
      services.nginx.virtualHosts."sb.otwell.dev" = lib.mkIf config.services.nginx.enable {
        forceSSL = true;
        useACMEHost = "otwell.dev";
        locations."/" = {
          proxyPass = "http://127.0.0.1:3000";
          proxyWebsockets = true;
          extraConfig = ''
            allow 100.64.0.0/10;
            deny all;
          '';
        };
      };

      # No preservation entry needed: the space lives at /home/john/vault/sb,
      # already covered by the vault bind mount (see john.nix / dev-dirs.nix).
    };
}
