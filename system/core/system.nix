{
  pkgs,
  lib,
  inputs,
  ...
}: let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in {
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      var allowedActions = [
        "org.freedesktop.udisks2.filesystem-mount",
        "org.freedesktop.udisks2.filesystem-mount-system",
        "org.freedesktop.udisks2.filesystem-mount-other-seat",
        "org.freedesktop.udisks2.eject-media",
        "org.freedesktop.udisks2.power-off-drive"
      ];

      if (
        allowedActions.indexOf(action.id) >= 0 &&
        subject.active &&
        subject.local &&
        (subject.isInGroup("wheel") || subject.isInGroup("storage"))
      ) {
        return polkit.Result.YES;
      }
    });
  '';

  services = {
    dbus = {
      packages = with pkgs; [dconf gcr udisks2];
      enable = true;
    };
    gvfs.enable = true;
    journald.extraConfig = ''
      SystemMaxUse=50M
      RuntimeMaxUse=10M
    '';
    psd = {
      enable = true;
      resyncTimer = "10m";
    };
  };
  services.udev.extraRules = ''
    KERNEL=="uinput", GROUP="input", MODE="0660"
  '';
  programs = {
    spicetify = {
      enable = true;
      enabledExtensions = with spicePkgs.extensions; [
        adblockify
        hidePodcasts
        keyboardShortcut
        betterGenres
        shuffle
      ];
      enabledCustomApps = with spicePkgs.apps; [
        newReleases
        ncsVisualizer
      ];
      enabledSnippets = with spicePkgs.snippets; [
        rotatingCoverart
        pointer
        hideMadeForYou
      ];
      #theme = lib.mkForce spicePkgs.themes.catppuccin;
      #colorScheme = lib.mkForce "mocha";
    };

    fuse.userAllowOther = true;
    java = {
      enable = true;
      package = pkgs.jre;
    };

    bash.promptInit = ''eval "$(${pkgs.starship}/bin/starship init bash)"'';
  };

  environment.variables = {
    EDITOR = "code";
    BROWSER = "helium";
  };
  environment.systemPackages = with pkgs; [
    git
    uutils-coreutils-noprefix
    btrfs-progs
    cifs-utils
    appimage-run
    starship
    ntfs3g
    wine
    wine64
    winetricks
    innoextract
  ];

  time = {
    timeZone = "Europe/Warsaw";
    hardwareClockInLocalTime = true;
  };

  services.timesyncd = {
    enable = true;
    extraConfig = ''
      PollIntervalMinSec=32
      PollIntervalMaxSec=64
      ConnectionRetrySec=5
    '';
  };

  i18n = let
    defaultLocale = "en_US.UTF-8";
    pl = "pl_PL.UTF-8";
  in {
    inherit defaultLocale;
    extraLocaleSettings = {
      LANG = defaultLocale;
      LC_COLLATE = defaultLocale;
      LC_CTYPE = defaultLocale;
      LC_MESSAGES = defaultLocale;

      LC_ADDRESS = pl;
      LC_IDENTIFICATION = pl;
      LC_MEASUREMENT = pl;
      LC_MONETARY = pl;
      LC_NAME = pl;
      LC_NUMERIC = pl;
      LC_PAPER = pl;
      LC_TELEPHONE = pl;
      LC_TIME = pl;
    };
  };

  console = let
    variant = "u24n";
  in {
    font = "${pkgs.terminus_font}/share/consolefonts/ter-${variant}.psf.gz";
    earlySetup = true;
    keyMap = "pl";
  };

  boot.binfmt.registrations = lib.genAttrs ["appimage" "AppImage"] (ext: {
    recognitionType = "extension";
    magicOrExtension = ext;
    interpreter = "/run/current-system/sw/bin/appimage-run";
  });

  systemd = {
    services."getty@tty1".enable = false;
    services."autovt@tty1".enable = false;
    services."getty@tty7".enable = false;
    services."autovt@tty7".enable = false;
    # Systemd OOMd
    # Fedora enables these options by default. See the 10-oomd-* files here:
    # https://src.fedoraproject.org/rpms/systemd/tree/acb90c49c42276b06375a66c73673ac3510255
    oomd.enableRootSlice = true;

    # TODO channels-to-flakes
    tmpfiles.rules = [
      "D /nix/var/nix/profiles/per-user/root 755 root root - -"
    ];
  };
}
