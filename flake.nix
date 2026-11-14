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
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-on-droid = {
      url = "github:nix-community/nix-on-droid";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Rev-pinned: openspecui hard-blocks the openspec CLI outside a
    # one-line window, and upstream bumps the two independently (each tracks
    # its own npm latest). This rev is the last matched pair — openspec
    # 1.16.1 + openspecui 16.1.1. HEAD pairs CLI 2.0.0 with openspecui
    # 17.0.0, which blocks it. Unpin when main carries a matched pair again
    # (expect an openspecui 18 for CLI 2.x).
    llm-agents = {
      url = "github:numtide/llm-agents.nix/117b03135ac3cfcc2a03db3787b549d80536056d";
      inputs.nixpkgs.follows = "nixpkgs";
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
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # noctalia-shell (v4, Quickshell-based) was removed from nixpkgs
    # 2026-10-22; v5 is a native rewrite with an incompatible config
    # format. Frozen at the last rev carrying it until the v5 migration
    # lands as its own unit.
    nixpkgs-noctalia.url = "github:NixOS/nixpkgs/55bfb4d7437bd4e09ab7cba58a43bd68eb310044";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
