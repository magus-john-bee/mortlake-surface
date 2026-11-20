{
  description = "Python project dev environment";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forEachSystem = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forEachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = [
              # Stable foundation: interpreter, uv, and the helix 25.07 python
              # LSP defaults (ty + ruff) so binaries resolve on PATH the moment
              # the shell opens. Python tooling is never system-wide on
              # mortlake hosts — projects get it from this shell.
              pkgs.python313
              pkgs.uv
              pkgs.ruff
              pkgs.ty
              pkgs.just
            ];

            shellHook = ''
              # nix develop spawns bash regardless of $SHELL — give it a
              # starship prompt; no-op where starship is absent. Skipped
              # under direnv (DIRENV_IN_ENVRC=1 during its export
              # sandbox): it would leak STARSHIP_SHELL=bash into the
              # host zsh, whose prompt then renders literal \[ \]
              command -v starship >/dev/null && [ -z "''${DIRENV_IN_ENVRC:-}" ] && eval "$(starship init bash)"
              echo ""
              echo "  Python dev shell — $(python --version 2>&1 | cut -d' ' -f2) + uv"
              echo "  Sync deps: just sync   (first run also enables jedi completion in helix)"
              echo "  Test: just test   Lint: just lint   Types: just check   REPL: just repl"
              echo ""
            '';
          };
        }
      );
    };
}
