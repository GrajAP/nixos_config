{...}: {
  imports = [
    ./hardware-configuration.nix

    # Shared with grajpap, unlike everything else in here: the unattended fleet
    # update has to be the same code on every host or the two drift.
    ../../system/maintenance

    # One concern per file, so a rebuild diff is reviewable at a glance.
    ./modules/boot.nix # kernel, swap, zram, loader, locale
    ./modules/server.nix # headless baseline, journald, oomd
    ./modules/power.nix # TLP, thermald, lid/backlight, CPU mitigations
    ./modules/security.nix # users, sudo, sshd
    ./modules/network.nix # tailscale, avahi, caddy, firewall
    ./modules/docker.nix # container engine
    ./modules/homenest.nix # the production app
    ./modules/nextcloud.nix # calendar, tasks, notes
    ./modules/backup.nix # restic + sqlite-safe snapshotting
    ./modules/monitoring.nix # smartd, alerting
    ./modules/maintenance.nix # nix GC, patch awareness
    ./modules/mobile.nix # adb + udev for the POCO test phone
    ./modules/packages.nix # system + per-user package sets
    ./modules/shell.nix # zsh, starship, aliases
  ];

  # The production app. Everything else on this box is infrastructure for it.
  services.homenest.enable = true;

  # Daily git pull + rebuild. Headless, so there is nobody's session to protect
  # and the update is switched in rather than left for the next boot.
  fleet.autoRebuild = {
    enable = true;
    onCalendar = "*-*-* 04:40:00";
    randomizedDelaySec = "20min";
    mode = "switch";
    # This box is the tailnet's only always-on path to the others. If tailscaled
    # is not back after a switch, the run rolls the switch back by itself.
    criticalUnits = [
      "tailscaled"
      "sshd"
      "caddy"
    ];
  };

  # Keep this in sync with `nixos-version`. Bump on every release, never before.
  system.stateVersion = "25.11";
}
