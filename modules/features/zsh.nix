{ self, inputs, ... }:
{
  # --- perSystem: build derivations (runs per-architecture) ---
  #
  # Why perSystem and flake.nixosModules both?
  # - perSystem gives us `nix run .#zsh` — a self-contained zsh with plugins bundled via wrapper-modules.
  # - flake.nixosModules installs zsh system-wide as the login shell.
  # Both need the same ZDOTDIR (custom .zshrc), so the zdotdir derivation is built here in perSystem
  # and exposed as a package so the NixOS module can reference it via self.packages.${pkgs.system}.
  # (self' is NOT available inside flake.nixosModules — that's a flake-parts constraint.)
  perSystem =
    { pkgs, lib, ... }:
    let
      # replaceVars substitutes @var@ placeholders in zshrc.zsh with nix store paths.
      # Any @name@ in the .zsh file must have a matching entry here, or the build fails.
      # Keep the .zsh file as a real file so treesitter/LSP can work with it.
      zshrc = pkgs.replaceVars ./zsh/zshrc.zsh {
        atuin = lib.getExe pkgs.atuin;
        starship = lib.getExe pkgs.starship;
        zoxide = lib.getExe pkgs.zoxide;
        zsh_vi_mode = pkgs.zsh-vi-mode;
        zsh_fzf_tab = pkgs.zsh-fzf-tab;
        zsh_autosuggestions = pkgs.zsh-autosuggestions;
        zsh_syntax_highlighting = pkgs.zsh-syntax-highlighting;
        intelli_shell = lib.getExe pkgs.intelli-shell;
      };

      zprofile = pkgs.writeText "zprofile" ''
        source /etc/profile
      '';

      # ZDOTDIR is the directory zsh looks in for .zshrc/.zprofile.
      # By pointing it at a nix store path, the custom config is read-only and reproducible.
      # Both the wrapped package (nix run) and the system zsh (login shell) use this same derivation.
      zdotdir = pkgs.runCommandLocal "zsh-zdotdir" { } ''
        mkdir -p $out
        cp ${zshrc} $out/.zshrc
        cp ${zprofile} $out/.zprofile
      '';
    in
    {
      packages = {
        # The wrapped zsh for `nix run .#zsh`. wrapper-modules sets ZDOTDIR and EDITOR as env vars
        # baked into the wrapper script, so running this binary gets the full customized shell.
        zsh = inputs.wrapper-modules.lib.wrapPackage (_: {
          inherit pkgs;

          package = pkgs.zsh;

          env = {
            ZDOTDIR = zdotdir;
            EDITOR = "hx";
          };

          runtimePkgs = [
            pkgs.zsh-vi-mode
            pkgs.zsh-fzf-tab
            pkgs.zsh-autosuggestions
            pkgs.zsh-syntax-highlighting
            pkgs.atuin
            pkgs.starship
            pkgs.zoxide
            pkgs.fzf
            pkgs.intelli-shell
          ];
        });

        # Exposed separately so the NixOS module can reference zdotdir without pulling in the
        # full wrapper. The NixOS module sets ZDOTDIR as a session variable instead — same effect,
        # different mechanism (PAM vs wrapper script).
        zsh-zdotdir = zdotdir;
      };
    };

  # --- flake.nixosModules: system-wide zsh config ---
  #
  # Why set ZDOTDIR as a sessionVariable?
  # The login shell is the system pkgs.zsh (not the wrapped one). Without ZDOTDIR, it would
  # read ~/.zshrc (which doesn't exist). Setting ZDOTDIR via sessionVariables tells PAM to
  # export it into the environment, so zsh reads our nix store .zshrc instead.
  #
  # Why install plugin deps (zoxide, starship, atuin, fzf) in systemPackages?
  # The .zshrc references these binaries by absolute nix store path (via replaceVars),
  # so they must be available at runtime. The wrapped package bundles them via runtimePkgs,
  # but the system zsh doesn't have that mechanism — they need to be on the system.
  flake.nixosModules.zsh =
    { pkgs, ... }:
    {
      environment = {
        sessionVariables = {
          NH_FLAKE = "$HOME/src/mortlake";
          ZDOTDIR = self.packages.${pkgs.stdenv.hostPlatform.system}.zsh-zdotdir;
          EDITOR = "hx";
        };
        extraInit = ''
          export PATH="$PATH:$HOME/.local/bin"
        '';
        systemPackages = [
          pkgs.zsh
          pkgs.zoxide
          pkgs.starship
          pkgs.atuin
          pkgs.fzf
          pkgs.intelli-shell
        ];
      };

      # Registers zsh in /etc/shells so it's a valid login shell target.
      programs.zsh.enable = true;

      # zoxide's db lives at $XDG_DATA_HOME/zoxide (verified on 0.10.0 —
      # data, not state). tmpfs root wipes it each boot; persist it here
      # alongside the shell's other state (cf. intellishell.nix).
      preservation.preserveAt."/persistent".users.john.directories = [ ".local/share/zoxide" ];

      # Sets the default shell for new users. For existing users, run: chsh -s $(which zsh)
      users.defaultUserShell = pkgs.zsh;
    };
}
