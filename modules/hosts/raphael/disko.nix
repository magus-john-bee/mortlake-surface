{ inputs, ... }:
{
  flake.nixosModules.raphaelDisko =
    _:
    let
      primaryDisk = "/dev/nvme0n1";
    in
    {
      imports = [ inputs.disko.nixosModules.disko ];

      fileSystems."/nix".neededForBoot = true;
      fileSystems."/persistent".neededForBoot = true;

      disko.devices.nodev = {
        "/" = {
          fsType = "tmpfs";
          mountOptions = [
            "size=50%"
            "mode=755"
          ];
        };
      };

      disko.devices.disk.main = {
        device = primaryDisk;
        type = "disk";

        content = {
          type = "gpt";

          partitions = {
            boot = {
              name = "boot";
              size = "1M";
              type = "EF02";
            };

            esp = {
              name = "ESP";
              size = "1G";
              type = "EF00";

              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };

            swap = {
              size = "4G";

              content = {
                type = "swap";
                resumeDevice = true;
              };
            };

            root = {
              name = "root";
              size = "100%";

              content = {
                type = "luks";
                name = "crypted";

                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];

                  subvolumes = {
                    "/persistent" = {
                      mountOptions = [
                        "subvol=persistent"
                        "noatime"
                      ];
                      mountpoint = "/persistent";
                    };

                    "/nix" = {
                      mountOptions = [
                        "subvol=nix"
                        "noatime"
                      ];
                      mountpoint = "/nix";
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
}
