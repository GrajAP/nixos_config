{...}: {
  imports = [
    ./hardware-configuration.nix

    # Shared with the desktops, unlike everything else in here: the unattended
    # fleet update has to be the same code on every host or they drift.
    ../../system/maintenance
    ../../system/mobile/adb.nix # adb + udev for the POCO test phone

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

    ./modules/packages.nix # system + per-user package sets
    ./modules/shell.nix # zsh, starship, aliases

    # Shared with grajpap: t3 CLI, T3 Connect environment, theme publishing
    ../../apps/t3code/modules/nixos.nix
  ];

  # The production app. Everything else on this box is infrastructure for it.
  services.homenest.enable = true;

  # Headless T3 Code host: `t3 serve`, `t3 theme` and `t3 connect` for T3
  # Connect, plus the drop-in that gives the `t3 service install` unit a Nix
  # PATH, nix-ld and a CA bundle.
  t3code.enable = true;

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
