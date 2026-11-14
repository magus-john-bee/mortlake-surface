# Arize Phoenix — self-hosted OTLP trace collector + LLM/agent trace
# viewer (https://github.com/Arize-ai/phoenix). Ingests pi session
# traces (pi-tracer extension) and muninn traces; project routing is
# producer-owned (each carries openinference.project.name in-resource
# or via standard OTel env).
# Producers speak OTLP to an otelcol relay (4318) that re-encodes into
# Phoenix; Phoenix's UI+gRPC stay on 6006/4317.
#
# Not in nixpkgs; the wheel's dependency tree (pyarrow, pandas, grpcio,
# pydantic-ai) is an ML fast-mover — uv owns the venv, systemd runs it,
# the version is pinned like a flake input (uv-service pattern).
#
# Auth: none, by design. PHOENIX_HOST stays loopback (Phoenix
# force-enables auth on non-loopback binds), and the pi producers' only
# config surface is the endpoint URL — they send no headers — so any
# auth mechanism requiring headers would break them. The vhost is
# tailnet-only like sb.otwell.dev: the tailnet is the auth.
#
# Storage: SQLite under /home/john/data/phoenix — persisted via the
# host's "data" preservation entry, restic-covered via /home/john/data,
# bracketed stop/start around the nightly snapshot (live SQLite), and
# capped at 365d retention so the DB cannot grow unbounded.
let
  port = 6006;
  # Relay front door. 4317 is NOT free: phoenix itself binds
  # OTLP/gRPC there, so the relay stays HTTP-only on 4318.
  collectorPort = 4318;
  venvDir = "/home/john/.cache/phoenix-venv";
  dataDir = "/home/john/data/phoenix";
  phoenixVersion = "21.0.0";
