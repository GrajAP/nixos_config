{
  pkgs,
  lib,
  config,
  ...
}: {
  services.mako = {
    enable = true;
    package = pkgs.mako;
    settings = lib.mkForce {
      font = "JetBrainsMono Nerd Font 11";
      background-color = "${config.lib.stylix.colors.withHashtag.base00}ee";
      text-color = config.lib.stylix.colors.withHashtag.base05;
      border-color = config.lib.stylix.colors.withHashtag.base0D;
      border-size = 2;
      border-radius = 10;
      padding = "14,18";
      margin = "18";
      width = 360;
      height = 120;
      default-timeout = 3500;
      max-visible = 4;
      layer = "overlay";
      markup = true;
      format = "%s\\n%b";
    };
  };
}
