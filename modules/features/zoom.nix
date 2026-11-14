# Zoom — video conferencing client (zoom-us in nixpkgs; unfree, allowed at
# pkgs creation in each host's default.nix). No wrapper/config injection:
# zoom manages its own state, which the preservation entries below carry
# across tmpfs-root reboots. Recordings (~/Zoom) are not preserved — add a
# users.john entry there if recording meetings ever becomes a thing.
_: {
  flake.nixosModules.zoom =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.zoom-us ];

      # Login + settings survive reboots on the tmpfs-root hosts.
      preservation.preserveAt."/persistent".users.john.directories = [
        ".config/zoom"
        ".zoom"
      ];
    };
}
