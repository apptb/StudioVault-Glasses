# GLASSES-1 task board

One line per task. Change a state with `python3 tools/program/ledger.py task <ID> --to <state> ...`; do not edit states by hand. The line grammar is fixed so the tool and the vault can parse it:

`- [ ] **ID** Title · owner:<who> · gate:<gate> · state:<state>`

- **owner**: `operator`, `duet`, `code` (Claude Code, local or web), or `any` (whichever agent has the reach).
- **gate**: the Apple ladder from the operator's contract. `R0` look, `R1` build and edit in the repository, `R2` drive devices and approved sign-in routes, `R3` the operator's yes each time (signing, App Store Connect, TestFlight, device registration, uploads, TCC, Keychain, push to `main`). `OP` marks other operator-only steps: a decision, a service exposure, a shared config change.
- **state**: `queued`, `running`, `blocked`, `done` (verified by a probe), `accepted` (the operator's word), `dropped`.

Acceptance for every task is in [PLAN.md](PLAN.md) section 6 under the same ID. A task with no acceptance line there is not ready to start.

## M0 · Ground truth and a signed build

No feature code. Ends when an unmodified upstream app, rebranded, installs from TestFlight and reaches the gateway probe.

- [ ] **M0-01** Ratify decisions D-01 to D-10 or amend them · owner:operator · gate:OP · state:queued
- [ ] **M0-02** File the vault pointer note for GLASSES-1 · owner:duet · gate:R1 · state:queued
- [ ] **M0-03** Reach probe: what this lane can read, write and run · owner:any · gate:R0 · state:queued
- [ ] **M0-04** Fabric probe: LiteLLM routes, an image through :4000, a tool call with an image · owner:any · gate:R0 · state:queued
- [ ] **M0-05** Answer the open questions O-1 to O-8 · owner:operator · gate:OP · state:queued
- [ ] **M0-06** Create branch `sovereign` from upstream HEAD and carry the program package onto it · owner:any · gate:R1 · state:queued
- [ ] **M0-07** Choose bundle id, app name and team; create the App Store Connect record · owner:operator · gate:R3 · state:queued
- [ ] **M0-08** Register the app in Meta Wearables Developer Center; enable Developer Mode on the glasses · owner:operator · gate:R3 · state:queued
- [ ] **M0-09** Make the project build from a fresh clone: identifiers, secrets script, resolved packages · owner:code · gate:R1 · state:queued
- [ ] **M0-10** Prove the build locally on the Mac: resolve packages, build for simulator, run unit tests · owner:code · gate:R1 · state:queued
- [ ] **M0-11** Create the Xcode Cloud workflow and get the first green archive · owner:operator · gate:R3 · state:queued
- [ ] **M0-12** Install from TestFlight, pair the glasses, confirm a photo and audio route on the device · owner:operator · gate:R3 · state:queued
- [ ] **M0-13** Move the DAT SDK pin to the current 1.x release in its own change · owner:code · gate:R1 · state:queued
- [ ] **M0-14** Fallback device loop from the Mac with xcodebuild and devicectl · owner:code · gate:R2 · state:queued
- [ ] **M0-15** Render the architecture map with Archify on the Mac and replace the preview · owner:any · gate:R1 · state:queued

## M1 · Sovereign photo turn, button-triggered

One press, one photo, one spoken question, one spoken answer from the local fabric.

- [ ] **M1-01** Gateway skeleton: health, turn endpoint with image, device-token auth, turn log, traces · owner:code · gate:R1 · state:queued
- [ ] **M1-02** Approve and apply: LiteLLM alias for the glasses route, gateway on Tailscale Serve · owner:operator · gate:OP · state:queued
- [ ] **M1-03** Device token mint and pairing through the app's gateway screen · owner:code · gate:R1 · state:queued
- [ ] **M1-04** Turn engine in the app: still photo, utterance capture, endpointing, on-device transcript · owner:code · gate:R1 · state:queued
- [ ] **M1-05** Spoken reply and earcons on the glasses route, with cancel · owner:code · gate:R1 · state:queued
- [ ] **M1-06** Triggers without the screen: Action Button and Siri App Intent · owner:code · gate:R1 · state:queued
- [ ] **M1-07** Simulator and mock-device tests for the turn pipeline in CI · owner:code · gate:R1 · state:queued
- [ ] **M1-08** End-to-end acceptance on home Wi-Fi and on cellular over the tailnet · owner:operator · gate:R2 · state:queued
- [ ] **M1-09** Daily synthesis worker reads the turn log · owner:any · gate:OP · state:queued

## M2 · Wake phrase

Decided by measurement. Two spikes, one operator decision, then the build.

- [ ] **M2-01** Spike: glasses-side trigger with the DAT voice invocation and input events · owner:code · gate:R2 · state:queued
- [ ] **M2-02** Spike: on-phone keyword spotter on recorded glasses audio, two candidates · owner:code · gate:R2 · state:queued
- [ ] **M2-03** Spike: a locked-phone listening session for two hours, battery and interruptions · owner:operator · gate:R2 · state:queued
- [ ] **M2-04** Decide the wake strategy from the three spikes (D-06) · owner:operator · gate:OP · state:queued
- [ ] **M2-05** Build the chosen wake path and its listening-session state machine · owner:code · gate:R1 · state:queued
- [ ] **M2-06** One-day wear test against the false-accept and battery budgets · owner:operator · gate:R2 · state:queued

## M3 · Tasks, first set

Notes, reminders and price checks, each with a receipt.

- [ ] **M3-01** Typed tool contract and the tier table in gateway code · owner:code · gate:R1 · state:queued
- [ ] **M3-02** Save a note with its photo into the vault intake folder · owner:code · gate:R1 · state:queued
- [ ] **M3-03** Create, list and complete reminders on the phone with EventKit · owner:code · gate:R1 · state:queued
- [ ] **M3-04** Price check: product from the photo, search, read-only isolated browser · owner:code · gate:R1 · state:queued
- [ ] **M3-05** Two-speed turns: acknowledge fast, deliver late results on the next wake · owner:code · gate:R1 · state:queued
- [ ] **M3-06** Spoken confirmation: fixed phrases, bound to one action, expiring · owner:code · gate:R1 · state:queued
- [ ] **M3-07** Acceptance: ten tasks of each kind with receipts in the vault · owner:operator · gate:R2 · state:queued

## M4 · Computer use on the Mac

- [ ] **M4-01** Read-only browser task on an origin allowlist with step and time budgets · owner:code · gate:R1 · state:queued
- [ ] **M4-02** Acting tasks on the operator's own Mac through the existing computer-use lane · owner:code · gate:OP · state:queued
- [ ] **M4-03** Operator-only stop: prepare, do not execute, raise a card · owner:code · gate:R1 · state:queued
- [ ] **M4-04** Injection test: instructions in photo text and web pages must not raise a tier · owner:code · gate:R1 · state:queued

## M5 · Proactive

- [ ] **M5-01** Local nudges tied to reminders, calendar and the daily brief · owner:code · gate:R1 · state:queued
- [ ] **M5-02** Push channel for late results · owner:operator · gate:R3 · state:queued
- [ ] **M5-03** Scheduled check-ins started from the Mac · owner:code · gate:OP · state:queued
- [ ] **M5-04** Weekly and monthly rollups in the vault from the ledger and the turn log · owner:any · gate:R1 · state:queued

## M6 · Hardening and options

- [ ] **M6-01** Remove or switch off the vendor-cloud paths inherited from upstream · owner:code · gate:R1 · state:queued
- [ ] **M6-02** Security pass: token rotation, transport, log redaction, photo retention · owner:code · gate:R1 · state:queued
- [ ] **M6-03** Optional live conversation mode on a self-hosted media server · owner:operator · gate:OP · state:queued
