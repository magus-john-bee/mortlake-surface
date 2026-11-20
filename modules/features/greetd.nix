_: {
  flake.nixosModules.greetd =
    { pkgs, ... }:
    {
      services.greetd = {
        enable = true;
        settings = {
          initial_session = {
            command = "${pkgs.niri}/bin/niri-session";
            user = "john";
          };
          default_session = {
            command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd ${pkgs.niri}/bin/niri-session";
            user = "greeter";
          };
        };
      };
    };
}
