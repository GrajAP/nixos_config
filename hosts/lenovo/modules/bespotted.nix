{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.bespotted;
  secretsDir = "${cfg.stateDir}/secrets";
  stageDir = "${cfg.stateDir}/backup-stage";
  mediaMirrorDir = "${cfg.stateDir}/backup-media";
  offsiteEnvFile = "${secretsDir}/offsite-r2.env";
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
    ${config.serverAlerts.posthogEvent}/bin/server-posthog-event server_heartbeat bespotted || true
    # After the heartbeat, so a web outage still alerts but never hides a
    # healthy API from the heartbeat.
    ${lib.optionalString cfg.web.enable ''
      ${lib.getExe pkgs.curl} -fsS -m 10 -o /dev/null http://127.0.0.1:${toString cfg.web.port}/
      ${lib.getExe pkgs.curl} -fsS -m 15 -o /dev/null https://${cfg.web.hostname}/
    ''}
  '';

  # R2 is the only copy of the media and the API's own token can delete from it,
  # so it is pulled into restic, whose snapshots a later deletion cannot touch.
  # The secret goes through the environment, never the command line. A failure
  # must not cost the database dump, so it is reported after restic has run.
  mediaMirror = pkgs.writeShellScript "bespotted-media-mirror" ''
    set -eu
    install -d -m 0700 ${mediaMirrorDir}
    value() { sed -n "s/^$1=//p" ${envFile} | tail -n 1; }
    [ "$(value MEDIA_STORAGE_BACKEND)" = r2 ] || exit 0
    RCLONE_CONFIG_R2_TYPE=s3 \
      RCLONE_CONFIG_R2_PROVIDER=Cloudflare \
      RCLONE_CONFIG_R2_ENDPOINT="$(value R2_ENDPOINT)" \
      RCLONE_CONFIG_R2_ACCESS_KEY_ID="$(value R2_ACCESS_KEY_ID)" \
      RCLONE_CONFIG_R2_SECRET_ACCESS_KEY="$(cat ${secretsDir}/r2-secret-access-key.compose)" \
      ${lib.getExe pkgs.rclone} sync "r2:$(value R2_BUCKET)" ${mediaMirrorDir} \
      --config /dev/null --s3-no-check-bucket --fast-list --transfers 4
  '';

  # pg_dump through the running container, then prove the archive is readable
  # before restic stores it.
  backupRun = pkgs.writeShellScriptBin "bespotted-backup" ''
    set -eu
    umask 0077
    install -d -m 0700 ${stageDir}
    media_status=0
    ${mediaMirror} || media_status=$?
    dump=${stageDir}/bespotted.dump
    rm -f "$dump"
    ${compose} exec -T postgres pg_dump -U bespotted -d bespotted -Fc > "$dump"
    ${compose} exec -T postgres pg_restore --list < "$dump" > /dev/null
    ${lib.getExe pkgs.restic} -r ${lib.escapeShellArg config.backup.resticRepository} backup \
      ${stageDir} \
      ${secretsDir} \
      ${mediaMirrorDir} \
      /var/lib/docker/volumes/bespotted_uploads_prod/_data \
      --tag bespotted \
      --tag "$(hostname)"
    if [ "$media_status" -ne 0 ]; then
      echo "bespotted-backup: copying the R2 media failed, status $media_status" >&2
      exit "$media_status"
    fi
  '';

  # lenovo and its mirror on the PC share a house, so a fire or a burglary takes
  # both. restic already encrypts this repository, and its files never change
  # once written, so --immutable can only add to the copy.
  offsiteCopy = pkgs.writeShellScript "bespotted-offsite-copy" ''
    set -eu
    set -a
    . ${offsiteEnvFile}
    set +a
    exec ${lib.getExe pkgs.rclone} copy ${lib.escapeShellArg config.backup.resticRepository} \
      "offsite:$OFFSITE_BUCKET/restic" \
      --config /dev/null --s3-no-check-bucket --immutable --exclude "locks/**" --transfers 4
  '';

  # Sent on every location: add_header in a location replaces inherited ones.
  # Content-Security-Policy stays Report-Only until a logged-in session shows no
  # violations; webEnforceCsp then turns it on. Tiles and media come through the
  # API, which redirects media to signed R2 URLs.
  webCsp = lib.concatStringsSep "; " [
    "default-src 'self'"
    "script-src 'self' https://clerk.be-spotted.org https://challenges.cloudflare.com"
    "style-src 'self' 'unsafe-inline'"
    "img-src 'self' data: blob: https://api.be-spotted.org https://*.eu.r2.cloudflarestorage.com https://img.clerk.com https://images.clerk.dev"
    "media-src 'self' blob: https://api.be-spotted.org https://*.eu.r2.cloudflarestorage.com"
    "connect-src 'self' https://api.be-spotted.org https://clerk.be-spotted.org https://photon.komoot.io https://*.eu.r2.cloudflarestorage.com"
    "worker-src 'self' blob:"
    "frame-src https://clerk.be-spotted.org https://challenges.cloudflare.com"
    "font-src 'self' data:"
    "manifest-src 'self'"
    "object-src 'none'"
    "base-uri 'self'"
    "form-action 'self' https://clerk.be-spotted.org"
    "frame-ancestors 'none'"
  ];
  webSecurityHeaders = ''
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "camera=(self), geolocation=(self), microphone=()" always;
    add_header ${
      if cfg.web.enforceCsp
      then "Content-Security-Policy"
      else "Content-Security-Policy-Report-Only"
    } "${webCsp}" always;
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

      enforceCsp = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enforce the Content-Security-Policy instead of only reporting violations in the browser console.";
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
          "d ${mediaMirrorDir} 0700 root root -"
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

        bespotted-offsite = {
          description = "Copy the encrypted restic repository outside the house";
          after = ["bespotted-backup.service" "network-online.target"];
          wants = ["network-online.target"];
          unitConfig.ConditionPathExists = offsiteEnvFile;
          onFailure = alertOnFailure "bespotted-offsite";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = offsiteCopy;
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

        # After restic's 03:00-05:30 backup and prune window.
        bespotted-offsite = {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "*-*-* 06:00:00";
            RandomizedDelaySec = "20m";
            Persistent = true;
          };
        };
      };
    };

    # A single-page app: unknown paths (/sso-callback, /spots/<id>) fall back to
    # index.html, hashed assets are cached for a year, index.html never.
    services.nginx.enable = lib.mkIf cfg.web.enable true;
    services.nginx.virtualHosts.bespotted-web = lib.mkIf cfg.web.enable {
      serverName = cfg.web.hostname;
      listen = [
        {
          addr = "127.0.0.1";
          inherit (cfg.web) port;
          ssl = false;
        }
      ];
      inherit (cfg.web) root;
      # Cloudflare reports how the visitor connected. A plain HTTP page could be
      # rewritten by anyone on the network, for example on campus Wi-Fi.
      extraConfig = ''
        if ($http_x_forwarded_proto = "http") {
          return 308 https://${cfg.web.hostname}$request_uri;
        }
      '';
      locations = {
        "/" = {
          tryFiles = "$uri /index.html";
          extraConfig = ''
            add_header Cache-Control "no-cache";
            ${webSecurityHeaders}
          '';
        };
        "/assets/".extraConfig = ''
          add_header Cache-Control "public, max-age=31536000, immutable";
          ${webSecurityHeaders}
        '';
      };
    };
  };
}
