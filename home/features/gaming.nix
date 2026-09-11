{pkgs, ...}: {
  home.packages = with pkgs; [
    heroic
    steam
    vulkan-tools
  ];
}
