# StudioVault-Glasses Roadmap

> Fork of [Intent-Lab/Matcha](https://github.com/Intent-Lab/Matcha) adapted for Konstantin's StudioVault AI OS.
> This doc exists so any Claude/Codex/human session dropping into this repo understands the direction.

---

## Why this fork

Matcha is an excellent DAT SDK base with:
- `VoiceModelProvider` protocol (model-agnostic voice seam)
- Dual-agent framework (Voice Agent + Action Agent + Coordinator)
- WebRTC + SignalingClient already adapted for Meta Ray-Ban glasses POV
- OpenClaw + E2B agent backends with a switcher
- iOS + Android feature parity

Matcha's roadmap had "OpenAI Realtime provider" as an unchecked item. StudioVault-Glasses is that implementation — but routed through Azure OpenAI (Konstantin's enterprise tenant) and integrated with the broader StudioVault AI OS substrate.

---

## Upstream sync

- **Upstream**: `Intent-Lab/Matcha` on main
- **This fork**: `apptb/StudioVault-Glasses`
- Maintain a `vendor/matcha` branch that tracks upstream main; rebase/merge periodically
- **Matcha-incompatible changes** live on main (our work)
- **Upstream-compatible bug fixes** should be contributed back to Matcha via PR

---

## Net additions vs Matcha

### Done in initial scaffolding (commit 0)
- `samples/CameraAccess/CameraAccess/Azure/AzureRealtimeConfig.swift` — endpoint + auth + audio format config
- `samples/CameraAccess/CameraAccess/Azure/AzureRealtimeService.swift` — WebSocket service skeleton with session.update + event handlers for the high-value Realtime events
- `samples/CameraAccess/CameraAccess/Core/Models/AzureRealtimeProvider.swift` — VoiceModelProvider adapter mirroring GeminiLiveProvider exactly

### Coming in Phase 1 (Weeks 1–2)
- SettingsManager extension: `azureRealtimeBase`, `azureRealtimeDeployment`, `azureRealtimeSystemPrompt`, `azureOpenAIAPIKey` keys
- `Secrets.swift.example` additions for Azure credentials
- Xcode project file references (the .swift files need to be added to the CameraAccess target)
- Backend switcher UI update: add "Azure Realtime" as selectable voice provider
- Complete `AzureRealtimeService.sendSessionUpdate()` tools array — port `ToolDeclarations.allDeclarations()` into Azure's tools format
- Wire up `capture_photo` and `execute` tools through the new provider end-to-end
- First-flight test: iPhone in simulator → Mac Studio → Azure Realtime endpoint → speech round trip

### Coming in Phase 2 (Weeks 3–4)
- `HostBrokerClient.swift` — client for Mac Studio HostBroker service (scope-tokened transport plane)
- `StudioVaultMCPBackend.swift` — new AgentBackend conforming implementation that routes tool calls to StudioVault's MCP servers via HostBroker (replaces E2B sandbox as default for vault operations)
- Capability-scoped token handshake (QR pair or Device Flow) per ChatGPT PKM Project cross-review
- Tailscale + LM Link transport detection logic
- `CameraAccess/CameraAccess/Vault/VaultContextCapture.swift` — pre-meeting context capture (image + voice description → pre-meeting context note via MCP)
- `CameraAccess/CameraAccess/Granola/GranolaBridge.swift` — bridge to notify Granola on Mac Studio when pre-meeting context is ready

### Coming in Phase 3 (Weeks 4–6)
- Parallel Research Agent substrate (see `_inbox/DESIGN__2026-04-17__StudioVault__Parallel-Research-Agent-Pattern.md` in StudioVault)
  - `Core/Research/ResearchCoordinator.swift`
  - `Core/Research/SynthesisFormatPicker.swift`
  - `Core/Research/InterimFindingSurfacer.swift`
- Extension to `AgentProtocol`: `ResearchTask`, `ResearchProgress`, `ResearchSteering`, `SynthesisTask`
- New HostBroker endpoints: `/research/start`, `/research/steer`, `/research/stream`, `/research/synthesize`

### Coming in Phase 4 (Weeks 6–8)
- NotebookLM-parity output generators (brief first, then deck, podcast, infographic, FAQ, mindmap, interactive)
- First synthesis test: complete a research session + produce a brief artifact in the vault

---

## What we're intentionally NOT doing

