{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options = {
    # nix-on-droid outputs aren't known to flake-parts. The `flake` submodule's
    # freeformType is `unique raw`, so an undeclared output can only be defined
    # once — each phone config (uriel/remiel) defining its own chunk
    # would collide. Declaring them as `lazyAttrsOf raw` (like flake-parts does
    # for nixosConfigurations) lets the module system merge across files.
    flake.nixOnDroidModules = mkOption {
      type = types.lazyAttrsOf types.raw;
      default = { };
    };

    flake.nixOnDroidConfigurations = mkOption {
      type = types.lazyAttrsOf types.raw;
      default = { };
    };
  };

  config.systems = [
    "x86_64-linux"
    "aarch64-linux"
    "aarch64-darwin"
  ];
}
