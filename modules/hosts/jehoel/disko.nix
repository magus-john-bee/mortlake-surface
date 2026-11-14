# Jehoel disk layout — placeholder based on mab pattern.
# tmpfs root (size=50%, mode=755), btrfs /persistent + /nix, swap.
# Fill in actual partition layout during physical provisioning.
{ inputs, ... }:
{
  flake.nixosModules.jehoelDisko = {
    imports = [ inputs.disko.nixosModules.disko ];

    disko.devices = {
      disk = {
        main = {
          type = "disk";
          device = "/dev/nvme0n1"; # adjust during provisioning
          content = {
            type = "gpt";
            partitions = {
              esp = {
                size = "1G";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                };
              };
              btrfs = {
                size = "100%";
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];
                  subvolumes = {
                    persistent = {
                      mountpoint = "/persistent";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                    nix = {
                      mountpoint = "/nix";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                    swap = {
                      mountpoint = "/swap";
                      mountOptions = [ "noatime" ];
                    };
                  };
                };
              };
            };
          };
        };
      };

      nodev."/" = {
        fsType = "tmpfs";
        mountOptions = [
          "size=50%"
          "mode=755"
        ];
      };
    };

    fileSystems = {
      "/nix".neededForBoot = true;
      "/persistent".neededForBoot = true;
    };

    # Swapfile on the /swap btrfs subvolume
    swapDevices = [
      {
        device = "/swap/swapfile";
        size = 32 * 1024;
      }
    ];
  };
}
