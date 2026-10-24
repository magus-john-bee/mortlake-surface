{
  flake.nixosModules.git =
    {
      pkgs,
      config,
      lib,
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
            # gh's stock helper answers the ACTIVE gh account; when
            # gh.credRouter is set (jehoel, dual-identity), it is appended and
            # routes non-active usernames via `gh auth token --user`.
            credential.helper = [
              "!gh auth git-credential"
            ]
            ++ lib.optionals (config.gh.credRouter != null) [ config.gh.credRouter ];
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
