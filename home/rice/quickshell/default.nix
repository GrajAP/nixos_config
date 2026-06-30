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
      from datetime import datetime
      from urllib.parse import urlencode
      from urllib.error import HTTPError, URLError
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

      def safe_int(value):
          try:
              return int(value)
          except (TypeError, ValueError):
              return 0

      params = {
          "latitude": "52",
          "longitude": "21",
          "timezone": "Europe/Warsaw",
          "current": "temperature_2m,apparent_temperature,weather_code,wind_speed_10m,is_day",
          "daily": "weather_code,temperature_2m_max,temperature_2m_min",
          "hourly": "temperature_2m,weather_code,wind_speed_10m",
          "forecast_days": "7",
          "temperature_unit": "celsius",
          "wind_speed_unit": "kmh",
      }

      url = "https://api.open-meteo.com/v1/forecast?" + urlencode(params)
      try:
          with urlopen(url, timeout=5) as response:
              payload = json.load(response)
      except HTTPError as error:
          try:
              details = json.load(error)
              reason = details.get("reason") or details.get("error") or str(error)
          except Exception:
              reason = str(error)
          print(json.dumps({"error": True, "description": "Weather unavailable", "message": str(reason)}))
          raise SystemExit(0)
      except (OSError, URLError) as error:
          print(json.dumps({"error": True, "description": "Weather unavailable", "message": str(error)}))
          raise SystemExit(0)

      current = payload.get("current", {})
      daily = payload.get("daily", {})
      hourly = payload.get("hourly", {})

      daily_time = daily.get("time", [])
      daily_weather = daily.get("weather_code", [])
      daily_max = daily.get("temperature_2m_max", [])
      daily_min = daily.get("temperature_2m_min", [])
      daily_forecast = []
      for index in range(min(len(daily_time), 7)):
          daily_forecast.append({
              "date": daily_time[index],
              "weatherCode": safe_int(daily_weather[index]) if index < len(daily_weather) else 0,
              "minTemperature": daily_min[index] if index < len(daily_min) else None,
              "maxTemperature": daily_max[index] if index < len(daily_max) else None,
          })

      hourly_time = hourly.get("time", [])
      hourly_weather = hourly.get("weather_code", [])
      hourly_temperature = hourly.get("temperature_2m", [])
      hourly_wind_speed = hourly.get("wind_speed_10m", [])
      now = datetime.now()
      hourly_forecast = []
      start_index = 0
      for index, label in enumerate(hourly_time):
          try:
              if datetime.fromisoformat(label) >= now:
                  start_index = index
                  break
          except (TypeError, ValueError):
              continue
      end_index = min(start_index + 24, len(hourly_time))
      for index in range(start_index, end_index):
          hourly_forecast.append({
              "time": hourly_time[index],
              "temperature": hourly_temperature[index] if index < len(hourly_temperature) else None,
              "weatherCode": safe_int(hourly_weather[index]) if index < len(hourly_weather) else 0,
              "windSpeed": hourly_wind_speed[index] if index < len(hourly_wind_speed) else None,
          })

      code = int(current.get("weather_code", 0))
      output = {
          "temperature": current.get("temperature_2m"),
          "apparentTemperature": current.get("apparent_temperature"),
          "windSpeed": current.get("wind_speed_10m"),
          "isDay": current.get("is_day") == 1,
          "weatherCode": code,
          "description": describe(code),
          "todayMax": daily_max[0] if len(daily_max) > 0 else None,
          "todayMin": daily_min[0] if len(daily_min) > 0 else None,
          "dailyForecast": daily_forecast,
          "hourlyForecast": hourly_forecast,
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
      from datetime import date
      from os import environ
      from pathlib import Path

      events_folder = Path("/home/grajpap/other/Obsidian Vault/obsidian/Events")
      state_home = Path(environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
      tasks_file = state_home / "quickshell" / "calendar-tasks.json"

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

      try:
          tasks = json.loads(tasks_file.read_text(encoding="utf-8"))
      except (OSError, json.JSONDecodeError):
          tasks = []

      for task in tasks:
          task_date = str(task.get("date", ""))
          title = str(task.get("title", "")).strip()
          if not task_date or not title:
              continue
          events.append({
              "date": task_date,
              "title": title,
              "allDay": True,
              "startTime": None,
              "endTime": None,
              "birthday": False,
              "task": True,
              "path": str(tasks_file),
          })

      print(json.dumps({"today": date.today().isoformat(), "events": events}))
      PY
    '';
  };
  calendarTask = pkgs.writeShellApplication {
    name = "quickshell-calendar-task";
    runtimeInputs = with pkgs; [python3];
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      action="''${1:-}"
      task_date="''${2:-}"
      task_title="''${3:-}"

      if [[ "$action" != "add" || -z "$task_date" || -z "$task_title" ]]; then
        echo "Usage: quickshell-calendar-task add YYYY-MM-DD title" >&2
        exit 2
      fi

      TASK_DATE="$task_date" TASK_TITLE="$task_title" python3 - <<'PY'
      import json
      import os
      import re
      import time
      from pathlib import Path

      task_date = os.environ["TASK_DATE"]
      title = os.environ["TASK_TITLE"].strip()
      if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", task_date) or not title:
          raise SystemExit(2)

      state_home = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
      tasks_file = state_home / "quickshell" / "calendar-tasks.json"
      tasks_file.parent.mkdir(parents=True, exist_ok=True)

      try:
          tasks = json.loads(tasks_file.read_text(encoding="utf-8"))
      except (OSError, json.JSONDecodeError):
          tasks = []

      tasks.append({
          "id": f"{int(time.time() * 1000)}",
          "date": task_date,
          "title": title,
      })
      tasks.sort(key=lambda task: (task.get("date", ""), task.get("title", "")))
      tasks_file.write_text(json.dumps(tasks, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
      print(json.dumps({"ok": True, "path": str(tasks_file)}))
      PY
    '';
  };
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
    text = ''
      set -euo pipefail

      mode="''${1:-edit}"
      target="''${2:-}"
      mkdir -p "$HOME/pics"
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/quickshell-tools"
      mkdir -p "$state_dir"
      log_file="$state_dir/screenshot.log"
      {
        echo "--- $(date --iso-8601=seconds) mode=$mode ---"
        echo "WAYLAND_DISPLAY=''${WAYLAND_DISPLAY:-}"
        echo "XDG_CURRENT_DESKTOP=''${XDG_CURRENT_DESKTOP:-}"
      } >> "$log_file"

      kill_stale_captures() {
        local stale=()
        local pid ppid args parent_args
        while read -r pid ppid args; do
          [[ -n "''${pid:-}" ]] || continue
          [[ "$pid" == "$$" ]] && continue

          if [[ "$args" == *"quickshell-screenshot edit"* || "$args" == *"quickshell-screenshot copy"* || "$args" == *"quickshell-screenshot save"* ]]; then
            stale+=("$pid")
            continue
          fi

          if [[ "$args" == slurp* ]]; then
            parent_args="$(ps -o args= -p "$ppid" 2>/dev/null || true)"
            if [[ "$parent_args" == *"quickshell-screenshot"* ]]; then
              stale+=("$pid")
            fi
          fi
        done < <(ps -u "$(id -u)" -o pid= -o ppid= -o args=)

        if ((''${#stale[@]} > 0)); then
          echo "killing stale screenshot process(es): ''${stale[*]}" >> "$log_file"
          kill "''${stale[@]}" 2>/dev/null || true
          sleep 0.1
          kill -KILL "''${stale[@]}" 2>/dev/null || true
        fi
      }

      slurp_pid=""
      slurp_output=""
      cleanup_selector() {
        if [[ -n "$slurp_pid" ]]; then
          kill "$slurp_pid" 2>/dev/null || true
        fi
        if [[ -n "$slurp_output" ]]; then
          rm -f "$slurp_output"
        fi
      }
      trap cleanup_selector EXIT INT TERM

      copy_file() {
        local file="$1"
        [[ -f "$file" ]] || { echo "missing file: $file" >> "$log_file"; exit 2; }
        wl-copy -t image/png < "$file" 2>> "$log_file"
        notify-send "Screenshot" "Copied to clipboard"
      }

      save_file() {
        local source="$1"
        [[ -f "$source" ]] || { echo "missing file: $source" >> "$log_file"; exit 2; }
        local file
        file="$HOME/pics/screenshot-$(date +'%F-%H%M%S').png"
        cp "$source" "$file"
        wl-copy -t image/png < "$file" 2>> "$log_file"
        notify-send "Screenshot" "Saved and copied: $(basename "$file")"
        printf '%s\n' "$file"
      }

      render_edited() {
        local source="$1"
        local strokes="''${2:-[]}"
        local output="$state_dir/latest-screenshot-edited.png"
        [[ -f "$source" ]] || { echo "missing file: $source" >> "$log_file"; exit 2; }
        SOURCE="$source" STROKES="$strokes" OUTPUT="$output" python3 - <<'PY' 2>> "$log_file"
      import json
      import os
      from PIL import Image, ImageDraw

      source = os.environ["SOURCE"]
      output = os.environ["OUTPUT"]
      try:
          strokes = json.loads(os.environ.get("STROKES", "[]"))
      except json.JSONDecodeError:
          strokes = []

      image = Image.open(source).convert("RGBA")
      draw = ImageDraw.Draw(image)
      for stroke in strokes:
          points = stroke.get("points", [])
          if len(points) < 1:
              continue
          color = stroke.get("color", "#ff4d6d")
          width = max(1, int(round(float(stroke.get("width", 4)))))
          xy = [(float(point.get("x", 0)), float(point.get("y", 0))) for point in points]
          if len(xy) == 1:
              x, y = xy[0]
              radius = width / 2
              draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)
          else:
              draw.line(xy, fill=color, width=width, joint="curve")
              radius = width / 2
              for x, y in (xy[0], xy[-1]):
                  draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)
      image.save(output)
      print(output)
      PY
      }

      case "$mode" in
        copy-file)
          copy_file "$target"
          exit 0
          ;;
        save-file)
          save_file "$target"
          exit 0
          ;;
        copy-edited)
          edited="$(render_edited "$target" "''${3:-[]}")"
          copy_file "$edited"
          printf '%s\n' "$edited"
          exit 0
          ;;
        save-edited)
          edited="$(render_edited "$target" "''${3:-[]}")"
          save_file "$edited"
          exit 0
          ;;
      esac

      kill_stale_captures
      sleep 0.15
      slurp_output="$state_dir/slurp-$$.out"
      : > "$slurp_output"
      slurp -b 00000066 -c 7aa2f7ff -s 7aa2f733 > "$slurp_output" 2>> "$log_file" &
      slurp_pid="$!"
      set +e
      wait "$slurp_pid"
      status="$?"
      set -e
      slurp_pid=""
      if [[ "$status" -ne 0 ]]; then
        echo "slurp failed: $status" >> "$log_file"
        exit "$status"
      fi
      geometry="$(< "$slurp_output")"
      rm -f "$slurp_output"
      slurp_output=""
      [[ -n "$geometry" ]] || exit 130
      echo "geometry=$geometry" >> "$log_file"

      tmp="$state_dir/latest-screenshot.png"

      case "$mode" in
        edit)
          grim -g "$geometry" "$tmp" 2>> "$log_file"
          printf '%s\n' "$tmp"
          ;;
        copy)
          grim -g "$geometry" "$tmp" 2>> "$log_file"
          copy_file "$tmp"
          ;;
        save)
          grim -g "$geometry" "$tmp" 2>> "$log_file"
          save_file "$tmp"
          ;;
        *)
          echo "Usage: quickshell-screenshot [edit|copy|save|copy-file|save-file|copy-edited|save-edited]" >&2
          exit 2
          ;;
      esac
    '';
  };
  voiceTool = pkgs.writeShellApplication {
    name = "quickshell-voice";
    runtimeInputs = with pkgs; [
      coreutils
      libnotify
    ];
    text = ''
      set -euo pipefail

      action="''${1:-toggle}"
      export PATH="/etc/profiles/per-user/grajpap/bin:$HOME/.nix-profile/bin:$PATH"
      if ! command -v whisper-record-v2 >/dev/null 2>&1; then
        notify-send "Voice to text" "whisper-record-v2 is not available in PATH"
        exit 127
      fi

      exec whisper-record-v2 "$action"
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
    text = ''
      set -euo pipefail

      pid="$(systemctl --user show --property MainPID --value quickshell.service 2>/dev/null || true)"
      if [[ -z "$pid" || "$pid" == "0" ]]; then
        pid="$(pgrep -u "$(id -u)" -x qs | head -n1 || true)"
      fi
      if [[ -z "$pid" ]]; then
        echo "quickshell-ipc: quickshell.service is not running" >&2
        exit 1
      fi

      exec qs ipc --pid "$pid" call "$@"
    '';
  };
  shellConfig = pkgs.replaceVars ./shell.qml {
    weatherQuery = "${weatherQuery}/bin/quickshell-weather-query";
    calendarQuery = "${calendarQuery}/bin/quickshell-calendar-query";
    calendarTask = "${calendarTask}/bin/quickshell-calendar-task";
    screenshotTool = "${screenshotTool}/bin/quickshell-screenshot";
    voiceTool = "${voiceTool}/bin/quickshell-voice";
  };
  themeConfig = pkgs.writeText "Theme.qml" ''
    pragma Singleton
    import QtQuick

    QtObject {
      readonly property color background: "${config.lib.stylix.colors.withHashtag.base00}"
      readonly property color surface: "${config.lib.stylix.colors.withHashtag.base02}"
      readonly property color surfaceAlt: "${config.lib.stylix.colors.withHashtag.base01}"
      readonly property color border: "${config.lib.stylix.colors.withHashtag.base03}"
      readonly property color text: "${config.lib.stylix.colors.withHashtag.base05}"
      readonly property color muted: "${config.lib.stylix.colors.withHashtag.base04}"
      readonly property color accent: "${config.lib.stylix.colors.withHashtag.base0D}"
      readonly property color danger: "${config.lib.stylix.colors.withHashtag.base08}"
      readonly property string font: "JetBrainsMono Nerd Font"
    }
  '';
  qmldirConfig = pkgs.writeText "qmldir" ''
    singleton Theme 1.0 Theme.qml
  '';
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
      name = "qmldir";
      path = qmldirConfig;
    }
  ];
in {
  home.packages = with pkgs; [
    quickshell
    quickshellIpc
    networkmanagerapplet
  ];

  xdg.configFile."quickshell/shell.qml".source = shellConfig;
  xdg.configFile."quickshell/Theme.qml".source = themeConfig;
  xdg.configFile."quickshell/qmldir".source = qmldirConfig;

  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell desktop shell";
      After = ["hyprland-session.target"];
      PartOf = ["hyprland-session.target"];
    };
    Service = {
      ExecStart = "${pkgs.quickshell}/bin/qs -p ${quickshellConfig}";
      Restart = "on-failure";
      RestartSec = 2;
      Environment = ["QS_NO_RELOAD_POPUP=1"];
    };
    Install.WantedBy = ["hyprland-session.target"];
  };
}
