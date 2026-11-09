# Endless v22: the paired floodgate court

## What changes

This is functional water terrain, not a blue wall, an elemental damage chart, or another reward menu. One pool is drained and walkable while the other is deep and impassable. Players cross the first pool to a permanently dry island, turn the connected valve there, and cross the other pool. The dry main route remains available without operating any valve.

The existing strong guardian and relic have moved into a sealed room on the island. No additional relic, cash, key or consumable reward was added. That gives the water route a visible goal: approach the old guardian, judge the forecast, retreat if unready, then return after growing stronger. The main route still requires one guardian; the water route requires both its bank guardians. Extra kills, their existing bounties and talent progress have their existing costs. The water route is not claimed to be always more profitable.

Combat remains the frozen v21 implementation, including heroes, talents, legacy exchanges, runes, equipment and consumables. v22 does not retune enemy damage or add water combat modifiers. Old rules 1–21 remain frozen.

## Appearance and two shapes

Each eight-depth block chooses one of floors 4/6, then 12/14, 20/22, and so on by seed. Thus the first ten floors contain an encounter, unlike a late rare event that most players never see. All water floors are even, naturally avoiding odd-floor bridge and cart events. Every non-water floor uses the existing v19 generation result unchanged.

- Variant 0 has two continuous 3×2 pools. Bank guardians are at (7,4)/(7,10); crossing from a guardian to the nearest island edge takes three movement steps once drained.
- Variant 1 moves the north guardian to (6,4), the south to (8,10), and inserts permanent rocks at (6,6)/(7,6)/(7,8)/(8,8). Each pool becomes a connected four-cell bent passage, requiring five steps between its guardian and the island edge. This changes actual routes and positions, not only colors.

Both use entry (13,13) and exit (1,1), paired with adjacent floors. Training is at (12,13), supply (11,13), merchant (12,12), course (11,12), and the key (11,11), all on the safe entry bank. The ordinary keyed vault remains D(10,3) → cache(12,3). Its v18–v21 reward and legacy rules are unchanged.

The dry main guardian is at (3,7). The island is (6..9,7). Its strong guardian at (10,7) is the only entrance to the relic at (12,7); walls above, below and at its far end prevent a bypass. The old lower-bank relic room is not duplicated.

## Water state and safe retreat

State 0 means north drained / south deep. State 1 means south drained / north deep. Initial state is seeded and stable. Three connected valve stations are at (5,3), (5,7), (5,11). All operable adjacent positions are permanently dry; neither the player nor a monster, item or NPC can be submerged by a legitimate turn.

The player must stand orthogonally adjacent to a valve. Turning is free and reversible, but records one action. It does not clear monsters, heal, refund keys, grant focus, duplicate a reward or change a seeded offer. A repeated request for the current state records nothing. Remote, ended, uninitialized or action-limit-exhausted requests are refused.

On the island the player can always restore the route just used. If the next bank guardian or island guardian cannot be beaten, the already cleared approach is still a real way back. Reversibility is intentional; the tradeoff comes from route length, battles and the relic opportunity, not a surprise irreversible trap or drowning timer.

Deep water explicitly refuses movement without charging HP or another resource. Drained cells return ordinary `.` for navigation. Their shallow-water appearance comes from terrain metadata, so they do not become visually indistinguishable empty tiles. Safe click walking and same-floor camp return do not turn valves automatically. A successful turn invalidates any old planned walk, which must be recalculated for the new terrain.

## API and replay

- `endless_generation_v22.gd`: `is_water(seed,floor)`, `water_manifest`, `state_grid(seed,floor,state)` and `validate`. The manifest contains both pool-cell arrays, controls, island, four guardians, relic, entry/exit, variant and seeded initial state.
- `endless_world_v22.gd`: current-version factories, clone, explicit map/route/contract selection, water overlay, cached immutable manifest and read-only `water_view`.
- `water_view` adds current state, each pool's `dry`/`deep` status, availability/reason, and the next canonical action. Returned collections are copied.
- `water_north` sets state 0; `water_south` sets state 1. `water_turn` is only a convenient live UI alias and records the resulting explicit action. Saved histories reject the alias itself. Setting the current state is a no-op.
- `~` is the impassable deep-water token; `F` is an adjacent-use station, never a walk-through tile. No new choice screen is necessary.
- Runtime `water_states[floor]` is derived from actions and deep-copied by clone. The saved DTO still has exactly `version/mode/seed/actions`, with the same hero/legacy starting prefix and profile rules as v21.

