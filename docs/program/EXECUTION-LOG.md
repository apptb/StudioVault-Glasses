# EXECUTION LOG — StudioVault-Glasses (GLASSES-1)

Rendered from `docs/program/LEDGER.jsonl` by `tools/program/ledger.py render`. Do not edit by hand;
append a ledger line and render again. No secrets are recorded here.

## Round 1 — The fork is the Matcha lineage on Meta SDK 0.4.0 and calls four vendor clouds from the phone (2026-11-21 01:05Z)

- **Probe.** Read at commit 73c5318. The SDK pin is exact at 0.4.0. The app opens connections to Gemini, an Azure realtime endpoint and an agent backend on Vercel with an E2B sandbox, and holds their keys on the phone.
- Lane `claude-code-web`, by Claude Code (web). State: **verified**. Reached: verified. Owner: operator. Grade A (Claude Code (web); read the files at the pinned commit).
- Not touched: Nothing was built or run; the code was read.
- Evidence: `samples/CameraAccess/CameraAccess.xcodeproj/project.pbxproj:976-983 @73c5318`; `samples/CameraAccess/CameraAccess/Gemini/GeminiConfig.swift:4 @73c5318`; `samples/CameraAccess/CameraAccess/Azure/AzureRealtimeConfig.swift:104 @73c5318`; `samples/CameraAccess/CameraAccess/Agent/AgentConfig.swift:3-12 @73c5318`

## Round 2 — Upstream VisionClaw at 3f39807 is the smaller and newer base (2026-11-21 01:05Z)

- **Probe.** Upstream is on Meta SDK 0.9.0, whose API shape 1.x keeps, and has the audio-route handling, intents and earcons this product needs. Its photo call needs a live video stream. Neither tree was compiled here.
- Lane `claude-code-web`, by Claude Code (web). State: **verified**. Reached: verified. Owner: operator. Grade A (Claude Code (web); read the files at the pinned commit).
- Evidence: `Intent-Lab/VisionClaw @3f39807, project.pbxproj:683`; `docs/program/PLAN.md section 2`

## Round 3 — The Mac and DGX fabric is known only from the operator's log; nothing on it was probed (2026-11-21 01:05Z)

- **Probe.** The log describes a model router with local routes, local model servers and proxies, a GLM model on the DGX pair, a daily synthesis worker and a trace store. It records text tool calls through the router and no image request through it. It mentions no speech-to-text service. No lane has yet tried an image through the router, which the design depends on.
- Lane `claude-code-web`, by Claude Code (web). State: **partial**. Reached: configured. Owner: operator. Grade B (Claude Code (web); one written source, not probed).
- Closes on: M0-04 returns an image described correctly through the router on a Mac route and a DGX route.
- Next: M0-04 fabric probe.
- Evidence: `operator's execution log, uploaded 2026-11-20 (not in this repository)`; `docs/program/PLAN.md section 2`

## Round 4 — Meta's toolkit is at 1.1.0; version 1.0 added a launch phrase, button events and a standalone still as experimental features (2026-11-21 01:05Z)

- **Probe.** Eight releases separate the fork's 0.4.0 from 1.1.0. The glasses microphone is reachable only over Bluetooth hands-free audio, and iOS will not start a recording from the background. These shape the wake strategy in D-07 and the SDK move in M0-14.
- Lane `claude-code-web`, by Claude Code (web). State: **partial**. Reached: configured. Owner: operator. Grade B (Claude Code (web); vendor pages read once each, nothing run).
- Closes on: M0-13 and M2-01 test the launch phrase, the capture button and photo with microphone on the real device.
- Evidence: `docs/program/RESOURCES.md, Meta and Apple sections`

## Round 5 — The operator set four directions on 2026-11-21 (2026-11-21 01:05Z)

