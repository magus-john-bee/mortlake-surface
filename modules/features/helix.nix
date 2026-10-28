{ self, inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.helix = inputs.wrapper-modules.lib.wrapPackage (
        { config, ... }:
        {
          config = {
            inherit pkgs;
            package = pkgs.helix;

            env.XDG_CONFIG_HOME = dirOf (dirOf config.constructFiles.configToml.path);

            runtimePkgs = [
              pkgs.bash-language-server
              pkgs.shellcheck
            ];

            constructFiles.configToml = {
              content = builtins.readFile ./helix/config.toml;
              relPath = "helix/config.toml";
            };

            constructFiles.languagesToml = {
              content = builtins.readFile ./helix/languages.toml;
              relPath = "helix/languages.toml";
            };
          };
        }
      );
    };

  flake.nixosModules.helix =
    { pkgs, ... }:
    let
      inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) helix;
    in
    {
      environment.systemPackages = [ helix ];
    };
}
