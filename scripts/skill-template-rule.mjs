// Custom markdownlint rule: skill template enforcement.
//
// Enforces the validated skill structure (arXiv 2608.14036 Appendix B.1):
// required sections in order, applicability boundary present, procedural
// body rather than reference material. Replaces MD043 because that rule
// matches literal heading sequences (wildcards anchor to doc boundaries),
// which cannot express "required sections, in order, with arbitrary
// content between/after".
//
// Usage: enabled by name in .markdownlint-cli2.jsonc ("skill-template":
// true) with customRules pointing here; the justfile lint-skills recipe
// passes only CHANGED SKILL.md files (grandfather policy).
//
// Checks:
//   1. Frontmatter starts the file, closes, and has name + description.
//   2. Required H2 sections, in this order:
//      Use This Skill When / Preconditions / Steps /
//      Common Failure Modes To Avoid / If A Failure Happens / Verify
//   3. Each H2 section non-empty.
//   4. "Use This Skill When" contains at least one list item.
"use strict";

export default {
  names: ["skill-template"],
  description: "Skill template: required sections, in order, non-empty",
  tags: ["skill", "template"],
  information: new URL("https://arxiv.org/abs/2608.14036"),
  function: function apply({ name, lines, tokens, frontMatterLines }, onError) {
    // Scope: this rule only governs SKILL.md files (any directory);
    // references/, templates/, etc. under skills/ are exempt.
    if (!/(^|\/)SKILL\.md$/.test(name ?? "")) return;
    const addContext = (description, lineNumber) =>
      onError({ lineNumber, detail: description, context: lines[lineNumber - 1] });

    // 1. Frontmatter (markdownlift strips it into frontMatterLines)
    const fm = (frontMatterLines ?? []).join("\n");
    if (fm === "") {
      addContext("no frontmatter block", 1);
      return;
    }
    if (!/^name:\s*\S/m.test(fm)) addContext("frontmatter missing name:", 1);
    if (!/^description:\s*\S/m.test(fm)) addContext("frontmatter missing description:", 1);

    // 2. Required H2 sections in order
    const h2s = [];
    for (const t of tokens) {
      if (t.type === "heading_open" && t.tag === "h2") {
        h2s.push({
          title: lines[t.map[0]].replace(/^##\s*/, "").trim(),
          start: t.map[0],
          end: t.map[1],
        });
      }
    }
    let searchFrom = 0;
    for (const required of REQUIRED_SECTIONS) {
      const idx = h2s.findIndex((h, i) => i >= searchFrom && h.title === required);
      if (idx === -1) {
        addContext(`missing/out-of-order section "## ${required}"`, 1);
      } else {
        searchFrom = idx + 1;
      }
    }

    // 3. Non-empty sections
    for (const h of h2s) {
      const next = h2s.find((o) => o.start > h.start);
      const bodyEnd = next ? next.start : lines.length;
      if (lines.slice(h.end, bodyEnd).join("").trim() === "") {
        addContext(`section "## ${h.title}" is empty`, h.start + 1);
      }
    }

    // 4. "Use This Skill When" needs >= 1 list item
    const utsw = h2s.find((h) => h.title === "Use This Skill When");
    if (utsw) {
      const next = h2s.find((o) => o.start > utsw.start);
      const end = next ? next.start : lines.length;
      const hasItem = lines
        .slice(utsw.end, end)
        .some((l) => /^\s*(?:[-*+]|\d+\.)\s+\S/.test(l));
      if (!hasItem) {
        addContext('"Use This Skill When" needs a list item', utsw.start + 1);
      }
    }
  },
};

const REQUIRED_SECTIONS = [
  "Use This Skill When",
  "Preconditions",
  "Steps",
  "Common Failure Modes To Avoid",
  "If A Failure Happens",
  "Verify",
];
