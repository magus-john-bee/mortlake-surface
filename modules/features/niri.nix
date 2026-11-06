{ self, inputs, ... }:
{
  flake.nixosModules.niri =
    { pkgs, ... }:
    {
      programs.niri = {
        enable = true;
        package = self.packages.${pkgs.stdenv.hostPlatform.system}.myNiri;
      };

      # nixpkgs' niri module mkDefaults gnome-keyring on ("recommended by
      # upstream" for desktop secret storage). We run NO secret service:
      # passwords live in keepass (kp-vault), Bridge's keychain is pass,
      # chromium is --password-store=basic. A live org.freedesktop.secrets
      # would (a) pop keyring-unlock modals at Bridge CLI logins and
      # (b) become Bridge's PREFERRED keychain — reintroducing the
      # boot-time unlock dependency the email module designs out.
      services.gnome.gnome-keyring.enable = false;
    };

  perSystem =
    {
      pkgs,
      lib,
      self',
      ...
    }:
    {
      packages.myNiri = inputs.wrapper-modules.wrappers.niri.wrap {
        inherit pkgs;
        runtimePkgs = [ pkgs.wl-clipboard ];
        settings = {
          # Phantom HDMI display: the fiber HDMI run to the HT-Z9F soundbar
          # latches the bar's EDID and holds HPD asserted permanently, so
          # the GPU always reports "connected" even with the TV off. Keep
          # it out of the desktop by default (audio is unaffected — verified
          # live: the HDMI sink survives niri output off, and playback works).
          # EDID match, not connector name — shared with raphael, whose
          # HDMI-A-1 may be a real display. Toggle at runtime with
          # `niri msg output <name> on|off` (tv-is-on / tv-is-off aliases).
          outputs."Sony SONY AVSYSTEM" = {
            off = _: { };
          };

          spawn-at-startup = [
            (lib.getExe self'.packages.myNoctalia)
          ];

          xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;

          input.keyboard.xkb = {
            layout = "us";
            options = "ctrl:nocaps";
          };

          input.touchpad = {
            tap = _: { };
            natural-scroll = _: { };
          };

          layout.gaps = 5;

          binds = {
            # Custom binds (differ from niri defaults)
            "Mod+T" = _: {
              props.hotkey-overlay-title = "Open a Terminal: ghostty";
              content.spawn-sh = lib.getExe self'.packages.ghostty;
            };
            "Mod+S" = _: {
              props.hotkey-overlay-title = "Run an Application: noctalia";
              content.spawn-sh = "${lib.getExe self'.packages.myNoctalia} ipc call launcher toggle";
            };
            "Super+Alt+L" = _: {
              props.hotkey-overlay-title = "Lock the Screen: swaylock";
              content.spawn-sh = "${lib.getExe pkgs.swaylock} -f";
            };
            "XF86AudioRaiseVolume" = _: {
              props.allow-when-locked = true;
              content.spawn-sh = "${lib.getExe' pkgs.wireplumber "wireplumber"} set-volume @DEFAULT_AUDIO_SINK@ 0.05+";
            };
            "XF86AudioLowerVolume" = _: {
              props.allow-when-locked = true;
              content.spawn-sh = "${lib.getExe' pkgs.wireplumber "wireplumber"} set-volume @DEFAULT_AUDIO_SINK@ 0.05-";
            };
            "XF86AudioMute" = _: {
              props.allow-when-locked = true;
              content.spawn-sh = "${lib.getExe' pkgs.wireplumber "wireplumber"} set-mute @DEFAULT_AUDIO_SINK@ toggle";
            };

            # Default binds (matching niri upstream)
            "Mod+Shift+Slash".show-hotkey-overlay = _: { };

            "XF86AudioPlay" = _: {
              props.allow-when-locked = true;
              content.spawn-sh = "${lib.getExe pkgs.playerctl} play-pause";
            };
            "XF86AudioPause" = _: {
              props.allow-when-locked = true;
              content.spawn-sh = "${lib.getExe pkgs.playerctl} play-pause";
            };
            "XF86AudioStop" = _: {
              props.allow-when-locked = true;
              content.spawn-sh = "${lib.getExe pkgs.playerctl} stop";
            };
            "XF86AudioPrev" = _: {
              props.allow-when-locked = true;
              content.spawn-sh = "${lib.getExe pkgs.playerctl} previous";
            };
            "XF86AudioNext" = _: {
              props.allow-when-locked = true;
              content.spawn-sh = "${lib.getExe pkgs.playerctl} next";
            };

            "XF86MonBrightnessUp" = _: {
              props.allow-when-locked = true;
              content.spawn = [
                (lib.getExe pkgs.brightnessctl)
                "--class=backlight"
                "set"
                "+10%"
              ];
            };
            "XF86MonBrightnessDown" = _: {
              props.allow-when-locked = true;
              content.spawn = [
                (lib.getExe pkgs.brightnessctl)
                "--class=backlight"
                "set"
                "10%-"
              ];
            };

            "Mod+O" = _: {
              props.repeat = false;
              content.toggle-overview = _: { };
            };

            "Mod+Q" = _: {
              props.repeat = false;
              content.close-window = _: { };
            };

            "Mod+Left".focus-column-left = _: { };
            "Mod+Down".focus-window-down = _: { };
            "Mod+Up".focus-window-up = _: { };
            "Mod+Right".focus-column-right = _: { };
            "Mod+H".focus-column-left = _: { };
            "Mod+J".focus-window-down = _: { };
            "Mod+K".focus-window-up = _: { };
            "Mod+L".focus-column-right = _: { };

            "Mod+Ctrl+Left".move-column-left = _: { };
            "Mod+Ctrl+Down".move-window-down = _: { };
            "Mod+Ctrl+Up".move-window-up = _: { };
            "Mod+Ctrl+Right".move-column-right = _: { };
            "Mod+Ctrl+H".move-column-left = _: { };
            "Mod+Ctrl+J".move-window-down = _: { };
            "Mod+Ctrl+K".move-window-up = _: { };
            "Mod+Ctrl+L".move-column-right = _: { };

            "Mod+Home".focus-column-first = _: { };
            "Mod+End".focus-column-last = _: { };
            "Mod+Ctrl+Home".move-column-to-first = _: { };
            "Mod+Ctrl+End".move-column-to-last = _: { };

            "Mod+Shift+Left".focus-monitor-left = _: { };
            "Mod+Shift+Down".focus-monitor-down = _: { };
            "Mod+Shift+Up".focus-monitor-up = _: { };
            "Mod+Shift+Right".focus-monitor-right = _: { };
            "Mod+Shift+H".focus-monitor-left = _: { };
            "Mod+Shift+J".focus-monitor-down = _: { };
            "Mod+Shift+K".focus-monitor-up = _: { };
            "Mod+Shift+L".focus-monitor-right = _: { };

            "Mod+Shift+Ctrl+Left".move-column-to-monitor-left = _: { };
            "Mod+Shift+Ctrl+Down".move-column-to-monitor-down = _: { };
            "Mod+Shift+Ctrl+Up".move-column-to-monitor-up = _: { };
            "Mod+Shift+Ctrl+Right".move-column-to-monitor-right = _: { };
            "Mod+Shift+Ctrl+H".move-column-to-monitor-left = _: { };
            "Mod+Shift+Ctrl+J".move-column-to-monitor-down = _: { };
            "Mod+Shift+Ctrl+K".move-column-to-monitor-up = _: { };
            "Mod+Shift+Ctrl+L".move-column-to-monitor-right = _: { };

            "Mod+Page_Down".focus-workspace-down = _: { };
            "Mod+Page_Up".focus-workspace-up = _: { };
            "Mod+U".focus-workspace-down = _: { };
            "Mod+I".focus-workspace-up = _: { };
            "Mod+Ctrl+Page_Down".move-column-to-workspace-down = _: { };
            "Mod+Ctrl+Page_Up".move-column-to-workspace-up = _: { };
            "Mod+Ctrl+U".move-column-to-workspace-down = _: { };
            "Mod+Ctrl+I".move-column-to-workspace-up = _: { };

            "Mod+Shift+Page_Down".move-workspace-down = _: { };
            "Mod+Shift+Page_Up".move-workspace-up = _: { };
            "Mod+Shift+U".move-workspace-down = _: { };
            "Mod+Shift+I".move-workspace-up = _: { };

            "Mod+WheelScrollDown" = _: {
              props.cooldown-ms = 150;
              content.focus-workspace-down = _: { };
            };
            "Mod+WheelScrollUp" = _: {
              props.cooldown-ms = 150;
              content.focus-workspace-up = _: { };
            };
            "Mod+Ctrl+WheelScrollDown" = _: {
              props.cooldown-ms = 150;
              content.move-column-to-workspace-down = _: { };
            };
            "Mod+Ctrl+WheelScrollUp" = _: {
              props.cooldown-ms = 150;
              content.move-column-to-workspace-up = _: { };
            };

            "Mod+WheelScrollRight".focus-column-right = _: { };
            "Mod+WheelScrollLeft".focus-column-left = _: { };
            "Mod+Ctrl+WheelScrollRight".move-column-right = _: { };
            "Mod+Ctrl+WheelScrollLeft".move-column-left = _: { };

            "Mod+Shift+WheelScrollDown".focus-column-right = _: { };
            "Mod+Shift+WheelScrollUp".focus-column-left = _: { };
            "Mod+Ctrl+Shift+WheelScrollDown".move-column-right = _: { };
            "Mod+Ctrl+Shift+WheelScrollUp".move-column-left = _: { };

            "Mod+1".focus-workspace = 1;
            "Mod+2".focus-workspace = 2;
            "Mod+3".focus-workspace = 3;
            "Mod+4".focus-workspace = 4;
            "Mod+5".focus-workspace = 5;
            "Mod+6".focus-workspace = 6;
            "Mod+7".focus-workspace = 7;
            "Mod+8".focus-workspace = 8;
            "Mod+9".focus-workspace = 9;
            "Mod+Ctrl+1".move-column-to-workspace = 1;
            "Mod+Ctrl+2".move-column-to-workspace = 2;
            "Mod+Ctrl+3".move-column-to-workspace = 3;
            "Mod+Ctrl+4".move-column-to-workspace = 4;
            "Mod+Ctrl+5".move-column-to-workspace = 5;
            "Mod+Ctrl+6".move-column-to-workspace = 6;
            "Mod+Ctrl+7".move-column-to-workspace = 7;
            "Mod+Ctrl+8".move-column-to-workspace = 8;
            "Mod+Ctrl+9".move-column-to-workspace = 9;

            "Mod+BracketLeft".consume-or-expel-window-left = _: { };
            "Mod+BracketRight".consume-or-expel-window-right = _: { };

            "Mod+Comma".consume-window-into-column = _: { };
            "Mod+Period".expel-window-from-column = _: { };

            "Mod+R".switch-preset-column-width = _: { };
            "Mod+Shift+R".switch-preset-column-width-back = _: { };
            "Mod+Ctrl+Shift+R".switch-preset-window-height = _: { };
            "Mod+Ctrl+R".reset-window-height = _: { };

            "Mod+F".maximize-column = _: { };
            "Mod+Shift+F".fullscreen-window = _: { };
            "Mod+M".maximize-window-to-edges = _: { };
            "Mod+Ctrl+F".expand-column-to-available-width = _: { };

            "Mod+C".center-column = _: { };
            "Mod+Ctrl+C".center-visible-columns = _: { };

            "Mod+Minus".set-column-width = "-10%";
            "Mod+Equal".set-column-width = "+10%";
            "Mod+Shift+Minus".set-window-height = "-10%";
            "Mod+Shift+Equal".set-window-height = "+10%";

            "Mod+V".toggle-window-floating = _: { };
            "Mod+Shift+V".switch-focus-between-floating-and-tiling = _: { };

            "Mod+W".toggle-column-tabbed-display = _: { };

            "Print".screenshot = _: { };
            "Ctrl+Print".screenshot-screen = _: { };
            "Alt+Print".screenshot-window = _: { };

            "Mod+Escape" = _: {
              props.allow-inhibiting = false;
              content.toggle-keyboard-shortcuts-inhibit = _: { };
            };

            "Mod+Shift+E".quit = _: { };
            "Ctrl+Alt+Delete".quit = _: { };

            "Mod+Shift+P" = _: {
              props.hotkey-overlay-title = "Hibernate";
              content.spawn-sh = "systemctl hibernate";
            };
          };
        };
      };
    };
}
