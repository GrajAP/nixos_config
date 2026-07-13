{pkgs, ...}: {
  home.packages = with pkgs; [
    ferdium
    proton-pass
    signal-desktop
  ];
}
