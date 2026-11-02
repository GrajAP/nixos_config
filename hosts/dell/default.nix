{lib, ...}: {
  imports = [
    ./hardware-configuration.nix
    # Android SDK for React Native on a USB device. Studio and the emulator
    # stay behind fleet.heavy.enable.
    ../../system/mobile
  ];

  networking.hostName = "dell";

  # Same desktop as the PC minus fleet.heavy. The reasons for each switch are
  # in the option descriptions in configuration.nix.
  fleet = {
    dualBoot = false;
    # Installed with systemd-boot. Swapping a live machine's bootloader is not
    # something a rebuild can undo.
    bootloader = "systemd-boot";
    heavy.enable = false;
    breaks = false;
    calendarHeader = false;
    autostart = false;
    wifiRandomMac = false;
    displayScale = 125;
  };

  powerManagement = {
    enable = true;
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
        # 50, not 40: TLP rejects a start threshold below 50 and then skips the
        # whole battery, which leaves both thresholds unset without an error the
        # user would notice.
        START_CHARGE_THRESH_BAT0 = 50;
        STOP_CHARGE_THRESH_BAT0 = 80;
      };
    };
    power-profiles-daemon.enable = false;
    thermald.enable = true;

    # Its resync failed every 10 minutes here with
    # "cannot create directory /var/empty/.config".
    psd.enable = lib.mkForce false;

    # HandleLidSwitch = "suspend" comes from the shared desktop config.
    logind.settings.Login.LidSwitchDocked = "ignore";

    upower.enable = true;

    fprintd.enable = true;

    # No /dev/input/by-id here: an i8042/PS/2 keyboard has no persistent ID,
    # so udev only gives it a by-path link.
    kanata.keyboards.internalKeyboard.devices = ["/dev/input/by-path/platform-i8042-serio-0-event-kbd"];
  };

  hardware = {
    bluetooth.enable = true;
    # No enable32Bit: the PC needs it for Steam/Wine, and here it would be
    # 32-bit library surface for nothing.
    graphics.enable = true;
  };
}
