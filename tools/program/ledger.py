#!/usr/bin/env python3
"""Program ledger for StudioVault-Glasses.

One append-only JSONL file is the machine record. Two human views are derived
from it or kept in step with it:

  docs/program/LEDGER.jsonl       append-only, one JSON object per line
  docs/program/EXECUTION-LOG.md   rendered from the ledger (never hand-edited)
  docs/program/TODO.md            task board; `task` edits one line and logs it

Commands:
  append    add one ledger line (validated, sequenced, locked)
  task      change a task's state in TODO.md and log the change
  validate  check the whole ledger and the task board
  render    regenerate EXECUTION-LOG.md from the ledger
  status    print task counts and the last ledger line

Standard library only. Runs on Python 3.9+.
"""

import argparse
import datetime as _dt
import json
import os
import re
import sys

try:
    import fcntl  # POSIX only; the ledger is written from macOS and Linux
except ImportError:  # pragma: no cover
    fcntl = None

SCHEMA = "glasses.ledger.v1"
WORK_ID = "GLASSES-1"

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PROGRAM_DIR = os.path.join(REPO_ROOT, "docs", "program")
LEDGER = os.path.join(PROGRAM_DIR, "LEDGER.jsonl")
LOG_MD = os.path.join(PROGRAM_DIR, "EXECUTION-LOG.md")
TODO_MD = os.path.join(PROGRAM_DIR, "TODO.md")

KINDS = ("decision", "change", "probe", "task_state", "gate", "incident", "correction", "note")
STATES = ("verified", "partial", "proposed", "blocked", "accepted", "failed")
GRADES = ("A", "B", "C")
TASK_STATES = ("queued", "running", "blocked", "done", "accepted", "dropped")
CHECKED_STATES = ("done", "accepted")

REQUIRED = ("schema", "seq", "ts", "work_id", "lane", "who", "kind", "title", "rationale", "evidence", "owner", "state")

TASK_LINE = re.compile(
    r"^- \[(?P<box>[ xX])\] \*\*(?P<id>[A-Z][A-Z0-9]*-[0-9]{2}[a-z]?)\*\* (?P<body>.*?)(?P<state> · state:(?P<st>[a-z]+))\s*$"
)
SECRETISH = re.compile(
    r"(sk-[A-Za-z0-9_-]{16,}|ghp_[A-Za-z0-9]{20,}|xox[abp]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.)"
)


class LedgerError(Exception):
    pass


def now_utc():
    return _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def read_ledger(path=None):
    path = path or LEDGER
    rows = []
    if not os.path.exists(path):
        return rows
    with open(path, "r", encoding="utf-8") as handle:
        for number, line in enumerate(handle, 1):
            if not line.strip():
                raise LedgerError("line %d is blank; the ledger has no blank lines" % number)
            try:
                rows.append(json.loads(line))
            except ValueError as exc:
                raise LedgerError("line %d is not JSON: %s" % (number, exc))
    return rows


def check_row(row, expected_seq=None):
    problems = []
    for key in REQUIRED:
        if key not in row:
            problems.append("missing field %s" % key)
    if problems:
        return problems
    if row["schema"] != SCHEMA:
        problems.append("schema is %r, expected %r" % (row["schema"], SCHEMA))
    if expected_seq is not None and row["seq"] != expected_seq:
        problems.append("seq is %r, expected %d" % (row["seq"], expected_seq))
    if row["kind"] not in KINDS:
        problems.append("kind %r is not one of %s" % (row["kind"], ", ".join(KINDS)))
    if row["state"] not in STATES:
        problems.append("state %r is not one of %s" % (row["state"], ", ".join(STATES)))
    if not re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$", str(row["ts"])):
        problems.append("ts %r is not UTC ISO-8601 (YYYY-MM-DDTHH:MM:SSZ)" % row["ts"])
    if not isinstance(row["evidence"], list):
        problems.append("evidence must be a list")
    elif row["state"] in ("verified", "accepted") and not row["evidence"]:
        problems.append("state %s needs at least one evidence entry" % row["state"])
    quality = row.get("quality")
    if quality is not None:
        if not isinstance(quality, dict) or quality.get("grade") not in GRADES:
            problems.append("quality.grade must be one of %s" % ", ".join(GRADES))
        elif not quality.get("graded_by") or not quality.get("basis"):
            problems.append("quality needs graded_by and basis")
    if row["kind"] == "correction" and not row.get("supersedes"):
        problems.append("a correction names the seq it supersedes")
    if row["kind"] == "task_state" and not row.get("task"):
        problems.append("a task_state line names its task")
    if SECRETISH.search(json.dumps(row)):
        problems.append("looks like a credential value; the ledger records names and locations only")
    for key in ("title", "rationale"):
        if not str(row.get(key, "")).strip():
            problems.append("%s is empty" % key)
    return problems


