# Work order for Duet: GLASSES-1, milestone M0

Paste everything below the line into Duet. If Duet cannot read the repository, attach `README.md`, `PLAN.md`, `TODO.md`, `RESOURCES.md` and `LEDGER.jsonl` from `docs/program/`. Attach your private fabric notes too; they are not in the repository because it is public.

---

You are picking up a build program called GLASSES-1 as lane `duet`. I am the operator. This message is the whole brief; you do not need anything from an earlier conversation.

## What this is

I want a hands-free assistant on my Ray-Ban Meta glasses. A trigger starts a turn, the glasses take a photo, I ask a question, and the answer comes back in my ear. When the question is a job (check a price, save a note, set a reminder, do something on my Mac), my Mac does it and leaves a record in my Obsidian vault. The iPhone app is built and signed by Xcode Cloud and reaches me through TestFlight.

Models come in two phases. First the frontier APIs (Claude, the DeepSeek platform, OpenAI), so we know what good looks like. Then the same turns on my own machines (the model servers and deepseek-recipe proxies on the Mac, Unsloth Studio, a large model on my DGX pair), which become the default once they match the frontier results on a fixed set of photo questions.

A plan already exists. It was written in cloud sessions that could read code, my execution log and the web, and could not touch my machines. So it is a set of sourced claims, not verified facts. Your first job is to find out which claims hold.

## Read first

In `apptb/StudioVault-Glasses`, branch `claude/rayban-meta-glasses-assistant-cb0gqs`, folder `docs/program/`:

1. `README.md`: how the record is kept. Read this before you change anything.
2. `PLAN.md`: requirements, what exists, twelve proposed decisions (D-01 to D-12), the target architecture, acceptance for every task, risks, and seventeen questions for me (O-1 to O-17).
3. `TODO.md`: the task board. Task ids below refer to it.
4. `RESOURCES.md`: repositories, models, the agent harnesses on my Mac, Meta and Apple requirements.

The architecture map is in `docs/architecture/glasses-assistant/`. Open `glasses-assistant.delta.html` in a browser for the before, delta and after views.

That repository is public. Never commit a host name, a local path, a port of one of my private services, or where a key lives. Those are in my private notes.

## What I want from this work order

Milestone M0: ground truth and a signed build. No feature code. It ends when the upstream app, renamed and re-signed as mine, installs from TestFlight and pairs with my glasses, and two probes have each answered an image question: one through my local routes, one through the frontier APIs.

Work in this order. Each step says what it needs, because you may not have the reach for all of them.

**A1. Find out what you can reach (M0-03).** Can you read and write the repository? Can you run a command on my Mac Studio by any route you have? The test for the Mac is simple: run `hostname` there and read the answer back. My own notes say I have not set up a route from you to the new Mac, so expect that to fail and say so plainly. A lane that is absent is a finding to record.

**A2. Bring me the decisions and questions as one short ballot (M0-01, M0-02).** Twelve decisions with their defaults and seventeen questions. Put each in one or two plain sentences with the default first, so I can answer "yes to all, except..." without opening the plan. Three decisions already carry my words from 2026-11-21 (D-01, D-04, D-09); show them as already given.

**A3. Write the probe packets (M0-04, M0-06).** Both probes need a shell on the Mac and a scoped model key that I provide; neither may print a key. If you have the shell, run them. If not, write each as a packet in `docs/program/packets/`: the exact commands, what each should return, and where the result file goes (`docs/program/reports/M0-04-fabric-probe.md`, `docs/program/reports/M0-06-frontier-probe.md`). A local Claude Code session or one of my headless harnesses will run them. The local probe must show an image going through my router and coming back described correctly, on a Mac route and on a DGX route, and one request that carries an image and a tool definition. The frontier probe sends the same photo and question through each frontier route and records time to first token, total time and cost. I care most about these two results: the design assumes they work and nobody has tried.

**A4. Harvest Athena (M0-17).** Athena was my earlier voice project. It is dated; take intent and use cases from it and nothing else. Ask me for the notes if you cannot see them.

**A5. Create the working line, once I have answered O-9 (M0-07).** O-9 asks whether the working code lives in a new private repository (the default) or in the public fork. Do not push upstream's code anywhere before I answer. When I have: import upstream `Intent-Lab/VisionClaw` at `3f39807`, add one commit carrying `docs/program`, `docs/architecture` and `tools/program`, and from then on keep the record only there. Do not commit to `main` of the fork.

