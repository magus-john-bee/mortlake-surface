{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem = _: {
    treefmt = {
      projectRootFile = "flake.nix";

      # Machine-structured formats only; markdown is deliberately unformatted
      # (reflow churn across skills/docs outweighs consistency).
      programs = {
        nixfmt.enable = true;
        nickel.enable = true;
        shfmt.enable = true;
        gofmt.enable = true;
        ruff-format.enable = true;
        taplo.enable = true;
        jsonfmt.enable = true;
        yamlfmt.enable = true;
      };

      settings.global.excludes = [
        # sops-encrypted: the YAML structure is MAC-covered; reformat = undecryptable
        "modules/features/secrets.yaml"
        # vendored hugo themes — third-party, churn on updates
        "sites/dev-resume/themes/**"
        # generated
        "**/package-lock.json"
        "flake.lock"
      ];
    };
  };
}
