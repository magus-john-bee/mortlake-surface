# DDNS client — Porkbun. Only active subdomains.
let
  baseDomain = "otwell.dev";
  secrets-opts = {
    owner = "john";
    sopsFile = ./secrets.yaml;
  };
in
{
  flake.nixosModules.dd-client =
    { config, ... }:
    let
      p = config.sops.placeholder;
    in
    {
      sops.secrets = {
        "porkbun-api-key" = secrets-opts;
        "porkbun-secret-api-key" = secrets-opts;
      };

      sops.templates."porkbun-ddclient.conf" = {
        content = ''
          apikey=${p.porkbun-api-key}
          secretapikey=${p.porkbun-secret-api-key}
        '';
        mode = "0400";
        owner = "john";
      };

      services.ddclient = {
        enable = true;
        protocol = "porkbun";
        interval = "5min";
        # We are IPv4-only: the v6 default creates failure noise
        usev6 = "disabled";
        # After a failed update attempt, ddclient skips retries until
        # min-error-interval (default 5m) expires. With a 5m timer that gate
        # races every run, so a failing update pattern wedges itself: retry
        # failures quickly instead.
        extraConfig = "min-error-interval=30s";
        # Only names that carry public DNS records — tailnet-only names
        # are gone from public DNS (their TLS is the wildcard DNS-01
        # cert); ddclient would fail on them every run ("no applicable
        # existing records").
        domains = [
          "ssh.${baseDomain}"
          "cache.${baseDomain}"
          "jehoel.${baseDomain}"
          "deletion.${baseDomain}"
        ];
        secretsFile = config.sops.templates."porkbun-ddclient.conf".path;
      };
    };
}
