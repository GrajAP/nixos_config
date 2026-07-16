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
      from urllib.parse import quote, urljoin
      from urllib.request import Request, urlopen
      from xml.etree import ElementTree as ET
      from xml.sax.saxutils import escape as escape_xml

      from icalendar import Calendar
      import recurring_ical_events

      USER = environ.get("USER", "grajpap")
      BASE_URL = "http://127.0.0.1:18080"
      CALENDAR_HOME = f"/remote.php/dav/calendars/{USER}/"
      PASSWORD_FILE = Path.home() / ".config/quickshell/nextcloud-app-password"
      UNDO_FILE = Path.home() / ".cache/quickshell/calendar-undo.json"
      EVENTS_FOLDER = Path.home() / "other/Obsidian Vault/obsidian/Events"
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
          if component.get("X-QUICKSHELL-TASK-HREF") or str(component.get("UID", "")).startswith("quickshell-task-"):
              return None
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

      def parse_todo(component, source, task_list_id, href=None, etag=None):
          status = str(component.get("STATUS", "")).upper()
          if status == "CANCELLED":
              return None
          due_prop = component.get("DUE") or component.get("DTSTART")
          due = due_prop.dt if due_prop is not None else None
          item_date = date_value(due) or ""
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
                          parsed = parse_todo(
                              component,
                              collection["displayName"],
                              collection["href"],
                              item["href"],
                              item["etag"],
                          )
                          if parsed:
                              tasks.append(parsed)
          sync_task_mirrors(tasks)
          events.extend(tasks)
          task_lists = [
              {"id": item["href"], "name": item["displayName"]}
              for item in calendars
              if "VTODO" in item["components"]
          ]
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
          candidates = [item for item in calendars if component in item["components"]]
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
              if item["href"] == task_list_id and "VTODO" in item["components"]:
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
          }))

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

      def add_overall_task(args):
          if len(args) < 2:
              raise RuntimeError("Usage: quickshell-calendar add-overall-task task-list-id title")
          task_list_id = args[0]
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
              "STATUS:NEEDS-ACTION",
              "PERCENT-COMPLETE:0",
              "END:VTODO",
              "END:VCALENDAR",
              "",
          ])
          href = put_ics(choose_task_calendar(task_list_id), ics)
          save_undo({"mode": "created", "href": href})
          print(json.dumps({"ok": True, "type": "task", "undated": True, "undoable": True}))

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
          task_lists = []
          error = ""
          try:
              events, task_lists = nextcloud_events()
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
          output = {
              "today": date.today().isoformat(),
              "events": events,
              "taskLists": task_lists,
          }
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
              elif action == "create-task-list":
                  create_task_list(sys.argv[2:])
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
                  raise RuntimeError("Usage: quickshell-calendar [query|add-task|add-overall-task|create-task-list|add-event|complete-task|edit-task|edit-event|delete-item|undo|add-note|open-note|sync-obsidian]")
          except Exception as exc:
              print(json.dumps({"ok": False, "error": str(exc)}))
              raise SystemExit(1)

      main()
PY