- **Gate.** Frontier APIs come first and local models second (D-04). DeepSeek Harness, Pi or OpenCode may be invoked headless (D-09). The glasses fork may be repurposed (D-01). The old vault repository is retired and is not to be cloned or relied on (D-10).
- Lane `claude-code-web`, by Claude Code (web). State: **accepted**. Owner: operator. Grade A (Claude Code (web); the operator's own words).
- Approval: operator 2026-11-21: 'The studio vault has been retired. Do not clone it. Studio glasses repo is something you can repurpose ... I give you authorization to invoke either the DeepSeek harness, Pi, or open code in a headless fashion ... explore using the Claude API, a DeepSeek platform API, and OpenAI's platform as initial frontier level matches, followed by ... Unsloth Studio'.
- Evidence: `operator's message in the planning session, 2026-11-21`

## Round 6 — Twelve decisions, D-01 to D-12, are proposed and wait for the operator (2026-11-21 01:05Z)

- **Decision.** Build from upstream on a new working line; one request per turn; a small gateway on the Mac that speaks the Messages API through the router; frontier first; speech on the phone; Xcode Cloud for delivery and the Mac for device tests; wake strategy by measurement; safety tiers in gateway code; a headless harness lane whose model calls go through the router; the record lives in the repository; iOS only; working code in a private repository.
- Lane `claude-code-web`, by Claude Code (web). State: **proposed**. Owner: operator. Grade B (Claude Code (web); reasoned from sources, not tested).
- Closes on: the operator's answer to the ballot.
- Open and human-held:
  - 1. Ratify or amend D-01 to D-12 (task M0-01)
- Evidence: `docs/program/PLAN.md section 3`

## Round 7 — Ten questions, O-1 to O-10, wait for the operator (2026-11-21 01:05Z)

- **Note.** Each one changes what gets built or where. They are listed with what they affect in the plan.
- Lane `claude-code-web`, by Claude Code (web). State: **proposed**. Owner: operator. Grade A (Claude Code (web); the questions are the plan's own).
- Closes on: each question answered; close items with --resolves ROUND:ITEM.
- Open and human-held:
  - 1. O-1: the request said the Mac has 512 GB; the log and the operator's map say 256 GB. Which, or are there two Macs?
  - 2. O-2: confirm 'NVIDIA Cutter' means the two-node DGX Spark cluster
  - 3. O-3: confirm the fabric in the log is the live one, and say where Unsloth Studio runs
  - 4. O-4: app name, bundle id and wake phrase
  - 5. O-5: which glasses, which iPhone, which iOS version
  - 6. O-6: which Obsidian vault is live and which folder receives glasses notes
  - 7. O-7: how long photos are kept on the Mac
  - 8. O-8: which frontier accounts have keys, which OpenAI model, and the daily spend cap
  - 9. O-9: private repository (the default) or this public fork for the working code
  - 10. O-10: how an agent reaches the Mac
- Evidence: `docs/program/PLAN.md section 9`

## Round 8 — This cloud lane can read and write the repository and cannot reach the Mac (2026-11-21 01:05Z)

- **Probe.** Pushes to the planning branch work. No folder on the operator's computers is shared with the session, and the operator's gateway connector did not answer, so no command ran on the Mac. The headless harnesses were authorized and were not invoked; no connector was installed there; no probe ran.
- Lane `claude-code-web`, by Claude Code (web). State: **blocked**. Reached: executed. Owner: operator. Grade A (Claude Code (web); ran it myself).
- Closes on: a lane runs hostname on the Mac and reads the answer back (M0-03).
- Not touched: Nothing on the Mac, the DGX pair, a phone or the glasses.
- Next: Share one folder with a cloud session through Remote Control, or run M0-04 and M0-06 from a local session.
- Evidence: `git push to the planning branch succeeded`; `the session's list of shared computer folders was empty on 2026-11-21`

## Round 9 — Machine-identifying detail was committed to this public repository; the current files no longer carry it, the first commit still does (2026-11-21 01:05Z)

> Superseded by round 14. Kept for the record; read that round for the current finding.

- **Incident.** The first version of this package named a machine on the private network, local paths and the location of a key file. It held no key, token or address. The package was rewritten without them and the details moved to a private notes file handed to the operator. A push that would have replaced the branch history was refused by the session's permission rules, so the first commit on this branch still holds the old text and can be read from the pull request's commit list.
- Lane `claude-code-web`, by Claude Code (web). State: **partial**. Reached: executed. Owner: operator. Grade A (Claude Code (web); scanned the files myself; the history rewrite was not done).
- Rollback: none needed; the removed text is in the operator's private notes.
- Closes on: the first commit is no longer reachable from any branch or pull request.
- Not touched: main, every other branch, and the branch history.
- Open and human-held:
  - 1. Approve replacing this branch's history with one clean commit (or delete the branch and pull request so it can be pushed fresh), and decide whether to ask GitHub Support to purge the old commit
- Evidence: `a scan of every committed file for the removed names and paths found none`; `docs/program/README.md, rule 5`

## Round 10 — The ledger tool passes its regression test (2026-11-21 01:05Z)

- **Change.** Thirty-two checks cover sequencing, required fields, evidence for done, the operator-only accepted state, board and ledger agreement, item-level closing of operator items, resequencing after a two-writer merge, the credential backstop and a stale log.
- Lane `claude-code-web`, by Claude Code (web). State: **verified**. Reached: verified. Owner: operator. Grade A (Claude Code (web); ran it myself).
- Evidence: `bash tools/program/ledger_test.sh: 32 passed, 0 failed`

## Round 11 — M0-16 queued → running: Render the architecture map with Archify, review it, retire the preview (2026-11-21 01:05Z)

- **Task state · M0-16.** Rendering the map with Archify and running the visual review loop.
- Lane `claude-code-web`, by Claude Code (web). State: **partial**. Owner: operator.

## Round 12 — Archify renders the target and as-found maps with every gate passing, and compares them (2026-11-21 01:05Z)

- **Change · M0-16.** Archify 3.2.0, showcase profile, signal-flow preset. Both pages pass validate, deliver, check and browser-check with no advisory. The as-found model pins the fork at 73c5318 and its source citations were checked by the tool. The comparison reports 10 components added, 2 changed and 1 removed; 15 relationships added, 2 changed and 1 removed; 1 boundary added and 3 changed. The renders were made in a scratch directory and copied in; the hashes in the receipts identify the files.
- Lane `claude-code-web`, by Claude Code (web). State: **verified**. Reached: verified. Owner: operator. Grade A (Claude Code (web); ran the tool and read its receipts).
- Evidence: `docs/architecture/glasses-assistant/glasses-assistant.finalize-summary.json`; `docs/architecture/glasses-assistant/glasses-assistant.base.finalize-summary.json`; `docs/architecture/glasses-assistant/glasses-assistant.delta.receipt.json`; `docs/architecture/glasses-assistant/review/pages.sha256.json`; `docs/architecture/glasses-assistant/review/target.png`

## Round 13 — The first review found a blocking defect that every gate had passed (2026-11-21 01:05Z)

- **Note · M0-16.** Three read-only reviewers found 47 issues in round 1; all three reported that eight planned components looked live, because the renderer hides status tags at default zoom. The models were rewritten and re-rendered, and what is committed here is that second version. A second review round is running on it; its result is the next line about this task.
- Lane `claude-code-web`, by Claude Code (web). State: **partial**. Reached: executed. Owner: operator. Grade B (Claude Code (web); independent reviewers looked at captures; the author fixed and re-rendered).
- Closes on: round 2 reports no confirmed blocking finding.
- Evidence: `docs/architecture/glasses-assistant/review/round-1.md`

## Round 14 — Round 9 restated: the first commit held no key or token, and no network address other than loopback (2026-11-21 01:55Z)

- **Correction to round 9.** Round 9 said the first commit held no key, token or address. It did hold the loopback address in several lines. The rest of round 9 stands, including the item waiting on the operator.
- Lane `claude-code-web`, by Claude Code (web). State: **verified**. Reached: verified. Owner: operator. Grade A (Claude Code (web); searched the commit myself).
- Evidence: `a search of the first commit for dotted addresses found only the loopback address`

## Round 15 — The fork's code sends the Google and Notion access tokens of linked accounts to the vendor sandbox with each task (2026-11-21 01:55Z)

- **Probe.** Found by a reviewer in the second review round of the architecture map and confirmed in source at 73c5318. The Google token carries read access to Calendar and Gmail and file access to Drive. This was read in code, not observed running; whether an account was ever linked in a signed build is not known. The target design has no such path.
- Lane `claude-code-web`, by Claude Code (web). State: **verified**. Reached: verified. Owner: operator. Grade A (Claude Code (web); read the lines at the pinned commit).
- Closes on: the operator's decision.
- Open and human-held:
  - 1. If that build was ever signed in to Google or Notion and used, treat those tokens as shared with the sandbox vendor and decide whether to revoke them
- Evidence: `samples/CameraAccess/CameraAccess/Agent/AgentBridge.swift:255-279 @73c5318`; `samples/CameraAccess/CameraAccess/Agent/GoogleAuthManager.swift:12-16 @73c5318`; `docs/program/PLAN.md section 2.1`

## Round 16 — M0-16 running → done: Render the architecture map with Archify, review it, retire the preview (2026-11-21 01:55Z)

- **Task state · M0-16.** The target, as-found and comparison pages exist with passing receipts, three review rounds ran against the checklist, and the hand-drawn preview is deleted.
- Lane `claude-code-web`, by Claude Code (web). State: **verified**. Reached: verified. Owner: operator. Grade B (Claude Code (web); gates ran; reviewers were agents, not the operator).
- Evidence: `docs/architecture/glasses-assistant/glasses-assistant.finalize-summary.json`; `docs/architecture/glasses-assistant/review/round-3.md`; `commit 48769b2`

## Round 17 — The operator asked for a vault scaffold and a problem statement for a host-level AGENTS.md; both live in the skills repository (2026-11-21 01:55Z)

- **Note.** On 2026-11-21 the operator asked for a templates folder in the live vault with a change-report template, a research-round and a ground-truth-round template, the visual standard made known to every agent there, plain lowercase folder names, and a problem statement for a root-level AGENTS.md to hand on. The vault could not be reached from this lane, so the scaffold is delivered with an installer that only adds what is missing. None of it belongs in this public repository.
- Lane `claude-code-web`, by Claude Code (web). State: **verified**. Reached: executed. Owner: operator. Grade A (Claude Code (web); the operator's own words).
- Approval: operator 2026-11-21: 'create a lowercase t template folder ... the one template I'm asking you to make for sure is this report ... just write that up as a problem statement that will be handed off'.
- Open and human-held:
  - 1. Run the installer against the live vault, or have a local agent do it, and set the templates folder in Obsidian
- Evidence: `apptb/studiovault-universal-skills, branch claude/rayban-meta-glasses-assistant-cb0gqs: assets/vault, docs/problem-statements/host-agents-md.md`

## Round 18 — The map went through three review rounds; neither of the last two found a blocking defect (2026-11-21 01:55Z)

- **Change · M0-16.** Round 2: 31 findings, none blocking, 16 should-level findings all confirmed by separate verifiers. Round 3: 15 findings, none blocking, 6 confirmed. All three round-3 reviewers called the target ready to deliver once text edits were made. Those edits are in; every gate passes again with one accepted advisory for a three-bend route. The edits after round 3 were checked by the gates and the author, not by new reviewers. The readme lists the renderer's limits. This closes what round 13 left open.
- Lane `claude-code-web`, by Claude Code (web). State: **verified**. Reached: verified. Owner: operator. Grade B (Claude Code (web); independent reviewers and verifiers were agents; the operator has not looked).
- Commit: `48769b2`
- Evidence: `docs/architecture/glasses-assistant/review/round-2.md`; `docs/architecture/glasses-assistant/review/round-3.md`; `docs/architecture/glasses-assistant/glasses-assistant.finalize-summary.json`; `docs/architecture/glasses-assistant/glasses-assistant.delta.receipt.json`

## Round 19 — A read-only survey ran on the Mac and answered O-1, part of O-3 and O-10 (2026-11-24 17:20Z)

- **Probe.** A session started on the Mac from the Claude app ran a read-only survey on 2026-11-24 and the cloud lane read its report. Seen there: an M3 Ultra with 256 GB; the model router, both DeepSeek proxies, two local model servers and Unsloth Studio running as services that listen on the machine itself only; Hermes 0.23.2 installed with its gateway running; Claude Code and Codex on the command path, and none of DSH, Pi or OpenCode there; Xcode 27.2. The survey created, changed and started nothing and printed no secret value. Details that locate the machine are in the operator's private notes, not in this repository.
- Lane `claude-code-web`, by Claude Code (web). State: **verified**. Reached: executed. Owner: operator.
- Not touched: Nothing on the Mac was changed. No fabric probe of an image request was run; M0-04 is still open.
- Next: M0-18: move Unsloth Studio inside the Mac Studio frame on the map; M4-01 starts from which harnesses have a command on the path.
- Evidence: `docs/program/PLAN.md section 2.2 (rows marked host)`; `docs/program/PLAN.md section 9 (Answered so far)`

## Round 20 — New task M0-18: re-render the map with Unsloth Studio inside the Mac Studio frame (2026-11-24 17:20Z)

- **Change · M0-18.** The survey answered where Unsloth Studio runs, so the map's placement of it outside every machine frame is out of date. A map change goes through the tester script and a review by someone other than the author.
- Lane `claude-code-web`, by Claude Code (web). State: **proposed**. Owner: operator.
- Rollback: remove the task line and its acceptance row.
- Closes on: the acceptance for M0-18 in PLAN.md section 6.
- Evidence: `docs/program/TODO.md (M0-18)`; `docs/program/PLAN.md section 6 (M0-18)`

## Open and human-held, all rounds

Every item an agent raised for the operator and nobody has closed, oldest first. Close one with
`--resolves ROUND:ITEM` on the line that records its outcome. A correction does not close items.

- (round 6 item 1) Ratify or amend D-01 to D-12 (task M0-01)
- (round 7 item 1) O-1: the request said the Mac has 512 GB; the log and the operator's map say 256 GB. Which, or are there two Macs?
- (round 7 item 2) O-2: confirm 'NVIDIA Cutter' means the two-node DGX Spark cluster
- (round 7 item 3) O-3: confirm the fabric in the log is the live one, and say where Unsloth Studio runs
- (round 7 item 4) O-4: app name, bundle id and wake phrase
- (round 7 item 5) O-5: which glasses, which iPhone, which iOS version
- (round 7 item 6) O-6: which Obsidian vault is live and which folder receives glasses notes
- (round 7 item 7) O-7: how long photos are kept on the Mac
- (round 7 item 8) O-8: which frontier accounts have keys, which OpenAI model, and the daily spend cap
- (round 7 item 9) O-9: private repository (the default) or this public fork for the working code
- (round 7 item 10) O-10: how an agent reaches the Mac
- (round 9 item 1) Approve replacing this branch's history with one clean commit (or delete the branch and pull request so it can be pushed fresh), and decide whether to ask GitHub Support to purge the old commit
- (round 15 item 1) If that build was ever signed in to Google or Notion and used, treat those tokens as shared with the sandbox vendor and decide whether to revoke them
- (round 17 item 1) Run the installer against the live vault, or have a local agent do it, and set the templates folder in Obsidian
