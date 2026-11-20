# Jehoel hardware — based on mab's Intel NUC pattern + AMD GPU via OCuLink.
# OCuLink is just physical PCIe-over-cable. The GPU appears as a normal PCIe
# device — no special drivers needed beyond standard AMD graphics setup.
_: {
  flake.nixosModules.jehoelHardware =
    {
      config,
      lib,
      modulesPath,
      ...
    }:
    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

      nixpkgs.hostPlatform = "x86_64-linux";

      boot = {
        initrd.availableKernelModules = [
          "xhci_pci"
          "ahci"
          "nvme"
          "usb_storage"
          "usbhid"
          "sd_mod"
          "sdhci_pci"
        ];
        # amdgpu for the eGPU card over OCuLink (RDNA3 7900 XTX). Same
        # driver for all AMD cards.
        #
        # kvm-amd for the 7840HS.
        kernelModules = [
          "kvm-amd"
          "amdgpu"
        ];
        loader = {
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
        };
      };

      hardware = {
        # Intel AX211 BT (8087:0032) — BT half of the M.2 card, USB-attached
        # internally (btusb). WiFi half is PCIe (8086:2725). Firmware via
        # enableRedistributableFirmware. Pairings persist via /var/lib/bluetooth.
        bluetooth.enable = true;
        enableRedistributableFirmware = lib.mkDefault true;
        cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

        # AMD GPU — 7900 XTX (RDNA3, gfx1100) has full ROCm support.
        amdgpu.opencl.enable = true;
        graphics.enable = true;
      };
    };
}
