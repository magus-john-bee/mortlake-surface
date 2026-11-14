#!/usr/bin/env python3
"""
build-resume.py — Generate a targeted resume variant for the Hugo site.

Usage:
  ./scripts/build-resume.py                  # list available variants
  ./scripts/build-resume.py generalist       # build a specific variant
  ./scripts/build-resume.py ai-orchestration
  ./scripts/build-resume.py knowledge-systems

Deep-merges data/resume.json (master) with a small override file from
data/resume.variants/<name>.json, then writes:
  - data/json_resume/en.json   (consumed by Hugo json-resume module)
  - content/_index.md          (homepage intro, first paragraph of summary)
  - updates hugo.toml subtitle/description to match the variant

The master resume is never modified. Variant files only contain the fields
they want to override (typically basics.label and basics.summary).
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / "data" / "resume.json"
VARIANTS_DIR = ROOT / "data" / "resume.variants"
OUTPUT_JSON = ROOT / "data" / "json_resume" / "en.json"
INDEX_MD = ROOT / "content" / "_index.md"
HUGO_TOML = ROOT / "hugo.toml"


def deep_merge(base: dict, override: dict) -> dict:
    """Recursively merge override into base. Override wins at every leaf."""
    result = dict(base)
    for key, val in override.items():
        if key in result and isinstance(result[key], dict) and isinstance(val, dict):
            result[key] = deep_merge(result[key], val)
        else:
            result[key] = val
    return result


def load_json(path: Path) -> dict:
    with open(path, "r") as f:
        return json.load(f)


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")


def update_index_md(summary: str, label: str) -> None:
    """Write the homepage intro using the first sentence(s) of the summary."""
    first_para = summary.split(". ")[0] + "."
    content = f"""+++
title = "John Otwell"
date = "2026-07-08"
draft = false
+++

{first_para}

[View my CV →](/cv/)
"""
    INDEX_MD.write_text(content)


def update_hugo_toml(summary: str, label: str) -> None:
    """Update subtitle and description in hugo.toml to match variant."""
    toml = HUGO_TOML.read_text()

    # Build a clean meta description: first 1-2 sentences, trimmed
    sentences = re.split(r"(?<=[.!?])\s+", summary)
    short_desc = sentences[0]
    if len(short_desc) < 120 and len(sentences) > 1:
        short_desc = short_desc + " " + sentences[1]
    if len(short_desc) > 170:
        cut = short_desc[:170].rfind(", ")
        if cut > 100:
            short_desc = short_desc[:cut]
        else:
            cut = short_desc[:170].rfind(" ")
            short_desc = short_desc[:cut]

    toml = re.sub(r'subtitle = ".*?"', f'subtitle = "{label}"', toml)
    # Use a DOTALL-aware regex that matches the existing description line
    toml = re.sub(
        r'description = ".*?"',
        lambda m: f'description = "John Otwell — {label}. {short_desc}"',
        toml,
        flags=re.DOTALL,
    )
    HUGO_TOML.write_text(toml)


def list_variants() -> None:
    variants = sorted(VARIANTS_DIR.glob("*.json"))
    if not variants:
        print("No variants found in", VARIANTS_DIR)
        return
    print("Available variants:\n")
    for v in variants:
        name = v.stem
        data = load_json(v)
        label = data.get("basics", {}).get("label", "(no label set)")
        summary = data.get("basics", {}).get("summary", "(no summary)")
        preview = summary[:90] + "..." if len(summary) > 90 else summary
        print(f"  {name}")
        print(f"    label:   {label}")
        print(f"    summary: {preview}")
        print()


def main() -> None:
    if len(sys.argv) < 2:
        list_variants()
        print("Run: ./scripts/build-resume.py <variant-name>")
        sys.exit(0)

    variant_name = sys.argv[1]
    variant_path = VARIANTS_DIR / f"{variant_name}.json"

    if not variant_path.exists():
        print(f"Error: variant '{variant_name}' not found at {variant_path}")
        print()
        list_variants()
        sys.exit(1)

    master = load_json(MASTER)
    override = load_json(variant_path)
    merged = deep_merge(master, override)

    label = merged["basics"]["label"]
    summary = merged["basics"]["summary"]

    # Write all outputs
    write_json(OUTPUT_JSON, merged)
    update_index_md(summary, label)
    update_hugo_toml(summary, label)

    print(f"✓ Built variant: {variant_name}")
    print(f"  label:   {label}")
    print(f"  summary: {summary[:100]}...")
    print(f"  → {OUTPUT_JSON}")
    print(f"  → {INDEX_MD}")
    print(f"  → {HUGO_TOML} (subtitle/description updated)")


if __name__ == "__main__":
    main()
