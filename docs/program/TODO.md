# GLASSES-1 task board

One line per task. Change a state with `python3 tools/program/ledger.py task <ID> --to <state> ...`; do not edit states by hand, because `validate` compares this board with the ledger. The line grammar is fixed so the tool and the vault can parse it:

`- [ ] **ID** Title · owner:<who> · gate:<gate> · state:<state>`

- **owner**: `operator`; `code` (Claude Code with a shell on the Mac); `any` (any agent with the reach the task needs, Duet included).
- **gate**: `R0` look. `R1` build and edit the working repository. `R2` drive devices and approved sign-in routes. `R3` the operator's yes each time: signing, App Store Connect, TestFlight, starting an Xcode Cloud build, device registration, system permission prompts, push to `main`. `OP` marks other operator-only steps: a decision, an API key, a service exposure, a shared configuration change.
- **state**: `queued`, `running`, `blocked`, `done` (verified by a probe), `accepted` (the operator's word), `dropped`.

Acceptance for every task through M5 is in [PLAN.md](PLAN.md) section 6 under the same id.

## M0 · Ground truth and a signed build

- [ ] **M0-01** Ratify decisions D-01 to D-12 or amend them · owner:operator · gate:OP · state:queued
- [ ] **M0-02** Answer the open questions O-1 to O-10 · owner:operator · gate:OP · state:queued
- [ ] **M0-03** Reach probe: what this lane can read, write and run · owner:any · gate:R0 · state:queued
- [ ] **M0-04** Fabric probe: local routes, an image through LiteLLM, an image with a tool call · owner:any · gate:R0 · state:queued
- [ ] **M0-05** Approve frontier API keys and their LiteLLM routes · owner:operator · gate:OP · state:queued
- [ ] **M0-06** Frontier probe: one image question through Claude, DeepSeek and OpenAI · owner:any · gate:R0 · state:queued
- [ ] **M0-07** Create the working line from upstream 3f39807 and carry this package onto it · owner:any · gate:R1 · state:queued
- [ ] **M0-08** Choose bundle id, app name and team; create the App Store Connect record · owner:operator · gate:R3 · state:queued
- [ ] **M0-09** Register the app in Meta Wearables Developer Center · owner:operator · gate:R3 · state:queued
- [ ] **M0-10** Prepare the project for a clean-clone build: identifiers, ignore rule, post-clone script, example secrets · owner:any · gate:R1 · state:queued
- [ ] **M0-11** On the Mac: resolve packages, commit Package.resolved, simulator build, unit tests · owner:code · gate:R1 · state:queued
- [ ] **M0-12** Create the Xcode Cloud workflow and get the first green archive · owner:operator · gate:R3 · state:queued
- [ ] **M0-13** Install from TestFlight, turn on Developer Mode, pair the glasses, check photo and microphone · owner:operator · gate:R3 · state:queued
- [ ] **M0-14** Move the Meta SDK pin to the current 1.x release in its own change · owner:any · gate:R1 · state:queued
- [ ] **M0-15** Fallback device loop from the Mac with xcodebuild and devicectl · owner:code · gate:R2 · state:queued
- [ ] **M0-16** Render the architecture map with Archify, review it, retire the preview · owner:any · gate:R1 · state:running
- [ ] **M0-17** Harvest intent and use cases from the Athena notes · owner:any · gate:R0 · state:queued

## M1 · Photo turn through the gateway, button-triggered

- [ ] **M1-01** Gateway skeleton: Messages client, turn endpoint with image, device-token auth, turn log, traces · owner:code · gate:R1 · state:queued
- [ ] **M1-02** Approve and apply: gateway on Tailscale Serve, a scoped model key for the gateway · owner:operator · gate:OP · state:queued
- [ ] **M1-03** Device token mint and pairing through the app's gateway screen · owner:code · gate:R1 · state:queued
- [ ] **M1-04** Turn engine in the app: still photo, utterance capture, endpointing, on-device transcript · owner:code · gate:R1 · state:queued
- [ ] **M1-05** Spoken reply and earcons on the glasses route, with cancel · owner:code · gate:R1 · state:queued
- [ ] **M1-06** Triggers without the screen: Action Button and Siri App Intent · owner:code · gate:R1 · state:queued
- [ ] **M1-07** Simulator and mock-device tests for the turn pipeline in CI · owner:code · gate:R1 · state:queued
- [ ] **M1-08** Eval set and scorer: thirty photo questions, frontier baseline recorded · owner:any · gate:R1 · state:queued
- [ ] **M1-09** End-to-end acceptance on home Wi-Fi and on cellular over the tailnet · owner:operator · gate:R2 · state:queued
- [ ] **M1-10** Daily synthesis worker reads the turn log · owner:any · gate:OP · state:queued

## M2 · Wake phrase

- [ ] **M2-01** Spike: glasses-side trigger with the SDK's launch phrase and button events · owner:code · gate:R2 · state:queued
- [ ] **M2-02** Spike: on-phone keyword spotter on recorded glasses audio, two candidates · owner:code · gate:R2 · state:queued
- [ ] **M2-03** Spike: a locked-phone listening session for two hours, battery and interruptions · owner:operator · gate:R2 · state:queued
- [ ] **M2-04** Decide the wake strategy from the three spikes · owner:operator · gate:OP · state:queued
- [ ] **M2-05** Build the chosen wake path and its listening-session state machine · owner:code · gate:R1 · state:queued
- [ ] **M2-06** One-day wear test against the false-accept and battery budgets · owner:operator · gate:R2 · state:queued

## M3 · Tasks, first set

- [ ] **M3-01** Typed tool contract and the tier table in gateway code · owner:code · gate:R1 · state:queued
- [ ] **M3-02** Save a note with its photo into the vault intake folder · owner:code · gate:R1 · state:queued
- [ ] **M3-03** Create, list and complete reminders on the phone with EventKit · owner:code · gate:R1 · state:queued
- [ ] **M3-04** Price check: product from the photo, search, read-only browser · owner:code · gate:R1 · state:queued
- [ ] **M3-05** Two-speed turns: acknowledge fast, deliver late results on the next wake · owner:code · gate:R1 · state:queued
- [ ] **M3-06** Spoken confirmation: fixed phrases, bound to one action, expiring · owner:code · gate:R1 · state:queued
- [ ] **M3-07** Acceptance: ten tasks of each kind with receipts · owner:operator · gate:R2 · state:queued

## M4 · Computer use through the harness lane

- [ ] **M4-01** Compare DSH, Pi and OpenCode headless on the Mac; run one read-only browser task · owner:code · gate:R1 · state:queued
- [ ] **M4-02** Acting tasks on the operator's own Mac through the harness lane · owner:code · gate:OP · state:queued
- [ ] **M4-03** Operator-only stop: prepare, do not execute, raise it for approval · owner:code · gate:R1 · state:queued
- [ ] **M4-04** Injection test: instructions in photo text and web pages must not raise a tier · owner:code · gate:R1 · state:queued

## M5 · Local match

- [ ] **M5-01** Route to Unsloth Studio and measure its per-request overhead · owner:any · gate:OP · state:queued
- [ ] **M5-02** Route to the deepseek-recipe proxies with images and tools · owner:any · gate:OP · state:queued
- [ ] **M5-03** Run the eval set on every local route against the frontier baseline · owner:any · gate:R1 · state:queued
- [ ] **M5-04** Choose the default route from the scores · owner:operator · gate:OP · state:queued

## M6 · Proactive

- [ ] **M6-01** Local nudges tied to reminders, calendar and the daily brief · owner:code · gate:R1 · state:queued
- [ ] **M6-02** Push channel for late results · owner:operator · gate:R3 · state:queued
- [ ] **M6-03** Scheduled check-ins started from the Mac · owner:code · gate:OP · state:queued
- [ ] **M6-04** Weekly and monthly rollups in the vault from the ledger and the turn log · owner:any · gate:R1 · state:queued

## M7 · Hardening and options

- [ ] **M7-01** Remove or switch off the vendor paths inherited from upstream that the gateway replaces · owner:code · gate:R1 · state:queued
- [ ] **M7-02** Security pass: token rotation, transport, log redaction, photo retention · owner:code · gate:R1 · state:queued
- [ ] **M7-03** Optional live conversation mode on a self-hosted media server · owner:operator · gate:OP · state:queued