The new route summary and order manifest use the actual bank-guardian coordinates and v22 simulation factory. Water-level changes do not silently replace the saved world with a v21 clone. Existing safe camp-return validation still checks every expanded movement against the current terrain.

## Validation and evidence boundaries

Production validation checks exact authored geometry/metadata, both water states, dynamic valve edges, no zero-battle crossing, the one-guardian dry route, both required water guardians, keyed-vault isolation and the island guardian cut. It also checks entry supply/key escape without treating stairs as reusable same-floor shortcuts, and all potential non-stair walkable cells in both states when guards/doors are considered cleared. These are spatial contracts, not a claim that any arbitrary build can win each battle.

The independent audit separately enumerates reachable player components, water state, four cleared-guardian bits and the door state, using its own maps rather than the production validator. It explicitly treats stairs as terminal transitions. This is distinct from merely flood-filling two static maps.

Core tests exercise actual blocked-water movement, same-state refusal, alias normalization, remote refusal, safe retreat, cloned state, and complete replay. An earned journey approaches the first island, leaves an unready guardian without spending or dying, grows to floor 20, returns, defeats it and collects the single original relic. Eight actual 100-floor policies cover two seeds, dry/water route choices and no-talent/first-offer builds, with real valve events on the water route. These samples do not establish every seed/build as solvable or optimal.

Native visual play, browser-engine acceptance, persistent-profile/CAS checks and battle-effect feedback are separate release evidence. More terrain interaction does not by itself solve long-run wealth surplus, prove stronger combat balance, or complete every original game idea.

## Final seed-mixing regression

Before release, an independent sample exposed correlation between the layout variant and initial water level when their hashes differed only by linear salts. The final initial-state calculation adds a third mix: `mix(mix(mix(seed,floor,4637),floor,113),floor,151) % 2`. Appearance and authored geometry are unchanged. Earlier candidate-v22 histories/evidence are not treated as a released compatibility contract; versions 1–21 remain untouched.

The independent export samples 10,000 seeds over four actual water floors each and checks all four `(variant, initial_state)` cells against a deliberately broad 9,000–11,000 range. This is a finite deterministic distribution regression, not proof of true randomness or independence for every seed range.

After the change, the core suite was rerun: **5,291 checks, zero failures**, including all eight real 100-floor policies and full replay. Conditional assertion counts differ slightly with initial states. Final generator SHA-256: `ba8f12fa2be869302e96fbb8838ae83b1cae6e37355435f849e7203e447c998c`; unchanged world SHA-256: `8d0e938ac74d1c0db41d3468ea9ce9957699cef813dd6e31f92aee2d8d7a136c`.

## Native and browser acceptance

A real desktop run used seed `172433723`, Warden, no legacy, from a new journey through floor 6 with ordinary training, supplies, five main-route battles and one finite shrine heal. On the bent-reef water floor, HP171/ATK38/DEF22 before the south guardian became HP155 with the displayed 16 damage; the enemy was not respawned. Mouse-adjacent shore turning drained the southern pool without changing resources. Safe click walking crossed the exposed bent pool into the island. Keyboard-adjacent turning flooded the return pool; attempting to enter deep water was refused and camp return became unavailable. The island relic preview showed its benefits while the guardian forecast showed lethal 162 damage against HP155. Clicking requested fatal-combat confirmation; cancelling preserved the run and reward. Restoring the southern route reopened safe camp return. An actual process restart restored island position, water state, HP155, gold31, key1 and six kills; T then followed the ten cleared cells to camp without further battle or reward. These checks used the final generator and no injected stats or position. This is native play, not Godot Web play.

The actual Chrome storage harness passed **893 checks**, covering production JavaScript callbacks, Web Locks, localStorage and a second browsing context, then restoring the pre-test data. The independent cross-version storage suite passed **336 native + 319 JavaScript checks**. This does not establish WebGL engine acceptance or trustworthy global rankings.

The independent final water gate exported 128 maps, checked all four layout/initial-state classes from both staircase directions, rejected eight broken-map mutants and replayed four earned journeys with **825 checks**. Its actual 40,000 manifest calls produced `(00,01,10,11) = (10012,9994,9986,10008)`.
