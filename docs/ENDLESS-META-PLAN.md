# Device-only reincarnation profile: deferred design

**Not implemented.** v20 is limited to heroes and finite focus. It retains envelope version1 and the four-field world DTO. Talent draws and reincarnation are a separate future batch, not promised v20 features. No accounts, network service, player uploads, credentials or charges are introduced by this plan.

## Current boundary

One native file (`user://endless-v1.json`) or one browser key (`magic-tower.endless.v1`) holds `{version,revision,run_id,active,finished,records}`. Native atomic replacement and the existing browser Web Lock serialize writes. Old world versions1–19 replay under frozen rules. v20 selects a hero through a single canonical first action and dedicated `start_hero`; ordinary `start` remains the old empty-log contract. A hero preview is not a saved new run until its CAS succeeds.

The current top10 is only a local convenience. Editing a save, executable or JavaScript can falsify it. Neither a local checksum nor a browser-side secret makes it a trustworthy global competition record.

## Prefer one envelope, not a second profile key

A later reincarnation batch should introduce a strictly validated **envelope version2**, preserving the old six fields and adding a bounded `device_profile` and a small last-operation receipt. Use the same file/key and lock. Never independently write points to another key after marking a run finished: a crash between those writes can lose or duplicate the reward.

Suggested profile: schema/version, available points, lifetime earned/spent counters, a bounded sorted whitelist of unlocked horizontal options, and the latest settlement receipt. All integers are bounded; reject unknown IDs, duplicate unlocks, unexpected fields and impossible negative balances. The catalog and costs must themselves have an explicit rules revision.

Read a valid envelope1 as an in-memory default profile without modifying its original world snapshot. On the first explicit successful transaction, serialize envelope2 atomically under CAS. Read-only access must not migrate. A failed quota/write/migration leaves the exact previous bytes and revision intact. Keep an explicit export/recovery path; never treat corruption as permission to initialize an empty profile. Future unsupported envelopes must fail closed rather than be reset. Older open clients should encounter incompatible save data and stop writing, not overwrite the new profile.

Do not retroactively award points from pre-meta runs or the top10. Old logs remain replayable, but did not commit to the new reward rules. The top10 can discard entries and is therefore never a settlement ledger.

## Replayable starts, independent of the current profile

A run's initial hero/talent loadout must be encoded in its frozen canonical action prefix (or in a separately versioned exact DTO if a future design explicitly changes the schema). Its replay cannot query whatever the device has unlocked today. Otherwise an old replay changes when the player unlocks something later.

For future talents, a deterministic draft may derive its offers from seed and fixed rules; canonical `pick_*` actions record the actual selection. No wall-clock random calls, hidden profile-dependent rerolls or arbitrary client-supplied stat dictionaries. The rules engine validates slot count, compatible choices and action ordering. The store separately validates that the current profile owns the requested options when creating the run.

These are different claims: a self-contained log proves what the rules would do; the profile enforces the normal local unlock UI. Neither proves that the player legitimately earned that profile on an untrusted device.

## API and transaction suggestions

Names below are proposals, not current APIs:

- `read()` returns snapshot, revision, records and a copied profile. It has no grant side effect.
- `unlock(option_id, expected_revision, request_id)` checks the fixed catalog, prerequisites and balance under the same lock, then subtracts points and adds ownership atomically. Already-owned options never charge again. A matching lost-ack receipt returns the saved result; the same request ID with different details is rejected.
- `begin_run(seed, hero, loadout, expected_revision, request_id)` verifies unlock ownership and creates the canonical initial prefix and new run ID in one CAS. Previewing cards does not modify the current save. Do not silently loosen old `start`/`start_hero` contracts.
- `settle(snapshot, expected_revision)` validates the actual ended world, derives reward from its frozen rule version, and atomically updates `finished`, local records, profile balance and settlement receipt. Never accept an arbitrary number of awarded points from the UI.

A crash after the final gameplay action is saved but before settlement is acceptable only as an explicit **pending settlement** state. Reading that ended current run should allow deterministic retry, and starting another run must not silently discard an unclaimed settlement. A combined final-action-and-settlement transaction is another option, but should be a dedicated API with exact one-action validation, not a generalized batch loophole.

Idempotence must survive the lost acknowledgement and process restart: same current run, same canonical ended snapshot, same rule version and same prior revision give the same receipt, with no second grant. A monotonic run ID and current `finished` plus a retained settlement receipt provide this independently of ranking retention. An old run cannot be submitted after a new one has started for another payment. Ordinary writes must preserve the profile; a stale tab cannot merge a stale balance over newer unlocks.

## Reward and choice policy still needs design

Prefer horizontal unlocks and bounded loadout slots over permanently escalating base attack/defense. Otherwise existing deterministic enemy and reward budgets become incomparable. Design the point formula before implementing persistence: which genuine progress milestones count, the per-run ceiling, and whether retirement earns the same progress as death. Awarding only for death may encourage intentional suicide; awarding on every start/early retirement creates trivial farming. These are gameplay decisions, not something storage should invent.

If death and retirement both pay, each uses the same earned-progress evidence and one settlement. Abandoning an unfinished run should have a clearly displayed policy, not a hidden grant. No real-money purchase, paid random draw or account-based entitlement is proposed.

## Verification requirements

Native, Node protocol and actual browser tests should cover: envelope1 reads without mutation; exact old-world replay; first successful upgrade; failed/quota write retention; two tabs competing to settle/unlock/start; repeated receipt after lost acknowledgement; same request ID with altered details; repeated settlement after a new run; finished run omitted from top10; negative/overflow/unknown fields; changed catalog prices; and recovery from a durable ended-but-unsettled run.

Godot validates full replay and derives the earned reward. The JS bridge must validate operation shape, allowed catalog identifiers, bounded deltas, CAS and receipts, but it does not independently execute the full Godot rules. Document this boundary; do not label bridge acceptance as server verification. UI updates current world/profile only after successful persistence and retains the prior display or a clearly pending state on failure.

For any eventual trusted global challenge, use standardized server-approved loadouts or a genuinely server-verified entitlement history, with rules/seed/season isolation and server replay. An imported local reincarnation balance is not proof. No global leaderboard service is implemented by this design.
