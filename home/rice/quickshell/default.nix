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
    text = ''
            #!/usr/bin/env bash
            set -euo pipefail

            python3 - <<'PY'
      if True:
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
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      sessions_root="$HOME/.codex/sessions"
      if [[ ! -d "$sessions_root" ]]; then
        echo '{"ok":false,"error":"No Codex session directory found"}'
        exit 0
      fi

      if ! find "$sessions_root" -type f -name "*.jsonl" -print -quit | grep -q .; then
        echo '{"ok":false,"error":"No Codex session files found"}'
        exit 0
      fi

      general_entry=""
      spark_entry=""
      while IFS= read -r session_file; do
        [[ -z "$session_file" ]] && continue
        while IFS= read -r latest_line; do
          [[ -z "$latest_line" ]] && continue

          if parsed="$(printf '%s\n' "$latest_line" | jq -e -c '
            .payload.rate_limits as $limits
            | select(($limits | type) == "object")
            | {
                limitId: ($limits.limit_id // null),
                limitName: ($limits.limit_name // null),
                primaryUsedPercent: ($limits.primary.used_percent // null),
                primaryWindowMinutes: ($limits.primary.window_minutes // null),
                primaryResetsAt: ($limits.primary.resets_at // null),
                secondaryUsedPercent: ($limits.secondary.used_percent // null),
                secondaryWindowMinutes: ($limits.secondary.window_minutes // null),
                secondaryResetsAt: ($limits.secondary.resets_at // null),
                planType: ($limits.plan_type // null)
              }' 2>/dev/null)"; then
            limit_id="$(printf '%s\n' "$parsed" | jq -r '.limitId // ""')"
            limit_name="$(printf '%s\n' "$parsed" | jq -r '.limitName // ""')"
            if [[ -z "$spark_entry" && ( "$limit_id" == "codex_bengalfox" || "$limit_name" == *"Spark"* ) ]]; then
              spark_entry="$parsed"
            elif [[ -z "$general_entry" && "$limit_id" == "codex" ]]; then
              general_entry="$parsed"
            fi
          fi

          if [[ -n "$general_entry" && -n "$spark_entry" ]]; then
            break 2
          fi
        done < <(tail -n 2000 "$session_file" | tac | rg -F '"rate_limits"' || true)
      done < <(find "$sessions_root" -type f -name "*.jsonl" -printf '%T@ %p\n' | sort -nr | awk '{print $2}' | head -n 8)

      if [[ -z "$general_entry" && -z "$spark_entry" ]]; then
        echo '{"ok":false,"error":"No session entry with rate limits"}'
        exit 0
      fi

      jq -n -c \
        --argjson general "''${general_entry:-null}" \
        --argjson spark "''${spark_entry:-null}" '
          def flatten($prefix; $item):
            if $item == null then {}
            else {
              ($prefix + "LimitId"): ($item.limitId // null),
              ($prefix + "LimitName"): ($item.limitName // null),
              ($prefix + "PrimaryUsedPercent"): ($item.primaryUsedPercent // null),
              ($prefix + "PrimaryWindowMinutes"): ($item.primaryWindowMinutes // null),
              ($prefix + "PrimaryResetsAt"): ($item.primaryResetsAt // null),
              ($prefix + "SecondaryUsedPercent"): ($item.secondaryUsedPercent // null),
              ($prefix + "SecondaryWindowMinutes"): ($item.secondaryWindowMinutes // null),
              ($prefix + "SecondaryResetsAt"): ($item.secondaryResetsAt // null)
            }
            end;
          {
            ok: true,
            planType: (($general.planType // $spark.planType) // null),
            generatedAt: (now | floor)
          }
          + flatten("codex"; $general)
          + flatten("spark"; $spark)'
    '';
  };
  calendarTool = pkgs.writeShellApplication {
    name = "quickshell-calendar";
    runtimeInputs = with pkgs; [
      calendarPython
      xdg-utils
    ];
    text = ''
            #!/usr/bin/env bash
            set -euo pipefail

            python3 - "$@" <<'PY'
      if True:
            import base64
            import hashlib
            import json
            import re
            import subprocess
            import sys
            import uuid
            from datetime import date, datetime, time, timedelta, timezone
            from os import environ
            from pathlib import Path
            from urllib.error import HTTPError, URLError
            from urllib.parse import quote, urljoin
            from urllib.request import Request, urlopen
            from xml.etree import ElementTree as ET

            from icalendar import Calendar
            import recurring_ical_events

            USER = "grajpap"
            BASE_URL = "http://127.0.0.1:18080"
            CALENDAR_HOME = f"/remote.php/dav/calendars/{USER}/"
            PASSWORD_FILE = Path.home() / ".config/quickshell/nextcloud-app-password"
            UNDO_FILE = Path.home() / ".cache/quickshell/calendar-undo.json"
            EVENTS_FOLDER = Path("/home/grajpap/other/Obsidian Vault/obsidian/Events")
            RANGE_START = date.today() - timedelta(days=60)
            RANGE_END = date.today() + timedelta(days=366)
            NS = {
                "d": "DAV:",
                "cal": "urn:ietf:params:xml:ns:caldav",
            }

            def password():
                try:
                    return PASSWORD_FILE.read_text(encoding="utf-8").strip()
                except OSError as error:
                    raise RuntimeError(f"Nextcloud bar token missing at {PASSWORD_FILE}") from error

            def request(method, path, body=None, headers=None, ok=(200, 201, 204, 207)):
                url = path if path.startswith("http") else urljoin(BASE_URL, path)
                data = body.encode("utf-8") if isinstance(body, str) else body
                auth = base64.b64encode(f"{USER}:{password()}".encode("utf-8")).decode("ascii")
                request_headers = {
                    "Authorization": f"Basic {auth}",
                    "User-Agent": "quickshell-nextcloud-calendar",
                }
                if body is not None:
                    request_headers["Content-Type"] = "application/xml; charset=utf-8"
                if headers:
                    request_headers.update(headers)
                req = Request(url, data=data, headers=request_headers, method=method)
                try:
                    with urlopen(req, timeout=10) as response:
                        payload = response.read()
                        if response.status not in ok:
                            raise RuntimeError(f"{method} {url} returned HTTP {response.status}")
                        return payload
                except HTTPError as error:
                    details = error.read().decode("utf-8", errors="replace")
                    raise RuntimeError(f"{method} {url} returned HTTP {error.code}: {details[:240]}") from error
                except URLError as error:
                    raise RuntimeError(f"{method} {url} failed: {error.reason}") from error

            def request_json(method, path, payload=None, ok=(200, 201, 204)):
                body = json.dumps(payload) if payload is not None else None
                headers = {
                    "Accept": "application/json",
                    "Content-Type": "application/json; charset=utf-8",
                }
                response = request(method, path, body, headers, ok=ok)
                if not response:
                    return None
                return json.loads(response.decode("utf-8"))

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
                    "source": "Obsidian",
                }

            def obsidian_event_id(path):
                return hashlib.sha1(str(path).encode("utf-8")).hexdigest()

            def obsidian_uid(path):
                return f"obsidian-{obsidian_event_id(path)}@quickshell"

            def all_obsidian_events():
                events = []
                if not EVENTS_FOLDER.exists():
                    return events
                for entry in sorted(EVENTS_FOLDER.glob("*.md")):
                    parsed = parse_frontmatter(entry)
                    if parsed:
                        events.append(parsed)
                return events

            def obsidian_events():
                return [
                    event for event in all_obsidian_events()
                    if RANGE_START.isoformat() <= event["date"] <= RANGE_END.isoformat()
                ]

            def note_date(note):
                content = note.get("content") or ""
                match = re.search(r"(?m)^date:\\s*(\\d{4}-\\d{2}-\\d{2})\\s*$", content)
                if match:
                    return match.group(1)
                modified = note.get("modified")
                if isinstance(modified, int):
                    return datetime.fromtimestamp(modified).date().isoformat()
                return date.today().isoformat()

            def nextcloud_notes():
                notes = request_json("GET", "/index.php/apps/notes/api/v1/notes", ok=(200,))
                events = []
                for note in notes or []:
                    item_date = note_date(note)
                    if item_date < RANGE_START.isoformat() or item_date > RANGE_END.isoformat():
                        continue
                    title = note.get("title") or "Untitled note"
                    category = note.get("category") or "Notes"
                    events.append({
                        "date": item_date,
                        "title": title,
                        "allDay": True,
                        "startTime": None,
                        "endTime": None,
                        "birthday": False,
                        "task": False,
                        "note": True,
                        "noteId": note.get("id"),
                        "source": f"Notes/{category}",
                    })
                return events

            def text_of(parent, path):
                element = parent.find(path, NS)
                return element.text if element is not None and element.text is not None else ""

            def discover_calendars():
                body = """<?xml version="1.0" encoding="utf-8" ?>
            <d:propfind xmlns:d="DAV:" xmlns:cal="urn:ietf:params:xml:ns:caldav">
              <d:prop>
                <d:displayname />
                <d:resourcetype />
                <cal:supported-calendar-component-set />
              </d:prop>
            </d:propfind>"""
                root = ET.fromstring(request("PROPFIND", CALENDAR_HOME, body, {"Depth": "1"}))
                calendars = []
                for response in root.findall("d:response", NS):
                    href = text_of(response, "d:href")
                    prop = response.find("d:propstat/d:prop", NS)
                    if not href or prop is None:
                        continue
                    if prop.find("d:resourcetype/cal:calendar", NS) is None:
                        continue
                    comps = {
                        comp.attrib.get("name", "").upper()
                        for comp in prop.findall("cal:supported-calendar-component-set/cal:comp", NS)
                    }
                    name = text_of(prop, "d:displayname") or href.rstrip("/").split("/")[-1]
                    calendars.append({
                        "href": href if href.endswith("/") else f"{href}/",
                        "displayName": name,
                        "components": comps,
                    })
                return calendars

            def calendar_report(collection, component, time_range=True):
                range_xml = ""
                if time_range:
                    start = datetime.combine(RANGE_START, time.min, timezone.utc).strftime("%Y%m%dT%H%M%SZ")
                    end = datetime.combine(RANGE_END, time.min, timezone.utc).strftime("%Y%m%dT%H%M%SZ")
                    range_xml = f'<cal:time-range start="{start}" end="{end}" />'
                body = f"""<?xml version="1.0" encoding="utf-8" ?>
            <cal:calendar-query xmlns:d="DAV:" xmlns:cal="urn:ietf:params:xml:ns:caldav">
              <d:prop>
                <d:getetag />
                <cal:calendar-data />
              </d:prop>
              <cal:filter>
                <cal:comp-filter name="VCALENDAR">
                  <cal:comp-filter name="{component}">
                    {range_xml}
                  </cal:comp-filter>
                </cal:comp-filter>
              </cal:filter>
            </cal:calendar-query>"""
                root = ET.fromstring(request("REPORT", collection["href"], body, {"Depth": "1"}))
                items = []
                for response in root.findall("d:response", NS):
                    href = text_of(response, "d:href")
                    etag = text_of(response, "d:propstat/d:prop/d:getetag")
                    data = text_of(response, "d:propstat/d:prop/cal:calendar-data")
                    if href and data.strip():
                        items.append({
                            "href": href,
                            "etag": etag,
                            "data": data,
                        })
                return items

            def date_value(value):
                if isinstance(value, datetime):
                    return value.date().isoformat()
                if isinstance(value, date):
                    return value.isoformat()
                return None

            def time_value(value):
                if isinstance(value, datetime):
                    return value.astimezone().strftime("%H:%M") if value.tzinfo else value.strftime("%H:%M")
                return None

            def parse_event(component, source, href=None):
                start_prop = component.get("DTSTART")
                if start_prop is None:
                    return None
                start = start_prop.dt
                if not date_value(start):
                    return None
                end_prop = component.get("DTEND")
                end = end_prop.dt if end_prop is not None else None
                return {
                    "date": date_value(start),
                    "title": str(component.get("SUMMARY", "Untitled event")),
                    "allDay": not isinstance(start, datetime),
                    "startTime": time_value(start),
                    "endTime": time_value(end) if end is not None else None,
                    "birthday": False,
                    "task": False,
                    "note": False,
                    "href": href,
                    "uid": str(component.get("UID", "")),
                    "obsidianPath": str(component.get("X-QUICKSHELL-OBSIDIAN-PATH", "")),
                    "source": source,
                }

            def parse_todo(component, source, href=None, etag=None):
                status = str(component.get("STATUS", "")).upper()
                if status == "CANCELLED":
                    return None
                due_prop = component.get("DUE") or component.get("DTSTART") or component.get("CREATED")
                due = due_prop.dt if due_prop is not None else date.today()
                item_date = date_value(due) or date.today().isoformat()
                completed = status == "COMPLETED" or str(component.get("PERCENT-COMPLETE", "")) == "100"
                return {
                    "date": item_date,
                    "title": str(component.get("SUMMARY", "Untitled task")),
                    "allDay": True,
                    "startTime": None,
                    "endTime": None,
                    "birthday": False,
                    "task": True,
                    "completed": completed,
                    "note": False,
                    "href": href,
                    "etag": etag,
                    "source": source,
                }

            def nextcloud_events():
                events = []
                for collection in discover_calendars():
                    if "VEVENT" in collection["components"]:
                        for item in calendar_report(collection, "VEVENT"):
                            ics = item["data"]
                            calendar = Calendar.from_ical(ics)
                            try:
                                components = recurring_ical_events.of(calendar).between(
                                    datetime.combine(RANGE_START, time.min),
                                    datetime.combine(RANGE_END, time.min),
                                )
                            except Exception:
                                components = calendar.walk("VEVENT")
                            for component in components:
                                parsed = parse_event(component, collection["displayName"], item["href"])
                                if parsed:
                                    events.append(parsed)
                    if "VTODO" in collection["components"]:
                        for item in calendar_report(collection, "VTODO", time_range=False):
                            ics = item["data"]
                            calendar = Calendar.from_ical(ics)
                            for component in calendar.walk("VTODO"):
                                parsed = parse_todo(component, collection["displayName"], item["href"], item["etag"])
                                if parsed:
                                    events.append(parsed)
                return events

            def escape_ics(value):
                return (
                    value.replace("\\", "\\\\")
                    .replace("\n", "\\n")
                    .replace(";", "\\;")
                    .replace(",", "\\,")
                )

            def compact_date(value):
                try:
                    return date.fromisoformat(value).strftime("%Y%m%d")
                except ValueError as error:
                    raise RuntimeError("Expected date as YYYY-MM-DD") from error

            def parse_clock(value):
                if not value:
                    return None
                if not re.fullmatch(r"[0-2][0-9]:[0-5][0-9]", value):
                    raise RuntimeError("Expected time as HH:MM")
                hour, minute = [int(part) for part in value.split(":", 1)]
                if hour > 23:
                    raise RuntimeError("Expected time as HH:MM")
                return hour, minute

            def maybe_clock(value):
                try:
                    return parse_clock(value)
                except RuntimeError:
                    return None

            def is_tasks_calendar(item):
                if "VTODO" not in item["components"]:
                    return False
                uri = item["href"].rstrip("/").split("/")[-1].lower()
                name = item["displayName"].strip().lower()
                return uri == "tasks" or name == "tasks" or "task" in uri or "task" in name

            def find_tasks_calendar(calendars):
                candidates = [item for item in calendars if is_tasks_calendar(item)]
                for item in candidates:
                    uri = item["href"].rstrip("/").split("/")[-1].lower()
                    if uri == "tasks":
                        return item
                for item in candidates:
                    if item["displayName"].strip().lower() == "tasks":
                        return item
                return candidates[0] if candidates else None

            def choose_calendar(component):
                calendars = discover_calendars()
                candidates = [item for item in calendars if component in item["components"]]
                if component == "VTODO":
                    tasks_calendar = find_tasks_calendar(candidates)
                    if tasks_calendar:
                        return tasks_calendar
                    return create_tasks_calendar()
                if component == "VEVENT":
                    for item in candidates:
                        uri = item["href"].rstrip("/").split("/")[-1]
                        if uri == "personal":
                            return item
                if candidates:
                    return candidates[0]
                raise RuntimeError(f"No writable {component} calendar found")

            def create_tasks_calendar():
                href = f"{CALENDAR_HOME}tasks/"
                body = """<?xml version="1.0" encoding="utf-8" ?>
            <cal:mkcalendar xmlns:d="DAV:" xmlns:cal="urn:ietf:params:xml:ns:caldav">
              <d:set>
                <d:prop>
                  <d:displayname>Tasks</d:displayname>
                  <cal:supported-calendar-component-set>
                    <cal:comp name="VTODO" />
                  </cal:supported-calendar-component-set>
                </d:prop>
              </d:set>
            </cal:mkcalendar>"""
                try:
                    request("MKCALENDAR", href, body, ok=(200, 201, 204))
                except RuntimeError as error:
                    if "HTTP 405" not in str(error) and "HTTP 409" not in str(error):
                        raise
                calendars = discover_calendars()
                tasks_calendar = find_tasks_calendar(calendars)
                if tasks_calendar:
                    return tasks_calendar
                calendars = [item for item in calendars if "VTODO" in item["components"]]
                if calendars:
                    return calendars[0]
                raise RuntimeError("Could not create Nextcloud Tasks calendar")

            def put_ics(collection, ics, object_name=None):
                object_name = quote(object_name or f"{uuid.uuid4()}.ics")
                path = f"{collection['href']}{object_name}"
                request("PUT", path, ics, {"Content-Type": "text/calendar; charset=utf-8"}, ok=(200, 201, 204))
                return path

            def event_ics(uid, event_date_value, title, start_clock=None, end_clock=None, extra_lines=None):
                event_date = compact_date(event_date_value)
                stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
                lines = [
                    "BEGIN:VCALENDAR",
                    "VERSION:2.0",
                    "PRODID:-//quickshell//nextcloud-calendar//EN",
                    "BEGIN:VEVENT",
                    f"UID:{uid}",
                    f"DTSTAMP:{stamp}",
                    f"SUMMARY:{escape_ics(title)}",
                ]
                if extra_lines:
                    lines.extend(extra_lines)
                if start_clock:
                    hour, minute = start_clock
                    start_dt = datetime.combine(date.fromisoformat(event_date_value), time(hour, minute))
                    if end_clock:
                        end_hour, end_minute = end_clock
                        end_dt = datetime.combine(date.fromisoformat(event_date_value), time(end_hour, end_minute))
                        if end_dt <= start_dt:
                            end_dt += timedelta(days=1)
                    else:
                        end_dt = start_dt + timedelta(hours=1)
                    lines.append(f"DTSTART;TZID=Europe/Warsaw:{start_dt.strftime('%Y%m%dT%H%M%S')}")
                    lines.append(f"DTEND;TZID=Europe/Warsaw:{end_dt.strftime('%Y%m%dT%H%M%S')}")
                else:
                    next_day = (date.fromisoformat(event_date_value) + timedelta(days=1)).strftime("%Y%m%d")
                    lines.append(f"DTSTART;VALUE=DATE:{event_date}")
                    lines.append(f"DTEND;VALUE=DATE:{next_day}")
                lines.extend(["END:VEVENT", "END:VCALENDAR", ""])
                return "\r\n".join(lines)

            def existing_event_identity(original_ics):
                uid = f"{uuid.uuid4()}@quickshell"
                preserved = []
                try:
                    calendar = Calendar.from_ical(original_ics)
                    component = next((item for item in calendar.walk("VEVENT")), None)
                except Exception:
                    component = None
                if component is None:
                    return uid, preserved
                uid = str(component.get("UID") or uid)
                for name in ("DESCRIPTION", "LOCATION", "URL", "CATEGORIES"):
                    value = component.get(name)
                    if value:
                        preserved.append(f"{name}:{escape_ics(str(value))}")
                return uid, preserved

            def save_undo(payload):
                UNDO_FILE.parent.mkdir(parents=True, exist_ok=True)
                UNDO_FILE.write_text(json.dumps(payload), encoding="utf-8")

            def clear_undo():
                try:
                    UNDO_FILE.unlink()
                except FileNotFoundError:
                    pass

            def writable_href(raw_href):
                href = raw_href.strip()
                if not href.startswith(CALENDAR_HOME):
                    raise RuntimeError("Refusing to update an item outside this user's calendar home")
                return href

            def unfold_ics(text):
                return re.sub(r"\r?\n[ \t]", "", text)

            def upsert_component_line(text, component, name, value):
                pattern = rf"(?ims)(BEGIN:{component}.*?)(?:\r?\n{re.escape(name)}(?:;[^:]*)?:.*?)(?=\r?\n)(.*?END:{component})"
                line = f"{name}:{value}"
                if re.search(pattern, text):
                    return re.sub(pattern, lambda match: f"{match.group(1)}\r\n{line}{match.group(2)}", text, count=1)
                return re.sub(rf"(?im)^END:{component}$", lambda _match: f"{line}\r\nEND:{component}", text, count=1)

            def remove_component_line(text, component, name):
                pattern = rf"(?ims)(BEGIN:{component}.*?)(?:\r?\n{re.escape(name)}(?:;[^:]*)?:.*?)(?=\r?\n)(.*?END:{component})"
                return re.sub(pattern, lambda match: f"{match.group(1)}{match.group(2)}", text, count=1)

            def replace_component_date_line(text, component, base_name, line_name, value):
                text = remove_component_line(text, component, base_name)
                return re.sub(rf"(?im)^END:{component}$", lambda _match: f"{line_name}:{value}\r\nEND:{component}", text, count=1)

            def update_stamp(text, component):
                stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
                return upsert_component_line(text, component, "DTSTAMP", stamp)

            def add_task(args):
                if len(args) < 2:
                    raise RuntimeError("Usage: quickshell-calendar add-task YYYY-MM-DD title")
                task_date = compact_date(args[0])
                title = " ".join(args[1:]).strip()
                if not title:
                    raise RuntimeError("Task title is empty")
                uid = f"{uuid.uuid4()}@quickshell"
                stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
                ics = "\r\n".join([
                    "BEGIN:VCALENDAR",
                    "VERSION:2.0",
                    "PRODID:-//quickshell//nextcloud-calendar//EN",
                    "BEGIN:VTODO",
                    f"UID:{uid}",
                    f"DTSTAMP:{stamp}",
                    f"CREATED:{stamp}",
                    f"LAST-MODIFIED:{stamp}",
                    f"SUMMARY:{escape_ics(title)}",
                    f"DUE;VALUE=DATE:{task_date}",
                    "STATUS:NEEDS-ACTION",
                    "PERCENT-COMPLETE:0",
                    "END:VTODO",
                    "END:VCALENDAR",
                    "",
                ])
                href = put_ics(choose_calendar("VTODO"), ics)
                save_undo({"mode": "created", "href": href})
                print(json.dumps({"ok": True, "type": "task", "undoable": True}))

            def add_event(args):
                if len(args) < 2:
                    raise RuntimeError("Usage: quickshell-calendar add-event YYYY-MM-DD title [HH:MM] [HH:MM]")
                event_date = compact_date(args[0])
                title_parts = args[1:]
                start_clock = None
                end_clock = None
                if len(title_parts) >= 2 and maybe_clock(title_parts[-1]) and maybe_clock(title_parts[-2]):
                    end_clock = parse_clock(title_parts.pop())
                    start_clock = parse_clock(title_parts.pop())
                elif len(title_parts) >= 2 and maybe_clock(title_parts[-1]):
                    start_clock = parse_clock(title_parts.pop())
                title = " ".join(title_parts).strip()
                if not title:
                    raise RuntimeError("Event title is empty")
                uid = f"{uuid.uuid4()}@quickshell"
                href = put_ics(choose_calendar("VEVENT"), event_ics(uid, args[0], title, start_clock, end_clock))
                save_undo({"mode": "created", "href": href})
                print(json.dumps({"ok": True, "type": "event", "undoable": True}))

            def existing_event_uids(collection):
                existing = {}
                for item in calendar_report(collection, "VEVENT", time_range=False):
                    try:
                        calendar = Calendar.from_ical(item["data"])
                    except Exception:
                        continue
                    for component in calendar.walk("VEVENT"):
                        uid = str(component.get("UID", ""))
                        if uid:
                            existing[uid] = item["href"]
                return existing

            def sync_obsidian_events(args):
                include_all = "--all" in args
                source_events = all_obsidian_events() if include_all else obsidian_events()
                collection = choose_calendar("VEVENT")
                existing = existing_event_uids(collection)
                created = 0
                updated = 0
                skipped = 0
                errors = []
                for event in source_events:
                    path = event.get("path", "")
                    if not path:
                        skipped += 1
                        continue
                    uid = obsidian_uid(path)
                    start_clock = None if event.get("allDay") else maybe_clock(event.get("startTime"))
                    end_clock = None if event.get("allDay") else maybe_clock(event.get("endTime"))
                    extra_lines = [
                        f"DESCRIPTION:{escape_ics('Synced from Obsidian: ' + path)}",
                        "CATEGORIES:Obsidian",
                        f"X-QUICKSHELL-OBSIDIAN-PATH:{escape_ics(path)}",
                    ]
                    try:
                        ics = event_ics(uid, event["date"], event["title"], start_clock, end_clock, extra_lines)
                        href = existing.get(uid)
                        if href:
                            request("PUT", writable_href(href), ics, {"Content-Type": "text/calendar; charset=utf-8"}, ok=(200, 201, 204))
                            updated += 1
                        else:
                            object_name = f"obsidian-{obsidian_event_id(path)}.ics"
                            put_ics(collection, ics, object_name)
                            created += 1
                    except Exception as exc:
                        errors.append({"path": path, "error": str(exc)})
                output = {
                    "ok": not errors,
                    "created": created,
                    "updated": updated,
                    "skipped": skipped,
                    "errors": errors,
                    "rangeStart": None if include_all else RANGE_START.isoformat(),
                    "rangeEnd": None if include_all else RANGE_END.isoformat(),
                }
                print(json.dumps(output))

            def complete_task(args):
                if len(args) != 1:
                    raise RuntimeError("Usage: quickshell-calendar complete-task href")
                href = writable_href(args[0])
                ics = request("GET", href, ok=(200,)).decode("utf-8", errors="replace")
                save_undo({"mode": "restore", "href": href, "ics": ics})
                stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

                ics = unfold_ics(ics)
                ics = upsert_component_line(ics, "VTODO", "STATUS", "COMPLETED")
                ics = upsert_component_line(ics, "VTODO", "PERCENT-COMPLETE", "100")
                ics = upsert_component_line(ics, "VTODO", "COMPLETED", stamp)
                ics = upsert_component_line(ics, "VTODO", "DTSTAMP", stamp)
                request("PUT", href, ics, {"Content-Type": "text/calendar; charset=utf-8"}, ok=(200, 201, 204))
                print(json.dumps({"ok": True, "type": "task", "completed": True, "undoable": True}))

            def edit_task(args):
                if len(args) < 3:
                    raise RuntimeError("Usage: quickshell-calendar edit-task href YYYY-MM-DD title")
                href = writable_href(args[0])
                task_date = compact_date(args[1])
                title = " ".join(args[2:]).strip()
                if not title:
                    raise RuntimeError("Task title is empty")
                original_ics = request("GET", href, ok=(200,)).decode("utf-8", errors="replace")
                save_undo({"mode": "restore", "href": href, "ics": original_ics})
                ics = unfold_ics(original_ics)
                ics = upsert_component_line(ics, "VTODO", "SUMMARY", escape_ics(title))
                ics = replace_component_date_line(ics, "VTODO", "DUE", "DUE;VALUE=DATE", task_date)
                ics = remove_component_line(ics, "VTODO", "DTSTART")
                ics = update_stamp(ics, "VTODO")
                request("PUT", href, ics, {"Content-Type": "text/calendar; charset=utf-8"}, ok=(200, 201, 204))
                print(json.dumps({"ok": True, "type": "task", "edited": True, "undoable": True}))

            def edit_event(args):
                if len(args) < 3:
                    raise RuntimeError("Usage: quickshell-calendar edit-event href YYYY-MM-DD title [HH:MM] [HH:MM]")
                href = writable_href(args[0])
                title_parts = args[2:]
                start_clock = None
                end_clock = None
                if len(title_parts) >= 2 and maybe_clock(title_parts[-1]) and maybe_clock(title_parts[-2]):
                    end_clock = parse_clock(title_parts.pop())
                    start_clock = parse_clock(title_parts.pop())
                elif len(title_parts) >= 2 and maybe_clock(title_parts[-1]):
                    start_clock = parse_clock(title_parts.pop())
                title = " ".join(title_parts).strip()
                if not title:
                    raise RuntimeError("Event title is empty")
                original_ics = request("GET", href, ok=(200,)).decode("utf-8", errors="replace")
                save_undo({"mode": "restore", "href": href, "ics": original_ics})
                uid, extra_lines = existing_event_identity(original_ics)
                ics = event_ics(uid, args[1], title, start_clock, end_clock, extra_lines)
                request("PUT", href, ics, {"Content-Type": "text/calendar; charset=utf-8"}, ok=(200, 201, 204))
                print(json.dumps({"ok": True, "type": "event", "edited": True, "undoable": True}))

            def delete_item(args):
                if len(args) != 1:
                    raise RuntimeError("Usage: quickshell-calendar delete-item href")
                href = writable_href(args[0])
                original_ics = request("GET", href, ok=(200,)).decode("utf-8", errors="replace")
                save_undo({"mode": "restore", "href": href, "ics": original_ics})
                request("DELETE", href, ok=(200, 202, 204))
                print(json.dumps({"ok": True, "deleted": True, "undoable": True}))

            def undo_last_change():
                try:
                    payload = json.loads(UNDO_FILE.read_text(encoding="utf-8"))
                except FileNotFoundError as error:
                    raise RuntimeError("Nothing to undo") from error
                mode = payload.get("mode")
                href = writable_href(payload.get("href", ""))
                if mode == "created":
                    request("DELETE", href, ok=(200, 202, 204, 404))
                elif mode == "restore":
                    ics = payload.get("ics")
                    if not ics:
                        raise RuntimeError("Undo data is missing calendar content")
                    request("PUT", href, ics, {"Content-Type": "text/calendar; charset=utf-8"}, ok=(200, 201, 204))
                else:
                    raise RuntimeError("Undo data is invalid")
                clear_undo()
                print(json.dumps({"ok": True, "undone": True, "undoable": False}))

            def add_note(args):
                if len(args) < 2:
                    raise RuntimeError("Usage: quickshell-calendar add-note YYYY-MM-DD title")
                note_date_value = date.fromisoformat(args[0]).isoformat()
                title = " ".join(args[1:]).strip()
                if not title:
                    raise RuntimeError("Note title is empty")
                content = "\n".join([
                    "---",
                    f"date: {note_date_value}",
                    "---",
                    "",
                    f"# {title}",
                    "",
                ])
                request_json("POST", "/index.php/apps/notes/api/v1/notes", {
                    "content": content,
                    "category": "Calendar",
                }, ok=(200, 201))
                print(json.dumps({"ok": True, "type": "note"}))

            def open_note(args):
                if len(args) != 1 or not str(args[0]).strip():
                    raise RuntimeError("Usage: quickshell-calendar open-note note-id")
                note_id = quote(str(args[0]).strip(), safe="")
                url = urljoin(BASE_URL, f"/index.php/apps/notes/#/notes/{note_id}")
                subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                print(json.dumps({"ok": True, "type": "note", "opened": True}))

            def query():
                events = []
                error = ""
                try:
                    events = nextcloud_events()
                except Exception as exc:
                    error = str(exc)
                synced_obsidian_uids = {
                    item.get("uid", "")
                    for item in events
                    if item.get("uid", "").startswith("obsidian-")
                }
                events.extend([
                    event for event in obsidian_events()
                    if obsidian_uid(event.get("path", "")) not in synced_obsidian_uids
                ])
                events.sort(key=lambda item: (
                    item.get("date", ""),
                    item.get("startTime") or "",
                    item.get("title", ""),
                ))
                output = {"today": date.today().isoformat(), "events": events}
                if error:
                    output["error"] = error
                print(json.dumps(output))

            def main():
                action = sys.argv[1] if len(sys.argv) > 1 else "query"
                try:
                    if action == "query":
                        query()
                    elif action in ("add", "add-task"):
                        add_task(sys.argv[2:])
                    elif action == "add-event":
                        add_event(sys.argv[2:])
                    elif action == "complete-task":
                        complete_task(sys.argv[2:])
                    elif action == "edit-task":
                        edit_task(sys.argv[2:])
                    elif action == "edit-event":
                        edit_event(sys.argv[2:])
                    elif action == "delete-item":
                        delete_item(sys.argv[2:])
                    elif action == "undo":
                        undo_last_change()
                    elif action == "add-note":
                        add_note(sys.argv[2:])
                    elif action == "open-note":
                        open_note(sys.argv[2:])
                    elif action == "sync-obsidian":
                        sync_obsidian_events(sys.argv[2:])
                    else:
                        raise RuntimeError("Usage: quickshell-calendar [query|add-task|add-event|complete-task|edit-task|edit-event|delete-item|undo|add-note|open-note|sync-obsidian]")
                except Exception as exc:
                    print(json.dumps({"ok": False, "error": str(exc)}))
                    raise SystemExit(1)

            main()
      PY
    '';
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
    text = ''
      set -euo pipefail

      action="''${1:-list}"
      encoded="''${2:-}"

      decode_entry() {
        if [[ -z "$encoded" ]]; then
          echo "Missing clipboard entry" >&2
          exit 2
        fi
        printf '%s' "$encoded" | base64 -d
      }

      case "$action" in
        list)
          python3 - <<'PY'
      import base64
      import json
      import subprocess
      import sys

      entries = []
      result = subprocess.run(["cliphist", "list"], check=False, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
      for index, raw in enumerate(result.stdout.splitlines()):
          if not raw:
              continue
          parts = raw.split("\t", 1)
          entry_id = parts[0].strip()
          preview = parts[1].strip() if len(parts) > 1 else raw.strip()
          compact = " ".join(preview.split())
          if len(compact) > 180:
              compact = compact[:177] + "..."
          entries.append({
              "id": entry_id,
              "line": base64.b64encode(raw.encode("utf-8", "replace")).decode("ascii"),
              "preview": compact or "(empty)",
          })
      print(json.dumps(entries[:80], ensure_ascii=False))
      PY
          ;;
        copy)
          decode_entry | cliphist decode | wl-copy
          notify-send -u low -t 1500 "Clipboard" "Copied from history."
          ;;
        delete)
          decode_entry | cliphist delete
          notify-send -u low -t 1500 "Clipboard" "Removed entry."
          ;;
        wipe)
          cliphist wipe
          notify-send -u normal -t 1800 "Clipboard" "History cleared."
          ;;
        *)
          echo "Usage: quickshell-clipboard [list|copy ENTRY|delete ENTRY|wipe]" >&2
          exit 2
          ;;
      esac
    '';
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
      from PIL import Image, ImageDraw, ImageFont

      source = os.environ["SOURCE"]
      output = os.environ["OUTPUT"]
      try:
          payload = json.loads(os.environ.get("STROKES", "[]"))
      except json.JSONDecodeError:
          payload = []
      if isinstance(payload, dict):
          annotations = payload.get("annotations", payload.get("strokes", []))
      elif isinstance(payload, list):
          annotations = payload
      else:
          annotations = []

      image = Image.open(source).convert("RGBA")
      draw = ImageDraw.Draw(image)
      font_path = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSans-Bold.ttf"

      for annotation in annotations:
          if not isinstance(annotation, dict):
              continue
          if annotation.get("type") == "text":
              text = str(annotation.get("text", "")).strip()
              if not text:
                  continue
              x = float(annotation.get("x", 0))
              y = float(annotation.get("y", 0))
              color = annotation.get("color", "#ff4d6d")
              size = max(8, int(round(float(annotation.get("size", 32)))))
              try:
                  font = ImageFont.truetype(font_path, size=size)
              except OSError:
                  font = ImageFont.load_default()
              stroke_width = max(2, int(round(size / 9)))
              draw.text((x, y), text, fill=color, font=font, stroke_width=stroke_width, stroke_fill=(0, 0, 0, 184))
              continue

          points = annotation.get("points", [])
          if len(points) < 1:
              continue
          color = annotation.get("color", "#ff4d6d")
          width = max(1, int(round(float(annotation.get("width", 4)))))
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
      sleep 0.08

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
  shutdownTimerTool = pkgs.writeShellApplication {
    name = "quickshell-shutdown-timer";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      libnotify
    ];
    text = ''
      set -euo pipefail

      action="''${1:-status}"
      target="''${2:-}"
      runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$UID}/auto-shutdown"
      cancel_file="$runtime_dir/cancel"
      custom_deadline_file="$runtime_dir/custom-deadline"
      pending_file="$runtime_dir/pending"
      pending_deadline_file="$runtime_dir/pending-deadline"
      mkdir -p "$runtime_dir"
      rm -f "$runtime_dir/custom-target"

      read_deadline() {
        if [[ -r "$pending_deadline_file" ]]; then
          head -n1 "$pending_deadline_file" | awk '/^[0-9]+$/ { print; exit }'
        fi
      }

      json_status() {
        local deadline now remaining pending
        pending=""
        if [[ -r "$pending_file" ]]; then
          pending="$(head -n1 "$pending_file")"
        fi
        deadline="$(read_deadline)"
        now="$(date +%s)"
        remaining=0
        if [[ -n "$deadline" && "$deadline" -gt "$now" ]]; then
          remaining=$((deadline - now))
        else
          rm -f "$pending_file" "$pending_deadline_file"
          pending=""
        fi
        printf '{"custom":"","pending":"%s","deadline":%s,"remaining":%s,"cancel":false}\n' \
          "$pending" "''${deadline:-0}" "$remaining"
      }

      case "$action" in
        status)
          json_status
          ;;
        schedule-in)
          if ! [[ "$target" =~ ^[0-9]+$ ]] || (( target < 1 || target > 720 )); then
            echo "Invalid shutdown delay minutes: $target" >&2
            exit 2
          fi
          deadline=$(( $(date +%s) + target * 60 ))
          printf '%s\n' "$deadline" > "$custom_deadline_file"
          printf 'in %s min\n' "$target" > "$pending_file"
          printf '%s\n' "$deadline" > "$pending_deadline_file"
          rm -f "$cancel_file"
          notify-send -u critical "Auto shutdown" "System will power off in $target minutes."
          json_status
          ;;
        cancel-pending)
          touch "$cancel_file"
          rm -f "$custom_deadline_file" "$pending_file" "$pending_deadline_file"
          notify-send -u normal "Auto shutdown" "Shutdown cancelled."
          json_status
          ;;
        *)
          echo "Usage: quickshell-shutdown-timer [status|schedule-in MINUTES|cancel-pending]" >&2
          exit 2
          ;;
      esac
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
  keybinds = import ../hyprland/keybinds.nix {
    inherit config lib pkgs;
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
      readonly property int motionPanel: 280
      readonly property int motionModal: 320

      readonly property string fontSans: "JetBrainsMono Nerd Font"
      readonly property string fontMono: "JetBrainsMono Nerd Font"
      readonly property string fontIcon: "JetBrainsMono Nerd Font"
      readonly property string font: fontIcon
    }
  '';
  qmldirConfig = pkgs.writeText "qmldir" ''
    singleton Theme 1.0 Theme.qml
    CodexUsageWindow 1.0 CodexUsageWindow.qml
    KeybindHelpWindow 1.0 KeybindHelpWindow.qml
    LauncherWindow 1.0 LauncherWindow.qml
    PowerMenuWindow 1.0 PowerMenuWindow.qml
  '';
  codexIcon = pkgs.writeText "codex.svg" (
    builtins.replaceStrings
    ["fill=\"#fff\"" "fill=\"url(#codex-gradient)\""]
    ["fill=\"none\"" "fill=\"${config.lib.stylix.colors.withHashtag.base05}\""]
    (builtins.readFile ./assets/codex.svg)
  );
  quickshellAssets = pkgs.linkFarm "quickshell-assets" [
    {
      name = "codex.svg";
      path = codexIcon;
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
      name = "PowerMenuWindow.qml";
      path = ./PowerMenuWindow.qml;
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
  ];

  xdg.configFile."quickshell/shell.qml".source = shellConfig;
  xdg.configFile."quickshell/Theme.qml".source = themeConfig;
  xdg.configFile."quickshell/CodexUsageWindow.qml".source = ./CodexUsageWindow.qml;
  xdg.configFile."quickshell/KeybindHelpWindow.qml".source = ./KeybindHelpWindow.qml;
  xdg.configFile."quickshell/LauncherWindow.qml".source = ./LauncherWindow.qml;
  xdg.configFile."quickshell/PowerMenuWindow.qml".source = ./PowerMenuWindow.qml;
  xdg.configFile."quickshell/assets".source = quickshellAssets;
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
