{pkgs, ...}: {
  home.packages = with pkgs; [
    playerctl
    pavucontrol
    pulsemixer
    qbittorrent
    imv
  ];
  # Bare `playerctl` acts on the first MPRIS player on the bus, so the media
  # keys hit an idle browser tab instead of what is playing. playerctld tracks the last
  # active player and playerctl follows it.
  services.playerctld.enable = true;
  programs = {
    mpv = {
      enable = true;
      bindings = {
        UP = "add volume +2";
        DOWN = "add volume -2";
      };
      # https://wiki.archlinux.org/title/mpv#Hardware_video_acceleration
      config = {
        hwdec = "auto-safe";
        gpu-context = "wayland";
        vo = "gpu";
        profile = "gpu-hq";

        osc = false;
        border = false;
      };
      scripts = with pkgs.mpvScripts; [mpris thumbnail sponsorblock];
    };

    obs-studio = {
      enable = true;
      plugins = with pkgs.obs-studio-plugins; [wlrobs];
    };
  };
}
