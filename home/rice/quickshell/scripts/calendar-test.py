"""Offline tests for calendar.sh. Run with a python that has icalendar and
recurring-ical-events, e.g. the calendarPython env from ../default.nix."""

import hashlib
import io
import json
import os
import re
import sys
import tempfile
import time as time_module
from contextlib import redirect_stdout
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from urllib.error import HTTPError

from icalendar import Calendar
import recurring_ical_events

SCRIPT = Path(__file__).with_name("calendar.sh")
HOME = tempfile.mkdtemp(prefix="calendar-test-")
os.environ["HOME"] = HOME
os.environ["XDG_CACHE_HOME"] = str(Path(HOME) / "cache")
os.environ["USER"] = "tester"
os.environ["TZ"] = "Europe/Warsaw"
time_module.tzset()


def load():
    text = SCRIPT.read_text(encoding="utf-8")
    body = text.split("<<'PY'\n", 1)[1].rsplit("\nPY", 1)[0]
    body = body.rstrip()
    assert body.endswith("main()")
    namespace = {"__name__": "calendar_under_test"}
    exec(compile(body[: -len("main()")], str(SCRIPT), "exec"), namespace)
    return namespace


cal = load()
HOME_HREF = cal["CALENDAR_HOME"]
EVENT_HREF = f"{HOME_HREF}personal/series.ics"
TASK_HREF = f"{HOME_HREF}tasks/task.ics"
store = {}
calls = []


def etag_of(path):
    return f'"{hashlib.md5(store[path].encode("utf-8")).hexdigest()[:8]}"' if path in store else None


def fake_request(method, path, body=None, headers=None, ok=(200, 201, 204, 207), retried=False, want_etag=False):
    calls.append((method, path, dict(headers or {})))
    if method == "GET":
        payload = store[path].encode("utf-8")
    elif method == "PUT":
        store[path] = body
        payload = b""
    elif method == "DELETE":
        store.pop(path, None)
        payload = b""
    else:
        raise AssertionError(f"unexpected {method}")
    return (payload, etag_of(path)) if want_etag else payload


cal["request"] = fake_request
cal["choose_task_calendar"] = lambda _list_id=None: {"href": f"{HOME_HREF}tasks/"}
cal["choose_calendar"] = lambda _component: {"href": f"{HOME_HREF}personal/"}


def run(command, *args):
    output = io.StringIO()
    with redirect_stdout(output):
        cal[command](list(args))
    return json.loads(output.getvalue())


def crlf(text):
    return "\r\n".join(line.strip() for line in text.strip().splitlines()) + "\r\n"


SERIES = crlf("""
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//phone//EN
BEGIN:VTIMEZONE
TZID:Europe/Warsaw
BEGIN:STANDARD
DTSTART:19701025T030000
RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU
TZOFFSETFROM:+0200
TZOFFSETTO:+0100
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19700329T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU
TZOFFSETFROM:+0100
TZOFFSETTO:+0200
END:DAYLIGHT
END:VTIMEZONE
BEGIN:VEVENT
UID:series-1
DTSTAMP:20261001T000000Z
DTSTART;TZID=Europe/Warsaw:20261102T100000
DTEND;TZID=Europe/Warsaw:20261102T110000
RRULE:FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20261231T225959Z
EXDATE;TZID=Europe/Warsaw:20261104T100000
SUMMARY:Lecture
LOCATION:Room 1
X-PHONE-COLOR:#ff0000
BEGIN:VALARM
ACTION:DISPLAY
DESCRIPTION:Lecture
TRIGGER:-PT15M
END:VALARM
END:VEVENT
BEGIN:VEVENT
UID:series-1
DTSTAMP:20261001T000000Z
RECURRENCE-ID;TZID=Europe/Warsaw:20261109T100000
DTSTART;TZID=Europe/Warsaw:20261109T120000
DTEND;TZID=Europe/Warsaw:20261109T130000
SUMMARY:Lecture moved
END:VEVENT
END:VCALENDAR
""")


def master_of(ics):
    calendar = Calendar.from_ical(ics)
    master = next(item for item in calendar.walk("VEVENT") if item.get("RECURRENCE-ID") is None)
    return calendar, master


