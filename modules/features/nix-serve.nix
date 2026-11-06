# Nix binary cache server using nix-serve behind nginx with HTTPS.
#
# Server-side only — import on the cache host (jehoel). Clients (raphael)
# get the substituter from nix-qol.nix and the public key only.
#
# The signing key pair must be generated before building. Run once:
#
#   nix-store --generate-binary-cache-key cache.otwell.dev \
#     /tmp/cache-private-key.pem /tmp/cache-public-key.pem
#
# The private key lives in secrets.yaml under "nix-serve-private-key".
#
# Alternatives if nix-serve proves insufficient:
#   - nix-serve-ng: drop-in Haskell replacement, faster
#   - Attic: feature-rich (dedup, GC, token auth, multi-tenant, S3-backed)
#   - Harmonia: Rust-based, fast, simple
#
# The cache host does NOT list cache.otwell.dev among its own substituters —
# nix-qol.nix skips it when services.nix-serve.enable is true. Its store
# already backs the cache, so querying itself is pure overhead and a local
# nginx/ACME hiccup would become a nix failure mode on the build host.
# Other substituters (cache.numtide.com via nix-qol.nix) are unaffected.
let
  cacheDomain = "cache.otwell.dev";
in
{
  flake.nixosModules.nix-serve =
    { config, ... }:
    {
      services.nix-serve = {
        enable = true;
        secretKeyFile = config.sops.secrets."nix-serve-private-key".path;
      };

      # Private signing key — rendered from sops at activation time.
      # Stored in secrets.yaml (encrypted for jehoel + raphael — cache host
      # and build host only; clients only need the PUBLIC key in nix.conf).
      sops.secrets."nix-serve-private-key" = {
        sopsFile = ./secrets.yaml;
      };

      # HTTPS reverse proxy via nginx + Let's Encrypt ACME.
      services.nginx.virtualHosts."${cacheDomain}" = {
        forceSSL = true;
        enableACME = true;
        locations."/.well-known/acme-challenge".root = "/var/lib/acme/acme-challenge";
        locations."/".proxyPass =
          "http://${config.services.nix-serve.bindAddress}:${toString config.services.nix-serve.port}";
      };

      # Allow `nix copy --to ssh://john@jehoel` from client machines.
      # Required for the post-build hook to push paths to this cache
      # (see raphael/configuration.nix for the client side).
      nix.settings.trusted-users = [ "john" ];
    };
}
