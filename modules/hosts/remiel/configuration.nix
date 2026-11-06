# Remiel — Viture Pro Neckband (near-vanilla Android, Play present)
#
# XR neckband computer (Android, Snapdragon XR2). Shares the same base
# nix-on-droid userspace as uriel.
# Exposed as flake.nixOnDroidModules.remielConfiguration so that import-tree
# evaluates this file as a flake-parts module.
{ self, ... }:
{
  flake.nixOnDroidModules.remielConfiguration =
    { pkgs, ... }:
    let
      # Shared base — keep in sync with uriel
      basePackages = with pkgs; [
        vim
        git
        openssh
        python3
        yq
        android-tools
        fdroidcl
        neovim
        fzf
        bat
        fd
        ripgrep
        tmux
      ];
    in
    {
      environment = {
        packages =
          basePackages
          ++ (with pkgs; [
            gnupg
            pass
          ]);

        # Shared aliases + pinned host keys + keep-alive — single source
        # of truth in modules/features/ssh-aliases.nix.
        etc = {
          "ssh/ssh_config".text = self.sshClient.configText;
          "ssh/ssh_known_hosts".text = self.sshClient.knownHostsText;
          "profile.d/nix-editor.sh".text = ''
            export EDITOR=nvim
            export NIX_REMOTE=daemon
          '';
        };
      };

      # nix-on-droid has no nix.settings — flat options instead, and
      # the listOf ones merge with the module defaults (cache.nixos.org
      # and nix-on-droid.cachix.org survive).
      nix = {
        extraOptions = ''
          experimental-features = nix-command flakes
        '';
        substituters = [
          "https://cache.otwell.dev"
          "https://cache.numtide.com"
        ];
        trustedPublicKeys = [
          "cache.otwell.dev:1uNVs/iKY7NnLUcSoS++Zl2+iWl9qw1VuC0Fa5Lkt4I="
          "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        ];
      };

      system.stateVersion = "24.05";
    };
}
