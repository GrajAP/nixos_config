{lib, ...}: {
  imports = [
    ./hardware-configuration.nix
    # adb, platform-tools, the Android SDK and the native build deps, so
    # React Native works against a real USB device here. Android Studio and
    # the emulator stay behind fleet.heavy.enable.
    ../../system/mobile
  ];

  networking.hostName = "dell";

  # Same desktop as the PC (system/wayland, system/core, theme/, all of home/),
  # minus everything behind fleet.heavy.enable.
  #
  # The PC dual-boots Windows on GRUB; dell has no dual-boot and was installed
  # with systemd-boot (there is a /boot/loader plus systemd-bootx64.efi on its
  # ESP). Both facts have to be declared, because bootloader.nix otherwise
  # assumes the PC's arrangement -- and swapping a live machine's bootloader is
  # not something a rebuild can undo.
  fleet = {
    dualBoot = false;
    bootloader = "systemd-boot";
    heavy.enable = false;
    # The break timer nags every 30 minutes and offers no value on a laptop you
    # close and carry around, so the entry is dropped from the widget entirely
    # instead of merely defaulting to off.
    breaks = false;
    # 1920x1080 on a 14" panel is ~141 PPI, which is roughly half the density of
    # the PC's 2560x1440 monitors. At scale 1 every label in the bar and the
    # widgets is uncomfortably small; 125 lands near 113 PPI, which is a normal
    # laptop reading size and still leaves a usable 1536x864 of logical space.
    displayScale = 125;
  };

  powerManagement = {
    enable = true;
    # Battery first. The PC pins "performance" because it is a desktop that is
    # almost never on battery; here that would only cost idle hours. Zen's
    # schedutil driver still scales up instantly under load, so this is not a
    # responsiveness tradeoff.
    cpuFreqGovernor = "powersave";
  };

  services = {
    # One power daemon, like lenovo. power-profiles-daemon would fight TLP over
    # the same knobs and, being AC/battery-blind about ASPM, undo the settings
    # that matter most here.
    tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "powersave";
        CPU_SCALING_MINFREQ_ON_AC = 800000;
        CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
        PLATFORM_PROFILE_ON_AC = "balanced";

        # The single biggest battery win on a PCIe laptop: let the link drop to
        # a low power state when idle instead of staying at full speed. These
        # are exactly the knobs the PC pins off for its dual-boot NVMe quirk.
        PCIE_ASPM_ON_AC = "powersupersave";
        PCIE_ASPM_ON_BAT = "powersupersave";
        RUNTIME_PM_ON_AC = "on";
        RUNTIME_PM_ON_BAT = "on";
        SATA_LINKPWR_ON_AC = "med_power";
        SATA_LINKPWR_ON_BAT = "med_power";
        WIFI_PWR_ON_AC = "on";
        WIFI_PWR_ON_BAT = "on";
        USB_AUTOSUSPEND = 1;

        # Preserve a full charge for a portable machine: only top up to 80%
        # while plugged in. A laptop that spends the day in a bag otherwise
        # sits at 100% SoC, which is the worst case for cell ageing.
        START_CHARGE_THRESH_BAT0 = 40;
        STOP_CHARGE_THRESH_BAT0 = 80;
      };
    };
    power-profiles-daemon.enable = false;
    thermald.enable = true;

    # profile-sync-daemon is a third power daemon and fights TLP over the same
    # knobs, so it goes the way power-profiles-daemon does. It was not merely
    # redundant here: its 10-minute resync failed for the whole uptime with
    # "cannot create directory /var/empty/.config", logging an error every ten
    # minutes.
    psd.enable = lib.mkForce false;

    # Suspend on lid close. The shared desktop config already sets
    # HandleLidSwitch = "suspend"; only LidSwitchDocked is added here. lenovo
    # masks the sleep targets entirely -- the opposite case, this is a portable
    # machine that must actually suspend.
    logind.settings.Login.LidSwitchDocked = "ignore";

    # Makes the TLP charge thresholds above effective.
    upower.enable = true;

    fprintd.enable = true;

    # Same home-row-mod layout as the PC, so the keybind (mod+Q) and the bar
    # widget behave identically. The keyboard name has to stay
    # `internalKeyboard`: quickshell watches the systemd D-Bus path for
    # kanata_2dinternalKeyboard_2eservice, and home/scripts/katana-switch
    # drives kanata-internalKeyboard.service by name.
    #
    # There is no /dev/input/by-id on this machine. udev only creates by-id
    # links for devices with a persistent ID, and an i8042/PS/2 keyboard has
    # none -- which is why the PC's by-id path cannot be copied here. The
    # by-path name below is what that same keyboard resolves to.
    kanata = {
      enable = true;
      keyboards.internalKeyboard = {
        devices = ["/dev/input/by-path/platform-i8042-serio-0-event-kbd"];
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

  hardware = {
    bluetooth.enable = true;
    # No enable32Bit: the PC needs it for Steam/Wine, and here it would be
    # 32-bit library surface for nothing.
    graphics.enable = true;
  };
}
