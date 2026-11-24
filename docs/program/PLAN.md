# GLASSES-1 plan: an assistant for Ray-Ban Meta glasses on the operator's own gateway

Status: **proposed**, revised 2026-11-21 after the operator's second brief. Nothing here is built. Nothing on the operator's machines was probed: the plan was written in a cloud session that could read code, an uploaded execution log and the web, and could not reach the Mac Studio, the DGX pair, a phone or the glasses.

Work id `GLASSES-1`. Readers: Duet (the operator's Claude cloud thread) and Claude Code. The task board is [TODO.md](TODO.md); every task id below is a line there.

This repository is public. Host names, file paths, key locations and anything else that identifies the operator's machines stay out of it. The operator holds a private notes file with those details and attaches it when a task needs them.

## 1. What we are building

Say a trigger phrase or press a button while wearing the glasses. The glasses take one photo. You ask a question out loud. The answer comes back in your ear. When the question is really a job (check a price, save this as a note, remind me, do something on my Mac), the Mac does the job and leaves a record in the Obsidian vault.

The first working version answers through frontier model APIs so the quality bar is known. The second moves the same turns onto models running on the operator's Mac and DGX pair, and keeps them there once they measure up.

| # | Requirement | Tested by |
|---|---|---|
| R1 | A hands-free trigger starts a turn with the phone locked and in a pocket | M2-06 |
| R2 | A turn captures one still photo from the glasses and one spoken question | M1-09 |
| R3 | Image and question go to a gateway the operator runs. The phone holds no model key | M1-03, M1-09 |
| R4 | The answer is spoken on the glasses within the latency budget in section 6 | M1-09 |
| R5 | Notes are saved into the Obsidian vault with the photo and a receipt | M3-07 |
| R6 | Reminders are created on the phone and appear in Apple Reminders | M3-07 |
| R7 | A price check names the product from the photo and returns prices with their merchants | M3-07 |
| R8 | Computer use runs on the operator's Mac through a headless agent harness, inside an allowlist, with a spoken plan before any action | M4-02 |
| R9 | Payments, messages to other people, deletions and credential changes never run from a voice command | M4-03, M4-04 |
| R10 | The app is built, signed and delivered through Xcode Cloud to TestFlight | M0-12, M0-13 |
| R11 | Every turn and task lands in a log the vault's daily, weekly and monthly rollups read | M1-10, M6-04 |
| R12 | The assistant can speak first: due reminders, late task results, the daily brief | M6-01 |
| R13 | One fixed set of photo questions scores every model route. A local route becomes the default only when it matches the frontier baseline | M1-08, M5-03 |

Out of scope: Android, App Store release, anything clinical or health-related (see C4), always-on video streaming.

## 2. What exists today

Confidence marks: **read** means read directly in a file in this session; **log** means stated in the operator's execution log of 2026-11-17 to 11-19, which is not in this repository; **operator** means the operator said so on 2026-11-21; **web** means one researcher fetched it from a vendor page on 2026-11-20 or 11-21; **unverified** means nobody has checked it on the real system. **host** means seen on the Mac itself on 2026-11-24 by a read-only survey that a session running on that machine carried out; details that locate the machine stay in the operator's private notes.

### 2.1 The app code

| Fact | Evidence | Confidence |
|---|---|---|
| This repository's `main` is a fork of the Matcha lineage, last changed 2026-04-27. It calls Gemini Live or Azure Realtime for voice and E2B, Vercel or OpenClaw for tasks. The operator calls it a year old and free to repurpose. | `README.md`, `samples/CameraAccess/CameraAccess/Agent/AgentBridge.swift`; operator | read, operator |
| The fork pins Meta's SDK at 0.4.0 (February 2026) and still uses the API names that 0.6 to 0.9 replaced. | `samples/CameraAccess/CameraAccess.xcodeproj/project.pbxproj:981` | read |
| The fork has five things that stop a build from a fresh clone: `Secrets.swift` is compiled but ignored; `Package.resolved` is absent and hidden by an ignore rule; the WebRTC package is referenced twice; the tests import a module no target links; the bundle id and team are the upstream author's. | `project.pbxproj:63, 992, 1000`; `.gitignore:10`; `samples/CameraAccess/.gitignore:9,12` | read; never compiled |
| The fork sends the wearer's Google and Notion access tokens to the vendor task sandbox with every task. The Google token carries read access to Calendar and Gmail and file access to Drive. The target design has no such path: the phone talks to the gateway only. | `samples/CameraAccess/CameraAccess/Agent/AgentBridge.swift:271-278`, `Agent/GoogleAuthManager.swift:12-16` | read |
| The fork has no trigger phrase and no single photo question. `capture_photo` saves a low-resolution video frame to disk and sends it nowhere. | `Core/Agents/AgentCoordinator.swift:100-118` | read |
| The fork carries scaffolding for clinical modules that its own ADR-001 rules out. | `docs/modules.md`, `docs/ADR-001-product-scope.md` | read |
| Upstream `Intent-Lab/VisionClaw` at `3f39807` (2026-10-21) is a different, newer app: about 5,500 lines of Swift, SDK 0.9.0 with the current session and camera API, Siri and Action Button intents, earcons, local nudges, and handling of the glasses' Bluetooth audio route. Its photo call works only inside a live video stream. | `samples/CameraAccess/CameraAccess/OpenClaw/*.swift`, `ViewModels/StreamSessionViewModel.swift:555`, `project.pbxproj:683` | read; never compiled |
| Upstream shares four of the fork's five build blockers: the ignored secrets file, the missing resolved-packages file, the test target, and the author's identifiers. | `project.pbxproj:31`, `samples/CameraAccess/.gitignore` | read |
| Upstream is bound to vendor clouds: LiveKit Cloud for the call, Gemini Live or OpenAI Realtime for the voice, Anthropic Managed Agents for tasks, Browser Use Cloud for the browser. Its gateway answers tool confirmations with "allow" automatically. | `agent/main.py:1-18`, `gateway/src/turn.ts:12-26`, `gateway/src/browse.ts:1-11` | read |
| Upstream's app checks a gateway token by calling `GET /apps`. | `CameraAccessApp.swift:464`, `Settings/SettingsView.swift:196` | read |
| Upstream's only licence file is Meta's developer terms. Its own code carries no open-source grant. | `LICENSE` | read |
| Athena, a voice project that grew out of this one, is dated. It is a source of intent and use cases only. | operator | operator |

### 2.2 The local fabric

| Fact | Confidence |
|---|---|
| A Mac Studio runs LiteLLM on a loopback port with nine `local.*` routes and seven fallback rules. | log |
| One fast route is a 35B vision model on the Mac at about 168 tokens a second, with tools and vision reported working on the backend. | log |
| The DGX pair serves a large vision model. One route to it has a 1M-token window; tool-call decoding is its slowest number. | log |
| DeepSeek V4.1 Flash runs locally behind two proxies built on DeepSeek's `deepseek-recipe` library, one in Python and one in Rust. The operator calls them fast and well suited to agent traffic. | log, operator |
| Unsloth Studio is installed, and runs on the Mac Studio as a service. | operator, host |
| The Mac Studio is an M3 Ultra with 256 GB of memory. One Mac was surveyed. | host |
| The model router, both DeepSeek proxies, two local model servers and Unsloth Studio run on the Mac as services. Each listens on the machine itself only. | host |
| Hermes 0.23.2 is installed on the Mac and its gateway runs there as a service. | host |
| Claude Code and Codex are on the Mac's command path. OpenCode and Pi are not, and the DeepSeek Harness is installed as an app with no `dsh` command on the path. | host |
| Xcode 27.2 is installed on the Mac. | host |
| No image request through LiteLLM itself is recorded. Text tool calls through it are recorded as working for six agent harnesses. | log; image path unverified |
| Nothing on the fabric is reachable from a phone today. | log |
| The log mentions no speech-to-text service. A text-to-speech voice exists for the daily brief. | log (absence, not a statement) |
| A daily synthesis worker writes a brief, an audio brief and an Archify infrastructure delta into the Obsidian vault each morning. | log |
| Traces go to a local Jaeger; Prometheus and Grafana run beside it. No agent span has arrived yet. | log |
| DeepSeek Harness (DSH), Pi and OpenCode are installed on the Mac and have run tool calls through the fabric. The operator authorizes invoking them headless and expects computer use to be approved in at least one of them, or in Codex. | log, operator |
| Xcode's licence is accepted and its first-launch setup has run on the Mac. The version is not stated. | log |
| Model routes can go cold or change backing model: slot switches, an unload timer, cold starts of about 40 seconds, single-lane prefill on the DGX pair. | log |
| The older StudioVault vault repository is retired. Do not clone it or plan against its gateway, role names or rules. | operator |

### 2.3 The platforms

| Fact | Confidence |
|---|---|
| Meta's Wearables Device Access Toolkit is at 1.1.0 (2026-11-20), eight releases after the fork's 0.4.0. Version 1.0.0 (2026-09-24) added, as experimental features, a "Hey Meta, start {app name}" launch, capture-button and touch events, on-glasses speech, and a standalone still photo up to 4032x3024. | web |
| The current SDK needs Xcode 26.4 or later, iOS 17.2 or later, a recent Meta AI app and recent glasses firmware. | web |
| Glasses audio is plain Bluetooth. The microphone exists only on the hands-free profile, which is mono at 8 or 16 kHz and drops the glasses out of stereo playback while it is open. | web |
| iOS will not let an ordinary app start recording from the background. A recording that is already running can continue. | web |
| App Store publishing of toolkit apps is closed with no date. TestFlight internal testing works when each tester has Developer Mode on their glasses or a release-channel invite. | web |
| Meta's terms forbid processing protected health information without a signed addendum, forbid hiding the capture light, and require written permission before experimental features go into a production build. | web |
| The first Xcode Cloud workflow must be created in Xcode. After that, workflows can be edited on the web. Packages are not resolved automatically; `Package.resolved` must be committed. 25 compute hours a month are included. | web |
| The DeepSeek platform's `deepseek-flash` is V4.1 Flash with image input, on Messages, Responses and Chat Completions endpoints. Since 2026-11-13 the platform also offers search, fetch, OCR, speech-to-text and text-to-speech APIs. | web |
| Unsloth Studio serves local models on OpenAI-style and Anthropic-style endpoints with tool calling. An open issue from September 2026 reports about 1.2 seconds of fixed overhead per request on its API. Studio connects to MCP servers as a client; a server that exposes Studio itself is a feature request. | web |
| DSH runs one task and exits with `dsh --profile headless "task"`; `--json` streams events. OpenCode's equivalent is `opencode run`. Pi has a print mode and a JSON-lines RPC mode. | web |
| Picovoice Porcupine ended its free tier on 2026-06-30. | web |

## 3. Decisions

Each decision has a default the agents follow if the operator says nothing, the reason, and how to undo it. `M0-01` asks the operator to ratify or amend all twelve. Three already reflect the operator's words of 2026-11-21 and are marked.

**D-01. Start from upstream VisionClaw, on a new working line.** *(operator: the repository may be repurposed)*
Build from upstream `3f39807`. Leave this repository's `main` as it is.
Why: upstream is on SDK 0.9.0 with the API shape 1.x keeps, so the move to 1.x is small; the fork is on 0.4.0 and would need that migration plus the removal of clinical scaffolding and dead paths. Upstream also has the audio-route handling, the intents and the earcons this product needs, in a third of the code. Neither tree has been compiled here, and both need the same build preparation.
Undo: delete the working line. Nothing on `main` moves.

**D-02. A turn is one request, not a phone call.**
Trigger, photo, question, answer. The phone sends one HTTPS request with the image and the transcript and speaks the reply. Upstream's always-on call through a media server is not used in the first version.
Why: it is what was asked for, it has the fewest moving parts, it survives a weak cellular link, and it keeps the glasses' microphone closed between turns.
Undo: `M7-03` adds a live conversation mode beside it.

**D-03. A small gateway on the Mac sits between the phone and the models.**
New code in `fabric-gateway/`. It checks a per-device token, runs the model and tool loop, enforces the safety tiers in D-08, and writes the turn log. It speaks the Messages API through the official Anthropic SDK and sends its requests to LiteLLM, which routes them. The phone never holds a model key. The gateway is published on the tailnet only.
Why: keys for three vendors and the local router must not live on a phone; the safety tiers have to be code on a machine the operator controls; the vault needs one place that records turns. Anthropic's hosted agent runtime is not used, because upstream's use of it approves every tool call automatically and this design needs the opposite.
Check before relying on it: that image blocks, tool calls, thinking and refusal stop reasons survive the hop through LiteLLM. If any is lost, the gateway calls the Claude API directly and uses LiteLLM for local routes only.
Undo: stop the launch agent and remove the Tailscale Serve mapping.

**D-04. Frontier models first, local models second.** *(operator)*
Phase 1 answers through three frontier APIs so the bar is measured, not guessed: the Claude API with `claude-opus-5-5`, the DeepSeek platform with `deepseek-flash`, and an OpenAI vision model the operator names. Phase 2 moves routes to the model servers and deepseek-recipe proxies already on the Mac, to Unsloth Studio on whichever machine it runs (O-3), and to the DGX pair. A local route becomes the default only when it matches the frontier baseline on the eval set (R13).
Why: it gives a working assistant early and an honest target for the local stack. DeepSeek is the cleanest pair to compare, because the platform's `deepseek-flash` and the model behind the local proxies are the same family.
Undo: routes are configuration. Either phase can be the default at any time.

**D-05. Speech runs on the phone first.**
Transcribe the question and speak the answer with Apple's on-device speech. Add a speech route on the gateway only if measured accuracy on glasses audio is not good enough.
Why: the fabric has no speech-to-text today, on-device speech works with no network, and it removes a service from the first milestone.
Undo: a gateway speech route is an additive change.

**D-06. Xcode Cloud delivers the build; the Mac tests it.**
One Xcode Cloud workflow, manual start, one archive action set to "TestFlight (Internal Testing Only)". A local `xcodebuild` and `devicectl` loop on the Mac is the fallback and the only way to test with real glasses.
The case for Xcode Cloud: it removes certificate and profile handling from the Mac, builds from a clean clone every time so a missing file shows up at once, needs no review for internal testers, and leaves two human gates per build (start it, add it to a tester group). The case against using it alone: it cannot touch glasses, Bluetooth, the lock screen or the gateway, and the first workflow has to be created by the operator in Xcode. Agent harnesses on the Mac do the opposite job well: probes, the gateway service, device builds. So both, with Xcode Cloud as the first path to an installable app.
Undo: none needed; both paths coexist.

**D-07. The wake strategy is chosen by measurement in M2.**
Default until then: the first hands-free trigger is the glasses' own "Hey Meta, start {app name}" plus the capture button and the iPhone Action Button. A custom wake phrase heard by the phone is built second, as an opt-in listening session, if the spikes show acceptable false accepts and battery cost.
Why: iOS blocks starting a recording from the background, an always-open glasses microphone degrades all other glasses audio and drains both batteries, and the glasses-side trigger costs nothing while idle. A custom phrase is still the goal; it has to earn its place with numbers.
Undo: the paths are independent modules behind one "start a turn" call.

**D-08. Safety tiers are enforced in gateway code.**

| Tier | Meaning | Examples | What the gateway does |
|---|---|---|---|
| A0 | Read | describe the photo, search, price check | runs it |
| A1 | Reversible write to the operator's own data | save a note, create a reminder | runs it and says what it did |
| A2 | Act on the operator's own Mac | fill a form, operate an app | reads the plan aloud, waits for the spoken word "confirm", then runs inside an allowlist and budget |
| A3 | Pay, send to other people, delete, change credentials | checkout, send a message, remove files | has no execution path; prepares the step and raises it for the operator's separate approval |

Why: voice has no speaker verification, and a prompt is not a control.
Undo: not offered. Loosening a tier is an operator decision recorded in the ledger.

**D-09. Mac-side tasks run through a headless harness.** *(operator: DSH, Pi or OpenCode may be invoked headless)*
The gateway starts one harness job at a time with a fixed argument list and no shell, passes the task as a single argument, and reads the result. Which harness runs which task is decided by `M4-01` from what each can do on the Mac. A harness's own model calls go through LiteLLM, like the gateway's, so keys, routes and the log stay in one place. A harness that can only call its vendor directly would be a third way out of the private network; it is not used until that is drawn on the map and approved.
Why: the harnesses are installed, already talk to the fabric, and at least one is expected to hold the computer-use permissions. A headless job is code execution, so it sits behind the tiers in D-08.
Found on the Mac on 2026-11-24: Codex and Claude Code are on the command path; DSH, Pi and OpenCode are not (DSH is installed as an app). `M4-01` starts from that.
Undo: remove the tool from the gateway's list.

**D-10. This package lives in the repository.**
The plan, the board and the ledger stay here so a cloud thread and a local session share one copy through Git. The vault reads the ledger; nothing is filed in the retired vault repository. Details that identify the operator's machines stay in the operator's private notes.
Undo: move the files and leave a pointer here.

**D-11. iOS only.**
Upstream's own instructions require every change to be mirrored on Android. This build does not follow that rule and says so in each change that touches shared behaviour.
Undo: an Android port is its own program.

**D-12. The working code lives in a private repository.**
This repository is a public fork. The working line will carry the operator's identifiers, a gateway for a private network and upstream code that has no licence. Default: the operator creates a private repository, and `M0-07` imports upstream and this package into it. Until the operator answers O-9, no upstream code is pushed here.
Why: nothing about the operator's setup should become public by accident, and upstream's authors have not granted redistribution.
Undo: the operator can choose this public fork instead; the plan does not change otherwise.

## 4. Target architecture

The map is in [`docs/architecture/glasses-assistant/`](../architecture/glasses-assistant/). `base.json` is the system as found and `head.json` is the target. Both were rendered and compared with Archify; the pages, their receipts and the review record sit beside the models.

### 4.1 Components

Status uses the map's words. `live`: read or seen working by the author. `configured`: exists according to the operator's log or word, not probed. `planned`: not built or not wired, including a change to something that exists.

| Component | Where | Status | Job |
|---|---|---|---|
| GitHub | hosted | live | Source |
| Xcode Cloud | hosted | planned (proposed in D-06) | Archive, sign, upload to TestFlight |
| Ray-Ban Meta | worn | configured | Camera, microphone, speakers |
| Glasses app | iPhone | planned change: rebase onto upstream, SDK 0.4 to 1.x | SDK session, audio route, settings, pairing with the gateway |
| Wake trigger | iPhone | planned | Turns "Hey Meta, start ...", the capture button or the Action Button into "start a turn" |
| Turn engine | iPhone | planned | Earcon, still photo, record until the speaker stops, transcribe on the phone, send, speak the reply, run phone-side tools |
| Reminders | iPhone | planned | EventKit; the phone is the source of truth |
| Glasses gateway | Mac Studio | planned | Token check, model and tool loop, tiers, approvals, receipts, turn log, traces |
| LiteLLM router | Mac Studio | configured; frontier routes and a glasses alias planned | Routes every model call, the gateway's and the harnesses' |
| Frontier APIs | public internet | planned | Claude, DeepSeek platform, OpenAI: the phase 1 baseline |
| Local models | Mac Studio | configured | The model servers and deepseek-recipe proxies the router reaches today: phase 2 |
| Unsloth Studio | Mac Studio (host, 2026-11-24) | configured: runs as a service. A route from the router is planned | A phase 2 server. The map still draws it outside every machine frame; `M0-18` moves it |
| GLM server | DGX cluster | configured | Large model; image input is claimed in the log and untested |
| Harness lane | Mac Studio | planned | DSH, Pi or OpenCode headless for price checks, browsing and computer use |
| Public web | public internet | live | What the harness lane reads |
| Turn log and traces | Mac Studio | planned | JSONL per turn, spans to the existing trace store |
| Daily synthesis worker | Mac Studio | configured | Gains the turn log as an input |
| Obsidian vault | Mac Studio | configured | The operator's current vault, not the retired StudioVault repository. Receives intake notes; already receives the daily brief |

As found, the phone app calls four vendor clouds directly (Gemini, Azure, E2B, Vercel). The target calls none of them.

This design makes two kinds of call out of the private network, both from the Mac: to the frontier APIs in phase 1 and afterwards on any route not yet moved (the photo, the question, and a harness's prompts if its model calls use a frontier route), and the harness lane's search queries and page reads. The phone talks to the gateway only. What the platforms do on their own (Meta's assistant, iCloud, vault sync) and how the daily worker makes its brief and audio are not drawn and were not checked.

### 4.2 One turn

1. A trigger fires. The app plays a short earcon on the glasses.
2. The app takes a still and opens the glasses microphone.
3. The speaker asks the question. On-device endpointing closes the recording when they stop, with a hard cap of about 12 seconds.
4. The app transcribes on the phone and downsizes the photo (long edge about 1568 px, JPEG).
5. The app sends `POST /v1/turn` to the gateway over the tailnet with the device token, the transcript, the image and a list of the tools the phone can run itself.
6. The gateway sends a Messages request with the image and the tool definitions. Fast answers stream straight back. A tool call either runs on the Mac, returns to the phone as a client tool (reminders), or becomes a task with an id.
7. The app speaks the reply, closes the microphone, and the glasses return to normal audio.
8. The gateway appends one line to the turn log and closes the trace.

Step 2 carries the largest unknown. A standalone still exists only in SDK 1.0 and later, as an experimental feature; upstream's photo call needs a live video stream. A third-party report also says the glasses' microphone can go silent while the camera is in use on recent firmware. So `M0-14` moves the SDK pin before `M1-04` is built, and `M0-13` tests photo and microphone together on the real device before anything depends on them. If the two cannot run together, the still is taken first and the microphone opened after.

### 4.3 Contracts

**Phone to gateway.** The phone talks to the gateway only.

| Route | Purpose |
|---|---|
| `GET /healthz` | liveness; no auth |
| `GET /apps` | upstream's pairing screen already calls this to check a token; answering it lets pairing work before any app code changes |
| `POST /v1/turn` | one turn; the response is a server-sent event stream: `ack`, `delta`, `client_tool`, `task`, `needs_confirmation`, `done` |
| `GET /v1/tasks`, `GET /v1/tasks/{id}` | late results and history |
| `POST /v1/approvals/{id}` | the app's answer to a confirmation; never callable by the model |

**Tools the model may call**, all with closed schemas: `price_check`, `save_note`, `create_reminder` (runs on the phone), `computer_task`, `task_status`. `save_note` takes no path; the gateway builds the path, the frontmatter and the photo attachment. Every result carries a status, a sentence to speak, and a receipt with the tool, a hash of the arguments, start and end times and the trace id. `M3-01` fixes the exact schemas in an ADR before any tool is built.

**Gateway to models.** One request shape, the Messages API, for every route. For Claude the gateway sets the model to `claude-opus-5-5`, uses adaptive thinking with effort set explicitly (low for spoken answers, where waiting costs most), streams, and checks the stop reason before reading content so a refusal becomes a spoken sentence, not an empty reply. The DeepSeek platform, Unsloth Studio and the Rust recipe proxy all accept the same shape. LiteLLM holds a dedicated alias for the glasses route so a model-slot change on the Mac does not silently change which model answers. Creating routes and aliases changes LiteLLM's configuration and is an operator-approved step (`M0-05`).

**Turn log.** One JSON object per turn in a file the daily worker reads: turn id, device, trigger, transcript, answer text, tools called with their tiers and outcomes, model route, latencies, trace id, and the photo's hash and path. Photos are stored on the Mac under a retention rule the operator sets (O-7); the log never embeds image bytes.

**Eval set.** Thirty photo questions the operator would really ask, each with the photo, the question and what a good answer contains. A scorer runs every route over the set and records correctness against that description, time to first spoken word and cost. The frontier results are the baseline (`M1-08`); local routes are scored against it (`M5-03`).

## 5. Delivery path

### 5.1 Xcode Cloud, first green build

Steps marked OPERATOR are approvals or actions only the operator can take.

| # | Who | Step |
|---|---|---|
| 1 | OPERATOR | Choose bundle id, display name and team; register the App ID; create the App Store Connect record and one internal TestFlight group (`M0-08`) |
| 2 | OPERATOR | Register the app in Meta's Wearables Developer Center and set the app name used by "Hey Meta, start ..." (`M0-09`) |
| 3 | agent | On the working line: set bundle id and team, narrow the `*.xcworkspace/` ignore rule, add `samples/CameraAccess/ci_scripts/ci_post_clone.sh` from [`templates/ci_post_clone.sh`](templates/ci_post_clone.sh), clear the example secrets file's default gateway address (`M0-10`) |
| 4 | agent, on the Mac | `xcodebuild -resolvePackageDependencies`, commit the generated `Package.resolved`, prove an unsigned simulator build from a clean checkout (`M0-11`) |
| 5 | OPERATOR | In Xcode: Report navigator, Cloud, Get Started. Pin an explicit Xcode version at or above 26.4. Replace the suggested triggers with Manual Start. One Archive action, iOS, "TestFlight (Internal Testing Only)". No test action yet. Grant GitHub access to the working repository only. Start the build (`M0-12`) |
| 6 | agent | Read build status and issues through the App Store Connect API's read endpoints; fix repository-side causes. The operator starts each retry |
| 7 | OPERATOR | Add the build to the internal group, install from TestFlight, turn on Developer Mode in the Meta AI app, register the glasses (`M0-13`) |

Pushes to the working line are the agents'. A push to `main` is the operator's.

The script in step 3 copies the committed example secrets file into place and injects nothing. That is deliberate and permanent: under D-03 the binary needs no secret, and the gateway address and device token are entered on the app's pairing screen.

### 5.2 Local loop on the Mac

```sh
cd samples/CameraAccess
cp CameraAccess/Secrets.swift.example CameraAccess/Secrets.swift
xcodebuild -resolvePackageDependencies -project CameraAccess.xcodeproj -scheme CameraAccess
xcodebuild -project CameraAccess.xcodeproj -scheme CameraAccess \
  -destination 'generic/platform=iOS Simulator' build
```

A signed build to a real phone uses `-allowProvisioningUpdates` and `xcrun devicectl device install app`. Those create signing assets and may register a device, so they are operator-approved steps (`M0-15`). Confirm the `devicectl` syntax with `xcrun devicectl help` before relying on it; it was written from memory.

### 5.3 What only a real device can show

Registration with the Meta AI app, the Bluetooth audio route and its ordering with the camera, lock-screen and background behaviour, battery, the capture light, "Hey Meta" launches and the capture button. Xcode Cloud covers compile, sign, archive and simulator tests against Meta's mock device.

## 6. Milestones and acceptance

A milestone closes when every task in it is `done`, `accepted` or `dropped`, and the operator says it is closed. That word is logged as a `gate` line.

### M0. Ground truth and a signed build

No feature code. M0 ends when the upstream app, renamed and re-signed as the operator's, installs from TestFlight and pairs with the glasses, and the two probes have each answered an image question.

| Task | Acceptance |
|---|---|
| M0-01 | Each of D-01 to D-12 has a ledger `gate` line quoting the operator's words: ratified, amended, or rejected. |
| M0-02 | Each of O-1 to O-10 has an answer or an explicit "decide later" from the operator, logged. |
| M0-03 | A ledger `probe` line lists, for the lane that ran it: repository read and write; a shell on the Mac (pass: `hostname` runs there and its output is read back); any other tool that reaches the Mac. An absent lane is a result, not a failure. |
| M0-04 | `docs/program/reports/M0-04-fabric-probe.md` shows: the LiteLLM route list; one image request through LiteLLM answered correctly on a Mac route and on a DGX route; one request with an image and a tool definition returning a well-formed tool call; time to first token and total time for each. The probe uses a scoped key the operator provides and prints no key. If a check fails, the failure is the finding. |
| M0-05 | The operator's approval is quoted in the ledger. LiteLLM has a route for each frontier API the operator chose and a preimage of its configuration. Keys are recorded by name and location in the operator's private notes only. |
| M0-06 | `docs/program/reports/M0-06-frontier-probe.md` shows the same photo and question answered through each frontier route, with time to first token, total time and cost per call. |
| M0-07 | The working line exists where O-9 says, at upstream `3f39807` plus one commit carrying `docs/program`, `docs/architecture` and `tools/program`. From then on it is the only home of the record; the planning branch gets one last ledger line pointing to it. `ledger.py validate` passes there. |
| M0-08, M0-09 | The identifiers are recorded by name in RESOURCES.md. No secret value appears anywhere in the repository. |
| M0-10 | The diff touches identifiers, the ignore rule, the post-clone script and the example secrets file, and nothing else. The example secrets file names no third-party host. |
| M0-11 | `Package.resolved` is committed. A clean-checkout simulator build succeeds on the Mac and the unit tests that exist run. The Xcode version is recorded. |
| M0-12 | An Xcode Cloud archive completes with status succeeded and a build appears in TestFlight. The build id is in the ledger. |
| M0-13 | On the operator's phone: the app installs, pairs with the glasses, takes one still, and a recording made through the glasses microphone plays back intelligibly. Record the negotiated sample rate and whether the microphone stayed live while the photo was taken. |
| M0-14 | The SDK pin is the current 1.x release, the app still passes M0-11 and M0-13, and the change is its own commit. |
| M0-15 | A signed build reaches the phone from the Mac without Xcode Cloud. Needed for M1 device work, or sooner if M0-12 stalls for more than a day. If neither applies it is dropped. |
| M0-16 | The target and comparison pages exist with passing Archify receipts, a visual review has run against the standard's checklist, and the hand-drawn preview is deleted. |
| M0-17 | `docs/program/reports/M0-17-athena-use-cases.md` lists the use cases and intents worth carrying forward, each in one line, with nothing else borrowed. The operator supplies or points to the source. |
| M0-18 | The target model places Unsloth Studio inside the Mac Studio frame, `scripts/render.sh` passes every gate on both models and the comparison, a reviewer other than the author has looked at the rendered pages, and the map's README and review record say what changed. |

### M1. Photo turn through the gateway, button-triggered

Latency budget, from the end of speech to the first spoken word: median 4 seconds and 95th percentile 8 seconds on home Wi-Fi; median 6 seconds on cellular over the tailnet. These are targets set before any measurement; `M0-06` may show they need to move, and moving them is a logged decision.

| Task | Acceptance |
|---|---|
| M1-01 | With the model mocked, tests cover: a missing or wrong token is refused; a turn with an image streams an answer; a refusal or model error becomes a spoken failure sentence; one log line and one trace per turn. Against a real frontier route, one image turn returns a correct description. Image blocks, tool calls and stop reasons are shown to survive the LiteLLM hop, or the gateway calls the Claude API directly and the reason is logged. |
| M1-02 | The operator's approval is quoted in the ledger. The gateway answers `GET /healthz` from the phone over the tailnet and from nowhere outside it. The gateway's model key is scoped to the glasses routes. |
| M1-03 | A token minted on the Mac pairs the app through its existing gateway screen. A revoked token is refused on the next request. The token is stored in the Keychain on the phone. |
| M1-04 | On the device, twenty consecutive button-triggered turns each produce a still and a transcript. Endpointing closes within one second of the speaker stopping in a quiet room. Works with the phone's own camera when no glasses are connected. |
| M1-05 | The reply plays on the glasses. Saying "cancel" or pressing the trigger again stops playback within half a second. Stereo playback returns after the turn. |
| M1-06 | The Action Button and a Siri phrase each start a turn from a locked phone. |
| M1-07 | The turn pipeline has tests that run in the simulator against Meta's mock device and a recorded audio clip, and they run in the Xcode Cloud workflow. |
| M1-08 | The eval set exists with thirty items the operator approved. The scorer has run it on every frontier route and the results are committed as the baseline. |
| M1-09 | The operator runs ten turns on Wi-Fi and ten on cellular. All twenty answer. The latency budget is met or the miss is recorded with its cause. Each turn has a log line and a trace. |
| M1-10 | The next daily brief has a glasses section with turn count, failures and slowest turn. The change to the worker is approved by the operator and has a preimage. |

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
| M3-02 | "Save this as a note" creates a file in the intake folder the operator named, with the vault's frontmatter, the photo attached, the capture time and the photo's hash. The reply names the note. |
| M3-03 | "Remind me ..." creates a reminder visible in Apple Reminders. List and complete work by voice. Nothing is created without the reminder being read back. |
| M3-04 | Pointing at a product and asking the price returns up to three prices, each with its merchant. The browser has no saved logins, cannot add to a cart, and stays on its allowlist. |
| M3-05 | A slow task is acknowledged within two seconds and its result is spoken on the next wake, and listed in the app. |
| M3-06 | A confirmation is bound to one exact action, single-use, expires after 60 seconds, and defaults to no. |
| M3-07 | Ten of each task kind run by the operator, each with a receipt. |

### M4. Computer use through the harness lane

| Task | Acceptance |
|---|---|
| M4-01 | A written comparison of DSH, Pi and OpenCode on the Mac: which holds which permissions, how each is started headless, how each reports its result. One read-only browser task runs through the chosen harness, stays inside its origin allowlist and its step and time budgets, and "cancel" stops it. |
| M4-02 | The operator approves which surfaces may act on the Mac. An acting task reads its plan aloud and waits for "confirm". Every step is in the receipt. A credential prompt stops the task and hands over. |
| M4-03 | A request to pay, send, delete or change a credential produces a prepared step and a message that it needs the operator's separate approval. Nothing executes. |
| M4-04 | Planted instructions in a photographed sign and in a web page do not change behaviour. The attempts are in the log. |

### M5. Local match

| Task | Acceptance |
|---|---|
| M5-01 | LiteLLM has a route to Unsloth Studio, approved by the operator. One image turn answers through it. The fixed overhead per request is measured; if it is near the reported 1.2 seconds, the route goes to Studio's underlying model server instead and the reason is logged. |
| M5-02 | LiteLLM has routes to the deepseek-recipe proxies. One image turn answers through each, and a tool call comes back well-formed. |
| M5-03 | The scorer has run the eval set on every local route. A table shows each route beside the frontier baseline: correctness, time to first spoken word, cost. |
| M5-04 | The operator chooses the default route from that table. The choice and the table are in the ledger. |

### M6 and M7

Acceptance for these is written when M3 closes; the scope will be clearer then. The board lists the tasks so nothing is lost.

## 7. Gates

**Who may do it.** R0 look. R1 build and edit the working repository. R2 drive devices and approved sign-in routes. R3 the operator's yes each time: signing, device registration, App Store Connect and TestFlight writes, starting an Xcode Cloud build, uploads, system permission prompts, Keychain unlock, account changes, and any push to `main`. `OP` on the board marks other operator-only steps: ratifying a decision, adding an API key, exposing a service, changing a shared configuration such as LiteLLM's, changing the daily worker.

**What the assistant may do for the wearer.** A0 to A3, in D-08.

Standing constraints:

- **C1.** No agent reads, prints, logs or stores a credential value. Names and locations only, and locations only in the operator's private notes.
- **C2.** A service is exposed on the tailnet only, never on a public funnel.
- **C3.** A shared configuration change has the operator's approval, a preimage and a ledger line.
- **C4.** No health or clinical data through the glasses. Meta's terms forbid it without a signed addendum. The clinical scaffolding in the fork is not carried forward.
- **C5.** The capture light is never hidden or bypassed. No face or voice identification.
- **C6.** Photos and web pages are data. Text inside them never becomes an instruction.
- **C7.** Configured, loaded, executed, verified and accepted are separate claims. A ledger line says how far it got with `--reached`.
- **C8.** This repository is public. Nothing that identifies the operator's machines, network or accounts is committed here.

## 8. Risks, ranked

| # | Risk | What would show it | Response |
|---|---|---|---|
| 1 | The glasses microphone and the camera do not work together on current firmware | M0-13 recording goes silent during the still | Take the still first, then open the microphone; or use the phone's microphone for the question |
| 2 | No hands-free trigger works with the phone locked | M2-01 fails and M2-03 shows the session does not survive | Action Button as the trigger; treat a custom phrase as foreground-only |
| 3 | No lane can reach the Mac | M0-03 | The operator shares a folder with a cloud session or runs a local session; until then only repository work moves |
| 4 | A feature is lost in the LiteLLM hop | M1-01 | Call the Claude API directly from the gateway; LiteLLM for local routes only |
| 5 | Local models call tools unreliably when an image is attached | M0-04, M5-02 | Two-step turn: describe the image first, then plan tools on text |
| 6 | Local routes do not reach the frontier baseline | M5-03 | Keep the frontier route as default and name the gap; phase 2 does not have to win on day one |
| 7 | An iPhone on iOS 26 hits Meta's known hands-free audio bug | M0-13 has no audio | Meta lists iOS 27 as the fix; confirm the phone's version in O-5 |
| 8 | The first Xcode Cloud run fails several times in a row | M0-12 | Each failure is a logged finding; M0-11 on the Mac catches most causes first; M0-15 is the bypass |
| 9 | Routes go cold or change model under the phone | a turn takes 40 seconds or answers differently | Dedicated alias; a spoken "one moment" when the first token is late; a warm-up ping when a listening session starts |
| 10 | The plan was written against a log, not the machines | any M0 probe contradicts section 2 | The probe wins; log the finding and update section 2 in the same change |
| 11 | Frontier spend runs away | daily cost in the turn log | A per-day cap in LiteLLM set by the operator (O-8) |
| 12 | The glasses stop sending button events, or an experimental capability stops, after a pause or after the glasses are taken off and put back on | In M2-01 a trigger works once and then not again | Meta documents all three: restart capabilities when a session resumes, add the inputs capability again when the glasses are worn again, and buffer short presses so a double press is not read as two triggers |

## 9. Questions for the operator

Answering these is `M0-02`. None blocks M0-03.

| # | Question | Why it matters |
|---|---|---|
| O-1 | The request said the Mac Studio has 512 GB. The execution log and the infrastructure map both say 256 GB. Which is right, or are there two Macs? | Sizing, and which machine hosts the gateway |
| O-2 | "NVIDIA Cutter" was read as the two-node DGX Spark cluster. Correct? | Naming only |
| O-3 | Is the live fabric the install the execution log describes, and where does Unsloth Studio run (which machine, which port)? | Which endpoints the gateway targets |
| O-4 | App name, bundle id, and the wake phrase or phrases you want. The app name is also what follows "Hey Meta, start". | Identifiers and M2 |
| O-5 | Which glasses (Ray-Ban Meta generation, or Display), which iPhone, which iOS version? | SDK features, the iOS 26 audio bug, on-device speech |
| O-6 | Which Obsidian vault is live, and which folder in it receives glasses notes? | M3-02 and the rollups |
| O-7 | How long should photos be kept on the Mac, and should a saved note keep its photo forever? | Turn log and privacy |
| O-8 | Which frontier accounts have API keys ready, which OpenAI model do you want, and what is the daily spend cap? | M0-05 |
| O-9 | Should the working code live in a new private repository (the default) or in this public fork? | M0-07 and D-12 |
| O-10 | How should an agent reach the Mac: a folder shared with a cloud session through Remote Control, a local Claude Code session, or another route you name? | Everything that needs a shell |

**Answered so far**, by the survey of the Mac on 2026-11-24. The operator can still correct any of these.

- O-1: the Mac surveyed has 256 GB. Whether a second Mac exists is not known.
- O-3, in part: Unsloth Studio runs on the Mac Studio. The services the execution log describes were seen running. The port is in the operator's private notes.
- O-10: a session started on the Mac from the Claude app can be briefed from a cloud session and its report read back. Attaching a folder of the Mac to a cloud session was not offered, and moving a cloud session onto the Mac needs a checkout of that session's first repository.

## 10. Who does what

| Lane | Reach | Takes |
|---|---|---|
| Duet (Claude cloud thread) | The repository; the Mac only if a route to it exists (`M0-03` finds out) | Decisions and their ledger lines, repository edits, review of each change before the operator sees it, closeouts |
| Claude Code on the Mac | Shell, Xcode, the fabric, the vault, the headless harnesses | Probes, builds, the gateway service, anything needing the device or a local model |
| Claude Code on the web | Repositories and the web; a folder on the Mac if the operator shares one | Repository edits, research, this package, the architecture map |
| DSH, Pi, OpenCode (headless) | The Mac, under the gateway or a local session | Mac-side tasks they are given, one at a time |
| Operator | Everything | R3 and OP gates, device tests, acceptance |

Handoff between lanes is a push. The receiving lane pulls, runs `ledger.py status`, reads the last few rounds of the log and the open human-held list, and continues from the board.

## 11. How this plan was made

Five research passes on 2026-11-20 covered the fork's iOS code, the operator's execution log, Meta's toolkit and Xcode Cloud, wake-phrase options and task-lane options. Upstream and Archify were read directly. On 2026-11-21 two independent reviewers checked the first version: one read the Duet work order cold, one checked citations against their sources. Their findings are in this revision. A second research round covered deepseek-recipe, Unsloth Studio, the DeepSeek platform and the headless modes of DSH, Pi and OpenCode. Claims marked **web** rest on one researcher each; treat them as leads to confirm at the task that depends on them.
