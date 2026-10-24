# Collie deployment research — AT-9WE6

Research date: **2026-10-19** (all live checks via `gh` API + local reads on jehoel this date).
Scope: what collie is, its security model, how to deploy it on jehoel behind nginx with no
Tailscale, and an end-to-end verification plan. Deployment itself is follow-up work — no repo
edits were made by this subagent.

---

## 1. What collie is

- **Repo**: `AltanS/collie` (MIT, TypeScript, 1,404 stars, homepage colliepwa.dev, pushed
  2026-10-19). A self-hosted **PWA (mobile web app, no app store)** that drives terminal AI
  agents running in a multiplexer — **Herdr is the primary supported target** (tmux/zellij
  experimental). Exactly the "mobile herdr client for pi agents" use case in the aven task.
- **Architecture**: a small Bun process (the "bridge") serves the static PWA + a JSON API on
  **loopback only** (`127.0.0.1:8787` default). The browser never touches the multiplexer; the
  Herdr adapter dials herdr's Unix socket (`HERDR_SOCKET_PATH`, default
  `~/.config/herdr/herdr.sock` — verified against jehoel's actual socket path, see §7). The
  browser **polls** `/api/snapshot`; actions are plain HTTP POSTs (`/api/pane/:id/reply|keys`).
  WebSockets are *not* used.
- **Default ingress** is `tailscale serve` (Variant A). Mortlake has **no Tailscale** (verified:
  no tailscale/wireguard anywhere in mortlake modules) — §5 covers the substitute.

## 2. Versions (datestamped)

| What | Version | Date / provenance |
| --- | --- | --- |
| Pinned in mortlake flake input `llm-agents` (numtide/llm-agents.nix @ `e85b9921`) | **1.21.3** | verified live: `packages/collie/hashes.json` at the locked rev; tag published 2026-10-14 |
| llm-agents.nix `main` today | **1.22.6** | last commit 2026-10-19T12:21Z — a plain input bump lands 1.22.6, not 1.23.0 |
| Upstream latest release | **1.23.0** | 2026-10-19 |

Pi-relevant changelog findings (from CHANGELOG.md, read 2026-10-19):

- **1.22.0–1.22.4 had an urgent pi bug**: a pi pane with an extension footer (pi supports
  extension footers, e.g. `custom-footer.ts`) refused *every* send. Fixed in **1.22.5**
  (2026-10-17). The pinned **1.21.3 predates the regression** — safe, but old.
- **1.22.5/1.23.0 pi improvements**: "Chat follows a pi session after `/new`", pi's thinking
  level shown beside the model label, pi verified in the upstream harness lab.
- 1.23.0 adds walky-talky (agents message each other / you message them; `collie skill install pi`
  teaches pi the verbs), Hermes Agent question/approval buttons, Tasks pill.
- Release cadence is ~1–3/day; `collie update` **declines on packaged installs** (updates come
  from nix — i.e. from bumping the llm-agents input). Recommend deploying **1.22.6 via input
  bump** (gets the pi fix + 6 days of fixes; 1.23.0 not yet packaged upstream).

## 3. Security model (docs/security.md, read 2026-10-19)

**Collie is remote shell access by design.** One API call types arbitrary keystrokes into a live
pane with John's full user privileges. No sandbox, no allow-list. "Treat the URL as a root
login."

Layers that exist independent of Tailscale:

1. **Device pairing — always on, the real door.** Since 1.18.0 *every* `/api` route needs a
   paired device's token, **reads included**. An unpaired browser sees only the pair screen.
   Codes are minted on-host (`collie pair`, 8 chars, 10-min TTL, QR); only `/api/health` and
   `/api/pair` stay open. 5 failed code attempts invalidate the code; >10 pairing
   attempts/min/source-IP → 429 (source = last `X-Forwarded-For` entry behind a same-host proxy).
   Revoke: `collie devices revoke <label>` (live, no restart). Optional expiry:
   `collie pair --expires 30d`.
2. **Host validation fails closed** — requests whose `Host` isn't loopback / a known tailnet
   name / an entry in `COLLIE_PUBLIC_HOSTS` are refused (anti DNS-rebinding).
3. **Same-origin gate** on the API (`COLLIE_ALLOWED_ORIGINS`).
4. **Secret masking on by default** (`COLLIE_REDACT`): sk-…/ghp_…/JWTs/PEM/bearer/named values
   masked to `•` in all five phone-bound paths.
