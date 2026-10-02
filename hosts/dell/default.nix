{...}: {
  imports = [./hardware-configuration.nix];

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

    # Suspend on lid close. The shared desktop config already sets
    # HandleLidSwitch = "suspend"; only LidSwitchDocked is added here. lenovo
    # masks the sleep targets entirely -- the opposite case, this is a portable
    # machine that must actually suspend.
    logind.settings.Login.LidSwitchDocked = "ignore";

    # Makes the TLP charge thresholds above effective.
    upower.enable = true;

    fprintd.enable = true;
  };

  hardware = {
    bluetooth.enable = true;
    # No enable32Bit: the PC needs it for Steam/Wine, and here it would be
    # 32-bit library surface for nothing.
    graphics.enable = true;
  };
}
