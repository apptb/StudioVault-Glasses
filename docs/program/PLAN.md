# GLASSES-1 plan: a sovereign assistant for Ray-Ban Meta glasses

Status: **proposed**, 2026-11-20. Nothing here is built and nothing on the operator's machines was probed. The plan was written in a cloud session that could read the repositories, the operator's execution log and the web, and could not reach the Mac Studio, the DGX pair, a phone or the glasses.

Work id `GLASSES-1`. Readers: Duet and Claude Code. The task board is [TODO.md](TODO.md); every task id used below is a line there.

## 1. What we are building

Say a wake phrase while wearing the glasses. The glasses take one photo. You ask a question out loud. The answer comes back in your ear from models running on your own machines. When the question is really a job (check a price, save this as a note, remind me), the Mac does the job and leaves a record in the vault.

Requirements, each written so it can be tested:

| # | Requirement | Tested by |
|---|---|---|
| R1 | A hands-free trigger starts a turn with the phone locked and in a pocket | M2-06 |
| R2 | A turn captures one still photo from the glasses and one spoken question | M1-08 |
| R3 | Image and question go to a gateway the operator runs; the default path uses no vendor model | M1-08, M6-01 |
| R4 | The answer is spoken on the glasses within the latency budget in section 6 | M1-08 |
| R5 | Notes are saved into the Obsidian vault with the photo and a receipt | M3-07 |
| R6 | Reminders are created on the phone and appear in Apple Reminders | M3-07 |
| R7 | A price check names the product from the photo and returns prices with their merchants | M3-07 |
| R8 | General computer use runs on the operator's Mac inside an allowlist, with a spoken plan before any action | M4-02 |
| R9 | Payments, messages to other people, deletions and credential changes never run from a voice command | M4-03, M4-04 |
| R10 | The app is built, signed and delivered through Xcode Cloud to TestFlight | M0-11, M0-12 |
| R11 | Every turn and task lands in a log the vault's daily, weekly and monthly rollups read | M1-09, M5-04 |
| R12 | The assistant can speak first: due reminders, late task results, the daily brief | M5-01 |

Out of scope: Android, App Store release, anything clinical or health-related (see C4), always-on video streaming.

## 2. What exists today

Confidence marks: **read** means read directly in a file this session; **log** means stated in the operator's execution log of 2026-11-17 to 11-19; **web** means a researcher fetched it from the vendor's page on 2026-11-20; **unverified** means nobody has checked it on the real system.

### 2.1 The app code

| Fact | Evidence | Confidence |
|---|---|---|
| `apptb/StudioVault-Glasses` `main` is a fork of the Matcha lineage, last changed 2026-04-27. It calls Gemini Live or Azure Realtime for voice and E2B, Vercel or OpenClaw for tasks. | `README.md`, `STUDIOVAULT-GLASSES-ROADMAP.md`, `samples/CameraAccess/CameraAccess/Agent/AgentBridge.swift` | read |
| The fork pins Meta's SDK at 0.4.0 (February 2026). | `samples/CameraAccess/CameraAccess.xcodeproj/project.pbxproj:981` | read |
| The fork will not build from a fresh clone: `Secrets.swift` is compiled but ignored, `Package.resolved` is absent and ignored, the WebRTC package is referenced twice, the tests import a module no target links, and the bundle id and team are the upstream author's. | iOS code read-through, 2026-11-20 | read; never compiled |
| The fork has no wake phrase and no single-shot photo question. `capture_photo` saves a low-resolution video frame to disk and sends it nowhere. | `Core/Agents/AgentCoordinator.swift:100-118` | read |
| The fork carries scaffolding for clinical modules that its own ADR-001 rules out. | `docs/modules.md`, `docs/ADR-001-product-scope.md` | read |
| The vault's portfolio review in June 2026 kept the project paused and said phase 1 must not resume against the April plan. | vault `10_Projects/Portfolio-Multipass-2026/CLASSIFY__2026-06-10__Portfolio__Verdicts.md:37` | read |
| Upstream `Intent-Lab/VisionClaw` at `3f39807` (2026-10-21) is a different, newer app: about 5,500 lines of Swift, SDK 0.9.0, a shared scheme, Siri and Action Button intents, earcons, local nudges, a still-photo call, and hard-won handling of the glasses' Bluetooth audio route. | `/samples/CameraAccess/CameraAccess/OpenClaw/*.swift`, `project.pbxproj:683` | read |
| Upstream is bound to vendor clouds: LiveKit Cloud for the call, Gemini Live or OpenAI Realtime for the voice, Anthropic Managed Agents for tasks, Browser Use Cloud for the browser. Its gateway approves tool confirmations automatically. | `agent/main.py`, `gateway/src/turn.ts:12-26`, `gateway/src/browse.ts` | read |
| Upstream's only licence file is Meta's developer terms. Its own code carries no open-source grant. | `LICENSE` | read |