def occurrence_starts(ics, start=date(2026, 11, 1), end=date(2026, 12, 1)):
    calendar = Calendar.from_ical(ics)
    return sorted(
        item["DTSTART"].dt.astimezone(timezone.utc).strftime("%Y-%m-%d %H:%M")
        for item in recurring_ical_events.of(calendar).between(start, end)
    )


def test_edit_title_preserves_series():
    store[EVENT_HREF] = SERIES
    before = occurrence_starts(SERIES)
    run("edit_event", "--occurrence=20261111T090000Z", EVENT_HREF, "2026-11-11", "Lecture 2", "10:00", "11:00")
    calendar, master = master_of(store[EVENT_HREF])
    assert str(master["SUMMARY"]) == "Lecture 2"
    assert master["RRULE"]["BYDAY"] == ["MO", "WE"]
    assert master["DTSTART"].dt == datetime(2026, 11, 2, 10, 0, tzinfo=cal["LOCAL_TZ"])
    assert [value.dt.day for value in master["EXDATE"].dts] == [4]
    assert str(master["LOCATION"]) == "Room 1"
    assert str(master["X-PHONE-COLOR"]) == "#ff0000"
    assert len(master.walk("VALARM")) == 1
    exceptions = [item for item in calendar.walk("VEVENT") if item.get("RECURRENCE-ID") is not None]
    assert len(exceptions) == 1 and str(exceptions[0]["SUMMARY"]) == "Lecture moved"
    assert occurrence_starts(store[EVENT_HREF]) == before


def test_edit_time_moves_exdate_and_exceptions():
    store[EVENT_HREF] = SERIES
    run("edit_event", "--occurrence=20261111T090000Z", EVENT_HREF, "2026-11-11", "Lecture", "12:00", "13:30")
    calendar, master = master_of(store[EVENT_HREF])
    assert master["DTSTART"].dt.hour == 12
    assert master["DTEND"].dt - master["DTSTART"].dt == timedelta(minutes=90)
    assert [value.dt.hour for value in master["EXDATE"].dts] == [12]
    exception = next(item for item in calendar.walk("VEVENT") if item.get("RECURRENCE-ID") is not None)
    assert exception["RECURRENCE-ID"].dt.hour == 12
    starts = occurrence_starts(store[EVENT_HREF])
    assert "2026-11-04 11:00" not in starts
    assert starts.count("2026-11-09 11:00") == 1
    assert len(master.walk("VALARM")) == 1


def test_day_shift_of_custom_series_is_refused():
    store[EVENT_HREF] = SERIES
    try:
        run("edit_event", "--occurrence=20261111T090000Z", EVENT_HREF, "2026-11-12", "Lecture", "10:00", "11:00")
    except RuntimeError as error:
        assert "custom-repeat" in str(error)
    else:
        raise AssertionError("day shift of a BYDAY series was accepted")
    assert store[EVENT_HREF] == SERIES
    run("edit_event", "--occurrence=20261111T090000Z", EVENT_HREF, "2026-11-11", "Lecture", "11:00", "12:00")
    assert "2026-11-04 10:00" not in occurrence_starts(store[EVENT_HREF])


def test_utc_custom_series_time_edit_that_changes_rule_day_is_refused():
    ics = crlf("""
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:x
    BEGIN:VEVENT
    UID:utc-series
    DTSTAMP:20261001T000000Z
    DTSTART:20261102T230000Z
    DTEND:20261103T000000Z
    RRULE:FREQ=WEEKLY;BYDAY=MO
    EXDATE:20261109T230000Z
    SUMMARY:Late
    END:VEVENT
    END:VCALENDAR
    """)
    store[EVENT_HREF] = ics
    try:
        run("edit_event", EVENT_HREF, "2026-11-03", "Late", "01:00", "02:00")
    except RuntimeError as error:
        assert "custom-repeat" in str(error)
    else:
        raise AssertionError("time edit that moves a UTC BYDAY series to another day was accepted")
    assert store[EVENT_HREF] == ics


