# Full-world session storage (schema 15; registered schema 13/14 migration)

This is separate from the six-field profile prototype. The current game session
uses `scripts/session_storage.gd`, `journey_store_native.gd` and
`profile_storage_web.js`. Atomic retirement/chapter/final-victory and explicit risk-mode fatal-combat
settlement are exposed; legacy imports are not. The old `journey-v4` file is untouched.

## Contract

The async adapter returns `{ok,status,reason,snapshot,run_id,slot,revision,
eligible,retryable,readonly}`. Empty storage returns `ok=false,status=empty`
without read-only mode; it is not an I/O failure.

- `create_run(seed, layout=2, mode="safe", replace_active=false, request_id="")`
  constructs a fresh World whose run ID is the stable request ID. It never grafts
  identity onto an old save.
- `commit_run(expected_slot, expected_revision, run_id, snapshot, request_id)`
  validates the full World and commits using global writer fencing plus slot/run
  compare-and-swap.
- `settle_run(expected_slot, expected_revision, run_id, outcome, request_id)`
  atomically finishes the authoritative stored World, applies its derived receipt,
  archives it and increments both revisions. Only withdrawn/chapter1/victory
  are supported.
- `read_active()` reads the current registered active or archived run.
- `reacquire_and_read()` explicitly obtains the current lease and reloads the
  actual stored state; it does not replay a stale candidate.

A successful write extends the writer lease by 60 seconds within the same
transaction. There is no background heartbeat: after 60 seconds idle, or after
another writer takes over, the player must reload explicitly. A closed window's
lease is not forcibly stolen. A stable request ID makes a lost write response
retryable without repeating the committed action. Superseded operations fail
rather than reactivating an older run.

Native data is in `user://journeys-v1`, using the atomic-container implementation
with checksum, temporary file, backup and directory writer lock. Abandoned runs
retain identity and operation metadata, not whole map payloads. This bounds
per-step parsing growth without evicting identities or profile receipts. No
power-loss/fsync guarantee or automatic stale directory-lock removal is claimed.

Web uses IndexedDB `magic-tower-journeys-v1`. A single read-write transaction
updates the active slot and run. The callback bridge has a 12-second timeout;
late callbacks are ignored. A timed-out write may already have committed and
must be retried with the same request ID. Godot validates full World payloads;
the JavaScript layer also performs bounded structural and identity checks.

## Reproducible checks

`tests/test_session_storage.gd` runs 35 native checks including real Session
empty-start/create, full snapshot writes, response-loss retry, stale revisions,
failed rename, writer contention, replacement, legacy identity rejection,
lease renewal/expiry/reacquisition and bounded missing/late callbacks.

`tools/generate_session_bridge_fixtures.gd` generates actual current-schema new-run
and one-real-step payloads. `session_storage_harness.html` loads the production
JS through `session_storage_runtime.js`, not a fork of its implementation.
It requires a test-prefixed IndexedDB name and uses visible buttons for writes.
Its isolated self-test exercises the production JSON callback protocol without
WebGL. This is not by itself evidence that Godot's JavaScriptBridge runtime or
the exported game rendered successfully in a browser.

Measured native complete-world commit times after 10 and 100 created/replaced
runs were approximately 14–17 ms and 27–34 ms, respectively (three steps each,
5-floor active world). These are observations, not a worst-case guarantee for
4096 identities or larger worlds. Controlled injected failures are not actual
OS termination or power-loss tests.

Production browser verification: the final harness passed 14 real IndexedDB
checks in Chrome (isolated database suffix
`auto-b0be6079-1e11-4ca6-967c-95744263db9b`). Two actual same-origin tabs also
verified A's create/save/retry stayed at revision 1, B received WRITER_BUSY, and
B's read returned the complete same World. The test page and server were closed;
the test database was retained. This verifies the production JavaScript callback
protocol, not the Godot JavaScriptBridge/WebGL runtime.

The adapter and native container reject nonempty-ended-reason payloads on
ordinary writes. Archived reads require a valid ended World and an exactly
matching receipt in the validated profile. New risk runs require an explicit mode
choice; existing safe runs cannot be switched.

