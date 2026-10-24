# mortlake

Personal monorepo for all code and configs. Named after John Dee's house at Mortlake — library, workshop, observatory.

NixOS configuration using the **Dendritic Pattern** — every `.nix` file under `modules/` is a self-contained flake-parts module, auto-discovered by `import-tree`.

## Hosts

| Host | Role | Hardware |
|------|------|----------|
| **Jehoel** | Server + desktop — Hermes, Jellyfin, Transmission, Mealie, Syncthing, AMD GPU | Intel NUC + OCuLink eGPU |
| **Raphael** | Framework 12 laptop — daily driver | Framework 12 |
| **Uriel** | Android phone (GrapheneOS) — nix-on-droid | Pixel 9 Pro |
| **Remiel** | Android XR neckband (near-vanilla) — nix-on-droid | Viture Pro Neckband |

## Build & Deploy

```bash
nixos-rebuild switch --flake .#jehoel     # Build and switch (NixOS hosts)
nix build .#nixosConfigurations.jehoel    # Build without switching
nix-on-droid switch --flake .#uriel       # Apply phone config
```

## Repository Structure

```
├── flake.nix                     # mkFlake + import-tree ./modules
├── modules/
│   ├── parts.nix                 # flake-parts systems list
│   ├── features/                 # Feature modules (auto-discovered)
│   └── hosts/                    # Host configurations
├── skills/                       # Agent skills for Hermes/Pi (~68 SKILL.md files)
├── sites/                        # Personal static sites
│   └── dev-resume/               # Hugo resume site (johnotwell.com)
├── android/                      # GrapheneOS + vanilla Android provisioning
└── justfile                      # lint, eval, schema validation, skill syncing
```

## Secrets (sops-nix)

All machines use SSH-derived age keys for sops. sops-nix derives the age key from the SSH host key (`/persistent/etc/ssh/ssh_host_ed25519_key`) at activation time.

### Adding a new machine

1. Get the age public key: `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`
2. Add to `.sops.yaml` under `keys:` with a descriptive anchor
3. Add to the relevant `key_groups` in `creation_rules`
4. Re-encrypt: `sops updatekeys modules/features/secrets.yaml`

## Build & Test

```bash
just eval jehoel          # Evaluate a host config without building
just dry jehoel           # Dry-build (eval + derivations, no switch)
just lint                # nix fmt + statix + deadnix + schema validation
just lint-fix            # Auto-fix linting issues
```

## Clean install with nixos-anywhere

```bash
nix run nixpkgs#nixos-anywhere -- --flake .#<host> --target-host john@<ip> --phases kexec,disko,install,reboot
```

## Restic Backups

Each host has a restic backup job configured in `restic.nix`. All backup paths and excludes are listed per-host in the `hostConfig` attrset — service modules no longer self-register paths.

## Design Principles

**Single-user by design.** These machines have one human user (john). Unless there is a compelling reason otherwise, all services run as `john:users` and all data directories are owned by `john:users`.

## What This Repo Does Not Contain

- **Knowledge base** — Markdown notes live in `~/vault/logbook` (separate repo)
- **Public projects** — career-ops and other release-intended projects stay separate

## Repo topology (2026-10-16)

**This repo is the private canonical** (`uriel-mortlake/mortlake`): full tree, normal branch protection, everything lands here first. Skills live in `skills/` (agent-shared library) and in a separate archive repo; personal content (android profiles, private notes) stays here.

**Public surface** (`magus-john-bee/mortlake-surface`): an orphan single-commit snapshot of the allow-listed public paths, auto-published by CI (`.github/workflows/publish-surface.yml`) on every push to main. The surface is ENUMERATED (allow-list), so new private content cannot leak by default. The flake is checked against the snapshot before it publishes — `nix build github:magus-john-bee/mortlake-surface#...` works without auth. sops ciphertext ships verbatim (age-encrypted to host keys; that's the design).