### 2.2 The local fabric

| Fact | Evidence | Confidence |
|---|---|---|
| A Mac Studio (user `m3u`) runs LiteLLM 1.109.1 on `127.0.0.1:4000` with nine `local.*` routes and seven fallback rules. | execution log lines 19, 907-914 | log |
| `local.mac-fast` is Qwen3.6-35B on rapid-mlx at about 168 tokens a second, with tools and vision reported working on the backend. | log lines 164, 215 | log |
| `local.glm-chat` is GLM-5.3-Flash on two DGX Spark nodes with vision and a 1M-token window; tool-call decoding is its slowest number at 24 tokens a second. | log lines 129, 156-157, 173 | log |
| No image request through LiteLLM itself is recorded. Vision was proven on the backends by a test harness. | log read-through | unverified |
| Nothing on the fabric is reachable from a phone. Tailscale Serve publishes only the password vault. | log lines 19, 110 | log |
| There is no speech-to-text service on this install. Piper text-to-speech exists for the daily brief. | log lines 330-333 | log |
| A daily synthesis worker writes a brief, an audio brief and an Archify infrastructure delta into `/Users/m3u/Documents/Obsidian/StudioVault` at 07:00, with a 07:30 fallback. It ingests no traces today. | log lines 276-292, 898, 1128-1159 | log |
| Traces go to Jaeger at `127.0.0.1:4318`; Prometheus and Grafana run beside it. No agent span has arrived yet. | log lines 68-72, 898-903 | log |
| Xcode's licence is accepted and its first-launch setup has run on the Mac. The version is not stated. | log line 244 | log |
| Model routes can go cold or change backing model: slot switches, a 30-minute unload timer, 39 to 46 second cold starts, single-lane prefill on the DGX pair. | log lines 234-235, 274, 456, 181 | log |
| The vault repository `apptb/StudioVault` describes an earlier install (user `brain`, gateway on `:7777`, role names such as `vision` and `mac-stt`). Its tailnet node is offline. Do not plan against it. | `_system/runtime/SERVING-ROLES.json`, log line 140 | read, log |

### 2.3 The platforms

| Fact | Evidence | Confidence |
|---|---|---|
| Meta's Wearables Device Access Toolkit is at 1.1.0 (2026-11-20). 1.0.0 (2026-09-24) added, as experimental features, a "Hey Meta, start {app name}" launch, capture-button and touch events, on-glasses speech, and a standalone still photo up to 4032x3024. | SDK changelog and docs | web |
| The current SDK needs Xcode 26.4 or later, iOS 17.2 or later, Meta AI app V292 and glasses firmware V130. | version-dependencies page | web |
| Glasses audio is plain Bluetooth. The microphone exists only on the hands-free profile, which is mono at 8 or 16 kHz and drops the glasses out of stereo playback while it is open. | Meta microphones-and-speakers page | web |
| iOS will not let an ordinary app start recording from the background. A recording that is already running can continue. | Apple developer forum, DTS reply, February 2026 | web |
| App Store publishing of toolkit apps is closed with no date. TestFlight internal testing works when each tester has Developer Mode on their glasses or a release-channel invite. | Meta iOS guide (2026-10-29), Meta replies on GitHub | web |
| Meta's terms forbid processing protected health information without a signed addendum, forbid hiding the capture light, and require written permission before experimental features go into a production build. | wearables.developer.meta.com terms and acceptable-use policy | web |
| The first Xcode Cloud workflow must be created in Xcode. After that, workflows can be edited on the web. Packages are not resolved automatically; `Package.resolved` must be committed. 25 compute hours a month are included. | Apple Xcode Cloud documentation | web |
| Picovoice Porcupine ended its free tier on 2026-06-30. | community reports | web |

