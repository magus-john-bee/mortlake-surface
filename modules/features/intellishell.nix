# IntelliShell — searchable shell command bookmarks with zsh hotkeys
# (ctrl+space search / ctrl+b bookmark / ctrl+l variables / ctrl+x fix,
# wired in zsh/zshrc.zsh). Import-based like podman/nginx/gh: no options
# — every host that imports this module gets it.
#
# Cross-host sync is manual via the CLI (gist id below); zshrc aliases:
#   iig  # intelli-shell import gist && intelli-shell export gist
#   ieg  # intelli-shell export gist
# GIST_TOKEN is exported by zshrc. Import is a union merge (idempotent);
# export PATCHes the gist — run it as john in a real shell only. An
# earlier options + systemd-timer version was simplified away; see git
# history.
_: {
  flake.nixosModules.intellishell =
    { pkgs, ... }:
    {
      environment = {
        etc."intellishell/config.toml".text = ''
          check_updates = false
          inline = true

          [gist]
          id = "4c83e47d1df90765651d45f73e87132c"
          token = ""

          [tui]
          keyboard_enhancement = true

          [search]
          mode = "auto"
        '';

        systemPackages = [ pkgs.intelli-shell ];
      };

      # Config symlink via tmpfiles L+ (was: mkdir+ln in zshrc on every
      # shell start). Lives here, not in zshrc — hosts without this
      # module never get a dangling link.
      systemd.tmpfiles.rules = [
        "d /home/john/.config/intelli-shell 0755 john users - -"
        "L+ /home/john/.config/intelli-shell/config.toml - - - - /etc/intellishell/config.toml"
      ];

      # tmpfs root: the bookmarks db must survive reboots.
      preservation.preserveAt."/persistent" = {
        users.john.directories = [ ".local/share/intelli-shell" ];
      };
    };
}
