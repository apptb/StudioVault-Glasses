# GLASSES-1 resources

What the build draws on and how sure we are of each fact. Update a row when a probe changes it, and log the change.

This repository is public. Host names, local paths, ports of private services and key locations are not recorded here. They are in the operator's private fabric notes, which the operator attaches to a task that needs them.

"web" rows were read from the vendor's page by one researcher on 2026-11-20 or 11-21 and have not been used yet.

## Repositories

| What | Where | Pin | Notes |
|---|---|---|---|
| This repository | `apptb/StudioVault-Glasses` (public fork) | `main` at `73c5318` | Matcha lineage. Free to repurpose per the operator; `main` stays as it is under D-01. |
| App baseline | `Intent-Lab/VisionClaw` | `3f39807` (2026-10-21) | Public. Its `LICENSE` is Meta's developer terms only; no grant for its own code (D-12). |
| Meta's SDK and sample | `meta/meta-wearables-dat-ios` | tag `1.1.0` | `facebook/meta-wearables-dat-ios` still resolves as an alias. Keep one URL in the project and in `Package.resolved`. Pin by version. |
| deepseek-recipe | `deepseek-ai/deepseek-recipe` | 0.2 | MIT. Rust libraries with Python bindings that turn Messages, Chat Completions and Responses requests into DeepSeek V4 and V4.1 prompts and parse the output back, images included. The operator's two local proxies are built on it. |
| Visual standard skill | `apptb/studiovault-universal-skills`, `skills/visual-standard/` | branch `claude/rayban-meta-glasses-assistant-cb0gqs` until its pull request merges | The operator's minimum for architecture output. Private repository. |
| Archify | `tt-a1i/archify` | 3.2.0 | Apache-2.0. Do not install the unrelated npm package named `archify`. |

## Models

| Route | Model | Facts | Source |
|---|---|---|---|
| Claude API | `claude-opus-5-5` | Image input, tool use, 1M context. Thinking cannot be disabled; set effort explicitly (it defaults to medium). Check `stop_reason` before reading content. Forced tool choice is rejected; use automatic tool choice. | Anthropic's API reference, as bundled with Claude Code on 2026-11-21 |
| DeepSeek platform | `deepseek-flash` (V4.1 Flash) | Image input, 1M context, Messages, Responses and Chat Completions endpoints. Search, fetch, OCR, speech-to-text and text-to-speech APIs since 2026-11-13. | web: https://benchlm.ai/deepseek/api-pricing ; https://cryptobriefing.com/deepseek-opens-app-features-developers-api |
| OpenAI platform | to be named by the operator (O-8) | One source lists `gpt-6-sol`, `gpt-6-luna` and `gpt-6.1-terra`, the last stressing visual reasoning and computer use. Confirm on OpenAI's own model page before use. | web, single secondary source |
| Unsloth Studio | whatever is loaded | OpenAI-style `/v1/chat/completions` and `/v1/responses`, Anthropic-style `/v1/messages`, bearer key, tool calling. An open issue reports about 1.2 s fixed overhead per request on Studio's API; its bundled model server does not have it. | web: https://unsloth.ai/docs/basics/api ; https://github.com/unslothai/unsloth/issues/12364 |
| deepseek-recipe proxies | DeepSeek V4.1 Flash, local | Same family as `deepseek-flash`. The Rust proxy serves chat, responses and messages. | operator's log; operator |
| DGX pair | large vision model | One route has a 1M-token window. | operator's log |

## Agent harnesses on the Mac

The operator authorized invoking these headless on 2026-11-21. A headless job is code execution; D-08 and D-09 govern how the gateway uses them.

| Harness | One-shot form | Notes | Source |
|---|---|---|---|
| DeepSeek Harness | `dsh --profile headless "task"` | Prints the final answer and exits. `--json` streams events; `--session-id` resumes. Exit 0 means the turn completed, not that the task succeeded. The model comes from its settings file, not a flag. | web: https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/bundle/headless/README.md |
| OpenCode | `opencode run "task"` | `--model`, `--format json`, `--file`, `--dir`. Most permissions default to allow, so guard with deny rules in its project config. `opencode serve` is the long-lived form. | web: https://dev.to/gabrielanhaia/headless-mode-in-5-agents-claude-p-codex-exec-gemini-p-copilot-p-opencode-run-4816 |
| Pi | print mode, or `pi --mode rpc --no-session` | RPC mode is JSON lines on stdin and stdout. | web: https://pi.dev/docs/latest/rpc |