## 3. Decisions

Each decision has a default the agents will follow if the operator says nothing, the reason, and how to undo it. `M0-01` asks the operator to ratify or amend all ten. Until then, work that depends on a decision stays inside what its "undo" line covers.

**D-01. Start from upstream VisionClaw, not from the fork's `main`.**
Create a branch `sovereign` from upstream `3f39807` inside `apptb/StudioVault-Glasses` and build there. Leave `main` exactly as it is and tag it `legacy/matcha-azure-2026-04`.
Why: upstream is five SDK releases closer to current, already builds with a shared scheme, and has the Bluetooth route handling, the still-photo call, the intents and the earcons this product needs. The fork needs nine fixes before its first build and its plan was already judged stale.
Undo: delete the branch. Nothing on `main` moves. Making `sovereign` the default branch is a separate operator decision, later.

**D-02. A turn is one request, not a phone call.**
Wake, photo, question, answer. The phone sends one HTTPS request with the image and the transcript and speaks the reply. Upstream's always-on call through a media server is not used in the first version.
Why: it is what was asked for, it has the fewest moving parts, it survives a weak cellular link, and it keeps the glasses' microphone closed between turns.
Undo: `M6-03` adds a live conversation mode beside it.

**D-03. A small gateway on the Mac sits between the phone and LiteLLM.**
New code in `fabric-gateway/`. It checks a per-device token, runs the model and tool loop against LiteLLM, enforces the safety tiers in D-07, and writes the turn log. The phone never holds a model key. The gateway is published on the tailnet only.
Why: LiteLLM's master key must not live on a phone, the safety tiers need to be code on a machine the operator controls, and the vault needs one place that records turns.
Undo: stop the launch agent and remove the Tailscale Serve mapping.

**D-04. Speech runs on the phone first.**
Transcribe the question and speak the answer with Apple's on-device speech. Add a speech service on the Mac only if measured accuracy on glasses audio is not good enough.
Why: the fabric has no speech-to-text today, on-device speech works with no network, and it removes a service from the first milestone.
Undo: a gateway speech route is an additive change.

**D-05. Xcode Cloud to TestFlight internal is the delivery path.**
One workflow, manual start, one archive action set to "TestFlight (Internal Testing Only)". A local `xcodebuild` and `devicectl` loop on the Mac is the fallback and the way to test with real glasses during development.
Why: it is the operator's stated preference, it removes certificate handling, and internal testing needs no review. It still cannot touch real glasses, so the local loop is needed either way.
Undo: none needed; both paths coexist.

**D-06. The wake strategy is chosen by measurement in M2.**
Default until then: the first hands-free trigger is the glasses' own "Hey Meta, start {app name}" plus the capture button and the iPhone Action Button. A custom wake phrase heard by the phone is built second, as an opt-in listening session, if the spikes show acceptable false accepts and battery cost.
Why: iOS blocks starting a recording from the background, an always-open glasses microphone degrades all other glasses audio and drains both batteries, and the glasses-side trigger costs nothing while idle. A custom phrase is still the goal; it has to earn its place with numbers.
Undo: the two paths are independent modules behind one "start a turn" call.

**D-07. Safety tiers are enforced in gateway code.**

| Tier | Meaning | Examples | What the gateway does |
|---|---|---|---|
| A0 | Read | describe the photo, search, price check | runs it |
| A1 | Reversible write to the operator's own data | save a note, create a reminder | runs it and says what it did |
| A2 | Act on the operator's own Mac | fill a form, operate an app | reads the plan aloud, waits for the spoken word "confirm", then runs inside an allowlist and budget |
| A3 | Pay, send to other people, delete, change credentials | checkout, send a message, remove files | has no execution path; prepares the step and raises it for the operator's separate approval |

Why: the operator's standing rules already keep A3 as separate explicit authorization, voice has no speaker verification, and a prompt is not a control.
Undo: not offered. Loosening a tier is an operator decision recorded in the ledger.

