# GLASSES-1 resources

What the build draws on, where each thing lives, and how sure we are. Update a row when a probe changes a fact, and log the change. Credential entries are names and locations only.

Checked on 2026-11-20 unless a row says otherwise. "web" rows were read from the vendor's page by one researcher and have not been used yet.

## Repositories

| What | Where | Pin | Notes |
|---|---|---|---|
| This repository | `apptb/StudioVault-Glasses` | `main` at `73c5318` | Matcha-lineage fork. Stays untouched under D-01. |
| App baseline | `Intent-Lab/VisionClaw` | `3f39807` (2026-10-21) | Public. Its `LICENSE` is Meta's developer terms only; no grant for its own code (D-10). |
| Meta's SDK and sample | `meta/meta-wearables-dat-ios` | tag `1.1.0` | `facebook/meta-wearables-dat-ios` still resolves as an alias. Keep one URL in the project and in `Package.resolved`. Pin by version; `main` has no `Package.swift`. |
| Visual standard skill | `apptb/studiovault-universal-skills`, `skills/visual-standard/` | branch `claude/rayban-meta-glasses-assistant-cb0gqs` | The operator's minimum for architecture output. |
| Archify | `tt-a1i/archify` | 3.2.0 | Apache-2.0. Installed on the Mac for the daily worker. Do not install the unrelated npm package named `archify`. |

## Meta Wearables Device Access Toolkit

| Topic | Fact | Source |
|---|---|---|
| Current version | 1.1.0, 2026-11-20. 1.0.0 was 2026-09-24. | https://github.com/meta/meta-wearables-dat-ios/blob/main/CHANGELOG.md |
| Needs | Xcode 26.4+, iOS 17.2+, Meta AI app V292, glasses firmware V130 | https://wearables.developer.meta.com/docs/develop/dat/version-dependencies |
| Devices | Ray-Ban Meta Gen 1 and 2, Ray-Ban Meta Optics, Meta glasses, Meta Ray-Ban Display, Oakley Meta HSTN and Vanguard | https://wearables.developer.meta.com/docs/develop/dat/getting-started-toolkit |
| Still photo | In a stream: `stream.capturePhoto(format:)`. Standalone (experimental): `camera.photo`, up to 4032x3024, not at the same time as a stream. | https://wearables.developer.meta.com/docs/develop/dat/camera-capture |
| Audio | Not an SDK API. Bluetooth through `AVAudioSession`. Microphone only on the hands-free profile, mono 8 or 16 kHz; opening it drops stereo playback. Let the route settle before starting the camera. | https://wearables.developer.meta.com/docs/develop/dat/microphones-and-speakers |
| Launch by voice | "Hey Meta, start {app name}" launches or foregrounds the app. Experimental. The name is set in the Developer Center. No custom wake word. | https://wearables.developer.meta.com/docs/develop/dat/voice-invocations |
| Buttons | `MWDATInputs`: capture button short, hold and double press; touch navigation. Experimental. | https://wearables.developer.meta.com/docs/develop/dat/inputs |
| On-glasses speech | `MWDATSpeech`. Known to stop silently after about a minute. | https://wearables.developer.meta.com/docs/develop/dat/speech |
| Known issues | Hands-free audio can connect silent on iPhone 17 with iOS 26; Meta lists iOS 27 as the fix. | https://wearables.developer.meta.com/docs/develop/dat/knownissues |
| Mock device | `MWDATMockDevice` has simulator slices and a test client for UI tests; suitable for CI. | https://wearables.developer.meta.com/docs/develop/dat/testing-mdk-ios |
| Project setup | `MWDAT` keys in Info.plist: `AppLinkURLScheme`, `MetaAppID`, `ClientToken`, `TeamID`. Developer Mode builds may leave `MetaAppID` empty. | https://wearables.developer.meta.com/docs/develop/dat/build-integration-ios |
| Testers | One private release channel per integration, invites by Meta account email. | https://wearables.developer.meta.com/docs/develop/dat/set-up-release-channels |
| Publishing | App Store not supported; no date. TestFlight internal works with Developer Mode or a release-channel invite per tester. | Meta iOS guide (2026-10-29); https://github.com/meta/meta-wearables-dat-ios/discussions/339 |
| Terms | No protected health information without a signed addendum. Do not hide the capture light. No face or voice identification without approval. Experimental features need written permission for production builds. | https://wearables.developer.meta.com/terms ; https://wearables.developer.meta.com/acceptable-use-policy |
| Developer Mode | Meta AI app, Settings, App Info, tap the version five times, then the toggle. Turns off after a firmware update. | upstream `README.md` |

