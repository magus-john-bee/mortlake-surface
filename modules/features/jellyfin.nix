# Jellyfin media server at https://jellyfin.otwell.dev (wildcard ACME
# cert) with LAN-direct access on :8096.
#
# Tailnet auto-login: the RemoteAuth plugin (BlackDark, pinned) trusts
# identity headers that nginx injects for tailnet-source requests only
# — the tailnet is the authentication boundary; the vhost is tailnet-only
# (no public DNS record, nginx refuses every other source — see
# ./jellyfin/tailnet-sso.conf). Password login stays available for
# direct clients on LAN :8096 (Infuse and friends).
let
  baseDomain = "otwell.dev";
  jellyfinPort = 8096;
in
{
  flake.nixosModules.jellyfin =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      # Plugin dll + meta.json from the upstream release zip. Jellyfin
      # loads plugins from a plugins/<Name>/ subdirectory and rewrites
      # meta.json at load, so both are installed as writable copies.
      remoteAuth = pkgs.fetchzip {
        url = "https://github.com/BlackDark/jellyfin-plugin-remoteauth/releases/download/v2.0.0/remote-auth_2.0.0.0.zip";
        stripRoot = false;
        hash = "sha256-FvoZG+YBVjbvsnqGEs7M+3uhyGf1MnfhZB2FreyRWAU=";
      };

      p = config.sops.placeholder;

      # Plugin config template: ./jellyfin/remoteauth.xml with the
      # shared secret spliced in (nginx sends the same value).
      remoteAuthXml = lib.replaceStrings [ "@REMOTEAUTH_SECRET@" ] [ p.jellyfin-remoteauth-secret ] (
        builtins.readFile ./jellyfin/remoteauth.xml
      );

      # Installs plugin, plugin config, and the login-screen SSO button
      # (branding) on every start — dashboard edits revert on restart.
      # Runs as the service user; all target paths are john-owned.
      remoteAuthInstall = pkgs.writeShellScript "jellyfin-remoteauth-install" ''
        set -eu
        mkdir -p /var/lib/jellyfin/plugins/RemoteAuth \
                 /var/lib/jellyfin/plugins/configurations \
                 /var/lib/jellyfin/config
        install -m 0644 "${remoteAuth}/Jellyfin.Plugin.RemoteAuth.dll" \
          /var/lib/jellyfin/plugins/RemoteAuth/Jellyfin.Plugin.RemoteAuth.dll
        install -m 0644 "${remoteAuth}/meta.json" \
          /var/lib/jellyfin/plugins/RemoteAuth/meta.json
        install -m 0600 "${config.sops.templates."jellyfin-remoteauth.xml".path}" \
          /var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.RemoteAuth.xml
        install -m 0600 ${./jellyfin/branding.xml} \
          /var/lib/jellyfin/config/branding.xml
      '';
    in
    {
      sops = {
        secrets."jellyfin-remoteauth-secret" = {
          owner = "john";
          sopsFile = ./secrets.yaml;
        };

        templates."jellyfin-remoteauth.xml" = {
          content = remoteAuthXml;
          owner = "john";
          mode = "0400";
          restartUnits = [ "jellyfin.service" ];
        };

        # Consumed via nginx `include` by ./jellyfin/tailnet-sso.conf.
        # The nginx group bit is required: the nginx config test runs
        # as the nginx user, not root.
        templates."jellyfin-remoteauth-nginx.conf" = {
          content = ''set $remoteauth_secret "${p.jellyfin-remoteauth-secret}";'';
          group = "nginx";
          mode = "0440";
          restartUnits = [ "nginx.service" ];
        };
      };

      networking.firewall.allowedTCPPorts = [ jellyfinPort ]; # LAN direct

      services.jellyfin = {
        enable = true;
        user = "john";
        group = "users";
      };

      systemd.services.jellyfin.serviceConfig.ExecStartPre = [ "${remoteAuthInstall}" ];

      services.nginx.virtualHosts."jellyfin.${baseDomain}" = {
        forceSSL = true;
        useACMEHost = "otwell.dev";
        locations."/".proxyPass = "http://localhost:${toString jellyfinPort}";
        locations."/".extraConfig = builtins.readFile ./jellyfin/tailnet-sso.conf;
      };

      preservation.preserveAt."/persistent".directories = [
        {
          directory = "/var/lib/jellyfin";
          user = "john";
          group = "users";
        }
      ];
    };
}
