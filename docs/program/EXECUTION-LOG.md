# EXECUTION LOG — StudioVault-Glasses (GLASSES-1)

Rendered from `docs/program/LEDGER.jsonl` by `tools/program/ledger.py render`. Do not edit by hand;
append a ledger line and render again. No secrets are recorded here.

## Round 1 — No live system was reachable; the plan rests on files, the operator's log and vendor pages (2026-11-20 23:58Z)

- **Probe.** This cloud session had the repositories, the uploaded execution log and web access. The gateway connector failed to connect and there was no Mac, phone or glasses. Every statement about the fabric is from the log of 2026-11-17 to 11-19 and is unverified until M0-04.
- Lane `claude-code-web`, by Claude Code (web). State: **partial**. Owner: operator. Grade C (Claude Code (web); nothing probed).
- Closes on: M0-03 and M0-04 report from a lane with a shell on the Mac.
- Not touched: No machine, service, account or shared config.
- Evidence: `StudioVault-Gateway connector: 502 at session start`; `docs/program/PLAN.md section 2`

## Round 2 — The fork's main cannot build from a fresh clone and is nine SDK releases behind (2026-11-20 23:58Z)

- **Probe.** Secrets.swift is a compiled source but ignored; Package.resolved is absent and hidden by a workspace ignore rule; the WebRTC package is referenced twice; the tests import a module no target links; bundle id and team are the upstream author's; the SDK pin is 0.4.0 against a current 1.1.0. Read in the project file, never compiled.
- Lane `claude-code-web`, by Claude Code (web). State: **partial**. Owner: operator. Grade B (Claude Code (web); read directly; no build).
- Closes on: M0-10 compiles the chosen baseline on the Mac.
- Evidence: `samples/CameraAccess/CameraAccess.xcodeproj/project.pbxproj:63,981`; `samples/CameraAccess/.gitignore:9,12`; `.gitignore:10`

## Round 3 — Upstream VisionClaw is the newer app, and every model and task call in it goes to a vendor cloud (2026-11-20 23:58Z)

- **Probe.** At 3f39807 upstream pins SDK 0.9.0, has a shared scheme, the still-photo call, Siri and Action Button intents, earcons and the glasses audio-route handling. It depends on LiveKit Cloud, Gemini Live or OpenAI Realtime, Anthropic Managed Agents and Browser Use Cloud, and its gateway answers tool confirmations with allow automatically. Its only licence file is Meta's developer terms.
- Lane `claude-code-web`, by Claude Code (web). State: **partial**. Owner: operator. Grade B (Claude Code (web); read directly; not run).
- Evidence: `Intent-Lab/VisionClaw@3f39807 samples/CameraAccess/CameraAccess.xcodeproj/project.pbxproj:683`; `Intent-Lab/VisionClaw@3f39807 agent/main.py:1-18`; `Intent-Lab/VisionClaw@3f39807 gateway/src/turn.ts:12-26`; `Intent-Lab/VisionClaw@3f39807 gateway/src/browse.ts:1-11`; `Intent-Lab/VisionClaw@3f39807 LICENSE`

## Round 4 — Ten decisions are proposed, led by building on upstream on a new branch and leaving main alone (2026-11-20 23:58Z)

- **Decision.** D-01 baseline is upstream on branch sovereign; D-02 a turn is one request; D-03 a small gateway on the Mac in front of LiteLLM; D-04 speech on the phone first; D-05 Xcode Cloud to TestFlight internal with a local fallback; D-06 wake strategy by measurement; D-07 safety tiers in gateway code; D-08 package in the repository with a vault pointer; D-09 iOS only; D-10 private build. Each has a default and an undo in the plan.
- Lane `claude-code-web`, by Claude Code (web). State: **proposed**. Owner: operator. Grade B (Claude Code (web); reasoned from read evidence; no measurement yet).
- Rollback: Each decision's undo line; D-01 is undone by deleting the sovereign branch.
- Closes on: M0-01: a gate line per decision quoting the operator.
- Open and human-held:
  - Ratify or amend D-01 to D-10 (M0-01)
- Evidence: `docs/program/PLAN.md section 3`

## Round 5 — The log and the infrastructure map both say the Mac Studio has 256 GB; the request said 512 (2026-11-20 23:58Z)

- **Probe.** The execution log calls it a 256 GB machine and sets the GPU wired limit to 245760 MB; every component title in the uploaded infrastructure map says Mac Studio 256GB. Nothing supports 512 GB. The vault repository also describes an earlier install under a different user whose tailnet node is offline.
- Lane `claude-code-web`, by Claude Code (web). State: **partial**. Owner: operator. Grade B (Claude Code (web); read in both uploads).
- Open and human-held:
  - O-1: is the Mac 256 GB or 512 GB, or are there two Macs
  - O-3: confirm the m3u install with LiteLLM on :4000 is the live fabric
- Evidence: `operator execution log line 931`; `infra-delta-20261120.html component titles`; `operator execution log line 140`

## Round 6 — Nothing on the fabric is reachable from a phone, and no image has been sent through LiteLLM (2026-11-20 23:58Z)

- **Probe.** LiteLLM listens on 127.0.0.1:4000 and Tailscale Serve publishes only the password vault. Vision was proven on the model backends by a test harness; no image request through :4000 is recorded. There is no speech-to-text service on this install. The design assumes image and tool calls work through LiteLLM, so this is the first thing to test.
- Lane `claude-code-web`, by Claude Code (web). State: **partial**. Owner: operator. Grade C (Claude Code (web); log only).
- Closes on: M0-04 report.
- Next: Run M0-04 before any gateway code is written.
- Evidence: `operator execution log lines 19, 110, 164, 157`

