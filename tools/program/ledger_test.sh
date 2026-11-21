#!/bin/bash
# Regression test for tools/program/ledger.py. Runs in a throwaway copy.
# Run with bash (it uses an array): bash tools/program/ledger_test.sh
# sed -i.bak is used because it works with both GNU and BSD (macOS) sed.
SRC="${1:-$(dirname "$0")/ledger.py}"; T=$(mktemp -d "${2:-${TMPDIR:-/tmp}}/ledgertest.XXXX"); mkdir -p "$T/tools/program" "$T/docs/program"; cp "$SRC" "$T/tools/program/ledger.py"; cd "$T" || exit 2
printf -- '- [ ] **M0-01** First · owner:any · gate:R0 · state:queued\n- [ ] **M0-02** Second · owner:operator · gate:OP · state:queued\n- [ ] **M0-03** Third · owner:any · gate:R0 · state:queued\n' > docs/program/TODO.md
L="python3 tools/program/ledger.py"; W=(--lane duet --who "Claude Duet (duet)"); pass=0; fail=0
ok()   { if "$@" >/dev/null 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL (expected success): $*"; fi; }
no()   { if "$@" >/dev/null 2>&1; then fail=$((fail+1)); echo "FAIL (expected refusal): $*"; else pass=$((pass+1)); fi; }
ok $L validate
ok $L append "${W[@]}" --kind gate --state proposed --title "Three things wait" --rationale r --human-held "one" --human-held "two" --human-held "three"
ok $L task M0-01 --to running "${W[@]}" --rationale "start"
no $L task M0-01 --to done "${W[@]}" --rationale "no evidence"
ok $L task M0-01 --to done "${W[@]}" --rationale "probe ran" --evidence "hostname printed" --reached verified
no $L task M0-01 --to accepted "${W[@]}" --rationale "self accept"
no $L task M0-01 --to accepted --lane operator --who operator --rationale "operator lane but no quote"
ok $L task M0-01 --to accepted --lane operator --who operator --rationale "accepted" --evidence "chat" --approval "operator 2026-11-21T01:00Z: accepted"
no $L task M0-01 --to queued "${W[@]}" --rationale "leave accepted without approval"
no $L append "${W[@]}" --kind task_state --state accepted --title "bypass" --rationale r --evidence e
no $L append "${W[@]}" --kind note --state partial --title "unknown task" --rationale r --task M0-99
no $L append "${W[@]}" --kind correction --state verified --title "no target" --rationale r --evidence e
ok $L append "${W[@]}" --kind note --state partial --title "file name with sk in it" --rationale "see docs/program/packets/task-m0-04-fabric-probe.md"
no $L append "${W[@]}" --kind note --state partial --title "leak" --rationale "key sk-abcdefghijklmnopqrstuvwxyz0123"
ok $L append "${W[@]}" --kind gate --state accepted --title "Item two answered" --rationale "answered" --evidence chat --resolves 1:2
no $L append "${W[@]}" --kind gate --state accepted --title "bad item" --rationale r --evidence chat --resolves 1:9
ok $L append "${W[@]}" --kind correction --state verified --title "Round one restated" --rationale "fix" --evidence e --supersedes 1
ok $L render; ok $L validate
grep -q "(round 1 item 1) one" docs/program/EXECUTION-LOG.md && grep -q "(round 1 item 3) three" docs/program/EXECUTION-LOG.md && ! grep -q "(round 1 item 2)" docs/program/EXECUTION-LOG.md && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: item-level resolve or supersede closed the wrong items"; }
# hand-edit the board: validate must notice
sed -i.bak 's/\[ \] \*\*M0-03\*\* Third · owner:any · gate:R0 · state:queued/[x] **M0-03** Third · owner:any · gate:R0 · state:done/' docs/program/TODO.md
no $L validate
sed -i.bak 's/\[x\] \*\*M0-03\*\* Third · owner:any · gate:R0 · state:done/[ ] **M0-03** Third · owner:any · gate:R0 · state:queued/' docs/program/TODO.md
ok $L validate
# two-writer merge: duplicate seq, then repair
cp docs/program/LEDGER.jsonl a.jsonl
ok $L append "${W[@]}" --kind note --state partial --title "clone A line" --rationale r
cp docs/program/LEDGER.jsonl merged.jsonl; cp a.jsonl docs/program/LEDGER.jsonl
ok $L append --lane claude-code-local --who "Claude Code (local)" --kind note --state partial --title "clone B line" --rationale r
tail -n 1 docs/program/LEDGER.jsonl >> merged.jsonl; cp merged.jsonl docs/program/LEDGER.jsonl
no $L validate
ok $L resequence --dry-run; ok $L resequence; ok $L render; ok $L validate
# concurrency: 12 parallel task changes on distinct tasks must leave board and ledger in agreement
for i in $(seq 10 21); do printf -- '- [ ] **M1-%s** T%s · owner:any · gate:R0 · state:queued\n' "$i" "$i" >> docs/program/TODO.md; done
for i in $(seq 10 21); do $L task M1-$i --to running "${W[@]}" --rationale "parallel" >/dev/null 2>&1 & done; wait
ok $L render; ok $L validate
n=$(grep -c "state:running" docs/program/TODO.md); [ "$n" = "12" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: $n of 12 parallel task changes reached the board"; }
echo "passed $pass, failed $fail"; [ "$fail" = "0" ]
