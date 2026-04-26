{
  pkgs,
  config,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
  ];
  environment.systemPackages = with pkgs; [
    acpi
    powertop
    libnotify
  ];

  networking.hostName = "grajpap";
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
    thermald.enable = true;
  };
  boot = {
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
