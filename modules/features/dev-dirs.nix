_: {
  flake.nixosModules.dev-dirs = _: {
    # Directory creation
    systemd.tmpfiles.rules = [
      "d /home/john/vault              0755 john users - -"
      "d /home/john/src                0755 john users - -"
    ];

    # Persist across reboots (tmpfs-root hosts)
    preservation.preserveAt."/persistent".users.john.directories = [
      "src"
      "vault"
    ];

  };
}
