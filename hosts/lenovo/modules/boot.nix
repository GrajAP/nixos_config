{
  config,
  lib,
  ...
}: {
  # ===========================================================================
  # BOOT, KERNEL, LOCALES
  # ===========================================================================

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;

      # This box is headless, so the menu is only useful for recovering from a bad
      # switch. Keep it short but non-zero, and keep enough generations to roll back.
      timeout = 1;
    };

    kernelParams =
      [
        "consoleblank=60" # blank the console after 60s

        # Drive the low-power governor interface directly. Without this the kernel
        # falls back to the legacy intel_cpufreq driver, which has measurably worse
        # idle power on Haswell. TLP's CPU_ENERGY_PERF_POLICY maps onto the EPP.
        "intel_pstate=active"
      ]
      ++ lib.optionals (!config.power.cpuMitigations) [
        # See modules/power.nix -> power.cpuMitigations. Turning this off removes
        # PTI, retpolines, IBPB, RDT and friends: a real power/thermal win on
        # Haswell, and a real security regression. It is opt-in for that reason.
        "mitigations=off"
      ];

    kernel.sysctl."vm.swappiness" = 10;
  };

  # ---------------------------------------------------------------------------
  # Swap
  #
  # The on-disk swap from hardware-configuration.nix stays as a last resort, but
  # with a low swappiness the kernel fills zram first. Keeps the page cache
  # (which is what Docker actually needs) from being evicted to the SSD.
  # ---------------------------------------------------------------------------
  zramSwap = {
    enable = true;
    memoryPercent = 33; # ~2.5G of 7.7G
    priority = 100; # outrank on-disk swap
    algorithm = "zstd";
  };

  # A swapfile is a better fit than the leftover partition for a growing store,
  # but swapping partitions is out of scope here: the disk UUID is referenced by
  # hardware-configuration.nix and must not change underneath a running system.

  # ---------------------------------------------------------------------------
  # Identity / locale
  # ---------------------------------------------------------------------------
  networking = {
    hostName = "lenovo";
    networkmanager.enable = true;
  };

  time.timeZone = "Europe/Warsaw";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "pl_PL.UTF-8";
      LC_IDENTIFICATION = "pl_PL.UTF-8";
      LC_MEASUREMENT = "pl_PL.UTF-8";
      LC_MONETARY = "pl_PL.UTF-8";
      LC_NAME = "pl_PL.UTF-8";
      LC_NUMERIC = "pl_PL.UTF-8";
      LC_PAPER = "pl_PL.UTF-8";
      LC_TELEPHONE = "pl_PL.UTF-8";
      LC_TIME = "pl_PL.UTF-8";
    };
  };
  console.keyMap = "pl2";

  # ---------------------------------------------------------------------------
  # Nix
  # ---------------------------------------------------------------------------
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    # The root disk is a Samsung 840 EVO (SSD). auto-optimise-store pays for
    # hardlink rewriting on every build and buys nothing on a filesystem that
    # is not duplicating Nix store paths.
    auto-optimise-store = false;

    # Keep headroom so a runaway build cannot fill the disk and take the journal
    # (and therefore every log-based diagnosis) down with it. The setting is
    # `min-free`, not `max-free-space`, and takes a size string.
    min-free = "10G";

    # Flake lives in /etc/nixos and is a git repo; a dirty tree is a real
    # signal, so keep the default warning enabled.
    warn-dirty = true;
  };

  # ---------------------------------------------------------------------------
  # Store housekeeping
  #
  # Nix's built-in auto-GC only fires when the machine is *idle*, which a 24/7
  # server never is. A timer in modules/maintenance.nix does the work instead.
  # ---------------------------------------------------------------------------
}
