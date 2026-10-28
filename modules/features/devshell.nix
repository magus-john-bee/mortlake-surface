{ inputs, ... }:
{
  imports = [ inputs.git-hooks-nix.flakeModule ];

  perSystem =
    { config, pkgs, ... }:
    {
      pre-commit.settings.hooks = {
        nixfmt.enable = true;
        statix.enable = true;
        deadnix.enable = true;
      };

      devShells.default = pkgs.mkShell {
        inherit (config.pre-commit) shellHook;

        packages =
          with pkgs;
          [
            nil
            nixd
            nix-output-monitor
            bash-language-server
            shellcheck
            # Skill template gate (just lint-skills; custom rule at
            # scripts/skill-template-rule.mjs)
            markdownlint-cli2
          ]
          ++ config.pre-commit.settings.enabledPackages;
      };
    };
}
