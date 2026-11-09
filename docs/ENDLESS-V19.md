# Endless v19: stone-cart courtyard

Status: implemented and verified locally; public-page deployment is pending. The live `BUILD.txt`, not this source document, identifies the publicly playable version.

## Scope and appearance

This is a small, early-game physical exploration event, not a solution to deep-floor repetition. Each seed selects at most one non-bridge floor in [3,5] and one in [9,11]. If both candidates in a window already belong to the frozen bridge family, that window is skipped. Therefore a run has **zero to two** courtyards. Existing bridge maps are never overlaid or reinterpreted.

All other floors use the exact v16 geometry still used by v18. Combat, rune prices/effects, equipment, v18's four-type ordinary vaults, and old version 1–18 saves retain their established rules. The courtyard introduces no additional permanent-stat cap, cash exchange, or reward currency.

## Physical puzzle

The player pushes one stone cart by walking orthogonally into it. Each legal push consumes one ordinary movement event. The cart may move only within the visibly bounded 4×4 track board, excluding its stone pillar. The player may stand on ordinary ground outside the track to push; the cart cannot leave the rails. Empty sockets are walkable, and the original cart square becomes empty when it moves away. Safe automatic walking never pushes the cart, fights a monster, or claims a cache.

- First window: cart origin (7,6), pillar (7,5). The supply solution is left, left, up; archive is left, up, up. Both require three pushes and repositioning behind the turn.
- Second window: origin (7,7), pillar (6,6). Supply is up, up, left, left; archive is up, up, up, left. Both require four pushes. This changes the actual obstruction and pushing position, not merely colors or mirrored artwork.
- Supply socket (5,5) opens gate (5,3), leading through (5,2) to supply cache (5,1).
- Archive socket (6,4) opens gate (8,3), followed by a real strong guardian at (8,2) and relic at (8,1).
- Reset station (4,7) works only from an orthogonally adjacent position. Before claiming a reward, it freely restores the cart to its variant's origin. It does not respawn enemies, restore spent resources, or duplicate rewards. A no-op reset, occupied origin, remote reset, ended run, action-limit exhaustion, or already claimed reward is refused without recording an event.

The whole causal arrangement fits within the event camera focus rectangle (3,0,11,11), including both reward rooms, track, and reset. Native interaction/readability acceptance has now been performed as described below; it is separate from headless proofs and does not establish Godot Web-engine acceptance.

## Shared reward and deliberate revisits

There is one shared reward opportunity per courtyard:

- Supply: one ward and one piercing tool. Both inventories need one free slot; no partial pickup.
- Archive: the existing relic formula, with the actual remaining attack/defense budget, relic-level capacity, and up-to-50 healing. The strong guardian uses normal deterministic combat and pays the ordinary v17+ strong-guardian bounty of 18 gold on a real victory. It is not silently weakened to fit an early arrival.

Adjacent movement into either cache first asks for confirmation, stating that the other reward will be forfeited. A confirmed claim fixes the cart in place, permanently latches the selected gate open for escape, and locks the other gate. The forfeited reward remains visibly behind that locked gate and is permanently unavailable; it is not claimed to disappear visually. A full tool inventory or relic with all four gains zero does not consume a cache or lock the shared choice. Players can leave and return when a reward becomes useful.

The archive can be inspected before it can be beaten. Real tests grew to floor 20 and returned to the early archives; growth only to floor 12 was not enough to guarantee survival against the later-window guardian. This is an intentional visible risk, not a claimed universal budget witness. Killing the guardian and then resetting or choosing supply is allowed: the dead guardian stays dead and its bounty is not paid twice.

Revisiting has real walking cost. No new teleport, cross-floor shortcut, or reduced event count is introduced. Existing same-floor safe return to camp still expands and records every actual movement. The event does not guarantee that a long return trip is worthwhile when the player already has full budgets and supplies.

## Geometry and the entrance correction

The dedicated 15×15 family retains paired stairs (1,1)/(13,13), ordinary door (10,3) and its v18 cache (12,3), original strong guardian (10,10) and relic (12,10). The separating wall lies on row 9:

