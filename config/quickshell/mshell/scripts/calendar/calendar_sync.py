#!/usr/bin/env python3
"""
calendar_sync.py - Sync Google Calendar & Holiday feeds for Quickshell Island.qml
Fetches iCal (.ics) URLs, parses events and recurring occurrences, and outputs
structured JSON for the calendar and agenda views.
"""

import sys
import os
import json
import time
import re
import urllib.request
import datetime
from pathlib import Path

try:
    from dateutil import rrule
    HAS_RRULE = True
except ImportError:
    HAS_RRULE = False

SCRIPT_DIR = Path(__file__).resolve().parent
CONFIG_PATH = SCRIPT_DIR / "calendar_config.json"
LOCAL_CONFIG_PATH = SCRIPT_DIR / "calendar_config.local.json"
CACHE_PATH = Path("/tmp/island_calendar_cache.json")

DEFAULT_CONFIG = {
    "google_calendar_url": "",
    "holiday_calendar_url": "",
    "custom_calendars": [],
    "cache_ttl_minutes": 20
}

def load_or_create_config():
    target_path = LOCAL_CONFIG_PATH if LOCAL_CONFIG_PATH.exists() else CONFIG_PATH
    if not target_path.exists():
        try:
            with open(CONFIG_PATH, "w", encoding="utf-8") as f:
                json.dump(DEFAULT_CONFIG, f, indent=4)
        except Exception:
            pass
        return DEFAULT_CONFIG

    try:
        with open(target_path, "r", encoding="utf-8") as f:
            cfg = json.load(f)
            # Ensure required keys
            for k, v in DEFAULT_CONFIG.items():
                if k not in cfg:
                    cfg[k] = v
            return cfg
    except Exception:
        return DEFAULT_CONFIG

def unescape_ics_text(text: str) -> str:
    if not text:
        return ""
    text = text.replace(r"\,", ",")
    text = text.replace(r"\;", ";")
    text = text.replace(r"\\", "\\")
    text = text.replace(r"\n", " ").replace(r"\N", " ")
    return text.strip()

def fetch_url(url: str, timeout: int = 8) -> str:
    if not url or not url.strip():
        return ""
    try:
        req = urllib.request.Request(
            url.strip(),
            headers={"User-Agent": "Mozilla/5.0 (compatible; QuickshellCalendar/1.0)"}
        )
        with urllib.request.urlopen(req, timeout=timeout) as response:
            return response.read().decode("utf-8", errors="ignore")
    except Exception as e:
        sys.stderr.write(f"[CalendarSync] Failed to fetch {url}: {e}\n")
        return ""

def parse_ics_datetime(val_str: str, local_tz):
    """
    Parses DTSTART / DTEND strings like:
    - 20261005 (all-day date)
    - 20261005T093000Z (UTC datetime)
    - 20261005T150000 (naive datetime)
    Returns (datetime_obj, is_all_day)
    """
    val_str = val_str.strip()
    if len(val_str) == 8 and val_str.isdigit():
        dt = datetime.datetime.strptime(val_str, "%Y%m%d")
        return dt, True
    
    # Check for UTC 'Z'
    if val_str.endswith("Z"):
        clean_str = val_str[:-1]
        try:
            dt = datetime.datetime.strptime(clean_str, "%Y%m%dT%H%M%S")
            dt = dt.replace(tzinfo=datetime.timezone.utc).astimezone(local_tz)
            return dt, False
        except ValueError:
            pass

    # Standard YYYYMMDDTHHMMSS
    if "T" in val_str:
        clean_str = val_str.split("T")[0] + "T" + val_str.split("T")[1][:6]
        try:
            dt = datetime.datetime.strptime(clean_str, "%Y%m%dT%H%M%S")
            # Treat naive as local timezone
            dt = dt.replace(tzinfo=local_tz)
            return dt, False
        except ValueError:
            pass

    # Fallback to date
    try:
        dt = datetime.datetime.strptime(val_str[:8], "%Y%m%d")
        return dt, True
    except Exception:
        return None, True

