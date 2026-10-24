# Obscura headless browser for AI agents and automation.
#
# Obscura (h4ckf0r0day/obscura) is an INDEPENDENT project from Lightpanda
# (lightpanda-io/browser) — similar purpose (agent-oriented headless
# browser, similar fetch/serve/scrape/mcp CLI surface), separate
# codebases, both actively developed. Mortlake switched from lightpanda
# to obscura by choice; nixpkgs packages obscura (buildRustPackage), so
# the old hand-rolled binary-wrap derivation is retired. This module
# wraps the nixpkgs binary (NOT overrideAttrs, which would bust the
# cache.nixos.org hit and force a full Rust rebuild on every nixpkgs
# bump) to set one mortlake default, and puts it in the flake output
# set (packages.nix installs all flake packages on every host).
#
# ── Local network access ─────────────────────────────────────
# Obscura blocks fetches to loopback/RFC1918/link-local by default
# (SSRF hardening, upstream #4). Agents routinely fetch from local
# services (sb.otwell.dev, taskdog.otwell.dev on the LAN), so default
# OBSCURA_ALLOW_PRIVATE_NETWORK=1; an explicitly-set value wins.
{
  perSystem =
    { pkgs, lib, ... }:
    {
      packages.obscura = lib.hiPrio (
        pkgs.writeShellScriptBin "obscura" ''
          : "''${OBSCURA_ALLOW_PRIVATE_NETWORK:=1}"
          export OBSCURA_ALLOW_PRIVATE_NETWORK
          exec "${pkgs.obscura}/bin/obscura" "$@"
        ''
      );
    };
}