def _locked_append(row_builder):
    """Take the ledger lock, read the tail, build the row, append, read back."""
    os.makedirs(PROGRAM_DIR, exist_ok=True)
    lock_path = LEDGER + ".lock"
    with open(lock_path, "w") as lock:
        if fcntl is not None:
            fcntl.flock(lock, fcntl.LOCK_EX)
        rows = read_ledger()
        row = row_builder(len(rows) + 1, rows)
        problems = check_row(row, expected_seq=len(rows) + 1)
        if problems:
            raise LedgerError("refusing to append: " + "; ".join(problems))
        with open(LEDGER, "a", encoding="utf-8") as handle:
            handle.write(json.dumps(row, ensure_ascii=False, sort_keys=False) + "\n")
            handle.flush()
            os.fsync(handle.fileno())
        if read_ledger()[-1] != row:
            raise LedgerError("read-back does not match the appended line")
    return row


def build_row(args, seq, rows, kind=None, title=None, task=None, state=None):
    stamp = args.ts or now_utc()
    clamped = False
    if args.ts:
        limit = (_dt.datetime.now(_dt.timezone.utc) + _dt.timedelta(minutes=10)).strftime("%Y-%m-%dT%H:%M:%SZ")
        if args.ts > limit:
            # A future stamp would drag every later line forward with it.
            raise LedgerError("--ts %s is in the future" % args.ts)
    if rows and stamp < str(rows[-1]["ts"]):
        if args.ts:
            raise LedgerError("--ts %s is earlier than the last ledger line (%s)" % (args.ts, rows[-1]["ts"]))
        # Two machines write this file. A clock a few seconds behind must not
        # reorder the record, so the line takes the previous stamp and says so.
        stamp, clamped = str(rows[-1]["ts"]), True
    row = {
        "schema": SCHEMA,
        "seq": seq,
        "ts": stamp,
        "work_id": WORK_ID,
        "lane": args.lane,
        "who": args.who,
        "kind": kind or args.kind,
        "task": task if task is not None else getattr(args, "task", None),
        "title": title or args.title,
        "rationale": args.rationale,
        "evidence": list(args.evidence or []),
        "owner": args.owner,
        "state": state or args.state,
    }
    optional = {
        "approval": args.approval,
        "rollback": args.rollback,
        "closes_on": args.closes_on,
        "not_touched": args.not_touched,
        "commit": args.commit,
        "supersedes": args.supersedes,
    }
    for key, value in optional.items():
        if value not in (None, ""):
            row[key] = value
    if clamped:
        row["ts_clamped"] = True
    if args.human_held:
        row["human_held"] = list(args.human_held)
    if args.resolves:
        known = {r["seq"] for r in rows}
        missing = [n for n in args.resolves if n not in known]
        if missing:
            raise LedgerError("resolves %s, not in the ledger" % ", ".join(str(n) for n in missing))
        row["resolves"] = list(args.resolves)
    if args.followup:
        row["followups"] = list(args.followup)
    if args.grade:
        row["quality"] = {"grade": args.grade, "graded_by": args.graded_by or args.who, "basis": args.basis or ""}
    if row.get("supersedes"):
        known = {r["seq"] for r in rows}
        if row["supersedes"] not in known:
            raise LedgerError("supersedes %r, which is not in the ledger" % row["supersedes"])
    return row


