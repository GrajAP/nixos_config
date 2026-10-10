{
  config,
  lib,
  pkgs,
  unstablePkgs,
  ...
}: let
  nextcloudHost = "lenovo.tail138448.ts.net";
  backendPort = 18080;
  nextcloudPackage = unstablePkgs.nextcloud34;
  nextcloudApps = unstablePkgs.nextcloud34Packages.apps;
in {
  # ===========================================================================
  # CALENDAR, TASKS AND NOTES
  #
  # Moved off grajpap, where it shared a machine with a desktop that is
  # expected to sleep. The phone could only sync while that machine was awake.
  # This instance exists so the tailnet always has somewhere to sync to.
  #
  # SCOPE: calendar, tasks and notes only. No file sync.
  #
  # The 214 GiB external mount at grajpap:/mnt/Storage stays where it is and is
  # not part of this move. Nothing here stores user files, so the datadir is a
  # few MB of DAV data rather than tens of GB.
  #
  # ---------------------------------------------------------------------------
  # SQLite vs postgres
  #
  # Measured on grajpap: postgres is ~270 MiB RSS across two backends, out of
  # ~6.2 GiB free here. Saving it was not worth losing notify_push (which
  # requires redis) or the pg_dump path the old config already used. Postgres
  # and redis it is, matching what is being replaced.
  #
  # ---------------------------------------------------------------------------
  # URL LAYOUT
  #
  # `tailscale serve` already owns https://lenovo.tail138448.ts.net/ for the
  # whole hostname and forwards it to Caddy, which proxies `/` to HomeNest on
  # :3001. Nextcloud therefore cannot have the root path without breaking
  # HomeNest, so it lives under a /nextcloud prefix.
  #
  # Caddy's `handle_path` strips the prefix before proxying, so the backend
  # serves Nextcloud from `/` while `overwritewebroot` makes Nextcloud emit
  # `/nextcloud/...` in every URL it hands to clients.
  # ---------------------------------------------------------------------------
  services = {
    nextcloud = {
      enable = true;
      package = nextcloudPackage;
      hostName = nextcloudHost;
      https = true;

      # Sets client_max_body_size. Declaring it in the vhost extraConfig instead
      # is a duplicate-directive emerg, because the module emits its own.
      maxUploadSize = "512M";

      database.createLocally = true;
      configureRedis = true;

      config = {
        dbtype = "pgsql";
        adminuser = "grajpap";
        adminpassFile = "/var/lib/nextcloud/secrets/admin-pass";
      };

      settings = {
        default_phone_region = "PL";
        log_type = "systemd";
        maintenance_window_start = 2;
        overwritehost = nextcloudHost;
        overwriteprotocol = "https";
        overwritewebroot = "/nextcloud";
        "overwrite.cli.url" = "https://${nextcloudHost}/nextcloud";
        trusted_domains = [
          "127.0.0.1"
          "localhost"
          nextcloudHost
        ];
        trusted_proxies = [
          "127.0.0.1"
          "::1"
        ];
      };

      appstoreEnable = false;

      # Only what was migrated. `contacts` stays off until it is actually wanted.
      extraApps = {
        inherit
          (nextcloudApps)
          calendar
          tasks
          notes
          ;
      };

      notify_push = {
        enable = true;
        nextcloudUrl = "https://${nextcloudHost}/nextcloud";

        # 25.11 stable ships 1.3.0, whose config parser aborts with
        # "invalid database configuration: no data directory" on a perfectly valid
        # config.php. 1.4.1 (unstable) parses it. The Nextcloud module itself is
        # still stable; only this daemon moves channel.
        package = unstablePkgs.nextcloud-notify_push;
      };
    };

    # Nextcloud is served by its own nginx on loopback. Caddy stays the single
    # public entrypoint on :80 and nothing else has to bind a second webserver.
    nginx.virtualHosts.${nextcloudHost} = {
      listen = [
        {
          addr = "127.0.0.1";
          port = backendPort;
          ssl = false;
        }
      ];
      # No extraConfig here on purpose. The module already emits
      # client_max_body_size and fastcgi_buffers, so restating either is an
      # nginx [emerg] "directive is duplicate" and the unit never starts.
    };

    # ---------------------------------------------------------------------------
    # Caddy: publish Nextcloud under /nextcloud, leave HomeNest on /
    #
    # A site block keyed on the exact hostname outranks the `http://` catch-all
    # that already exists in modules/network.nix, so HomeNest is untouched.
    #
    # The well-known block has to come first and has to be answered here rather
    # than by Nextcloud. CalDAV clients probe /.well-known/caldav, but
    # Nextcloud builds that redirect out of overwritehost alone and drops the
    # /nextcloud webroot, so it sends the client to
    # https://<host>/remote.php/dav/ -- which lands on the HomeNest catch-all
    # and returns HTML instead of a DAV collection. DAVx5 fails discovery with
    # "HTTP 404 Not Found" on exactly this. Redirecting here keeps the prefix.
    # ---------------------------------------------------------------------------
    caddy.virtualHosts."http://${nextcloudHost}".extraConfig = ''
      @dav_discovery path /.well-known/caldav /.well-known/carddav /nextcloud/.well-known/*

      handle @dav_discovery {
        # `redir /nextcloud/remote.php/dav/ 301` does NOT work here. Caddy's redir
        # takes an optional leading matcher, and it claims the path as one: the
        # request then only matches clients literally asking for
        # /nextcloud/remote.php/dav/, and the Location header ends up as "301".
        # Setting the header and the status separately is unambiguous.
        header Location /nextcloud/remote.php/dav/
        respond 301
      }

      handle_path /nextcloud* {
        reverse_proxy 127.0.0.1:${toString backendPort}
      }

      handle {
        reverse_proxy localhost:3001
      }
    '';
  };

  systemd = {
    services = {
      # The generated admin password is local to this machine; it is not carried
      # over from grajpap, where the same file held a different value.
      nextcloud-admin-pass = {
        before = ["nextcloud-setup.service"];
        requiredBy = ["nextcloud-setup.service"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = "2min";
        };
        path = with pkgs; [
          coreutils
          openssl
        ];
        script = ''
          # root:users, not nextcloud:nextcloud. The group exists so a desktop
          # on the tailnet can pull nextcloud-quickshell-token-print out of
          # this directory over ssh. Nothing changes for the admin password
          # below, which stays 0400 and owner-only: the extra group bit on a
          # directory only decides who may open the directory, and the file
          # itself still refuses everyone else.
          install -d -m 0750 -o root -g users /var/lib/nextcloud/secrets

          if [ ! -s /var/lib/nextcloud/secrets/admin-pass ]; then
            umask 077
            openssl rand -base64 32 > /var/lib/nextcloud/secrets/admin-pass
          fi

          chown nextcloud:nextcloud /var/lib/nextcloud/secrets/admin-pass
          chmod 0400 /var/lib/nextcloud/secrets/admin-pass
        '';
      };

      # notify_push talks to the loopback nginx, not to the public URL, so a DNS
      # or TLS problem cannot wedge it into a retry loop.
      nextcloud-notify_push = {
        environment.NEXTCLOUD_URL = lib.mkForce "http://127.0.0.1:${toString backendPort}";
        wantedBy = lib.mkForce [];
      };
      nextcloud-notify_push_setup = {
        environment.NEXTCLOUD_URL = "http://127.0.0.1:${toString backendPort}";
        requiredBy = lib.mkForce [];
        wantedBy = lib.mkForce [];
      };

      # -----------------------------------------------------------------------
      # Credentials for the desktop calendar widget
      #
      # home/rice/quickshell/scripts/calendar.sh reads an app password from
      # ~/.config/quickshell/nextcloud-lenovo-app-password. Nothing used to
      # write that file: the only service that minted a token lived in
      # system/sync on grajpap, ran against the Nextcloud that used to be hosted
      # there, and wrote it to a path without "-lenovo" in the name. So the
      # widget on the PC had no password to read and rendered an empty calendar.
      #
      # occ is local-only, so the token has to be minted here and collected on
      # the desktop. From any desktop, with the fleet key already in place:
      #
      #   ssh lenovo-user sudo nextcloud-quickshell-token-print \
      #     > ~/.config/quickshell/nextcloud-lenovo-app-password
      #
      # The wrapper is the supported way to read it: the token file is
      # root-owned 0640, so a desktop pulls it through its own passwordless
      # sudo rather than reading the file off the disk.
      # -----------------------------------------------------------------------
      nextcloud-quickshell-token = {
        description = "Mint the Nextcloud app password used by the desktop calendar widget";
        after = ["nextcloud-setup.service"];
        wantedBy = ["multi-user.target"];
        path = [
          config.services.nextcloud.occ
          pkgs.coreutils
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = "2min";
        };
        script = ''
          # After a package bump occ answers in limited-command mode until
          # nextcloud-setup.service has finished `occ upgrade`, and
          # user:auth-tokens is not one of the calls that still works there.
          # `occ status` is the same readiness probe the other units in this
          # file use.
          for _ in $(seq 1 60); do
            if nextcloud-occ status >/dev/null 2>&1; then
              break
            fi
            echo "Nextcloud is still upgrading; waiting"
            sleep 10
          done

          if ! nextcloud-occ status >/dev/null 2>&1; then
            echo "Nextcloud did not finish upgrading within 10 minutes" >&2
            exit 1
          fi

          install -d -m 0750 -o root -g users /var/lib/nextcloud/secrets

          umask 077
          tmp="$(mktemp)"
          trap 'rm -f "$tmp"' EXIT
          nextcloud-occ user:auth-tokens:add \
            --no-interaction --name quickshell-calendar grajpap > "$tmp"
          tail -n 1 "$tmp" | install \
            -m 0640 -o root -g users /dev/stdin /var/lib/nextcloud/secrets/quickshell-token
        '';
      };

      # Re-mint on a schedule so a token that leaked, or one a desktop cached
      # months ago, eventually stops working instead of quietly authenticating
      # a widget nobody re-collected the password for.
      nextcloud-quickshell-token-rotate = {
        description = "Rotate the calendar widget's Nextcloud app password";
        after = [
          "nextcloud-setup.service"
          "nextcloud-quickshell-token.service"
        ];
        path = [
          config.services.nextcloud.occ
          pkgs.coreutils
          pkgs.jq
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = "2min";
        };
        script = ''
          for _ in $(seq 1 60); do
            if nextcloud-occ status >/dev/null 2>&1; then
              break
            fi
            sleep 10
          done
          nextcloud-occ status >/dev/null 2>&1 || exit 1

          old_ids="$(nextcloud-occ user:auth-tokens:list grajpap --output=json \
            | jq -r '.[] | select(.name == "quickshell-calendar") | .id')"

          systemctl restart nextcloud-quickshell-token.service

          # After the restart, not before: the new token has to exist before
          # the old one stops working, or a rotation that fails halfway leaves
          # every desktop with a password for nothing.
          for token_id in $old_ids; do
            nextcloud-occ user:auth-tokens:delete \
              --no-interaction grajpap "$token_id" || true
          done
        '';
      };
    };

    timers = {
      nextcloud-notify_push = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "30s";
          Unit = "nextcloud-notify_push.service";
        };
      };

      nextcloud-notify_push_setup = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "45s";
          Unit = "nextcloud-notify_push_setup.service";
        };
      };
      nextcloud-quickshell-token-rotate = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "monthly";
          Persistent = true;
          RandomizedDelaySec = "6h";
        };
      };
    };
  };

  # The wrapper the desktops call over ssh. The token file is root-owned 0640,
  # so this is the supported way in rather than loosening the file itself.
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "nextcloud-quickshell-token-print";
      runtimeInputs = [pkgs.coreutils];
      text = ''
        set -eu
        file=/var/lib/nextcloud/secrets/quickshell-token

        if [ ! -s "$file" ]; then
          echo "nextcloud-quickshell-token-print: no token minted yet." >&2
          echo "On lenovo: sudo systemctl start nextcloud-quickshell-token.service" >&2
          exit 1
        fi

        cat "$file"
      '';
    })
  ];
}