Which of them holds the computer-use permissions on the Mac is not confirmed. `M4-01` finds out.

## Meta Wearables Device Access Toolkit

| Topic | Fact | Source |
|---|---|---|
| Current version | 1.1.0, 2026-11-20. 1.0.0 was 2026-09-24. | https://github.com/meta/meta-wearables-dat-ios/blob/main/CHANGELOG.md |
| Needs | Xcode 26.4+, iOS 17.2+, Meta AI app V292, glasses firmware V130 | https://wearables.developer.meta.com/docs/develop/dat/version-dependencies |
| Devices | Ray-Ban Meta Gen 1 and 2, Ray-Ban Meta Optics, Meta glasses, Meta Ray-Ban Display, Oakley Meta HSTN and Vanguard | https://wearables.developer.meta.com/docs/develop/dat/getting-started-toolkit |
| Still photo | In a stream: `stream.capturePhoto(format:)`. Standalone (experimental, 1.0+): `camera.photo`, up to 4032x3024, not at the same time as a stream. | https://wearables.developer.meta.com/docs/develop/dat/camera-capture |
| Audio | Not an SDK API. Bluetooth through `AVAudioSession`. Microphone only on the hands-free profile, mono 8 or 16 kHz; opening it drops stereo playback. Let the route settle before starting the camera. | https://wearables.developer.meta.com/docs/develop/dat/microphones-and-speakers |
| Launch by voice | "Hey Meta, start {app name}" launches or foregrounds the app. Experimental. The name is set in the Developer Center. No custom wake word. | https://wearables.developer.meta.com/docs/develop/dat/voice-invocations; the SDK repository lists "Voice Invocations: launch or activate an app from Hey Meta" among its capabilities (second source, 2026-11-21) |
| Buttons | Capture button short, hold and double press; touch navigation. Experimental. | https://wearables.developer.meta.com/docs/develop/dat/inputs |
| On-glasses speech | Known to stop silently after about a minute. | https://wearables.developer.meta.com/docs/develop/dat/knownissues |
| Known issue | Hands-free audio can connect silent on iPhone 17 with iOS 26; Meta lists iOS 27 as the fix. | same page |
| Known issues that shape the trigger | A double press of the capture button arrives as a short press followed by a double press, so buffer short presses briefly. After a session resumes, experimental capabilities have to be restarted. With wear detection on, inputs stop when the glasses are taken off and put back on until the capability is added again. After the firmware v128 update, camera capture needs a reboot of the glasses. | same page, read 2026-11-21 |
| Docs for agents | Meta hosts a documentation MCP endpoint for the toolkit with a `search_dat_docs` tool, and the SDK repositories describe a read-only live-debugging MCP. Connecting either to an agent is the operator's step. | https://wearables.developer.meta.com/docs/develop/dat/knownissues (the page names the endpoint); https://github.com/meta/meta-wearables-dat-android |
| Mock device | Simulator slices and a test client for UI tests; suitable for CI. | https://wearables.developer.meta.com/docs/develop/dat/testing-mdk-ios |
| Project setup | `MWDAT` keys in Info.plist: `AppLinkURLScheme`, `MetaAppID`, `ClientToken`, `TeamID`. Developer Mode builds may leave `MetaAppID` empty. | https://wearables.developer.meta.com/docs/develop/dat/build-integration-ios |
| Developer Mode | Meta AI app, Settings, App Info, tap the version five times, then the toggle. Per device; reported to turn off after a firmware update. | upstream `README.md` for the steps; web for the firmware note |
| Publishing | App Store not supported; no date. TestFlight internal works with Developer Mode or a release-channel invite per tester. | Meta iOS guide (2026-10-29); https://github.com/meta/meta-wearables-dat-ios/discussions/339 |
| Terms | No protected health information without a signed addendum. Do not hide the capture light. No face or voice identification without approval. Experimental features need written permission for production builds. | https://wearables.developer.meta.com/terms ; https://wearables.developer.meta.com/acceptable-use-policy |

## Apple