- **Not porting GlassFlow's DeepgramService.swift** — Granola Pipeline A (existing, gold-standard per Konstantin's 2026-02-25 vault assessment) is the meeting-transcription spine. iOS/glasses augments Granola with pre-meeting visual context + live-research-during-meeting + post-meeting synthesis. Re-evaluate in Phase 5 if gaps emerge.
- **Not lifting WebRTC from VisionClaw** — Matcha already has WebRTC + SignalingClient adapted for DAT SDK. VisionClaw lift would be duplicate work.
- **Not replacing Gemini Live** — keep it as a selectable backend for non-sensitive contexts + as a regression baseline. Azure Realtime is primary; Gemini is an alternative.
- **Not re-using E2B sandbox as default** — the StudioVaultMCPBackend is the default execution lane for vault-integrated work. E2B stays available for sandboxed code execution tasks.

---

## Configuration state

### Azure OpenAI Realtime endpoint (deployed 2026-04-17)

```
Resource:      dev-vault.openai.azure.com
Deployment:    gpt-realtime-1-5
Model:         gpt-realtime v2025-08-28 (effective)
Planned model: v2026-02-23 (subscription-gated; retry periodically)
SKU:           GlobalStandard, 5 units capacity
Rate limits:   100 req/min, 50000 tok/min
API version:   2025-04-01-preview
WebSocket URL: wss://dev-vault.openai.azure.com/openai/realtime?deployment=gpt-realtime-1-5&api-version=2025-04-01-preview
Auth:          api-key header
```

Provenance: `_system/logs/CONFIG__2026-04-17__Azure__GPT-Realtime-Deployed__id1776413907.md` in StudioVault repo.
Routing: `voice_realtime_audio` route in `.claude/evals/lmstudio/model_routing.json` v1.2.0.

### Required before running

1. Copy `samples/CameraAccess/CameraAccess/Secrets.swift.example` → `Secrets.swift`
2. Add Azure credentials:
   ```swift
   static let azureOpenAIAPIKey = "..." // from Azure Portal or `az cognitiveservices account keys list`
   static let azureRealtimeBase = "dev-vault.openai.azure.com"
   static let azureRealtimeDeployment = "gpt-realtime-1-5"
   ```
3. Add new files to Xcode project:
   - `Azure/AzureRealtimeConfig.swift`
   - `Azure/AzureRealtimeService.swift`
   - `Core/Models/AzureRealtimeProvider.swift`
4. Extend `SettingsManager` with the new keys (see code comments in `AzureRealtimeConfig.swift`)

---

## Architectural invariants (inherited from StudioVault)

- **Capability preservation > refusal rate** — see `.claude/rules/capability-preservation.md` in StudioVault. Voice/vision backend selection respects user's per-session routing choice.
- **Append-only content model** — vault writes from this app must respect StudioVault's append-only convention. No retroactive edits to immutable sections.
- **Write scope compliance** — writes land in `00_Inbox/`, `_system/logs/`, or domain-appropriate scopes. Never arbitrary paths.
- **Structural evaluators enforced** — the 5 custom evaluators (`filename_convention`, `required_frontmatter`, `append_only_compliance`, `write_scope_compliance`, `canary_exfil_detection`) apply to all vault artifacts this app produces.
- **Host-scoped permissions** — HostBroker issues capability-scoped tokens per the ChatGPT PKM Project cross-review pattern. iOS never holds raw provider keys.

---

## Related StudioVault documents

- `_inbox/NOTE__2026-04-17__StudioVault__Glasses-Plan-Rationalization-v2.md` — v2 plan, transport plane, model routing, workflow revisions
- `_inbox/DESIGN__2026-04-17__StudioVault__Parallel-Research-Agent-Pattern.md` — substrate design for Workflows A/B/C
- `_system/handoffs/HANDOFF__2026-04-17__Evaluation__Multimodal-Model-Bakeoff.md` — 10-model × 5-dimension bakeoff (Qwen 3.6, Unsloth Gemma 4 family, etc.)
- `_system/logs/CONFIG__2026-04-17__Azure__GPT-Realtime-Deployed__id1776413907.md` — realtime endpoint provenance
- `_inbox/Multimodal WearableMobile AI Interface – Initial Research & Analysis -ChatGPT pkm project.md` — ChatGPT PKM Project cross-review

---

## Changelog

- 2026-04-17: Initial fork + scaffolding. AzureRealtimeConfig / AzureRealtimeService (skeleton) / AzureRealtimeProvider committed. Roadmap documented.
