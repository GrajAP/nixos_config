{pkgs, ...}: {
  home.packages = with pkgs; [
    heroic
    steam
    umu-launcher
    vulkan-tools
  ];

  xdg.desktopEntries.cs2 = {
    name = "Counter-Strike 2";
    comment = "Play this game on Steam";
    exec = "steam steam://rungameid/730";
    icon = "steam_icon_730";
    terminal = false;
    type = "Application";
    categories = ["Game"];
    settings = {
      Keywords = "cs2;counterstrike;counter-strike;";
    };
  };
}
