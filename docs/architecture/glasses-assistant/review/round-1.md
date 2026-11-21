# Review round 1

Date: 2026-11-21. Reviewed: the first Archify render of the map (17 components and 17 relationships in the target, 9 and 5 as found).

## Gates before review

| Page | validate | deliver | check | browser-check | Advisory |
|---|---|---|---|---|---|
| Target | pass | pass | pass | pass | none |
| As found | pass | pass | pass | pass | one route with 3 bends |
| Comparison | compare pass, 28 of 28 checks | | | | |

Every gate was green. The review still found one blocking defect.

## Reviewers

Three read-only reviewers, none of which wrote the models, each with one lens. They were given captures in dark, light, 2x and phone width, both models, the receipts, the checklist and the operator's reference artifact.

| Lens | Verdict | Blocking | Should | Nit |
|---|---|---|---|---|
| Legibility and layout | pass with fixes | 1 | 7 | 4 |
| Meaning and honesty | fail | 1 | 12 | 5 |
| Conformance to the checklist | fail | 1 | 13 | 3 |

47 findings in all. Many overlap; merged, they are the 30 below. All three reviewers raised the blocking one independently.

## Verification

A separate read-only agent checked three findings against the files (the blocking one and two about label placement) and confirmed all three. Checking one finding per agent was then stopped: it was handling two findings every ten minutes. The implementer checked the remaining findings against the models and the resolved layout, and found none to reject. From round 2 on, one verifier per reviewer checks all of that reviewer's serious findings.

## Findings and what was done

Lens: L legibility, M meaning, C conformance.

### Blocking

| # | Finding | Lens | Done |
|---|---|---|---|
| 1 | Eight planned components looked the same as live ones. The renderer draws the status tag as small text that stays hidden until 175% zoom, and the card pointed at tags no reader could see. | L M C | Every planned component's sublabel now starts with `planned · `. The card names what is not built. Every component has a tag. The title says "Target (planned)". |

### Should

| # | Finding | Lens | Done |
|---|---|---|---|
| 2 | `changed` on the app and the router read as done. Local models had been relabelled as Unsloth Studio, tagged configured and drawn on the main path, while a card said the route did not exist. | M C | The app says `planned · rebase, DAT 0.4 → 1.x`; the router says `local now · frontier planned`. Local models is back to what runs today. Unsloth Studio is its own planned component with a planned route. |
| 3 | One id, `frontier`, meant four vendor clouds as found and three frontier APIs in the target, so the comparison reported a rename and hid that four vendors are dropped. | M C | Separate ids: `vendor_clouds` is removed, `frontier_apis` is added. The removed box sits where the target is empty. |
| 4 | The pink dashed line was used for a hop inside the private network, the main path broke at the phone-to-Mac hop, and only one model route named its phase. | M C L | Pink dashed is now only the two exits. The main path is continuous from the glasses to the router. Each model route names its phase; the frontier route says what leaves. |
| 5 | "HTTPS, read-only" sat against the Mac frame title and the two read as one caption. | L C M | Both exit labels sit in the gap between the two frames. The frame title is shorter and back in its corner. |
| 6 | The harness lane had no line to a model. A harness calling its vendor directly would be a third exit. | M C | A `model calls` line from the harness lane to the router. The plan's D-09 says so, and a card says what happens to a harness that cannot. |
| 7 | Nothing said where speech is recognised. | M | The turn engine says `on-device STT`; a card says the question is transcribed on the phone. |
| 8 | The map did not say which vault, and the old vault repository is retired. | M C | A card says it is the operator's current vault, not the retired repository. The plan's question O-6 asks which one. |
| 9 | "Wake listener" fed by "audio session" read as an always-open microphone. | M | "Wake trigger", `planned · Hey Meta · buttons`, fed by `launch · button`. |
| 10 | The Mac frame said "tailnet only" while two lines left it for the public internet. | M C | The frame is "Mac Studio". A card says the Mac accepts nothing from the public internet. |
| 11 | No card stated the exits; one card item was loose; two proposals were drawn as settled. | M | A card states both exits and what leaves. Another separates what is not built from what the operator has not decided. |
| 12 | No repository pin and no sources for the as-found claims. | M C | The as-found model pins the fork at commit `73c5318` and cites the SDK pin and three vendor endpoints; the tool checked the citations against that commit. Planned components cite nothing. A card names the operator's log as the source for the Mac and the DGX pair. |
| 13 | In the comparison, a label sat on the earlier Mac frame's edge and title, a change marker printed over a label, and a removed label touched a new one. | L C M | Labels moved clear. The removed vendor box and its line moved to the top row. The route to the GLM server is the same in both snapshots, so it is drawn once. |
| 14 | Ray-Ban Meta sat far from the app, reached by the longest and greyest line on the map. | L | Level with the app, one straight emphasised line. |
| 15 | Four line styles carried meaning and nothing explained them. | L C | A card, "Reading the lines". |
| 16 | The picture's description was the tool's default sentence. | C | Both models set a subtitle saying what the map shows and as of when. |
| 17 | GitHub and Xcode Cloud are internet services but sat outside any boundary. | C M | A "Build services (GitHub · Apple)" boundary in the target. |
| 18 | The captures were older than the last gate run, the comparison had no capture after it, and the as-found advisory was not dispositioned. | C | The tester now captures only after every gate passed and records page hashes. The as-found route has one bend and raises no advisory. |

### Not fixable in the model, stated instead

| # | Finding | Lens | Why |
|---|---|---|---|
| 19 | In the light theme the grey relationship labels are pale. | L C | The colour belongs to the preset. No critical fact is carried only on a grey label. |
| 20 | At phone width the map is small and its zoom control is clipped. | L C | The viewer owns the phone layout. The cards read well and carry status, exits and the path; a card says the map needs panning. |
| 21 | In the comparison, change markers print over the status tags, and the tags are about 6.5px. | L C M | Renderer behaviour. Status is now in the sublabel, which the markers do not cover. |
| 22 | The comparison draws an earlier boundary as a second frame with its own title. | L | Renderer behaviour. Titles were shortened so the second title no longer collides with anything. |

### Nits

| # | Finding | Lens | Done |
|---|---|---|---|
| 23 | The router, a local process, wore the cloud type. | M C | Typed `backend` in both models. |
| 24 | "9 local routes" and "vision" were stated as fact. | M | `local routes · per log`; `GLM-5.3 · vision untested`. |
| 25 | The DGX frame and its only box had nearly the same name. | C | The box is "GLM server". |
| 26 | The glasses line read as one-way although the reply is spoken through the glasses. | M C | `DAT · HFP in/out`. |
| 27 | A card titled "Planned, not live" also listed what is live. | C | "What exists, what is planned". |
| 28 | "Switching is a route change" was stated as fact. | M | "meant to be ... a design intent, not yet tested". |
| 29 | A sublabel had 2 units of clearance. | L | Box widths were recomputed from the text. |
| 30 | The canvas is 1420 wide, so it renders at about 0.95 scale. | L | Not changed. The revised map has more on it and is still 1420 wide; relationship labels stay just above the size floor. |

Also changed by the author, not raised by a reviewer: port numbers were taken off two labels, because this repository is public.

## What the review changed in the standard

The conformance reviewer listed nine gaps in the checklist itself. They became revision 2 of the checklist in the `visual-standard` skill: status readable at default zoom, a tense for every tag, one id per thing, review of the comparison view with markers on, captures after the last gate run, advisories dispositioned, a key for line styles, a real description, and gate names that match the tool's.
