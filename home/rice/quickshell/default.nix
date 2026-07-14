{
  config,
  lib,
  pkgs,
  ...
}: let
  calendarPython = pkgs.python3.withPackages (pythonPackages: [
    pythonPackages.icalendar
    pythonPackages.recurring-ical-events
  ]);
  weatherQuery = pkgs.writeShellApplication {
    name = "quickshell-weather-query";
    runtimeInputs = with pkgs; [python3];
    text = builtins.readFile ./scripts/weather-query.sh;
  };
  codexUsageQuery = pkgs.writeShellApplication {
    name = "quickshell-codex-usage";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      findutils
      gawk
      gnugrep
      jq
      ripgrep
    ];
    text = builtins.readFile ./scripts/codex-usage-query.sh;
  };
  calendarTool = pkgs.writeShellApplication {
    name = "quickshell-calendar";
    runtimeInputs = with pkgs; [
      calendarPython
      xdg-utils
    ];
    text = builtins.readFile ./scripts/calendar.sh;
  };
  clipboardTool = pkgs.writeShellApplication {
    name = "quickshell-clipboard";
    runtimeInputs = with pkgs; [
      cliphist
      coreutils
      libnotify
      python3
      wl-clipboard
    ];
    text = builtins.readFile ./scripts/clipboard.sh;
  };
  katanaSwitchTool = pkgs.writeShellScriptBin "katana-switch" (builtins.readFile ../../scripts/katana-switch);
  screenshotTool = pkgs.writeShellApplication {
    name = "quickshell-screenshot";
    runtimeInputs = with pkgs; [
      coreutils
      grim
      libnotify
      procps
      (python3.withPackages (pythonPackages:
        with pythonPackages; [
          pillow
        ]))
      slurp
      wl-clipboard
    ];
    text = builtins.readFile ./scripts/screenshot.sh;
  };
  voiceTool = pkgs.writeShellApplication {
    name = "quickshell-voice";
    runtimeInputs = with pkgs; [
      coreutils
      libnotify
    ];
    text = builtins.readFile ./scripts/voice.sh;
  };
  shutdownTimerTool = pkgs.writeShellApplication {
    name = "quickshell-shutdown-timer";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      libnotify
    ];
    text = builtins.readFile ./scripts/shutdown-timer.sh;
  };
  spotifyLauncher = pkgs.writeShellApplication {
    name = "spotify";
    runtimeInputs = with pkgs; [
      coreutils
      hyprland
      jq
    ];
    text = ''
      set -euo pipefail

      spotify_client_exists() {
        hyprctl clients -j \
          | jq -e 'any(.[]; ((.class // "") | ascii_downcase) == "spotify")' \
          >/dev/null
      }

      if ! spotify_client_exists; then
        # Chromium can leave these links behind after a forced Spotify exit.
        # Remove them only when their recorded process no longer exists.
        cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/spotify"
        singleton_lock="$(readlink "$cache_dir/SingletonLock" 2>/dev/null || true)"
        singleton_pid="''${singleton_lock##*-}"
        if [[ "$singleton_pid" =~ ^[0-9]+$ ]] && ! kill -0 "$singleton_pid" 2>/dev/null; then
          singleton_socket="$(readlink "$cache_dir/SingletonSocket" 2>/dev/null || true)"
          rm -f "$cache_dir/SingletonCookie" "$cache_dir/SingletonLock" "$cache_dir/SingletonSocket"
          case "$singleton_socket" in
            /tmp/.org.chromium.Chromium.*/SingletonSocket)
              rm -rf "''${singleton_socket%/*}"
              ;;
          esac
        fi

        /run/current-system/sw/bin/spotify "$@" >/dev/null 2>&1 &
      fi

      for _ in $(seq 1 30); do
        spotify_client_exists && break
        sleep 0.25
      done

      spotify_client_exists || exit 1

      visible_monitor="$(
        hyprctl monitors -j \
          | jq -r '.[] | select((.specialWorkspace.name // "") == "special:tools") | .name' \
          | head -n1
      )"

      if [[ -z "$visible_monitor" ]]; then
        toggle-special-workspace tools
      else
        hyprctl dispatch focusmonitor "$visible_monitor" >/dev/null
      fi

      hyprctl dispatch focuswindow 'class:^(Spotify|spotify)$' >/dev/null
    '';
  };
  quickshellIpc = pkgs.writeShellApplication {
    name = "quickshell-ipc";
    runtimeInputs = with pkgs; [
      coreutils
      procps
      quickshell
      systemd
    ];
    text = builtins.readFile ./scripts/quickshell-ipc.sh;
  };
  keybinds = import ../hyprland/keybinds.nix {
    inherit config lib;
    ipc = "${quickshellIpc}/bin/quickshell-ipc";
  };
  shellConfig = pkgs.replaceVars ./shell.qml {
    weatherQuery = "${weatherQuery}/bin/quickshell-weather-query";
    codexUsageQuery = "${codexUsageQuery}/bin/quickshell-codex-usage";
    calendarQuery = "${calendarTool}/bin/quickshell-calendar";
    calendarTask = "${calendarTool}/bin/quickshell-calendar";
    clipboardTool = "${clipboardTool}/bin/quickshell-clipboard";
    katanaSwitchTool = "${katanaSwitchTool}/bin/katana-switch";
    screenshotTool = "${screenshotTool}/bin/quickshell-screenshot";
    voiceTool = "${voiceTool}/bin/quickshell-voice";
    shutdownTimerTool = "${shutdownTimerTool}/bin/quickshell-shutdown-timer";
    keybindHelp = builtins.toJSON keybinds.help;
  };
  mediaWidgetConfig = pkgs.replaceVars ./MediaWidget.qml {
    spotifyLauncher = "${spotifyLauncher}/bin/spotify";
  };
  themeConfig = pkgs.writeText "Theme.qml" ''
    pragma Singleton
    import QtQuick

    QtObject {
      readonly property color background: "${config.lib.stylix.colors.withHashtag.base00}"
      readonly property color panel: background
      readonly property color surface: "${config.lib.stylix.colors.withHashtag.base02}"
      readonly property color surfaceAlt: "${config.lib.stylix.colors.withHashtag.base01}"
      readonly property color border: "${config.lib.stylix.colors.withHashtag.base03}"
      readonly property color text: "${config.lib.stylix.colors.withHashtag.base05}"
      readonly property color muted: "${config.lib.stylix.colors.withHashtag.base04}"
      readonly property color accent: "${config.lib.stylix.colors.withHashtag.base0D}"
      readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.16)
      readonly property color danger: "${config.lib.stylix.colors.withHashtag.base08}"
      readonly property color success: "${config.lib.stylix.colors.withHashtag.base0B}"
      readonly property color warning: "${config.lib.stylix.colors.withHashtag.base0A}"

      readonly property int radiusXs: 7
      readonly property int radiusSm: 9
      readonly property int radiusMd: 12
      readonly property int radiusLg: 16
      readonly property int radiusXl: 22

      readonly property int gapXs: 4
      readonly property int gapSm: 8
      readonly property int gapMd: 12
      readonly property int gapLg: 18

      readonly property int padSm: 12
      readonly property int padMd: 16
      readonly property int padLg: 18

      readonly property int motionFast: 120
      readonly property int motionMedium: 180
      readonly property int motionPanel: 260
      readonly property int motionModal: 300

      readonly property string fontSans: "Lexend"
      readonly property string fontMono: "Maple Mono NF"
      readonly property string fontIcon: "JetBrainsMono Nerd Font"
      readonly property string font: fontIcon
    }
  '';
  qmldirConfig = pkgs.writeText "qmldir" ''
    singleton Theme 1.0 Theme.qml
    BarWorkspaceList 1.0 BarWorkspaceList.qml
    ClipboardWidget 1.0 ClipboardWidget.qml
    CodexUsageWindow 1.0 CodexUsageWindow.qml
    KeybindHelpWindow 1.0 KeybindHelpWindow.qml
    LauncherWindow 1.0 LauncherWindow.qml
    MediaWidget 1.0 MediaWidget.qml
    NotificationCenter 1.0 NotificationCenter.qml
    PowerMenuWindow 1.0 PowerMenuWindow.qml
    ShutdownWidget 1.0 ShutdownWidget.qml
    ToolsWidget 1.0 ToolsWidget.qml
    TrayWidget 1.0 TrayWidget.qml
    WeatherWidget 1.0 WeatherWidget.qml
  '';
  codexIcon = pkgs.writeText "codex.svg" (
    builtins.replaceStrings
    ["fill=\"#fff\"" "fill=\"url(#codex-gradient)\""]
    ["fill=\"none\"" "fill=\"${config.lib.stylix.colors.withHashtag.base05}\""]
    (builtins.readFile ./assets/codex.svg)
  );
  codexIconAccent = pkgs.writeText "codex-accent.svg" (
    builtins.replaceStrings
    ["fill=\"#fff\"" "fill=\"url(#codex-gradient)\""]
    ["fill=\"none\"" "fill=\"${config.lib.stylix.colors.withHashtag.base0D}\""]
    (builtins.readFile ./assets/codex.svg)
  );
  quickshellAssets = pkgs.linkFarm "quickshell-assets" [
    {
      name = "codex.svg";
      path = codexIcon;
    }
    {
      name = "codex-accent.svg";
      path = codexIconAccent;
    }
  ];
  quickshellConfig = pkgs.linkFarm "quickshell-config" [
    {
      name = "shell.qml";
      path = shellConfig;
    }
    {
      name = "Theme.qml";
      path = themeConfig;
    }
    {
      name = "BarWorkspaceList.qml";
      path = ./BarWorkspaceList.qml;
    }
    {
      name = "ClipboardWidget.qml";
      path = ./ClipboardWidget.qml;
    }
    {
      name = "CodexUsageWindow.qml";
      path = ./CodexUsageWindow.qml;
    }
    {
      name = "KeybindHelpWindow.qml";
      path = ./KeybindHelpWindow.qml;
    }
    {
      name = "LauncherWindow.qml";
      path = ./LauncherWindow.qml;
    }
    {
      name = "MediaWidget.qml";
      path = mediaWidgetConfig;
    }
    {
      name = "NotificationCenter.qml";
      path = ./NotificationCenter.qml;
    }
    {
      name = "PowerMenuWindow.qml";
      path = ./PowerMenuWindow.qml;
    }
    {
      name = "ShutdownWidget.qml";
      path = ./ShutdownWidget.qml;
    }
    {
      name = "ToolsWidget.qml";
      path = ./ToolsWidget.qml;
    }
    {
      name = "TrayWidget.qml";
      path = ./TrayWidget.qml;
    }
    {
      name = "WeatherWidget.qml";
      path = ./WeatherWidget.qml;
    }
    {
      name = "assets";
      path = quickshellAssets;
    }
    {
      name = "qmldir";
      path = qmldirConfig;
    }
  ];
