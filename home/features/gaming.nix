{pkgs, ...}: {
  home.packages = with pkgs; [
    steam
    vulkan-tools
  ];
}