5. **Audit log**: `<state-dir>/audit.log` records writes, uploads, pane lifecycle.
6. Loopback-only bind; refuses `0.0.0.0` without an explicit opt-out.

What Tailscale would have added and we lose: `COLLIE_TRUSTED_USER` (Tailscale-User-Login header
injected by `tailscale serve`) is **inactive without Tailscale**. The substitute is the front
door's own auth (§5).

Residual risks to accept consciously: paired phone = open shell (stolen unlocked phone);
on-device cache keeps masked pane text ≤24h; Files view can read any file under a workspace
folder incl. `.env`s; the project's own posture is "keep the URL on a private network, never on
the public internet" — with basic auth + pairing (two independent gates, one of which is
rate-limited and code-minted-on-host) public exposure is defensible but is **John's call**, and
this report recommends it only with both gates on.

## 4. Variant C — the no-Tailscale deployment (docs/deployment.md)

Upstream's blessed shape for exactly our case: reverse proxy as the only front door.

- Bridge stays on loopback; proxy must (1) authenticate, (2) proxy to `127.0.0.1:$COLLIE_PORT`,
  (3) **forward the public `Host` unchanged**, (4) not cache `sw.js`/`index.html`.
- Required `.env`: `COLLIE_SKIP_SERVE=1`, `COLLIE_PUBLIC_HOSTS=collie.otwell.dev`,
  `COLLIE_ALLOWED_ORIGINS=https://collie.otwell.dev`.
- `COLLIE_DEVICE_HEADER`/`COLLIE_DEVICE_ALLOWLIST` (Variant B per-device authz) only make sense
  with an identity-aware proxy that injects a per-device header — we have none; skip. Pairing
  covers device identity.
- Proxy must run on the same host (collie refuses non-loopback connections) — nginx on jehoel ✓.

## 5. Recommended deployment on jehoel

Follows the established sb.otwell.dev / aven.otwell.dev patterns (nginx + ACME vhost, declarative
systemd user service, activation-script config, preservation) — all verified in
mortlake @ current checkout:

### 5.1 Package