- Main route: guardian at (3,9).
- Alternate route: guardians at (6,9) and (6,10); walls at (5,10)/(7,10) prevent bypassing the second.

The puzzle cannot bypass these guards or either ordinary reward gate. Conditional reward rooms are intentionally sealed until their socket opens them; no island-repair pass carves an accidental shortcut.

An early candidate had M at (2,2) and S at (3,2), which trapped the player in the training/supply top-row pocket unless they stepped back onto a stair and changed floors. Pure spatial connectivity incorrectly treated that stair as ordinary floor. The final layout moves S to **(2,4)**, clears (3,2), and leaves M/key unchanged. Validation now explicitly proves that the supply exit (3,1) reaches the outside safe area and station neighbors **without traversing either stair**. Real movement histories exercise this correction; tests do not fake a same-floor turn on a stair.

## Implementation and replay

- `endless_generation_v19.gd`: `cart_floors`, `has_cart`, `cart_manifest`, `skill_position`, explicit routes/contract, authored geometry and validation.
- `endless_world_v19.gd`: current-version factories and route simulator, explicit v19 map/contract selection, cached immutable current-floor manifest, cart overlay and interactions.
- `cart_view()` returns track, origin/current position, sockets, open/locked gates, reward quotes, reset eligibility, current push eligibility, guardian and focus rectangle. Returned mutable collections are copied; callers cannot edit the cached manifest.
- `cart_reward_quote(side)` exposes actual capacity/capped relic gains. `cart_push_quote(delta)` exposes legal current-player pushes and refusal reasons.
- Runtime `carts[floor] = {pos, claim}` is derived only from replay, cloned deeply, and never accepted as arbitrary saved data.
- DTO remains exactly `version/mode/seed/actions`. Legal pushes log U/D/L/R. Reset logs `cart_reset`. Confirmed cache claims log the direction plus `!`. Unconfirmed reward records and gratuitous confirmations cannot be replayed as valid actions.
- The discarded archive guardian is excluded from the justification for buying a rune after a supply claim. It cannot justify charging for an effect on permanently unreachable combat.

## Evidence boundaries

Core checks include authored geometry, unchanged non-event maps, controlled capacity/zero-gain/death boundaries, reset and gate state, clone/view isolation, and earned floor-20 return histories with real movement, guardian combat, re-selection before claiming, and full event replay. Eight real 100-floor no-event-claim policies preserve baseline progression and resource results. Controlled fixtures are not presented as earned growth histories.

The production generator validates fixed geometry/metadata, static gate configurations, route and reward cuts, potential floor connectivity and entry-side station access. It does **not** claim to enumerate every moving-cart state. That stronger check is supplied by the separate independent state-graph audit, which includes player connectivity, cart position, claim state and living/dead archive guardian. Independent resource journeys and protocol audits are likewise recorded separately.

Passing these tests establishes specific safety and replay contracts. It does not establish that every seed/build is solvable, every reward is attractive at every point, or that this limited puzzle resolves long-run repetition.

## Independent acceptance and reproducible evidence

Audited frozen identities:

- World SHA-256: `283e2fc26462911404efdeecd1b2fdcbdb5891388a9b7eeb818a2b9b29260023`.
- Generator SHA-256: `0b496bd2add0d54b71fa071d0e20165dbc9717b2d3b6c8297de56fa2d290e248`.

`bash tools/test_endless_cart_contracts.sh` exports actual generated maps, crosses them against an independently authored ASCII contract, enumerates the independent cart/player/claim/guardian graph, runs legal resource histories, and commits those histories one action at a time through the production native store. It fails on process errors, `SCRIPT ERROR`, `ERROR`, missing/duplicate structured results, or reported failures. Final measured wall time was **16.672 seconds on this local machine**, not a CI or browser performance guarantee.

