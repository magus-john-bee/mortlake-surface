_: {
  flake.nixosModules.sound =
    { config, lib, ... }:
    let
      # Hosts whose audio output is a soundbar hanging off a secondary display
      # connector of the GPU. ALSA cards expose one profile at a time, and the
      # default profile (first connector, e.g. the DP monitor) never surfaces
      # the soundbar as a sink. These rules pin the card profile and
      # default-sink election declaratively — no reliance on saved WirePlumber
      # state, which is ephemeral on tmpfs-root hosts.
      #
      # Keys with dots (node.name, device.name, ...) are FLAT WirePlumber
      # properties, not nested Nix attrsets — hence the quoting.
      soundbarHosts = {
        jehoel = {
          # 5700 XT audio (pci c5:00.1): PCM 0 = DP monitor, PCM 1 = HDMI
          # feeding a Sony HT-Z9F. Verified against /proc/asound/card1/eld.
          card = "alsa_card.pci-0000_c5_00.1";
          sink = "alsa_output.pci-0000_c5_00.1.hdmi-stereo-extra1";
          description = "Sony HT-Z9F Soundbar (HDMI)";
          profiles = [
            "output:hdmi-stereo-extra1"
            "output:hdmi-stereo"
          ];
        };
      };
      cfg = soundbarHosts.${config.networking.hostName} or null;
    in
    {
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;

        wireplumber.extraConfig = lib.mkIf (cfg != null) {
          soundbar = {
            # Make the soundbar sink win default-sink election and switch to
            # the media's native sample rate instead of resampling to 48k.
            "monitor.alsa.rules" = [
              {
                matches = [ { "node.name" = cfg.sink; } ];
                actions.update-props = {
                  "node.description" = cfg.description;
                  "priority.session" = 1900;
                  "audio.allowed-rates" = [
                    44100
                    48000
                    88200
                    96000
                    176400
                    192000
                  ];
                };
              }
            ];
            # Pin the card profile to the soundbar's HDMI output (fallback:
            # first HDMI output) whenever no saved state exists.
            "device.profile.priority.rules" = [
              {
                matches = [ { "device.name" = cfg.card; } ];
                actions.update-props = {
                  priorities = cfg.profiles;
                };
              }
            ];
          };
        };
      };
    };
}
