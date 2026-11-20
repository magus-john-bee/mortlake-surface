# Uriel — GrapheneOS Pixel 9 Pro (de-Googled, privacy-focused)
#
# GrapheneOS ships without Google Play Services.  This nix-on-droid
# config provides a full Linux userspace for CLI work, development,
# and self-provisioning via ADB (android-tools + fdroidcl are
# available in-path so the device can provision itself).
#
# Exposed as flake.nixOnDroidModules.urielConfiguration so that import-tree
# evaluates this file as a flake-parts module (the actual nix-on-droid
# module is the inner function).
#
# SSH to jehoel: alias + pinned host key + keepalive come declaratively
# from sshClient (ssh-aliases.nix). The client IDENTITY is generated
# on-device after bootstrap (ssh-keygen in the nix-on-droid home) and its
# public half lands in john.nix authorized_keys — private key never
# leaves the phone. Real Termux is a separate home; if SSH from Termux
# is ever wanted, pkg install openssh + copy or second key.
{ self, ... }:
{
  flake.nixOnDroidModules.urielConfiguration = {
    imports = [ self.nixOnDroidModules.droidCommon ];
  };
}
