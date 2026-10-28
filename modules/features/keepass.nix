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
    };
}
