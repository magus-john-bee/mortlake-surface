{ self, inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.zellij = inputs.wrapper-modules.lib.wrapPackage (
        { config, ... }:
        {
          config = {
            inherit pkgs;
            package = pkgs.zellij;

            env.ZELLIJ_CONFIG_DIR = dirOf config.constructFiles.mainConfig.path;

            constructFiles = {
              mainConfig = {
                content = builtins.readFile ./zellij/config.kdl;
                relPath = "zellij/config.kdl";
              };
              defaultLayout = {
                content = builtins.readFile ./zellij/layouts/default.kdl;
                relPath = "zellij/layouts/default.kdl";
              };
              devLayout = {
                content = builtins.readFile ./zellij/layouts/dev.kdl;
                relPath = "zellij/layouts/dev.kdl";
              };
            };
          };
        }
      );
    };

  flake.nixosModules.zellij =
    { pkgs, ... }:
    let
      inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) zellij;
    in
    {
      environment.systemPackages = [ zellij ];
    };
}