in {
  home.packages = with pkgs; [
    quickshell
    quickshellIpc
    spotifyLauncher
  ];

  xdg.desktopEntries.spotify = {
    name = "Spotify";
    genericName = "Music Player";
    comment = "Listen to music and podcasts";
    exec = "${spotifyLauncher}/bin/spotify %U";
    icon = "spotify-client";
    terminal = false;
    type = "Application";
    categories = ["Audio" "Music" "Player" "AudioVideo"];
    mimeType = ["x-scheme-handler/spotify"];
    settings.StartupWMClass = "spotify";
  };

  xdg.configFile = {
    "quickshell/shell.qml".source = shellConfig;
    "quickshell/Theme.qml".source = themeConfig;
    "quickshell/BarWorkspaceList.qml".source = ./BarWorkspaceList.qml;
    "quickshell/ClipboardWidget.qml".source = ./ClipboardWidget.qml;
    "quickshell/CodexUsageWindow.qml".source = ./CodexUsageWindow.qml;
    "quickshell/KeybindHelpWindow.qml".source = ./KeybindHelpWindow.qml;
    "quickshell/LauncherWindow.qml".source = ./LauncherWindow.qml;
    "quickshell/MediaWidget.qml".source = mediaWidgetConfig;
    "quickshell/NotificationCenter.qml".source = ./NotificationCenter.qml;
    "quickshell/PowerMenuWindow.qml".source = ./PowerMenuWindow.qml;
    "quickshell/ShutdownWidget.qml".source = ./ShutdownWidget.qml;
    "quickshell/ToolsWidget.qml".source = ./ToolsWidget.qml;
    "quickshell/TrayWidget.qml".source = ./TrayWidget.qml;
    "quickshell/WeatherWidget.qml".source = ./WeatherWidget.qml;
    "quickshell/assets".source = quickshellAssets;
    "quickshell/qmldir".source = qmldirConfig;
  };

  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell desktop shell";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${pkgs.quickshell}/bin/qs -p ${quickshellConfig}";
      Restart = "on-failure";
      RestartSec = 2;
      Environment = ["QS_NO_RELOAD_POPUP=1"];
    };
    Install.WantedBy = ["graphical-session.target"];
  };
}
