# Email — Proton Bridge + himalaya (jehoel only).
#
# Topology: Bridge (systemd user service, starts with the graphical
# session — greetd auto-login on jehoel) exposes IMAP on 127.0.0.1:1143
# with its own TLS CA. Himalaya reads through it; the account config
# (./himalaya/config.toml) has NO send backend — sending is impossible
# by construction. Drafts APPEND to the Drafts folder and sync to all
# Proton apps; the user sends. That is the enforced boundary:
# draft-yes, send-no. Deletes are move-to-Trash (recoverable);
# permadelete requires deleting from Trash itself — deliberate.
#
# One-time bootstrap (as john, on jehoel, before this is useful):
#   1. pass init <gpg-id>        # Bridge stores creds in a keyring;
#      `pass` is the headless one (needs a gpg key: gpg --full-generate-key
#      if none exists).
#   2. protonmail-bridge --cli   # log in; note the MAILBOX password it
#      shows (not the Proton account password)
#   3. sops --set '["proton-bridge-password"] "<mailbox password>"' \
#        modules/features/secrets.yaml
#   4. rebuild; verify: himalaya envelope list
_: {
  flake.nixosModules.email =
    { pkgs, ... }:
    {
      services.protonmail-bridge = {
        enable = true;
        # Credential store for headless Bridge (see bootstrap step 1).
        # pass holds ONE thing: Bridge's vault key — a machine/infra
        # secret that must answer non-interactively at boot (greetd
        # auto-login; nobody types a password). NOT a password manager
        # competing with keepass: user passwords live in kp-vault.
        # gnupg goes in systemPackages, not just the service path: pass
        # shells out to gpg, and the user needs `pass init` in their own
        # shell during bootstrap.
        path = [ pkgs.pass ];
      };

      environment = {
        systemPackages = [
          (pkgs.writeShellScriptBin "himalaya" ''
            exec ${pkgs.himalaya}/bin/himalaya --config /etc/himalaya/config.toml "$@"
          '')
          pkgs.pass
          pkgs.gnupg
        ];
        etc."himalaya/config.toml".source = ./himalaya/config.toml;
        etc."himalaya/bridge-cert.pem".source = ./himalaya/bridge-cert.pem;
      };

      # see comment on bootstrap section
      sops.secrets."proton-bridge-password" = {
        owner = "john";
        sopsFile = ./secrets.yaml;
      };

      preservation.preserveAt."/persistent".users.john.directories = [
        ".config/protonmail"
        ".local/share/protonmail"
        ".password-store"
        ".gnupg"
      ];
    };
}
