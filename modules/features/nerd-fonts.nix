_: {
  flake.nixosModules.nerd-fonts =
    { pkgs, ... }:
    {
      fonts.packages = with pkgs; [
        nerd-fonts.jetbrains-mono
        nerd-fonts.fira-code
        nerd-fonts.meslo-lg
        nerd-fonts.symbols-only
      ];
    };
}