Use `inputs.llm-agents.packages.${system}.collie` directly (no wrapper needed — default herdr
socket path already matches jehoel; herdr.nix wraps herdr only for `HERDR_CONFIG_PATH`, which
collie doesn't read). The llm-agents package is a from-source bun2nix build installing
`$out/bin/collie` (makeWrapper around `bun run …/cli/main.ts`) + `$out/lib/collie/{bridge,cli,
systemd,web/dist,…}`.

### 5.2 New module `modules/features/collie.nix` → `flake.nixosModules.collie`

Import it in jehoel's configuration.nix under "AI tooling" (next to `nixosModules.herdr`).

**systemd user service** — declarative unit mirroring upstream `systemd/collie.service` (fetched
2026-10-19) the way aven.nix declaratively replaces `aven daemon install`:

```nix
systemd.user.services.collie = {
  description = "Collie (herdr mobile PWA bridge)";
  wantedBy = [ "default.target" ];
  startLimitIntervalSec = 0;           # upstream: phone-only operator can't reset-failed
  serviceConfig = {
    Type = "simple";
    WorkingDirectory = "${colliePkg}/lib/collie";
    ExecStart = "${colliePkg}/bin/collie _exec-bridge";
    Restart = "on-failure";
    RestartSec = "5";
    NoNewPrivileges = true;            # upstream hardening
    PrivateTmp = true;
    # ProtectSystem deliberately NOT set (upstream comment: state dir is env-driven)
  };
};
```

Environment via unit + `EnvironmentFile=-%h/.config/collie/.env` (leading `-`: absent file is
not fatal): `COLLIE_PORT=8787`, `COLLIE_PLUGIN_ROOT=${colliePkg}/lib/collie`,
`HERDR_PLUGIN_CONFIG_DIR=%h/.config/collie`, `COLLIE_STATE_DIR=%h/.local/state/collie`.

Linger is already enabled for john on jehoel (verified live: `Linger=yes`) — the service
survives logout/reboot, as upstream's install docs require.

**`.env`** — declarative, via activation script (aven-config precedent; `~/.config` is tmpfs on
mortlake):

```bash
COLLIE_SKIP_SERVE=1
COLLIE_MUX=herdr                      # skip the interactive first-run multiplexer probe
COLLIE_PORT=8787
COLLIE_PUBLIC_HOSTS=collie.otwell.dev
COLLIE_ALLOWED_ORIGINS=https://collie.otwell.dev
COLLIE_PUBLIC_URL=https://collie.otwell.dev   # status/QR/crew address
```

No secrets in it → plain store-path file or generated copy; no sops needed for collie itself.

**Preservation** (pairing tokens must survive reboots or the phone re-pairs every boot):

```nix
preservation.preserveAt."/persistent".users.john.directories = [
  ".local/state/collie"    # devices.json, audit.log, uploads, walky/, sent.jsonl
  ".config/collie"         # user-editable config.toml, quick-replies.toml, sources.json
];
```

(.env is re-provisioned by activation each boot; dir-level preservation, so no per-file
bind-mount rename hazard — the lesson recorded in herdr.nix re plugins.json.)

### 5.3 nginx vhost — `collie.otwell.dev` (sb/aven pattern + auth)

```nix
services.nginx.virtualHosts."collie.otwell.dev" = lib.mkIf config.services.nginx.enable {
  forceSSL = true;
  enableACME = true;   # ACME defaults already set in nginx.nix (email johnbee@otwell.dev)
  basicAuthFile = config.sops.templates."collie-htpasswd".path;   # see below
  locations."/.well-known/acme-challenge".root = "/var/lib/acme/acme-challenge";
  locations."/" = {
    proxyPass = "http://127.0.0.1:8787";
    extraConfig = ''
      # REQUIRED: nginx's default proxy_set_header Host $proxy_host would send
      # Host: 127.0.0.1:8787 and collie's host validation fails closed.
      proxy_set_header Host $host;
      # collie's pairing rate-limiter takes the source IP from the last XFF entry
      # when the connection comes from loopback.
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;   # bridge sends HSTS on https
      client_max_body_size 25m;     # file attachments (camera-roll images)
    '';
  };
};
```

- **Do not enable proxy caching** on this vhost (`sw.js`/`index.html` must stay uncached or the
  PWA can't update; nginx doesn't cache by default — just never add `proxy_cache` here).
- Websocket upgrade directives unnecessary (collie polls plain HTTP).
- Optional hardening: `limit_req` zone on `/api/pair` (collie already 429s at 10/min/IP; a
  nginx-level limit adds a layer before basic-auth-reuse mistakes matter).

**Auth decision — basic auth via sops**: this is the "auth substitute" the task asks for.
Rationale over alternatives:

| Option | Verdict |
| --- | --- |
| nginx basic auth (htpasswd in sops) | **Recommended.** Two independent gates (basic auth + pairing); works on Android PWA (credentials cached same-origin, SW fetches include them); sops template must be readable by nginx (owner `nginx` or root + group nginx — not john-only like dd-client's john-owned templates). |
| Rely on pairing alone | Rejected as sole gate on a public vhost: collie is shell-by-design; docs explicitly say keep it off the public internet without a login in front. |
| `COLLIE_DEVICE_HEADER` + allowlist | Needs an identity-aware proxy injecting per-device headers; none exists on jehoel. |
| IP allowlist | Home IP is dynamic (ddclient exists for this reason); phone on cellular changes IPs. |
| Cloudflare Access / CF Tunnel | Would work (`COLLIE_ACCESS_TEAM`+`AUD` verified by the bridge) but moves ingress to CF — a bigger architectural change than the task wants. |
| mTLS client certs | Strongest, but painful with mobile PWAs/service workers. |

Generate the htpasswd entry once (`openssl passwd -apr1`), store in sops as
`collie-basic-auth` → template `collie-htpasswd` (one line `john:$apr1$…`).

Note: sb and aven vhosts themselves carry no HTTP-level auth (their apps have app-layer
pairing/tokens); collie gets basic auth because its pairing gate is thinner than aven's
invitation model and its power (arbitrary shell) is greater.

### 5.4 DNS — one-time imperative

1. At Porkbun, create an **A record** `collie.otwell.dev` → current home IP (IPv4-only per
   dd-client config). ACME HTTP-01 needs it resolvable + router 443→jehoel forward (already in
   place for sb/aven — same path, no router change).
2. Add `"collie.${baseDomain}"` to the `domains` list in `modules/features/dd-client.nix`
   (Porkbun DDNS, 5-min interval) so the record tracks the dynamic IP.

### 5.5 First run (imperative, once)

```bash
systemctl --user restart collie
collie doctor                 # front-door row should show the proxy mount + no tailscale
collie pair                   # prints code + QR for the phone
# phone (uriel): open https://collie.otwell.dev (basic auth), Settings → Paired devices → code
collie devices list
```

## 6. Phone side — uriel (GrapheneOS Pixel 9 Pro)

- **PWA install**: from Vanadium menu "Add to Home screen"/"Install app". No store needed (by
  design). Requires HTTPS with a trusted cert → ACME ✓.
- **Web Push: likely non-functional** — Chromium-on-Android push rides Play Services/FCM;
  uriel is de-Googled (nix-on-droid config confirms no Play Services assumption).
  *Unverified — test on device.* Impact is low: collie is poll-based; the dashboard updates
  whenever the PWA is open. Push is a notification nicety, not a dependency.
- **Dictation**: standard input box works with system voice dictation (README); built-in
  Whistle voice input is optional/off by default — skip initially.

## 7. Live state on jehoel (checked 2026-10-19 ~17:00 EDT)

- `collie` **not installed**; ports 8787/8788/8443 free; no `~/.config/collie`,
  no `~/.local/state/collie`.
- **herdr client 0.9.5 installed; herdr server NOT running** (`herdr status`: "server: status:
  not running"); socket would be `/home/john/.config/herdr/herdr.sock` (matches collie's
  default). `~/.config/herdr/` holds plugins.json + plugins/ (herdr-annotate linked) — plugins
  were re-linked today, so herdr has run recently, but the persistent server is down right now.
- **Consequence**: collie against a down herdr server shows no panes (adapter can't dial the
  socket). **Open decision for John**: daemonize herdr (a `herdr server` systemd user unit, or
  just keep launching herdr in a terminal — its server persists across client detach) so collie
  has something to mirror, or accept that collie only mirrors while herdr is up. Recommend at
  minimum documenting "herdr must be running" next to the collie unit; a `herdr.service` user
  unit is a separate small task (needs a headless-server usage check upstream — unverified).
- Linger=yes for john; `/persistent/home/john/.local/state/` exists (aven precedent).

## 8. End-to-end verification checklist (post-deploy)

1. `systemctl --user status collie` — active, `After=default.target`, no start-limit stalls.
2. `curl -s -u john:… https://collie.otwell.dev/api/health` → JSON (no basic-auth creds → 401;
   wrong Host handling → collie-side refusal showing in bridge log).
3. `collie doctor` → front-door row correct; warns while no device is paired (expected until 4).
4. `collie pair` → phone pairs over WAN/LTE (proves public reachability + both auth gates).
5. From phone: dashboard shows herdr panes once herdr runs; send a reply to a pi pane; Esc /
   Ctrl+C from the keys board; verify typed text lands in the pane (on jehoel, in herdr).
6. `collie devices list` shows the phone; audit.log records the writes.
7. PWA installs on uriel home screen; survives a jehoel reboot (preservation of pairing state)
   without re-pairing.
8. Negative tests: unpaired incognito browser → only pair screen; revoked device → "device not
   paired"; no-basic-auth curl → 401.

## 9. Unverified / open items

- llm-agents `main` packages 1.22.6 today; **1.23.0 not yet packaged** (upstream updates daily —
  recheck at deploy time). Whether the input bump lands cleanly in mortlake's eval is untested
  here (no repo edits permitted for this subagent).
- Web Push on GrapheneOS/Vanadium (expect: no).
- Whether herdr should be an always-on user service (John's call; see §7).
- Exact sops→nginx file ownership for the htpasswd template (needs nginx-readable; follow the
  root/nginx-owned pattern, not dd-client's john-owned one).
- iOS Safari basic-auth re-prompt quirk is documented behavior for basic-auth PWAs generally —
  irrelevant for uriel (Android) but worth knowing if the vhost is ever opened from an iPhone.

## 10. Sources

- AltanS/collie README, ARCHITECTURE.md, HERDR_API.md, systemd/collie.service, .env.example —
  via gh api @ main, 2026-10-19.
- docs/{deployment,security,install,configure,voice-and-push}.md, CHANGELOG.md — via gh api,
  2026-10-19. Releases list via gh api (v1.21.3 → v1.23.0 dates).
- numtide/llm-agents.nix README + packages/collie/{package.nix,hashes.json} at locked rev
  `e85b9921` and at main, 2026-10-19.
- mortlake working tree @ ~/src/mortlake: features/{herdr,aven,silverbullet,nginx,dd-client}.nix,
  hosts/jehoel/configuration.nix, flake.lock — read 2026-10-19.
- Live jehoel: `herdr status`, `loginctl show-user john`, `ss -ltn`, `pgrep` — 2026-10-19.
