{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.gh = inputs.wrapper-modules.lib.wrapPackage (_: {
        inherit pkgs;
        package = pkgs.gh;
        env.GH_CONFIG_DIR = "/etc/gh";
      });
    };

  flake.nixosModules.gh =
    {
      config,
      pkgs,
      ...
    }:
    let
      # sops-nix: ${p.<key>} in a template resolves to the rendered secret
      # value at activation — secret values never enter the Nix store.
      p = config.sops.placeholder;
    in
    {
      config = {
        environment.etc."gh/config.yml".source = ./gh-config.yml;

        sops.secrets = {
          "magus-gh-pat-for-jehoel".sopsFile = ./secrets.yaml;
        };

        # One GitHub identity fleet-wide: magus-john-bee (public work).
        # Mortlake has no GitHub private repo — collaboration happens as
        # radicle patches, so gh only ever serves public repos. A second
        # account would need a credential router to be usable from git;
        # don't add one casually.
        sops.templates."gh-hosts.yml" = {
          content = ''
            github.com:
              users:
                magus-john-bee:
                  oauth_token: ${p."magus-gh-pat-for-jehoel"}
              oauth_token: ${p."magus-gh-pat-for-jehoel"}
              user: magus-john-bee
          '';
          path = "/etc/gh/hosts.yml";
          owner = "john";
          mode = "0600";
        };

        # No-op where the mortlake clone is absent.
        system.activationScripts.ghRemoteHints.text = builtins.readFile ./gh-remote-hints.sh;

        environment.systemPackages = [
          inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.gh
        ];
      };
    };
}
