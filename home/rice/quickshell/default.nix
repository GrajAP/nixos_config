{
  config,
  pkgs,
  ...
}: let
  weatherQuery = pkgs.writeShellApplication {
    name = "quickshell-weather-query";
    runtimeInputs = with pkgs; [python3];
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      python3 - <<'PY'
      import json
      from urllib.parse import urlencode
      from urllib.request import urlopen

      def describe(code: int) -> str:
          if code == 0:
              return "Clear sky"
          if code in (1, 2, 3):
              return "Cloudy"
          if code in (45, 48):
              return "Fog"
          if code in (51, 53, 55, 56, 57):
              return "Drizzle"
          if code in (61, 63, 65, 66, 67):
              return "Rain"
          if code in (71, 73, 75, 77):
              return "Snow"
          if code in (80, 81, 82):
              return "Showers"
          if code in (95, 96, 99):
              return "Thunderstorm"
          return "Unknown"

      params = {
          "latitude": "52",
          "longitude": "21",
          "timezone": "Europe/Warsaw",
          "current": "temperature_2m,apparent_temperature,weather_code,wind_speed_10m,is_day",
          "daily": "weather_code,temperature_2m_max,temperature_2m_min",
          "forecast_days": "2",
          "temperature_unit": "celsius",
          "wind_speed_unit": "kmh",
      }

      url = "https://api.open-meteo.com/v1/forecast?" + urlencode(params)
      with urlopen(url, timeout=5) as response:
          payload = json.load(response)

      current = payload.get("current", {})
      daily = payload.get("daily", {})
      code = int(current.get("weather_code", 0))
      output = {
          "temperature": current.get("temperature_2m"),
          "apparentTemperature": current.get("apparent_temperature"),
          "windSpeed": current.get("wind_speed_10m"),
          "isDay": current.get("is_day") == 1,
          "weatherCode": code,
          "description": describe(code),
          "todayMax": daily.get("temperature_2m_max", [None])[0],
          "todayMin": daily.get("temperature_2m_min", [None])[0],
      }
      print(json.dumps(output))
      PY
    '';
  };
  calendarQuery = pkgs.writeShellApplication {
    name = "quickshell-calendar-query";
    runtimeInputs = with pkgs; [python3];
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      python3 - <<'PY'
      import json
      import os
      from datetime import date
      from pathlib import Path

      events_folder = Path("/home/grajpap/other/Obsidian Vault/obsidian/Events")

      def parse_frontmatter(path: Path):
          try:
              text = path.read_text(encoding="utf-8")
          except OSError:
              return None

          lines = text.splitlines()
          if not lines or lines[0].strip() != "---":
              return None

          frontmatter = {}
          for line in lines[1:]:
              stripped = line.strip()
              if stripped == "---":
                  break
              if ":" not in line:
                  continue
              key, value = line.split(":", 1)
              frontmatter[key.strip()] = value.strip()

          event_date = frontmatter.get("date")
          title = frontmatter.get("title")
          if not event_date or not title:
              return None

          return {
              "date": event_date,
              "title": title,
              "allDay": frontmatter.get("allDay", "true") != "false",
              "startTime": frontmatter.get("startTime"),
              "endTime": frontmatter.get("endTime"),
              "birthday": frontmatter.get("birthday", "false") == "true",
              "path": str(path),
          }

      events = []
      if events_folder.exists():
          for entry in sorted(events_folder.glob("*.md")):
              parsed = parse_frontmatter(entry)
              if parsed:
                  events.append(parsed)

      print(json.dumps({"today": date.today().isoformat(), "events": events}))
      PY
    '';
  };
in {
  home.packages = with pkgs; [
    quickshell
    networkmanagerapplet
  ];

  xdg.configFile."quickshell/shell.qml".source = pkgs.replaceVars ./shell.qml {
    weatherQuery = "${weatherQuery}/bin/quickshell-weather-query";
    calendarQuery = "${calendarQuery}/bin/quickshell-calendar-query";
  };
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
