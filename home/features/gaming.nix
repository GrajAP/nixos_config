{pkgs, ...}: {
  home.packages = with pkgs; [
    steam
    heroic
    vulkan-tools
    rare
  ];
}
