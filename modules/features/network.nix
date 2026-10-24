{ self, ... }:
{
  flake.nixosModules.network = _: {
    networking.firewall.enable = true;

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    # Shared SSH client config — single source of truth in
    # modules/features/ssh-aliases.nix (aliases + pinned host keys +
    # keep-alive). The nix-on-droid hosts consume the same strings via
    # environment.etc in their configuration.nix.
    programs.ssh.extraConfig = self.sshClient.configText;

    # Pinned host keys — ssh jehoel is not TOFU. See
    # ssh-aliases.nix for key provenance.
    programs.ssh.knownHosts = builtins.mapAttrs (_name: h: {
      hostNames = [ h.address ];
      inherit (h) publicKey;
    }) self.sshClient.hosts;
  };
}
