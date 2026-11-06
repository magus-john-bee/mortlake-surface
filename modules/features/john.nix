{ self, lib, ... }:
{
  flake.nixosModules.john =
    { config, pkgs, ... }:
    let
      home = config.users.users.john.home;
      sshDir = "${home}/.ssh";
      privateKey = "${sshDir}/id_ed25519";
      publicKey = "${privateKey}.pub";
    in
    {
      # After update-users-groups.pl writes /etc/group, nscd may still
      # serve stale "group not found" results from before the switch
      # (e.g. first migration to mutableUsers=false). This causes
      # cascading failures in sops, hermes, and other activation scripts
      # that resolve the "users" group. Force nscd to flush.
      system.activationScripts = {
        users.text = lib.mkAfter ''
          systemctl reload-or-restart nscd 2>/dev/null || true
        '';

        # Copy the host's SSH key as john's user key. On a single-user machine
        # where john IS root (NOPASSWD:ALL), maintaining a separate user key
        # is pointless ceremony. The host key is already generated, persisted,
        # and used by sops. One key, one identity, zero friction.
        #
        # We copy (not symlink) because the host key is root:root 600, and SSH
        # refuses keys where (st_mode & 077) != 0 — setfacl would trip that.
        # Running every boot is idempotent; the content never changes.
        john-ssh-keys.text = lib.mkAfter ''
          mkdir -p ${sshDir}
          chmod 0700 ${sshDir}
          cp /etc/ssh/ssh_host_ed25519_key ${privateKey}
          cp /etc/ssh/ssh_host_ed25519_key.pub ${publicKey}
          chown john:users ${privateKey} ${publicKey}
          chmod 0600 ${privateKey}
          chmod 0644 ${publicKey}
        '';

        # Default ACL: any file/dir created under /home/john — even by root
        # via sudo — automatically gets rwx for john. Eliminates the chown
        # dance when root writes into john's home (common with restic restores,
        # sops, manual fixes, etc.). Applies to new files only (-d = default).
        john-default-acls.text = lib.mkAfter ''
          if [ -d /home/john ]; then
            ${pkgs.acl}/bin/setfacl -R -d -m u:john:rwx /home/john
          fi
        '';
      };

      users.mutableUsers = false;
      users.users.john = {
        isNormalUser = true;
        description = "john";
        shell = "${self.packages.${pkgs.stdenv.hostPlatform.system}.zsh}/bin/zsh";
        linger = true;
        extraGroups = [
          "networkmanager"
          "wheel"
        ];
        hashedPassword = "$6$nhupSF2Neq$m61opyOxxlZAt10pdgSw/ORYlLOGa8efAF7dfKVRas8Wl4hVaSUI4d5poAk9VnMFY/xejKkZjst26INwMWrZZ.";
        openssh.authorizedKeys.keys = [
          # Full set from thoth's /etc/ssh/authorized_keys.d/john (corpus) —
          # keep every existing access path (mab, xtx, puck) across the
          # mortlake switch.
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBHRm1rqdQJBm82C1fn8sNzP+gG691b70MOSRI5Vsn0m john@mab"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILxMx03v5a9RBU5PH979XTuXYXsDzjiu/t0/ACdB+b9X john@xtx"
          # root@thoth (uriel) key removed at decommission: uriel is
          # being cancelled, and Hermes now runs on jehoel so the SSH-diagnostics
          # hop uriel->jehoel is obsolete. A decommissioned box kept no standing
          # access into the build host.
          # nix-on-droid@uriel (Pixel 9 Pro) — client identity generated
          # on-device post factory reset; public half recorded
          # here per modules/hosts/uriel/configuration.nix bootstrap contract
          # (private key never leaves the device). Regenerate on next reset.
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINDMWQq2qOsHL0z1CbxIJwURUxiwBJwmilIu8hK5tHkG nix-on-droid@localhost"
          # jehoel host key — deploy-rs / rebuild sessions originate from jehoel
          # (build host). Same identity thoth's key uses on other mortlake hosts.
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDPeQiYDQJGWpEnXZSwVIFm8CJ+95iOwhl06SfGnap0z root@jehoel"
          # raphael host key — installed as "puck", renamed raphael (the
          # corpus-era john@puck key was the previous install's identity and
          # is dead). Label updated to root@raphael on-host; key
          # material unchanged (fingerprint
          # SHA256:TRxhxCAb9lFPp0LaTflhbRj5TNzV8BDkjRhxbkcJQ9Q). Verified via
          # ssh-to-age: derives to the &raphael anchor in .sops.yaml — same
          # provenance standard as ssh-aliases.nix (jehoel entry).
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN1xWsgUtOgd7ZTRvn9VMzlGH4kJLdLDcFr8blIHQ8qK root@raphael"
        ];
      };

      security.sudo = {
        # No password for john — single-user machine, sudo is a formality.
        extraRules = [
          {
            users = [ "john" ];
            commands = [
              {
                command = "ALL";
                options = [ "NOPASSWD" ];
              }
            ];
          }
        ];
        # Suppress the first-use lecture ("We trust you have received...").
        extraConfig = ''
          Defaults lecture = never
        '';
      };

      # Polkit: allow wheel users to perform privileged actions without
      # a password prompt. This is the *other* auth stack — even with
      # NOPASSWD sudo, desktop prompts (mounting, networking, systemd
      # service control via GUI) route through polkit and would still
      # ask for a password. On a single-user machine this is pure friction.
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (subject.isInGroup("wheel")) {
            return polkit.Result.YES;
          }
        });
      '';

      nix.settings.trusted-users = [
        "root"
        "john"
      ];
    };
}