**D-08. This package lives in the repository; the vault gets a pointer.**
Why: Duet and a local session share one copy through Git. The vault's own layout rule prefers plans and handoffs in the vault, so `M0-02` files a pointer note there and the operator can move the package later.
Undo: move the files and leave a pointer here.

**D-09. iOS only.**
Upstream's own instructions require every change to be mirrored on Android. This build does not follow that rule and says so in each change that touches shared behaviour.
Undo: an Android port is its own program.

**D-10. Private build, internal testers only.**
No public distribution and no redistribution of upstream's code, because upstream grants no licence for its own code and Meta has not opened publishing. Experimental SDK features are used only in Developer Mode and internal builds.
Undo: needs a licence from upstream's authors and a change in Meta's policy.

## 4. Target architecture

The map is in [`docs/architecture/glasses-assistant/`](../architecture/glasses-assistant/): `base.json` is today, `head.json` is the target, and the preview page shows both and the difference. `M0-15` replaces the preview with the Archify-finalized artifact.

### 4.1 Components

| Component | Where | New? | Job |
|---|---|---|---|
| Glasses app | iPhone | changed (upstream base) | SDK session, audio route, settings, pairing with the gateway |
| Wake listener | iPhone | new | Turns a trigger into "start a turn": glasses launch phrase, capture button, Action Button, and later a custom phrase |
| Turn engine | iPhone | new | Earcon, still photo, record until the speaker stops, transcribe, send, speak the reply, run phone-side tools |
| Reminders | iPhone | new | EventKit; the phone is the source of truth |
| Glasses gateway | Mac Studio | new | Token check, model and tool loop, tiers, approvals, receipts, turn log, traces |
| LiteLLM | Mac Studio | exists | Routes to the local models; gains one alias for the glasses route |
| rapid-mlx 35B, DGX pair | Mac Studio, DGX | exist | Vision and tool-calling models |
| Browser agent | Mac Studio | new | Read-only isolated browser for price checks; acting surfaces later |
| Turn log and traces | Mac Studio | new | JSONL per turn, spans to the existing Jaeger |
| Daily synthesis worker | Mac Studio | exists | Gains the turn log as an input |
| Obsidian vault | Mac Studio | exists | Receives intake notes; already receives the daily brief |
| Xcode Cloud | Apple | new | Archive, sign, upload to TestFlight |

### 4.2 One turn

1. A trigger fires. The app plays a short earcon on the glasses.
2. The app asks the SDK for a standalone still and, in parallel, opens the glasses microphone.
3. The speaker asks the question. On-device endpointing closes the recording when they stop, with a hard cap of about 12 seconds.
4. The app transcribes on the phone and downsizes the photo (long edge about 1568 px, JPEG).
5. The app sends `POST /v1/turn` to the gateway over the tailnet with the device token, the transcript, the image and a list of the tools the phone can run itself.
6. The gateway calls LiteLLM with the image and the tool definitions. Fast answers stream straight back. A tool call either runs on the Mac, returns to the phone as a client tool (reminders), or becomes a task with an id.
7. The app speaks the reply, closes the microphone, and the glasses return to normal audio.
8. The gateway appends one line to the turn log and closes the trace.

Step 2 carries the largest unknown in the design: a third-party report says the glasses' microphone can go silent while the camera is in use on recent firmware. The design uses a standalone still, not a video stream, to stay clear of that. `M0-12` and `M1-04` test it on the real device before anything depends on it.

### 4.3 Contracts

**Phone to gateway.** One long-lived design choice: the phone talks to the gateway only, never to LiteLLM.

| Route | Purpose |
|---|---|
| `GET /healthz` | liveness; no auth |
| `GET /v1/chat/completions` | the reachability probe upstream's pairing screen already sends; returns 200 for a valid token so pairing works before any app code changes |
| `POST /v1/turn` | one turn; response is a server-sent event stream: `ack`, `delta`, `client_tool`, `task`, `needs_confirmation`, `done` |
| `GET /v1/tasks`, `GET /v1/tasks/{id}` | late results and history |
| `POST /v1/approvals/{id}` | the app's answer to a confirmation; never callable by the model |

