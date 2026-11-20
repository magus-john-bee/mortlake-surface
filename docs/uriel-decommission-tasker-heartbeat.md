# Uriel decommission: phone-based heartbeat (Tasker)

Plan: 2026-10-01 (Hermes session, Discord). Repo retirement done 2026-10-10
(host module + sops key + refs removed; the name moved to the Pixel 9 Pro).
Context: uriel (cloud) being dropped; services move to jehoel. Always-on gap
covered by a phone heartbeat instead of a rented outpost box. See also:
nixos-anywhere outpost idea (deferred — phone makes it unnecessary for the
"house is dark" use case).

## Goal

Phone probes the public edge of jehoel over CELL DATA and notifies locally when
the home network is unreachable from outside. Catches the failure class
"outbound fine, inbound broken" (router reset to defaults, stale ddclient IP,
lost port-forward) — which jehoel-side or dead-man-switch monitoring cannot
see.

## Tasker profile (GrapheneOS Pixel 9 Pro)

1. **Profile: Time** — every 15 min (Tasker "Repeat" interval).
2. **Task: Heartbeat**, steps:
   - A1 **HTTP Request** (Tasker built-in, no plugin needed):
     - Method GET, URL `https://jellyfin.otwell.dev` (the lightest real vhost;
       any 2xx/3xx/4xx HTTP response = edge reachable — we care about TCP+TLS
       reachability, not content)
     - Timeout ~15s; on connection failure set local var `%err`
     - Optional second probe: `https://sb.otwell.dev` (second vhost confirms
       nginx/ACME health, not just one app)
   - A2 **If** `%err` set AND %previously_failed (global var) set:
     - A2.1 **Notify**: "jehoel unreachable over cell — 2 consecutive failures.
       Check router / ddclient / port-forwards."
   - A3 **Else If** `%err` set (first failure):
     - A3.1 **Variable Set** `%previously_failed` = true
   - A4 **Else**:
     - A4.1 **Variable Clear** `%previously_failed`
3. Force mobile data for the probe (else Wi-Fi probe would test the LAN, not
   the edge). Options, in order of preference:
   - Tasker "Mobile Data" action BEFORE the request + restore after (simplest),
   - or Tasker network binding via Java function if the simple action
     misbehaves (ask Hermes to generate the Java snippet),
   - or accept Wi-Fi+cell failover since Android marks no-internet Wi-Fi as
     validated=false and routes around it (weakest, but free).
4. Exempt the Tasker profile from battery optimization (Settings → Apps →
   Tasker → Battery → Unrestricted) or the 15-min timer will drift under Doze.

## Alert semantics

- 2 consecutive failures over cell → local notification. Threshold prevents
  single flaky-LTE-bar false positives.
- Recovery is implicit: next success clears `%previously_failed`; optionally
  add a "recovered" notify on the success-after-failure transition.
5. No outbound dependency on jehoel itself; nothing to deploy on jehoel; zero
  infra. Phone is on a different power AND network path (LTE vs home ISP).

## Limitations (accepted)

- No diagnosis vantage: when the alert fires, debugging happens from the
  phone. The nixos-anywhere outpost (public flake, jbotwell account, generic
  KVM disko profile, canary-only listening posture) remains the upgrade path
  if outages turn out to be frequent.
- 15-min granularity; a brief outage shorter than the interval is invisible.
- Tasker is a paid app (~$3.49); already-owned? If not, alternatives:
  Termux + termux-job-scheduler + termux-notifier (free, needs boot + battery
  exemptions), or automate via Lightning Wall/QuickEdit variants.

## Migration checklist (uriel → jehoel), pre-cancel

- [x] Stand up silverbullet, taskdog, ebay-deletion vhosts on jehoel (nginx +
      ACME per-vhost; same pattern as jellyfin/transmission) — done 2026-10-08
- [x] Flip DNS for sb/taskdog/ebay-deletion to jehoel (ddclient picked them
      up automatically after the cutover rebuild)
- [x] One-time rsync of the vault (logbook + sb) uriel → jehoel — NOT
      Syncthing: the vault is restic+git by design (see
      sb/security-surface.md), and jehoel's copies are stale one-shot
      snapshots from Oct 3 (sb 23/25 files, logbook 1.4G vs 1.9G)
- [x] Migrate Hermes state: hermes-state-sync skill, uriel → jehoel (.hermes
      dir; cron jobs ride along — trash Tue 8AM etc.)
- [ ] Verify cron jobs fire on jehoel schedule (first proof: trash job,
      Tue 2026-10-13 8AM)
- [x] Remove uriel host key from jehoel john.nix authorized keys (mortlake)
      — done 2026-10-08, PR (root@thoth key; module is shared so it drops
      uriel's access fleet-wide, raphael included)
- [ ] Point the heartbeat at jehoel vhosts (above), run it for a week BEFORE
      canceling uriel — overlap proves the alert path end-to-end
- [ ] Cancel uriel billing

### Cutover log (2026-10-08) — gotchas hit, for next time

- **Interactive CLI runs the setup wizard on the new host** when the shell
  lacks `HERMES_HOME=/var/lib/hermes/.hermes`. Subtlety: the module exports
  it via sessionVariables, but terminals inherit the COMPOSITOR's
  environment with `__NIXOS_SET_ENVIRONMENT_DONE=1` set — /etc/zshenv then
  skips the updated set-environment, so even terminals opened AFTER the
  rebuild miss the var until the graphical session restarts. Fix: log out/
  in (or reboot), or export manually; delete any `/home/john/.hermes` the
  wizard created. The gateway is never affected (unit pins the env).
- ACME raced the DNS flip: first issuance validated against uriel's IP
  (404) and left self-signed placeholders. Fix: after DNS moves, restart
  `acme-order-renew-<domain>.service`, then `systemctl reload nginx`.
- Preservation created /var/lib/hermes root-owned → hermes-agent crashed
  (EACCES on .local/). Fixed imperatively, then declaratively via tmpfiles
  rule in hermes.nix.
- Order that worked: stop uriel hermes-agent → rebuild jehoel (starts bot
  on jehoel with migrated state) → ddclient flips DNS → ACME retry +
  nginx reload. uriel's hermes/taskdog-server quiesced in config after.
