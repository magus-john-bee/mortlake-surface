# Shared nix-on-droid base for uriel (GrapheneOS Pixel 9 Pro) and
# remiel (Viture Pro Neckband). Host configuration.nix files carry
# only identity deltas on top of droidCommon.
#
# nix-on-droid has no nix.settings — flat options instead, and the
# listOf ones merge with the module defaults (cache.nixos.org and
# nix-on-droid.cachix.org survive).
{ self, ... }:
{
  flake.nixOnDroidModules.droidCommon =
    { pkgs, ... }:
    {
      environment = {
        packages = with pkgs; [
          vim
          git
          openssh
          python3
          yq
          android-tools # self-provisioning via ADB
          fdroidcl # self-provisioning via F-Droid
          neovim
          fzf
          bat
          fd
          ripgrep
          tmux
          gnupg
          pass
        ];

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

      # Use the same binary caches as the mortlake NixOS hosts (nix-qol.nix).
      # numtide serves aarch64 for the llm-agents.nix packages (pi, herdr).
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