**Tools the model may call**, all with closed schemas: `price_check`, `save_note`, `create_reminder` (runs on the phone), `computer_task`, `task_status`. `save_note` takes no path; the gateway builds the path, the frontmatter and the photo attachment. Every result carries `status`, a sentence to speak, and a receipt with the tool, a hash of the arguments, start and end times and the trace id. `M3-01` fixes the exact schemas in an ADR before any tool is built.

**Model route.** The gateway reads its upstream from configuration: a base URL and a model name. The default is LiteLLM with a dedicated alias for the glasses route so that a slot switch on the Mac does not silently change which model answers. Creating that alias changes LiteLLM's config and is an operator-approved step (`M1-02`).

**Turn log.** One JSON object per turn in a file the daily worker reads: turn id, device, trigger, transcript, answer text, tools called with their tiers and outcomes, model route, latencies, trace id, and the photo's hash and path. Photos are stored on the Mac under a retention rule the operator sets (O-7); the log never embeds image bytes.

## 5. Delivery path

Two tracks. The cloud track produces signed builds. The local track is the only way to test with glasses.

### 5.1 Xcode Cloud, first green build

Steps marked OPERATOR are approvals or actions only the operator can take. Everything else is repository work.

| # | Who | Step |
|---|---|---|
| 1 | OPERATOR | Choose bundle id, display name and team (`M0-07`) |
| 2 | OPERATOR | Register the App ID; create the App Store Connect record and one internal TestFlight group (`M0-07`) |
| 3 | OPERATOR | Register the app in Meta's Wearables Developer Center; set the app name used by "Hey Meta, start ..." (`M0-08`) |
| 4 | agent | On `sovereign`: set bundle id and team, narrow the `*.xcworkspace/` ignore rule so `Package.resolved` can be committed, add `samples/CameraAccess/ci_scripts/ci_post_clone.sh` from [`templates/ci_post_clone.sh`](templates/ci_post_clone.sh) (`M0-09`) |
| 5 | agent, on the Mac | `xcodebuild -resolvePackageDependencies`, commit the generated `Package.resolved`, prove an unsigned simulator build from a clean checkout (`M0-10`) |
| 6 | OPERATOR | Approve the push |
| 7 | OPERATOR | In Xcode: Report navigator, Cloud, Get Started. Pin an explicit Xcode version at or above 26.4. Replace the suggested triggers with Manual Start. One Archive action, iOS, "TestFlight (Internal Testing Only)". No test action yet. Grant GitHub access to this repository only. Start the build (`M0-11`) |
| 8 | agent | Read build status and issues through the App Store Connect API's read endpoints; fix repository-side causes. The operator starts each retry. |
| 9 | OPERATOR | Add the build to the internal group, install from TestFlight, turn on Developer Mode in the Meta AI app, register the glasses (`M0-12`) |

Manual Start with no post-action gives two human gates per build: starting it, and adding it to a tester group. Keep both until the operator chooses otherwise.

The script in step 4 copies the committed example secrets file into place and injects nothing. That is deliberate and permanent: under D-03 the binary needs no secret, and the gateway address and device token are entered on the app's pairing screen.

### 5.2 Local loop on the Mac

```sh
cd samples/CameraAccess
cp CameraAccess/Secrets.swift.example CameraAccess/Secrets.swift
xcodebuild -resolvePackageDependencies -project CameraAccess.xcodeproj -scheme CameraAccess
xcodebuild -project CameraAccess.xcodeproj -scheme CameraAccess \
  -destination 'generic/platform=iOS Simulator' build
```

A signed build to a real phone uses `-allowProvisioningUpdates` and `xcrun devicectl device install app`. Those create signing assets and may register a device, so they are operator-approved steps (`M0-14`). Confirm the `devicectl` syntax with `xcrun devicectl help` before relying on it; it was written from memory.

### 5.3 What only a real device can show

Registration with the Meta AI app, the Bluetooth audio route and its ordering with the camera, lock-screen and background behaviour, battery, the capture light, "Hey Meta" launches and the capture button. Xcode Cloud covers compile, sign, archive and simulator tests against Meta's mock device.

## 6. Milestones and acceptance

A milestone closes when every task in it is `done` with evidence and the operator sets the milestone's last task to `accepted`.

### M0. Ground truth and a signed build