## Atomic settlement addition

All successful active and archived responses include the complete validated
profile ledger. Archived responses additionally include the exact receipt and
remain eligible (a terminal result, not an active playable run). Ordinary save
cannot seal or unseal a run. Native settlement uses World.restore/finish_run/
settlement_summary on the stored payload. Web preparation validates in Godot;
the IndexedDB transaction then requires exact full-base equality and allows only
the ended_reason change, derives the summary from its actual state and atomically
writes profile, receipt, archive, both revisions and operation metadata.

`tests/test_session_settlement.gd` passes 72 checks covering seven rollback points,
actual post-rename acknowledgement loss, repeated requests and restart recovery,
malformed operation metadata, damaged archive/receipt pairs, writer takeover,
and real legal K/Z routes. These are controlled failures, not power-loss tests.
Archived full snapshots are retained as evidence. The earlier 100-run timing
measurements apply to abandoned/tombstoned runs, NOT 100 archived full worlds;
no cheap-4096-archive performance claim is made.

The browser harness now additionally exercises five true IndexedDB abort points,
full-base comparison, ended-field-only restrictions, ledger-preserving new runs
and stale settlement replay. Its previous 14-check browser result is not evidence
for these new settlement checks; the expanded browser run must be recorded after
actual execution.

`tools/test_session_storage_protocol.mjs` additionally passes 39 pure checks
against the actual production JavaScript validation functions: exact operation
metadata, safe counter exhaustion, real K/Z summaries and corrupt receipt pairs.
The production counter limit is 10,000,000, matching native metadata validation;
no increment beyond that limit is written. This pure test does not exercise IDB.

Final production-browser settlement QA: 33 self-test checks passed in real Chrome,
including all five controlled transaction abort points and exact rollback, then
manual save/settle/duplicate followed by closing and reopening the test page
preserved the archived World, receipt and profile. Screenshots
`settlement-bridge-selftest.png` and `settlement-bridge-reopened.png`.
This supersedes the pending-browser note above, but does not certify Godot WebGL
or the engine's JavaScriptBridge runtime.

## Risk-mode fatal combat (schema 14)

New runs explicitly choose safe or risk; the mode cannot be switched through an
ordinary save. Active payloads in either mode must remain alive and unsealed.
`settle_death(expected_slot, expected_revision, run_id, delta, request_id)` is the
only fatal-encounter storage entry point. Native reconstructs the current full
World, executes `lethal_fight(delta)`, derives the `defeat` summary and atomically
archives it with its profile/receipt and both revision increments. Ordinary save
and generic finish cannot publish a dead run. Risk survivors can still retire,
finish chapter one, or finish the final victory normally.

Schema 13 production containers retain their existing identity, active/archive
status and receipt when read through World schema 14; no death record or award is
manufactured. Genuine old-code active/archive fixtures cover this transition.

Web receives the complete base and death candidate after Godot's validation and
combat replay. Its transaction compares the stored base exactly, verifies the
same adjacent target and death record, and permits only HP, moves, ended_reason,
death_record and actually applicable focus/armed changes. Enemy tiles, position,
gold, kills, equipment and all other fields must remain unchanged. It derives the
summary from the stored state/candidate, not a caller-provided reward summary.
JavaScript does **not** independently execute GDScript's combat formula; full
World restore/replay occurs in Godot before preparation and after reading the
result. This is transaction integrity, not an offline anti-cheat guarantee.

Death request retries preserve the original delta/CAS/nonce and return one
receipt. A changed delta conflicts; a newer run supersedes the old request.
Malformed death records fail native World replay and cannot be read as a valid
archive. The production browser harness includes a genuine 26-step risk-route
fixture plus a manually clickable death/retry/reopen flow; browser evidence must
be recorded separately from the pure validator tests.


Risk/death storage verification: `test_death_storage.gd` passes 63 checks,
including real no-injection seven-floor paths with and without an armed skill,
actual post-rename uncertainty, safe-mode rejection, normal risk survivor
settlement and authentic old production-container migration. Production JS pure
checks now total 59 (including fixture-isolation guards); static/failure-report
checks remain 17.

