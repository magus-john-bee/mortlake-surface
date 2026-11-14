# Wildcard TLS (*.otwell.dev) via ACME DNS-01 against Porkbun.
#
# Tailnet-only vhosts have no public DNS records, so HTTP-01 cannot
# renew their certs — one DNS-01 wildcard covers every private name
# and keeps each of them out of public DNS and per-name CT logs.
# Vhosts attach via useACMEHost = "otwell.dev".
#
# lego's porkbun provider talks to api.porkbun.com, the actual API
# host (porkbun.com serves the docs but rejects non-GET API calls).
# The API keys are shared with dd-client; the identical secret
# declarations merge.
{
  flake.nixosModules.acme-wildcard =
    { config, ... }:
    let
      baseDomain = "otwell.dev";
      p = config.sops.placeholder;
    in
    {
      sops.secrets = {
        "porkbun-api-key" = {
          owner = "john";
          sopsFile = ./secrets.yaml;
        };
        "porkbun-secret-api-key" = {
          owner = "john";
          sopsFile = ./secrets.yaml;
        };
      };

      # Environment for the root-run lego renewal unit.
      sops.templates."porkbun-acme.env" = {
        content = ''
          PORKBUN_API_KEY=${p.porkbun-api-key}
          PORKBUN_SECRET_API_KEY=${p.porkbun-secret-api-key}
          # Porkbun NS apply quickly; the cap only bounds worst-case
          # first issuance, not steady-state renewals.
          PORKBUN_PROPAGATION_TIMEOUT=1800
          PORKBUN_POLLING_INTERVAL=30
        '';
        mode = "0400";
      };

      # The wildcard covers subdomains only; the apex keeps per-name
      # certs (public records, HTTP-01 works there).
      security.acme.certs."${baseDomain}" = {
        domain = "*.${baseDomain}";
        dnsProvider = "porkbun";
        environmentFile = config.sops.templates."porkbun-acme.env".path;
      };
    };
}
