{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    wrapper-modules = {
      url = "github:BirdeeHub/nix-wrapper-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    preservation = {
      url = "github:nix-community/preservation";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # package repos
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      # hermes's pm-packages.nix layers a patchelf-0.19-targeted fix
      # (NixOS/patchelf#674) on whatever patchelf its nixpkgs ships;
      # nixos-unstable reverted patchelf to 0.15.2, where that patch no
      # longer applies and the build dies. Hold hermes at its own tested
      # nixpkgs pin until the patch is version-conditional upstream.
      inputs.nixpkgs.url = "github:NixOS/nixpkgs/02c087f3fe673c9e317f206a627cb6b910336dbe";
    };
    nix-on-droid = {
      url = "github:nix-community/nix-on-droid";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Rev-pinned: openspecui hard-blocks the openspec CLI outside a
    # one-line window, and upstream bumps the two independently (each tracks
    # its own npm latest). This rev is the last matched pair — openspec
    # 1.16.1 + openspecui 16.1.1. Main still mismatches (CLI 2.1.0 vs
    # openspecui 17, whose gate admits only CLI 1.17.x). Unpin when main
    # carries a matched pair again.
    llm-agents = {
      url = "github:numtide/llm-agents.nix/117b03135ac3cfcc2a03db3787b549d80536056d";
      # Pinned to its own tested nixpkgs: on root nixpkgs (d4f25a3) aven's
      # vendored zstd-sys probes pkg-config, which the package doesn't
      # carry, and the build panics. Drop when llm-agents bumps past
      # 117b0313 (the openspec-pairing pin) or adds pkg-config itself.
      inputs.nixpkgs.url = "github:NixOS/nixpkgs/6dadaf4375be35033e1c84395adbd53ff5fded96";
    };
    # Ponytail ruleset: pi extension loaded from this store path
    # (pi-extension/); its six skills are vendored under
    # skills/software-development/ponytail* at the locked rev.
    ponytail = {
      url = "github:DietrichGebert/ponytail";
      flake = false;
    };
    jotter = {
      url = "github:samox73/jotter";
      # Pinned to its own tested nixpkgs: on root nixpkgs (d4f25a3) the
      # Rust build env no longer carries pkg-config, and jotter's onig_sys
      # panics without it. Drop once nixpkgs or jotter adapts.
      inputs.nixpkgs.url = "github:NixOS/nixpkgs/4975466d324710c576dc11ad614684e6bd8cad8e";
    };
    # noctalia-shell (v4, Quickshell-based) was removed from nixpkgs
    # 2026-10-22; v5 is a native rewrite with an incompatible config
    # format. Frozen at the last rev carrying it until the v5 migration
    # lands as its own unit.
    nixpkgs-noctalia.url = "github:NixOS/nixpkgs/55bfb4d7437bd4e09ab7cba58a43bd68eb310044";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
