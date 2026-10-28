{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.myNoctalia = inputs.wrapper-modules.wrappers.noctalia-shell.wrap {
        inherit pkgs;
        # v4 left nixpkgs 2026-10-22; pulled from the frozen pin in
        # flake.nix until the v5 (rewrite) migration lands.
        package = inputs.nixpkgs-noctalia.legacyPackages.${pkgs.stdenv.hostPlatform.system}.noctalia-shell;
        settings =
          if builtins.pathExists ./noctalia/config.json then
            (builtins.fromJSON (builtins.readFile ./noctalia/config.json)).settings
          else
            { };
      };
    };
}