def read_tasks(path=None):
    path = path or TODO_MD
    tasks = []
    if not os.path.exists(path):
        return tasks
    with open(path, "r", encoding="utf-8") as handle:
        for number, line in enumerate(handle, 1):
            match = TASK_LINE.match(line.rstrip("\n"))
            if match:
                tasks.append({"line": number, "id": match.group("id"), "box": match.group("box"), "state": match.group("st"), "body": match.group("body")})
    return tasks


def check_tasks(tasks):
    problems = []
    seen = set()
    for task in tasks:
        where = "TODO.md line %d (%s)" % (task["line"], task["id"])
        if task["id"] in seen:
            problems.append("%s: duplicate task id" % where)
        seen.add(task["id"])
        if task["state"] not in TASK_STATES:
            problems.append("%s: state %r is not one of %s" % (where, task["state"], ", ".join(TASK_STATES)))
        checked = task["box"].lower() == "x"
        if checked != (task["state"] in CHECKED_STATES):
            problems.append("%s: checkbox and state disagree" % where)
    return problems


def set_task_state(task_id, new_state):
    with open(TODO_MD, "r", encoding="utf-8") as handle:
        lines = handle.read().split("\n")
    for index, line in enumerate(lines):
        match = TASK_LINE.match(line)
        if match and match.group("id") == task_id:
            old_state = match.group("st")
            box = "x" if new_state in CHECKED_STATES else " "
            lines[index] = "- [%s] **%s** %s · state:%s" % (box, task_id, match.group("body"), new_state)
            with open(TODO_MD, "w", encoding="utf-8") as handle:
                handle.write("\n".join(lines))
            return old_state, match.group("body")
    raise LedgerError("task %s is not on the board" % task_id)


def _sentence(text):
    text = " ".join(str(text).split())
    return text if text.endswith((".", "!", "?")) else text + "."


def render(rows):
    out = []
    out.append("# EXECUTION LOG — StudioVault-Glasses (%s)" % WORK_ID)
    out.append("")
    out.append("Rendered from `docs/program/LEDGER.jsonl` by `tools/program/ledger.py render`. Do not edit by hand;")
    out.append("append a ledger line and render again. No secrets are recorded here.")
    out.append("")
    superseded = {row["supersedes"]: row["seq"] for row in rows if row.get("supersedes")}
    resolved = {}
    for row in rows:
        for target in row.get("resolves", []):
            resolved[target] = row["seq"]
    open_items = []
    for row in rows:
        stamp = row["ts"].replace("T", " ")[:16] + "Z"
        heading = "## Round %d — %s (%s)" % (row["seq"], " ".join(row["title"].split()).rstrip("."), stamp)
        out.append(heading)
        out.append("")
        if row["seq"] in superseded:
            out.append("> Superseded by round %d. Kept for the record; read that round for the current finding." % superseded[row["seq"]])
            out.append("")
        if row.get("supersedes"):
            out.append("- **Correction to round %d.** %s" % (row["supersedes"], _sentence(row["rationale"])))
        else:
            out.append("- **%s** %s" % (row["kind"].replace("_", " ").capitalize() + (" · " + row["task"] if row.get("task") else "") + ".", _sentence(row["rationale"])))
        meta = "- Lane `%s`, by %s. State: **%s**. Owner: %s." % (row["lane"], row["who"], row["state"], row["owner"])
        if row.get("quality"):
            meta += " Grade %s (%s; %s)." % (row["quality"]["grade"], row["quality"]["graded_by"], row["quality"]["basis"])
        out.append(meta)
        if row.get("approval"):
            out.append("- Approval: %s" % _sentence(row["approval"]))
        if row.get("commit"):
            out.append("- Commit: `%s`" % row["commit"])
        if row.get("rollback"):
            out.append("- Rollback: %s" % _sentence(row["rollback"]))
        if row.get("closes_on"):
            out.append("- Closes on: %s" % _sentence(row["closes_on"]))
        if row.get("not_touched"):
            out.append("- Not touched: %s" % _sentence(row["not_touched"]))
        if row.get("followups"):
            out.append("- Next: " + "; ".join(row["followups"]) + ".")
        if row.get("resolves"):
            out.append("- Resolves the human-held items of round%s %s." % ("s" if len(row["resolves"]) > 1 else "", ", ".join(str(n) for n in row["resolves"])))
        if row.get("human_held"):
            closed = resolved.get(row["seq"]) or superseded.get(row["seq"])
            out.append("- Open and human-held%s:" % ((" (closed by round %d)" % closed) if closed else ""))
            for item in row["human_held"]:
                out.append("  - %s" % item)
                if not closed:
                    open_items.append((row["seq"], item))
        if row["evidence"]:
            out.append("- Evidence: " + "; ".join("`%s`" % item for item in row["evidence"]))
        out.append("")
    out.append("## Open and human-held, all rounds")
    out.append("")
    if open_items:
        out.append("Every item an agent raised for the operator and nobody has closed, oldest first. An item leaves this")
        out.append("list when a later line names its round in `--resolves`, or corrects it with `--supersedes`.")
        out.append("")
        for seq, item in open_items:
            out.append("- (round %d) %s" % (seq, item))
    else:
        out.append("None recorded.")
    out.append("")
    return "\n".join(out)


