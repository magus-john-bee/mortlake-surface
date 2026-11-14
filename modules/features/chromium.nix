# ── Config vs state ──────────────────────────────────────────
# ~/.config/chromium is 99% STATE (Cookies, Login Data, Bookmarks,
# History, Extension State, Local Storage, session restore) — persisted
# via the preservation entry below and never managed.
#
# Use programs.chromium.extraOpts for actual declarative settings — shows "managed by your organization".
#
# ── Why vanilla chromium, not ungoogled-chromium ─────────────
# nixpkgs builds Chromium from the open-source tree WITHOUT Google API
# keys: browser sign-in/sync, usage-metrics upload, and RLZ don't exist
# in the build at all. What still talks to Google: the variations seed
# (OS/version/locale fingerprint), the extension updater (installed IDs
# + versions — the mechanism behind force-install below), Safe Browsing
# list downloads, omnibox suggest to the default search engine, and
# geolocation on an explicit site grant. The default engine is pinned
# to DuckDuckGo and everything else switchable is off below.
#
# ungoogled-chromium nullifies every Google domain by construction —
# but that also nullifies Web Store CRX fetches: ExtensionInstallForce-
# list never fires, extensions never install or update, and a stale
# blocker/keepassxc-extension is a worse hole than a variations ping.
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
#   - MV2 is dead on modern Chromium: uBlock Origin Lite (MV3) filters
#     via declarativeNetRequest with ruleset caps and no per-site
#     dynamic rules. It is the Web Store option, not a choice; Nyxt's
#     blocker-mode remains the primary defense.
#
# ── KeePassXC-Browser chain ──────────────────────────────────
# Extension (force-installed below) → native messaging host (etc entry
# below) → keepassxc-proxy → running KeePassXC with Browser/Enabled
# (seeded in keepass.nix) and the database's own browser-integration
# settings (imperative, lives encrypted in the kdbx). The GUI must be
# running with the vault unlocked for the extension to see anything.
_: {
  flake.nixosModules.chromium =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        # basic store: greetd auto-login means no PAM-unlocked keyring (prompt
        # every launch); KeePassXC owns logins anyway.
        (chromium.override { commandLineArgs = "--password-store=basic"; })
      ];

      # Persist browser *state* only (profiles, logins, history, sessions).
      # Caches need no entry — preservation-common persists ~/.cache wholesale.
      preservation.preserveAt."/persistent".users.john.directories = [ ".config/chromium" ];

      programs.chromium = {
        enable = true;
        extensions = [
          # KeePassXC-Browser — official extension
          "oboonakemofpalcgghocfoadofidjkkk"
          # uBlock Origin Lite — MV3 successor of uBlock Origin (MV2, dead)
          "ddkjiahejlhfcafbddmgiahcphecmpfh"
          # Sakutto — on-device translation (PLaMo 3 via wllama wasm); the
          # only translator that works in this build — no Google API keys
          # means no built-in translate. Model (~0.5 GB) downloads from
          # Hugging Face into the profile on first use; see the 11
          # Translator-API-fallback languages that stay inert here.
          "mhlbjjijfkoghmcjndgdimhdlfkhadfl"
        ];
        extraOpts = {
          # Stops annoying modal
          "PasswordManagerEnabled" = false;
          # Omnibox keystrokes belong to DDG, not Google
          "DefaultSearchProviderEnabled" = true;
          "DefaultSearchProviderName" = "DuckDuckGo";
          "DefaultSearchProviderSearchURL" = "https://duckduckgo.com/?q={searchTerms}";
          # No as-you-type suggest traffic at all
          "SearchSuggestEnabled" = false;
          # No Google threat-list downloads; uBO Lite covers blocking
          "SafeBrowsingProtectionLevel" = 0;
        };
      };

      # KeePassXC native messaging host for Chromium browser integration.
      # nixpkgs' keepassxc does NOT ship the NMH manifest (upstream keeps it
      # in share/keepassxc/browser/ but the nixpkgs install drops it), so we
      # generate it: the proxy binary comes from the store (string context
      # keeps keepassxc in this file's closure), the origin is the official
      # KeePassXC-Browser extension ID from the force-list above.
      environment.etc."chromium/native-messaging-hosts/org.keepassxc.keepassxc_browser.json".text =
        builtins.toJSON
          {
            name = "org.keepassxc.keepassxc_browser";
            description = "KeePassXC integration with native messaging support";
            path = "${pkgs.keepassxc}/bin/keepassxc-proxy";
            type = "stdio";
            allowed_origins = [ "chrome-extension://oboonakemofpalcgghocfoadofidjkkk/" ];
          };
    };
}
