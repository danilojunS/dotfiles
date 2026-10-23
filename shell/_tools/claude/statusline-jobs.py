#!/usr/bin/env python3
# The /loop and cron jobs a Claude Code session has, for statusline.sh, read
# back from the session's transcript: Claude Code keeps both in memory and
# passes neither to the status line.
#
#   statusline-jobs.py <transcript> <started_ms>
#
# Prints "<loop> <cron> <jobs>": the epoch seconds of the loop's next wakeup
# and of the next cron run (0 when there is none), and how many cron jobs are
# live. Cron jobs count from when they were created: a resumed session gets
# them back (claude --resume/--continue restores CronCreate jobs, short of the
# expired ones below). A /loop does not come back, so a wakeup counts only when
# scheduled after <started_ms>, when this process started.
#
# One-shot jobs end at their run; recurring ones expire 7 days after they were
# created. The scheduler moves each job by a fixed offset of its own, which
# CronCreate's nextFireAt already includes; the later runs keep that offset. A
# wakeup still counts for 5 minutes past its time, while the turn it woke runs
# and schedules the next.

import json
import sys
import time
from datetime import datetime, timedelta

TOOLS = ("CronCreate", "CronDelete", "ScheduleWakeup")
WEEK = 7 * 86400
GRACE = 300


def field(spec, lo, hi):
    values = set()
    for part in spec.split(","):
        rng, _, step = part.partition("/")
        if rng == "*":
            a, b = lo, hi
        elif "-" in rng:
            a, b = map(int, rng.split("-"))
        else:
            a = b = int(rng)
            if step:
                b = hi
        values.update(range(a, b + 1, int(step or 1)))
    return values


def matcher(cron):
    m, h, dom, mon, dow = cron.split()
    mins, hours = field(m, 0, 59), field(h, 0, 23)
    doms, mons = field(dom, 1, 31), field(mon, 1, 12)
    dows = {d % 7 for d in field(dow, 0, 7)}
    # Standard cron: with both day fields restricted, either one matching will do.
    either = dom != "*" and dow != "*"

    def match(t):
        day = t.day in doms
        wday = (t.weekday() + 1) % 7 in dows
        days = (day or wday) if either else (day and wday)
        return t.minute in mins and t.hour in hours and t.month in mons and days

    return match


def next_match(match, after):
    t = after.replace(second=0, microsecond=0) + timedelta(minutes=1)
    for _ in range(WEEK // 60 + 1):
        if match(t):
            return t
        t += timedelta(minutes=1)
    return None


def prev_match(match, upto):
    t = upto.replace(second=0, microsecond=0)
    for _ in range(WEEK // 60 + 1):
        if match(t):
            return t
        t -= timedelta(minutes=1)
    return None


def stamp(ts):
    return datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp()


def main(path, started):
    now = time.time()
    uses, results = {}, []
    with open(path, encoding="utf-8") as f:
        for line in f:
            if not any(t in line for t in TOOLS) and '"toolUseResult"' not in line:
                continue
            try:
                e = json.loads(line)
            except ValueError:
                continue
            content = (e.get("message") or {}).get("content")
            if not isinstance(content, list):
                continue
            for c in content:
                if c.get("type") == "tool_use" and c.get("name") in TOOLS:
                    uses[c["id"]] = (c["name"], c.get("input") or {})
            if e.get("type") == "user" and e.get("toolUseResult") and e.get("timestamp"):
                use_id = content[0].get("tool_use_id") if content else None
                results.append((stamp(e["timestamp"]), use_id, e["toolUseResult"]))

    jobs, wake = {}, 0
    for t, use_id, r in sorted(results, key=lambda x: x[0]):
        if use_id not in uses or not isinstance(r, dict):
            continue
        name, args = uses[use_id]
        if name == "ScheduleWakeup" and t < started:
            continue
        if name == "CronCreate" and r.get("id"):
            jobs[r["id"]] = (args.get("cron", ""), r.get("recurring", True), r.get("nextFireAt", 0) / 1000, t)
        elif name == "CronDelete":
            jobs.pop(r.get("id"), None)
        elif name == "ScheduleWakeup":
            wake = 0 if r.get("stopped") else r.get("scheduledFor", 0) / 1000

    runs = []
    for cron, recurring, first, created in jobs.values():
        if not recurring:
            if first > now:
                runs.append(first)
            continue
        if now >= created + WEEK:
            continue
        if first > now:
            runs.append(first)
            continue
        try:
            match = matcher(cron)
            base = prev_match(match, datetime.fromtimestamp(first))
            offset = first - base.timestamp() if base else 0
            nxt = next_match(match, datetime.fromtimestamp(now - offset))
        except (ValueError, AttributeError):
            nxt = None
        runs.append(min(nxt.timestamp() + offset, created + WEEK) if nxt else created + WEEK)

    loop = int(wake) if wake and wake + GRACE > now else 0
    print(loop, int(min(runs)) if runs else 0, len(runs))


if __name__ == "__main__":
    main(sys.argv[1], int(sys.argv[2]) / 1000)
