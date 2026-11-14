let
  baseDomain = "otwell.dev";
  mealiePort = 9000;
in
_: {
  flake.nixosModules.mealie = { lib, ... }: {
    services.mealie = {
      enable = true;
      port = mealiePort;
      settings = {
        BASE_URL = "mealie.${baseDomain}";
      };
    };

    # Override DynamicUser to run as john:users for /run/secrets access
    # and compatibility with preservation bind-mounts
    systemd.services.mealie.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = lib.mkForce "john";
      Group = lib.mkForce "users";
    };

    # Tailnet-only vhost (transmission.nix pattern): no public DNS
    # record exists (ddclient list) — the name resolves only on the
    # tailnet via split-DNS, and nginx refuses every other source.
    # Mealie has NO proxy/trusted-header auth and no auth-off mode
    # (backends: internal/LDAP/OIDC only) — its own login stays as the
    # app gate on the tailnet path; the public path is dead.
    services.nginx.virtualHosts."mealie.${baseDomain}" = {
      forceSSL = true;
      useACMEHost = "otwell.dev";
      locations."/".proxyPass = "http://localhost:${toString mealiePort}";
      locations."/".extraConfig = ''
        allow 100.64.0.0/10;
        deny all;
      '';
    };

    # Mealie state — service runs as john:users (overridden above) for
    # /run/secrets access and preservation bind-mount compatibility.
    preservation.preserveAt."/persistent".directories = [
      {
        directory = "/var/lib/mealie";
        user = "john";
        group = "users";
      }
    ];
  };
}
