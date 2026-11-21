# Glasses assistant architecture map

Two authored models, the pages Archify rendered from them, and the record of the review they went through.

![Target architecture](review/target.png)

| File | What it is |
|---|---|
| `base.json` | The system as found: an older fork of the app calling four vendor clouds from the phone, and models on the Mac and the DGX pair that it never reaches |
| `head.json` | The target: a trigger and photo turn on the phone, a gateway on the Mac, frontier APIs first and local models second, a harness lane for Mac-side tasks, and the evidence trail into the vault |
| `glasses-assistant.html` | The target, rendered by Archify 3.2 with all four gates passing |
| `glasses-assistant.base.html` | The as-found system, rendered the same way |
| `glasses-assistant.delta.html` | Before, Delta and After in one page, with the exact authored changes |
| `*.finalize-summary.json`, `*.finalize.json`, `*.browser-check.json`, `*.delivery.json` | Gate receipts for the two rendered models |
| `glasses-assistant.delta.receipt.json` | The comparison's receipt: what was compared, by semantic hash, and the change counts |
| `review/` | The review record, round by round; two captures; the hashes of the pages the reviewers saw |

Open the HTML files in a browser. They work offline. GitHub shows their source, not the page, so download them or open them from a checkout.

Both models are Archify `architecture` IR, schema version 1, `signal-flow` preset, `showcase` profile. Component and relationship ids are stable; keep them stable so the delta stays meaningful, and give a different thing a different id.

## Reading the target

- **One turn.** A trigger starts it. The phone takes one photo from the glasses and one spoken question, transcribes the question itself, and sends image plus transcript to the gateway on the Mac. The answer returns on the same request and is spoken. The thick teal line is that path.
- **Two exits from the private network.** The router's calls to the frontier APIs in phase 1, carrying the photo and the question, and the harness lane's read-only web requests. Both leave from the Mac and both are the pink dashed lines. The phone talks to the gateway only.
- **Frontier first, then local.** Switching a turn from a frontier API to a local model is meant to be a route change in LiteLLM. That is a design intent; `M0-04` and `M0-06` test it.
- **Evidence.** The gateway writes a turn log and traces. The daily synthesis worker already writes the daily brief into the vault; it gains one input.
- **Planned means planned.** A sublabel that starts with `planned` marks something not built or not wired. Tag `configured` marks something that exists according to the operator's log or word and was not probed. Tag `live` marks what the author read or saw. Nothing on the Mac or the DGX pair was probed.

## How these were produced

1. The models were written by hand from the plan.
2. Archify's `finalize` ran on each model: validate, deliver, check, browser check. A failed gate was repaired in the model (positions, label placement) and the full command run again. No component, relationship or label was dropped to pass a gate. The as-found model cites source lines in this repository at commit `73c5318`, and the tool checked them.
3. Archify's `compare` produced the delta page and its receipt.
4. Three read-only reviewers looked at captures in dark, light, 2x and phone width through three lenses: legibility, meaning, conformance to the checklist. A separate pass checked serious findings against the files before they were acted on. Confirmed findings were fixed in the models and steps 2 and 3 run again. `review/round-1.md` and `review/round-2.md` say what was found and what was done.

The first render passed every gate and still drew eight planned components as if they were live. The review caught it. That is why the standard this map follows counts a review as part of delivery.

The renders were made in a scratch working directory and copied here, so paths inside the receipts point at that directory. The hashes in the receipts and in `review/pages.sha256.json` identify the models and pages regardless of path. Re-rendering on your own machine rewrites the receipts with local paths.

## Known limits

These belong to the renderer, not the models:

- In the comparison view, change markers (`+`, `~`) print over the small status tags, and a boundary whose members changed is drawn twice, once as the earlier frame with its own title.
- The comparison page has no light theme and no browser gate of its own.
- In the light theme the grey relationship labels are pale.
- On a phone the cards read well and the map needs panning.

## Re-rendering

With the `visual-standard` skill installed, from the repository root:

```bash
ARCHIFY_DIR=<archify> sh <visual-standard>/scripts/render.sh docs/architecture/glasses-assistant --captures
```

Or by hand. Replace `<archify>` with the installed Archify skill directory.

```bash
node <archify>/bin/archify.mjs finalize architecture \
  docs/architecture/glasses-assistant/head.json \
  docs/architecture/glasses-assistant/glasses-assistant.html \
  --quality showcase --json

node <archify>/bin/archify.mjs finalize architecture \
  docs/architecture/glasses-assistant/base.json \
  docs/architecture/glasses-assistant/glasses-assistant.base.html \
  --quality showcase --json --repo-root .

node <archify>/bin/archify.mjs compare architecture \
  docs/architecture/glasses-assistant/base.json \
  docs/architecture/glasses-assistant/head.json \
  docs/architecture/glasses-assistant/glasses-assistant.delta.html \
  --receipt docs/architecture/glasses-assistant/glasses-assistant.delta.receipt.json \
  --quality showcase --json --repo-root .
```

A non-zero exit is not success. Read the diagnostics, repair the model, and run the same command again. Archify refuses to overwrite the browser receipt of an earlier render, so remove the previous page and its receipts first; the script does that for you.

`--repo-root` is needed because the as-found model cites this repository at commit `73c5318`, which must be present in the checkout.

## Updating the map as the build moves

1. Copy `head.json` over `base.json`, and remove `meta.repository` and `sources` from the new `base.json` unless they still describe it.
2. Edit `head.json`. When something is built, drop `planned · ` from its sublabel and change its tag: `live` when you saw it work, `configured` when it is set up and unproven, `blocked` when a gate holds it. Add or remove relationships as they become real.
3. Render, look at the captures, and run a review round if anything moved.
4. Append one ledger line naming what changed and the receipt path.

Do this at the end of each milestone, not for every commit.
