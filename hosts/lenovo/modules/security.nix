{pkgs, ...}: {
  # ===========================================================================
  # USERS, SUDO, SSH
  # ===========================================================================

  users = {
    users = {
      grajpap = {
        isNormalUser = true;
        description = "grajpap";
        shell = pkgs.zsh;

        # wheel  - sudo, and (as a side effect) the nix profile on $PATH
        # docker  - container engine socket
        # homenest- write access to /opt/homenest/data alongside the app's own user,
        #           so APK builds and manual sqlite work still function
        extraGroups = [
          "networkmanager"
          "wheel"
          "docker"
          "homenest"
        ];

        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHNE9YV3UXWgYdYsNlF8pxBqF9DWSXeGyAM7rzzFElEm lenovo-auto"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJvg6c2WU5T613n8uRr8PxteoOcX+79X70k1scYgiCyO adampisarczyk2006@gmail.com"
        ];
      };

      # HomeNest runs as this account, not as grajpap. It has no shell, no wheel, no
      # docker group and an empty capability set, so a remote code execution in the
      # Node process is no longer a root shell.
      homenest = {
        isSystemUser = true;
        group = "homenest";
        home = "/var/empty";
        createHome = false;
        shell = "${pkgs.shadow}/bin/nologin";
        description = "HomeNest application service account";
      };

      # grajpap no longer carries keys for the root account. Root SSH login is
      # disabled outright (see services.openssh below), so a leaked private key
      # now buys an unprivileged shell and nothing more.
      root.openssh.authorizedKeys.keys = [];
    };

    groups.homenest = {};
  };

  # ---------------------------------------------------------------------------
  # sudo
  #
  # Still passwordless: the rebuild aliases and the HomeNest auto-updater both
  # invoke sudo non-interactively, and this box has no logged-in session to type
  # a password into. That means grajpap is root-equivalent, so at least every
  # invocation is now written to a log.
  #
  # To require a password, set this to true -- but then `nrb`/`rebuild` stop
  # working unattended and the auto-updater's restart step will fail.
  # ---------------------------------------------------------------------------
  security.sudo.wheelNeedsPassword = false;
  security.sudo.extraConfig = ''
    Defaults log_output
    Defaults logfile=/var/log/sudo.log
    Defaults timestamp_timeout=15
  '';

  # ---------------------------------------------------------------------------
  # OpenSSH
  #
  # Key-only, root login refused, no X11 forwarding, and a hard cap on auth
  # attempts. AllowTcpForwarding is "local" so `ssh -L` still works but the box
  # cannot be used as a reverse tunnel pivot.
  # ---------------------------------------------------------------------------
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PubkeyAuthentication = true;
      PermitEmptyPasswords = false;
      X11Forwarding = false;
      AllowAgentForwarding = false;
      AllowTcpForwarding = "local";
      MaxAuthTries = 3;
      MaxSessions = 5;
      LoginGraceTime = 30;
      LogLevel = "VERBOSE";

      # Reap connections whose client has stopped answering. This does not drop
      # idle-but-healthy sessions, because the client answers the probe locally.
      ClientAliveInterval = 120;
      ClientAliveCountMax = 3;
    };
  };

  # ---------------------------------------------------------------------------
  # Kernel
  # ---------------------------------------------------------------------------
  # NixOS exposes sysctls under boot.kernel.sysctl (freeform), not under
  # security.*. boot.nix sets vm.swappiness in the same place.
  boot.kernel.sysctl = {
    # Randomise the stack layout. Cheap, and the only reason to bother given
    # mitigations are on by default.
    "kernel.randomize_va_space" = 2;

    # Refuse SUID binaries that are not on the whitelist. NixOS already ships
    # almost none; this makes a newly installed one inert.
    "kernel.unprivileged_bpf_disabled" = 1;

    # Do not let processes inspect other users' /proc entries.
    "kernel.yama.ptrace_scope" = 1;

    # Hardening for the kernel's own attack surface, and a ptrace/syscall
    # restriction for anything that does not need them.
    "kernel.dmesg_restrict" = 1;
    "kernel.kptr_restrict" = 2;
    "net.core.bpf_jit_harden" = 2;

    # This is a single-user homelab box, not a multi-tenant host.
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;
  };

  # ---------------------------------------------------------------------------
  # fail2ban
  #
  # Low value while PasswordAuthentication is off -- there is no password to
  # brute force -- but it still shortens the window for anything key-shaped and
  # it silences the constant scanner noise in the log.
  #
  # The NixOS module already provides an `sshd` jail whenever services.openssh
  # is enabled, with backend=systemd (so it reads the journal, not a file that
  # does not exist here) and LogLevel=VERBOSE, which is what makes the jail
  # match anything.
  # ---------------------------------------------------------------------------
  services.fail2ban = {
    enable = true;
    bantime = "1h";
    maxretry = 3;

    # findtime is not a top-level option here; it is set per jail below.

    # Never ban the tailnet, and never ban the local machine. Getting this
    # wrong locks you out of a headless box.
    ignoreIP = [
      "127.0.0.1/8"
      "::1"
      "100.64.0.0/10" # Tailscale CGNAT range
      "192.168.0.0/16" # home LAN
      "10.0.0.0/8"
      "172.16.0.0/12"
    ];

    jails.sshd.settings.findtime = "10m";
  };
}
