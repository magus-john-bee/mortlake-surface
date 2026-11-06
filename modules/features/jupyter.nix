{ inputs, ... }:
{
  flake.nixosModules.jupyter =
    { pkgs, ... }:
    let
      inherit (pkgs.stdenv.hostPlatform) system;

      # This env is the system python: packages.nix ships no bare python313
      # because two python builds in systemPackages collide on bin/python3.
      # jupyterlab-vim is a prebuilt extension, active on install — vim
      # keybindings in notebook cells with no runtime `labextension install`.
      pythonJupyter = pkgs.python313.withPackages (
        ps: with ps; [
          ipykernel
          jupyterlab
          jupyterlab-vim
        ]
      );
    in
    {
      environment.systemPackages = [
        # TUI notebook editor. Vim keybindings are the built-in default
        # (config.toml `editor = "builtin"`); kernels are found via
        # `jupyter --paths` on PATH and venvs beside the notebook.
        inputs.jotter.packages.${system}.jotter
        pythonJupyter
      ];

      preservation.preserveAt."/persistent".users.john.directories = [
        ".config/jotter" # config.toml once customized
        ".local/state/jotter" # autosave + crash recovery
        ".jupyter" # lab user settings
        ".local/share/jupyter" # user kernels/extensions
      ];
    };
}
