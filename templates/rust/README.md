# Rust Project

Created from the `mortlake#rust` template.

## Setup

```bash
nix develop        # enter dev shell (rustc, cargo, clippy, rustfmt, rust-analyzer, bacon, just)
just build         # first compile
```

With direnv (`.envrc`), entering the directory puts the toolchain on PATH
automatically.

## Architecture

Two declarative layers, same split as `mortlake#python`:

| Layer | Tool | File | Contents |
|---|---|---|---|
| Stable foundation | Nix | `flake.nix` | rustc, cargo, clippy, rustfmt, rust-analyzer, bacon, just — all from one nixpkgs revision, so versions stay coherent |
| Project deps | cargo | `Cargo.toml` + `Cargo.lock` | runtime + dev dependencies |

Both are tracked in git (`Cargo.lock` too — this is an application). `cargo
add <crate>` writes `Cargo.toml` and updates `Cargo.lock`. Reproducible
across machines; the toolchain is identical, the deps are locked.

## Commands

| Command | Description |
|---|---|
| `just build` | Debug build |
| `just run -- args` | Run with args |
| `just test` | Run tests |
| `just check` | Fast type-check (cargo check) |
| `just lint` | `cargo fmt --check` + clippy `-D warnings` |
| `just fmt` | Apply formatting + clippy fixes |
| `just watch` | bacon — rebuild/retest on save |

## Helix

No helix config needed in the project. Helix's rust defaults are
rust-analyzer (LSP) + rustfmt (formatter) — both come from the nix dev shell.
Launch `hx` from inside the dev shell (direnv counts) and they resolve.
`RUST_SRC_PATH` is exported by the shell so rust-analyzer can index std.

## TODO (flesh out per project)

- Rename `my-rust-project`, set real `description`, add `license`
- Add deps: `cargo add ...`; git deps get pinned to a rev/tag in `Cargo.toml`
- If link times hurt with heavy deps (lance, ort, tokio), add `mold` to the
  shell and `-C link-arg=--fuse-ld=mold` to `.cargo/config.toml`
