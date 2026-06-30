{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    quickshell
    networkmanagerapplet
  ];

  xdg.configFile."quickshell/shell.qml".source = ./shell.qml;
  xdg.configFile."quickshell/Theme.qml".text = ''
    pragma Singleton
    import QtQuick

    QtObject {
      readonly property color background: "${config.lib.stylix.colors.withHashtag.base00}"
      readonly property color surface: "${config.lib.stylix.colors.withHashtag.base02}"
      readonly property color text: "${config.lib.stylix.colors.withHashtag.base05}"
      readonly property color muted: "${config.lib.stylix.colors.withHashtag.base04}"
      readonly property color accent: "${config.lib.stylix.colors.withHashtag.base0D}"
      readonly property color danger: "${config.lib.stylix.colors.withHashtag.base08}"
      readonly property string font: "JetBrainsMono Nerd Font"
    }
  '';
  xdg.configFile."quickshell/qmldir".text = ''
    singleton Theme 1.0 Theme.qml
  '';

  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell desktop shell";
      After = ["hyprland-session.target"];
      PartOf = ["hyprland-session.target"];
    };
    Service = {
      ExecStart = "${pkgs.quickshell}/bin/qs -c ${config.xdg.configHome}/quickshell";
      Restart = "on-failure";
      RestartSec = 2;
      Environment = ["QS_NO_RELOAD_POPUP=1"];
    };
    Install.WantedBy = ["hyprland-session.target"];
  };
}
