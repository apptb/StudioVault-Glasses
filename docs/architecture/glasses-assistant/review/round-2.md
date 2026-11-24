# Review round 2

Date: 2026-11-21. Reviewed: the models as rewritten after round 1, captured after the last gate run.

## Gates before review

| Page | validate | deliver | check | browser-check | Advisory |
|---|---|---|---|---|---|
| Target | pass | pass | pass | pass | none |
| As found | pass | pass | pass | pass | none |
| Comparison | compare pass, 28 of 28 checks | | | | |

`visual-check` also ran, to make captures: pass on the target, fail on the comparison (see the limits below), not run on the as-found page in this round.

## Reviewers

The same three lenses, new reviewers. Each was told what round 1 found and asked to judge the files as they were.

| Lens | Verdict | Blocking | Should | Nit |
|---|---|---|---|---|
| Legibility and layout | pass with fixes | 0 | 3 | 3 |
| Meaning and honesty | pass with fixes | 0 | 6 | 6 |
| Conformance to the checklist | pass with fixes | 0 | 7 | 6 |

31 findings, none blocking. All three confirmed that the round-1 blocker is fixed: status reads in the drawing at default zoom in both themes. Two reviewers judged the target cleaner than the reference artifact on routing, status and the change list, and weaker in one place: the comparison view is busier and drawn smaller.

## Verification

One read-only verifier per reviewer checked that reviewer's should findings against the files: 16 findings checked, 16 confirmed. In six cases the verifier replaced the reviewer's fix with a better one. Three of those mattered:

- A proposed fix would have failed validation (adding two sources to a component that already had the maximum of three).
- "tokens" on a map about AI reads as model tokens; the label says "access tokens".
- A proposed card sentence, "the gateway listens on the tailnet only", claimed more than the plan does. The plan publishes it on the tailnet; it says nothing about the bind address.

## Findings and what was done

Lens: L legibility, M meaning, C conformance. Findings raised by more than one reviewer are merged.

### Should

| # | Finding | Lens | Done |
|---|---|---|---|
| 1 | The comparison drew the route to the GLM server twice, 7 units apart, with both labels, so an unchanged route looked rerouted. Only the target model carried a label offset on it. | L M C | The same offset is in both models. The comparison draws one line. |
| 2 | The as-found exit understated what leaves the phone. At the pinned commit the app's code also posts the Google and Notion access tokens of linked accounts to the vendor sandbox with each task. | M | Confirmed in source. The line says `voice, video, tasks, access tokens`; the app cites the request; a card says it was read in code and not observed running; the plan's findings table records it. |
| 3 | The as-found card said "no path from the phone to the Mac". The fork carries an OpenClaw backend aimed at a gateway on a Mac on the local network, and a stub backend. | C | The card now says no path to the model router, and names both backends, with "whether OpenClaw was ever configured is not known". |
| 4 | The web exit said "HTTPS, read-only", which names how it leaves and not what leaves. | M C | `HTTPS · queries, no writes`. |
| 5 | The card's statement of what leaves the network was written as complete. It left out a harness's own prompts and what the platforms do on their own. | M C | "This design makes two kinds of call…", naming what goes in each, and a new item listing what is not drawn, ending "None of this was checked". The frontier line says `photo + prompts`. |
| 6 | "The Mac accepts nothing from the public internet" was a flat claim about a machine nobody probed. | M | "By design the gateway is published on the tailnet only… what else the Mac exposes was not probed." |
| 7 | Unsloth Studio is installed today but was missing from the as-found map, so the comparison showed it as newly added. Which machine it runs on is not recorded. | M | It is in both models and outside every machine frame: `installed · host unknown` as found, `host unknown · route planned` in the target. The right column was re-laid so it has a place; the route to the GLM server now takes three bends to stay out of the Public internet frame, and the tool's advisory for that is accepted. |
| 8 | "HTTPS over tailnet" had under 2 units to the frame on each side. The tool's clearance check does not measure frames. | L C | `HTTPS · tailnet`, 9 units each side. |
| 9 | The as-found page had no key for its line styles. | L C | A "Reading the lines" card there too, worded for what that map shows. |
| 10 | The comparison opened with a "repository provenance changed" banner, because only the as-found model pinned a commit. | M C | The target pins the same commit; the app, which exists today, keeps its citation. The banner is gone. |
| 11 | A failed `visual-check` record for the comparison sat beside the pages while the hand-off said "no browser gate of its own". | C | The readme names the command, its result and why it fails there. The tester prints the result with counts and now runs it on the as-found page too. The comparison's "light" captures are not kept. |
| 12 | The comparison drawing is at about 0.8 scale in a 900px-high window, which puts relationship labels near 6.5px. | L C | Stated as a limit. Removing 107 units of height would be needed to change it. |

### Nits

| # | Finding | Lens | Done |
|---|---|---|---|
| 13 | Xcode Cloud read as decided. | M | `planned · proposed · sign`. |
| 14 | The router exists and gains a planned part; the checklist had no rule for that. | M C | The checklist now lets such a component keep its tag and say both states. The app follows the same rule: `DAT 0.4 now · 1.x rebase planned`. |
| 15 | "phase 2 · new route" named a status, not a route. | C | `phase 2 · unsloth`. |
| 16 | The teal path stops at the router and no card said the turn continues. | M C | The line key says where it continues in each phase. |
| 17 | "push" read as GitHub pushing to Apple; "tiers" was unexplained. | M C | `on push · build`; a card item says what the tiers are. |
| 18 | Card wording: tense, a wrapped title, "pink" where the light theme draws red, "needs panning". | L M | Reworded. |
| 19 | The as-found card defined `configured` only as "per the log". | M | It gives both meanings: per the log for the Mac and DGX; read in source for the app. |

### Not changed, with the reason

| Finding | Lens | Why |
|---|---|---|
| "phase 2 · local" has 4 units to each box. | L | The reviewer called it acceptable. Shortening it breaks the pattern of the other phase labels; widening the gap pushes labels under the size floor. |
| The canvas is 1420 units wide. | L | The map carries more than the reference. Relationship labels stay just above the floor on the target page. |
| Ray-Ban Meta is in no boundary. | M C | A frame around one box has no room beside the label on its line. Both reviewers who raised it said leaving it is acceptable. |

## What the review changed in the standard

The conformance reviewer found nine faults in revision 2 of the checklist: two lines that contradicted each other (the emphasised path and the exit rule), one that named the wrong cause for a doubled line, and missing lines for the snapshot kind in the title, the name of the private network, platform services, and components whose host is unknown. They are revision 3.
