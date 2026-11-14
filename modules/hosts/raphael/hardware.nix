{ inputs, ... }:
{
  flake.nixosModules.raphaelHardware =
    { lib, ... }:
    {
      imports = [
        inputs.nixos-hardware.nixosModules.framework-12-13th-gen-intel
      ];

      boot = {
        initrd.availableKernelModules = [
          "xhci_pci"
          "nvme"
          "usb_storage"
          "uas"
          "sd_mod"
        ];
        kernelModules = [ "kvm-intel" ];
        loader = {
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
        };
      };

      hardware = {
        bluetooth.enable = true;
        enableRedistributableFirmware = lib.mkDefault true;
      };

      services.fwupd.enable = true;

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
