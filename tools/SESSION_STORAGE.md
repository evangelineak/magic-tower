# Full-world session storage (schema 13)

This is separate from the six-field profile prototype. The current game session
uses `scripts/session_storage.gd`, `journey_store_native.gd` and
`profile_storage_web.js`. Atomic safe-mode retirement/chapter/final-victory settlement is exposed; death
rewards and legacy imports are not. The old `journey-v4` file is untouched.

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

`tools/generate_session_bridge_fixtures.gd` generates actual schema-13 new-run
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

The adapter and native container reject risk-mode and reject nonempty-ended-reason
payloads on ordinary writes. Archived reads require a valid ended World and an exactly
matching receipt in the validated profile. Risk mode remains unsupported.

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
