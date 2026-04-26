{pkgs, ...}: {
  programs.waybar = {
    enable = true;
    systemd = {
      enable = true;
      targets = ["hyprland-session.target"];
    };
    settings = {
      mainBar = {
        layer = "top";
        output = "DP-1";
        position = "right";
        height = 1440;
        width = 30;
        spacing = 7;
        margin-left = 0;
        margin-top = 0;
        margin-bottom = 0;
        margin-right = 0;
        exclusive = true;
        modules-left = [
          "hyprland/workspaces"
        ];
        modules-right = [
          "pulseaudio"
          "network"
          "clock"
        ];
        clock = {
          format = "{:%H:%M\n%d/%m}";
          interval = 1;
          on-click = "obsidian";
          tooltip-format = ''
            <big>{:%Y %B}</big>
            <tt><small>{calendar}</small></tt>'';
        };
        pulseaudio = {
          scroll-step = 5;
          tooltip = true;
          on-click = "${pkgs.killall}/bin/killall pavucontrol || ${pkgs.pavucontrol}/bin/pavucontrol";
          format = "{icon}";
          format-muted = "󰝟 ";
          format-bluetooth = "󰂯";
          format-icons = {
            default = ["" "" " "];
          };
        };
        network = let
          nm-editor = "${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
        in {
          format-wifi = "󰤨 {essid}";
          format-ethernet = "󰈀";
          format-alt = "󱛇";
          format-disconnected = "󰤭";
          tooltip-format = "{ipaddr}/{ifname} via {gwaddr} ({signalStrength}%)";
          on-click-right = "${nm-editor}";
        };
        "hyprland/workspaces" = {
          on-click = "activate";
          format = "{icon}";
          active-only = false;
          format-icons = {
            "1" = "一";
            "2" = "二";
            "3" = "三";
            "4" = "四";
            "5" = "五";
            "6" = "六";
            "7" = "七";
            "8" = "八";
            "9" = "九";
            "10" = "十";
            default = "一";
          };

          persistent_workspaces = {
            "*" = 10;
          };
        };
      };
    };
  };
}
