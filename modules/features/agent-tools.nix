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
#   openspecui       — web dashboard for openspec/ (live mode + static
#                      export), from llm-agents. Its major hard-blocks the
#                      openspec CLI outside a one-line window, and the
#                      llm-agents input is rev-pinned to the last matched
#                      pair — see the pin comment in flake.nix before
#                      bumping that input.
#   plannotator      — plan/review bridge for the BROWSER flow (Collie /
#                      off-terminal reviews): John annotates in a web view
#                      (--tailscale), annotations flow back to the agent.
#                      On-terminal reviews go through tuicr instead.
#                      Ships WRAPPED with the network-feature lockdown
#                      (share/AI/Jina/release-check phone-home all off) —
#                      see perSystem below.
#   tuicr            — code review TUI (vim keybindings, git/jj native).
#                      The agent-side skill and herdr tab wrapper live in
#                      ~/.agents/skills/tuicr/; review sessions persist in
#                      ~/.local/share/tuicr (preserved below).
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
    };

  flake.nixosModules.agent-tools =
    { pkgs, ... }:
    let
      inherit (pkgs.stdenv.hostPlatform) system;
      inherit (inputs.llm-agents.packages.${system})
        codegraph
        openspec
        openspecui
        tuicr
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
        openspecui
        tuicr
        inputs.self.packages.${system}.plannotator
      ];

      # tuicr review sessions and their comments live here; the tmpfs home
      # would drop in-flight reviews at reboot.
      preservation.preserveAt."/persistent".users.john.directories = [
        ".local/share/tuicr"
      ];
    };
}