def parse_vevent_block(block: str, local_tz, window_start, window_end, source_name, source_color, is_holiday):
    events = []
    
    # Extract SUMMARY
    sum_m = re.search(r"^SUMMARY(?::|;[^\r\n:]*:)(.*)$", block, re.MULTILINE)
    summary = unescape_ics_text(sum_m.group(1)) if sum_m else "Untitled Event"
    
    # Extract LOCATION
    loc_m = re.search(r"^LOCATION(?::|;[^\r\n:]*:)(.*)$", block, re.MULTILINE)
    location = unescape_ics_text(loc_m.group(1)) if loc_m else ""
    
    # Extract DESCRIPTION
    desc_m = re.search(r"^DESCRIPTION(?::|;[^\r\n:]*:)(.*)$", block, re.MULTILINE)
    description = unescape_ics_text(desc_m.group(1)) if desc_m else ""
    
    # Extract DTSTART
    dtstart_m = re.search(r"^DTSTART(?::|;[^\r\n:]*:)(.*)$", block, re.MULTILINE)
    if not dtstart_m:
        return events
    raw_start = dtstart_m.group(1).strip()
    start_dt, is_all_day = parse_ics_datetime(raw_start, local_tz)
    if not start_dt:
        return events

    # Extract DTEND
    dtend_m = re.search(r"^DTEND(?::|;[^\r\n:]*:)(.*)$", block, re.MULTILINE)
    if dtend_m:
        end_dt, _ = parse_ics_datetime(dtend_m.group(1).strip(), local_tz)
    else:
        end_dt = start_dt + (datetime.timedelta(days=1) if is_all_day else datetime.timedelta(hours=1))

    duration = end_dt - start_dt if end_dt else datetime.timedelta(hours=1)

    # Check for RRULE
    rrule_m = re.search(r"^RRULE:(.*)$", block, re.MULTILINE)
    if rrule_m and HAS_RRULE:
        rrule_str = rrule_m.group(1).strip()
        try:
            # rrulestr requires naive or uniformly tz-aware dtstart
            naive_start = start_dt.replace(tzinfo=None) if start_dt.tzinfo else start_dt
            naive_win_start = window_start.replace(tzinfo=None)
            naive_win_end = window_end.replace(tzinfo=None)
            
            # If UNTIL has 'Z' while dtstart is naive, strip 'Z' to avoid dateutil tz mismatch error
            clean_rrule = re.sub(r"(UNTIL=\d{8}(?:T\d{6})?)Z", r"\1", rrule_str)
            rule = rrule.rrulestr(clean_rrule, dtstart=naive_start)
            occurrences = rule.between(naive_win_start, naive_win_end, inc=True)
            for occ in occurrences:
                if start_dt.tzinfo:
                    occ_dt = occ.replace(tzinfo=local_tz)
                else:
                    occ_dt = occ
                occ_end = occ_dt + duration
                
                date_key = occ_dt.strftime("%Y-%m-%d")
                time_str = "All day" if is_all_day else f"{occ_dt.strftime('%H:%M')} - {occ_end.strftime('%H:%M')}"
                
                events.append({
                    "title": summary,
                    "date": date_key,
                    "time": time_str,
                    "isAllDay": is_all_day,
                    "isHoliday": is_holiday,
                    "location": location,
                    "source": source_name,
                    "color": source_color,
                    "timestamp": int(occ_dt.timestamp()) if hasattr(occ_dt, "timestamp") else 0
                })
            return events
        except Exception as e:
            sys.stderr.write(f"[CalendarSync] Error expanding RRULE for '{summary}': {e}\n")

    # Single Event (non-recurring)
    # Check if within window
    naive_start = start_dt.replace(tzinfo=None) if start_dt.tzinfo else start_dt
    naive_win_start = window_start.replace(tzinfo=None)
    naive_win_end = window_end.replace(tzinfo=None)
    
    if naive_win_start <= naive_start <= naive_win_end:
        date_key = start_dt.strftime("%Y-%m-%d")
        time_str = "All day" if is_all_day else f"{start_dt.strftime('%H:%M')} - {end_dt.strftime('%H:%M')}"
        events.append({
            "title": summary,
            "date": date_key,
            "time": time_str,
            "isAllDay": is_all_day,
            "isHoliday": is_holiday,
            "location": location,
            "source": source_name,
            "color": source_color,
            "timestamp": int(start_dt.timestamp()) if hasattr(start_dt, "timestamp") else 0
        })

    return events

def parse_ics_feed(ics_content: str, local_tz, window_start, window_end, source_name, source_color, is_holiday):
    if not ics_content:
        return []
    # RFC 5545 unfolding: replace CRLF followed by space/tab
    unfolded = re.sub(r"\r?\n[ \t]", "", ics_content)
    
    all_events = []
    # Match every VEVENT block
    pattern = re.compile(r"BEGIN:VEVENT.*?END:VEVENT", re.DOTALL)
    for match in pattern.finditer(unfolded):
        block = match.group(0)
        evs = parse_vevent_block(block, local_tz, window_start, window_end, source_name, source_color, is_holiday)
        all_events.extend(evs)
    return all_events

