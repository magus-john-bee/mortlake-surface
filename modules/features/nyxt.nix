# Nyxt — keyboard-driven Common Lisp browser.
#
# Config shape (live-hackable + declarative):
#   /etc/nyxt/config.lisp              mortlake base (this repo), read-only
#   ~/.config/nyxt/config.lisp         writable overlay: loads the base,
#                                      then whatever hacks are pasted below
#                                      the fold. Seeded once via tmpfiles C+
#                                      (copy-if-absent) and persisted —
#                                      C+ never clobbers user edits, unlike
#                                      the L+ symlink this replaces.
#   ~/.config/nyxt/auto-config.3.lisp  nyxt's own settings-UI writes; now
#                                      also persisted (same directory entry).
# Confirming a hack = move it into nyxt/config.lisp, rebuild, delete it
# from the overlay. Base loads first, overlay forms override.
_: {
  flake.nixosModules.nyxt =
    { pkgs, ... }:
    {
      environment = {
        systemPackages = with pkgs; [ nyxt ];

        etc."nyxt/config.lisp".source = ./nyxt/config.lisp;
        # Seed source for the tmpfiles C+ rule below.
        etc."nyxt/config-seed.lisp".source = ./nyxt/config-seed.lisp;
      };

      # C+ copies only when the destination is absent — first activation
      # seeds the overlay; afterwards the user's file is never touched.
      systemd.tmpfiles.rules = [
        "d /home/john/.config/nyxt 0755 john users - -"
        "C+ /home/john/.config/nyxt/config.lisp 0644 john users - /etc/nyxt/config-seed.lisp"
      ];

      # Overlay + auto-config persistence, plus browser state (tmpfs home).
      preservation.preserveAt."/persistent".users.john.directories = [
        ".config/nyxt"
        ".local/share/nyxt"
      ];
    };
}
