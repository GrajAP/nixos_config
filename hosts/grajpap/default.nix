{
  pkgs,
  config,
  lib,
  ...
}: let
  kanataCs2Guard = pkgs.writeShellApplication {
    name = "kanata-cs2-guard";
    runtimeInputs = with pkgs; [coreutils procps systemd];
    text = ''
      service="kanata-internalKeyboard.service"
      restart_marker="/run/kanata-cs2-guard/restart-kanata"

      game_running() {
        pgrep -x -i 'cs2|cs2_linux64|cs2\.exe|rocketleague(\.exe?)?' >/dev/null
      }

      restore_keyboard() {
        if [[ -e "$restart_marker" ]] && ! game_running; then
          systemctl start "$service"
          rm -f "$restart_marker"
        fi
      }

      trap restore_keyboard EXIT INT TERM

      while true; do
        if game_running; then
          if systemctl is-active --quiet "$service"; then
            touch "$restart_marker"
            systemctl stop "$service"
          fi
        else
          restore_keyboard
        fi

        sleep 1
      done
    '';
  };
in {
  imports = [
    ./hardware-configuration.nix

    # PC-only: data disks, Android dev, Nextcloud hosting, backups, health.
    ../../system/core/storage.nix
    ../../system/mobile
    ../../system/sync
    ../../system/backup
    ../../system/monitoring

    # The public PanicMap API. This machine is the backend for hy.be-spotted.org.
    ../../apps/panicmap/modules/nixos.nix
  ];

  fleet.heavy.enable = true;

  # Serves hy.be-spotted.org out of /mnt/SSD2/dev/hackyeah2026 and keeps itself
  # in step with that checkout: the reload timer for a local edit, the update
  # timer for a pushed commit.
  panicmap = {
    enable = true;
    autoUpdate.enable = true;
  };

  fleet.autoRebuild = {
    enable = true;
    # The PC sleeps, so the wall clock is a suggestion: Persistent=true below
    # catches the run on the next boot if it was missed.
    onCalendar = "*-*-* 05:20:00";
    randomizedDelaySec = "2h";
    # Nobody is usually logged in at 05:20, and switching the system under a
    # running compositor restarts user services out from under it.
    skipWhenUserSessionActive = true;
    # A desktop is not a server: the nightly update is a convenience, so a
    # failed switch is rolled back and the previous system is left running.
    criticalUnits = [
      "tailscaled"
      "sshd"
      "panicmap-api.service"
    ];
  };
  environment.systemPackages = with pkgs; [
    acpi
    powertop
    libnotify
    corectrl
    gamemode
    mangohud
    umu-launcher
  ];

  programs = {
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };
    gamemode.enable = true;
  };

  systemd = {
    services.kanata-cs2-guard = {
      description = "Disable Kanata home-row mods while Counter-Strike 2 or Rocket League is running";
      wantedBy = ["multi-user.target"];
      after = ["kanata-internalKeyboard.service"];
      serviceConfig = {
        ExecStart = lib.getExe kanataCs2Guard;
        Restart = "always";
        RestartSec = 1;
        RuntimeDirectory = "kanata-cs2-guard";
        RuntimeDirectoryPreserve = "yes";
      };
    };

    services.teamviewerd = {
      serviceConfig = {
        Restart = lib.mkForce "always";
        RestartSec = 2;
        ExecStartPost = "${pkgs.writeShellScript "fix-teamviewer-perms" ''
          ${pkgs.coreutils}/bin/chmod 644 /var/lib/teamviewer/global.conf || true
        ''}";
      };
    };
  };

  powerManagement.resumeCommands = ''
    ${pkgs.systemd}/bin/systemctl try-restart teamviewerd.service
  '';

  networking.hostName = "grajpap";
  # Keep the desktop responsive while avoiding unnecessarily aggressive boost
  # clocks during light and background workloads.
  powerManagement.cpuFreqGovernor = "performance";
  services = {
    kanata = {
      enable = true;
      keyboards = {
        internalKeyboard = {
          devices = [
            "/dev/input/by-id/usb-Cooler_Master_Technology_Inc._MK730-event-kbd"
            "/dev/input/by-id/usb-Cooler_Master_Technology_Inc._MK730-if02-event-kbd"
          ];
          extraArgs = ["--nodelay"];
          extraDefCfg = "process-unmapped-keys yes";
          config = ''

            (defsrc
              caps a s d f j k l ; rmet
            )
            (defvar
              tap-time 200
              hold-time 200
            )

            (defalias
              escctrl (tap-hold $tap-time $hold-time esc lctl)
              a (tap-hold $tap-time $hold-time a lalt)
              s (tap-hold $tap-time $hold-time s ralt)
              d (tap-hold $tap-time $hold-time d lsft)
              f (tap-hold $tap-time $hold-time f lctl)
              j (tap-hold $tap-time $hold-time j lctl)
              k (tap-hold $tap-time $hold-time k lsft)
              l (tap-hold $tap-time $hold-time l ralt)
              ; (tap-hold $tap-time $hold-time ; lalt)
            )

            (deflayer base
              @escctrl @a @s @d @f @j @k @l @; lalt
            )


          '';
        };
      };
    };
    fprintd.enable = true;
    xserver.videoDrivers = ["amdgpu"];
    teamviewer = {
      enable = true;
      package = pkgs.teamviewer.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [pkgs.makeWrapper];
        postFixup =
          (old.postFixup or "")
          + ''
            wrapProgram $out/bin/teamviewer --set QT_QPA_PLATFORM xcb
            wrapProgram $out/share/teamviewer/tv_bin/script/teamviewer --set QT_QPA_PLATFORM xcb
          '';
      });
    };
  };

  boot = {
    resumeDevice = "/dev/disk/by-uuid/03bff03d-086e-42ea-89a8-f921c2eabcd1";
    kernelPackages = lib.mkForce pkgs.linuxPackages_zen;
    kernelModules = ["acpi_call"];
    extraModulePackages = with config.boot.kernelPackages;
      [
        acpi_call
        cpupower
      ]
      ++ [pkgs.cpupower-gui];
    kernelParams = [
      "processor.max_cstate=5"
      "amd_pstate=guided"
      "amdgpu.dpm=1"
      "amdgpu.gpu_recovery=1"
    ];
  };
  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      package = pkgs.bluez5-experimental;
    };
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        libva
        libvdpau-va-gl
        mesa.opencl
        ocl-icd
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [
        libvdpau-va-gl
      ];
    };
  };
}