in
{
  flake.nixosModules.phoenix =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # pip wheels link host libstdc++/zlib the venv does not bundle;
      # programs.nix-ld does not reach inside systemd units.
      hostLibs = "${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib";

      # Traces-only: Phoenix has no OTLP logs/metrics ingest. Retry+queue
      # so a Phoenix restart (e.g. the nightly restic bracket) never
      # loses a batch — the queue holds and flushes when it's back.
      otelcolConfig = pkgs.writeText "otelcol-phoenix.yaml" ''
        receivers:
          otlp:
            protocols:
              http:
                endpoint: 127.0.0.1:${toString collectorPort}
        processors:
          batch: {}
        exporters:
          otlphttp/phoenix:
            endpoint: http://127.0.0.1:${toString port}
            sending_queue:
              enabled: true
            retry_on_failure:
              enabled: true
        service:
          pipelines:
            traces:
              receivers: [otlp]
              processors: [batch]
              exporters: [otlphttp/phoenix]
      '';
    in
    {
      systemd = {
        services = {
          # Builder as a oneshot, never an activation script: a slow first
          # uv resolve must block only first boot, not every switch. The
          # GC probe (venv python symlinks die with their store
          # interpreter) makes healthy reboots a fast no-op.
          phoenix-venv = {
            description = "Phoenix uv venv builder (arize-phoenix)";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];
            path = [ pkgs.uv ];
            environment.LD_LIBRARY_PATH = hostLibs;
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              User = "john";
              Group = "users";
              ExecStart = pkgs.writeShellScript "phoenix-venv" ''
                set -eu
                if [ ! -x ${venvDir}/bin/python ] || ! ${venvDir}/bin/python -c 'import sys' >/dev/null 2>&1; then
                  rm -rf ${venvDir}
                  uv venv --python ${pkgs.python3}/bin/python3 ${venvDir}
                fi
                uv pip install --python ${venvDir}/bin/python3 'arize-phoenix==${phoenixVersion}'
              '';
            };
          };

          phoenix = {
            description = "Arize Phoenix — OTLP collector + trace viewer";
            requires = [ "phoenix-venv.service" ];
            after = [ "phoenix-venv.service" ];
            wantedBy = [ "multi-user.target" ];
            environment = {
              PHOENIX_HOST = "127.0.0.1";
              PHOENIX_PORT = toString port;
              PHOENIX_WORKING_DIR = dataDir;
              PHOENIX_SQL_DATABASE_URL = "sqlite:///${dataDir}/phoenix.db";
              PHOENIX_DEFAULT_RETENTION_POLICY_DAYS = "365";
              # No phoning home (telemetry pixels, fonts, WASM runtime).
              PHOENIX_ALLOW_EXTERNAL_RESOURCES = "false";
              LD_LIBRARY_PATH = hostLibs;
            };
            serviceConfig = {
              User = "john";
              Group = "users";
              ExecStart = "${venvDir}/bin/phoenix serve";
              Restart = "on-failure";
              RestartSec = "5s";
            };
          };

          # Why a relay: Phoenix 21 ingest is protobuf-only (/v1/traces
          # 415s OTLP/JSON), its queue+retry makes Phoenix restarts
          # lossless for one-shot producers, and it is the single
          # backend-swap point. Logs and metrics have no pipeline —
          # 404, permanent drop (same as pointing at Phoenix directly;
          # ocr's metrics die here too, one stderr warning per run).
          otelcol-phoenix = {
            description = "otelcol relay — OTLP JSON->protobuf into Phoenix";
            after = [ "phoenix.service" ];
            wants = [ "phoenix.service" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              User = "john";
              Group = "users";
              ExecStart = "${pkgs.opentelemetry-collector-contrib}/bin/otelcol-contrib --config ${otelcolConfig}";
              Restart = "on-failure";
              RestartSec = "5s";
            };
          };
        };

        # Tmpfiles, not StateDirectory: the dir sits inside john's home
        # and must exist before the unit's sandbox resolves paths
        # (226/NAMESPACE fires before ExecStart, before unit tmpfiles).
        tmpfiles.rules = [ "d ${dataDir} 0755 john users -" ];
      };

      # Tailnet-only vhost (no public DNS record; split-DNS resolves it
      # on the tailnet, nginx refuses everything else). jehoel producers
      # use the loopback endpoint; this serves other hosts.
      # client_max_body_size 32m: full-content OTLP batches run multi-MB
      # and nginx's 1m default would 413 them — pi-tracer treats 413 as
      # a permanent drop. /v1/traces -> relay; everything else (UI,
      # GraphQL; protobuf gRPC stays on 6006) -> Phoenix.
      services.nginx.virtualHosts."phoenix.otwell.dev" = lib.mkIf config.services.nginx.enable {
        forceSSL = true;
        useACMEHost = "otwell.dev";
        locations."/v1/traces" = {
          proxyPass = "http://127.0.0.1:${toString collectorPort}";
          extraConfig = ''
            allow 100.64.0.0/10;
            deny all;
            client_max_body_size 32m;
          '';
        };
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString port}";
          extraConfig = ''
            allow 100.64.0.0/10;
            deny all;
            client_max_body_size 32m;
          '';
        };
      };

      # Producer wiring: pi-tracer reads the endpoint env; ocr speaks
      # standard OTel env. Point everything at the relay (4318) even
      # though it speaks protobuf — the queue spans Phoenix restarts and
      # a backend swap is one exporter edit. Other hosts point at
      # https://phoenix.otwell.dev (same routing).
      environment.sessionVariables = {
        OTEL_EXPORTER_OTLP_ENDPOINT = "http://127.0.0.1:${toString collectorPort}";
        # ocr's config file cannot set a protocol (default gRPC, which
        # 4318 refuses); pi-tracer and muninn fix it in code, so this is
        # a safe fleet default.
        OTEL_EXPORTER_OTLP_PROTOCOL = "http/protobuf";
        # ocr's resource carries no service.name upstream (it names only
        # the tracer); routing is the RESOURCE_ATTRIBUTES line below.
        # pi-tracer hardcodes its own resource and muninn builds its in
        # code, so neither inherits these.
        OTEL_SERVICE_NAME = "open-code-review";
        # Routes ocr traces into their Phoenix project (standard OTel
        # resource env var, detected by ocr's Go SDK). muninn sets no env
        # detection today — a muninn telemetry change needs rechecking
        # against inheriting this.
        OTEL_RESOURCE_ATTRIBUTES = "openinference.project.name=open-code-review";
        # shortcut: any future producer using standard OTel env resource
        # detection inherits this name AND project — move the two ocr vars
        # above plus these into an ocr wrapper when one appears.
        # ocr's master switch. Env, not its config file: contexts without
        # a login shell (cron, systemd units) stay telemetry-off instead
        # of ocr falling back to its console exporter on stdout.
        OCR_ENABLE_TELEMETRY = "1";
      };
      # IMPERATIVE (superseded by the pi-tracer extension, which pi.nix
      # activates declaratively): remove "npm:@thomas-fazzari/pi-otlp"
      # from ~/.pi/agent/settings.json on hosts where it was installed
      # (jehoel done; the extension dir symlink needs no settings entry).
    };
}
