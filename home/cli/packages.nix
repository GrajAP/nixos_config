{pkgs, ...}: let
  texlive = pkgs.texlive.combine {
    inherit
      (pkgs.texlive)
      scheme-small
      noto
      mweights
      cm-super
      cmbright
      fontaxes
      beamer
      ;
  };
in {
  home.packages = with pkgs; [
    fastfetch
    texlive
    python3
    gcc
    gpp
    gdb
    ddd
    valgrind
    gprof2dot
    nodejs
    pnpm
    #    nodePackages.typescript
    watchman
    #   nodePackages.eas-cli # Expo Application Services CLI
    lsix
    docker-compose
    rustup
    neovim
    opencode
    gitleaks
    killall
    zoxide
    wget
    # Tbh should be preinstalled
    gnumake
    # Runs programs without installing them
    comma

    cloudflared
    # grep replacement
    ripgrep

    # ping, but with cool graph
    gping

    # dns client

    # neofetch but for git repos
    onefetch

    vdirsyncer
    #khal

    # neofetch but for cpu's
    cpufetch

    poppler-utils

    audacity

    # download from yt and other websites
    yt-dlp
    catimg

    # minecraft launcher (non-premium)
    prismlauncher

    # man pages for tiktok attention span mfs
    tealdeer

    # markdown previewer
    glow

    # profiling tool
    hyperfine

    # gimp for acoustic people
    #krita

    # premiere pro for acoustic people
    ffmpeg-full

    # networking stuff
    nmap
    wget

    # faster find
    fd

    # http request thingy
    xh

    grex

    # todo app for acoustic people (wrriten by me :3)
    todo

    # json thingy
    jq

    doppler
    # syncthnig for acoustic people
    rsync

    figlet
    # Generate qr codes
    qrencode

    # script kidde stuff
    hcxdumptool
    hashcat

    unzip
    zip
    # tshark
    # termshark
  ];
}
