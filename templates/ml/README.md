# ML Project

Created from the `mortlake#ml` template.

## Setup

```bash
nix develop        # enter dev shell (Python, uv, Jupyter, rdflib, git-lfs)
just sync          # install project deps from pyproject.toml (mlflow, dvc, ...)
```

## Architecture

Two declarative layers:

| Layer | Tool | File | Contents |
|---|---|---|---|
| Stable foundation | Nix | `flake.nix` | Python, uv, Jupyter, rdflib, git-lfs |
| Project deps | uv | `pyproject.toml` + `uv.lock` | mlflow, dvc, torch, transformers, ... |

Both are tracked in git. Adding a package means writing to `pyproject.toml`
via `uv add`, which also updates the lockfile. Reproducible across machines.

## Commands

| Command | Description |
|---|---|
| `just sync` | Install/sync deps from pyproject.toml |
| `just mlflow` | Start MLflow tracking server (UI on :5000) |
| `just jupyter` | Start JupyterLab |
| `just dvc-init` | Initialize DVC for data versioning |

## Adding ML Packages

```bash
uv add torch transformers peft trl datasets
```

For CUDA PyTorch on NVIDIA cloud instances:

```bash
uv add torch --index-url https://download.pytorch.org/whl/cu121
```
