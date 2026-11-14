{ self, inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.ghostty = inputs.wrapper-modules.lib.wrapPackage (
        { config, ... }:
        {
          config = {
            inherit pkgs;
            package = pkgs.ghostty;

            flags."--config-file" = {
              sep = "=";
              data = config.constructFiles.configFile.path;
            };

            constructFiles.configFile = {
              content = builtins.readFile ./ghostty/config.ghostty;
              relPath = "ghostty/config";
            };
          };
        }
      );
    };

  flake.nixosModules.ghostty =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) ghostty;

      # Per-host config overlays, layered on top of the shared baked config.
      # The wrapped package's config.ghostty ends with
      #   config-file = ?/etc/ghostty/host.ghostty
      # (optional include — silently skipped on hosts with no overlay), and
      # later files override earlier ones, so these win.
      hostConfig = {
        jehoel = ./ghostty/jehoel.host.ghostty;
      };
      hostOverlay = hostConfig.${config.networking.hostName} or null;
    in
    {
      environment.systemPackages = [ ghostty ];

      environment.etc = lib.optionalAttrs (hostOverlay != null) {
        "ghostty/host.ghostty".source = hostOverlay;
      };
    };
}
