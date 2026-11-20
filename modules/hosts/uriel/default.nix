# Uriel — flake output for the GrapheneOS Pixel 9 Pro.
#
# Same nix-on-droid pattern as remiel: default.nix produces the flake
# output; configuration.nix provides the module as a flake attribute.
{ self, inputs, ... }:
{
  flake.nixOnDroidConfigurations.uriel = inputs.nix-on-droid.lib.nixOnDroidConfiguration {
    pkgs = import inputs.nixpkgs { system = "aarch64-linux"; };
    modules = [ self.nixOnDroidModules.urielConfiguration ];
  };
}
