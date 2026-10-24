# ── Config vs state ──────────────────────────────────────────
# ~/.config/chromium is 99% STATE (Cookies, Login Data, Bookmarks,
# History, Extension State, Local Storage, session restore) — persisted
# via the preservation entry below and never managed.
#
# Use programs.chromium.extraOpts for actual declarative settings — shows "managed by your organization".
#
# ── Extensions ───────────────────────────────────────────────
# programs.chromium.extensions becomes the ExtensionInstallForcelist
# policy.
#
#   - An ID is the extension's stable IDENTITY: the first 128 bits of
#     SHA-256(public key of the extension's keypair), rendered base-16
#     with a-p in place of 0-f. It never changes across releases.
#   - Find one via chrome://extensions (Developer mode toggle) or the
#     32-letter string in the Web Store detail URL.
#
# Version-locking / upgrades:
#   - Force-installed extensions are NOT version-locked. Chromium
#     checks the Web Store for updates at startup and every few hours
#     and self-updates — "upgrading" requires no action here, ever.
#   - Adding an ID force-installs it silently on next launch; REMOVING
#     an ID auto-UNINSTALLS it (policy supersedes user installs).
#
_: {
  flake.nixosModules.chromium =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        # basic store: greetd auto-login means no PAM-unlocked keyring (prompt
        # every launch); KeePassXC owns logins anyway.
        (ungoogled-chromium.override { commandLineArgs = "--password-store=basic"; })
      ];

      # Persist browser *state* only (profiles, logins, history, sessions).
      # Caches need no entry — preservation-common persists ~/.cache wholesale.
      preservation.preserveAt."/persistent".users.john.directories = [ ".config/chromium" ];

      programs.chromium = {
        enable = true;
        extensions = [
          # KeePassXC-Browser — official extension
          "oboonakemofpalcgghocfoadofidjkkk"
          # uBlock Origin
          "cjpalhdlnbpafiamejdnhcphjbkeiagm"
        ];
        extraOpts = {
          # Stops annoying modal
          "PasswordManagerEnabled" = false;
        };
      };

      # KeePassXC native messaging host for Chromium browser integration
      environment.etc."chromium/native-messaging-hosts/org.keepassxc.keepassxc_browser.json".source =
        "${pkgs.keepassxc}/share/keepassxc/browser/native-messaging-hosts/org.keepassxc.keepassxc_browser.json";
    };
}
