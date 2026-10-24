{ self, inputs, ... }:
let
  pkgs = import inputs.nixpkgs {
    system = "x86_64-linux";
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [ "electron-39.8.10" ];
    };
  };
in
{
  flake.nixosConfigurations.jehoel = inputs.nixpkgs.lib.nixosSystem {
    inherit pkgs;
    modules = [ self.nixosModules.jehoelConfiguration ];
  };
}