The final risk/death production bridge was executed in real Chrome: 55 automated
checks passed in test database suffix
`auto-5567d66b-ed1d-4954-b4e4-2db1b0888f5f`. In a separate manual test database,
claim → real 26-step risk fixture → fatal archive → duplicate retry → actual
close/reopen/read retained the death record, defeat receipt and profile. The
archived snapshot had 27 moves, HP 0, and retained its pre-fight 8 gold / 1 kill;
no target-kill reward was granted. Test pages/server were closed and the test
DBs retained. This validates production JavaScript/IndexedDB, not the Godot
WebGL/JavaScriptBridge runtime itself.


## Profile-backed strategy draft (schema 15)

Creation derives the complete birth pool from the authoritative stored profile,
not UI-provided unlocks. Reaching floors 3/5/8 enables the ordered 4/5/6-ID pools.
Offers are the first three IDs sorted by unsigned FNV-1a rank of UTF-8
`legacy-strategy-v1|<decimal seed>|<id>`, with ID ordering to resolve ties.
Native and production JS are checked against GDScript-generated vectors.

`choose_strategy(expected_slot, expected_revision, run_id, choice, request_id)`
locks one offered choice or `none` while the new run is still pending at zero
moves. It increments only run revision; slot, profile and gameplay resources are
unchanged. Lost acknowledgements reuse the same nonce and CAS. Old requests
cannot reactivate a replaced/tombstoned run. Ordinary save/Undo cannot change any
birth-pool, offer, revision or choice field. Pending runs may save only the exact
unchanged state; normal actions, retirement and fatal combat remain blocked until
the explicit choice. Explicit new-run replacement is still permitted.

Old schema-13/14 active and archived runs receive a revision-0 empty/no-choice
draft on read. They never receive a retroactive draw or new reward. Their original
IDs, death records and receipts remain authoritative. A run's saved birth pool
must remain within the current profile's entitlements; it is not expanded when
later milestones are earned.

`test_strategy_storage.gd` passes 35 checks, including authentic old14 migration,
profile-derived creation, aborted and repeated choice, pending/no-op boundaries,
immutable ordinary save/Undo, superseded requests and a real selected-Study
26-step risk route whose death is replay-validated with that strategy intact.
`test_strategy_storage_protocol.mjs` passes 473 comparisons of production JS ranks,
offers and drafts with the pure GDScript vectors. These do not claim that JS
executes Godot combat. The expanded real-browser draft harness is separate.

The expanded production callback harness was subsequently exercised in real
Chromium: 74 checks passed in `auto-a6ea663c-b606-4409-8da0-491799cff4d2`.
A separate manual `strategy-nativeqa` database used the actual chapter-one
fixture to unlock [3,5], created seed 51 with channel/forager/ambush_hunter,
locked channel, retried the same nonce without another revision, and retained
the complete draft and ledger after closing the tab and opening a new one.
This verifies production JavaScript and real IndexedDB, not the Godot WebGL
engine or JavaScriptBridge runtime.

## Schema 16 talent candidates and last surviving kill

New registered journeys carry a fixed `talent_draft` (version 1, three offers
per tier). The first two tiers independently rank their four-card pools with
FNV1a `talent-draft-v1|seed|tier|id`; the third retains its original three cards.
The native store validates the complete fresh World; production JS independently
checks the exact deterministic birth candidates. Ordinary saves and Undo cannot
change candidate version or offers. `last_kill_kind` is mutable gameplay state,
not a birth field. Atomic death retains it unchanged, along with the candidates;
it cannot turn an attempted lethal fight into a surviving kill.

Authentic schema 15 active and defeated containers from isolated commit
`cca5b73` retain their old three-card policy (version 0) and receive no inferred
kill history. The adapter continues to normalize and fully restore World before
publishing a response; it does not synthesize candidates from UI inputs. The
JS side remains a payload/transaction validator, not a second combat engine.