def cmd_append(args):
    row = _locked_append(lambda seq, rows: build_row(args, seq, rows))
    print("appended seq %d: %s" % (row["seq"], row["title"]))
    return 0


def cmd_task(args):
    if args.to not in TASK_STATES:
        raise LedgerError("state %r is not one of %s" % (args.to, ", ".join(TASK_STATES)))
    if args.to == "accepted" and args.lane != "operator" and not args.approval:
        raise LedgerError("accepted is the operator's state: pass --lane operator, or quote the operator's words in --approval")
    if args.to == "done" and not args.evidence:
        raise LedgerError("done needs --evidence: a probe, a build result or a commit")
    before = read_tasks()
    current = [t for t in before if t["id"] == args.id]
    if not current:
        raise LedgerError("task %s is not on the board" % args.id)
    old_state = current[0]["state"]
    body = current[0]["body"]
    ledger_state = {"done": "verified", "accepted": "accepted", "blocked": "blocked", "dropped": "partial"}.get(args.to, "partial")
    title = "%s %s → %s: %s" % (args.id, old_state, args.to, re.sub(r" · .*$", "", body).strip())

    def builder(seq, rows):
        return build_row(args, seq, rows, kind="task_state", title=title, task=args.id, state=ledger_state)

    row = _locked_append(builder)
    set_task_state(args.id, args.to)
    print("task %s: %s -> %s (ledger seq %d)" % (args.id, old_state, args.to, row["seq"]))
    return 0


def cmd_validate(args):
    problems = []
    try:
        rows = read_ledger()
    except LedgerError as exc:
        print("FAIL ledger: %s" % exc)
        return 1
    for index, row in enumerate(rows, 1):
        for problem in check_row(row, expected_seq=index):
            problems.append("ledger seq %d: %s" % (index, problem))
    previous = ""
    for row in rows:
        if str(row.get("ts", "")) < previous:
            problems.append("ledger seq %s: ts goes backwards" % row.get("seq"))
        previous = str(row.get("ts", ""))
    tasks = read_tasks()
    problems.extend(check_tasks(tasks))
    task_ids = {task["id"] for task in tasks}
    for row in rows:
        if row.get("task") and task_ids and row["task"] not in task_ids:
            problems.append("ledger seq %s: task %s is not on the board" % (row.get("seq"), row["task"]))
    if os.path.exists(LOG_MD) and rows:
        with open(LOG_MD, "r", encoding="utf-8") as handle:
            if handle.read() != render(rows):
                problems.append("EXECUTION-LOG.md is stale; run `ledger.py render`")
    if problems:
        for problem in problems:
            print("FAIL %s" % problem)
        return 1
    print("ok: %d ledger lines, %d tasks" % (len(rows), len(tasks)))
    return 0


