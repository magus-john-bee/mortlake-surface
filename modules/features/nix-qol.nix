{ inputs, ... }:
{
  flake.nixosModules.nix-qol =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      nix = {
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];

          # Substituters: own cache (everywhere except the cache host itself —
          # its store already backs the cache, so querying itself is pure
          # overhead and couples its nix to local nginx/ACME health) plus the
          # numtide/llm-agents.nix cache (pi, prime-agent, herdr, funes), declared
          # here so any host consuming the input gets it, not just hosts
          # that happen to import pi.nix.
          extra-substituters =
            (lib.optionals (!config.services.nix-serve.enable) [ "https://cache.otwell.dev" ])
            ++ [ "https://cache.numtide.com" ];
          extra-trusted-public-keys = [
            "cache.otwell.dev:1uNVs/iKY7NnLUcSoS++Zl2+iWl9qw1VuC0Fa5Lkt4I="
            "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
          ];
        };

        registry = pkgs.lib.mapAttrs (_: value: { flake = value; }) inputs;

        settings.nix-path = pkgs.lib.mapAttrsToList (
          key: value: "${key}=${value.to.path}"
        ) config.nix.registry;
      };

      # nix-ld: critical for running pre-built binaries (MCP servers, Pi tools)
      programs.nix-ld = {
        enable = true;
        libraries = with pkgs; [
          stdenv.cc.cc.lib
          zlib
          opus
        ];
      };

      # envfs: provides /usr/bin/env
      services.envfs.enable = true;
    };
}
