# Resume Variants

Three summary variants for different job categories. The master resume
(`data/resume.json`) stays unchanged — each variant only overrides
`basics.label` and `basics.summary`.

## Variants

| Variant | Target role | Label |
|---|---|---|
| `generalist` | Normal dev work, AI as a tool | Software Engineer |
| `ai-orchestration` | Building AI orchestration systems (agents, RAG, MCP, tooling) | AI Orchestration Engineer |
| `knowledge-systems` | Knowledge systems, applied ontology, AI-for-science | Software Engineer |

## Usage

```sh
# List available variants
./scripts/build-resume.py

# Build a variant (writes data/json_resume/en.json, _index.md, hugo.toml)
./scripts/build-resume.py generalist
./scripts/build-resume.py ai-orchestration
./scripts/build-resume.py knowledge-systems
```

## How it works

1. `data/resume.json` is the master — full work history, skills, education.
2. `data/resume.variants/<name>.json` is a small override (label + summary).
3. `scripts/build-resume.py` deep-merges master + variant and writes the
   output files that Hugo consumes.

## Creating a new variant

Copy any existing variant file and edit the label/summary:

```sh
cp data/resume.variants/generalist.json data/resume.variants/custom.json
# edit custom.json, then:
./scripts/build-resume.py custom
```

The override file supports deep-merging any field, not just summary —
you can override work highlights, skills, or anything else per-variant.
