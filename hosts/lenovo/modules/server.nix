_: {
  # ===========================================================================
  # HEADLESS SERVER BASELINE
  #
  # No compositor, no display manager, no audio stack. Anything that only exists
  # to serve a GUI is actively disabled so it cannot be pulled in as a
  # dependency later.
  # ===========================================================================

  services = {
    # GUI stack: off
    xserver.enable = false;
    displayManager.gdm.enable = false;
    desktopManager.gnome.enable = false;
    greetd.enable = false;
    pulseaudio.enable = false;
    pipewire.enable = false;
    printing.enable = false;

    # ---------------------------------------------------------------------------
    # journald
    #
    # Docker's log driver was json-file, so container output was capped; the
    # journal itself had no cap at all and was already ~300MB after ten hours.
    # Bounded now, and retention-bounded so the disk cannot creep upward forever.
    # ---------------------------------------------------------------------------
    # The NixOS options are services.journald.{storage,rateLimitInterval,
    # rateLimitBurst,forwardToSyslog}; size and retention caps go through
    # extraConfig, which is appended to journald.conf verbatim.
    journald = {
      storage = "persistent";
      forwardToSyslog = false; # otherwise every message is stored twice

      # Tighter than the 10000/30s default. A log-spamming service should be
      # throttled, not allowed to write gigabytes between collections.
      rateLimitInterval = "30s";
      rateLimitBurst = 2000;

      extraConfig = ''
        # Without these, SystemMaxUse defaults to 10% of the filesystem capped at
        # 4GB. The journal was already ~300MB after ten hours.
        SystemMaxUse=2G
        SystemKeepFree=10G
        SystemMaxFileSize=128M
        MaxRetentionSec=30day
      '';
    };
  };

  programs = {
    hyprland.enable = false;

    # Enable nix-ld so dynamically linked generic Linux binaries (such as
    # npm/bun packages, language servers, and T3 Code providers like OpenCode)
    # can run seamlessly on NixOS instead of failing with stub-ld.
    nix-ld.enable = true;
  };

  xdg.portal.enable = false;

  hardware = {
    bluetooth.enable = false;

    # i915 + VAAPI. Containers that want hardware transcoding need
    # devices = [ "/dev/dri/renderD128" ] and membership of the `render` group;
    # see modules/docker.nix.
    graphics.enable = true;
  };

  # ---------------------------------------------------------------------------
  # systemd-oomd
  #
  # NixOS enables this by default with an 80% memory-pressure limit on
  # system.slice, user.slice and -.slice. On a 4-core box that also runs gradle
  # daemons and tsc, the defaults are tight enough to kill the wrong process.
  # Loosened globally, and the real protection is per-service memory caps
  # (see modules/homenest.nix) which reap the guilty cgroup instead of a
  # bystander.
  # ---------------------------------------------------------------------------
  systemd = {
    oomd = {
      enable = true;
      enableRootSlice = true;
      enableSystemSlice = true;
      enableUserSlices = true;
      settings.OOM = {
        DefaultMemoryPressureLimit = "90%";
        DefaultMemoryPressureDurationSec = "120s";
      };
    };

    slices = {
      system.sliceConfig.ManagedOOMMemoryPressureLimit = "90%";
      user.sliceConfig.ManagedOOMMemoryPressureLimit = "90%";
      "-".sliceConfig.ManagedOOMMemoryPressureLimit = "90%";
    };
  };
}
