# Remiel — Viture Pro Neckband (near-vanilla Android, Play present)
#
# XR neckband computer (Android, Snapdragon XR2). Shares the same base
# nix-on-droid userspace as uriel.
# Exposed as flake.nixOnDroidModules.remielConfiguration so that import-tree
# evaluates this file as a flake-parts module.
{ self, ... }:
{
  flake.nixOnDroidModules.remielConfiguration = {
    imports = [ self.nixOnDroidModules.droidCommon ];
  };
}
