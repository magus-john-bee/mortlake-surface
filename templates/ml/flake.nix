{
  description = "ML project dev environment";

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
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true; # CUDA if added later
          };
        in
        {
          default = pkgs.mkShell {
            packages = [
              (pkgs.python313.withPackages (ps: [
                ps.ipython
                ps.jupyterlab
                ps.rdflib
              ]))
              pkgs.uv
              pkgs.git-lfs
              pkgs.just
            ];

            shellHook = ''
              echo ""
              echo "  ML dev shell — Python $(python --version 2>&1 | cut -d' ' -f2)"
              echo "  Sync deps:  just sync"
              echo "  Tracking:   just mlflow   (MLflow UI on :5000)"
              echo "  Notebooks:  just jupyter"
              echo ""
            '';
          };
        }
      );
    };
}
