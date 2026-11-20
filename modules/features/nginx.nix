_: {
  flake.nixosModules.nginx = _: {
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      commonHttpConfig = ''
        # Tailnet-source flag for identity-header injection (remote
        # auth consumers: jellyfin today, auth-parity vhosts later).
        # 100.64.0.0/10 is the Tailscale CGNAT range.
        geo $tailnet_source {
          default 0;
          100.64.0.0/10 1;
        }
      '';
    };

    # Nginx uses PrivateTmp which needs /tmp to exist as a mount point.
    # On tmpfs-root systems, /tmp is bind-mounted from /persistent by
    # preservation.target, which may not be ready during nixos-rebuild switch.
    systemd.services.nginx = {
      after = [ "tmp.mount" ];
      requires = [ "tmp.mount" ];
    };

    security.acme = {
      acceptTerms = true;
      defaults = {
        email = "johnbee@otwell.dev";
        group = "nginx";
      };
    };
  };
}
