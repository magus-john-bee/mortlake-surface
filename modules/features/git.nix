{
  flake.nixosModules.git =
    {
      pkgs,
      ...
    }:
    {
      environment.systemPackages = [ pkgs.delta ];

      programs.git = {
        enable = true;
        config = [
          {
            core = {
              editor = "hx";
              pager = "delta";
            };
            # gh's stock helper serves the single configured gh account
            # (see gh.nix) — git push/pull over https needs nothing else.
            credential.helper = [ "!gh auth git-credential" ];
            delta = {
              line-numbers = true;
              navigate = true;
              side-by-side = true;
            };
            init.defaultBranch = "main";
            interactive.diffFilter = "delta --color-only";
            pull.rebase = false;
            alias.lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
            user = {
              name = "John Otwell";
              email = "john@otwell.dev";
            };
          }
        ];
      };
    };
}
