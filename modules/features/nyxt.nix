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
        # webkitgtk 2.54.2's DMABUF renderer crashes Nyxt at window creation
        # under niri (WebKit bug 280210 / nyxt#3641; worked on 2.54.1 before
        # the 2026-11-14 nixpkgs bump). Env var is the accepted workaround —
        # drop it once webkitgtk passes under niri. --set-default so an
        # explicit env override still wins.
        systemPackages = [
          (pkgs.nyxt.overrideAttrs (prev: {
            postFixup = (prev.postFixup or "") + ''
              wrapProgram $out/bin/nyxt \
                --set-default WEBKIT_DISABLE_DMABUF_RENDERER 1
            '';
          }))
        ];

        etc."nyxt/config.lisp".source = ./nyxt/config.lisp;
        # Kept for inspection; the tmpfiles C+ rule below seeds from the
        # STORE path — C+ from an /etc symlink plants a symlink (read-only)
        # instead of a writable file.
        etc."nyxt/config-seed.lisp".source = ./nyxt/config-seed.lisp;
      };

      # C+ copies only when the destination is absent — first activation
      # seeds the overlay; afterwards the user's file is never touched.
      systemd.tmpfiles.rules = [
        "d /home/john/.config/nyxt 0755 john users - -"
        "C+ /home/john/.config/nyxt/config.lisp 0644 john users - ${./nyxt/config-seed.lisp}"
      ];

      # Overlay + auto-config persistence, plus browser state (tmpfs home).
      preservation.preserveAt."/persistent".users.john.directories = [
        ".config/nyxt"
        ".local/share/nyxt"
      ];
    };
}
