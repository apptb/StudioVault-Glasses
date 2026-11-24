# Reference clients: a watch client and a room speaker for Hermes

Status: **proposed**, 2026-11-21; checked against the files again and corrected on 2026-11-24. A study, with proposals for [PLAN.md](PLAN.md). Nothing here is adopted and no decision in the plan has changed.

The operator pointed to two public projects as "a related segment of the infrastructure to take inspiration from". Six readers studied them. Two verifiers checked every finding against the files. No finding was refuted: 72 of 114 were confirmed as written and 42 in part. Where a verifier corrected one, the correction is used here.

How each fact is known:

- **read**: read in the file at the pinned commit by a reader and a verifier. The lines cited below were opened again when this document was written.
- **run**: seen in a test run in this study, on a cloud machine with no device.
- **file**: matches a result file or a constant in the repository. Not measured again.
- **stated**: the project says so in prose and keeps no artefact.
- **inferred**: reasoning from the above, not a finding.

Everything in sections 2 and 3 is **read** unless marked. Paths are relative to each repository. `W:` is the watch project and `H:` is the room speaker. `APP/` stands for `app/src/main/java/dev/hermes/wearos/`. The readers' and verifiers' working files are not in this repository.

## 1. The two projects

**Watch client.** `borealBytes/hermes-wearos`, commit `50b65cd` (2026-11-12), version 0.10.12. A Wear OS app in Kotlin, about 24,000 lines, for a self-hosted Hermes agent. With it come a Python plugin that runs inside Hermes (pairing, device registry, key delivery, an outbox) and a Node helper that its default speech-to-text goes through. The watch sends each ask straight to Hermes's own runs interface.

- Licence: MIT, app and plugin. Outside that grant: a committed binary of its embedded Tailscale node (16.9 MB), for which no third-party notice was found; speech models, which are downloaded and whose licences are mostly not stated in the files read; its cloned-voice assets. None of those is for lifting.
- Examined: read. The app compiled and its 528 JVM unit tests passed (**run**). No run of the plugin's Python tests is recorded for this study.

**Room speaker.** `RaYYeR220/housemate`, commit `09c1a1d` (2026-11-10). A Hermes plugin in Python that turns browser pages into room microphones and speakers. A hub inside the Hermes process hears the wake word and decides end of speech. Hermes transcribes, runs the model and speaks.

- Licence: MIT for the code. The wake-word and feature models it downloads (openWakeWord v0.5.1, with the "hey jarvis" head) are CC BY-NC-SA 4.0, non-commercial. A head trained with its recipe inherits those terms. Silero VAD is MIT. Piper voices carry their own licences.
- Examined: read. Its test suite gave 556 passed, 4 skipped, 10 deselected (**run**). Its own result file records 566 passed and 4 deselected against Hermes 0.23.0. The totals agree at 570, so the tests that need a real Hermes or the real wake models did not run here (**inferred** from the test markers).

Nothing was run on a watch, in a browser, with a microphone, or against a real Hermes. Both repositories carry instructions written for agents or reviewers (install a plugin, restart a gateway, delete a folder). None was followed. The watch app is Kotlin and the glasses app is Swift, so the phone side borrows by pattern. The Python pieces could be copied under MIT with the notice kept (O-16).

## 2. What the plan should take

Fourteen patterns, each one bearing on a decision, a contract or a task. The last column is wording the plan could adopt. Task ids marked "proposed" are not on the board.

