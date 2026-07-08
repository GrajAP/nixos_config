{pkgs, ...}: {
  home.packages = with pkgs; [
    jstest-gtk
    speed-dreams
    steam
    supertuxkart
    vulkan-tools
  ];
}