| Task | Acceptance |
|---|---|
| M0-01 | Each of D-01 to D-10 has a ledger `gate` line quoting the operator's words: ratified, amended, or rejected. |
| M0-02 | A pointer note exists in the vault under the Glasses project, written under the vault's own rules, linking to this package by repository path. No content is copied. |
| M0-03 | A ledger `probe` line lists, for the lane that ran it: repository read and write, shell on the Mac, the gateway connector, GitHub, and any lane that was absent. An absent lane is a result, not a failure. |
| M0-04 | A report file shows: the LiteLLM route list; one image request through `:4000` answered correctly on `local.mac-fast` and on `local.glm-chat`; one request with an image and a tool definition returning a well-formed tool call; time to first token and total time for each. If any fails, the failure is the finding. |
| M0-05 | Each of O-1 to O-8 has an answer or an explicit "decide later" from the operator, logged. |
| M0-06 | `sovereign` exists on `origin` at upstream `3f39807` plus one commit carrying `docs/program`, `docs/architecture` and `tools/program`. `main` is unchanged and tagged. `ledger.py validate` passes on the new branch. |
| M0-07, M0-08 | The identifiers are recorded by name in RESOURCES.md. No secret value appears anywhere in the repository. |
| M0-09 | From a fresh clone of `sovereign`, the only missing input to a build is the operator's signing. The diff touches identifiers, the ignore rule, the script, the resolved-packages file and the example secrets file, and nothing else. The example secrets file names no third-party host: upstream's default points at its authors' pilot gateway and must be cleared. |
| M0-10 | A clean-checkout simulator build succeeds on the Mac and the unit tests that exist run. The Xcode version is recorded. |
| M0-11 | An Xcode Cloud archive completes with status succeeded and a build appears in TestFlight. The build id is in the ledger. |
| M0-12 | On the operator's phone: the app installs, pairs with the glasses, takes one still, and a recording made through the glasses microphone plays back intelligibly. Record the negotiated sample rate and whether the microphone stayed live while the photo was taken. |
| M0-13 | The SDK pin is the current 1.x release, the app still passes M0-10 and M0-12, and the change is its own commit. |
| M0-14 | A signed build reaches the phone from the Mac without Xcode Cloud. Needed only if M0-11 stalls for more than a day, or for M1 device work. |
| M0-15 | `glasses-assistant.html` and the delta page exist with passing receipts, and the preview file is deleted. |

### M1. Sovereign photo turn, button-triggered

Latency budget, from the end of speech to the first spoken word: median 4 seconds and 95th percentile 8 seconds on home Wi-Fi; median 6 seconds on cellular over the tailnet. These are targets set before any measurement; `M0-04` may show they need to move, and moving them is a logged decision.

| Task | Acceptance |
|---|---|
| M1-01 | With LiteLLM mocked, tests cover: a missing or wrong token is refused; a turn with an image streams an answer; a model error becomes a spoken failure sentence; one log line and one trace per turn. Against the real LiteLLM on the Mac, one image turn returns a correct description. |
| M1-02 | The operator's approval is quoted in the ledger. The LiteLLM config has a preimage. The gateway answers `GET /healthz` from the phone over the tailnet and from nowhere outside it. |
| M1-03 | A token minted on the Mac pairs the app through its existing gateway screen. A revoked token is refused on the next request. The token is stored in the Keychain on the phone, not in UserDefaults. |
| M1-04 | On the device, twenty consecutive button-triggered turns each produce a still and a transcript. Endpointing closes within one second of the speaker stopping in a quiet room. Works with the phone's own camera when no glasses are connected. |
| M1-05 | The reply plays on the glasses. Saying "cancel" or pressing the trigger again stops playback within half a second. Stereo playback returns after the turn. |
| M1-06 | The Action Button and a Siri phrase each start a turn from a locked phone. |
| M1-07 | The turn pipeline has tests that run in the simulator against Meta's mock device and a recorded audio clip, and they run in the Xcode Cloud workflow. |
| M1-08 | The operator runs ten turns on Wi-Fi and ten on cellular. All twenty answer. The latency budget is met or the miss is recorded with its cause. Each turn has a log line and a trace. |
| M1-09 | The next daily brief has a glasses section with turn count, failures and slowest turn. The change to the worker is approved by the operator and has a preimage. |