| # | Pattern | Where | Bears on | Proposed wording |
|---|---|---|---|---|
| 1 | Each ask gets one idempotency key, reused on every retry. The answer comes on an event stream while a status poller runs beside it, and whichever path finishes first settles the turn, once. | W: `APP/domain/ChatSession.kt:518-545, 559-586, 650-676, 1437-1440`; `APP/net/HermesApi.kt:17-31, 84-86` | 4.3 `POST /v1/turn`; M1-01, M1-04; M3-02 to M3-05; proposed M1-11 | "The phone sends an idempotency key with each turn and reuses it on a retry. The gateway returns the same turn for the same key and refuses the same key with a different body. `ack` carries a turn id. A status route returns the turn's state, any pending confirmation and, once finished, the whole answer. The phone reads it when the stream drops, and speaks an answer once." The watch's authors found on a live run that a parked approval left the stream open and silent. Only the poller showed it. |
| 2 | End of speech is decided by the transcript no longer growing (watch) or by silence (room speaker). Each is a small state machine with a hard cap. | W: `APP/domain/Vad.kt:12-57`; `APP/MainActivity.kt:456-462`. H: `core/endpointer.py:41-56, 148-163`; `core/listener.py:322-325` | 4.2 step 3; M1-04; RESOURCES "End of speech"; proposed M1-14 | "Two rules are candidates: growth of the on-device transcript, and silence from a voice-activity detector. Either is a pure state machine with a hard cap, a minimum of speech, and 'nothing heard sends nothing'. The rule and its constants are chosen by measurement on glasses audio. A second press while words are still arriving cancels; after a pause it sends." The constants are in section 4. As tuned, the watch's rule cannot meet M1-04's one second: it waits 1.2 s after the last new word by design. The room speaker's rule closed a median 0.69 s after the last speech frame, but only on synthetic clips fed in digitally (**file**). Neither has been run on glasses audio. |
| 3 | The room speaker's wake word runs on the server, over a microphone stream that is always open. | H: `core/wake.py:1-12`; `core/listener.py:348-367`; `core/models.py:41-42`; `README.md:225` | D-07; M2-02, M2-05; RESOURCES "Custom wake phrase" | "A wake word heard on the server needs the glasses microphone open and its audio streamed to the Mac for as long as it listens. D-07 counts an open microphone as the cost a custom phrase has to justify in M2-03, and D-02 keeps it closed between turns; a server-side spotter adds a continuous audio stream over the tailnet to that cost. It is not a candidate unless M2-03 shows the open session is acceptable. Whichever spotter M2-02 picks, keep these mechanics: fire once and re-arm only after the score falls; ignore one second after a trigger; cut the wake phrase out of the audio sent for transcription; pin model files by hash; keep the button working when the spotter fails to load." The detector itself is a possible third candidate for M2-02 only if O-14 allows its licence. |
| 4 | Two harnesses. The stock phrase is scored through the listener's own trigger rule (fire once, re-arm below the threshold, 1 s quiet period) and has no pass bar. The custom phrase is scored by a separate script against a bar of 90% recall at no more than 0.5 false accepts an hour; it counts a crossing and then ignores 2 s, and picks the threshold after the sweep. It missed that bar in four training runs, and the failure is written up. The bar and the first results were committed together, so the repository does not show that the bar came first. | H: `bench/run.py:55-77, 294-302`; `wakeword/eval_wake.py:200-209, 257`; `wakeword/MODEL_CARD.md:3-11, 66-92`; `results/wake.json` | D-07; M2-02, M2-04, M2-06; proposed M2-07 | "Before any spotter is scored, write the pass bar: recall and false accepts per hour at one threshold. Score through the shipping trigger rule, not raw scores. Record each false accept with its file and time. Use several hours of negatives: no event in one hour only shows a rate below about three an hour (**inferred**). Test the phrase against near-misses in the wearer's own voice. Keep a failed result." What the published wake figures do not show is in section 3. |
| 5 | An approval answer names the one pending request, is single-use and expires, and the device that answered is recorded. | W: `APP/net/HermesApi.kt:281-288`; `APP/domain/ChatSession.kt:665-670`. H: `core/answers.py:1-15, 108-114, 181-200`; `adapter.py:100, 607-611, 1807` | 4.3 `POST /v1/approvals/{id}` and receipts; M3-06; D-08 | "A confirmation names the pending action by id and by a counter that changes when the action is planned again. The gateway refuses any other pair. Only the device that was asked may answer. The receipt records the device and whether the answer was spoken or tapped. An answer to an older question never confirms a newer action. A second trigger while a confirmation is pending never cancels it; whether it may carry the answer is O-17. The check is on the device, not the person: anyone the microphone hears can say the word, which is why A3 has no path." In the watch the two identifiers are optional in the request. The plan should require them. In the room speaker every utterance from the asked device is taken as the answer while the prompt is armed, for up to 310 s (H: `adapter.py:100, 670-691`). Its claims file says it does not know who is speaking: anyone in earshot of a paired speaker can talk to the agent (H: `CLAIMS.md:68`). On Hermes 0.23 the resolver takes no actor, so the answering device is not passed on (H: `adapter.py:2313-2320`). |
| 6 | The approval card shows the command whole, never cut. The voice reads only a short description. | H: `adapter.py:196, 1671-1675, 2304-2311`; `tests/test_approvals.py:605-622` | R8; D-08 tier A2; M4-02; M3-06 | "The ear hears a short description. The phone holds the exact action, whole, and the confirmation is bound to that text. A spoken 'confirm' grants this one action, once. An action the gateway's own check flags cannot be confirmed by voice." Nothing in the room speaker checks that the description matches the command. With no screen in view that gap is wider (**inferred**; O-12). R8, D-08 and M4-02 have the plan read aloud, so this wording would change all three; O-12 asks first. |
| 7 | A spoken answer counts only when the whole utterance is a short approve phrase. Everything else fails closed. | H: `core/intents.py:34-84`; `adapter.py:104, 668-692, 1499-1504` | D-08 tier A2; M3-06; proposed M3-08 | "Only a whole utterance confirms: at most four words, no question mark, every word from a fixed confirm list or a short filler list. Anything else is asked again, at most twice; after that only the phone answers. An answer that overlaps the assistant's own audio, or starts within 0.3 s of it, is refused." The parser is English only. Its confirm list is wider than D-08's one word: it also takes "yes", "yes please", "do it", "go ahead", "approve" and "approved", and treats the wake phrase as filler (H: `core/intents.py:37-45`). A copied parser needs its list cut to what the M3-01 ADR fixes. The phone sends the transcript of the answer and the gateway applies the rule, so it stays in gateway code (D-08). The parser sees what the recogniser wrote, so check how Apple's recogniser writes "confirm". |
| 8 | One pure function decides whether an answer is spoken or becomes a silent notification. Both paths must call it. | W: `APP/domain/AttentionPolicy.kt:16-38`; callers `APP/ui/VoiceHost.kt:54`, `APP/domain/AwayWatch.kt:54`, `APP/domain/ChatSession.kt:1472-1476` | R12; M3-05; M6-01; 4.2 step 7; proposed M1-13 | "One function answers 'may the assistant speak now' from turn state: a turn is open, the glasses are the audio route, no call is in progress. The reply path and the late-result path both call it. When it says no, the result becomes a notification or a tone and waits for the next wake. Its test table changes together with this sentence." The watch's rule is about a screen; only the shape carries over. The watch never speaks unprompted, and R12 as worded lets the assistant speak first (O-13). |
| 9 | Results that arrive after the turn wait in a per-device outbox. The device drains it with a cursor and an acknowledgement. | W: `hermes-plugin/pairing.py:48-49, 604-640`; `hermes-plugin/__init__.py:792-800`; `APP/WearApp.kt:838-866` | 4.3 `GET /v1/tasks`; M3-05; R12; M6-01 | "Late results wait in a per-device queue on the gateway. The phone reads from a cursor and acknowledges what it has delivered. The queue is bounded, drops old items, and folds a burst from one job into one line." The watch acknowledges after showing at most 160 characters, and the gateway then deletes the item. The plan should acknowledge only after the whole result was spoken or listed. |
| 10 | Pairing is closed until a window is opened, and the code is typed by a person: no tool the model can call sees, mints or approves a code. In the watch the model's own tool can open the window (W: `hermes-plugin/__init__.py:1431-1442`); the wording proposed here is stricter. The device is then also known by its network identity. | W: `hermes-plugin/pairing.py:40-47, 298-316, 508-521`; `hermes-plugin/__init__.py:90-92, 1431-1437`; `hermes-plugin/private_api.py:228-235, 303-308`. H: `core/store.py:150-154`; `core/hub.py:394-397` | M1-03; M1-02; 4.3; D-03 | "Pairing opens only when the operator opens a window at the Mac. The gateway issues a short code and the operator types it at the Mac. No tool the model can call takes, shows or approves a code. The gateway keeps only a hash of the device token, compares in constant time, and tells a revoked phone to erase its token. Check before relying on it: what the gateway can learn about the caller behind the Tailscale Serve mapping. If it can learn the device, bind the token to it on first use and refuse it from any other." This would replace the flow in M1-03 and section 5.1, where a token minted at the Mac is typed into the app's existing gateway screen and `GET /apps` checks it, and it needs a new pairing screen in the app. That flow already keeps the model out, because the token is minted at the Mac. What carries over without changing it: keep only a hash of the token, compare in constant time, tell a revoked phone to erase its token, and give the model no tool that mints, shows or accepts a token. Corrections from the verifier: the watch's identity check covers two groups of routes only; the pending code is kept in plain text beside its hash; the list of places allowed to approve includes an empty name. |
| 11 | The client picks its route before the request, picks again when the network changes, and turns a failure into one sentence that names the fix and counts only what was tried. | W: `APP/domain/Failover.kt:10-63`; `APP/net/EndpointResolver.kt:180-184`; `APP/domain/NetworkWatch.kt:84-90`; `APP/domain/RouteReport.kt:17-22, 63-88`; `docs/SPEC.md:589-592` | M1-01; M1-02, M1-03; risk 9; turn log; proposed M1-13 | "A failed turn is spoken as one sentence that names the link that failed: phone off the tailnet, gateway not answering, token refused, or model route failed. It counts only what was really tried. Reachability is checked when the network changes and when a trigger fires, not inside the latency window. `GET /healthz` takes no token, so it never stands in for the pairing check." One dead probe costs the watch up to 2.8 s. If the gateway ever has two addresses, the watch's ordered list with a remembered last good address is the model. |
| 12 | Every turn is stamped at named stages. A scripted client replays a recorded question against the real server to measure them. | H: `adapter.py:2245-2261`; `core/control.py:462-464`; `bench/run.py:405-424, 486-492`; `results/latency.json:42-79` | M1 latency budget; 4.3 turn log; M0-06, M1-07, M1-09; proposed M1-12 | "The turn log names its stages once and records each in seconds after the end of speech: capture closed, transcript ready, request sent, first model token, first tool call, first spoken word. A scripted client replays a recorded turn against the real gateway in real time. It reports one warm-up run apart from the rest and writes the setup, never a key, into the result file." |
| 13 | A claims file grades every public statement by its evidence and lists what is not claimed. A walk-through lets a reviewer check the product with no phone: two browser windows on one PC, a microphone and a running Hermes. | H: `CLAIMS.md:3-26, 65-78`; `scripts/render_numbers.py:35-47, 84-105`; `JUDGES.md:3, 50-62`; `tests/fake_satellite.py:1-5` | C7; reports in section 6 (M0-04, M0-06, M1-08, M2-02, M5-03); 5.3; proposed M1-15 | "Each report grades its statements: reproduced by a command in the repository; seen live, with the steps; follows from the code but not measured; not claimed. Each names its artefact. Numbers in prose are filled from the result file by a script, and its check runs with the tests. A review path needs no glasses: the scripted client and the phone's own camera, with the words to say, what to look for, and the test that pins each step." In the room speaker the check mode is unit-tested on a sample file (H: `tests/test_render_numbers.py`), but no test or CI step runs it against the README itself, only 11 numbers are filled by the script, and two README statements have no row. Adopt the method with the check wired in. The four grades sit beside C7, not in place of it: "reproduced" is C7's verified, "seen live" is executed, "follows from the code" is configured or loaded. |
| 14 | Decisions live in small pure functions that take time and events as inputs, so they are tested without a device. | W: `APP/domain/` (46 files, 45 with no Android import); `AGENTS.md:151`; `.github/workflows/ci.yml:45-48`; `app/src/debug/AndroidManifest.xml:1-12` | 4.1 Turn engine; M1-04, M1-07; 5.3; proposed M1-13 | "The turn engine keeps its decisions in plain Swift types that import no SDK, audio or network module: end of speech, what a trigger press means in each phase, may-speak, settle-once, failure wording. The SDK session, the audio route and the camera are a thin shell that forwards events. A debug-only entry starts a turn from a photo file and a transcript." The watch's exception is its 1,507-line run and approval file. It has no test, and its two different rules for picking the approve word live there. |