## Apple

| Topic | Fact | Source |
|---|---|---|
| First workflow | Must be created in Xcode. Later edits can be made in App Store Connect. | https://developer.apple.com/documentation/xcode/configuring-your-first-xcode-cloud-workflow |
| Project requirements | Shared scheme with archive, automatic signing, bundle id set, app record | https://developer.apple.com/documentation/xcode/setting-up-your-project-to-use-xcode-cloud |
| Scripts | `ci_scripts/` beside the `.xcodeproj`; `ci_post_clone.sh`, `ci_pre_xcodebuild.sh`, `ci_post_xcodebuild.sh`; executable; no `sudo` | https://developer.apple.com/documentation/xcode/writing-custom-build-scripts |
| Packages | Not resolved automatically. Commit `Package.resolved` under `CameraAccess.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`. | https://developer.apple.com/documentation/xcode/making-dependencies-available-to-xcode-cloud |
| Secrets in CI | Workflow environment variables marked Secret are redacted in logs. This build uses none. | https://developer.apple.com/documentation/xcode/xcode-cloud-workflow-reference |
| TestFlight | Archive action with "TestFlight (Internal Testing Only)". Xcode Cloud builds are added to tester groups by hand. Up to 100 internal testers. | https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers |
| Compute | 25 hours a month included | https://developer.apple.com/xcode-cloud/get-started/ |
| Build status API | Read: `GET /v1/ciProducts`, `/v1/ciWorkflows/{id}/buildRuns`, `/v1/ciBuildRuns/{id}`, `/v1/ciBuildActions/{id}/issues`. Starting a build (`POST /v1/ciBuildRuns`) stays with the operator. | https://developer.apple.com/documentation/appstoreconnectapi/xcode-cloud-workflows-and-builds |
| Background recording | An app cannot start a recording session from the background. | https://developer.apple.com/forums/thread/816408 |
| Reminders | EventKit, one full-access grant on iOS 17+ | https://developer.apple.com/documentation/eventkit |

The ignore rule that lets `Package.resolved` be committed while other workspace files stay ignored. It replaces `*.xcworkspace/` in `samples/CameraAccess/.gitignore`:

