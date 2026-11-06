# Jujutsu — first-class VCS for agent work.
#
# jj needs its own user identity: it does not read the *wrapped* git
# config's user.name/email (git.nix injects that at wrapper runtime), and
# ~/.config/jj would be tmpfs-wiped anyway. House pattern (see herdr.nix):
# declarative /etc/jj/config.toml + JJ_CONFIG env in a wrapper, so the
# identity and defaults travel with the system, not the home dir.
#
# git.colocate = true: new jj repos get real .git dirs — jj workspaces
# register as real git worktrees, which is what makes herdr's
# worktree-backed display/open see them (verified on mortlake).
{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.jj = inputs.wrapper-modules.lib.wrapPackage (_: {
        inherit pkgs;
        package = pkgs.jujutsu;
        env.JJ_CONFIG = "/etc/jj/config.toml";
      });
    };

  flake.nixosModules.jj =
    { pkgs, ... }:
    {
      environment.etc."jj/config.toml".source = ./jj/config.toml;

      environment.systemPackages = [
        inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.jj
      ];
    };
}
