# Full-world session storage (schema 13)

This is separate from the six-field profile prototype. The current game session
uses `scripts/session_storage.gd`, `journey_store_native.gd` and
`profile_storage_web.js`. Settlement, death rewards and legacy imports are not
exposed by this adapter. The old `journey-v4` file is untouched.

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
- `read_active()` reads the current registered run.
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

The adapter and native container reject both risk-mode and nonempty-ended-reason
payloads on write and read, even if otherwise valid under the World model.
Changing this deliberate batch boundary requires a future storage/session change.