def cmd_render(args):
    rows = read_ledger()
    text = render(rows)
    with open(LOG_MD, "w", encoding="utf-8") as handle:
        handle.write(text)
    print("rendered %d rounds to %s" % (len(rows), os.path.relpath(LOG_MD, REPO_ROOT)))
    return 0


def cmd_status(args):
    tasks = read_tasks()
    counts = {}
    for task in tasks:
        counts[task["state"]] = counts.get(task["state"], 0) + 1
    print("tasks: " + (", ".join("%s %d" % (state, counts[state]) for state in TASK_STATES if state in counts) or "none"))
    for task in tasks:
        if task["state"] in ("running", "blocked"):
            print("  %s %s — %s" % (task["state"].upper(), task["id"], re.sub(r" · .*$", "", task["body"]).strip()))
    rows = read_ledger()
    if rows:
        last = rows[-1]
        print("ledger: %d lines; last seq %d at %s by %s — %s" % (len(rows), last["seq"], last["ts"], last["who"], last["title"]))
    else:
        print("ledger: empty")
    return 0


def add_common(parser):
    parser.add_argument("--lane", required=True, help="duet | claude-code-web | claude-code-local | operator | xcode-cloud | other lane name")
    parser.add_argument("--who", required=True, help="agent or person, e.g. 'Claude Duet (duet)'")
    parser.add_argument("--rationale", required=True, help="what was found or decided, and why")
    parser.add_argument("--evidence", action="append", help="repeatable: path:line, commit, URL, build id, trace id")
    parser.add_argument("--owner", default="operator", help="who owns the outcome (default operator)")
    parser.add_argument("--approval", help="the operator's words and UTC time, when the action needed them")
    parser.add_argument("--rollback", help="how to undo it")
    parser.add_argument("--closes-on", dest="closes_on", help="the observable condition that closes this item")
    parser.add_argument("--not-touched", dest="not_touched", help="what was deliberately left alone")
    parser.add_argument("--human-held", dest="human_held", action="append", help="repeatable: an item only the operator can do")
    parser.add_argument("--followup", action="append", help="repeatable: next action")
    parser.add_argument("--commit", help="commit sha in this repository")
    parser.add_argument("--supersedes", type=int, help="seq this line corrects")
    parser.add_argument("--resolves", type=int, action="append", help="repeatable: seq whose human-held items this line closes")
    parser.add_argument("--grade", choices=GRADES, help="quality grade of the evidence")
    parser.add_argument("--graded-by", dest="graded_by")
    parser.add_argument("--basis", help="why that grade")
    parser.add_argument("--ts", help="UTC timestamp override (YYYY-MM-DDTHH:MM:SSZ); default now")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command")

    p_append = sub.add_parser("append", help="add one ledger line")
    add_common(p_append)
    p_append.add_argument("--kind", required=True, choices=KINDS)
    p_append.add_argument("--title", required=True, help="the finding as a sentence; it becomes the round heading")
    p_append.add_argument("--task", help="task id this line belongs to")
    p_append.add_argument("--state", required=True, choices=STATES)
    p_append.set_defaults(func=cmd_append)

    p_task = sub.add_parser("task", help="change a task's state and log it")
    add_common(p_task)
    p_task.add_argument("id", help="task id, e.g. M0-03")
    p_task.add_argument("--to", required=True, help="|".join(TASK_STATES))
    p_task.set_defaults(func=cmd_task)

    for name, func, text in (("validate", cmd_validate, "check ledger and board"), ("render", cmd_render, "regenerate EXECUTION-LOG.md"), ("status", cmd_status, "print a summary")):
        p = sub.add_parser(name, help=text)
        p.set_defaults(func=func)

    args = parser.parse_args(argv)
    if not getattr(args, "func", None):
        parser.print_help()
        return 2
    try:
        return args.func(args)
    except LedgerError as exc:
        print("error: %s" % exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
