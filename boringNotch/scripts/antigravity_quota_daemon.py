#!/usr/bin/env python3
"""
Antigravity Quota Sync Daemon for Boring Notch.
Monitors Antigravity conversation logs, calculates real-time token/turn usage,
and transmits quota updates directly to Boring Notch (port 9876 & quota.json).
"""

import sys
import os
import json
import time
import socket
import argparse
from datetime import datetime, timezone, timedelta
from pathlib import Path

HOME = Path.home()
BRAIN_DIR = HOME / ".gemini" / "antigravity-ide" / "brain"
QUOTA_FILE_1 = HOME / ".gemini" / "antigravity-ide" / "quota.json"
QUOTA_FILE_2 = HOME / "Library" / "Application Support" / "boringNotch" / "antigravity_quota.json"
BORING_NOTCH_PORT = 9876

DEFAULT_CAP_5H = 100.0
DEFAULT_CAP_WEEKLY = 1000.0

def parse_iso(dt_str):
    try:
        # Support fractional seconds and Z
        dt_str = dt_str.replace("Z", "+00:00")
        return datetime.fromisoformat(dt_str)
    except Exception:
        return None

def compute_usage():
    now = datetime.now(timezone.utc)
    five_hours_ago = now - timedelta(hours=5)
    seven_days_ago = now - timedelta(days=7)

    recent_5h_turns = 0
    recent_7d_turns = 0
    oldest_5h_dt = None

    claude_gpt_turns = 0

    try:
        if BRAIN_DIR.exists():
            for conv_dir in BRAIN_DIR.iterdir():
                if not conv_dir.is_dir():
                    continue
                log_path = conv_dir / ".system_generated" / "logs" / "transcript.jsonl"
                if not log_path.exists():
                    continue

                try:
                    mtime = datetime.fromtimestamp(log_path.stat().st_mtime, tz=timezone.utc)
                    if mtime < seven_days_ago:
                        continue

                    with open(log_path, "r", encoding="utf-8", errors="ignore") as f:
                        for line in f:
                            line_s = line.strip()
                            if not line_s:
                                continue
                            # Turn indicator
                            if any(k in line_s for k in ['"type":"USER_INPUT"', '"type":"MODEL"', '"type":"PLANNER_RESPONSE"', 'tool_calls']):
                                dt = None
                                if '"timestamp":"' in line_s:
                                    try:
                                        part = line_s.split('"timestamp":"')[1].split('"')[0]
                                        dt = parse_iso(part)
                                    except Exception:
                                        pass
                                if not dt:
                                    dt = mtime

                                if dt >= seven_days_ago:
                                    recent_7d_turns += 1
                                    if "claude" in line_s.lower() or "gpt" in line_s.lower():
                                        claude_gpt_turns += 1

                                if dt >= five_hours_ago:
                                    recent_5h_turns += 1
                                    if oldest_5h_dt is None or dt < oldest_5h_dt:
                                        oldest_5h_dt = dt
                except Exception:
                    continue
    except Exception:
        pass

    # Remaining ratios (capped between 0.05 and 1.0)
    five_hour_rem = max(0.05, 1.0 - (recent_5h_turns / DEFAULT_CAP_5H))
    weekly_rem = max(0.05, 1.0 - (recent_7d_turns / DEFAULT_CAP_WEEKLY))

    claude_rem = max(0.10, 1.0 - (claude_gpt_turns / 50.0))

    # Countdown formatting
    if oldest_5h_dt:
        elapsed = (now - oldest_5h_dt).total_seconds()
        rem_sec = max(60, int((5 * 3600) - elapsed))
        h = rem_sec // 3600
        m = (rem_sec % 3600) // 60
        five_h_text = f"Resets in {h}h {m}m" if h > 0 else f"Resets in {m}m"
    else:
        five_h_text = "Resets in 3h 59m"

    # Weekly reset (upcoming Sunday midnight)
    days_to_sun = (6 - now.weekday()) % 7
    if days_to_sun == 0:
        days_to_sun = 7
    weekly_text = f"Resets in {days_to_sun}d {23 - now.hour}h"

    claude_weekly_text = "Full quota (7d)" if claude_rem >= 0.99 else f"Resets in {days_to_sun}d"
    claude_5h_text = "Full quota (5h)" if claude_rem >= 0.99 else five_h_text

    return {
        "planName": "Google AI Pro",
        "geminiWeeklyRemaining": round(weekly_rem, 2),
        "geminiWeeklyResetText": weekly_text,
        "geminiFiveHourRemaining": round(five_hour_rem, 2),
        "geminiFiveHourResetText": five_h_text,
        "claudeWeeklyRemaining": round(claude_rem, 2),
        "claudeWeeklyResetText": claude_weekly_text,
        "claudeFiveHourRemaining": round(claude_rem, 2),
        "claudeFiveHourResetText": claude_5h_text
    }

def save_quota_files(payload):
    for qpath in [QUOTA_FILE_1, QUOTA_FILE_2]:
        try:
            qpath.parent.mkdir(parents=True, exist_ok=True)
            with open(qpath, "w", encoding="utf-8") as f:
                json.dump(payload, f, indent=2)
            print(f"✅ Saved quota to: {qpath}")
        except Exception as e:
            print(f"⚠️ Could not write to {qpath}: {e}")

def send_to_boring_notch(payload):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(1.5)
        s.connect(("127.0.0.1", BORING_NOTCH_PORT))
        msg = json.dumps(payload).encode("utf-8")
        s.sendall(msg)
        s.close()
        print(f"🚀 Sent live quota payload to Boring Notch on port {BORING_NOTCH_PORT}")
        return True
    except Exception as e:
        print(f"ℹ️ Boring Notch socket not reachable on port {BORING_NOTCH_PORT} ({e}). File saved.")
        return False

def main():
    parser = argparse.ArgumentParser(description="Antigravity Quota Sync Daemon for Boring Notch")
    parser.add_argument("--daemon", action="store_true", help="Run continuously every 15 seconds")
    parser.add_argument("--interval", type=int, default=15, help="Daemon polling interval in seconds")
    parser.add_argument("--gemini-5h", type=float, help="Override Gemini 5-hour quota (0.0 to 1.0)")
    parser.add_argument("--gemini-weekly", type=float, help="Override Gemini weekly quota (0.0 to 1.0)")
    parser.add_argument("--plan", type=str, help="Override plan name")

    args = parser.parse_args()

    while True:
        payload = compute_usage()

        if args.plan:
            payload["planName"] = args.plan
        if args.gemini_5h is not None:
            payload["geminiFiveHourRemaining"] = round(args.gemini_5h, 2)
        if args.gemini_weekly is not None:
            payload["geminiWeeklyRemaining"] = round(args.gemini_weekly, 2)

        save_quota_files(payload)
        send_to_boring_notch(payload)

        if not args.daemon:
            break

        time.sleep(args.interval)

if __name__ == "__main__":
    main()
