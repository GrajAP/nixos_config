{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.bespotted;
  secretsDir = "${cfg.stateDir}/secrets";
  stageDir = "${cfg.stateDir}/backup-stage";
  envFile = "${secretsDir}/production.env";
  docker = lib.getExe config.virtualisation.docker.package;

  # compose.production.yml was sized for the PC (8 CPUs, 4 GiB per service).
  # Docker refuses `cpus` above the host's core count, so this box needs its own
  # limits. The guard keeps the 2-CPU/2-GiB budget its benchmark passed with.
  composeOverride = pkgs.writeText "bespotted-compose.lenovo.yml" (builtins.toJSON {
    services = {
      postgres = {
        cpus = 2.0;
        mem_limit = "1g";
      };
      api = {
        cpus = 3.0;
        mem_limit = "2g";
      };
      moderation-pl = {
        cpus = 2.0;
        mem_limit = "2g";
      };
    };
  });

  compose = lib.concatStringsSep " " [
    docker
    "compose"
    "--project-directory ${cfg.appDir}"
    "--env-file ${envFile}"
    "--file ${cfg.appDir}/compose.production.yml"
    "--file ${composeOverride}"
  ];

  tunnelConfig = pkgs.writeText "bespotted-cloudflared.yml" (builtins.toJSON {
    tunnel = cfg.tunnelId;
    credentials-file = "/run/credentials/bespotted-tunnel.service/tunnel.json";
    no-autoupdate = true;
    ingress =
      [
        {
          inherit (cfg) hostname;
          path = "^/metrics(?:/.*)?$";
          service = "http_status:404";
        }
        {
          inherit (cfg) hostname;
          service = "http://127.0.0.1:${toString cfg.originPort}";
        }
      ]
      ++ lib.optional cfg.web.enable {
        inherit (cfg.web) hostname;
        service = "http://127.0.0.1:${toString cfg.web.port}";
      }
      ++ [
        {service = "http_status:404";}
      ];
  });

  healthCheck = pkgs.writeShellScriptBin "bespotted-health" ''
    set -eu
    ${lib.getExe pkgs.curl} -fsS -m 10 -o /dev/null http://127.0.0.1:${toString cfg.originPort}/health/ready
    ${lib.getExe pkgs.curl} -fsS -m 15 -o /dev/null https://${cfg.hostname}/health/ready
    ${lib.optionalString cfg.web.enable "${lib.getExe pkgs.curl} -fsS -m 10 -o /dev/null http://127.0.0.1:${toString cfg.web.port}/"}
    ${config.serverAlerts.posthogEvent}/bin/server-posthog-event server_heartbeat bespotted || true
  '';

  # pg_dump through the running container, then prove the archive is readable
  # before restic stores it.
  backupRun = pkgs.writeShellScriptBin "bespotted-backup" ''
    set -eu
    umask 0077
    install -d -m 0700 ${stageDir}
    dump=${stageDir}/bespotted.dump
    rm -f "$dump"
    ${compose} exec -T postgres pg_dump -U bespotted -d bespotted -Fc > "$dump"
    ${compose} exec -T postgres pg_restore --list < "$dump" > /dev/null
    ${lib.getExe pkgs.restic} -r ${lib.escapeShellArg config.backup.resticRepository} backup \
      ${stageDir} \
      ${secretsDir} \
      /var/lib/docker/volumes/bespotted_uploads_prod/_data \
      --tag bespotted \
      --tag "$(hostname)"
  '';

  alertOnFailure = name: ["server-alert@${name}.service"];
in {
  options.services.bespotted = {
    enable = lib.mkEnableOption "the Bespotted production API, database, moderation guard and tunnel";

    appDir = lib.mkOption {
      type = lib.types.path;
      default = "/opt/bespotted";
      description = ''
        `git archive` of the deployed bespotted_codex commit. Only
        compose.production.yml and backend/ are read; the API image itself is
        loaded beforehand as bespotted-api:production.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/bespotted";
      description = "Root-only state: secrets/ (env file, Clerk, R2, tunnel), models/, backup-stage/.";
    };

    originPort = lib.mkOption {
      type = lib.types.port;
      default = 8790;
      description = ''
        Loopback port of the API. Must match BESPOTTED_ORIGIN_PORT in the env
        file. 8788/8789 are taken by development backends on this box.
      '';
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      default = "api.be-spotted.org";
    };

    tunnelId = lib.mkOption {
      type = lib.types.str;
      description = "Cloudflare Tunnel UUID; its credentials JSON lives at secrets/cloudflared-tunnel.json.";
    };

    web = {
      enable = lib.mkEnableOption "the static Bespotted web app behind the same tunnel";

      hostname = lib.mkOption {
        type = lib.types.str;
        default = "app.be-spotted.org";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8791;
        description = "Loopback port of the nginx site that serves the web build.";
      };

      root = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/bespotted-web/current";
        description = ''
          `npm run build:production` output of bespotted_codex/webapp, copied
          here by hand (see webapp/README.md in that repo). Not built by Nix:
          the build bakes in the public Clerk key and API URL.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd = {
      tmpfiles.rules =
        [
          "d ${cfg.stateDir} 0700 root root -"
          "d ${secretsDir} 0700 root root -"
          "d ${stageDir} 0700 root root -"
          "d ${dirOf config.serverAlerts.posthogKeyFile} 0700 root root -"
        ]
        ++ lib.optional cfg.web.enable "d ${dirOf cfg.web.root} 0755 root root -";

      services = {
        bespotted-production = {
          description = "Bespotted production API, PostgreSQL and Polish moderation guard";
          wantedBy = ["multi-user.target"];
          requires = ["docker.service"];
          after = [
            "docker.service"
            "network-online.target"
          ];
          wants = ["network-online.target"];
          onFailure = alertOnFailure "bespotted-production";
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStartPre = "${compose} config --quiet";
            ExecStart = "${compose} up --detach --wait --wait-timeout 600";
            ExecReload = "${compose} up --detach --wait --wait-timeout 600";
            ExecStop = "${compose} stop --timeout 30";
            TimeoutStartSec = "15min";
            TimeoutStopSec = "90s";
          };
        };

        bespotted-tunnel = {
          description = "Cloudflare Tunnel for ${cfg.hostname}";
          wantedBy = ["multi-user.target"];
          after = [
            "network-online.target"
            "bespotted-production.service"
          ];
          wants = ["network-online.target"];
          onFailure = alertOnFailure "bespotted-tunnel";
          startLimitIntervalSec = 0;
          serviceConfig = {
            ExecStart = "${lib.getExe pkgs.cloudflared} tunnel --config ${tunnelConfig} run";
            LoadCredential = "tunnel.json:${secretsDir}/cloudflared-tunnel.json";
            DynamicUser = true;
            Restart = "always";
            RestartSec = "5s";
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
          };
        };

        bespotted-health = {
          description = "Probe the Bespotted API locally and through the public tunnel";
          after = ["bespotted-tunnel.service"];
          onFailure = alertOnFailure "bespotted-health";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${healthCheck}/bin/bespotted-health";
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectHome = true;
            ProtectSystem = "strict";
          };
        };

        bespotted-backup = {
          description = "restic backup of the Bespotted database, uploads and secrets";
          after = [
            "bespotted-production.service"
            "homenest-backup-env.service"
          ];
          requires = ["bespotted-production.service"];
          onFailure = alertOnFailure "bespotted-backup";
          path = [
            pkgs.coreutils
            pkgs.inetutils
          ];
          environment.RESTIC_PASSWORD_FILE = "/var/lib/restic/password";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${backupRun}/bin/bespotted-backup";
            ExecStopPost = "${pkgs.coreutils}/bin/rm -f ${stageDir}/bespotted.dump";
          };
        };
      };

      timers = {
        bespotted-health = {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnBootSec = "10min";
            OnUnitActiveSec = "5min";
          };
        };

        bespotted-backup = {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "*-*-* 03:10:00";
            RandomizedDelaySec = "10m";
            Persistent = true;
          };
        };
      };
    };

    # A single-page app: unknown paths (/sso-callback, /spots/<id>) fall back to
    # index.html, hashed assets are cached for a year, index.html never.
    services.nginx.virtualHosts.bespotted-web = lib.mkIf cfg.web.enable {
      listen = [
        {
          addr = "127.0.0.1";
          inherit (cfg.web) port;
          ssl = false;
        }
      ];
      inherit (cfg.web) root;
      locations = {
        "/" = {
          tryFiles = "$uri /index.html";
          extraConfig = ''
            add_header Cache-Control "no-cache";
            add_header X-Content-Type-Options "nosniff";
            add_header Referrer-Policy "strict-origin-when-cross-origin";
          '';
        };
        "/assets/".extraConfig = ''
          add_header Cache-Control "public, max-age=31536000, immutable";
          add_header X-Content-Type-Options "nosniff";
        '';
      };
    };
  };
}
