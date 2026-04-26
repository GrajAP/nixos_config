{pkgs, ...}: {
  home.packages = with pkgs; [
    github-desktop
    libreoffice-fresh
    obsidian
  ];
}
