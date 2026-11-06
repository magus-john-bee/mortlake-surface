# eBay Marketplace Account Deletion endpoint.
#
# Gates the production keyset: eBay won't activate production API keys
# until a "Marketplace Account Deletion/Closure Notifications" endpoint
# passes challenge validation (GDPR-style third-party data deletion
# compliance — see the personal-resale skill for context).
#
# GET  /ebay-deletion?challenge_code=X
#   -> 200 {"challengeResponse": sha256hex(challenge_code + token + endpoint_url)}
#      (concatenation order and the exact URL string are binding)
# POST /ebay-deletion  -> 200, payload+signature logged to the journal
#      (ack fast, review later; for a self-use app the only data
#      subject is the seller themselves)
#
# Same vhost pattern as silverbullet: nginx + ACME in front,
# plain-http service behind. jehoel hosts it (nginx already runs there;
# ssh.otwell.dev pattern is for SSH, not HTTP).
#
# DNS: deletion.otwell.dev points at jehoel's public IP (ddclient).
_: {
  flake.nixosModules.ebayDeletion =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      domain = "deletion.otwell.dev";
      port = 8647;

      # flakeIgnore: the repo formatter is ruff (treefmt.nix); writePython3's
      # build-time flake8 gate enforces stock PEP8, which disagrees with ruff
      # on wrapped lines (E501 length, W503/E203 operator placement). Style
      # is ruff's call here; flake8 still catches everything non-style.
      script = pkgs.writers.writePython3 "ebay-deletion-endpoint" {
        flakeIgnore = [
          "E501"
          "E203"
          "W503"
          "W504"
        ];
      } (builtins.readFile ./ebay_deletion_endpoint.py);
    in
    {
      options.services.ebayDeletion = {
        enable = lib.mkEnableOption "eBay Marketplace Account Deletion endpoint (deletion.otwell.dev)";
      };

      config = lib.mkIf config.services.ebayDeletion.enable {
        sops.secrets.ebay-verification-token = {
          sopsFile = ./secrets.yaml;
        };

        systemd.services.ebay-deletion = {
          description = "eBay Marketplace Account Deletion endpoint";
          after = [ "sops-nix.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            ExecStart = "${script}";
            # systemd (root) copies the root-only sops file into
            # /run/credentials/ owned by the dynamic user — the designed
            # way to hand secrets to DynamicUser services.
            LoadCredential = [
              "ebay-token:${config.sops.secrets.ebay-verification-token.path}"
            ];
            Environment = [
              "EBAY_ENDPOINT_URL=https://${domain}/ebay-deletion"
              "PORT=${toString port}"
              "EBAY_VERIFICATION_TOKEN_FILE=/run/credentials/ebay-deletion.service/ebay-token"
            ];
            DynamicUser = true;
            Restart = "on-failure";
            RestartSec = "5";
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
          };
        };

        # Listing photos dir (tmpfs-root: preservation creates + binds it).
        preservation.preserveAt."/persistent".directories = [
          { directory = "/var/lib/ebay-photos"; }
        ];

        # Public HTTPS entry — same vhost pattern as silverbullet.
        services.nginx.virtualHosts."${domain}" = lib.mkIf config.services.nginx.enable {
          forceSSL = true;
          enableACME = true;
          locations = {
            "/.well-known/acme-challenge".root = "/var/lib/acme/acme-challenge";
            # Listing photos for eBay Sell API imageUrl ingestion (eBay
            # fetches + re-hosts; random filenames, short exposure window).
            "/photos/" = {
              alias = "/var/lib/ebay-photos/";
              extraConfig = ''
                autoindex off;
                gzip off;
              '';
            };
            "/ebay-deletion" = {
              proxyPass = "http://127.0.0.1:${toString port}";
              extraConfig = ''
                proxy_set_header Host $host;
                proxy_read_timeout 30s;
              '';
            };
          };
        };
      };
    };
}
