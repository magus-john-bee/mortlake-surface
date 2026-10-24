{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.myNoctalia = inputs.wrapper-modules.wrappers.noctalia-shell.wrap {
        inherit pkgs;
        settings =
          if builtins.pathExists ./noctalia/config.json then
            (builtins.fromJSON (builtins.readFile ./noctalia/config.json)).settings
          else
            { };
      };
    };
}