**A6. Prepare the project to build from a fresh clone (M0-10).** On the working line: my identifiers (once I have chosen them), the narrowed ignore rule from RESOURCES.md, the post-clone script from `docs/program/templates/`, and a cleared default gateway address in the example secrets file. `Package.resolved` has to be generated by Xcode on the Mac (M0-11); write that as a packet if you cannot run it.

**A7. Walk me through the steps only I can take (M0-05, M0-08, M0-09, M0-12, M0-13).** Section 5.1 of the plan lists the Apple and Meta steps; M0-05 is adding the frontier keys and routes. Give them to me one screen at a time, in order, with what I should see when each one worked. When a build fails, read the failure with me and fix the repository side.

**A8. Upgrade the SDK pin (M0-14).** After the first green build, not before.

Steps A1 to A4 need nothing from me except the two keys in A3. Start them without waiting for the ballot.

When M0 is done, stop and write the closeout. Do not start M1 without my word.

## What stays with me

You prepare these and I do them or say yes each time: signing, device registration, anything written to App Store Connect or TestFlight, starting an Xcode Cloud build, the Meta Developer Center registration, adding an API key, exposing any service on my private network, changing my model router's configuration or my daily worker, any system permission or Keychain prompt, creating a repository, and any push to `main`. Pushing to the working line or to a task branch is yours.

No agent reads, prints, stores or logs a credential value. If a credential prompt appears, stop and hand it to me. If you see a secret value anywhere, stop, tell me, and record that it happened without recording the value.

I have authorized running DeepSeek Harness, Pi or OpenCode headless on my Mac for Mac-side tasks. Treat a headless job as running code: one job at a time, a fixed argument list, the task as a single argument.

Nothing clinical or health-related goes through this app. Meta's terms forbid it and the plan rules it out.

The old StudioVault vault repository is retired. Do not clone it, and do not follow rules or gateway names from it.

## How to keep the record

The record is how I follow this work from my vault, and how the next lane picks it up, so it matters as much as the work. `docs/program/README.md` has the commands and the rules. The ones that trip people up:

- Change a task's state only with `ledger.py task`. `validate` compares the board with the ledger and fails if they disagree.
- A task is `done` only with evidence someone could re-run. Say how far it got with `--reached`. `accepted` is mine; it needs my words in `--approval`.
- When a probe contradicts the plan, the probe wins: log it as a `probe` line and update section 2 of the plan in the same change.
- Anything only I can do goes in `--human-held`. Close it later with `--resolves ROUND:ITEM`.
- Commit the work first, then the record citing that commit.
- If you cannot run Python where you are, do not edit `LEDGER.jsonl` by hand. Put the exact `ledger.py` commands you would have run in your closeout under "Ledger commands to run", and a lane that can run them will.
- Pull before you append and push right after. If a merge leaves two lines with the same number, keep both and run `ledger.py resequence`.

Any architecture picture you make follows my visual standard, the `visual-standard` skill in `apptb/studiovault-universal-skills` (on branch `claude/rayban-meta-glasses-assistant-cb0gqs` until its pull request merges). In short: the picture is rendered by Archify from a JSON model kept beside it, the tool's checks pass and their result file (the receipt) is kept too, and a change is shown as before, delta and after. A Mermaid block is a draft.

## When to stop and ask

- Two failures or one timeout on the same step: stop, record what you tried, and propose the next approach instead of a third identical attempt.
- Two reasonable readings of an instruction that lead to different results: give me both, your recommendation, and what you will do if I do not answer.
- Anything irreversible, anything that publishes outward, anything on shared infrastructure.

Otherwise keep going. Reversible work on a branch does not need my permission.

## What to send back

First reply: the reach report from A1 and the ballot from A2. Keep it short enough to read on a phone.

At the end of M0, a closeout committed at `docs/program/closeouts/CLOSEOUT__<date>__M0.md` with four sections:

- **Done**: each task with its commit, build id or result file.
- **Not finished**: each task with the exact gap, and which tasks were not started.
- **Operator items**: what is waiting on me, most blocking first.
- **Lanes**: one line for each lane that worked on M0, giving what it set out to do, what is verified, what is partial and what needs a decision.
