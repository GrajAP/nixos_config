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
        pgrep -x 'cs2|cs2_linux64|cs2\.exe' >/dev/null
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
  ];
  environment.systemPackages = with pkgs; [
    acpi
    powertop
    libnotify
    teamviewer
  ];

  systemd.services.kanata-cs2-guard = {
    description = "Disable Kanata home-row mods while Counter-Strike 2 is running";
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
            "/dev/input/by-path/pci-0000:09:00.3-usb-0:6.2:1.0-event-kbd"
            "/dev/input/by-path/pci-0000:09:00.3-usb-0:6.2:1.2-event-kbd"
            "/dev/input/by-path/pci-0000:0e:00.3-usb-0:4.2:1.1-event-kbd"
            "/dev/input/by-path/pci-0000:09:00.3-usb-0:2:1.0-event-kbd"
            "/dev/input/by-path/pci-0000:0e:00.3-usb-0:1.1:1.0-event-kbd"
            "/dev/input/by-path/pci-0000:0e:00.3-usb-0:1.2:1.1-event-kbd"
            "/dev/input/by-path/pci-0000:0e:00.3-usb-0:1.1:1.2-event-kbd"
            "/dev/input/by-path/pci-0000:09:00.3-usb-0:1.2:1.1-event-kbd"
            "/dev/input/by-path/pci-0000:09:00.3-usb-0:2:1.2-event-kbd"
          ];
          extraArgs = ["--nodelay"];
          extraDefCfg = "process-unmapped-keys yes";
          config = ''

            (defsrc
              caps a s d f j k l ;
            )
            (defvar
              tap-time 200
              hold-time 200
            )

            (defalias
              escctrl (tap-hold $tap-time $hold-time esc lctl)
              a (tap-hold $tap-time $hold-time a lmet)
              s (tap-hold $tap-time $hold-time s ralt)
              d (tap-hold $tap-time $hold-time d lsft)
              f (tap-hold $tap-time $hold-time f lctl)
              j (tap-hold $tap-time $hold-time j lctl)
              k (tap-hold $tap-time $hold-time k lsft)
              l (tap-hold $tap-time $hold-time l ralt)
              ; (tap-hold $tap-time $hold-time ; lmet)
            )

            (deflayer base
              @escctrl @a @s @d @f @j @k @l @;
            )


          '';
        };
      };
    };
    fprintd.enable = true;
    xserver.videoDrivers = ["amdgpu"];
    teamviewer.enable = true;
  };

  boot = {
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
        corectrl
        gamemode
        mangohud
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [
        libvdpau-va-gl
        mangohud
      ];
    };
  };
}
