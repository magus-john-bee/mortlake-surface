# Utility scripts exposed as flake packages — `nix run .#<name>`.
# Each script is wrapped with writeShellApplication for proper PATH handling.
_: {
  perSystem =
    { pkgs, ... }:
    {
      packages = {
        # Print this machine's sops age public key (derived from SSH host key)
        get-age-key = pkgs.writeShellApplication {
          name = "get-age-key";
          runtimeInputs = [ pkgs.ssh-to-age ];
          text = builtins.readFile ../scripts/get-age-key.sh;
        };

        # Re-encrypt all sops secret files after updating .sops.yaml
        update-sops-keys = pkgs.writeShellApplication {
          name = "update-sops-keys";
          runtimeInputs = [ pkgs.sops ];
          text = builtins.readFile ../scripts/update-sops-keys.sh;
        };

        # Find and resolve Syncthing .sync-conflict files interactively
        stconflict = pkgs.writeShellApplication {
          name = "stconflict";
          runtimeInputs = [ pkgs.delta ];
          text = builtins.readFile ../scripts/stconflict.sh;
        };
      };
    };
}
