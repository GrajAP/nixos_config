{pkgs, ...}: {
  nixpkgs.config.allowUnfree = true;
  home.packages = with pkgs; [
    udev
    nemo
    easyeffects
    rnnoise-plugin
    rnnoise
    flameshot
  ];
}
