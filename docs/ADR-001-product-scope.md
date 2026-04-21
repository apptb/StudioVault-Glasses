# ADR-001: Product Scope Boundary for StudioVault-Glasses

- **Status:** Accepted
- **Date:** 2026-04-21
- **Deciders:** StudioVault-Glasses maintainers
- **Related Docs:** `README.md`, `STUDIOVAULT-GLASSES-ROADMAP.md`

## Context

This repository is a fork of Matcha and is positioned as a DAT SDK-based wearable/mobile runtime that provides:

- real-time voice + vision capture on iOS/Android,
- model/provider adapters (Gemini Live, Azure Realtime), and
- delegation to external agent backends for complex actions.

The root README describes an "agent-native voice-and-vision framework" for connecting devices (phone, earbuds, smart glasses) to a dual-agent runtime, rather than a full product-specific domain application.

The StudioVault roadmap further narrows this fork to implementation of Azure OpenAI Realtime integration and HostBroker/MCP backend routing for StudioVault AI OS integration, while preserving upstream-compatible architecture where possible.

## Decision

**This repository is responsible for device capture/runtime only (Option 1), not end-to-end healthcare application features (Option 2).**

Specifically, this repo owns:

1. Wearable/mobile audio-video capture and streaming runtime.
2. Realtime voice provider integration and switching.
3. Action-agent delegation interfaces and backend client wiring.
4. Device-side UX needed to drive runtime/session behavior.

This repo does **not** own longitudinal healthcare workflows, regulated data-domain business logic, cross-patient orchestration, or enterprise healthcare product surfaces.

## Non-goals (Explicit)

The following are out of scope for `StudioVault-Glasses`:

1. End-to-end EHR/EMR workflows and patient chart system-of-record behavior.
2. Clinical decision support policy engines and care pathway governance.
3. Enterprise healthcare tenancy, RBAC administration, auditing dashboards, and billing/revenue-cycle modules.
4. Full care coordination workflow systems beyond runtime-triggered handoff events.
5. Persistent healthcare document lifecycle management as a standalone product surface.

## Where healthcare modules live

Healthcare application modules that are out-of-scope for this repo will live in the **StudioVault AI OS application repository**, not in `StudioVault-Glasses`.

- **Repository:** `apptb/StudioVault`
- **Expected location/path:** healthcare domain modules under app-layer directories in that repo (for example, clinical workflows, patient timelines, and care coordination services), with this repo integrated only via HostBroker/MCP contracts.

## Rationale

- The README emphasizes device-agnostic, real-time multimodal runtime responsibilities.
- The roadmap defines this fork as a focused provider/runtime integration layer and explicitly avoids expanding into unrelated platform rewrites.
- Keeping this boundary protects maintainability, supports upstream sync with Matcha, and prevents coupling regulated healthcare product concerns into low-level device runtime code.

## Consequences

### Positive

- Clear ownership boundaries between runtime and healthcare product layers.
- Faster iteration on capture/realtime reliability and provider integrations.
- Reduced compliance blast radius in this repository.

### Trade-offs

- Requires stronger interface contracts to external healthcare modules.
- Some feature requests in healthcare UX must be redirected to the StudioVault app repo.

## Review trigger

Revisit this ADR if maintainers intentionally choose to make this repository the primary healthcare application surface.
