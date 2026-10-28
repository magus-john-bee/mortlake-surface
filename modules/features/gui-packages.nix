# GUI packages — no zed-editor, no zed/garnix cache. keepassxc instead of proton-pass.
_: {
  flake.nixosModules.gui-packages =
    { pkgs, ... }:
    let
      ankiWith = pkgs.anki.withAddons [
        pkgs.ankiAddons.anki-connect
      ];
    in
    {
      environment.systemPackages = with pkgs; [
        ankiWith
        keepassxc
        librewolf
        logseq
        meld
        nemo-with-extensions
        kdePackages.okular
        vlc
      ];

      # Nemo outside GNOME: gvfs for trash:// and mount:// locations,
      # dconf so GSettings prefs have a backend to write to.
      services.gvfs.enable = true;
      programs.dconf.enable = true;

      # Electron apps (logseq, anki) may need this
      nixpkgs.config.permittedInsecurePackages = [
        "electron-39.8.10"
      ];
    };
}
