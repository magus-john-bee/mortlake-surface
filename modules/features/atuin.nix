_: {
  flake.nixosModules.atuin =
    { config, ... }:
    {
      programs.atuin = {
        enable = true;

        # House shell is zsh; the init snippet is evaluated once in
        # zsh/zshrc.zsh INSIDE zvm_after_init — atuin's keybinds must be
        # installed after zsh-vi-mode's or zvm clobbers them. The module's
        # own zsh hook would double-init (it lands in /etc/zshrc, which
        # runs before ZDOTDIR's .zshrc). The module DOES set
        # ATUIN_CONFIG_DIR=/etc/atuin globally — which is what makes the
        # plain pkgs.atuin binary (eval'd by zshrc.zsh at a store path, no
        # wrapper env) read the settings below.
        enableZshIntegration = false;

        # Sync runs via the shell hook (auto_sync + sync_frequency, checked
        # per command); the daemon socket unit would exist but never be
        # used — atuin's own [daemon] enabled defaults to false.
        daemon.enable = false;

        settings = {
          auto_sync = true;
          sync_frequency = "2m";
          search_mode = "fuzzy";
          filter_mode = "global";
          style = "compact";
          keymap_mode = "vim-insert";
          theme.name = "marine";
          sync.records = true;
          key_path = config.sops.secrets."atuin-key".path;
        };
      };

      # One sops secret; login is one-time manual per host (session token
      # persists in meta.db): atuin login -u <user> -k "$(cat /run/secrets/atuin-key)"
      sops.secrets."atuin-key" = {
        owner = "john";
        sopsFile = ./secrets.yaml;
      };

      preservation.preserveAt."/persistent".users.john.directories = [
        ".local/share/atuin"
      ];
    };
}
