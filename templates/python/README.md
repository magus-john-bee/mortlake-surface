# Python Project

Created from the `mortlake#python` template.

## Setup

```bash
nix develop        # enter dev shell (Python 3.13, uv, ruff, ty, just)
just sync          # create .venv + install dev deps (pytest, hypothesis, IPython, jedi)
```

With direnv (`.envrc`), entering the directory does both: dev shell on PATH,
`.venv` activated once it exists.

## Architecture

Two declarative layers, same split as `mortlake#ml`:

| Layer | Tool | File | Contents |
|---|---|---|---|
| Stable foundation | Nix | `flake.nix` | Python 3.13, uv, ruff, ty, just |
| Project deps | uv | `pyproject.toml` + `uv.lock` | runtime deps + dev group (pytest, hypothesis, IPython, jedi) |

Both are tracked in git. `uv add <pkg>` writes `pyproject.toml` and updates
`uv.lock`. Reproducible across machines.

## Commands

| Command | Description |
|---|---|
| `just sync` | Create/sync `.venv` from pyproject.toml |
| `just test` | Run pytest |
| `just check` | Type-check with ty |
| `just lint` | ruff check + format check |
| `just fmt` | ruff autofix + format |
| `just repl` | IPython |

## Helix

No helix config needed in the project. Helix 25.07 python defaults are
`ty`, `ruff`, `jedi`, `pylsp` — `ty` and `ruff` binaries come from the nix
dev shell (present before the first `uv sync`), `jedi-language-server` from
the activated `.venv`. Launch `hx` from inside the dev shell (direnv counts)
and all three resolve. Python tooling is never installed system-wide on
mortlake hosts.

## TODO (flesh out per project)

- Rename `my-python-project`, set real `description`
- Add runtime deps: `uv add ...`
- Tighten ruff config in pyproject `[tool.ruff]` if the project outgrows defaults
- Add a `[tool.pytest.ini_options]` section when the suite grows structure