| Topic | Fact | Source |
|---|---|---|
| First workflow | Must be created in Xcode. Later edits can be made in App Store Connect. | https://developer.apple.com/documentation/xcode/configuring-your-first-xcode-cloud-workflow |
| Project requirements | Shared scheme with archive, automatic signing, bundle id set, app record | https://developer.apple.com/documentation/xcode/setting-up-your-project-to-use-xcode-cloud |
| Scripts | `ci_scripts/` beside the `.xcodeproj`; executable; no `sudo` | https://developer.apple.com/documentation/xcode/writing-custom-build-scripts |
| Packages | Not resolved automatically. Commit `Package.resolved` under `CameraAccess.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`. | https://developer.apple.com/documentation/xcode/making-dependencies-available-to-xcode-cloud |
| TestFlight | Archive action with "TestFlight (Internal Testing Only)". Builds are added to tester groups by hand. Up to 100 internal testers. | https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers |
| Compute | 25 hours a month included | https://developer.apple.com/xcode-cloud/get-started/ |
| Build status API | Read: `GET /v1/ciProducts`, `/v1/ciWorkflows/{id}/buildRuns`, `/v1/ciBuildRuns/{id}`, `/v1/ciBuildActions/{id}/issues`. Starting a build stays with the operator. | https://developer.apple.com/documentation/appstoreconnectapi/xcode-cloud-workflows-and-builds |
| Background recording | An app cannot start a recording session from the background. | https://developer.apple.com/forums/thread/816408 |

The ignore rule that lets `Package.resolved` be committed while other workspace files stay ignored. It replaces `*.xcworkspace/` in `samples/CameraAccess/.gitignore`:

```
**/*.xcworkspace/*
!**/*.xcworkspace/xcshareddata/
**/*.xcworkspace/xcshareddata/*
!**/*.xcworkspace/xcshareddata/swiftpm/
**/*.xcworkspace/xcshareddata/swiftpm/*
!**/*.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

## Candidate building blocks

Not chosen yet. Each is evaluated in the task named.

| Need | Candidate | Licence | Task |
|---|---|---|---|
| Custom wake phrase | livekit-wakeword (Swift package, ONNX Runtime) | Apache-2.0 | M2-02 |
| Custom wake phrase, no training | sherpa-onnx keyword spotting | Apache-2.0 | M2-02 |
| End of speech | Silero VAD, or the end-of-utterance model in FluidAudio | MIT / Apache-2.0 | M1-04 |
| Transcript on the phone | Apple Speech (SpeechAnalyzer on iOS 26+, SFSpeechRecognizer below) | OS | M1-04 |
| Transcript fallback | WhisperKit; Parakeet through FluidAudio; the DeepSeek platform's speech-to-text API | MIT / Apache-2.0 / vendor | M1-04, only if Apple Speech is not good enough |
| Spoken reply | AVSpeechSynthesizer | OS | M1-05 |
| Read-only browser | Playwright MCP, isolated, origin allowlist; or a headless harness | Apache-2.0 | M3-04, M4-01 |
| Mac app control | the computer-use permissions already granted on the Mac; cua-driver | MIT | M4-02 |
| Ruled out | Picovoice Porcupine: free tier ended 2026-06-30 | commercial | none |

## Identifiers and credentials

Filled in as the operator creates them. Record names only. Values never; locations in the private notes.

| Item | Set by | Task |
|---|---|---|
| Apple team id, bundle id, App Store Connect app record | operator | M0-08 |
| Meta app id and client token | operator | M0-09 |
| Frontier API keys (Anthropic, DeepSeek, OpenAI) and the daily spend cap | operator | M0-05 |
| A scoped model key for the gateway and one for probes; never the router's master key | operator | M0-04, M1-02 |
| Gateway device tokens | operator approves the scheme | M1-03 |

## Upstream files worth reading before writing code

| File in `Intent-Lab/VisionClaw` at `3f39807` | Why |
|---|---|
| `samples/CameraAccess/CameraAccess/OpenClaw/LiveKitSession.swift` lines 330-380 | How to select the glasses microphone without breaking the route |
| `samples/CameraAccess/CameraAccess/ViewModels/StreamSessionViewModel.swift` line 555 | The in-stream still-photo call |
| `samples/CameraAccess/CameraAccess/CameraAccessApp.swift` line 464 | The pairing screen's `GET /apps` token check |
| `samples/CameraAccess/CameraAccess/OpenClaw/CallIntents.swift` | Siri and Action Button intents |
| `samples/CameraAccess/CameraAccess/OpenClaw/Earcons.swift` | Audio cues |
| `samples/CameraAccess/CameraAccess/OpenClaw/NudgeScheduler.swift` | Local notifications on a schedule |
| `gateway/README.md` | The two-speed turn idea: answer fast, deliver late results later |
| `gateway/src/turn.ts` lines 12-26 | The automatic approval this build must not copy |
| `samples/CLAUDE.md` | Upstream's iOS and Android parity rule, which D-11 sets aside |
