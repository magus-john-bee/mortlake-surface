# nrs — "nixos-rebuild switch", mortlake edition.
#
# Just the switch: cd ~/src/mortlake (NRS_FLAKE to override) and
# sudo nixos-rebuild <verb> --flake .#<hostname>. Deliberately no git —
# pulling is the operator's call, so a phone dispatch is "pull" then
# "nrs", not one command with a baked-in assumption about which
# branch should go live.
#
# The switch phase needs root (setting /nix/var/nix/profiles/system),
# and nixos-rebuild does not self-elevate — hence sudo -n, which is
# passwordless for john on every mortlake host. Root-side evaluation
# of the john-owned checkout is fine here: Nix reads local flakes via
# libgit2, not the git CLI, so git's safe.directory check never runs.
#
# Why a script on PATH instead of a zsh alias: `sudo nrs` (muscle
# memory) can't see aliases, and scripts work from agent panes and
# non-interactive SSH.
#
# Usage:
#   nrs [switch|boot|test|dry-activate] [extra nixos-rebuild args...]
{
  flake.nixosModules.nrs =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        (pkgs.writeShellScriptBin "nrs" ''
          set -euo pipefail
          # wrappers first: /run/current-system/sw/bin contains a non-setuid
          # sudo copy that shadows the real one if ordered ahead of it.
          export PATH="/run/wrappers/bin:/run/current-system/sw/bin:$PATH"

          # Single-user machines by design — see AGENTS.md.
          flake="''${NRS_FLAKE:-/home/john/src/mortlake}"

          verb=switch
          case "''${1:-}" in
            switch|boot|test|dry-activate) verb="$1"; shift ;;
          esac

          command -v nixos-rebuild >/dev/null || {
            echo "nrs: nixos-rebuild not found (NixOS hosts only)" >&2
            exit 1
          }

          cd "$flake"
          exec sudo -n nixos-rebuild "$verb" --flake ".#$(hostname)" "$@"
        '')
      ];
    };
}
