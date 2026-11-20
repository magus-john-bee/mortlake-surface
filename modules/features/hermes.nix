{ inputs, ... }:
{
  flake.nixosModules.hermes =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (pkgs.stdenv.hostPlatform) system;
      p = config.sops.placeholder;

      enabled-toolsets = [
        "search"
        "vision"
        "terminal"
        "skills"
        "cronjob"
        "file"
        "tts"
        "todo"
        "memory"
        "session_search"
        "clarify"
        "code_execution"
      ];
    in
    {
      imports = [ inputs.hermes-agent.nixosModules.default ];

      sops.templates."hermes-env" = {
        content = ''
          EXA_API_KEY=${p.exa-api-key}
          FAL_KEY=${p.fal-api-key}
          DASHSCOPE_API_KEY=${p.qwencloud-api-key}
          DASHSCOPE_BASE_URL=https://token-plan.maas.qwencloudapi.com/compatible-mode/v1
          GROQ_API_KEY=${p.groq-api-key}
          MISTRAL_API_KEY=${p.mistral-api-key}
          OPENROUTER_API_KEY=${p.openrouter-api-key}
          LOGSEQ_PATH=/home/john/vault/logbook
          DISCORD_BOT_TOKEN=${p.discord-bot-token}
          DISCORD_ALLOWED_USERS=${p.discord-allowed-users}
          DISCORD_HOME_CHANNEL=${p.discord-home-channel}
        '';
        owner = "john";
      };

      services.hermes-agent = {
        enable = true;
        user = "john";
        group = "users";
        createUser = false;
        package = inputs.hermes-agent.packages.${system}.default;
        addToSystemPackages = true;
        # hermes-env template (sops secrets rendered below)
        environmentFiles = [ config.sops.templates."hermes-env".path ];
        extraDependencyGroups = [
          "exa"
          "messaging"
          "mistral"
          "tts-premium"
          "voice"
        ];

        # Matches the flake input hermes-agent's DEFAULT_CONFIG._config_version
        # (hermes_cli/config_defaults.py — recheck on every input bump). The
        # module deep-merges settings over the live config additively; this
        # stamp keeps `hermes doctor` from flagging drift after every rebuild.
        settings._config_version = 54;

        settings = {
          approvals.mode = "off";
          toolsets = enabled-toolsets;

          platform_toolsets.cli = enabled-toolsets;

          # funes episodic-memory plugin (modules/features/funes.nix).
          # Declarative by design: the imperative `hermes plugins enable`
          # path runs dependency admission, which needs <site-packages>/uv.lock
          # and is broken under uv2nix builds. The funes plugin carries no
          # python deps, so the admission proof is moot; enabling here keeps
          # plugin state rebuild-stable.
          plugins.enabled = [ "funes" ];

          # Default inference: QwenCloud token plan (Singapore,
          # token-plan.maas.qwencloudapi.com) via hermes' "alibaba"
          # (Qwen Cloud) provider — OpenAI-compatible, DASHSCOPE_BASE_URL
          # from hermes-env points it at the token-plan host. Main model is
          # qwen4-max-preview for as long as that endpoint stays alive;
          # when it dies, switch to qwen4-max (same plan, stable slug).
          # Backup path is fallback_model below (openrouter), never qwen.
          model = {
            provider = "alibaba";
            default = "qwen4-max-preview";
            # Qwen max-family context; qwen4-max-preview shares the family
            # limit. Raise only if the docs page says otherwise.
            context_length = 262144;
          };

          # The fleet-wide backup: everything defaults to qwencloud, this is
          # the only sanctioned non-qwen inference path (pi-backup uses the
          # same provider/model pair).
          fallback_model = {
            provider = "openrouter";
            model = "deepseek/deepseek-v4.1-flash";
          };

          stt = {
            provider = "groq";
          };

          # TTS stays off-qwen deliberately: the token plan serves ASR/TTS
          # only via native DashScope endpoints
          # (/api/v1/services/audio/tts/SpeechSynthesizer,
          # /api/v1/services/aigc/multimodal-generation/generation), NOT
          # the OpenAI-compatible /audio/* hermes speaks — hermes has no
          # qwen audio provider yet (see skills qwencloud for the native
          # curl recipes). Revisit when hermes-agent gains one.
          tts = {
            provider = "mistral";
            mistral = {
              model = "voxtral-mini-tts-2603";
              voice_id = "e3596645-b1af-469e-b857-f18ddedc7652";
            };
          };

          smart_model_routing = {
            enabled = true;
            cheap_model = {
              provider = "alibaba";
              model = "qwen3.8-flash";
            };
          };

          auxiliary = {
            # qwen4-max takes image input through the compatible-mode chat
            # API (verified live 2026-11-18). deepseek-v4.1-flash also rides
            # the same token plan if a cheaper vision pass is ever wanted.
            vision = {
              provider = "alibaba";
              model = "qwen4-max";
            };
            flush_memories = {
              provider = "alibaba";
              model = "qwen3.8-flash";
              timeout = 60;
            };
          };

          session_reset = {
            reset_by_platform = {
              discord = {
                mode = "idle";
                idle_minutes = 180;
              };
            };
          };

          provider_routing = {
            sort = "throughput";
          };

          memory = {
            memory_char_limit = 6000;
            user_char_limit = 3000;
          };

          compression = {
            enabled = true;
            threshold = 0.9;
          };

          skills = {
            # Three-tier skills: tier 1 = this external_dir
            # (mortlake skills/, shared with pi via ~/.agents/skills); tier 2
            # = skill-archive/ (search-only, never loaded); tier 3 = per-repo
            # .agents/skills (project_discovery default-on).
            config.wiki.path = "/home/john/vault/book-of-thoth";
            external_dirs = [ "/home/john/src/mortlake/skills" ];
            # Native authoring/maintenance flows OFF: skills are authored in
            # the mortlake repo (template-gated by just lint-skills), not via
            # skill_manage into the private dir. write_approval stages any
            # skill_manage mutation for explicit /skills approve; curator
            # (background stale/archive/consolidate of agent-created skills)
            # has nothing legitimate to maintain.
            write_approval = true;
            curator.enabled = false;
          };

          # Purge the gateway `documents:` key from the live config.yaml —
          # the gateway's documents feature writes to the working directory,
          # where hermes never reads it: hermes reads SOUL.md only from
          # HERMES_HOME (hermesHomeFiles below). settings deep-merges, so
          # declaring the empty map is what removes the stale key from disk.
          documents = { };
        };

        # SOUL.md lives in HERMES_HOME and hermes reads it only from there.
        # Content = hermes persona (./hermes/SOUL.md) + the shared
        # cross-agent policy (./global-agents.md, same directory):
        # hermes has no user-level AGENTS.md surface, so its always-loaded
        # SOUL.md carries the same policy pi/prime load as their user-level
        # AGENTS.md — one source of truth for all agents.
        hermesHomeFiles."SOUL.md" =
          builtins.readFile ./hermes/SOUL.md
          + ''

            ---

            # Shared agent policy

          ''
          + builtins.readFile ./global-agents.md;

        # Trimmed MCP servers — removed mempalace, codegraph, procontext, ouroboros, agentmemory
        mcpServers = {
          codebase-memory = {
            command = "${pkgs.codebase-memory-mcp}/bin/codebase-memory-mcp";
            args = [ ];
            enabled = true;
          };
          context = {
            command = "npx";
            args = [
              "@neuledge/context"
              "serve"
            ];
            enabled = true;
          };
          exa = {
            # get_code_context_exa is deprecated upstream (generic code search
            # folded into general search; repo-local code intel is codegraph's
            # job now) — must not be requested in the tools list. agent_run
            # (async Exa Agent research) exists if ever needed.
            url = "https://mcp.exa.ai/mcp?tools=web_search_exa,web_fetch_exa,web_search_advanced_exa";
            # Escaped \${...} → literal ${EXA_API_KEY} in config.yaml.
            # Hermes interpolates ${VAR} at MCP-connect time from the
            # gateway process env, which carries EXA_API_KEY via the
            # sops hermes-env template. (builtins.getEnv baked the
            # *building* host's env in at eval time — empty on jehoel.)
            headers = {
              x-api-key = "\${EXA_API_KEY}";
            };
          };
          nixos = {
            command = "uvx";
            args = [ "mcp-nixos" ];
            enabled = true;
          };
          gitmcp = {
            url = "https://gitmcp.io/docs";
            enabled = true;
          };
          # Obscura headless browser: one stdio MCP server, ~37
          # browser_* tools (navigate/snapshot/click/fill/evaluate/tabs).
          # Store-path command so the gateway's pinned PATH is irrelevant;
          # private-network default mirrors obscura.nix's wrapper (LAN
          # services like sb.otwell.dev are legitimate targets). Batch/raw
          # work stays on the CLI (skill routes it); the MCP session is one
          # live browser — concurrent sessions share it (tabs mitigate).
          obscura = {
            command = "${pkgs.obscura}/bin/obscura";
            args = [ "mcp" ];
            env.OBSCURA_ALLOW_PRIVATE_NETWORK = "1";
            enabled = true;
          };
        };
      };

      # /var/lib/hermes must exist and be owned by the service user before
      # the gateway starts. Preservation creates the bind-mount point
      # root-owned on first provisioning (tmpfs-root), which crashes the
      # Discord adapter with EACCES on .local/; the rule makes the fix
      # permanent.
      # "d" rules re-apply their mode on every systemd-tmpfiles pass (boot +
      # switch), which runs AFTER activation — so upstream's 2770 rule for
      # HERMES_HOME always re-beat the 2750 activation script below (cron
      # control-plane calls failed with GatewayUnavailableError: unsafe_
      # control_permissions). systemd-tmpfiles deduplicates by path with
      # FIRST-rule-wins (later duplicates are warned + ignored) and orders
      # files lexically, so the counter-rule must live in a file sorting
      # before NixOS's 00-nixos.conf — hence the dedicated environment.etc
      # entry below instead of this rules list (a lib.mkBefore element does
      # NOT hoist here; verified). The gateway client's check only rejects
      # group/other WRITE on HERMES_HOME itself; subdirs at upstream's 2770
      # are fine (hostUsers intent) and never checked.
      systemd.tmpfiles.rules = [
        "d /var/lib/hermes 0755 ${config.services.hermes-agent.user} ${config.services.hermes-agent.group} -"
        # Opt out of bundled-skill seeding declaratively:
        # skills live in the mortlake repo tiers, not this profile. `f`
        # creates-if-missing and never overwrites — a wipe can't silently
        # resume seeding, while `hermes skills opt-in` stays possible
        # until the next activation re-asserts this. To opt back in for
        # real: remove this rule, rebuild, then `hermes skills opt-in`.
        "f /var/lib/hermes/.hermes/.no-bundled-skills 0644 ${config.services.hermes-agent.user} ${config.services.hermes-agent.group} - Managed by NixOS (mortlake hermes.nix): this profile opts out of bundled-skill seeding. Skills load from /home/john/src/mortlake/skills (tier 1) + skill-archive (tier 2). To re-enable, remove the tmpfiles rule and run: hermes skills opt-in"
        # XDG dirs the service user's CLIs create on first use (.config,
        # .local, .cache). Without the
        # rule, preservation re-creates the parent root-owned after a wipe
        # and every CLI in the gateway env dies with EACCES — silently kills
        # cron jobs that shell out.
        "d /var/lib/hermes/.config 0750 ${config.services.hermes-agent.user} ${config.services.hermes-agent.group} -"
        "d /var/lib/hermes/.local 0770 ${config.services.hermes-agent.user} ${config.services.hermes-agent.group} -"
        "d /var/lib/hermes/.cache 0770 ${config.services.hermes-agent.user} ${config.services.hermes-agent.group} -"
      ];

      # "00-hermes-agent-home.conf" sorts before "00-nixos.conf", so this
      # 2750 rule is the first rule for HERMES_HOME in every tmpfiles pass
      # and upstream's later 2770 duplicate is the one ignored.
      environment.etc."tmpfiles.d/00-hermes-agent-home.conf".text =
        "d /var/lib/hermes/.hermes 2750 ${config.services.hermes-agent.user} ${config.services.hermes-agent.group} - -\n";

      # Belt to the tmpfiles rules above (covers the activation→tmpfiles
      # window during a switch): upstream's activation sets 2770 (setgid +
      # group-writable) on stateDir/HERMES_HOME/workdir for hostUsers group
      # access, but the gateway client's unsafe_control_permissions check
      # refuses a group-writable control dir — every cron/control-plane call
      # fails with GatewayUnavailableError. 2750 keeps setgid + group
      # read/traverse minus the write bits the check rejects.
      # Supersedes upstream; drop when the module ships 2750 itself.
      system.activationScripts.hermes-agent-home-mode =
        lib.stringAfter
          [
            "hermes-agent-setup"
          ]
          ''
            chmod 2750 ${config.services.hermes-agent.stateDir} ${config.services.hermes-agent.stateDir}/.hermes ${config.services.hermes-agent.workingDirectory}
            find ${config.services.hermes-agent.stateDir}/.hermes -maxdepth 1 -type d -exec chmod g-w {} +
          '';

      systemd.services.hermes-agent = {
        environment = {
          LD_LIBRARY_PATH = "${pkgs.libopus.outPath}/lib:${pkgs.stdenv.cc.cc.lib}/lib";
          # Obscura SSRF gate: pre-open private networks for CLI calls made
          # from gateway shells (matches obscura.nix's system wrapper).
          OBSCURA_ALLOW_PRIVATE_NETWORK = "1";
        };
        path = [
          pkgs.binutils
          pkgs.nodejs
          # The memory provider check shells out to the gno binary, but this
          # service PATH is pinned store paths and never includes
          # /run/current-system/sw/bin, where gno.nix's environmentPackages
          # put gno. Mirror the llm-agents attr so the gateway can find it.
          inputs.llm-agents.packages.${system}.gno
        ];
        # pm's lockfile pins ffmpeg+ripgrep as required tools, but a sealed
        # nix artifact delegates its tool store to the user-writable
        # $HERMES_HOME/tools (node/npm/python/uv land there at first boot).
        # When a flake bump re-pins a tool version, drift makes the gateway
        # print "install out of sync" until the store catches up. Self-heal
        # at service start: doctor exits 1 on drift, install --tools-only
        # writes only the writable store (never the nix store).
        preStart = ''
          if ! ${config.services.hermes-agent.package}/bin/hermes pm doctor >/dev/null 2>&1; then
            echo "hermes-agent: pm tool store drifted from lockfile; healing ffmpeg/ripgrep/…"
            ${config.services.hermes-agent.package}/bin/hermes pm install --tools-only >/dev/null 2>&1 || true
          fi
        '';
        serviceConfig = {
          NoNewPrivileges = lib.mkForce false;
        };
      };

      environment.systemPackages = [
        pkgs.ffmpeg
        pkgs.yt-dlp
        pkgs.libopus
        pkgs.codebase-memory-mcp
        # pdftotext et al. for Hermes text-extraction (TODO.md, PR #68)
        pkgs.poppler-utils
      ];
    };
}
