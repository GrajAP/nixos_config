set -euo pipefail

python3 - "$@" <<'PY'
if True:
      import base64
      import hashlib
      import json
      import re
      import subprocess
      import sys
      import unicodedata
      import uuid
      from datetime import date, datetime, time, timedelta, timezone
      from os import environ
      from pathlib import Path
      from urllib.error import HTTPError, URLError
      from urllib.parse import quote, urljoin, urlsplit
      from urllib.request import Request, urlopen
      from xml.etree import ElementTree as ET
      from subprocess import run
      from xml.sax.saxutils import escape as escape_xml
      from zoneinfo import ZoneInfo

      from icalendar import Calendar
      import recurring_ical_events

      USER = environ.get("USER", "grajpap")
      # Nextcloud runs on lenovo so the widget works while this machine sleeps.
      # It is served under /nextcloud there because tailscale serve already
      # owns the root path for HomeNest.
      BASE_URL = "https://lenovo.tail138448.ts.net/nextcloud"
      # ssh alias for the same machine, used only to re-collect the app password
      # when the cached one has been rotated away.
      LENOVO_HOST = "lenovo-user-ts"
      # urljoin() throws away any path in BASE_URL when handed an absolute one,
      # so every path built here has to carry the prefix itself. The hrefs DAV
      # returns already contain it, which is why only the literals below needed
      # changing.
      WEBROOT = urlsplit(BASE_URL).path.rstrip("/")
      CALENDAR_HOME = f"{WEBROOT}/remote.php/dav/calendars/{USER}/"
      NOTES_API = f"{WEBROOT}/index.php/apps/notes/api/v1/notes"
      # Deliberately not "nextcloud-app-password": that path is owned by the
      # nextcloud-quickshell-token service in system/sync/default.nix, which
      # mints a token against the Nextcloud still running on this machine and
      # would silently break this widget. This one is issued by lenovo.
      PASSWORD_FILE = Path.home() / ".config/quickshell/nextcloud-lenovo-app-password"
      UNDO_FILE = Path.home() / ".cache/quickshell/calendar-undo.json"
      CACHE_FILE = Path(environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "quickshell/calendar-cache.json"
      EVENTS_FOLDER = Path.home() / "Nextcloud/Notes/obsidian/Events"
      OBSIDIAN_INDEX_FILE = EVENTS_FOLDER.parent / ".tocano-index.json"
      RANGE_START = date.today() - timedelta(days=60)
      RANGE_END = date.today() + timedelta(days=366)
      NS = {
          "d": "DAV:",
          "cal": "urn:ietf:params:xml:ns:caldav",
      }
      LOCAL_TZID = "Europe/Warsaw"
      LOCAL_TZ = ZoneInfo(LOCAL_TZID)
      # Written by hand because icalendar's generated VTIMEZONE is a list of
      # RDATEs that stops at 2037. These are the EU rules Poland uses.
      LOCAL_VTIMEZONE = [
          "BEGIN:VTIMEZONE",
          f"TZID:{LOCAL_TZID}",
          "BEGIN:DAYLIGHT",
          "TZOFFSETFROM:+0100",
          "TZOFFSETTO:+0200",
          "TZNAME:CEST",
          "DTSTART:19700329T020000",
          "RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU",
          "END:DAYLIGHT",
          "BEGIN:STANDARD",
          "TZOFFSETFROM:+0200",
          "TZOFFSETTO:+0100",
          "TZNAME:CET",
          "DTSTART:19701025T030000",
          "RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU",
          "END:STANDARD",
          "END:VTIMEZONE",
      ]
      REPEAT_CHOICES = ("daily", "weekly", "monthly", "yearly")
      KEEP = object()

      # The token lenovo mints for this widget is rotated monthly
      # (nextcloud-quickshell-token-rotate on hosts/lenovo), which deletes the
      # old one server-side. A cached copy therefore goes stale on its own and
      # used to leave the widget permanently empty until someone re-collected
      # it by hand. Re-collect it here instead: occ is local-only, so the
      # supported path is the token-print wrapper over the fleet key, which the
      # desktop already has passwordless sudo for.
      def refresh_password():
          result = run(
              [
                  "ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10",
                  LENOVO_HOST, "sudo", "nextcloud-quickshell-token-print",
              ],
              capture_output=True, text=True, timeout=60,
          )
          token = result.stdout.strip()
          if result.returncode != 0 or not token:
              raise RuntimeError(
                  f"could not re-fetch the Nextcloud app password from {LENOVO_HOST}: "
                  f"{result.stderr.strip()[:200]}"
              )
          PASSWORD_FILE.parent.mkdir(parents=True, exist_ok=True)
          PASSWORD_FILE.write_text(token + "\n", encoding="utf-8")
          PASSWORD_FILE.chmod(0o600)
          return token

      def password():
          try:
              return PASSWORD_FILE.read_text(encoding="utf-8").strip()
          except OSError as error:
              raise RuntimeError(
                  f"Nextcloud app password missing at {PASSWORD_FILE} and could "
                  f"not be re-fetched; set it manually"
              ) from error

      def request(method, path, body=None, headers=None, ok=(200, 201, 204, 207), retried=False, want_etag=False):
          url = path if path.startswith("http") else urljoin(BASE_URL, path)
          data = body.encode("utf-8") if isinstance(body, str) else body
          auth = base64.b64encode(f"{USER}:{password()}".encode("utf-8")).decode("ascii")
          request_headers = {
              "Authorization": f"Basic {auth}",
              "User-Agent": "quickshell-nextcloud-calendar",
              # Without this Nextcloud serves webcal subscriptions as cs:subscribed
              # nodes with no readable children, so discover_calendars() skips them
              # and subscribed calendars (USOS) never reach the widget.
              "X-NC-CalDAV-Webcal-Caching": "On",
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
                  return (payload, response.headers.get("ETag")) if want_etag else payload
          except HTTPError as error:
              details = error.read().decode("utf-8", errors="replace")
              # 401 usually means the cached app password was rotated away.
              # Re-collect it once and retry before giving up, so the widget
              # heals itself the month after the rotation instead of staying
              # empty until a human intervenes.
              if error.code == 401 and not retried:
                  try:
                      refresh_password()
                  except Exception as refresh_error:
                      raise RuntimeError(
                          f"{method} {url} returned HTTP 401 and the app password "
                          f"could not be re-fetched: {refresh_error}"
                      ) from refresh_error
                  return request(method, path, body, headers, ok=ok, retried=True, want_etag=want_etag)
              if error.code == 412:
                  raise RuntimeError("Changed on another device, refresh and try again") from error
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
              "dateOfBirth": frontmatter.get("dateOfBirth"),
              "title": title,
              "allDay": frontmatter.get("allDay", "true") != "false",
              "startTime": frontmatter.get("startTime"),
              "endTime": frontmatter.get("endTime"),
              "birthday": frontmatter.get("birthday", "false") == "true",
              "seriesId": frontmatter.get("seriesId"),
              "recurringType": frontmatter.get("recurringType"),
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
          ordinary = [event for event in events if not event.get("birthday")]
          birthday_groups = {}
          for event in events:
              if not event.get("birthday"):
                  continue
              birthday_date = event.get("dateOfBirth")
              try:
                  origin = date.fromisoformat(birthday_date or event["date"])
              except (TypeError, ValueError):
                  continue
              series_key = (
                  f"{event.get('title', '').strip().casefold()}|"
                  f"{origin.month:02d}-{origin.day:02d}"
              )
              candidate = dict(event)
              candidate["date"] = origin.isoformat()
              candidate["recurringType"] = "yearly"
              birthday_groups.setdefault(series_key, []).append(candidate)
          birthdays = []
          for group in birthday_groups.values():
              canonical = dict(min(group, key=lambda item: item["path"]))
              canonical["seriesPaths"] = sorted(item["path"] for item in group)
              birthdays.append(canonical)
          return ordinary + birthdays

      def obsidian_events(source_events=None):
          events = []
          for event in source_events if source_events is not None else all_obsidian_events():
              if not event.get("birthday"):
                  if RANGE_START.isoformat() <= event["date"] <= RANGE_END.isoformat():
                      events.append(event)
                  continue
              try:
                  origin = date.fromisoformat(event["date"])
              except (TypeError, ValueError):
                  continue
              for year in range(max(RANGE_START.year, origin.year), RANGE_END.year + 1):
                  try:
                      occurrence = origin.replace(year=year)
                  except ValueError:
                      occurrence = date(year, 2, 28)
                  if occurrence < RANGE_START or occurrence > RANGE_END:
                      continue
                  instance = dict(event)
                  instance["date"] = occurrence.isoformat()
                  events.append(instance)
          return events

      def relative_obsidian_path(path):
          try:
              return str(Path(path).relative_to(EVENTS_FOLDER.parent))
          except (TypeError, ValueError):
              return str(path)

      def write_obsidian_index(events):
          birthdays = []
          for event in events:
              if not event.get("birthday"):
                  continue
              birthdays.append({
                  "title": event.get("title") or "Untitled birthday",
                  "date": event.get("date"),
                  "path": relative_obsidian_path(event.get("path", "")),
                  "seriesPaths": [
                      relative_obsidian_path(path)
                      for path in event.get("seriesPaths", [event.get("path", "")])
                  ],
              })
          payload = json.dumps(
              {
                  "version": 1,
                  "birthdays": sorted(
                      birthdays,
                      key=lambda item: (item["date"] or "", item["title"].casefold()),
                  ),
              },
              ensure_ascii=False,
              indent=2,
          ) + "\n"
          try:
              current = OBSIDIAN_INDEX_FILE.read_text(encoding="utf-8")
          except FileNotFoundError:
              current = ""
          if current == payload:
              return
          temporary = OBSIDIAN_INDEX_FILE.with_suffix(".json.tmp")
          # The vault is a Nextcloud sync directory, so it only exists once the
          # desktop client has synced it. dell has no synced vault at all, and
          # an unwritable parent here made the whole widget fail with
          # "No such file or directory" instead of just reporting no birthdays.
          temporary.parent.mkdir(parents=True, exist_ok=True)
          temporary.write_text(payload, encoding="utf-8")
          temporary.replace(OBSIDIAN_INDEX_FILE)

      def note_date(note):
          content = note.get("content") or ""
          match = re.search(r"(?m)^date:\s*(\d{4}-\d{2}-\d{2})\s*$", content)
          if match:
              return match.group(1)
          modified = note.get("modified")
          if isinstance(modified, int):
              return datetime.fromtimestamp(modified).date().isoformat()
          return date.today().isoformat()

      def nextcloud_notes():
          notes = request_json("GET", NOTES_API, ok=(200,))
          events = []
          for note in notes or []:
              item_date = note_date(note)
              if item_date < RANGE_START.isoformat() or item_date > RANGE_END.isoformat():
                  continue
              title = note.get("title") or "Untitled note"
              category = note.get("category") or "Notes"
              if category.strip("/").casefold().startswith("obsidian/events"):
                  continue
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
          <d:current-user-privilege-set />
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
              privileges = {
                  granted.tag.rsplit("}", 1)[-1]
                  for granted in (
                      child
                      for privilege in prop.findall("d:current-user-privilege-set/d:privilege", NS)
                      for child in privilege
                  )
              }
              name = text_of(prop, "d:displayname") or href.rstrip("/").split("/")[-1]
              calendars.append({
                  "href": href if href.endswith("/") else f"{href}/",
                  "displayName": name,
                  "components": comps,
                  # A webcal subscription is mirrored read-only: the server
                  # grants read but no write-content, so PUTs to it fail 403.
                  "readOnly": not privileges & {"write", "write-content", "all"},
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

      def local_datetime(value):
          return value.astimezone() if value.tzinfo else value

      def local_day(value):
          if isinstance(value, datetime):
              return local_datetime(value).date()
          return value

      def date_value(value):
          if isinstance(value, date):
              return local_day(value).isoformat()
          return None

      def time_value(value):
          if isinstance(value, datetime):
              return local_datetime(value).strftime("%H:%M")
          return None

      def component_end(component, end_name="DTEND"):
          end = component.get(end_name)
          if end is not None:
              return end.dt
          start = component.get("DTSTART")
          duration = component.get("DURATION")
          if start is not None and duration is not None and isinstance(duration.dt, timedelta):
              return start.dt + duration.dt
          return None

      def last_covered_day(start, end):
          if end is None:
              return local_day(start)
          if not isinstance(start, datetime):
              return max(start, end - timedelta(days=1)) if not isinstance(end, datetime) else start
          if end <= start:
              return local_day(start)
          return local_day(end - timedelta(microseconds=1))

      def repeat_choice(component):
          if component is None:
              return "none"
          rules = component.get("RRULE")
          if rules is None:
              return "custom" if component.get("RDATE") is not None else "none"
          if isinstance(rules, list) or component.get("RDATE") is not None:
              return "custom"
          freq = [str(value).lower() for value in rules.get("FREQ", [])]
          extra = {key.upper() for key in rules.keys()} - {"FREQ", "WKST"}
          if [str(value) for value in rules.get("INTERVAL", [])] in ([], ["1"]):
              extra.discard("INTERVAL")
          if len(freq) == 1 and freq[0] in REPEAT_CHOICES and not extra:
              return freq[0]
          return "custom"

      def occurrence_id(value):
          if isinstance(value, datetime):
              if value.tzinfo:
                  return value.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
              return value.strftime("%Y%m%dT%H%M%S")
          return value.strftime("%Y%m%d")

      def parse_occurrence_id(text):
          text = (text or "").strip()
          try:
              if re.fullmatch(r"\d{8}", text):
                  return datetime.strptime(text, "%Y%m%d").date()
              if re.fullmatch(r"\d{8}T\d{6}Z", text):
                  return datetime.strptime(text, "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
              if re.fullmatch(r"\d{8}T\d{6}", text):
                  return datetime.strptime(text, "%Y%m%dT%H%M%S")
          except ValueError:
              pass
          raise RuntimeError("Expected an occurrence id like 20261103T090000Z")

      def same_instance(left, right):
          return occurrence_id(left) == occurrence_id(right)

      def series_repeats(calendar, name):
          repeats = {}
          for component in calendar.subcomponents:
              if component.name == name and component.get("RECURRENCE-ID") is None:
                  repeats[str(component.get("UID", ""))] = repeat_choice(component)
          return repeats

      def series_overrides(calendar, name):
          return {
              (str(component.get("UID", "")), occurrence_id(component["RECURRENCE-ID"].dt))
              for component in calendar.subcomponents
              if component.name == name and component.get("RECURRENCE-ID") is not None
          }

      def parse_event(component, source, href=None, repeats=None, overrides=None):
          if component.get("X-QUICKSHELL-TASK-HREF") or str(component.get("UID", "")).startswith("quickshell-task-"):
              return None
          start_prop = component.get("DTSTART")
          if start_prop is None:
              return None
          start = start_prop.dt
          if not date_value(start):
              return None
          end = component_end(component)
          uid = str(component.get("UID", ""))
          recurrence = component.get("RECURRENCE-ID")
          repeat = (repeats or {}).get(uid, repeat_choice(component))
          # recurring_ical_events stamps RECURRENCE-ID on every occurrence it
          # returns, single events included, so only an override with no
          # master here counts as recurring on that property alone.
          recurring = repeat != "none" or (recurrence is not None and uid not in (repeats or {}))
          override = recurrence is not None and (uid, occurrence_id(recurrence.dt)) in (overrides or set())
          span_end = last_covered_day(start, end)
          return {
              "date": date_value(start),
              "spanEnd": span_end.isoformat() if span_end > local_day(start) else None,
              "title": str(component.get("SUMMARY", "Untitled event")),
              "allDay": not isinstance(start, datetime),
              "startTime": time_value(start),
              "endTime": time_value(end) if end is not None else None,
              "recurring": recurring,
              "repeat": repeat,
              "recurrenceId": occurrence_id(recurrence.dt if recurrence is not None else start) if recurring else None,
              "override": override,
              "birthday": (
                  str(component.get("X-QUICKSHELL-BIRTHDAY", "")).upper() == "TRUE"
                  or "BIRTHDAY" in str(component.get("CATEGORIES", "")).upper()
              ),
              "task": False,
              "note": False,
              "href": href,
              "uid": str(component.get("UID", "")),
              "obsidianPath": str(component.get("X-QUICKSHELL-OBSIDIAN-PATH", "")),
              "source": source,
          }

      def todo_occurrence_days(calendar, component, start_day, due_day):
          primary = due_day or start_day
          lead = max(0, (due_day - start_day).days) if start_day and due_day else 0
          uid = str(component.get("UID", ""))
          days = {}
          try:
              occurrences = recurring_ical_events.of(calendar, components=["VTODO"]).between(
                  primary + timedelta(days=1),
                  RANGE_END,
              )
          except Exception:
              return days
          for occurrence in occurrences:
              if str(occurrence.get("UID", "")) != uid:
                  continue
              anchor = occurrence.get("DUE") if due_day else occurrence.get("DTSTART")
              if anchor is None:
                  continue
              last_day = local_day(anchor.dt)
              if last_day <= primary:
                  continue
              for offset in range(lead + 1):
                  days[(last_day - timedelta(days=offset)).isoformat()] = True
          return days

      def parse_todo(component, source, task_list_id, href=None, etag=None, calendar=None):
          status = str(component.get("STATUS", "")).upper()
          if status == "CANCELLED":
              return None
          start_prop = component.get("DTSTART")
          start_day = local_day(start_prop.dt) if start_prop is not None else None
          due = component_end(component, "DUE")
          due_day = local_day(due) if due is not None else None
          item_day = due_day or start_day
          span_start = start_day if start_day and due_day and start_day < due_day else None
          completed = status == "COMPLETED" or str(component.get("PERCENT-COMPLETE", "")) == "100"
          repeat = repeat_choice(component)
          cover_days = {}
          if repeat != "none" and not completed and item_day and calendar is not None:
              cover_days = todo_occurrence_days(calendar, component, start_day, due_day)
          return {
              "date": item_day.isoformat() if item_day else "",
              "startDate": start_day.isoformat() if start_day else None,
              "dueDate": due_day.isoformat() if due_day else None,
              "spanStart": span_start.isoformat() if span_start else None,
              "recurring": repeat != "none",
              "repeat": repeat,
              "coverDays": cover_days,
              "title": str(component.get("SUMMARY", "Untitled task")),
              "allDay": True,
              "startTime": None,
              "endTime": None,
              "birthday": False,
              "task": True,
              "completed": completed,
              "note": False,
              "href": href,
              "uid": str(component.get("UID", "")),
              "etag": etag,
              "source": source,
              "taskListId": task_list_id,
          }

      def nextcloud_events():
          events = []
          tasks = []
          calendars = discover_calendars()
          for collection in calendars:
              if "VEVENT" in collection["components"]:
                  for item in calendar_report(collection, "VEVENT"):
                      ics = item["data"]
                      calendar = Calendar.from_ical(ics)
                      try:
                          components = recurring_ical_events.of(calendar, keep_recurrence_attributes=True).between(
                              datetime.combine(RANGE_START, time.min),
                              datetime.combine(RANGE_END, time.min),
                          )
                      except Exception:
                          components = calendar.walk("VEVENT")
                      repeats = series_repeats(calendar, "VEVENT")
                      overrides = series_overrides(calendar, "VEVENT")
                      for component in components:
                          parsed = parse_event(component, collection["displayName"], item["href"], repeats, overrides)
                          if parsed:
                              events.append(parsed)
              if "VTODO" in collection["components"]:
                  for item in calendar_report(collection, "VTODO", time_range=False):
                      ics = item["data"]
                      calendar = Calendar.from_ical(ics)
                      for component in calendar.walk("VTODO"):
                          parsed = parse_todo(
                              component,
                              collection["displayName"],
                              collection["href"],
                              item["href"],
                              item["etag"],
                              calendar,
                          )
                          if parsed:
                              tasks.append(parsed)
          events.extend(tasks)
          task_lists = []
          for item in calendars:
              if "VTODO" not in item["components"]:
                  continue
              task_count = sum(1 for task in tasks if task.get("taskListId") == item["href"])
              task_lists.append({
                  "id": item["href"],
                  "name": item["displayName"],
                  "readOnly": item["readOnly"],
                  "deletable": not item["readOnly"] and item["components"] == {"VTODO"} and task_count == 0,
                  "taskCount": task_count,
              })
          task_lists.sort(key=lambda item: item["name"].casefold())
          return events, task_lists

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

      def find_synced_calendar(calendars):
          for item in calendars:
              name = item["displayName"].strip().lower()
              uri = item["href"].rstrip("/").split("/")[-1].lower()
              if name == "synced calendar" or uri == "synced-calendar":
                  return item
          for item in calendars:
              name = item["displayName"].strip().lower()
              uri = item["href"].rstrip("/").split("/")[-1].lower()
              if "sync" in name or "sync" in uri:
                  return item
          return None

      def choose_calendar(component):
          calendars = discover_calendars()
          candidates = [item for item in calendars if component in item["components"] and not item["readOnly"]]
          if component == "VTODO":
              tasks_calendar = find_tasks_calendar(candidates)
              if tasks_calendar:
                  return tasks_calendar
              return create_tasks_calendar()
          if component == "VEVENT":
              synced_calendar = find_synced_calendar(candidates)
              if synced_calendar:
                  return synced_calendar
              for item in candidates:
                  uri = item["href"].rstrip("/").split("/")[-1]
                  if uri == "personal":
                      return item
          if candidates:
              return candidates[0]
          raise RuntimeError(f"No writable {component} calendar found")

      def choose_task_calendar(task_list_id=None):
          if not task_list_id:
              return choose_calendar("VTODO")
          for item in discover_calendars():
              if item["href"] == task_list_id and "VTODO" in item["components"] and not item["readOnly"]:
                  return item
          raise RuntimeError("Selected task list is unavailable")

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

      def task_list_slug(name, calendars):
          normalized = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode("ascii")
          base = re.sub(r"[^a-z0-9]+", "-", normalized.lower()).strip("-") or "list"
          existing = {item["href"].rstrip("/").split("/")[-1] for item in calendars}
          slug = base
          suffix = 2
          while slug in existing:
              slug = f"{base}-{suffix}"
              suffix += 1
          return slug

      def create_task_list(args):
          name = " ".join(args).strip()
          if not name:
              raise RuntimeError("Task list name is empty")
          if len(name) > 80:
              raise RuntimeError("Task list name is too long")
          calendars = discover_calendars()
          slug = task_list_slug(name, calendars)
          href = f"{CALENDAR_HOME}{quote(slug)}/"
          body = f"""<?xml version="1.0" encoding="utf-8" ?>
      <cal:mkcalendar xmlns:d="DAV:" xmlns:cal="urn:ietf:params:xml:ns:caldav">
        <d:set>
          <d:prop>
            <d:displayname>{escape_xml(name)}</d:displayname>
            <cal:supported-calendar-component-set>
              <cal:comp name="VTODO" />
            </cal:supported-calendar-component-set>
          </d:prop>
        </d:set>
      </cal:mkcalendar>"""
          request("MKCALENDAR", href, body, ok=(200, 201, 204))
          collection = choose_task_calendar(href)
          print(json.dumps({
              "ok": True,
              "type": "task-list",
              "taskListId": collection["href"],
              "taskListName": collection["displayName"],
              "requiresDavxActivation": True,
          }))

      def delete_task_list(args):
          if len(args) != 1:
              raise RuntimeError("Usage: quickshell-calendar delete-task-list task-list-id")
          collection = choose_task_calendar(args[0])
          if collection["components"] != {"VTODO"}:
              raise RuntimeError("This list also contains calendar data and cannot be deleted here")
          tasks = calendar_report(collection, "VTODO", time_range=False)
          if tasks:
              raise RuntimeError("Only an empty task list can be deleted")
          request("DELETE", collection["href"], ok=(200, 202, 204))
          clear_undo()
          print(json.dumps({
              "ok": True,
              "type": "task-list",
              "deleted": True,
              "undoable": False,
          }))

      def put_ics(collection, ics, object_name=None):
          object_name = quote(object_name or f"{uuid.uuid4()}.ics")
          path = f"{collection['href']}{object_name}"
          _payload, etag = request("PUT", path, ics, {"Content-Type": "text/calendar; charset=utf-8"}, ok=(200, 201, 204), want_etag=True)
          return path, etag

      def get_item(href):
          payload, etag = request("GET", href, ok=(200,), want_etag=True)
          return payload.decode("utf-8", errors="replace"), etag

      def put_item(href, ics, etag=None):
          headers = {"Content-Type": "text/calendar; charset=utf-8"}
          if etag:
              headers["If-Match"] = etag
          return request("PUT", href, ics, headers, ok=(200, 201, 204), want_etag=True)[1]

      def delete_href(href, etag=None, ok=(200, 202, 204)):
          request("DELETE", href, headers={"If-Match": etag} if etag else None, ok=ok)

      def event_ics(uid, event_date_value, title, start_clock=None, end_clock=None, extra_lines=None):
          event_date = compact_date(event_date_value)
          stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
          lines = [
              "BEGIN:VCALENDAR",
              "VERSION:2.0",
              "PRODID:-//quickshell//nextcloud-calendar//EN",
              *(LOCAL_VTIMEZONE if start_clock else []),
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
              lines.append(f"DTSTART;TZID={LOCAL_TZID}:{start_dt.strftime('%Y%m%dT%H%M%S')}")
              lines.append(f"DTEND;TZID={LOCAL_TZID}:{end_dt.strftime('%Y%m%dT%H%M%S')}")
          else:
              next_day = (date.fromisoformat(event_date_value) + timedelta(days=1)).strftime("%Y%m%d")
              lines.append(f"DTSTART;VALUE=DATE:{event_date}")
              lines.append(f"DTEND;VALUE=DATE:{next_day}")
          lines.extend(["END:VEVENT", "END:VCALENDAR", ""])
          return "\r\n".join(lines)

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

      def split_options(args, allowed):
          options = {}
          rest = list(args)
          while rest and rest[0].startswith("--") and "=" in rest[0]:
              key, value = rest.pop(0)[2:].split("=", 1)
              if key not in allowed:
                  raise RuntimeError(f"Unknown option --{key}")
              options[key] = value
          return options, rest

      def parse_repeat(value):
          if value is None:
              return None
          value = value.strip().lower()
          if value not in ("none", *REPEAT_CHOICES):
              raise RuntimeError("Repeat must be none, daily, weekly, monthly or yearly")
          return value

      def parse_day_option(value):
          if value is None:
              return KEEP
          if value.strip() in ("", "-"):
              return None
          try:
              return date.fromisoformat(value.strip())
          except ValueError as error:
              raise RuntimeError("Expected date as YYYY-MM-DD") from error

      def split_event_title(parts):
          parts = list(parts)
          start_clock = None
          end_clock = None
          if len(parts) >= 2 and maybe_clock(parts[-1]) and maybe_clock(parts[-2]):
              end_clock = parse_clock(parts.pop())
              start_clock = parse_clock(parts.pop())
          elif len(parts) >= 2 and maybe_clock(parts[-1]):
              start_clock = parse_clock(parts.pop())
          title = " ".join(parts).strip()
          if not title:
              raise RuntimeError("Event title is empty")
          return title, start_clock, end_clock

      def parse_calendar_for_edit(original_ics):
          try:
              calendar = Calendar.from_ical(original_ics)
          except Exception as error:
              raise RuntimeError("Could not parse this item; edit it on the phone instead") from error
          for component in calendar.walk():
              if getattr(component, "errors", None):
                  raise RuntimeError("This item has values the widget cannot rewrite without loss; edit it on the phone instead")
          return calendar

      def components_named(calendar, name):
          return [item for item in calendar.subcomponents if item.name == name]

      def master_component(calendar, name):
          items = components_named(calendar, name)
          return next((item for item in items if item.get("RECURRENCE-ID") is None), None), items

      def ensure_local_timezone(calendar):
          if any(str(item.get("TZID", "")) == LOCAL_TZID for item in components_named(calendar, "VTIMEZONE")):
              return
          wrapper = "\r\n".join(["BEGIN:VCALENDAR", *LOCAL_VTIMEZONE, "END:VCALENDAR", ""])
          calendar.subcomponents.insert(0, Calendar.from_ical(wrapper).subcomponents[0])

      def uses_local_zone(*values):
          return any(isinstance(value, datetime) and value.tzinfo is LOCAL_TZ for value in values)

      def set_property(component, name, value):
          component.pop(name, None)
          component.add(name, value)

      def touch_component(component, significant=False):
          now = datetime.now(timezone.utc).replace(microsecond=0)
          set_property(component, "DTSTAMP", now)
          set_property(component, "LAST-MODIFIED", now)
          if significant:
              try:
                  sequence = int(component.get("SEQUENCE", 0))
              except (TypeError, ValueError):
                  sequence = 0
              set_property(component, "SEQUENCE", sequence + 1)

      def same_moment(left, right):
          if isinstance(left, datetime) != isinstance(right, datetime):
              return False
          if isinstance(left, datetime) and (left.tzinfo is None) != (right.tzinfo is None):
              return False
          return left == right

      def zone_of(value):
          return value.tzinfo if isinstance(value, datetime) else None

      def wall_clock(value, zone):
          if isinstance(value, datetime):
              if value.tzinfo is not None and zone is not None:
                  value = value.astimezone(zone)
              return value.replace(tzinfo=None)
          return datetime.combine(value, time.min)

      def from_wall_clock(value, template):
          if isinstance(template, datetime):
              return value.replace(tzinfo=template.tzinfo)
          return value.date()

      def date_list_values(prop):
          if prop is None:
              return []
          values = []
          for item in prop if isinstance(prop, list) else [prop]:
              values.extend(entry.dt for entry in getattr(item, "dts", []))
          return values

      def shift_series(calendar, master, old_start, new_start):
          # EXDATE, RDATE and RECURRENCE-ID point at instances computed from
          # DTSTART, so moving DTSTART without moving them would revive
          # deleted occurrences and orphan moved ones.
          old_zone = zone_of(old_start)
          delta = wall_clock(new_start, zone_of(new_start)) - wall_clock(old_start, old_zone)

          def move(value):
              return from_wall_clock(wall_clock(value, old_zone) + delta, new_start)

          for name in ("EXDATE", "RDATE"):
              values = date_list_values(master.get(name))
              if not values or not all(isinstance(value, date) for value in values):
                  continue
              master.pop(name)
              master.add(name, [move(value) for value in values])
          uid = str(master.get("UID", ""))
          for item in components_named(calendar, master.name):
              recurrence = item.get("RECURRENCE-ID")
              if item is master or recurrence is None or str(item.get("UID", "")) != uid:
                  continue
              set_property(item, "RECURRENCE-ID", move(recurrence.dt))
          rule = master.get("RRULE")
          if rule is not None and not isinstance(rule, list) and rule.get("UNTIL"):
              until = rule["UNTIL"][0]
              moved = move(until)
              if isinstance(new_start, datetime):
                  if not isinstance(until, datetime):
                      moved = moved.replace(hour=23, minute=59, second=59)
                  if moved.tzinfo is not None:
                      moved = moved.astimezone(timezone.utc)
              rule["UNTIL"] = [moved]

      def rule_has_by_parts(component):
          rules = component.get("RRULE")
          for rule in rules if isinstance(rules, list) else [] if rules is None else [rules]:
              if {key.upper() for key in rule.keys()} - {"FREQ", "INTERVAL", "WKST", "UNTIL", "COUNT"}:
                  return True
          return False

      def apply_repeat(calendar, master, choice):
          if choice is None or choice == repeat_choice(master):
              return False
          if choice == "none":
              for name in ("RRULE", "RDATE", "EXDATE"):
                  master.pop(name, None)
              uid = str(master.get("UID", ""))
              for item in components_named(calendar, master.name):
                  if item is not master and str(item.get("UID", "")) == uid and item.get("RECURRENCE-ID") is not None:
                      calendar.subcomponents.remove(item)
          else:
              set_property(master, "RRULE", {"FREQ": choice.upper()})
          return True

      def edited_event_times(old_start, old_end, start_day, start_clock, end_clock):
          old_timed = isinstance(old_start, datetime)
          if start_clock is None:
              if old_timed:
                  days = (local_day(old_end) - local_day(old_start)).days + 1 if old_end is not None else 1
              else:
                  days = (old_end - old_start).days if old_end is not None and not isinstance(old_end, datetime) else 1
              return start_day, start_day + timedelta(days=max(1, days))
          floating = old_timed and old_start.tzinfo is None

          def at(day, clock):
              value = datetime.combine(day, time(*clock))
              return value if floating else value.replace(tzinfo=LOCAL_TZ)

          new_start = at(start_day, start_clock)
          if end_clock is None:
              duration = old_end - old_start if old_timed and old_end is not None else timedelta(hours=1)
              return new_start, new_start + duration
          span_days = (local_day(old_end) - local_day(old_start)).days if old_timed and old_end is not None else 0
          new_end = at(start_day + timedelta(days=span_days), end_clock)
          if new_end <= new_start:
              new_end += timedelta(days=1)
          return new_start, new_end

      def update_event_calendar(calendar, new_day, title, start_clock=None, end_clock=None, repeat=None, occurrence=None):
          master, events = master_component(calendar, "VEVENT")
          target = None
          if occurrence is not None:
              target = next((
                  item for item in events
                  if item.get("RECURRENCE-ID") is not None and same_instance(item["RECURRENCE-ID"].dt, occurrence)
              ), None)
          if target is None:
              target = master or (events[0] if events else None)
          if target is None or target.get("DTSTART") is None:
              raise RuntimeError("This item has no event to edit")
          old_start = target["DTSTART"].dt
          old_end = component_end(target)
          base_day = local_day(occurrence) if occurrence is not None and target is master else local_day(old_start)
          start_day = local_day(old_start) + (new_day - base_day)
          new_start, new_end = edited_event_times(old_start, old_end, start_day, start_clock, end_clock)
          if target is not master and repeat is not None:
              raise RuntimeError("This day was changed on its own; change the repeat from another day of the series")
          replaces_rule = repeat is not None and repeat != repeat_choice(master)
          if target is master and not replaces_rule and wall_clock(new_start, zone_of(new_start)).date() != wall_clock(old_start, zone_of(old_start)).date() and rule_has_by_parts(master):
              # EXDATE and RECURRENCE-ID move by the same delta as DTSTART,
              # but BYDAY and friends pin the instances, so they would stop
              # lining up and deleted or moved days would come back.
              raise RuntimeError("Move the day of a custom-repeat series on the phone")
          significant = False
          written = []
          if str(target.get("SUMMARY", "")) != title:
              set_property(target, "SUMMARY", title)
          if not same_moment(new_start, old_start):
              set_property(target, "DTSTART", new_start)
              written.append(new_start)
              if target is master:
                  shift_series(calendar, master, old_start, new_start)
              significant = True
          implied_end = old_end if old_end is not None else (old_start + timedelta(days=1) if not isinstance(old_start, datetime) else old_start)
          keeps_no_end = old_end is None and same_moment(new_start, old_start) and (end_clock is None or same_moment(new_end, new_start + timedelta(hours=1)))
          if not keeps_no_end and (significant or not same_moment(new_end, implied_end)):
              if target.get("DURATION") is not None and target.get("DTEND") is None:
                  set_property(target, "DURATION", new_end - new_start)
              else:
                  set_property(target, "DTEND", new_end)
              written.append(new_end)
              significant = True
          if target is master and apply_repeat(calendar, master, repeat):
              significant = True
          if uses_local_zone(*written):
              ensure_local_timezone(calendar)
          touch_component(target, significant)
          return calendar.to_ical().decode("utf-8")

      def delete_occurrence_calendar(calendar, occurrence):
          master, events = master_component(calendar, "VEVENT")
          for item in events:
              recurrence = item.get("RECURRENCE-ID")
              if recurrence is not None and same_instance(recurrence.dt, occurrence):
                  calendar.subcomponents.remove(item)
          if master is None:
              return calendar.to_ical().decode("utf-8") if components_named(calendar, "VEVENT") else None
          if master.get("RRULE") is None and master.get("RDATE") is None:
              return None
          start = master["DTSTART"].dt
          if not isinstance(start, datetime):
              excluded = local_day(occurrence)
          elif not isinstance(occurrence, datetime):
              excluded = from_wall_clock(datetime.combine(occurrence, wall_clock(start, zone_of(start)).time()), start)
          elif start.tzinfo is None:
              excluded = local_datetime(occurrence).replace(tzinfo=None) if occurrence.tzinfo else occurrence
          else:
              excluded = occurrence.astimezone(start.tzinfo) if occurrence.tzinfo else occurrence.replace(tzinfo=start.tzinfo)
          master.add("EXDATE", excluded)
          touch_component(master, True)
          return calendar.to_ical().decode("utf-8")

      def set_task_day(component, name, sibling_name, new_day):
          if name == "DUE":
              current = component_end(component, "DUE")
          else:
              current = component["DTSTART"].dt if component.get("DTSTART") is not None else None
          if new_day is None:
              if current is None:
                  return False
              if name == "DTSTART" and component.get("DUE") is None and component.get("DURATION") is not None:
                  set_property(component, "DUE", current + component["DURATION"].dt)
              component.pop(name, None)
              component.pop("DURATION", None)
              return True
          if current is not None and local_day(current) == new_day:
              return False
          template = current if isinstance(current, datetime) else None
          if template is None:
              sibling = component.get(sibling_name)
              if sibling is not None and isinstance(sibling.dt, datetime):
                  template = sibling.dt
          if template is None:
              value = new_day
          elif template.tzinfo is None:
              value = datetime.combine(new_day, template.time())
          else:
              value = datetime.combine(new_day, local_datetime(template).time()).astimezone().astimezone(timezone.utc)
          if name == "DUE" and component.get("DURATION") is not None:
              component.pop("DURATION")
          set_property(component, name, value)
          return True

      def update_todo_calendar(calendar, title, due_day=KEEP, start_day=KEEP, repeat=None):
          master, _todos = master_component(calendar, "VTODO")
          if master is None:
              raise RuntimeError("This item has no task to edit")
          significant = False
          if str(master.get("SUMMARY", "")) != title:
              set_property(master, "SUMMARY", title)
          if due_day is not KEEP and set_task_day(master, "DUE", "DTSTART", due_day):
              significant = True
          if start_day is not KEEP and set_task_day(master, "DTSTART", "DUE", start_day):
              significant = True
          start = master["DTSTART"].dt if master.get("DTSTART") is not None else None
          due = component_end(master, "DUE")
          if start is not None and due is not None and local_day(start) > local_day(due):
              raise RuntimeError("The start date is after the due date")
          if apply_repeat(calendar, master, repeat):
              significant = True
          if master.get("RRULE") is not None and start is None and due is None:
              raise RuntimeError("A repeating task needs a date")
          touch_component(master, significant)
          return calendar.to_ical().decode("utf-8")

      def complete_todo_calendar(calendar):
          master, _todos = master_component(calendar, "VTODO")
          if master is None:
              raise RuntimeError("This item has no task to complete")
          now = datetime.now(timezone.utc).replace(microsecond=0)
          anchor_name = "DUE" if master.get("DUE") is not None else "DTSTART"
          anchor = master[anchor_name].dt if master.get(anchor_name) is not None else None
          following = None
          if master.get("RRULE") is not None and anchor is not None:
              # Phone task apps complete a repeating task by moving it to its
              # next date; marking the series COMPLETED would end it for good.
              try:
                  for occurrence in recurring_ical_events.of(calendar, components=["VTODO"]).after(anchor):
                      value = occurrence.get(anchor_name)
                      if value is not None and str(occurrence.get("UID", "")) == str(master.get("UID", "")) and value.dt > anchor:
                          following = value.dt
                          break
              except Exception:
                  following = None
          if following is None:
              set_property(master, "STATUS", "COMPLETED")
              set_property(master, "PERCENT-COMPLETE", 100)
              set_property(master, "COMPLETED", now)
              touch_component(master)
              return calendar.to_ical().decode("utf-8"), False
          zone = zone_of(anchor)
          delta = wall_clock(following, zone) - wall_clock(anchor, zone)
          for name in ("DTSTART", "DUE"):
              prop = master.get(name)
              if prop is not None:
                  old = prop.dt
                  set_property(master, name, from_wall_clock(wall_clock(old, zone_of(old)) + delta, old))
          rule = master["RRULE"]
          if not isinstance(rule, list) and rule.get("COUNT"):
              rule["COUNT"] = [max(1, int(rule["COUNT"][0]) - 1)]
          set_property(master, "STATUS", "NEEDS-ACTION")
          master.pop("COMPLETED", None)
          master.pop("PERCENT-COMPLETE", None)
          touch_component(master, True)
          return calendar.to_ical().decode("utf-8"), True

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
          href, etag = put_ics(choose_calendar("VTODO"), ics)
          save_undo({"mode": "created", "href": href, "etag": etag})
          print(json.dumps({"ok": True, "type": "task", "undoable": True}))

      def add_overall_task(args):
          options, args = split_options(args, {"start", "repeat"})
          if len(args) < 2:
              raise RuntimeError("Usage: quickshell-calendar add-overall-task [--start=YYYY-MM-DD] [--repeat=weekly] task-list-id title")
          task_list_id = args[0]
          has_explicit_date = len(args) >= 3 and (args[1] == "-" or re.fullmatch(r"\d{4}-\d{2}-\d{2}", args[1]))
          due_date = None if not has_explicit_date or args[1] == "-" else compact_date(args[1])
          title = " ".join(args[2:] if has_explicit_date else args[1:]).strip()
          if not title:
              raise RuntimeError("Task title is empty")
          start_day = parse_day_option(options.get("start"))
          start_date = start_day.strftime("%Y%m%d") if start_day not in (KEEP, None) else None
          repeat = parse_repeat(options.get("repeat"))
          if start_date and due_date and start_date > due_date:
              raise RuntimeError("The start date is after the due date")
          if repeat not in (None, "none") and not (start_date or due_date):
              raise RuntimeError("A repeating task needs a date")
          uid = f"{uuid.uuid4()}@quickshell"
          stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
          lines = [
              "BEGIN:VCALENDAR",
              "VERSION:2.0",
              "PRODID:-//quickshell//nextcloud-calendar//EN",
              "BEGIN:VTODO",
              f"UID:{uid}",
              f"DTSTAMP:{stamp}",
              f"CREATED:{stamp}",
              f"LAST-MODIFIED:{stamp}",
              f"SUMMARY:{escape_ics(title)}",
          ]
          if start_date:
              lines.append(f"DTSTART;VALUE=DATE:{start_date}")
          if due_date:
              lines.append(f"DUE;VALUE=DATE:{due_date}")
          if repeat not in (None, "none"):
              lines.append(f"RRULE:FREQ={repeat.upper()}")
          lines.extend([
              "STATUS:NEEDS-ACTION",
              "PERCENT-COMPLETE:0",
              "END:VTODO",
              "END:VCALENDAR",
              "",
          ])
          ics = "\r\n".join(lines)
          href, etag = put_ics(choose_task_calendar(task_list_id), ics)
          save_undo({"mode": "created", "href": href, "etag": etag})
          print(json.dumps({"ok": True, "type": "task", "undated": due_date is None, "undoable": True}))

      def edit_overall_task(args):
          options, args = split_options(args, {"start", "repeat"})
          if len(args) < 2:
              raise RuntimeError("Usage: quickshell-calendar edit-overall-task [--start=YYYY-MM-DD|-] [--repeat=weekly] href title")
          href = writable_href(args[0])
          has_explicit_date = len(args) >= 3 and (args[1] == "-" or re.fullmatch(r"\d{4}-\d{2}-\d{2}", args[1]))
          due_day = parse_day_option(args[1]) if has_explicit_date else KEEP
          title = " ".join(args[2:] if has_explicit_date else args[1:]).strip()
          if not title:
              raise RuntimeError("Task title is empty")
          original_ics, etag = get_item(href)
          ics = update_todo_calendar(
              parse_calendar_for_edit(original_ics),
              title,
              due_day,
              parse_day_option(options.get("start")),
              parse_repeat(options.get("repeat")),
          )
          save_undo({"mode": "restore", "href": href, "ics": original_ics, "etag": put_item(href, ics, etag)})
          print(json.dumps({"ok": True, "type": "task", "undated": due_day is None, "edited": True, "undoable": True}))

      def add_event(args):
          options, args = split_options(args, {"repeat"})
          if len(args) < 2:
              raise RuntimeError("Usage: quickshell-calendar add-event [--repeat=weekly] YYYY-MM-DD title [HH:MM] [HH:MM]")
          compact_date(args[0])
          title, start_clock, end_clock = split_event_title(args[1:])
          repeat = parse_repeat(options.get("repeat"))
          extra_lines = [f"RRULE:FREQ={repeat.upper()}"] if repeat not in (None, "none") else None
          uid = f"{uuid.uuid4()}@quickshell"
          href, etag = put_ics(choose_calendar("VEVENT"), event_ics(uid, args[0], title, start_clock, end_clock, extra_lines))
          save_undo({"mode": "created", "href": href, "etag": etag})
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

      def task_mirror_key(task):
          identity = task.get("uid") or task.get("href") or task.get("title", "")
          return hashlib.sha1(identity.encode("utf-8")).hexdigest()

      def task_mirror_uid(task):
          return f"quickshell-task-{task_mirror_key(task)}@quickshell"

      def task_mirror_ics(task):
          task_date = compact_date(task["date"])
          next_day = (date.fromisoformat(task["date"]) + timedelta(days=1)).strftime("%Y%m%d")
          stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
          title = f"TODO: {task.get('title') or 'Untitled task'}"
          key = task_mirror_key(task)
          task_href = task.get("href") or ""
          lines = [
              "BEGIN:VCALENDAR",
              "VERSION:2.0",
              "PRODID:-//quickshell//nextcloud-calendar//EN",
              "BEGIN:VEVENT",
              f"UID:{task_mirror_uid(task)}",
              f"DTSTAMP:{stamp}",
              f"SUMMARY:{escape_ics(title)}",
              f"DESCRIPTION:{escape_ics('Mirrored from Nextcloud Tasks. Edit the task in the task list.')}",
              "CATEGORIES:Tasks",
              "TRANSP:TRANSPARENT",
              f"DTSTART;VALUE=DATE:{task_date}",
              f"DTEND;VALUE=DATE:{next_day}",
              f"X-QUICKSHELL-TASK-KEY:{key}",
              f"X-QUICKSHELL-TASK-HREF:{escape_ics(task_href)}",
              "END:VEVENT",
              "END:VCALENDAR",
              "",
          ]
          return "\r\n".join(lines)

      def existing_task_mirrors(collection):
          mirrors = {}
          for item in calendar_report(collection, "VEVENT", time_range=False):
              try:
                  calendar = Calendar.from_ical(item["data"])
              except Exception:
                  continue
              for component in calendar.walk("VEVENT"):
                  uid = str(component.get("UID", ""))
                  key = str(component.get("X-QUICKSHELL-TASK-KEY", ""))
                  if not key and uid.startswith("quickshell-task-") and uid.endswith("@quickshell"):
                      key = uid.removeprefix("quickshell-task-").removesuffix("@quickshell")
                  if key:
                      mirrors[key] = item["href"]
          return mirrors

      def sync_task_mirrors(tasks):
          collection = choose_calendar("VEVENT")
          existing = existing_task_mirrors(collection)
          active_tasks = [task for task in tasks if not task.get("completed") and task.get("date")]
          active_keys = {task_mirror_key(task) for task in active_tasks}

          for task in active_tasks:
              key = task_mirror_key(task)
              ics = task_mirror_ics(task)
              href = existing.get(key)
              if href:
                  request("PUT", writable_href(href), ics, {"Content-Type": "text/calendar; charset=utf-8"}, ok=(200, 201, 204))
              else:
                  put_ics(collection, ics, f"task-{key}.ics")

          for key, href in existing.items():
              if key not in active_keys:
                  request("DELETE", writable_href(href), ok=(200, 202, 204, 404))

      def sync_obsidian_events(args):
          include_all = "--all" in args
          all_source_events = all_obsidian_events()
          write_obsidian_index(all_source_events)
          source_events = all_source_events if include_all else [
              event for event in all_source_events
              if event.get("birthday")
              or RANGE_START.isoformat() <= event["date"] <= RANGE_END.isoformat()
          ]
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
                  "CATEGORIES:Obsidian,Birthday" if event.get("birthday") else "CATEGORIES:Obsidian",
                  f"X-QUICKSHELL-OBSIDIAN-PATH:{escape_ics(path)}",
              ]
              if event.get("birthday"):
                  extra_lines.extend([
                      "RRULE:FREQ=YEARLY",
                      "X-QUICKSHELL-BIRTHDAY:TRUE",
                  ])
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
          original_ics, etag = get_item(href)
          ics, advanced = complete_todo_calendar(parse_calendar_for_edit(original_ics))
          save_undo({"mode": "restore", "href": href, "ics": original_ics, "etag": put_item(href, ics, etag)})
          print(json.dumps({"ok": True, "type": "task", "completed": True, "advanced": advanced, "undoable": True}))

      def edit_task(args):
          if len(args) < 3:
              raise RuntimeError("Usage: quickshell-calendar edit-task href YYYY-MM-DD title")
          href = writable_href(args[0])
          due_day = parse_day_option(args[1])
          title = " ".join(args[2:]).strip()
          if not title:
              raise RuntimeError("Task title is empty")
          original_ics, etag = get_item(href)
          ics = update_todo_calendar(parse_calendar_for_edit(original_ics), title, due_day)
          save_undo({"mode": "restore", "href": href, "ics": original_ics, "etag": put_item(href, ics, etag)})
          print(json.dumps({"ok": True, "type": "task", "edited": True, "undoable": True}))

      def edit_event(args):
          options, args = split_options(args, {"repeat", "occurrence"})
          if len(args) < 3:
              raise RuntimeError("Usage: quickshell-calendar edit-event [--repeat=weekly] [--occurrence=id] href YYYY-MM-DD title [HH:MM] [HH:MM]")
          href = writable_href(args[0])
          new_day = parse_day_option(args[1])
          if new_day in (KEEP, None):
              raise RuntimeError("Expected date as YYYY-MM-DD")
          title, start_clock, end_clock = split_event_title(args[2:])
          occurrence = parse_occurrence_id(options["occurrence"]) if options.get("occurrence") else None
          original_ics, etag = get_item(href)
          ics = update_event_calendar(
              parse_calendar_for_edit(original_ics),
              new_day,
              title,
              start_clock,
              end_clock,
              parse_repeat(options.get("repeat")),
              occurrence,
          )
          save_undo({"mode": "restore", "href": href, "ics": original_ics, "etag": put_item(href, ics, etag)})
          print(json.dumps({"ok": True, "type": "event", "edited": True, "undoable": True}))

      def delete_item(args):
          options, args = split_options(args, {"occurrence"})
          if len(args) != 1:
              raise RuntimeError("Usage: quickshell-calendar delete-item [--occurrence=id] href")
          href = writable_href(args[0])
          original_ics, etag = get_item(href)
          ics = None
          if options.get("occurrence"):
              occurrence = parse_occurrence_id(options["occurrence"])
              ics = delete_occurrence_calendar(parse_calendar_for_edit(original_ics), occurrence)
          if ics is None:
              delete_href(href, etag)
              new_etag = None
          else:
              new_etag = put_item(href, ics, etag)
          save_undo({"mode": "restore", "href": href, "ics": original_ics, "etag": new_etag})
          print(json.dumps({"ok": True, "deleted": True, "occurrence": ics is not None, "undoable": True}))

      def undo_last_change():
          try:
              payload = json.loads(UNDO_FILE.read_text(encoding="utf-8"))
          except FileNotFoundError as error:
              raise RuntimeError("Nothing to undo") from error
          mode = payload.get("mode")
          href = writable_href(payload.get("href", ""))
          if mode == "created":
              delete_href(href, payload.get("etag"), ok=(200, 202, 204, 404))
          elif mode == "restore":
              ics = payload.get("ics")
              if not ics:
                  raise RuntimeError("Undo data is missing calendar content")
              put_item(href, ics, payload.get("etag"))
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
          request_json("POST", NOTES_API, {
              "content": content,
              "category": "Calendar",
          }, ok=(200, 201))
          print(json.dumps({"ok": True, "type": "note"}))

      def open_note(args):
          if len(args) != 1 or not str(args[0]).strip():
              raise RuntimeError("Usage: quickshell-calendar open-note note-id")
          note_id = quote(str(args[0]).strip(), safe="")
          url = urljoin(BASE_URL, f"{WEBROOT}/index.php/apps/notes/#/notes/{note_id}")
          subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
          print(json.dumps({"ok": True, "type": "note", "opened": True}))

      def event_identity(item):
          normalized_title = unicodedata.normalize(
              "NFKC",
              str(item.get("title") or ""),
          ).casefold()
          normalized_title = re.sub(r"\s+", " ", normalized_title).strip()
          kind = "task" if item.get("task") else "note" if item.get("note") else "event"
          return (
              kind,
              normalized_title,
              item.get("date") or "",
              item.get("startTime") or "",
          )

      def merge_obsidian_events(events, obsidian_items):
          merged = list(events)
          for obsidian_item in obsidian_items:
              identity = event_identity(obsidian_item)
              mirror_indexes = [
                  index for index, existing in enumerate(merged)
                  if existing.get("obsidianPath")
                  and event_identity(existing) == identity
              ]
              if not mirror_indexes:
                  merged.append(obsidian_item)
                  continue

              if not obsidian_item.get("birthday"):
                  continue

              marked_birthday_exists = any(
                  merged[index].get("birthday")
                  for index in mirror_indexes
              )
              for index in reversed(mirror_indexes):
                  if not marked_birthday_exists or not merged[index].get("birthday"):
                      del merged[index]
              if not marked_birthday_exists:
                  merged.append(obsidian_item)
          return merged

      def read_cache():
          try:
              payload = json.loads(CACHE_FILE.read_text(encoding="utf-8"))
          except (OSError, ValueError):
              return {}
          return payload if isinstance(payload, dict) else {}

      def write_cache(payload):
          try:
              CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
              temporary = CACHE_FILE.with_suffix(".json.tmp")
              temporary.write_text(json.dumps(payload), encoding="utf-8")
              temporary.replace(CACHE_FILE)
          except OSError:
              pass

      def query():
          task_lists = []
          error = ""
          stale_since = None
          calendar_items = None
          notes = None
          try:
              calendar_items, task_lists = nextcloud_events()
              notes = nextcloud_notes()
          except Exception as exc:
              error = str(exc)
          cache = read_cache()
          if calendar_items is None:
              # lenovo is often unreachable (asleep, tailnet down). Show the
              # last good copy marked stale instead of birthdays only.
              calendar_items = cache.get("events") or []
              task_lists = cache.get("taskLists") or []
              notes = cache.get("notes") or []
              stale_since = cache.get("savedAt") or ""
          else:
              if notes is None:
                  notes = cache.get("notes") or []
              write_cache({
                  "savedAt": datetime.now().astimezone().isoformat(timespec="seconds"),
                  "events": calendar_items,
                  "taskLists": task_lists,
                  "notes": notes,
              })
          events = calendar_items + notes
          try:
              obsidian_source_events = all_obsidian_events()
              write_obsidian_index(obsidian_source_events)
              events = merge_obsidian_events(
                  events,
                  obsidian_events([
                      event for event in obsidian_source_events
                      if event.get("birthday")
                  ]),
              )
          except Exception as exc:
              # A partly broken source (a vault file that is not UTF-8, an
              # unreadable index) must not take the whole widget down with an
              # empty stdout; report it the same way network errors are.
              error = error or str(exc)
          events.sort(key=lambda item: (
              item.get("date", ""),
              item.get("startTime") or "",
              item.get("title", ""),
          ))
          output = {
              "today": date.today().isoformat(),
              "events": events,
              "taskLists": task_lists,
              "canUndo": UNDO_FILE.is_file(),
          }
          if stale_since is not None:
              output["stale"] = True
              output["staleSince"] = stale_since
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
              elif action == "add-overall-task":
                  add_overall_task(sys.argv[2:])
              elif action == "edit-overall-task":
                  edit_overall_task(sys.argv[2:])
              elif action == "create-task-list":
                  create_task_list(sys.argv[2:])
              elif action == "delete-task-list":
                  delete_task_list(sys.argv[2:])
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
                  raise RuntimeError("Usage: quickshell-calendar [query|add-task|add-overall-task|edit-overall-task|create-task-list|delete-task-list|add-event|complete-task|edit-task|edit-event|delete-item|undo|add-note|open-note|sync-obsidian]")
          except Exception as exc:
              print(json.dumps({"ok": False, "error": str(exc)}))
              raise SystemExit(1)

      main()
PY
