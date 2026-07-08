{pkgs, ...}: {
  home.packages = with pkgs; [
    jstest-gtk
    steam
    supertuxkart
    vulkan-tools
  ];
}
