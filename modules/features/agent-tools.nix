# Agent tooling stack — the CLI tools from global-agents.md that are
# consumed directly by coding agents (pi, hermes, codex) rather than wrapped
# per-agent. Binary cache for llm-agents packages is declared in nix-qol.nix.
#
#   codegraph        — semantic code intelligence (symbols/calls/deps).
#                      Map a repo, then query it instead of grepping around.
#   context          — neuledge/context CLI wrapper (v1.3.3, npm-only — not
#                      in nixpkgs or llm-agents): local-first library docs.
#                      `context install npm/<lib>` then `context query <lib>
#                      <topic>`; `context add` ingests llms.txt sites/git
#                      repos/local dirs. Hermes already runs the same package
#                      as its `context` MCP server (hermes.nix). Installed
#                      docs live in ~/.context/packages (preserved in pi.nix).
#                      NOTE: @neuledge/context is NOT context-hub/chub
#                      (andrewyng) — different project; chub was evaluated
#                      and dropped as superseded.
#   openspec         — spec-driven development: change proposals with specs
#                      and tasks under openspec/ in each repo.
#   plannotator      — plan/review bridge: John annotates agent-written
#                      plans/specs; annotations flow back to the agent.
#                      Primary surface is the herdr integration
#                      (`herdr plugin install plannotator/herdr-annotate`).
#   plannotator-tui  — terminal frontend for the same annotation flow
#                      (works standalone via --export/--annotate and inside
#                      herdr panes).
#                      Both plannotator binaries ship WRAPPED with the
#                      network-feature lockdown (share/AI/Jina/release-check
#                      phone-home all off) — see perSystem below; the
#                      herdr-annotate plugin bundles its own binary
#                      (herdr.nix) and is out of this module's scope.
#
# Usage guidance lives in skills/ (see global-agents.md pointers), not in
# this module.
{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      # Network-feature lockdown (docs/agent-tooling-reports/plannotator.md):
      # share links, Ask AI, Jina URL enrichment, and the release-check /
      # git-remote phone-home are all off, baked into the wrapper so every
      # invocation gets the same posture.
      plannotatorLockdown = {
        PLANNOTATOR_SHARE = "disabled";
        PLANNOTATOR_AI = "disabled";
        PLANNOTATOR_JINA = "0";
        PLANNOTATOR_GIT_REMOTE_CHECK = "0";
      };
      wrap =
        name:
        inputs.wrapper-modules.lib.wrapPackage (_: {
          inherit pkgs;
          package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.${name};
          env = plannotatorLockdown;
        });
    in
    {
      packages.plannotator = wrap "plannotator";
      packages.plannotator-tui = wrap "plannotator-tui";
    };

  flake.nixosModules.agent-tools =
    { pkgs, ... }:
    let
      inherit (pkgs.stdenv.hostPlatform) system;
      inherit (inputs.llm-agents.packages.${system})
        codegraph
        openspec
        ;
      context = pkgs.writeShellApplication {
        name = "context";
        runtimeInputs = [ pkgs.nodejs ];
        text = ''
          exec npx -y @neuledge/context@1.3.3 "$@"
        '';
      };
    in
    {
      environment.systemPackages = [
        codegraph
        context
        openspec
        inputs.self.packages.${system}.plannotator
        inputs.self.packages.${system}.plannotator-tui
      ];
    };
}
