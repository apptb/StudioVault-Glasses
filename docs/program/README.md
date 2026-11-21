# GLASSES-1 program package

Everything an agent or the operator needs to run the glasses assistant build. Written on 2026-11-20 for two readers: Duet (the Claude cloud thread, lane `duet`) and Claude Code (local or web). Either can pick the work up cold from these files.

| File | Read it for | Who edits it |
|---|---|---|
| [DUET-WORK-ORDER.md](DUET-WORK-ORDER.md) | The one-shot prompt. Paste it, or attach it with the three files below. | Operator and planner only |
| [PLAN.md](PLAN.md) | Requirements, decisions, architecture, milestones, gates, risks | Planner; a change is a ledger `decision` line first |
| [TODO.md](TODO.md) | The task board: one line per task with owner, gate and state | Anyone, through `ledger.py task` |
| [RESOURCES.md](RESOURCES.md) | Repos, SDKs, versions, accounts, endpoints, credential names | Anyone, when a probe changes a fact |
| [LEDGER.jsonl](LEDGER.jsonl) | The machine record: append-only JSON, one event per line | Nobody by hand; `ledger.py` only |
| [EXECUTION-LOG.md](EXECUTION-LOG.md) | The same record for people, in the operator's round format | Nobody by hand; `ledger.py render` |
| [../architecture/glasses-assistant/](../architecture/glasses-assistant/) | The before and target architecture models and the preview page | Planner, at milestone ends |

## The update loop

Work changes three things together: the task board, the ledger, and the rendered log. One command does the first two; a second does the third.

```bash
# start a task
python3 tools/program/ledger.py task M0-03 --to running \
  --lane duet --who "Claude Duet (duet)" --rationale "Starting the reach probe"

# finish it: done needs evidence
python3 tools/program/ledger.py task M0-03 --to done \
  --lane duet --who "Claude Duet (duet)" \
  --rationale "Gateway answered an image request through LiteLLM" \
  --evidence "curl 200 /v1/chat/completions, local.mac-fast, 2026-11-21T14:02Z" \
  --grade A --basis "ran it myself, response read back"

# record a finding, a decision, a correction or a gate that is not a task change
python3 tools/program/ledger.py append --kind probe --state verified \
  --title "LiteLLM passes image parts to mac-fast" \
  --lane claude-code-local --who "Claude Code (local)" \
  --rationale "A 1280px JPEG was described correctly through :4000" \
  --evidence "reports/20261121/vision-probe.json"

# then, before every commit
python3 tools/program/ledger.py render
python3 tools/program/ledger.py validate
```

`validate` fails when the ledger is out of sequence, a line lacks required fields, a `verified` line has no evidence, a task's checkbox and state disagree, a line looks like it contains a credential, or the rendered log is stale. Commit `TODO.md`, `LEDGER.jsonl` and `EXECUTION-LOG.md` together, in the same commit as the work they describe.

## Rules that keep the record honest

1. **Done needs a probe.** A task moves to `done` only with evidence someone could re-run: a command and its result, a build id, a commit, a trace id. Configured, loaded, executed, verified and accepted are different states; say which one you reached.
2. **Accepted is the operator's word.** Agents stop at `done`. `accepted` is set from the `operator` lane, or with the operator's words quoted in `--approval`.
3. **Corrections are first-class.** When an earlier line turns out wrong, append a `correction` with `--supersedes <seq>`. Never rewrite a line. The rendered log marks the old round as superseded.
4. **Human-held items are named.** Anything only the operator can do goes in `--human-held`. It stays in the open list at the bottom of the log until a later line closes it with `--resolves <seq>`.
5. **No secret values, ever.** The ledger records credential names and locations. The tool refuses lines that look like keys or tokens; that check is a backstop, not permission to try.
6. **Say what you did not touch.** Use `--not-touched` when a reader might assume you restarted, pushed, signed or deleted something.
7. **Two writers, one file.** Duet and Claude Code both append here. Pull before you append, and push right after. The tool takes a file lock and re-reads the tail, which covers two processes on one machine; across machines, Git is the lock.

## Feeding the vault

`LEDGER.jsonl` is the JSON the vault's collection agent reads; `EXECUTION-LOG.md` is the user-facing log it renders to, in the same shape as the operator's fabric execution log. Each line carries `work_id`, `lane`, `who`, `kind`, `state`, `evidence`, `owner`, `rollback`, `closes_on` and a quality grade, so the daily, weekly and monthly rollups can group by lane, list what is verified versus partial, and surface what is waiting on the operator.

Vault convention puts plans, ledgers and handoffs in the vault and code in the repository. This package lives in the repository on purpose, so that a cloud thread and a local session share one copy through Git. Task `M0-02` files a pointer note in the vault; the plan lists moving the package into the vault as an operator decision (`D-08`).
