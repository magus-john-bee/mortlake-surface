{ inputs, ... }:
{
  flake.nixosModules.preservation-common =
    { ... }:
    {
      imports = [ inputs.preservation.nixosModules.preservation ];

      # With tmpfs root + preservation bind-mount, /etc/machine-id already
      # resolves to /persistent/etc/machine-id (on btrfs, not tmpfs).
      # The commit service expects a tmpfs-backed transient ID and fails
      # with "not on a temporary file system". Mask it — preservation
      # already handles persistence.
      systemd.services.systemd-machine-id-commit.enable = false;

      preservation = {
        enable = true;

        preserveAt."/persistent" = {
          # Host-side preservation binds were never ro — /persistent is a
          # plain rw btrfs mount and these units mount rw binds from it at
          # boot. Every "ro mount" sighting on jehoel came from inside the
          # hermes-agent service namespace (unit sets ProtectSystem=strict;
          # real fix = gno.nix/funes.nix ReadWritePaths on that unit).
          # The rw below is inert for binds of the rw /persistent view; it
          # stays only to avoid churning every mount unit at the next
          # switch. Per-entry mountOptions still override it.
          commonMountOptions = [ "rw" ];

          directories = [
            # Disk-backed, not persisted for its own sake: / is tmpfs (50%
            # RAM), so an unpersisted /tmp would put every build scratch dir
            # and transcode intermediate in RAM. Boot survival is a side
            # effect; growth stays bounded by systemd's upstream tmpfiles age
            # rule for /tmp (10d, enforced by the daily clean timer).
            {
              directory = "/tmp";
              user = "john";
              group = "users";
              mode = "1777";
            }
            {
              directory = "/var/lib/nixos";
              inInitrd = true;
            }
            "/var/log"
            {
              directory = "/var/lib/syncthing";
              user = "john";
              group = "users";
            }
          ];

          files = [
            {
              file = "/etc/machine-id";
              inInitrd = true;
            }
            {
              file = "/etc/ssh/ssh_host_ed25519_key";
              mode = "0600";
              # sops runs in initrd on systemd-initrd hosts, where it
              # derives the age key from this file. Without inInitrd the mount
              # lands in stage 2, after activation, so decryption gets an empty
              # key file ("0 successful groups required, got 0").
              inInitrd = true;
            }
            "/etc/ssh/ssh_host_ed25519_key.pub"
            {
              file = "/etc/ssh/ssh_host_rsa_key";
              mode = "0600";
            }
            "/etc/ssh/ssh_host_rsa_key.pub"
          ];

          users.john = {
            directories = [
              ".ssh"
              ".cache"
              ".npm"
            ];
          };
        };
      };
    };
}