### M2. Wake phrase

| Task | Acceptance |
|---|---|
| M2-01 | A written result for each: does "Hey Meta, start {app name}" start a turn with the phone locked; with the app not running; does the capture button reach the app; how long from phrase to earcon. |
| M2-02 | Both candidate spotters scored on at least one hour of the operator's own recorded glasses audio and thirty spoken wake phrases: false accepts per hour and misses. Candidates: livekit-wakeword and sherpa-onnx keyword spotting. |
| M2-03 | Two hours with the phone locked and a listening session running: battery drop on phone and glasses, what happened to music, and whether the session survived a phone call, a Siri request and folding the glasses. |
| M2-04 | The operator's decision is logged with the three results beside it. |
| M2-05 | The chosen path starts a turn hands-free. A second-stage check on the phone confirms a custom phrase before a turn opens. Settings cover phrases, sensitivity and quiet hours. |
| M2-06 | One day of normal wear: false accepts and battery within the budgets set in M2-04. |

### M3. Tasks, first set

| Task | Acceptance |
|---|---|
| M3-01 | An ADR fixes the tool schemas and the tier of each. Tests show an A3 verb has no code path and that text inside a photo or web page cannot change a tier. |
| M3-02 | "Save this as a note" creates a file in the intake folder with the vault's required frontmatter, the photo attached, the capture time, and the photo's hash. The reply names the note. |
| M3-03 | "Remind me ..." creates a reminder visible in Apple Reminders. List and complete work by voice. Nothing is created without the reminder being read back. |
| M3-04 | Pointing at a product and asking the price returns up to three prices, each with its merchant. The browser has no saved logins, cannot add to a cart, and stays on its allowlist. |
| M3-05 | A slow task is acknowledged within two seconds and its result is spoken on the next wake, and listed in the app. |
| M3-06 | A confirmation is bound to one exact action, single-use, expires after 60 seconds, and defaults to no. |
| M3-07 | Ten of each task kind run by the operator, each with a receipt. |

### M4. Computer use on the Mac

| Task | Acceptance |
|---|---|
| M4-01 | A read-only browser task stays inside its origin allowlist and its step and time budgets, and "cancel" stops it. |
| M4-02 | The operator approves which surface acts on the Mac. An acting task reads its plan aloud and waits for "confirm". Every step is in the receipt. A credential prompt stops the task and hands over. |
| M4-03 | A request to pay, send, delete or change a credential produces a prepared step and a message that it needs the operator's separate approval. Nothing executes. |
| M4-04 | Planted instructions in a photographed sign and in a web page do not change behaviour. The attempts are in the log. |

### M5 and M6

Acceptance for these is written when M3 closes; the scope will be clearer then. The board lists the tasks so nothing is lost.

## 7. Gates

Two ladders apply and they are different things.