## 3. What does not transfer, and why

- **The 2.6 s headline** (H: `results/latency.json:42-79`, **file**). In the loop: real transcription on a GPU, a hosted text model, a local streaming voice. Not in the loop: a browser, a microphone, a loudspeaker, any network hop between the device and the hub (the scripted client ran on the hub's own PC), an image, a tool call. The model call did cross the internet to a hosted service. There were two clips, synthetic voices asking arithmetic, and the replies were a single word in all but one run ("Four.", "Nine."), so the first audio needed almost no model output. The file was written at commit `75194b4`, 28 commits before the pinned one, and records no plugin commit. The clock stops when a script receives the first audio frame, not when sound is heard. Stage split, medians: 0.69 s waiting for silence, 0.83 s transcription, 0.06 s to the model request, 0.99 s model plus first audio. Git history holds an earlier run with another hosted model at 3.1 s. What carries over is the method and one reading: the silence wait and transcription were more than half, and under D-05 both sit on the phone.
- **The wake figures** (**file**). Every positive is a synthetic voice fed in digitally. The negatives are read audiobooks. No person, microphone, room, music or television. Recall under background speech is one draw: 55 of 58 in the committed file, 51 of 57 in an earlier committed run of the same model. The stock phrase was never put through the harder set that the custom phrase failed.
- **The watch has no wake word.** A search of its code, manifest and documents finds none. Every turn starts with a touch. There is no conversation mode and no spoken answer to an approval. It gives no evidence for or against a custom phrase. It has no figure for end of speech to first spoken word, and none for battery.
- **A spoken "approve" can run a delete.** The room speaker's own walk-through deletes a folder by saying "approve" (H: `JUDGES.md:53-59`). Its approvals are Hermes's command approvals, so whatever Hermes offers for approval can be approved by voice unless Hermes's own check flags it. R9 and tier A3 forbid exactly that. Take the parser and the binding. Do not take the reach.
- **The watch lets the client approve.** Per-chat modes approve always, or exactly when the wearer is not looking (W: `APP/domain/ApprovalMode.kt:31-35`, `APP/domain/ChatSession.kt:686-696`). Its approval receiver is exported with no permission, so any app on the watch that knows a run id can answer (W: `app/src/main/AndroidManifest.xml:85-92`). Its notification shows at most 120 characters of the command. This is the opposite of D-08.
- **The watch holds a shared key.** Revoking one watch changes the key for every client of that Hermes profile and can restart Hermes (W: `hermes-plugin/__init__.py:343-401`). The per-device token in D-03 avoids this.
- **Android and browser plumbing.** The embedded Tailscale node (about 44 MB of native code by the README's own count, **stated**; a permanent foreground service; battery cost unmeasured), wake locks and chained background jobs have no iOS counterpart. An iPhone runs Tailscale itself. The browser page needs a tap after every load and a visible screen.
- **Stopping.** The watch's stop does not cancel a sentence already being synthesized (W: `APP/voice/GatewayTts.kt:309, 322-353`). The room speaker has no spoken way to cancel a running turn, and its barge-in is unmeasured. Neither helps M1-05's half second.
- **The constants as tuned.** 1.2 s and 0.7 s are the authors' choices, with no cut-off rate behind them. On one of the watch's recognisers the first pause sends what was said so far as an ask, and the rest of the utterance is dropped while that run is busy. A one-photo, one-question turn must not copy that.
- **Prose ahead of code.** The verifiers list 43 contradictions. Nine or ten are between this study's own readers and were settled against the code. The other 33 or 34 are places where a README, a spec or a comment in the two projects disagrees with the code, with a result file or with itself. Take the code as the record.

## 4. Numbers, and what each one measured

None of these is a target or a baseline for the glasses. Section 3 says why.

| # | Value | What was measured, and how | Status |
|---|---|---|---|
| 1 | 528 unit tests, 0 failures, no device; 415 of them on the pure-logic package | The watch app's JVM tests, run in this study; counts recounted in the tree | run |
| 2 | 556 passed, 4 skipped, 10 deselected | The room speaker's suite, run in this study. Its own file says 566 passed and 4 deselected with Hermes 0.23.0 (see section 1) | run (556 of 570 here); the project's own 566 was not reproduced |
| 3 | 2.556 s median, 3.203 s 95th percentile, 20 warm runs | End of speech to the first reply audio frame received by a script on the hub's own PC. Two synthetic clips, replies of one word in all but one run, a hosted text model. No microphone, loudspeaker, image, tool call or device-to-hub network hop. Written 28 commits before the pinned commit | file (H: `results/latency.json:54-59`) |
| 4 | 0.69 / 0.83 / 0.06 / 0.99 s | Stage medians of the same runs: silence wait, transcription, transcript to model request, model plus first audio | file (H: `results/latency.json:73-79`) |
| 5 | 6.446 s | The first run of the same bench. The README calls it "about 7 s" after a restart; the file does not record a restart | file (H: `results/latency.json:60-62`) |
| 6 | 58 of 58 clean; 55 of 58 with speech 10 dB lower; 1 false wake in 9.21 h | The stock "hey jarvis" model at threshold 0.5. Synthetic voices; read audiobooks as negatives. With one event the true rate could lie from near zero to about 0.6 an hour (**inferred**). An earlier committed run of the same model gave 51 of 57 with background speech | file (H: `results/wake.json`) |
| 7 | Custom phrase: 89.4% recall at 0.34 false accepts an hour at best (third run, first held-out set; 4 events in 11.6 h, which the authors put at roughly 0.1 to 0.9 an hour); 77.6% at 0.43 for the fourth run on a stricter, accent-heavier held-out set, where the third run scores 78.5% at 0.34; the bar was 90% at no more than 0.5 | Four training runs on one 8 GB GPU: 60 to 80 minutes each for three, about 2 h 10 min for the fourth. Scored by a separate script that counts a crossing and then ignores 2 s, with the threshold picked after the sweep, so these figures cannot be set beside row 6. The raw reports are outside the repository | stated (H: `wakeword/MODEL_CARD.md:3-11, 40-48, 66-93, 108-117, 143`) |
| 8 | Watch: send 1.2 s after the last new word, 20 s cap, a press within 0.9 s of a word cancels. Room speaker: 0.7 s of silence, 0.25 s minimum speech, 15 s cap, 5 s give-up | Design constants. No cut-off rate was measured for either | file (W: `APP/domain/Vad.kt:14-57`; H: `core/endpointer.py:45-51`, `core/listener.py:92`) |
| 9 | Watch: status poll every 3 s; stream read timeout 45 s; route probe 2.5 s with a 2.8 s limit; winner kept 5 minutes; network-change debounce 1.5 s | Constants | file (W: `APP/domain/ChatSession.kt:87, 657`; `APP/net/EndpointResolver.kt:182-184`; `APP/domain/Failover.kt:28`; `APP/domain/NetworkWatch.kt:86`) |
| 10 | Pairing code lives 300 s; three wrong codes lock for 300 s, then 900 s. Outbox: 50 items, 24 hours, folds after 5. Spoken answer: at most 4 words, 2 repeats of the question; listening without a wake word 10 s for an answer and 6 s for a follow-up; the answer stays armed for 310 s | Constants | file (W: `hermes-plugin/pairing.py:40-49, 617`; H: `core/intents.py:46`, `adapter.py:100, 104`, `core/config.py:78-79`) |

## 5. What this changes in the plan

These are proposals. The decisions stand as written until the operator rules on them.

**D-03, the gateway.** Both projects reach the model through Hermes itself. The watch posts to Hermes's runs interface and has no gateway of its own; its plugin sits beside the data path. The room speaker runs inside the Hermes process as a platform adapter.

- What that offers, already built: idempotent submit, an event stream, a status read that carries the final answer, parked approvals answered by request id, stop, sessions. This is **read** in the watch's client and, by one reader and one reviewer, in a checkout of `NousResearch/hermes-agent` `main` at `242315c` (2026-11-09), not a release tag (`gateway/platforms/api_server_runs.py:285-300, 559-564, 1370-1381`); sessions are **read** in the watch's client only. How long a replay is remembered is **stated** only.
- What it would cost against D-08: Hermes's approval mode is set per profile (manual, smart or off), not per request (**stated**, W: `docs/SPEC.md:816-822`). Its approval answers include grants wider than one action, except for a request carrying a room grant token, which may answer only once or deny (**read** in the same checkout, lines 1370-1381). Whatever it offers for approval can be approved, a delete included. D-08 wants the tiers in code the operator controls, and no execution path at all for A3.
- Other costs: an adapter shares Hermes's process; the watch's route hands the device a shared key; whether a photo survives the runs interface is **unverified** (the watch sends text only).
- The choice is the operator's (O-11). (a) D-03 as written, adopting the patterns in section 2; this needs no new fact. (b) Keep the gateway for the token, the tiers, confirmations and the turn log, and put Hermes behind it as the model and tool loop for A0 and A1 work, or as one more harness under D-09. This changes D-03, because the gateway no longer runs that loop, and it keeps D-08 only if the Hermes profile used can call nothing beyond A0 and A1 tools: a tool Hermes runs itself is outside the gateway's tier code. M0-19 has to show that. (c) Make the glasses a Hermes client or platform and drop the gateway's own loop; this needs D-08 rewritten. Until the operator answers, (a) holds. Proposed M0-19 gathers the facts for (b) and (c).

**D-05, speech.** Nothing here argues against starting on the phone. Three additions are proposed for the turn engine: speak the first finished sentence while the rest streams (W: `APP/voice/SpeakAloud.kt:20-24`); never hand the speaker more audio than the wearer should hear after a cancel; stop locally on the trigger before any network call. If a gateway speech route is added later, keep a local fallback and measure it. The watch's gateway voice took 271 s cold and 29 to 41 s warm per call on its owner's machine (**stated**), and its replay fallback still loses the sentence in three coded cases.

**D-07, wake.** The default stands, and nothing here argues against it. One project has no wake word. The other's custom phrase missed its authors' bar in four runs on synthetic voices, which says little about a phrase tested on the wearer's own voice, and its working stock phrase needs an always-open microphone and a non-commercial model. Proposed: rows 3 and 4 above, and M2-07 before M2-02 runs.

**D-08, approvals.** The tiers stand. Rows 5 and 7 sharpen tier A2 and M3-06. Row 6 would change what is read aloud. One point is open: A2 says the plan is read aloud. The room speaker reads a short description and shows the whole command on a screen. Glasses have no screen; the phone has one. O-12 asks which the operator wants.

**Elsewhere.** Section 4.3 would gain the key, the status route and the outbox (rows 1, 5, 9). The M1 budget runs from the end of speech, so it already contains the silence wait, and the plan should say so: at a 4 s median, a 0.7 s wait is more than a sixth of the budget, spent before anything is sent. R12 needs its own rule (row 8, O-13). Eight tasks are proposed for the board: M0-19, M1-11 to M1-15, M2-07 and M3-08. Adopting a task means one line in TODO.md and one acceptance row in PLAN.md section 6; both are written out in section 7.

## 6. Questions for the operator

Proposed additions to section 9 of the plan.

| # | Question | Why it matters |
|---|---|---|
| O-11 | PLAN.md section 2.2 records Hermes installed on the Mac with its gateway running. Do you count it as part of the fabric the glasses may use? If you do, should a glasses turn (a) stay on the gateway in D-03, (b) pass through the gateway to Hermes for A0 and A1 work, or (c) go to Hermes directly as a client or a platform plugin? | D-03, D-08, D-09. Decides whether proposed M0-19 runs. Options (b) and (c) change D-03; (b) keeps D-08 only with a Hermes profile limited to A0 and A1 tools; (c) needs D-08 rewritten |
| O-12 | D-08 has the plan read aloud before an A2 action. The room speaker speaks only a short description and shows the whole command on a screen. Should the glasses read the whole plan aloud, or speak a short description with the whole action shown on the phone? For which kinds of action must the answer be a tap? | R8, D-08, M3-06, M4-02 |
| O-13 | R12 says the assistant can speak first. The two reference clients split. The watch stays silent outside the chat on screen and sends a notification. The room speaker speaks unprompted: timer rings, announcements, cron deliveries and reminders are spoken in the room. M3-05 already speaks a late result on the next wake. Should a due reminder or a late result be spoken unprompted, or signalled by a tone or notification and spoken on the next wake? | R12, M3-05, M6-01 |
| O-14 | Is your use of a wake word non-commercial? The only working open wake word seen in this study uses models under a non-commercial licence. | Whether it can be a third candidate in M2-02 |
| O-15 | What pass bar do you want for a custom wake phrase, set before any spotter is scored? The room speaker's authors chose 90% recall at no more than 0.5 false accepts an hour, and missed it. Will you record your own voice saying the phrase and near-miss phrases? | M2-02, M2-04, M2-06, proposed M2-07 |
| O-16 | May MIT code from the two projects be copied into the working repository with its notice (the spoken-answer parser, the bench script), or are they a source of patterns only? | D-12; depends on the gateway's language, which the plan does not fix |
| O-17 | A confirmation expires after 60 seconds (M3-06). For how much of that should the glasses microphone stay open without a new trigger, and may a new trigger inside the 60 seconds carry the answer? The room speaker listens without a wake word for 10 seconds and keeps the answer armed for 310 seconds, during which any utterance from the asked device is taken as the answer. | M3-06, M2-03: each open second holds the hands-free profile |

## 7. The proposed tasks

Eight tasks, none of them on the board. Each entry holds what adoption needs: the line for [TODO.md](TODO.md) and the acceptance row for PLAN.md section 6. Adopt a task by adding both in one change, with a ledger line that quotes the operator.

### M0-19 (proposed). Hermes probe, only if O-11 names Hermes: the runs interface with a photo, a replayed key and a parked approval

Owner: any. Gate: OP.

Acceptance: Runs only if the operator's answer to O-11 names a Hermes agent as part of the fabric; otherwise it is dropped with the answer quoted. The operator's approval of the probe, the profile and the scoped key is quoted in the ledger; the key is never printed. `docs/program/reports/M0-19-hermes-probe.md` shows, in this order: the approval mode of the profile used, who can change it, and the tools that profile can call; one run submitted twice under one idempotency key comes back as one run, and the same key with a different body is refused; one run with a photo answers correctly, or the report says the photo did not survive; a status read after the stream is closed returns the whole answer; then, only if the approval mode read manual, one gated command with no lasting effect (deleting an empty folder the probe created) parks, the report lists the approval choices offered and whether an answer without the request id is refused, and the probe answers deny and shows the folder still there. If the mode is not manual that check is not run and the report says so. If a check fails, the failure is the finding.

Board line:

```
- [ ] **M0-19** Hermes probe, only if O-11 names Hermes: the runs interface with a photo, a replayed key and a parked approval · owner:any · gate:OP · state:queued
```

### M1-11 (proposed). Turn submission that survives a dropped link: idempotency key, turn id, status route, settle once

Owner: code. Gate: R1.

Acceptance: With the model mocked, tests show: a turn sent twice under one key runs once and returns the same turn id; the same key with a different body is refused; a tool with a side effect runs once when the phone retries; with the stream cut after `ack`, a status read returns the state, a pending confirmation if there is one, and the whole answer once finished; the app speaks an answer once when the stream, the status read and a resume all deliver it. The key and the turn id are in the turn log.

Board line:

```
- [ ] **M1-11** Turn submission that survives a dropped link: idempotency key, turn id, status route, settle once · owner:code · gate:R1 · state:queued
```

### M1-12 (proposed). Scripted turn client and per-stage latency marks in the turn log

Owner: code. Gate: R1.

Acceptance: The turn log holds named stages for every turn, in seconds after the end of speech; the stage names are listed once in PLAN.md section 4.3. End of speech, capture closed, transcript ready and request sent are stamped by the phone and sent with the turn; first spoken word is stamped by the phone and reported after the turn; first model token and first tool call are stamped by the gateway. The log says which clock each mark came from. A script in the repository replays a recorded turn (transcript, photo and the phone's recorded marks) against the running gateway in real time, reports one warm-up run apart from the rest, and writes a result file with the raw runs, the stage medians and the setup. Its report says that it measures from request sent to the first reply text, and that end of speech, transcription and spoken output are measured on the device in M1-09. A test shows the result file holds no key.

Board line:

```
- [ ] **M1-12** Scripted turn client and per-stage latency marks in the turn log · owner:code · gate:R1 · state:queued
```

### M1-13 (proposed). Turn rules as pure functions with injected time: end of speech, trigger by phase, may-speak, failure wording

Owner: code. Gate: R1.

Acceptance: End of speech, the meaning of a trigger press in each phase of a turn, may-speak, settle-once and failure wording are plain Swift types that import no SDK, audio or network module and take the time and events as inputs. Each has a test table that runs in the simulator and in the Xcode Cloud workflow with no glasses, microphone or network. The may-speak function is the only place that decides between speaking and notifying; the reply path and the late-result path both call it. The failure function gives a different sentence for each of: phone off the tailnet, gateway not answering, token refused, model route failed. A debug-only entry starts a turn from a photo file and a transcript, and is absent from release builds.

Board line:

```
- [ ] **M1-13** Turn rules as pure functions with injected time: end of speech, trigger by phase, may-speak, failure wording · owner:code · gate:R1 · state:queued
```

### M1-14 (proposed). Measure the end-of-speech rules on recorded glasses audio and choose the constants

Owner: code. Gate: R2.

Acceptance: At least thirty questions recorded by the operator through the glasses microphone, some with a pause in mid-sentence. Every end-of-speech candidate in RESOURCES.md runs over the same recordings: growth of the on-device transcript, silence from a voice-activity detector, and the end-of-utterance model in FluidAudio, or the report says why one was left out. `docs/program/reports/M1-14-end-of-speech.md` gives, for each rule and setting: the delay from the last word to the close, how many questions were cut short, and how many ran to the cap. The rule and constants that M1-04 uses are chosen from that table and logged. If none closes within M1-04's one second without cutting questions short, the miss is recorded and the target moves only by a logged decision.

Board line:

```
- [ ] **M1-14** Measure the end-of-speech rules on recorded glasses audio and choose the constants · owner:code · gate:R2 · state:queued
```

### M1-15 (proposed). Claims file and a review path that needs no glasses

Owner: any. Gate: R1.

Acceptance: `docs/program/CLAIMS.md` lists every measured number and every statement that something works in the README and the reports so far. A reviewer picks ten such statements from those files at random and finds a row for each. Each is graded as reproduced by a command in the repository, seen live with the steps given, follows from the code but not measured, or not claimed, and each names its artefact. A "not claimed" list sits beside them. Numbers in those files are filled from result files by a script; its check mode runs with the tests and fails on a stale number. A walk-through lets a reviewer run one full turn with the scripted client and one with the phone's own camera; each step gives the words to say, what to look for, and the test that pins it.

Board line:

```
- [ ] **M1-15** Claims file and a review path that needs no glasses · owner:any · gate:R1 · state:queued
```

### M2-07 (proposed). Wake measurement protocol, written before any spotter is scored

Owner: any. Gate: R1.

Acceptance: A one-page protocol is committed before M2-02 runs. It states: the pass bar the operator gave in O-15 (recall and false accepts per hour at one threshold); that scoring uses the shipping trigger rule (fire once, re-arm after the score falls, a quiet period after a trigger); how many hours of negative audio are used and why that many are enough for the bar; a list of near-miss phrases recorded in the wearer's own voice; that every false accept is kept with its file and time; that the false-accept rate is reported with an interval; the licence of each candidate's model files; and that a failed result is kept and written up. M2-02's report follows it. M2-04 decides against this bar and M2-06 tests against it; in the same change M2-06's acceptance reads "false accepts within the bar written in M2-07 and confirmed in M2-04, and battery within the budget set in M2-04". If O-15 is answered "decide later", M2-02 does not start.

Board line:

```
- [ ] **M2-07** Wake measurement protocol, written before any spotter is scored · owner:any · gate:R1 · state:queued
```

### M3-08 (proposed). Spoken-answer parser and self-hearing guards for confirmations

Owner: code. Gate: R1.

Acceptance: M3-06 keeps the binding, single use and expiry; this task is the parser and the guards. The phone sends the transcript of the answer and the gateway applies the parser, so the rule sits in gateway code (D-08). A test table shows: only a whole utterance of at most four words, with no question mark and every word from the confirm list fixed in the M3-01 ADR ("confirm" under D-08) or the filler list, confirms; hedged, mixed, longer and question forms do not, are asked again at most twice, and after that only the phone answers; an answer that overlaps the assistant's own audio or starts within 0.3 s after it (the value is in the ADR) is refused; an answer whose words match what the assistant just said is refused; an answer to an older question never confirms a newer action; a second trigger while a confirmation is pending never cancels it. The phone shows the whole action the confirmation is bound to. The receipt records the device and whether the answer was spoken or tapped.

Board line:

```
- [ ] **M3-08** Spoken-answer parser and self-hearing guards for confirmations · owner:code · gate:R1 · state:queued
```
