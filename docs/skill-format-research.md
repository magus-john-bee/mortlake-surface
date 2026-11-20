# Skill Format Research — Demystifying Agent Skills

Grounding for task #117 (principled skill building & management) and the
"making a skill" follow-up. Source: **arXiv 2608.14036** — "Demystifying
Agent Skills: Why They Work—Until They Don't" (Jiang et al., Aug 2026).
Also in the logbook reading list: ai-research.md #158 (unchecked as of
2026-09-30). Companion paper: arXiv 2607.17598 (progressive disclosure —
one routing level is enough).

## Findings that shape our skill system

1. **Skills are procedural anchors, not knowledge injections.** 65.7% of
   skill-use cases = stabilized execution (setup steps, tool sequences,
   verification checks); explicit knowledge injection = 4.5%. Skills teach
   *how to act*. Reference-style SKILL.md content is effectively null.
2. **Skill representation beats raw experience.** On Terminal-Bench-2:
   Skill 79.2% vs Workflow Memory 62.3% vs Raw 50.0%. Even bare procedural
   text ("test-first": success conditions + checks + verify, no SKILL.md)
   hit 59.2% — the procedural skeleton is the active ingredient; SKILL.md
   packaging adds the rest.
3. **Retval is a separate bottleneck.** Actual-use precision falls
   29.6% → 3.3% as the candidate pool grows 5 → 100. Curation (small,
   distinguishable pools) matters as much as format. Exact ground-truth
   invocation is neither sufficient nor necessary — confusable distractors
   hurt selection but downstream success stays stable.
4. **Skills can hurt** on tasks needing reformulation or independent
   verification — followed-without-adapting is a real failure class.
5. **Outcome annotations guide distillation** — knowing which traces
   succeeded/failed improves the distilled skill.

## The validated template (paper's skill-creator.md, Appendix B.1)

```markdown
---
name: {{skill-name}}
description: {{one-line description}}
---
# {{Skill Name}}

## Use This Skill When
- {{condition 1}}
- {{condition 2}}

## Preconditions
- {{what must be true before starting}}

## Steps
1. {{step 1}}
2. {{step 2}} ...

## Common Failure Modes To Avoid
- {{failure mode 1: signal and mitigation}}
- {{failure mode 2: signal and mitigation}}

## If A Failure Happens
1. Stop and inspect the latest output.
2. Map the error to the failure modes above and apply the fix.
3. Re-run verification before finishing.

## Verify
- {{how to confirm the skill completed successfully}}
```

Generator rules (from the same prompt): exactly ONE skill per file;
generalize to similar tasks, not just the source task; steps concrete and
actionable; when traces disagree keep the most reliable approach; failed
traces harvest into Failure Modes; placeholders instead of task-specific
paths.

## Honest caveats

- The template is the *instrument* of the winning experimental arm, not
  itself the A/B. Evidence supports "procedural skeleton + failure modes +
  verification," of which this is the validated instantiation.
- Benchmarks are Terminal-Bench-2/pro (terminal agent tasks); transfer to
  ops/research skills is plausible but unmeasured.

## Delta vs current mortlake skills

House format already has: frontmatter (name/description), When-to-Use
triggers, linked references. Missing from the validated template:
**Preconditions**, **Common Failure Modes To Avoid**, **If A Failure
Happens**, **Verify**. The delta is those four sections — and several
existing skills are reference-shaped (the 4.5% case), candidates for
proceduralization when touched next.

## Green-red validation

Two layers:

1. **Template conformance (heading structure): markdownlint-cli2 + MD043** —
   in nixpkgs. MD043 ("required-headings") compares a file against a
   template headings array with wildcards (`*` zero+, `+` one+, `?` exactly
   one — lets the H1 vary while pinning the skeleton). Scope via
   markdownlint-cli2's nested `configs` object (only `skills/**/SKILL.md`
   gets the gate). Nonzero exit on violation → `just lint` / `nix flake
   check` green-red with zero custom code. Structure only — it does not
   check section *content* or frontmatter keys.
2. **Content rules (frontmatter keys, Steps non-empty + numbered):** a
   ~20-line markdownlint custom rule (plain JS) or small Python checker
   alongside.

No skill-specific off-the-shelf linter exists (vercel-labs/skills =
installer/updater; anthropics/skills validators = office-doc content;
Hermes = frontmatter only). Heavyweight alternative for structured-data
templates: conftest (Rego, nixpkgs) — right tool for config files, wrong
for prose templates.
