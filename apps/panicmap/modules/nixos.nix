# PanicMap, the backend behind hy.be-spotted.org.
#
# The app is not packaged here: it is served straight out of a git checkout, the
# same one the mobile client is developed against, because "what is live" and
# "what is in the tree" are then the same question with one answer. What this
# module owns is everything around it -- the units, the database, and the two
# ways a change reaches the running server:
#
#   * a one-minute poll of the sources, for a local edit;
#   * a three-minute fetch that fast-forwards the checkout, for a pushed commit.
#
# Both go through apps/panicmap/panicmap-api-update, which restarts the API only
# when the sources actually differ from the last restart. See that script for
# why the fingerprint check is not optional.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.panicmap;
  backend = "${cfg.sourceDir}/backend";
  stateDir = "/var/lib/panicmap";
  runtimeDir = "/run/panicmap";

  node = cfg.nodejs;

  # `npm ci` when the lockfile moved, `tsc` when a source moved, nothing when
  # neither did. Every start goes through this, so `systemctl restart
  # panicmap-api` after a hand edit compiles what is on disk instead of serving
  # whatever `dist/` happened to contain.
  build = pkgs.writeShellApplication {
    name = "panicmap-api-build";
    runtimeInputs = [
      # bashInteractive and not bash: `npm run build` spawns `sh -c`, and plain
      # bash does not ship one.
      pkgs.bashInteractive
      node
      pkgs.coreutils
      pkgs.findutils
    ];
    text = ''
      cd "$1"

      if [[ ! -d node_modules || package-lock.json -nt node_modules/.package-lock.json ]]; then
        echo "[build] lockfile moved, reinstalling dependencies"
        npm ci --no-audit --no-fund
      fi

      # -print -quit inside a substitution, never a pipeline: `find | grep -q`
      # dies of SIGPIPE under `set -o pipefail` and reports a failure that never
      # happened. The `! -f` comes first so the `find` is never handed a
      # dist/server.js that is not there.
      if [[ ! -f dist/server.js ]] || [[ -n $(find src package.json tsconfig.json tsconfig.build.json -newer dist/server.js -print -quit) ]]; then
        echo "[build] compiling"
        # The checkout compiles with type errors -- 15 of them, all
        # `request.body is of type unknown` in the route files, because the
        # Zod type provider is not wired into those handlers. `npm run dev` is
        # tsx, which never typechecks, so nothing has ever run tsc over this
        # tree. tsc emits anyway, and Node does not care: a failed typecheck is
      # reported and survived, a failed *emit* is not.
        if ! npm run build; then
          if [[ -f dist/server.js ]] && [[ -z $(find src package.json tsconfig.json tsconfig.build.json -newer dist/server.js -print -quit) ]]; then
            echo "[build] WARNING: tsc reported errors, dist/ was still emitted, serving it anyway"
          else
            echo "[build] tsc failed and left dist/ stale or empty" >&2
            exit 1
          fi
        fi
      else
        echo "[build] dist/ is up to date"
      fi
    '';
  };

  # What the API and the worker need beyond the EnvironmentFile. DATABASE_URL
  # is here and not in that file so that the socket directory is stated once, in
  # `database.socketDir`, instead of twice.
  # Every unit runs as `cfg.user` and no Group: on NixOS a user's primary group
  # is `users`, not their name, and naming the user in Group= fails the unit with
  # 216/GROUP before ExecStart ever runs.
  appEnv =
    [
      "HOME=${stateDir}"
      "npm_config_cache=${stateDir}/npm-cache"
      "PATH=${servicePath}"
    ]
    ++ lib.optional cfg.database.enable "DATABASE_URL=postgresql://${cfg.database.name}@/${cfg.database.name}?host=${cfg.database.socketDir}";

  # git and flock for the update run, curl for its health probe; the unit adds
  # /run/wrappers/bin for the sudo systemctl the script ends with.
  servicePath = lib.makeBinPath [
    # bashInteractive for the same `sh` npm needs, on both sides of the restart.
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.curl
    pkgs.findutils
    pkgs.git
    pkgs.gnused
    pkgs.systemd
    pkgs.util-linux
  ];

  # What both update runs need to know about the checkout and the units, as a
  # list rather than an attrset because systemd wants `KEY=value` lines. Kept in
  # one place because the reload unit is the update unit with the git turned off,
  # and a copy that drifts is a bug waiting for a bad day.
  #
  # The quotes around PANICMAP_UNITS are not decoration: systemd splits an
  # `Environment=` line on whitespace, and an unquoted pair of unit names becomes
  # two malformed assignments.
  updateEnv = pull: [
    "PATH=${servicePath}:/run/wrappers/bin:/run/current-system/sw/bin"
    "XDG_RUNTIME_DIR=${runtimeDir}"
    "PANICMAP_SOURCE=${cfg.sourceDir}"
    "PANICMAP_BACKEND=${backend}"
    "PANICMAP_PORT=${toString cfg.port}"
    "PANICMAP_PULL=${pull}"
    "PANICMAP_UNITS=\"panicmap-api.service panicmap-worker.service\""
  ];
