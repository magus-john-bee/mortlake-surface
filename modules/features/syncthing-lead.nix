# Syncthing lead node (jehoel). Device IDs are public identifiers — not secrets.
# GUI auth is OFF: the syncthing docs' condition for an authless GUI is
# that it not be reachable from untrusted networks — the vhost below
# allows only tailnet + LAN sources, and no public DNS record exists
# (the name resolves on the tailnet via split-DNS only).
let
  baseDomain = "otwell.dev";
  syncthingPort = 8384;
in
_: {
  flake.nixosModules.syncthing-lead = _: {
    services = {
      # Tailnet-only + LAN: no public record (ddclient list); nginx
      # refuses every other source outright. Empty GUI user = auth
      # disabled server-side (syncthing ignores the password then;
      # "" also clears the stored bcrypt hash via the config PATCH).
      nginx.virtualHosts."syncthing.${baseDomain}" = {
        forceSSL = true;
        useACMEHost = "otwell.dev";
        locations."/".proxyPass = "http://localhost:${toString syncthingPort}";
        locations."/".extraConfig = ''
          allow 100.64.0.0/10; # Tailscale CGNAT
          allow 192.168.0.0/16; # home LAN (192.168.50.0/24 today)
          allow 10.0.0.0/8; # LAN renumbering headroom
          deny all;
        '';
      };

      syncthing = {
        enable = true;
        user = "john";
        overrideDevices = true;
        overrideFolders = true;
        openDefaultPorts = true;
        settings = {
          devices = {
            # Device IDs are public keys — not secrets.
            # Hub-and-spoke: spokes (pixel8, pixel9, raphael) only know
            # jehoel; folders are shared with registered peers, and peers
            # are not introducers, so they never sync with each other.
            # TODO(raphael): get raphael's syncthing device ID
            # (`syncthing --device-id` or GUI: Actions > Show ID), then
            # uncomment + add "raphael" to the st devices and the vault
            # peers list in keepass.nix:
            # "raphael".id = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
            "pixel8".id = "7YWROAI-Z66BW2L-UE2DPVL-WOEMEBH-FNRKHPQ-NVDXRHR-EQOXICC-CDRLLAF";
            # uriel (Pixel 9 Pro) — new device ID after the factory reset
            "uriel".id = "NJJT572-SPO5KTH-75G7R6L-OVXIL4O-FLOKRYV-CKBOP7R-2AB7UDV-CGYT6AM";
          };
          folders = {
            "st" = {
              path = "/var/lib/syncthing/st";
              devices = [
                "pixel8"
                "uriel"
              ];
            };

            # Keepass vault — dedicated folder, NOT inside st: small
            # sync surface, and the phone subscribes to ONLY this
            # folder. Named kp-vault, not vault, to avoid confusion
            # with ~/vault (plaintext notes/writing).
            # Usage discipline (merge-on-conflict, single-writer,
            # key-file-out-of-band) documented in keepass.nix.
            # TODO(raphael): add "raphael" to devices once its ID lands
            # (see devices TODO above) — and it arrives automatically on
            # raphael via syncthing-follow.
            "kp-vault" = {
              path = "/var/lib/syncthing/kp-vault";
              devices = [ "uriel" ];
              # Staggered versioning = the KeePassXC-recommended sync
              # safety net (old versions on a decaying schedule:
              # ~per-minute recent, thinning to per-week old; maxAge
              # 365d). Recovers from bad overwrites/deletions that sync
              # would otherwise propagate everywhere.
              versioning = {
                type = "staggered";
                params.maxAge = "31536000";
              };
            };
          };
          gui = {
            # Auth off (see header): empty user disables the GUI login;
            # password "" clears the stored hash via the module's
            # config PATCH. Access gate is the nginx allow list above.
            user = "";
            password = "";
            insecureSkipHostcheck = true;
          };
        };
      };
    };

    systemd = {
      tmpfiles.rules = [
        "d /var/lib/syncthing 0755 john users"
        "d /var/lib/syncthing/st 0755 john users"
        # 0700: keepass vault — only john (syncthing + KeePassXC run as
        # john) needs access. Usage side: keepass.nix.
        "d /var/lib/syncthing/kp-vault 0700 john users"
      ];
    };
  };
}
