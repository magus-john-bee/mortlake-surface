# KeePassXC — the app (usage module).
#
# The vault's SYNC lives in the syncthing modules, not here — sync
# topology belongs with topology:
#   - syncthing-lead.nix (jehoel, hub): folder "kp-vault", shared with
#     uriel (+ raphael once its device ID lands — TODO there)
#   - syncthing-follow.nix (raphael): spoke side of the same folder
# Vault path on every peer: /var/lib/syncthing/kp-vault/*.kdbx
# (kp-vault, not vault — ~/vault is the plaintext notes/writing tree)
#
# Operating discipline (the part that actually matters):
# - The .kdbx is a plain encrypted file riding normal file sync — safe
#   for any transport (KeePassXC docs; the app has no sync features by
#   design).
# - CONFLICTS: Syncthing leaves .sync-conflict-* copies; resolve with
#   Database > Merge from Database (UUID merge; losing version goes to
#   entry history — nothing is lost).
# - THE HAZARD: entries held open in edit mode on two devices at once
#   clobber SILENTLY (keepassxc#10225) — no conflict file is produced.
#   One writer at a time.
# - KEY FILE (if used) travels out of band (USB/wormhole) — never
#   inside the synced folder.
# - Backups, three layers: jehoel restic covers /var/lib/syncthing
#   wholesale (vault + version history); staggered versioning keeps
#   ~a year of old versions on every peer; the kdbx itself keeps
#   entry-level history internally.
_: {
  flake.nixosModules.keepass =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.keepassxc ];

      # App-level browser-integration toggle, declaratively seeded.
      # keepassxc.ini is MIXED config + state (window geometry, recent
      # vaults): the live file is preserved below and never managed; the
      # seed only sets defaults on a fresh tmpfs home (C+ copies only
      # when the destination is absent — a preserved file always wins).
      # The C+ source is the STORE path, not the /etc symlink: C+ from a
      # symlink source plants a symlink (read-only!) instead of a file.
      environment.etc."keepassxc/keepassxc-seed.ini".source = ./keepass/keepassxc-seed.ini;
      systemd.tmpfiles.rules = [
        "d /home/john/.config/keepassxc 0755 john users - -"
        "C+ /home/john/.config/keepassxc/keepassxc.ini 0644 john users - ${./keepass/keepassxc-seed.ini}"
      ];

      preservation.preserveAt."/persistent".users.john.directories = [
        ".config/keepassxc" # app settings (browser toggle) + recents/geometry
        ".local/state/keepassxc" # machine-local settings (Config "Local" group)
      ];

      # The KeePassXC app process IS the server for the browser integration
      # (keepassxc-proxy relays extension traffic to it) — upstream has no
      # headless daemon mode. So: autostart tray-resident with the vault open
      # but LOCKED. The master password is typed once per login, by design —
      # auto-unlock would mean storing it, which hollows out the vault. The
      # tray/minimize keys ride in keepassxc-seed.ini; noctalia's bar provides
      # the StatusNotifierWatcher they depend on. An explicit quit (exit code
      # 0) is respected — Restart only covers crashes.
      systemd.user.services.keepassxc = {
        description = "KeePassXC — tray-resident; serves KeePassXC-Browser";
        wantedBy = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.keepassxc}/bin/keepassxc /var/lib/syncthing/kp-vault/keepass.kdbx";
          Restart = "on-failure";
          RestartSec = "2s";
        };
      };

      # IMPERATIVE (once per database; stored encrypted INSIDE the kdbx,
      # so it cannot be declarative — and it syncs to every vault peer):
      # Database Settings → Browser Integration → enable + pick the
      # exposed group; then Connect once from the browser extension and
      # confirm — the association is remembered in the kdbx.
    };
}