in {
  options.panicmap = {
    enable = lib.mkEnableOption "the PanicMap API, its escalation worker and its database";

    sourceDir = lib.mkOption {
      type = lib.types.path;
      default = "/mnt/SSD2/dev/hackyeah2026";
      example = "/mnt/SSD2/dev/hackyeah2026";
      description = ''
        PanicMap checkout to serve. Not a flake input on purpose: the tree is
        dirty most of the time (the backend rewrite is uncommitted work), and a
        flake ref would only ever see HEAD.
      '';
    };

    envFile = lib.mkOption {
      type = lib.types.path;
      default = "/home/grajpap/.config/panicmap/api.env";
      description = ''
        EnvironmentFile for both units. Kept out of this repository: it holds the
        Clerk keys, the invite signing key and the Expo token, and rebuild.sh runs
        gitleaks over /etc/nixos before it evaluates anything. Read by a system
        unit, so it only has to be readable by the service user.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = ''
        Port the API listens on. This is the port the Cloudflare tunnel points
        `hy.be-spotted.org` at, so changing it takes the public hostname with it.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "grajpap";
      description = ''
        Who runs the API, the worker and the update runs.

        Not a dedicated service account: `npm run build` writes `dist/` into the
        checkout, and the checkout belongs to the desktop user. The alternative
        is a service account that cannot rebuild what it serves.
      '';
    };

    nodejs = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nodejs_22;
      defaultText = lib.literalExpression "pkgs.nodejs_22";
      description = "Node runtime. backend/package.json asks for >= 22.";
    };

    database = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Put PanicMap's database in the system Postgres cluster.

          Not a cluster of its own: nixpkgs has no `services.postgresql.instances`,
          and the alternative -- a hand-rolled second cluster in the state
          directory -- breaks the first time nixpkgs moves the major version,
          because nothing runs pg_upgrade for it.
        '';
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "panicmap";
        description = "Database and role name.";
      };

      socketDir = lib.mkOption {
        type = lib.types.path;
        default = "/run/postgresql";
        description = ''
          Where the cluster's unix socket lives, and the host part of
          DATABASE_URL.

          Not TCP, and this is the whole reason. Docker publishes the bespotted
          Postgres on 127.0.0.1:5432, so the system cluster cannot bind the
          address it would listen on and answers on ::1 only. The socket is
          unambiguous, it is not reachable from off the machine, and it is not
          shared with anything.
        '';
      };
    };

    autoUpdate = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Restart the API when the checkout changes.";
      };

      watchInterval = lib.mkOption {
        type = lib.types.str;
        default = "1min";
        example = "30s";
        description = ''
          How often the sources are checked for a local edit. This is a poll, not
          an inotify watch: a systemd path unit does not watch a directory
          recursively, so `backend/src` alone would miss every file under
          `backend/src/routes`, and the directories that exist today are not the
          ones that will exist after the next refactor.
        '';
      };

      interval = lib.mkOption {
        type = lib.types.str;
        default = "3min";
        example = "10min";
        description = ''
          How often the checkout is fetched. This is the upper bound on how long
          a pushed commit takes to reach the live API; a local edit does not wait
          for it, the shorter watch above handles that.
        '';
      };

      pull = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Fast-forward the checkout when its upstream has moved. Skipped whenever
          the tree is dirty, which is most of the time right now: the Node
          backend is uncommitted work on `init`, and a pull that half applied
          would take the live API with it.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # ==============================================================
    # DATABASE
    # ==============================================================
    # The system cluster, over its unix socket. Not the postgres that
    # scripts/db.sh starts from a checkout on 5433: that one dies with the
    # terminal and takes the incident history the demo is built on with it.
    #
    # Port and PGDATA are left exactly as they are, because Nextcloud lives in
    # this cluster too and system/backup/default.nix dumps it from here.
    services.postgresql = lib.mkIf cfg.database.enable {
      enable = true;
      ensureDatabases = [cfg.database.name];
      ensureUsers = [
        {
          name = cfg.database.name;
          ensureDBOwnership = true;
        }
      ];
      # Trust, for one role, over the unix socket. The default is peer, which
      # would compare the role against the *system* user running the API --
      # grajpap -- and refuse every connection. The alternative is a password in
      # a file, and a password in *this* repository would be published by the
      # nightly auto-rebuild.
      authentication = lib.mkBefore ''
        local ${cfg.database.name} ${cfg.database.name} trust
      '';
    };

    systemd = {
      services = {
        # ============================================================
        # API AND WORKER
        # ============================================================
        panicmap-api = {
          description = "PanicMap API (hy.be-spotted.org)";
          documentation = [
            "file:${../README.md}"
          ];
          after =
            [
              "network-online.target"
            ]
            ++ lib.optional cfg.database.enable "postgresql.service";
          wants = ["network-online.target"];
          wantedBy = ["multi-user.target"];
          # A bad deploy must not become a permanent outage: 20 starts in five
          # minutes, then the unit stays down and says so, and the next update
          # run tries again.
          startLimitIntervalSec = 300;
          startLimitBurst = 20;

          serviceConfig = {
            Type = "simple";
            User = cfg.user;
            WorkingDirectory = backend;
            EnvironmentFile = cfg.envFile;
            # A system unit has no login shell and no usable HOME, and npm will
            # not run without somewhere to put its cache.
            Environment = appEnv;
            StateDirectory = "panicmap";
            ExecStartPre = [
              "${build}/bin/panicmap-api-build ${backend}"
              # Drizzle migrations are idempotent, so this belongs to the start
              # of the service rather than to a deploy step nobody remembers to
              # run.
              "${node}/bin/node dist/db/migrate.js"
            ];
            ExecStart = "${node}/bin/node dist/server.js";
            Restart = "always";
            RestartSec = 5;
            NoNewPrivileges = true;
            PrivateTmp = true;
          };
        };

        # The escalation sweep. Same checkout, same build, separate process: it
        # is the part of the backend that has to keep working while nobody has
        # the app open.
        panicmap-worker = {
          description = "PanicMap escalation worker";
          documentation = [
            "file:${../README.md}"
          ];
          # After the API, because the API's ExecStartPre is what compiles
          # dist/.
          after = [
            "panicmap-api.service"
            "network-online.target"
          ];
          wants = ["network-online.target"];
          wantedBy = ["multi-user.target"];
          startLimitIntervalSec = 300;
          startLimitBurst = 20;

          serviceConfig = {
            Type = "simple";
            User = cfg.user;
            WorkingDirectory = backend;
            EnvironmentFile = cfg.envFile;
            # A system unit has no login shell and no usable HOME, and npm will
            # not run without somewhere to put its cache.
            Environment = appEnv;
            StateDirectory = "panicmap";
            ExecStartPre = "${build}/bin/panicmap-api-build ${backend}";
            ExecStart = "${node}/bin/node dist/worker.js";
            Restart = "always";
            RestartSec = 5;
            NoNewPrivileges = true;
            PrivateTmp = true;
          };
        };

        # ============================================================
        # UPDATES
        # ============================================================
        panicmap-api-update = {
          description = "Fetch the PanicMap checkout and restart the API when it changed";
          documentation = [
            "file:${./../panicmap-api-update}"
          ];
          after = [
            "network-online.target"
          ];
          wants = ["network-online.target"];

          serviceConfig = {
            Type = "oneshot";
            # Not root: a pull by root leaves root-owned refs and objects that
            # the desktop user cannot write over on the next fetch.
            User = cfg.user;
            WorkingDirectory = cfg.sourceDir;
            RuntimeDirectory = "panicmap";
            RuntimeDirectoryMode = "0700";
            # The fingerprint lives in the state directory, which the API's
            # StateDirectory creates for this user.
            StateDirectory = "panicmap";
            Environment = updateEnv (lib.boolToString cfg.autoUpdate.pull);
            ExecStart = "${pkgs.bash}/bin/bash ${./../panicmap-api-update}";
            Nice = 10;
          };
        };

        # The same script with the git turned off: a local edit should not wait
        # on, or spend, a round trip to GitHub. The fingerprint check inside the
        # script is what keeps this from restarting the API every minute.
        panicmap-api-reload = {
          description = "Restart the PanicMap API after a local edit";
          after = [
            "network-online.target"
          ];
          wants = ["network-online.target"];

          serviceConfig = {
            Type = "oneshot";
            User = cfg.user;
            WorkingDirectory = cfg.sourceDir;
            RuntimeDirectory = "panicmap";
            RuntimeDirectoryMode = "0700";
            StateDirectory = "panicmap";
            Environment = updateEnv "false";
            ExecStart = "${pkgs.bash}/bin/bash ${./../panicmap-api-update} --sources-only";
            Nice = 10;
          };
        };
      };

      timers = {
        # The slow half: fetch the checkout, then the same fingerprint test.
        panicmap-api-update = {
          description = "Check the PanicMap checkout for pushed commits";
          wantedBy = ["timers.target"];
          timerConfig = {
            # A couple of minutes after boot for the pull, then on a plain
            # interval: the work is a `git fetch`, so there is nothing to gain
            # from a calendar.
            OnBootSec = "2min";
            OnUnitActiveSec = cfg.autoUpdate.interval;
            RandomizedDelaySec = "20s";
            # A machine that was asleep at the appointed moment catches up on
            # wake instead of waiting a whole interval.
            Persistent = true;
            Unit = "panicmap-api-update.service";
          };
        };

        # The fast half of the update: no network, just "did the files move".
        panicmap-api-reload = lib.mkIf cfg.autoUpdate.enable {
          description = "Notice local edits to the PanicMap sources";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnBootSec = "90s";
            OnUnitActiveSec = cfg.autoUpdate.watchInterval;
            Persistent = true;
            Unit = "panicmap-api-reload.service";
          };
        };
      };
    };
  };
}