def main():
    force = "--force" in sys.argv
    config = load_or_create_config()
    cache_ttl = int(config.get("cache_ttl_minutes", 20)) * 60

    # Check cache if not forcing and configs haven't changed
    if not force and CACHE_PATH.exists():
        try:
            mtime = CACHE_PATH.stat().st_mtime
            cfg_mtime = max(
                LOCAL_CONFIG_PATH.stat().st_mtime if LOCAL_CONFIG_PATH.exists() else 0,
                CONFIG_PATH.stat().st_mtime if CONFIG_PATH.exists() else 0
            )
            if (time.time() - mtime) < cache_ttl and mtime > cfg_mtime and CACHE_PATH.stat().st_size > 10:
                with open(CACHE_PATH, "r", encoding="utf-8") as f:
                    print(f.read())
                    return
        except Exception:
            pass

    # Build calendar list to fetch
    calendars = []
    
    # 1. Holidays
    holiday_url = config.get("holiday_calendar_url", "").strip()
    if holiday_url:
        calendars.append({
            "name": "Holidays",
            "url": holiday_url,
            "color": "#f9e2af",
            "isHoliday": True
        })

    # 2. Personal Google Calendar
    google_url = config.get("google_calendar_url", "").strip()
    if google_url:
        calendars.append({
            "name": "Personal",
            "url": google_url,
            "color": "#cba6f7",
            "isHoliday": False
        })

    # 3. Custom calendars (strings or objects)
    for c in config.get("custom_calendars", []):
        if isinstance(c, str) and c.strip():
            calendars.append({
                "name": "Calendar",
                "url": c.strip(),
                "color": "#89b4fa",
                "isHoliday": False
            })
        elif isinstance(c, dict) and c.get("url"):
            calendars.append({
                "name": c.get("name", "Calendar"),
                "url": c.get("url", "").strip(),
                "color": c.get("color", "#89b4fa"),
                "isHoliday": c.get("isHoliday", False)
            })

    local_now = datetime.datetime.now().astimezone()
    local_tz = local_now.tzinfo
    # Time window: 45 days back to 90 days ahead
    window_start = local_now - datetime.timedelta(days=45)
    window_end = local_now + datetime.timedelta(days=90)

    events_by_date = {}
    all_events_list = []

    for cal in calendars:
        url = cal["url"]
        content = fetch_url(url)
        if content:
            cal_events = parse_ics_feed(
                content,
                local_tz,
                window_start,
                window_end,
                source_name=cal["name"],
                source_color=cal["color"],
                is_holiday=cal["isHoliday"]
            )
            for ev in cal_events:
                d_key = ev["date"]
                if d_key not in events_by_date:
                    events_by_date[d_key] = []
                # Avoid duplicate events (same title and date)
                if not any(e["title"] == ev["title"] and e["time"] == ev["time"] for e in events_by_date[d_key]):
                    events_by_date[d_key].append(ev)
                    all_events_list.append(ev)

    # Sort events within each date: all-day / holidays first, then by time
    for d_key in events_by_date:
        events_by_date[d_key].sort(key=lambda x: (not x["isHoliday"], not x["isAllDay"], x["time"]))

    # Find upcoming events (today onward, max 15)
    today_key = local_now.strftime("%Y-%m-%d")
    upcoming = [e for e in all_events_list if e["date"] >= today_key]
    upcoming.sort(key=lambda x: (x["date"], not x["isHoliday"], not x["isAllDay"], x["time"]))
    upcoming = upcoming[:15]

    has_personal_calendar = bool(google_url) or bool(config.get("custom_calendars"))

    result = {
        "eventsByDate": events_by_date,
        "upcoming": upcoming,
        "today": events_by_date.get(today_key, []),
        "hasPersonalCalendar": has_personal_calendar,
        "lastUpdated": local_now.strftime("%Y-%m-%d %H:%M:%S")
    }

    output_json = json.dumps(result)
    
    # Save to cache
    try:
        with open(CACHE_PATH, "w", encoding="utf-8") as f:
            f.write(output_json)
    except Exception as e:
        sys.stderr.write(f"[CalendarSync] Failed to write cache: {e}\n")

    print(output_json)

if __name__ == "__main__":
    main()