```
**/*.xcworkspace/*
!**/*.xcworkspace/xcshareddata/
**/*.xcworkspace/xcshareddata/*
!**/*.xcworkspace/xcshareddata/swiftpm/
**/*.xcworkspace/xcshareddata/swiftpm/*
!**/*.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

## The local fabric

From the operator's execution log, 2026-11-17 to 11-19. Not probed. `M0-04` confirms or corrects each row.

| What | Where | Notes |
|---|---|---|
| LiteLLM | `127.0.0.1:4000` on the Mac Studio, launch agent `com.studio.litellm`, config `/Users/m3u/studio/services/litellm/config.yaml` | Start it with exported environment. Master key in `/Users/m3u/studio/etc/litellm.env`. |
| Fast vision route | `local.mac-fast`: Qwen3.6-35B on rapid-mlx `:8090` | About 168 tokens a second. Vision and tools reported on the backend. |
| Large-context vision route | `local.glm-chat`: GLM-5.3-Flash on the DGX pair `:8888` | 1M-token window. Tool-call decoding 24 tokens a second. The DGX port has no key. |
| Other routes | `local.glm`, `local.intent`, `local.long`, `local.glm-lm`, `local.mac-quality`, `local.ds41`, `local.ds41-rs` | `mac-quality` and `ds41` change with the Mac's model slot. `ds41` needs more than 8 output tokens. |
| Fallbacks | `mac-fast` and `glm-chat` fall back to each other; `glm-lm` has none | Message-level replay only |
| Traces | Jaeger OTLP `127.0.0.1:4318`; Prometheus `:9090`; Grafana `:3000` | No agent span has arrived yet |
| Tailnet | Mac host `m3us-mac-studio.tail5f13a2.ts.net`. Serve maps 443 to the password vault only. | The log's last entry reports Tailscale offline; check |
| Daily worker | `daily_synth.py`, 07:00 scheduled turn, 07:30 launchd fallback | Writes `Daily-YYYYMMDD.md`, audio and the infra delta into `/Users/m3u/Documents/Obsidian/StudioVault` |
| Text to speech | Piper 1.8.0, voice `en_US-lessac-medium` | Used by the worker |
| Speech to text | none on this install | The earlier `brain` install recorded one; it is not live |
| Computer use | A separate signed computer-use binary holds Accessibility and Screen Recording grants | Belongs to the Mac's agent harness. Using it from the gateway is an operator decision (M4-02). |
| Xcode | Licence accepted, first launch run | Version unknown; needs 26.4+ |

## Candidate building blocks

Not chosen yet. Each is evaluated in the task named.

| Need | Candidate | Licence | Task |
|---|---|---|---|
| Custom wake phrase | livekit-wakeword (Swift package, ONNX Runtime) | Apache-2.0 | M2-02 |
| Custom wake phrase, no training | sherpa-onnx keyword spotting | Apache-2.0 | M2-02 |
| End of speech | Silero VAD, or the end-of-utterance model in FluidAudio | MIT / Apache-2.0 | M1-04 |
| Transcript on the phone | Apple Speech (SpeechAnalyzer on iOS 26+, SFSpeechRecognizer below) | OS | M1-04 |
| Transcript fallback | WhisperKit; Parakeet through FluidAudio | MIT / Apache-2.0 | M1-04, only if Apple Speech is not good enough |
| Spoken reply | AVSpeechSynthesizer | OS | M1-05 |
| Read-only browser | Playwright MCP, isolated, origin allowlist | Apache-2.0 | M3-04 |
| Acting browser | browser-use with a local model; its domain list is a guide, not a sandbox | MIT | M4-01 |
| Mac app control | cua-driver; or the Mac's existing computer-use binary | MIT | M4-02 |
| Ruled out | Picovoice Porcupine: free tier ended 2026-06-30 | commercial | none |

Sources for this table: https://github.com/livekit/livekit-wakeword , https://k2-fsa.github.io/sherpa/onnx/kws/index.html , https://github.com/FluidInference/FluidAudio , https://github.com/argmaxinc/WhisperKit , https://github.com/microsoft/playwright-mcp , https://github.com/browser-use/browser-use , https://github.com/trycua/cua .

## Identifiers and credentials

Filled in as the operator creates them. Record the name and where it lives. Never the value.

| Item | Name or location | Set by | Task |
|---|---|---|---|
| Apple team id | to be recorded | operator | M0-07 |
| Bundle id | to be chosen | operator | M0-07 |
| App Store Connect app record | to be created | operator | M0-07 |
| Meta app id and client token | Wearables Developer Center | operator | M0-08 |
| Gateway device tokens | proposed: Keychain on the Mac under `sv/glasses/DEVICE_TOKEN_<device>`; Keychain on the phone | operator approves the scheme | M1-03 |
| LiteLLM key for the gateway | a scoped key, not the master key; location to be chosen | operator | M1-02 |

## Upstream files worth reading before writing code

| File in `Intent-Lab/VisionClaw` | Why |
|---|---|
| `samples/CameraAccess/CameraAccess/OpenClaw/LiveKitSession.swift` lines 330-400 | How to select the glasses microphone without breaking the route |
| `samples/CameraAccess/CameraAccess/ViewModels/StreamSessionViewModel.swift` around line 555 | The still-photo call |
| `samples/CameraAccess/CameraAccess/OpenClaw/CallIntents.swift` | Siri and Action Button intents |
| `samples/CameraAccess/CameraAccess/OpenClaw/Earcons.swift` | Audio cues |
| `samples/CameraAccess/CameraAccess/OpenClaw/NudgeScheduler.swift` | Local notifications on a schedule |
| `gateway/README.md` | The pairing and two-speed turn protocol the app already speaks |
| `gateway/src/turn.ts` lines 12-26 | The automatic approval this build must not copy |
| `samples/CLAUDE.md` | Upstream's iOS and Android parity rule, which D-09 sets aside |
