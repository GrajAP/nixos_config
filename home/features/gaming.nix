{pkgs, ...}: {
  home.packages = with pkgs; [
    heroic
    steam
    umu-launcher
    vulkan-tools
  ];

  xdg.desktopEntries = {
    cs2 = {
      name = "Counter-Strike 2";
      comment = "Play this game on Steam";
      exec = "steam steam://rungameid/730";
      icon = "steam_icon_730";
      terminal = false;
      type = "Application";
      categories = ["Game"];
      settings = {
        Keywords = "cs2;counterstrike;counter-strike;gaming;";
      };
    };

    rocket-league = {
      name = "Rocket League";
      comment = "Play Rocket League via Heroic";
      exec = "heroic --no-gui --no-sandbox \"heroic://launch?appName=Sugar&runner=legendary\"";
      icon = "/home/grajpap/.config/heroic/icons/Sugar.jpg";
      terminal = false;
      type = "Application";
      categories = ["Game"];
      settings = {
        Keywords = "rocketleague;rocket;league;rl;sugar;gaming;";
      };
    };

    meccha-chameleon = {
      name = "MECCHA CHAMELEON";
      comment = "Play MECCHA CHAMELEON on Steam";
      exec = "steam steam://rungameid/4704690";
      icon = "steam";
      terminal = false;
      type = "Application";
      categories = ["Game"];
      settings = {
        Keywords = "meccha;chameleon;gaming;";
      };
    };
  };
}