def test_no_end_event_gets_end_when_duration_changes():
    ics = crlf("""
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:x
    BEGIN:VEVENT
    UID:point2
    DTSTAMP:20261001T000000Z
    DTSTART:20261105T090000Z
    SUMMARY:Call
    END:VEVENT
    END:VCALENDAR
    """)
    store[EVENT_HREF] = ics
    run("edit_event", EVENT_HREF, "2026-11-05", "Call", "10:00", "12:00")
    event = Calendar.from_ical(store[EVENT_HREF]).walk("VEVENT")[0]
    assert event["DTEND"].dt - event["DTSTART"].dt == timedelta(hours=2)


def test_day_shift_of_plain_weekly_series():
    plain = SERIES.replace("RRULE:FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20261231T225959Z", "RRULE:FREQ=WEEKLY").replace(
        "EXDATE;TZID=Europe/Warsaw:20261104T100000", "EXDATE;TZID=Europe/Warsaw:20261116T100000"
    )
    store[EVENT_HREF] = plain
    assert "2026-11-16 09:00" not in occurrence_starts(plain)
    run("edit_event", "--occurrence=20261123T090000Z", EVENT_HREF, "2026-11-24", "Lecture", "10:00", "11:00")
    calendar, master = master_of(store[EVENT_HREF])
    assert master["DTSTART"].dt.date() == date(2026, 11, 3)
    assert [value.dt.date() for value in master["EXDATE"].dts] == [date(2026, 11, 17)]
    exception = next(item for item in calendar.walk("VEVENT") if item.get("RECURRENCE-ID") is not None)
    assert exception["RECURRENCE-ID"].dt.date() == date(2026, 11, 10)
    starts = occurrence_starts(store[EVENT_HREF])
    assert "2026-11-17 09:00" not in starts
    assert starts.count("2026-11-09 11:00") == 1 and "2026-11-10 09:00" not in starts


def test_repeat_on_override_is_refused():
    store[EVENT_HREF] = SERIES
    try:
        run("edit_event", "--repeat=daily", "--occurrence=20261109T090000Z", EVENT_HREF, "2026-11-09", "Lecture moved", "12:00", "13:00")
    except RuntimeError as error:
        assert "on its own" in str(error)
    else:
        raise AssertionError("repeat change on an override was accepted")
    assert store[EVENT_HREF] == SERIES


def test_recurring_flag_and_override():
    single = crlf("""
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:x
    BEGIN:VEVENT
    UID:single
    DTSTART:20261105T090000Z
    DTEND:20261105T100000Z
    SUMMARY:Dentist
    END:VEVENT
    END:VCALENDAR
    """)
    namespace = load()
    namespace["discover_calendars"] = lambda: [{"href": f"{HOME_HREF}personal/", "displayName": "Cal", "components": {"VEVENT"}, "readOnly": False}]
    namespace["calendar_report"] = lambda _collection, _component, time_range=True: [
        {"href": f"{HOME_HREF}personal/single.ics", "etag": "", "data": single},
        {"href": EVENT_HREF, "etag": "", "data": SERIES},
    ]
    events, _lists = namespace["nextcloud_events"]()
    dentist = next(item for item in events if item["uid"] == "single")
    assert (dentist["recurring"], dentist["recurrenceId"], dentist["override"]) == (False, None, False)
    lectures = {item["date"]: item for item in events if item["uid"] == "series-1"}
    assert lectures["2026-11-11"]["recurring"] and not lectures["2026-11-11"]["override"]
    assert lectures["2026-11-09"]["override"] and lectures["2026-11-09"]["recurrenceId"] == "20261109T090000Z"


def test_complex_rrule_kept_unless_changed():
    store[EVENT_HREF] = SERIES
    run("edit_event", EVENT_HREF, "2026-11-02", "Lecture", "10:00", "11:00")
    _calendar, master = master_of(store[EVENT_HREF])
    assert cal["repeat_choice"](master) == "custom"
    assert master["RRULE"]["UNTIL"]
    run("edit_event", "--repeat=daily", EVENT_HREF, "2026-11-02", "Lecture", "10:00", "11:00")
    _calendar, master = master_of(store[EVENT_HREF])
    assert cal["repeat_choice"](master) == "daily"
    assert len(master.walk("VALARM")) == 1


