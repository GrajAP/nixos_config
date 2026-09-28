{pkgs, ...}: {
  # ===========================================================================
  # PACKAGES
  #
  # Split by who needs them, because the split is not cosmetic: everything in
  # environment.systemPackages is linked into /run/current-system/sw and becomes
  # part of every rebuild's closure, and everything in it is on $PATH for every
  # service and every systemd unit.
  #
  # Anything an operational script shells out to MUST stay in the system set,
  # even if only grajpap ever runs it. The HomeNest auto-updater
  # (/opt/homenest/scripts/auto-update.sh) is the specific case that matters
  # here: it sets its own PATH to
  #     /run/current-system/sw/bin:~/.nix-profile/bin:/usr/local/bin:/usr/bin:/bin
  # and calls git, node and npm. Those are system packages for that reason, not
  # because a human needs them at a root prompt.
  # ===========================================================================

  environment.systemPackages = with pkgs; [
    # --- required by services and operational scripts -------------------
    git # homenest auto-update.sh, nix-update-check timer
    nodejs_22 # homenest.service ExecStart, auto-update.sh
    sqlite # consistent database snapshot in the restic backup
    python3 # was in the previous system set; node tooling and scripts expect it
    restic # backup timers
    smartmontools # smartd, and manual smartctl
    curl
    wget
    gnused
    coreutils
    util-linux # ss, lsblk, flock used by scripts
    procps # pgrep in the GC timer

    # --- ssh / remote access -------------------------------------------
    cloudflared # required by T3 Code connect tunnel
    openssh

    # --- diagnostics, cheap enough to keep system-wide -------------------
    vim
    neovim
    nano
    jq
    ripgrep
    fd
    htop
    btop
    tmux
    usbutils
    pciutils
    lm_sensors
    ethtool
    acpid
    powertop # manual diagnostics only; see modules/power.nix
    tree

    # --- containers -----------------------------------------------------
    docker-compose
    lazydocker
  ];

  # Interactive tooling for grajpap only. Reaches $PATH through
  # /etc/profiles/per-user/grajpap, which the profile chain adds for logged-in
  # sessions. Not available to services.
  users.users.grajpap.packages = with pkgs; [
    # shells and their integrations
    starship
    eza
    bat
    zoxide
    fzf
    skim
    dust
    procs
    zsh-autosuggestions
    zsh-syntax-highlighting
    starship

    # dev
    bun
    pnpm
    gcc
    gnumake
    yt-dlp
    fastfetch
    nvd
    nh

    # homelab / t3 workspace
    nix-output-monitor

    # shim for the t3 CLI, which lives outside Nix at /opt/t3. Not reproducible
    # and it will break when /opt/t3 is reinstalled; kept because it is on the
    # critical path for day-to-day work.
    (writeShellScriptBin "t3" ''
      exec /opt/t3/node_modules/.bin/t3 "$@"
    '')
  ];

  # Extras that are not worth putting in a system closure but are handy.
  environment.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less -R";
  };
}
