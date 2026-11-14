{
  description = "Rust project dev environment";

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
              # Stable foundation: the whole rust toolchain from ONE nixpkgs
              # revision (rustc/clippy/rustfmt/rust-analyzer stay version-
              # coherent), bacon for the watch loop, just for recipes.
              # Rust tooling is never system-wide on mortlake hosts —
              # projects get it from this shell.
              pkgs.rustc
              pkgs.cargo
              pkgs.clippy
              pkgs.rustfmt
              pkgs.rust-analyzer
              pkgs.bacon
              pkgs.just
            ];

            # rust-analyzer needs the std sources for core/std completions
            RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";

            shellHook = ''
              echo ""
              echo "  Rust dev shell — $(rustc --version | cut -d' ' -f2) + cargo"
              echo "  Build: just build   Test: just test   Check: just check"
              echo "  Lint: just lint   Fmt: just fmt   Watch: just watch (bacon)"
              echo ""
            '';
          };
        }
      );
    };
}
