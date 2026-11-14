# OpenCodeReview (ocr, alibaba/open-code-review; package from inputs.llm-agents)
# — second-eyes reviewer for the pre-gate-2 pass. Deploys two files into
# ~/.opencodereview (home is tmpfs; recreated at every activation):
#
#   rule.json   GLOBAL layer of ocr's four-layer rule chain (--rule flag >
#               repo .opencodereview/rule.json > ~/.opencodereview/rule.json
#               > embedded system default; first matching glob wins).
#               Content is the ponytail lean lens distilled from
#               skills/software-development/ponytail-review: ocr's built-ins
#               already cover bugs/security/tests/speed per language; this
#               adds the "what to cut" lens on top (merge_system_rule
#               combines both). Symlink, not copy: ocr only reads it, and
#               the store copy stays the single source. Repo-scale rules
#               stay per-repo (.opencodereview/rule.json, committable).
#
#   config.json provider wiring, seeded as a REAL writable file (same
#               semantics as the ponytail config seed: `ocr config set`
#               rewrites it at runtime; the next activation resets to the
#               declared default). The key never enters the store —
#               api_key_cmd shells out to the sops secret at runtime, so
#               ocr works from any john context without env plumbing.
#               llm.timeout_sec + tasks.MAIN_TASK.timeout = 600s: the
#               default 180s per-request cap kills the core-review
#               synthesis (~86k-token prompts run 100-180s+); a ~30m
#               whole-session wall remains upstream-hardcoded — on a
#               slow provider night a big diff still needs the wall or
#               a faster model, not more per-request headroom.
#               Telemetry: OCR's NATIVE OTLP spans (metadata only: model,
#               tokens, durations, tool names — never prompt/response
#               content) are enabled and aimed at the otelcol-phoenix
#               relay by ENV VARS set in phoenix.nix (OCR_ENABLE_TELEMETRY
#               + the OTEL_EXPORTER_OTLP_* pair), NOT here: upstream env
#               beats config.json, and its config section can't set a
#               protocol — enabling telemetry from the file would point
#               gRPC at an HTTP-only relay and, in shell-less contexts,
#               fall back to a console exporter on stdout. Traces land in
#               the Phoenix `open-code-review` project.
#
# transcripts (sessions/) are preserved + backed up — the durable record
# of what the reviewer said; raw/ wire logs stay ephemeral (bulk,
# forensic only). Phoenix itself renders full content attrs fine
# (OpenInference prompts/responses/tool payloads) — but ocr emits
# metadata-only spans (model/tokens/durations; its OCR_CONTENT_LOGGING
# flag is unwired in v1.13.3), so sessions stay the content record.
# The fromJSON roundtrips make malformed JSON an eval failure.
{
  inputs,
  ...
}:
{
  flake.nixosModules.ocr =
    {
      pkgs,
      ...
    }:
    let
      ruleJson = pkgs.writers.writeJSON "opencodereview-rule.json" (
        builtins.fromJSON (builtins.readFile ./ocr-rules.json)
      );
      configJson = pkgs.writers.writeJSON "opencodereview-config.json" (
        builtins.fromJSON (builtins.readFile ./ocr-config.json)
      );
    in
    {
      environment.systemPackages = [
        inputs.llm-agents.packages.${pkgs.system}.open-code-review
      ];

      preservation.preserveAt."/persistent".users.john.directories = [
        ".opencodereview/sessions"
      ];

      system.activationScripts.opencodereview.text = ''
        mkdir -p /home/john/.opencodereview
        ln -sfn ${ruleJson} /home/john/.opencodereview/rule.json
        chown -h john:users /home/john/.opencodereview/rule.json
        install -D -m 644 -o john -g users ${configJson} /home/john/.opencodereview/config.json
      '';
    };
}
