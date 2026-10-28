{ self, ... }:
{
  flake.nixosModules.raphaelConfiguration =
    {
      pkgs,
      lib,
      ...
    }:
    {
      imports = [
        self.nixosModules.raphaelHardware
        self.nixosModules.raphaelDisko
        self.nixosModules.preservation-common
        self.nixosModules.dev-dirs
        self.nixosModules.john
        self.nixosModules.clock
        self.nixosModules.network
        self.nixosModules.packages
        self.nixosModules.the-aether
        self.nixosModules.nix-qol
        self.nixosModules.nrs
        self.nixosModules.sops
        self.nixosModules.gh
        self.nixosModules.git
        self.nixosModules.zsh
        self.nixosModules.atuin
        self.nixosModules.intellishell
        self.nixosModules.helix
        self.nixosModules.zellij
        self.nixosModules.nerd-fonts
        self.nixosModules.niri
        self.nixosModules.greetd
        self.nixosModules.ghostty
        self.nixosModules.chromium
        self.nixosModules.nyxt
        self.nixosModules.keepass
        self.nixosModules.syncthing-follow
        # AI tooling
        self.nixosModules.pi
        self.nixosModules.herdr
        self.nixosModules.aven
        self.nixosModules.td
      ];

      services = {

      };

      networking = {
        hostName = "raphael";
        useDHCP = lib.mkDefault true;
        networkmanager.enable = true;
      };

      environment.systemPackages = with pkgs; [
        grim
        slurp
      ];

      preservation.preserveAt."/persistent" = {
        directories = [
          "/etc/NetworkManager/system-connections"
          "/var/lib/bluetooth"
        ];

        # Host-specific home content (jehoel persists `data` the same way).
        # src/vault come from dev-dirs.nix; reference-repos exists only on
        # this host (June-era, already on the persistent subvol).
        users.john.directories = [ "reference-repos" ];
      };

      nix.settings.post-build-hook =
        let
          hook = pkgs.writeShellScript "push-to-cache" ''
            ${pkgs.nix}/bin/nix copy --to ssh://john@jehoel $OUT_PATHS || true
          '';
        in
        "${hook}";

      system.stateVersion = "25.11";
    };
}
