# td — minimalist CLI for tracking tasks across AI coding sessions
# (marcus/td, Go + per-repo SQLite in .todos/). From numtide/llm-agents.nix.
#
# Complements aven (aven.nix): aven is the personal/cross-project task
# tracker; td is per-repo session handoff — structured done/remaining/
# decision/uncertain handoffs so a fresh agent context resumes from real
# state (`td usage --new-session -q`) instead of guessing.
#
# Data lives per checkout in .todos/ (gitignored; td init adds the entry).
# mortlake itself is initialized. Initializing another repo: `td init`,
# then add the compact guidance it prints to that repo's AGENTS.md.
#
# The agent-facing integration (vendored td-task-management skill +
# AGENTS.md guidance block for mortlake) is deliberately deferred to the
# skills/AGENTS.md backlog (aven PRS-0CRG).
{
  inputs,
  ...
}:
{
  flake.nixosModules.td =
    {
      pkgs,
      ...
    }:
    {
      environment.systemPackages = [
        inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.td
      ];
    };
}
