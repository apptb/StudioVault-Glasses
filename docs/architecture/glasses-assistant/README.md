# Glasses assistant architecture map

Two authored models and one preview page. The models are the source; the page is drawn from them.

| File | What it is |
|---|---|
| `base.json` | The system as found on 2026-11-20: the Matcha-lineage fork calling vendor clouds, and the local fabric it never reaches. |
| `head.json` | The target: wake phrase and photo turn on the phone, a gateway on the Mac Studio, local models, a task lane, and the evidence trail into the vault. |
| `glasses-assistant.preview.html` | A hand-authored Before / Delta / After page drawn from the two models. Opens offline. |

Both models are Archify `architecture` IR, schema version 1, `signal-flow` preset, `showcase` profile. Component and relationship ids are stable; keep them stable so the delta stays meaningful.

## The preview is not the deliverable

The operator's standard is an Archify-finalized artifact with a receipt (see the `visual-standard` skill in `apptb/studiovault-universal-skills`). The Archify command could not be run in the session that authored these models, so the preview has had no validate, deliver, check or browser-check gate. It was looked at once in a headless browser in dark and light.

Render the real artifact on a machine where Archify is installed. On the Mac Studio that is the copy the daily synthesis worker already uses. Replace `<archify>` with the installed package path.

```bash
# from the repository root

# 1. the target on its own, with all four gates
node <archify>/bin/archify.mjs finalize architecture \
  docs/architecture/glasses-assistant/head.json \
  docs/architecture/glasses-assistant/glasses-assistant.html \
  --quality showcase --json

# 2. the Before / Delta / After comparison and its receipt
node <archify>/bin/archify.mjs compare architecture \
  docs/architecture/glasses-assistant/base.json \
  docs/architecture/glasses-assistant/head.json \
  docs/architecture/glasses-assistant/glasses-assistant.delta.html \
  --receipt docs/architecture/glasses-assistant/glasses-assistant.delta.receipt.json \
  --quality showcase --json
```

A non-zero exit is not success. Read the receipt, repair the model (positions and sizes first; never drop a component or a label to pass a gate), and run the same command again. Positions in these files were placed by hand for the preview's simple router; Archify routes for itself and may ask for more room between labelled neighbours.

When the finalized pair exists, commit it beside the models, delete `glasses-assistant.preview.html`, and log the change in the program ledger.

## Updating the map as the build moves

1. Copy `head.json` over `base.json`.
2. Edit `head.json`: flip a component's `tag` from `planned` to `new` when it runs, `configured` when it is set up but unproven, `blocked` when a gate holds it. Add or remove relationships as they become real.
3. Run the two commands above.
4. Append one ledger line naming what changed and the receipt path.

Do this at the end of each milestone, not for every commit.

## Reading the target

- **One turn.** The phone hears the wake phrase, takes one photo from the glasses and one spoken question, and sends image plus transcript to the gateway on the Mac. The answer returns on the same request and is spoken.
- **Two trust crossings.** Phone to Mac over the tailnet, authenticated by a per-device token. Browser agent to the public web, read-only by default. Nothing else leaves the tailnet.
- **Evidence.** The gateway writes a turn log and traces. The daily synthesis worker already runs on the Mac and already writes the daily brief into the vault; it gains one input.
- **Planned means planned.** Every component tagged `planned` is on paper. LiteLLM, the Mac and DGX model servers, the daily worker and the vault are live according to the operator's execution log of 2026-11-17 to 11-19; nothing was probed from this session.
