#!/usr/bin/env python3
"""Program ledger for StudioVault-Glasses.

One append-only JSONL file is the machine record. Two human views are derived
from it or kept in step with it:

  docs/program/LEDGER.jsonl       append-only, one JSON object per line
  docs/program/EXECUTION-LOG.md   rendered from the ledger (never hand-edited)
  docs/program/TODO.md            task board; `task` edits one line and logs it

Commands:
  append       add one ledger line (validated, sequenced, locked)
  task         change a task's state in TODO.md and log the change
  validate     check the ledger, the board, and that they agree
  render       regenerate EXECUTION-LOG.md from the ledger
  status       print task counts and the last ledger line
  resequence   repair sequence numbers after two clones appended in parallel

Standard library only. Runs on Python 3.9+.

This tool keeps the record consistent. It cannot prove who is typing: a lane
name and an approval quote are statements by the writer, and the record is
only as honest as they are.
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
REACHED = ("configured", "loaded", "executed", "verified")
TASK_STATES = ("queued", "running", "blocked", "done", "accepted", "dropped")
CHECKED_STATES = ("done", "accepted")

REQUIRED = ("schema", "seq", "ts", "work_id", "lane", "who", "kind", "title", "rationale", "evidence", "owner", "state")

TASK_LINE = re.compile(
    r"^- \[(?P<box>[ xX])\] \*\*(?P<id>[A-Z][A-Z0-9]*-[0-9]{2}[a-z]?)\*\* (?P<body>.*?)(?P<state> · state:(?P<st>[a-z]+))\s*$"
)
# Credential shapes. Each must start at a token boundary so that ordinary
# words and file names ("task-m0-04-...") do not trip it.
SECRETISH = re.compile(
    r"(?<![A-Za-z0-9])(sk-[A-Za-z0-9_-]{16,}|ghp_[A-Za-z0-9]{20,}|xox[abp]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}"
    r"|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.)|-----BEGIN [A-Z ]*PRIVATE KEY-----"
)
RESOLVE_REF = re.compile(r"^(\d+)(?::(\d+))?$")


class LedgerError(Exception):
    pass


def now_utc():
    return _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def read_ledger(path=None, tolerant=False):
    path = path or LEDGER
    rows = []
    if not os.path.exists(path):
        return rows
    with open(path, "r", encoding="utf-8") as handle:
        for number, line in enumerate(handle, 1):
            if not line.strip():
                if tolerant:
                    continue
                raise LedgerError("line %d is blank; the ledger has no blank lines" % number)
            try:
                rows.append(json.loads(line))
            except ValueError as exc:
                raise LedgerError("line %d is not JSON: %s" % (number, exc))
    return rows


def write_ledger(rows, path=None):
    path = path or LEDGER
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False, sort_keys=False) + "\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(tmp, path)


def parse_resolve(ref):
    match = RESOLVE_REF.match(str(ref))
    if not match:
        raise LedgerError("--resolves takes SEQ or SEQ:ITEM, for example 11 or 11:3; got %r" % ref)
    return int(match.group(1)), (int(match.group(2)) if match.group(2) else None)


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
    if row.get("reached") is not None and row["reached"] not in REACHED:
        problems.append("reached must be one of %s" % ", ".join(REACHED))
    if row["kind"] == "correction" and not row.get("supersedes"):
        problems.append("a correction names the seq it supersedes")
    if row["kind"] == "task_state":
        if not row.get("task"):
            problems.append("a task_state line names its task")
        if row.get("task_to") not in TASK_STATES:
            problems.append("a task_state line records task_to")
        if (row.get("task_to") == "accepted" or row.get("task_from") == "accepted") and not row.get("approval"):
            problems.append("moving a task into or out of accepted quotes the operator in approval")
    if SECRETISH.search(json.dumps(row, ensure_ascii=False)):
        problems.append("looks like a credential value; the ledger records names and locations only")
    for key in ("title", "rationale"):
        if not str(row.get(key, "")).strip():
            problems.append("%s is empty" % key)
    return problems


class _Lock(object):
    """One writer at a time on this machine. Across machines, Git is the lock."""

    def __enter__(self):
        os.makedirs(PROGRAM_DIR, exist_ok=True)
        self.handle = open(LEDGER + ".lock", "w")
        if fcntl is not None:
            fcntl.flock(self.handle, fcntl.LOCK_EX)
        return self

    def __exit__(self, *exc):
        self.handle.close()
        return False


def _append_locked(row):
    """Append one checked row. Caller holds the lock."""
    rows = read_ledger()
    problems = check_row(row, expected_seq=len(rows) + 1)
    if problems:
        raise LedgerError("refusing to append: " + "; ".join(problems))
    with open(LEDGER, "a", encoding="utf-8") as handle:
        handle.write(json.dumps(row, ensure_ascii=False, sort_keys=False) + "\n")
        handle.flush()
        os.fsync(handle.fileno())
    if read_ledger()[-1] != row:
        raise LedgerError("read-back does not match the appended line")


def build_row(args, rows, kind=None, title=None, task=None, state=None, extra=None):
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
        "seq": len(rows) + 1,
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
    if extra:
        row.update(extra)
    optional = {
        "reached": args.reached,
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
    if args.followup:
        row["followups"] = list(args.followup)
    if args.grade:
        row["quality"] = {"grade": args.grade, "graded_by": args.graded_by or args.who, "basis": args.basis or ""}
    by_seq = {r["seq"]: r for r in rows}
    if row.get("supersedes") and row["supersedes"] not in by_seq:
        raise LedgerError("supersedes %r, which is not in the ledger" % row["supersedes"])
    if args.resolves:
        refs = []
        for ref in args.resolves:
            seq, item = parse_resolve(ref)
            target = by_seq.get(seq)
            if target is None:
                raise LedgerError("resolves round %d, which is not in the ledger" % seq)
            held = target.get("human_held") or []
            if not held:
                raise LedgerError("round %d has no human-held items to resolve" % seq)
            if item is not None and not 1 <= item <= len(held):
                raise LedgerError("round %d has %d human-held items; there is no item %d" % (seq, len(held), item))
            refs.append("%d:%d" % (seq, item) if item is not None else str(seq))
        row["resolves"] = refs
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
            box = "x" if new_state in CHECKED_STATES else " "
            lines[index] = "- [%s] **%s** %s · state:%s" % (box, task_id, match.group("body"), new_state)
            tmp = TODO_MD + ".tmp"
            with open(tmp, "w", encoding="utf-8") as handle:
                handle.write("\n".join(lines))
            os.replace(tmp, TODO_MD)
            return
    raise LedgerError("task %s is not on the board" % task_id)


def closed_items(rows):
    """Map (seq, item_index) -> seq of the line that resolved it."""
    held = {row["seq"]: len(row.get("human_held") or []) for row in rows}
    closed = {}
    for row in rows:
        for ref in row.get("resolves", []):
            seq, item = parse_resolve(ref)
            items = range(1, held.get(seq, 0) + 1) if item is None else [item]
            for index in items:
                closed.setdefault((seq, index), row["seq"])
    return closed


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
    closed = closed_items(rows)
    open_items = []
    for row in rows:
        stamp = row["ts"].replace("T", " ")[:16] + "Z"
        out.append("## Round %d — %s (%s)" % (row["seq"], " ".join(row["title"].split()).rstrip("."), stamp))
        out.append("")
        if row["seq"] in superseded:
            out.append("> Superseded by round %d. Kept for the record; read that round for the current finding." % superseded[row["seq"]])
            out.append("")
        if row.get("supersedes"):
            out.append("- **Correction to round %d.** %s" % (row["supersedes"], _sentence(row["rationale"])))
        else:
            lead = row["kind"].replace("_", " ").capitalize() + (" · " + row["task"] if row.get("task") else "") + "."
            out.append("- **%s** %s" % (lead, _sentence(row["rationale"])))
        meta = "- Lane `%s`, by %s. State: **%s**." % (row["lane"], row["who"], row["state"])
        if row.get("reached"):
            meta += " Reached: %s." % row["reached"]
        meta += " Owner: %s." % row["owner"]
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
            out.append("- Resolves: " + ", ".join("round %s" % ref.replace(":", " item ") for ref in row["resolves"]) + ".")
        if row.get("human_held"):
            out.append("- Open and human-held:")
            for index, item in enumerate(row["human_held"], 1):
                by = closed.get((row["seq"], index))
                if by:
                    out.append("  - %d. ~~%s~~ (closed by round %d)" % (index, item, by))
                else:
                    out.append("  - %d. %s" % (index, item))
                    open_items.append((row["seq"], index, item))
        if row["evidence"]:
            out.append("- Evidence: " + "; ".join("`%s`" % item for item in row["evidence"]))
        out.append("")
    out.append("## Open and human-held, all rounds")
    out.append("")
    if open_items:
        out.append("Every item an agent raised for the operator and nobody has closed, oldest first. Close one with")
        out.append("`--resolves ROUND:ITEM` on the line that records its outcome. A correction does not close items.")
        out.append("")
        for seq, index, item in open_items:
            out.append("- (round %d item %d) %s" % (seq, index, item))
    else:
        out.append("None recorded.")
    out.append("")
    return "\n".join(out)


def cmd_append(args):
    if args.kind == "task_state":
        raise LedgerError("task_state lines are written by the `task` command, which also updates the board")
    with _Lock():
        rows = read_ledger()
        if args.task and args.task not in {t["id"] for t in read_tasks()}:
            raise LedgerError("task %s is not on the board" % args.task)
        row = build_row(args, rows)
        _append_locked(row)
    print("appended seq %d: %s" % (row["seq"], row["title"]))
    return 0


def cmd_task(args):
    if args.to not in TASK_STATES:
        raise LedgerError("state %r is not one of %s" % (args.to, ", ".join(TASK_STATES)))
    if args.to == "done" and not args.evidence:
        raise LedgerError("done needs --evidence: a probe, a build result or a commit")
    with _Lock():
        current = [t for t in read_tasks() if t["id"] == args.id]
        if not current:
            raise LedgerError("task %s is not on the board" % args.id)
        old_state, body = current[0]["state"], current[0]["body"]
        if old_state == args.to:
            raise LedgerError("task %s is already %s" % (args.id, args.to))
        if (args.to == "accepted" or old_state == "accepted") and not args.approval:
            raise LedgerError("accepted is the operator's state: quote the operator's words and time in --approval")
        ledger_state = {"done": "verified", "accepted": "accepted", "blocked": "blocked"}.get(args.to, "partial")
        title = "%s %s → %s: %s" % (args.id, old_state, args.to, re.sub(r" · .*$", "", body).strip())
        rows = read_ledger()
        row = build_row(args, rows, kind="task_state", title=title, task=args.id, state=ledger_state,
                        extra={"task_from": old_state, "task_to": args.to})
        _append_locked(row)
        set_task_state(args.id, args.to)
    print("task %s: %s -> %s (ledger seq %d)" % (args.id, old_state, args.to, row["seq"]))
    return 0


def find_problems():
    problems = []
    rows = read_ledger()
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
    board = {task["id"]: task["state"] for task in tasks}
    last = {}
    for row in rows:
        if row.get("task") and board and row["task"] not in board:
            problems.append("ledger seq %s: task %s is not on the board" % (row.get("seq"), row["task"]))
        if row.get("kind") == "task_state":
            last[row.get("task")] = row.get("task_to")
    for task_id, state in board.items():
        expected = last.get(task_id, "queued")
        if state != expected:
            problems.append("task %s is %s on the board but the ledger says %s; change states with `ledger.py task`" % (task_id, state, expected))
    by_seq = {row.get("seq"): row for row in rows}
    for row in rows:
        for ref in row.get("resolves", []):
            try:
                seq, item = parse_resolve(ref)
            except LedgerError as exc:
                problems.append("ledger seq %s: %s" % (row.get("seq"), exc))
                continue
            held = (by_seq.get(seq) or {}).get("human_held") or []
            if not held or (item is not None and not 1 <= item <= len(held)):
                problems.append("ledger seq %s: resolves %s, which does not exist" % (row.get("seq"), ref))
    if os.path.exists(LOG_MD) and rows:
        with open(LOG_MD, "r", encoding="utf-8") as handle:
            if handle.read() != render(rows):
                problems.append("EXECUTION-LOG.md is stale; run `ledger.py render`")
    return problems, len(rows), len(tasks)


def cmd_validate(args):
    try:
        problems, n_rows, n_tasks = find_problems()
    except LedgerError as exc:
        print("FAIL ledger: %s" % exc)
        return 1
    if problems:
        for problem in problems:
            print("FAIL %s" % problem)
        return 1
    print("ok: %d ledger lines, %d tasks" % (n_rows, n_tasks))
    return 0


def cmd_render(args):
    rows = read_ledger()
    with open(LOG_MD, "w", encoding="utf-8") as handle:
        handle.write(render(rows))
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
        closed = closed_items(rows)
        still = sum(1 for row in rows for index in range(1, len(row.get("human_held") or []) + 1) if (row["seq"], index) not in closed)
        print("open human-held items: %d" % still)
    else:
        print("ledger: empty")
    return 0


def cmd_resequence(args):
    """After a Git merge where two clones both appended, the file has duplicate
    or out-of-order seq values. Keep every line, order by time, renumber, and
    carry references across. Run it once, on one machine, then render."""
    with _Lock():
        rows = read_ledger(tolerant=True)
        indexed = list(enumerate(rows))
        indexed.sort(key=lambda pair: (str(pair[1].get("ts", "")), pair[1].get("seq", 0), pair[0]))
        old_counts = {}
        for _, row in indexed:
            old_counts[row.get("seq")] = old_counts.get(row.get("seq"), 0) + 1
        mapping, ambiguous = {}, set()
        for new_seq, (_, row) in enumerate(indexed, 1):
            old = row.get("seq")
            if old_counts[old] > 1:
                ambiguous.add(old)
            else:
                mapping[old] = new_seq
        warnings, changed, out = [], 0, []
        for new_seq, (_, row) in enumerate(indexed, 1):
            row = dict(row)
            if row.get("seq") != new_seq:
                changed += 1
            row["seq"] = new_seq
            if row.get("supersedes") is not None:
                old = row["supersedes"]
                if old in ambiguous:
                    warnings.append("new seq %d supersedes old seq %s, which two lines shared; fix by hand" % (new_seq, old))
                else:
                    row["supersedes"] = mapping.get(old, old)
            if row.get("resolves"):
                refs = []
                for ref in row["resolves"]:
                    seq, item = parse_resolve(ref)
                    if seq in ambiguous:
                        warnings.append("new seq %d resolves old round %s, which two lines shared; fix by hand" % (new_seq, seq))
                        refs.append(ref)
                    else:
                        target = mapping.get(seq, seq)
                        refs.append("%d:%d" % (target, item) if item is not None else str(target))
                row["resolves"] = refs
            out.append(row)
        print("%d lines; %d renumbered; %d references need a hand fix" % (len(out), changed, len(warnings)))
        for warning in warnings:
            print("WARN %s" % warning)
        if args.dry_run:
            print("dry run: nothing written")
            return 0
        write_ledger(out)
    print("written. Now run `ledger.py render` and `ledger.py validate`.")
    return 0


def add_common(parser):
    parser.add_argument("--lane", required=True, help="duet | claude-code-web | claude-code-local | operator | xcode-cloud | other lane name")
    parser.add_argument("--who", required=True, help="agent or person, e.g. 'Claude Duet (duet)'")
    parser.add_argument("--rationale", required=True, help="what was found or decided, and why")
    parser.add_argument("--evidence", action="append", help="repeatable: path:line, commit, URL, build id, trace id")
    parser.add_argument("--reached", choices=REACHED, help="how far the thing got: configured, loaded, executed or verified")
    parser.add_argument("--owner", default="operator", help="who owns the outcome (default operator)")
    parser.add_argument("--approval", help="the operator's words and UTC time, when the action needed them")
    parser.add_argument("--rollback", help="how to undo it")
    parser.add_argument("--closes-on", dest="closes_on", help="the observable condition that closes this item")
    parser.add_argument("--not-touched", dest="not_touched", help="what was deliberately left alone")
    parser.add_argument("--human-held", dest="human_held", action="append", help="repeatable: an item only the operator can do")
    parser.add_argument("--followup", action="append", help="repeatable: next action")
    parser.add_argument("--commit", help="commit sha in this repository")
    parser.add_argument("--supersedes", type=int, help="seq this line corrects")
    parser.add_argument("--resolves", action="append", help="repeatable: SEQ:ITEM closes one human-held item of that round; SEQ closes all of them")
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

    p_reseq = sub.add_parser("resequence", help="repair seq values after a two-writer merge")
    p_reseq.add_argument("--dry-run", action="store_true", help="report what would change and write nothing")
    p_reseq.set_defaults(func=cmd_resequence)

    for name, func, text in (("validate", cmd_validate, "check ledger, board and their agreement"), ("render", cmd_render, "regenerate EXECUTION-LOG.md"), ("status", cmd_status, "print a summary")):
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