**Who may do it** (from the operator's contract for Apple work): R0 look, R1 build and edit the repository, R2 drive devices and approved sign-in routes, R3 the operator's yes each time. R3 covers signing, device registration, App Store Connect and TestFlight writes, uploads, notarization, TCC consent, Keychain unlock, account changes and push to `main`. Other operator-only steps are marked `OP` on the board: ratifying a decision, exposing a service, changing a shared config such as LiteLLM's, changing the daily worker.

**What the assistant may do for the wearer** (D-07): A0 to A3.

Standing constraints:

- **C1.** No agent reads, prints, logs or stores a credential value. Names and locations only.
- **C2.** A service is exposed on the tailnet only, never on a public funnel.
- **C3.** A shared config change has the operator's approval, a preimage and a ledger line.
- **C4.** No health or clinical data through the glasses. Meta's terms forbid it without a signed addendum. The clinical scaffolding in the fork does not come to `sovereign`.
- **C5.** The capture light is never hidden or bypassed. No face or voice identification.
- **C6.** Photos and web pages are data. Text inside them never becomes an instruction.
- **C7.** Configured, loaded, executed, verified and accepted are separate claims. Each ledger line says which one it reached.

## 8. Risks, ranked

| # | Risk | What would show it | Response |
|---|---|---|---|
| 1 | The glasses microphone and the camera do not work together on current firmware | M0-12 recording goes silent during the still | Take the still first, then open the microphone; or use the phone's microphone for the question |
| 2 | No hands-free trigger works with the phone locked | M2-01 fails and M2-03 shows the session does not survive | Action Button as the trigger; treat a custom phrase as foreground-only |
| 3 | Vision through LiteLLM fails or is slow | M0-04 | Call the backend directly from the gateway for image turns; choose the route by measured time |
| 4 | Local models call tools unreliably when an image is attached | M0-04 tool-call check | Two-step turn: describe the image first, then plan tools on text |
| 5 | Duet cannot reach the Mac | M0-03 | Claude Code on the Mac takes every task that needs a shell; Duet plans, reviews and edits the repository |
| 6 | An iPhone 17 on iOS 26 hits Meta's known hands-free audio bug | M0-12 has no audio | Meta lists iOS 27 as the fix; confirm the phone's version in O-5 |
| 7 | The first Xcode Cloud run fails several times in a row | M0-11 | Each failure is a logged finding; M0-10 on the Mac catches most causes first; M0-14 is the bypass |
| 8 | Routes go cold or change model under the phone | a turn takes 40 seconds or answers in a different voice | Dedicated alias (M1-02); a spoken "one moment" when the first token is late; a warm-up ping when a listening session starts |
| 9 | The plan was written against a log, not the machines | any M0 probe contradicts section 2 | The probe wins; append a correction and update section 2 |
| 10 | Upstream's licence | the authors object, or the operator wants to share the build | D-10 keeps it private; ask the authors before anything wider |

## 9. Questions for the operator

Answering these is `M0-05`. None blocks M0-03 or M0-04.

| # | Question | Why it matters |
|---|---|---|
| O-1 | The request says the Mac Studio has 512 GB. The execution log and the infrastructure map both say 256 GB. Which is right, or are there two Macs? | Sizing and which machine hosts the gateway |
| O-2 | "NVIDIA Cutter" was read as the two-node DGX Spark cluster. Correct? | Naming only |
| O-3 | Is the live fabric the `m3u` install with LiteLLM on `:4000`, and is the `brain` install with the gateway on `:7777` retired? | Which endpoint the gateway targets and what Duet can reach |
| O-4 | App name, bundle id, and the wake phrase or phrases you want. The app name is also what follows "Hey Meta, start". | Identifiers and M2 |
| O-5 | Which glasses (Ray-Ban Meta generation, or Display), which iPhone, which iOS version? | SDK features, the iOS 26 audio bug, on-device speech |
| O-6 | Which folder in the live vault receives glasses notes? The vault's own documents name three different intake folders. | M3-02 |
| O-7 | How long should photos be kept on the Mac, and should a saved note keep its photo forever? | Turn log and privacy |
| O-8 | Is `apptb/StudioVault` still the canonical vault repository, or is the new vault on the `m3u` Mac separate? | Where M0-02's pointer note goes |

## 10. Who does what

| Lane | Reach | Takes |
|---|---|---|
| Duet (Claude cloud thread) | Repository through GitHub; the Mac only if its gateway connector is up (`M0-03` finds out) | Planning, decisions and their ledger lines, repository edits, review of every change before the operator sees it, closeouts |
| Claude Code on the Mac | Shell, Xcode, the fabric, the vault | Probes, builds, the gateway service, anything needing the device or a local model |
| Claude Code on the web | Repositories and the web; no machines | Repository edits, research, this package |
| Operator | Everything | R3 and OP gates, device tests, acceptance |

Handoff between lanes is a push. The receiving lane pulls, runs `ledger.py status`, reads the last few rounds of the log and the open human-held list, and continues from the board. Nothing else needs to be said in chat for the work to continue.

## 11. How this plan was made

Five research passes on 2026-11-20: the fork's iOS code; the operator's execution log and the vault's serving config; the vault's conventions for Duet, ledgers and rollups; Meta's toolkit and Xcode Cloud from vendor pages; wake-phrase and task-lane options. Upstream and Archify were read directly. The intended multi-agent verification pass did not run, so claims marked **web** rest on one researcher each. Treat them as leads to confirm at the task that depends on them.
