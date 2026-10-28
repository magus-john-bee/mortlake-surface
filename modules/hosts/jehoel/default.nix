{ self, inputs, ... }:
let
  pkgs = import inputs.nixpkgs {
    system = "x86_64-linux";
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [
        "electron-39.8.10"
        # Inter-node traffic is unencrypted/unauthenticated (upstream
        # protocol state, no fixed version exists); accepted for the
        # tailnet-only, outbound-only private canonical — rationale in
        # openspec provision-radicle-node design.md.
        "radicle-node-1.10.3"
      ];
    };
  };
in
{
  flake.nixosConfigurations.jehoel = inputs.nixpkgs.lib.nixosSystem {
    inherit pkgs;
    modules = [ self.nixosModules.jehoelConfiguration ];
  };
}
