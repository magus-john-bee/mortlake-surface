_: {
  flake.nixosModules.printing =
    { pkgs, ... }:
    {
      services = {
        printing = {
          enable = true;
          drivers = [ pkgs.brlaser ];
        };
        avahi = {
          enable = true;
          nssmdns4 = true;
          openFirewall = true;
        };
      };

      # Queue for the Brother HL-2280DW (living room laser). 2011
      # host-based engine — no AirPrint/IPP-everywhere, hence brlaser.
      # Router DNS doesn't register the printer's node name, so the queue
      # pins the IP. If DHCP ever reassigns it, reserve 192.168.50.254 in
      # the router or update the URI below.
      hardware.printers = {
        ensurePrinters = [
          {
            name = "HL-2280DW";
            deviceUri = "socket://192.168.50.254:9100";
            # drv URI = <path under share/cups/drv>/<PCFileName from brlaser.drv>
            model = "drv:///brlaser.drv/br2280d.ppd";
            description = "Brother HL-2280DW (living room)";
            location = "Living room";
          }
        ];
        ensureDefaultPrinter = "HL-2280DW";
      };
    };
}