- **122 generated event maps**, each checked against the correct independent variant; **33 reachable spatial equivalence states per variant**. Both minimum solutions are three pushes in variant 1 and four in variant 2. All states preserve escape and original guard/door cuts; unclaimed states can reach the real adjacent reset station. The entrance training/supply pocket is checked without treating either stair as ordinary traversable floor. This spatial abstraction assumes a guardian fight can be won and a reward has usable capacity; resource tests are separate.
- **127 independent resource checks**: legal grown return histories cover both variants and rewards, failed pushes, reset without moving the player, confirmation cancellation/no mutation, latch/escape, dead guardian remaining dead after switching to supply, and replay. Capacity, zero-gain, invalid origin occupancy, and forced adjacency to the forfeited reward are explicitly controlled fixtures, not purported earned histories.
- **4 complete legal histories, 4,164 native-store checks**: real temporary-file writes, ordinary single-action CAS commits, a fresh store read, and exact normalized replay of cart state, items, HP and map deltas. JSON numeric representation is normalized before dictionary comparison; the initial raw float/int comparison failure was a test issue, not lost state.
- Version protocol: native **879**, safe-walk **360**, production Node storage **1,156**. A separately operated real Chrome harness passed **595** callback/WebLocks/localStorage/second-context checks. This harness is **not** a Godot Web-engine playtest.

The release coordinator also ran the final aggregate gate: **107 Godot suites plus Node and the cart contract gate**, exit0, with no `SCRIPT ERROR` or `ERROR` in `/tmp/endless-v19-final.log`. The frozen world/generator hashes above were unchanged. This is test acceptance, not publication confirmation.

Artifacts: [state graph](benchmarks/endless-v19-space.json), [resource histories](benchmarks/endless-v19-independent.json), [native persistence](benchmarks/endless-v19-native-store.json), [legal 100-floor journeys](benchmarks/endless-v19-journeys.json), and [contract gate log](benchmarks/endless-v19-contract-gate.txt).

## Legal journey and actual revisit cost

The independent 12-policy sample used seeds 0/42, primary/alternate routes, and skip/supply/archive policies. All completed 100 floors and replayed exactly (**1,904 checks**), with floor-50 and floor-100 states retained in the raw rows. It used capped training/tactics and an ordinary potion policy, no ordinary key-vault rewards, purchased equipment, or runes. Event policies physically returned after clearing floor 12 and visited the earlier archive first; no teleport or injected growth was used.

At first sight on floor 3, seed 0 had HP164/153 against predicted damage339; seed42 had HP166/155 against damage345. The archive was genuinely unsafe then. The later event could already be survivable in these builds. After 12 growth packages and first claiming the earlier relic, seed0's floor11 guardian caused **53/60** damage, leaving HP127/126 before the second relic healed50. This does not contradict a different build needing longer growth: the order and first reward matter, and floor12 is not a universal safe-return guarantee.

For seed42, taking supply after this return trip added **506/502 actual recorded events** to primary/alternate runs versus skipping, ending at the same HP and gold with two wards and two piercing tools acquired across the two events. Those tools were not used by this policy, so unchanged HP does not establish that the reward is worthless. The archive policy added **502/484 events**, ended at HP136/176 and gold556/1016 versus skipping HP178/145 and gold490/950. These are different resource outcomes, not a claim that one choice dominates. The measured on-floor event portions took 34–46 events, including positioning and walking to/from the puzzle; the hundreds of additional events include real cross-floor backtracking.

The at-most-two early events do not solve deep-floor repetition, abundant resources, or the lack of an integrated endless-mode hero/reincarnation loop.

## Actual native play acceptance

The release coordinator played a real native run with seed **1165695190**, progressing normally from floor1 to floor5, its first courtyard:

1. A far click caused no action or automatic push. `LLU` opened supply, followed by a free reset; `LUU` opened the archive.
2. An actual adjacent click on the archive guardian fought it: **HP170→41 (129 damage), gold21→39, kills4→5**. The guardian was not weakened or replaced by a test fixture.
3. Resetting did not respawn it. The player switched to supply with `LLU`, canceled the first claim confirmation, then accepted one ward and one piercing tool. The opposite archive remained visible but locked and forfeited; further reset was refused.
4. A real native stop/restart and return to the mode (F8/F5/F3 in that test) restored **HP41, gold39, keys5, kills5, position(4,6)** and the exact cart/gate state.

This verifies that specific native interaction/save flow. Publication is still pending at this document's update, and cloud Chrome's WebGL limitation still prevents claiming equivalent Godot Web-engine play/reload acceptance.