def test_delete_one_occurrence():
    store[EVENT_HREF] = SERIES
    before = occurrence_starts(SERIES)
    result = run("delete_item", "--occurrence=20261111T090000Z", EVENT_HREF)
    assert result["occurrence"] is True
    after = occurrence_starts(store[EVENT_HREF])
    assert "2026-11-11 09:00" in before and "2026-11-11 09:00" not in after
    assert len(after) == len(before) - 1
    _calendar, master = master_of(store[EVENT_HREF])
    assert master["RRULE"] and len(master.walk("VALARM")) == 1
    run("delete_item", "--occurrence=20261109T090000Z", EVENT_HREF)
    calendar = Calendar.from_ical(store[EVENT_HREF])
    assert not [item for item in calendar.walk("VEVENT") if item.get("RECURRENCE-ID") is not None]
    run("delete_item", EVENT_HREF)
    assert EVENT_HREF not in store


def test_new_event_has_vtimezone_and_repeat():
    store.clear()
    run("add_event", "--repeat=weekly", "2026-11-05", "Gym", "18:00", "19:00")
    (href, ics), = store.items()
    calendar = Calendar.from_ical(ics)
    assert [str(item["TZID"]) for item in calendar.walk("VTIMEZONE")] == ["Europe/Warsaw"]
    event = calendar.walk("VEVENT")[0]
    assert str(event["RRULE"].to_ical().decode()) == "FREQ=WEEKLY"
    summer = occurrence_starts(ics, date(2027, 6, 1), date(2027, 6, 8))
    assert summer == ["2027-06-03 16:00"], summer


def test_task_start_and_repeat_written():
    store.clear()
    run("add_overall_task", "--start=2026-11-03", "--repeat=weekly", f"{HOME_HREF}tasks/", "2026-11-06", "Report")
    (href, ics), = store.items()
    assert "DTSTART;VALUE=DATE:20261103" in ics
    assert "DUE;VALUE=DATE:20261106" in ics
    assert "RRULE:FREQ=WEEKLY" in ics


TASK = crlf("""
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//phone//EN
BEGIN:VTODO
UID:task-1
DTSTAMP:20261001T000000Z
SUMMARY:Laundry
DTSTART;VALUE=DATE:20261102
DUE;VALUE=DATE:20261104
RRULE:FREQ=WEEKLY
X-TASKS-ORG-ORDER:5
CATEGORIES:home
BEGIN:VALARM
ACTION:DISPLAY
TRIGGER;RELATED=END:-PT1H
END:VALARM
END:VTODO
END:VCALENDAR
""")


def todo_of(ics):
    return Calendar.from_ical(ics).walk("VTODO")[0]


def test_task_edit_keeps_dtstart_and_unknown():
    store[TASK_HREF] = TASK
    run("edit_overall_task", TASK_HREF, "2026-11-05", "Laundry and ironing")
    todo = todo_of(store[TASK_HREF])
    assert todo["DTSTART"].dt == date(2026, 11, 2)
    assert todo["DUE"].dt == date(2026, 11, 5)
    assert str(todo["SUMMARY"]) == "Laundry and ironing"
    assert str(todo["X-TASKS-ORG-ORDER"]) == "5"
    assert todo["RRULE"] and len(todo.walk("VALARM")) == 1
    run("edit_task", TASK_HREF, "2026-11-05", "Laundry")
    assert todo_of(store[TASK_HREF])["DTSTART"].dt == date(2026, 11, 2)
    run("edit_overall_task", "--start=-", "--repeat=none", TASK_HREF, "2026-11-05", "Laundry")
    todo = todo_of(store[TASK_HREF])
    assert todo.get("DTSTART") is None and todo.get("RRULE") is None
    try:
        run("edit_overall_task", "--start=2026-11-09", TASK_HREF, "2026-11-05", "Laundry")
    except RuntimeError as error:
        assert "after the due date" in str(error)
    else:
        raise AssertionError("start after due was accepted")


