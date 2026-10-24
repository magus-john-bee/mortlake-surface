# Herdr — agent multiplexer (herdr.dev). "tmux for coding agents."
# Manages panes for Pi, Hermes, etc. Tracks lifecycle state
# (idle/working/blocked) and provides session restore.
#
# Packaged in numtide/llm-agents.nix (buildRustPackage + vendored Zig deps
# for libghostty-vt). Binary cache at cache.numtide.com (configured in
# nix-qol.nix).
#
# Config: declarative via wrapper (HERDR_CONFIG_PATH -> /etc herdr/config.toml,
# herdr/config.toml below) — no symlink, per the atuin shape. Herdr writes
# config.toml for in-TUI settings edits; those fail against the read-only
# /etc path, so settings live here. ~/.config/herdr IS preserved now
# (session.json lives there — see preservation note below); it was tmpfs
# until 2026-10-20.
# Agent integrations land in each agent's own config dir (e.g.
# ~/.pi/agent/extensions/), persisted where the agent module says so:
#   herdr integration install pi      (lifecycle hooks)
#   herdr integration install hermes  (lifecycle hooks)
# IMPERATIVE (one-time per fresh machine, for the always-on server below):
#   herdr integration install pi
#   herdr integration install hermes   # HERMES_HOME is exported shell-wide
# — without pi's, agent panes restore as plain shells after a reboot instead
# of resuming their conversations (native session restore needs the
# integration's reported session refs). Both installed on jehoel
# (pi v9, hermes v5 at $HERMES_HOME/plugins/herdr-agent-state, auto-enabled
# in hermes config.yaml by the installer).
{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.herdr = inputs.wrapper-modules.lib.wrapPackage (_: {
        inherit pkgs;
        package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr;
        env.HERDR_CONFIG_PATH = "/etc/herdr/config.toml";
      });
    };

  flake.nixosModules.herdr =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      herdrPkg = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.herdr;
      # The canonical NixOS user PATH, composed from the same profile
      # list the login environment uses (config.environment.profiles
      # is shell-form — substitute its $HOME/$USER/${XDG_STATE_HOME}).
      canonicalUserPath =
        let
          home = config.users.users.john.home;
          substitute =
            lib.replaceStrings
              [ "$HOME" "$USER" "\${XDG_STATE_HOME}" ]
              [ home "john" "${home}/.local/state" ];
        in
        lib.concatStringsSep ":" (
          [ "/run/wrappers/bin" ]
          ++ (lib.unique (map (p: "${substitute p}/bin") config.environment.profiles))
          ++ [ "${home}/.local/bin" ]
        );
    in
    {
      environment.etc."herdr/config.toml".source = ./herdr/config.toml;

      environment.systemPackages = [
        herdrPkg
      ];

      # Declarative plugin (herdr-annotate): flake input pinned to a rev,
      # copied at activation to a WRITABLE dir (the plugin's build steps
      # fetch binaries into plugin_root/bin — a store path is read-only),
      # then registered with `herdr plugin link` (serverless; replaces any
      # prior registration of the same plugin_id). Copy merges over the
      # destination so previously fetched bin/ survives; bumping the input
      # rev refreshes the checkout files but NOT the fetched binaries.
      # IMPERATIVE (runtime, one-time per fetch): the plugin's build steps
      # (scripts/fetch-herdr-annotate.sh, fetch-plannotator-tui.sh) download
      # binaries into plugin_root/bin on first herdr server start — network
      # required once. After bumping the herdr-annotate input rev, refresh
      # the fetched binaries manually:
      #   rm -rf ~/.local/share/herdr/plugins/herdr-managed-annotate/bin
      #   (then restart herdr to re-fetch; activation re-copies the checkout)
      system.activationScripts.herdr-plugin-annotate.text = ''
        set -e
        dest=/home/john/.local/share/herdr/plugins/herdr-managed-annotate
        mkdir -p "$dest"
        cp -rL --no-preserve=mode,ownership ${inputs.herdr-annotate}/. "$dest"/
        chown -R john:users /home/john/.local/share/herdr/plugins
        runuser -u john -- env HOME=/home/john ${herdrPkg}/bin/herdr plugin link "$dest" 2>&1 || echo "herdr plugin link failed (see IMPERATIVE note in herdr.nix)" >&2
      '';

      # plugins.json is DERIVED state (herdr rewrites it via atomic rename,
      # which a per-file bind mount breaks — EBUSY): it is
      # re-linked at every activation above AND at every login by this
      # oneshot, so a reboot without a switch still gets the plugin.
      # (.config/herdr is dir-level preserved, so plugins.json also
      # survives — the oneshot stays as the self-healing path.)
      systemd.user.services.herdr-plugin-annotate = {
        description = "Re-link herdr-managed annotate plugin (derived plugins.json)";
        wantedBy = [ "default.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${herdrPkg}/bin/herdr plugin link /home/john/.local/share/herdr/plugins/herdr-managed-annotate";
        };
      };

      # Always-on headless server: a herdr session exists
      # whenever jehoel is on — attach locally with `herdr`, or from the
      # phone via collie (same socket). `herdr server` is upstream's
      # headless mode; the TUI client is a pure attach.
      #
      # Deliberate stops stay stopped: `herdr server stop` exits 0 and
      # Restart=on-failure does not revive it — matches upstream semantics
      # (a stop is a decision, not a crash). Comes back at next boot.
      # Reboot semantics: snapshot restore brings the layout back as fresh
      # shells; agent panes resume their conversations via native session
      # restore ONLY after `herdr integration install pi` (see header) and
      # a client attach (terminal size/theme context) — collie's adapter
      # attach counts.
      systemd.user.services.herdr-server = {
        description = "Herdr headless server (persistent agent session)";
        wantedBy = [ "default.target" ];
        # Plugin must be registered before the first server start (its
        # build steps fetch binaries then — see IMPERATIVE in header).
        after = [ "herdr-plugin-annotate.service" ];
        wants = [ "herdr-plugin-annotate.service" ];
        # Phone-only operator cannot reset a failed unit (collie parity).
        startLimitIntervalSec = 0;
        serviceConfig = {
          Type = "simple";
          ExecStart = "${herdrPkg}/bin/herdr server";
          Restart = "on-failure";
          RestartSec = "5";
          # Panes inherit this unit's environment. At boot (linger) that is
          # systemd's minimal PATH, and the login-imported
          # __NIXOS_SET_ENVIRONMENT_DONE/__ETC_PROFILE_DONE guards stop pane
          # shells from re-deriving the NixOS environment — so set the
          # canonical PATH here and drop the guards.
          Environment = [ "PATH=${canonicalUserPath}" ];
          UnsetEnvironment = [
            "__NIXOS_SET_ENVIRONMENT_DONE"
            "__ETC_PROFILE_DONE"
          ];
        };
      };

      # Session/workspace state AND config survive reboots: `.config/herdr`
      # is preserved at DIR level because session_dir IS ~/.config/herdr
      # (verified live, hermes 0.9.5: `herdr session list --json` ->
      # session_dir) and no config/env key relocates it. session.json + session-snapshots/ + plugins.json live
      # there; dir-level bind mounts don't break herdr's atomic renames
      # (the per-file plugins.json lesson). Logs ride along and persist —
      # rotate by truncating if herdr-server.log ever matters.
      preservation.preserveAt."/persistent".users.john.directories = [
        ".local/share/herdr"
        ".config/herdr"
      ];
    };
}
