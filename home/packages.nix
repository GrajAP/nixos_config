{pkgs, ...}: {
  home.packages = with pkgs; [
    udev
    nemo
    easyeffects
    rnnoise-plugin
    rnnoise
    krita
  ];
}