def test_complete_repeating_task_advances():
    store[TASK_HREF] = TASK
    result = run("complete_task", TASK_HREF)
    assert result["advanced"] is True
    todo = todo_of(store[TASK_HREF])
    assert todo["DUE"].dt == date(2026, 11, 11)
    assert todo["DTSTART"].dt == date(2026, 11, 9)
    assert str(todo["STATUS"]) == "NEEDS-ACTION"
    assert todo["RRULE"]


def test_task_span_and_recurrence_days():
    calendar = Calendar.from_ical(TASK)
    item = cal["parse_todo"](calendar.walk("VTODO")[0], "Tasks", "list", TASK_HREF, None, calendar)
    assert (item["date"], item["spanStart"], item["startDate"]) == ("2026-11-04", "2026-11-02", "2026-11-02")
    assert item["repeat"] == "weekly"
    for day in ("2026-11-09", "2026-11-10", "2026-11-11", "2026-11-16"):
        assert item["coverDays"].get(day), day
    assert "2026-11-07" not in item["coverDays"]
    assert "2026-11-04" not in item["coverDays"]


def test_multi_day_events():
    ics = crlf("""
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:x
    BEGIN:VEVENT
    UID:trip
    DTSTART;VALUE=DATE:20261103
    DTEND;VALUE=DATE:20261106
    SUMMARY:Trip
    END:VEVENT
    BEGIN:VEVENT
    UID:night
    DTSTART:20261107T200000Z
    DTEND:20261108T230000Z
    SUMMARY:Party
    END:VEVENT
    BEGIN:VEVENT
    UID:single
    DTSTART;VALUE=DATE:20261110
    DTEND;VALUE=DATE:20261111
    SUMMARY:One day
    END:VEVENT
    END:VCALENDAR
    """)
    parsed = {
        item["uid"]: item
        for item in (cal["parse_event"](component, "Cal") for component in Calendar.from_ical(ics).walk("VEVENT"))
    }
    assert (parsed["trip"]["date"], parsed["trip"]["spanEnd"]) == ("2026-11-03", "2026-11-05")
    assert (parsed["night"]["date"], parsed["night"]["spanEnd"]) == ("2026-11-07", "2026-11-08")
    assert parsed["single"]["spanEnd"] is None


def test_midnight_timezone():
    ics = crlf("""
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:x
    BEGIN:VEVENT
    UID:late
    DTSTART:20261103T233000Z
    DTEND:20261104T003000Z
    SUMMARY:Late
    END:VEVENT
    END:VCALENDAR
    """)
    item = cal["parse_event"](Calendar.from_ical(ics).walk("VEVENT")[0], "Cal")
    assert (item["date"], item["startTime"], item["endTime"], item["spanEnd"]) == ("2026-11-04", "00:30", "01:30", None)


def test_broken_item_is_refused():
    store[EVENT_HREF] = SERIES.replace("LOCATION:Room 1", "GEO:not,a-number")
    before = store[EVENT_HREF]
    try:
        run("edit_event", EVENT_HREF, "2026-11-02", "Lecture", "10:00", "11:00")
    except RuntimeError as error:
        assert "without loss" in str(error)
    else:
        raise AssertionError("broken item was rewritten")
    assert store[EVENT_HREF] == before


def test_untimed_end_stays_absent():
    ics = crlf("""
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:x
    BEGIN:VEVENT
    UID:point
    DTSTAMP:20261001T000000Z
    DTSTART:20261105T090000Z
    SUMMARY:Call
    END:VEVENT
    END:VCALENDAR
    """)
    store[EVENT_HREF] = ics
    run("edit_event", EVENT_HREF, "2026-11-05", "Call mom", "10:00", "11:00")
    calendar = Calendar.from_ical(store[EVENT_HREF])
    event = calendar.walk("VEVENT")[0]
    assert str(event["SUMMARY"]) == "Call mom"
    assert event.get("DTEND") is None and event.get("DURATION") is None
    assert event.get("SEQUENCE") is None
    assert not calendar.walk("VTIMEZONE")


