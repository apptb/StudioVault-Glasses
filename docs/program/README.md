# GLASSES-1 program package

Everything an agent or the operator needs to run the glasses assistant build. Written for two readers: Duet (the operator's Claude cloud thread, lane `duet`) and Claude Code (local or web). Either can pick the work up cold from these files.

This repository is public. The package carries no host names, local paths or key locations; the operator holds those in a private notes file.

| File | Read it for | Who edits it |
|---|---|---|
| [DUET-WORK-ORDER.md](DUET-WORK-ORDER.md) | The one-shot prompt. Paste it, or attach it with the four files below. | Operator, or whoever writes the next work order |
| [PLAN.md](PLAN.md) | Requirements, decisions, architecture, milestones, gates, risks | Any lane; a change to a decision is a ledger `decision` line first |
| [TODO.md](TODO.md) | The task board: one line per task with owner, gate and state | Anyone, through `ledger.py task` |
| [RESOURCES.md](RESOURCES.md) | Repositories, models, SDKs, harnesses, vendor requirements | Anyone, when a probe changes a fact |
| [LEDGER.jsonl](LEDGER.jsonl) | The machine record: append-only JSON, one event per line | Nobody by hand; `ledger.py` only |
| [EXECUTION-LOG.md](EXECUTION-LOG.md) | The same record for people. Each ledger line becomes a "round" with a sentence heading, the finding, its evidence and what is waiting on the operator, in the shape of the operator's own execution log | Nobody by hand; `ledger.py render` |
| [REFERENCE-CLIENTS.md](REFERENCE-CLIENTS.md) | A study of two reference clients for the Hermes agent, with proposals for the plan. Nothing in it is adopted | Any lane; the operator rules on each proposal |
| [../architecture/glasses-assistant/](../architecture/glasses-assistant/) | The as-found and target architecture models, the Archify pages and their receipts | Any lane, at milestone ends |

`reports/` holds probe and review results, named by task. `packets/` holds work written for another lane to run. `closeouts/` holds end-of-milestone summaries.

## The update loop

Work changes three things: the task board, the ledger, and the rendered log.

```bash
# start a task
python3 tools/program/ledger.py task M0-03 --to running \
  --lane duet --who "Claude Duet (duet)" --rationale "Starting the reach probe"

# finish it: done needs evidence, and says how far it got
python3 tools/program/ledger.py task M0-03 --to done \
  --lane duet --who "Claude Duet (duet)" \
  --rationale "This lane can read and write the repository; it has no shell on the Mac" \
  --evidence "git push of a test branch succeeded" --evidence "no machine is attached to the thread" \
  --reached verified --grade A --basis "ran it myself"

# record a finding, a decision, a correction or a gate that is not a task change
python3 tools/program/ledger.py append --kind probe --state verified --reached executed \
  --title "LiteLLM passes image parts to the fast Mac route" \
  --lane claude-code-local --who "Claude Code (local)" \
  --rationale "A 1280px JPEG was described correctly through the router" \
  --evidence "docs/program/reports/M0-04-fabric-probe.md"

# close one item that was waiting on the operator: round 9, item 2
python3 tools/program/ledger.py append --kind gate --state accepted \
  --title "The operator chose a private repository for the working code" \
  --lane duet --who "Claude Duet (duet)" --rationale "Answer to O-9" \
  --approval "operator 2026-11-22T15:04Z: private repo" --evidence "thread message" --resolves 9:2

# before every commit of the record
python3 tools/program/ledger.py render
python3 tools/program/ledger.py validate
```

Commit in two steps. First the work. Then the record, citing the work's commit with `--commit <sha>` or as evidence: `TODO.md`, `LEDGER.jsonl` and `EXECUTION-LOG.md` together.

`validate` fails when the ledger is out of sequence, a line lacks required fields, a `verified` line has no evidence, the board and the ledger disagree about a task's state, a line looks like it contains a credential, or the rendered log is stale. `bash tools/program/ledger_test.sh` exercises all of this in a throwaway copy.

## Rules that keep the record honest

1. **Done needs a probe.** A task moves to `done` only with evidence someone could re-run: a command and its result, a build id, a commit, a trace id. Say how far it got with `--reached configured|loaded|executed|verified`.
2. **Accepted is the operator's word.** Agents stop at `done`. Moving a task into or out of `accepted` needs the operator's words and time in `--approval`. The tool cannot check who is typing; it only refuses the move without a quote.
3. **Probes beat the plan.** When a probe contradicts PLAN.md, log the finding as a `probe` line and update section 2 of the plan in the same change. Use `correction --supersedes <seq>` only to correct an earlier ledger line.
4. **Human-held items are named and numbered.** Anything only the operator can do goes in `--human-held`. It stays in the open list at the bottom of the log until a later line closes that item with `--resolves ROUND:ITEM`. A correction does not close items.
5. **No secret values, ever, and no machine-identifying detail.** The tool refuses lines that look like keys or tokens; that check is a backstop. Host names, paths and key locations belong in the operator's private notes.
6. **Say what you did not touch.** Use `--not-touched` when a reader might assume you restarted, pushed, signed or deleted something.
7. **Two writers, one file.** Pull before you append, push right after. On one machine the tool takes a file lock. Across machines Git is the lock: if a merge leaves two lines with the same sequence number, keep both lines, run `ledger.py resequence`, then `render` and `validate`.
8. **One home for the record.** Until the working line exists (M0-07), the record lives on the planning branch. After that it lives only on the working line.

## Feeding the vault

`LEDGER.jsonl` is the JSON the vault's collection agent reads; `EXECUTION-LOG.md` is the user-facing log rendered from it. Each line carries `work_id`, `lane`, `who`, `kind`, `state`, `reached`, `evidence`, `owner`, `rollback`, `closes_on` and a quality grade, so the daily, weekly and monthly rollups can group by lane, list what is verified versus partial, and surface what is waiting on the operator.
