# Review round 3

Date: 2026-11-21. The last round the loop allows. Reviewed: the models as changed after round 2.

## Gates before review

| Page | validate | deliver | check | browser-check | visual-check | Advisory |
|---|---|---|---|---|---|---|
| Target | pass | pass | pass | pass | pass | one route with 3 bends, accepted |
| As found | pass | pass | pass | pass | pass | none |
| Comparison | compare pass, 28 of 28 checks | | | | fail, by design | |

The advisory is the route from the router to the GLM server, which takes three bends to stay out of the Public internet frame. `visual-check` fails on the comparison page because that page has no light theme and scrolls vertically (4 `viewer/theme-state`, 6 `viewer/viewport-overflow`).

## Reviewers

The same three lenses, new reviewers, told what round 2 found and what the author had decided.

| Lens | Verdict | Blocking | Should | Nit | In the reviewer's words |
|---|---|---|---|---|---|
| Legibility and layout | pass with fixes | 0 | 1 | 0 | "Ready to deliver: yes" |
| Meaning and honesty | pass with fixes | 0 | 4 | 3 | "Ready to deliver once the four should-level text edits are made… none moves a box or a line" |
| Conformance to the checklist | pass with fixes | 0 | 1 | 6 | "The target map is ready to deliver as drawn" |

15 findings, none blocking. Every round-2 finding was confirmed fixed, closed as a stated limit, or left by a decision the reviewers accepted.

## Verification

One verifier per reviewer: 6 should findings checked, 6 confirmed. Twice the verifier corrected the reviewer's wording: "the pink line" is red in the light theme, and "stay configured" would have collided with a status word the map uses.

## Findings and what was done

Lens: L legibility, M meaning, C conformance.

### Should

| # | Finding | Lens | Done |
|---|---|---|---|
| 1 | In the Delta tab the label "HTTPS · queries, no writes" sat under the elbow of the removed line from the old app to the vendor clouds, nearer to that line than to its own. A reader could take it as describing what the old app sent. Introduced by moving the label in round 2. | L | Moved 14 units down. It now sits midway between the removed line and the Mac frame. |
| 2 | "on push · build" said a push starts the build. The plan says the build is started by hand and that starting it is the operator's step. Introduced by a round-2 fix. | M | `manual start · build`. The gates card now lists starting a build and adding it to a tester group. |
| 3 | The GitHub box named the public fork as the repository the app is built from. The plan leaves that open (question O-9) and defaults to a private repository. | M | `fork now · repo undecided`, and a card item that names the fork and the open question. |
| 4 | The daily worker gains the turn log as an input, and that change is operator-gated, but the map drew the worker as untouched. | M | `brief now · log input planned`. Both cards that list planned changes and operator gates include it. |
| 5 | Phase 2 read as a cutover. The plan makes it conditional and reversible: a route moves only when it matches the frontier baseline, and the frontier routes are kept. | M | The card says so, and the statement of exits says the photo still goes out "afterwards on any route not yet moved". |
| 6 | The as-found page said "leaves the private network" without saying what that network is, and listed no platform services. Revision 3 of the checklist asks for both. | C | Two card items on that page, worded so as not to imply the phone is already linked to the Mac. |

### Nits

| # | Finding | Lens | Done |
|---|---|---|---|
| 7 | The count of exits did not cover how the daily worker makes its brief and audio, or the build path through GitHub and Apple. | M | One sentence added for each, saying what was not checked and what the build path carries. |
| 8 | One card called the Unsloth route planned and another called it a proposal. | M C | The cards agree: the route is planned and needs the operator's approval when it is made. Only Xcode Cloud is listed as a proposal. |
| 9 | The as-found subtitle still said the app "never reaches" the Mac's models. | M | "No path was found from it to the model router on the Mac or to the DGX pair." |
| 10 | "The router accepts local connections only" was stated flat. | C | "per the operator's log the router listens on a loopback port". |
| 11 | Two lists on a target card did not match the model. | C | Both lists name every component they cover, and say on what basis the app is tagged configured. |
| 12 | The citation for the sandbox request started two lines below the line that names the vendor. | C | The range now starts at that line. |
| 13 | The readme's limits left out three things, and the comparison's "light" captures are dark renders. | C | The readme states them; those captures are not kept. |

## After the last round

The thirteen changes above were made after round 3. Every gate was run again and passes, with the same single advisory. The author looked at the new captures of the target and the comparison. No independent reviewer has seen these last edits: they are six text changes on cards, four sublabels, one relationship label, one label moved 14 units, and two citation ranges.

Final comparison counts: components 9 added, 5 changed, 1 removed; relationships 15 added, 2 changed, 1 removed; boundaries 1 added, 3 changed.

## Left as it is

- "phase 2 · local" has 4 units to each neighbouring box.
- The canvas is 1420 units wide, so relationship labels on the single maps sit at the 7.5px floor.
- Ray-Ban Meta is in no boundary.
- The route to the GLM server runs 10 units from the DGX frame for 44 units before entering it.

## Not checked by any round

Hover and focus in a live browser. The Before and After tabs of the comparison. The as-found and comparison pages at phone width. Anything on the Mac or the DGX pair.

## To revisit when the plan moves

- "no writes" on the web exit matches today's description. Task M4-02 adds acting tasks through the same harness lane; when it does, that label has to change.
- Where photos kept on the Mac sit on the map depends on question O-7.
- When O-9 is answered, the GitHub box names the chosen repository. When O-3 is answered, Unsloth Studio moves into the frame of its machine.