def test_writes_send_if_match_and_undo_keeps_etag():
    store[EVENT_HREF] = SERIES
    original = etag_of(EVENT_HREF)
    calls.clear()
    run("edit_event", EVENT_HREF, "2026-11-02", "Lecture 3", "10:00", "11:00")
    put = next(call for call in calls if call[0] == "PUT")
    assert put[2]["If-Match"] == original
    saved = json.loads(cal["UNDO_FILE"].read_text())
    assert saved["etag"] == etag_of(EVENT_HREF) != original
    calls.clear()
    with redirect_stdout(io.StringIO()):
        cal["undo_last_change"]()
    assert calls[0][0] == "PUT" and calls[0][2]["If-Match"] == saved["etag"]
    assert store[EVENT_HREF] == SERIES
    calls.clear()
    run("delete_item", EVENT_HREF)
    assert calls[-1][0] == "DELETE" and calls[-1][2]["If-Match"] == original


def test_412_reports_conflict():
    namespace = load()
    namespace["PASSWORD_FILE"].parent.mkdir(parents=True, exist_ok=True)
    namespace["PASSWORD_FILE"].write_text("secret\n")
    namespace["clear_undo"]()
    seen = []

    class Response:
        status = 200
        headers = {"ETag": '"phone-1"'}

        def __enter__(self):
            return self

        def __exit__(self, *_args):
            return False

        def read(self):
            return SERIES.encode("utf-8")

    def urlopen(request, timeout=None):
        seen.append((request.get_method(), request.get_header("If-match")))
        if request.get_method() == "PUT":
            raise HTTPError(request.full_url, 412, "Precondition Failed", {}, io.BytesIO(b""))
        return Response()

    namespace["urlopen"] = urlopen
    try:
        namespace["edit_event"]([EVENT_HREF, "2026-11-02", "Lecture 4", "10:00", "11:00"])
    except RuntimeError as error:
        assert str(error) == "Changed on another device, refresh and try again"
    else:
        raise AssertionError("412 did not raise")
    assert seen == [("GET", None), ("PUT", '"phone-1"')]
    assert not namespace["UNDO_FILE"].exists()


def test_note_date_from_frontmatter():
    assert cal["note_date"]({"content": "---\ndate: 2026-11-20\n---\n# Exam\n", "modified": 0}) == "2026-11-20"


def test_401_retries_once():
    namespace = load()
    attempts = []
    refreshes = []
    namespace["PASSWORD_FILE"].parent.mkdir(parents=True, exist_ok=True)
    namespace["PASSWORD_FILE"].write_text("old\n")

    def urlopen(_request, timeout=None):
        attempts.append(1)
        raise HTTPError("https://example", 401, "Unauthorized", {}, io.BytesIO(b""))

    namespace["urlopen"] = urlopen
    namespace["refresh_password"] = lambda: refreshes.append(1) or "new"
    try:
        namespace["request"]("GET", "/x")
    except RuntimeError as error:
        assert "401" in str(error)
    else:
        raise AssertionError("401 did not raise")
    assert (len(attempts), len(refreshes)) == (2, 1)


def test_offline_shows_cached_data():
    namespace = load()
    cached = [{"date": "2026-11-05", "title": "Exam", "uid": "exam"}]
    namespace["nextcloud_events"] = lambda: (list(cached), [{"id": "l", "name": "Tasks"}])
    namespace["nextcloud_notes"] = lambda: []
    output = io.StringIO()
    with redirect_stdout(output):
        namespace["query"]()
    assert "stale" not in json.loads(output.getvalue())

    def offline():
        raise RuntimeError("GET failed: timed out")

    namespace["nextcloud_events"] = offline
    output = io.StringIO()
    with redirect_stdout(output):
        namespace["query"]()
    payload = json.loads(output.getvalue())
    assert payload["stale"] is True and payload["staleSince"]
    assert [item["title"] for item in payload["events"]] == ["Exam"]
    assert payload["taskLists"][0]["name"] == "Tasks"
    assert "timed out" in payload["error"]


def main():
    tests = [(name, value) for name, value in globals().items() if name.startswith("test_") and callable(value)]
    failed = 0
    for name, test in tests:
        try:
            test()
        except Exception as error:
            failed += 1
            print(f"FAIL {name}: {type(error).__name__}: {error}")
        else:
            print(f"ok   {name}")
    print(f"{len(tests) - failed}/{len(tests)} passed")
    sys.exit(1 if failed else 0)


main()