## Round 7 — Meta's SDK is at 1.1.0 with a glasses-side launch phrase; publishing is closed but TestFlight internal works (2026-11-20 23:58Z)

- **Probe.** Vendor pages read on 2026-11-20 say 1.0.0 added Hey Meta start app-name, capture-button events, on-glasses speech and a standalone still as experimental features; the current SDK needs Xcode 26.4 and iOS 17.2; the glasses microphone exists only on the hands-free profile; App Store publishing has no date. One researcher, not yet used in a build.
- Lane `claude-code-web`, by Claude Code (web). State: **partial**. Owner: operator. Grade C (Claude Code (web); single researcher, vendor pages).
- Closes on: M0-12 and M0-13 on the real device.
- Evidence: `https://github.com/meta/meta-wearables-dat-ios/blob/main/CHANGELOG.md`; `https://wearables.developer.meta.com/docs/develop/dat/voice-invocations`; `https://wearables.developer.meta.com/docs/develop/dat/microphones-and-speakers`; `https://github.com/meta/meta-wearables-dat-ios/discussions/339`

## Round 8 — The program package is written: plan, task board, resources, work order and a ledger tool (2026-11-20 23:58Z)

- **Change.** docs/program holds the plan with acceptance for every task through M4, a 48-task board, the resources list, the one-shot work order for Duet and a post-clone script template. tools/program/ledger.py appends, validates and renders this record and refuses lines without evidence, out-of-order lines and credential-shaped text. The tool was exercised end to end in a scratch copy, including its refusal cases.
- Lane `claude-code-web`, by Claude Code (web). State: **verified**. Owner: operator. Grade A (Claude Code (web); files written and the tool run in this session).
- Rollback: Delete docs/program, docs/architecture and tools/program; nothing else was changed.
- Not touched: Existing source, docs and the fork's main.
- Evidence: `docs/program/PLAN.md`; `docs/program/TODO.md`; `docs/program/DUET-WORK-ORDER.md`; `tools/program/ledger.py validate: ok`

## Round 9 — The architecture map exists as two models and a hand-drawn preview; Archify did not run (2026-11-20 23:58Z)

- **Change.** base.json is the system as found and head.json is the target, both in Archify's architecture format with stable ids. The Archify command was blocked in this session, so the Before, Delta and After page was drawn from the same two files by a throwaway script and looked at once in a headless browser in dark and light. It has no validate, deliver, check or browser-check receipt.
- Lane `claude-code-web`, by Claude Code (web). State: **partial**. Owner: operator. Grade C (Claude Code (web); one visual look; no automated gates).
- Closes on: M0-15: Archify finalize and compare on the Mac, preview deleted.
- Evidence: `docs/architecture/glasses-assistant/head.json`; `docs/architecture/glasses-assistant/base.json`; `docs/architecture/glasses-assistant/glasses-assistant.preview.html`

## Round 10 — The intended cross-checking pass did not run, so web claims rest on one researcher each (2026-11-20 23:58Z)

- **Note.** The multi-agent workflow and one research agent were blocked by this session's permission classifier. Five single-researcher passes ran instead and I read upstream, Archify and the cited code lines myself. Anything marked web in the plan is a lead to confirm at the task that depends on it.
- Lane `claude-code-web`, by Claude Code (web). State: **partial**. Owner: operator. Grade C (Claude Code (web); process note).
- Evidence: `docs/program/PLAN.md section 11`

## Round 11 — Eight questions and four setup steps are waiting on the operator (2026-11-20 23:58Z)

- **Gate.** The questions do not block the reach probe or the fabric probe. The setup steps are approvals or actions only the operator can take and they gate the first signed build.
- Lane `claude-code-web`, by Claude Code (web). State: **proposed**. Owner: operator.
- Open and human-held:
  - O-2: confirm NVIDIA Cutter means the two-node DGX Spark cluster
  - O-4: app name, bundle id and wake phrases
  - O-5: which glasses, which iPhone, which iOS
  - O-6: which vault folder receives glasses notes
  - O-7: how long photos are kept
  - O-8: which vault repository is canonical
  - M0-07: choose identifiers and create the App Store Connect record
  - M0-08: register the app in Meta Wearables Developer Center
  - M0-11: create the first Xcode Cloud workflow in Xcode and start the build
  - M0-12: install from TestFlight and pair the glasses
- Evidence: `docs/program/PLAN.md sections 5.1 and 9`

## Open and human-held, all rounds

Every item an agent raised for the operator and nobody has closed, oldest first. An item leaves this
list when a later line names its round in `--resolves`, or corrects it with `--supersedes`.

- (round 4) Ratify or amend D-01 to D-10 (M0-01)
- (round 5) O-1: is the Mac 256 GB or 512 GB, or are there two Macs
- (round 5) O-3: confirm the m3u install with LiteLLM on :4000 is the live fabric
- (round 11) O-2: confirm NVIDIA Cutter means the two-node DGX Spark cluster
- (round 11) O-4: app name, bundle id and wake phrases
- (round 11) O-5: which glasses, which iPhone, which iOS
- (round 11) O-6: which vault folder receives glasses notes
- (round 11) O-7: how long photos are kept
- (round 11) O-8: which vault repository is canonical
- (round 11) M0-07: choose identifiers and create the App Store Connect record
- (round 11) M0-08: register the app in Meta Wearables Developer Center
- (round 11) M0-11: create the first Xcode Cloud workflow in Xcode and start the build
- (round 11) M0-12: install from TestFlight and pair the glasses
