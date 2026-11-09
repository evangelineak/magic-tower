# Endless v7: distinct enemy timing, not recoloured stats

New runs use v7. Existing v1–v6 journeys retain their rules. Four map families still enforce paired stairs, two guarded routes and sealed worthwhile rooms. A seed/floor hash replaces some primary guards; it does not add mandatory fights.

## Two additional enemy identities

- **Intercept scout (`r`)** fires before the player. Brace and ward mitigate the first retaliation, not this opening shot. Even killing the scout in one hit can incur its opening damage.
- **Charged hammer guard (`c`)** doubles its first retaliation. Killing it in one hit avoids that retaliation; brace and ward can mitigate it within the actual damage limit.

Both are completely predictable. Hover text separates opening, ordinary retaliation, charged extra damage, stance/item mitigation and recovery. If an opening shot kills the player, displayed player rounds are zero and there are no later retaliations, kill rewards or healing. Consumables follow the existing actual-battle-only consumption rule.

Original flat art distinguishes a ready crossbow scout from a raised two-handed hammer silhouette. The six enemy identities were compared together at 24/40/64/128 pixels in the native contact-sheet scene. Battle results include a short explanation of the mechanic.

Example after entrance training: scout damage is 8 with Pierce, 4 with Brace, and net5 with Reap. Against a charged guard, Pierce can kill in one hit for 0 damage, compared with Brace4 and Reap net5. These are different tactical incentives, not elemental rock-paper-scissors.

## Verification

- Core: 21,321 checks, including 8 seeds × 2 routes × 32 floors of real actions, sequential budgets, complete replay, items, and opening-lethal behaviour.
- UI: 221 checks including actual adjacent-click fights against both new tokens and one-time result replay.
- Native seed993727743: restored v6, explicitly started v7, played normally to floor4. Floor2 scout inflicted 8 damage including opening4; floor4 charged guard inflicted8 including charged extra4. Reload preserved HP198/ATK32/DEF18/gold76/keys2/kills4. No injected resources or skipped floors.
- Real Chrome production storage: 97 checks across seven rule versions; full local regression: 75 Godot scripts plus Node protocol suites passed.
- New actor module: 10 actual drawing calls plus native six-enemy contact sheet.

## Important remaining balance problem

This batch does **not** fix infinite-run growth balance. The separate v6 audit (`benchmarks/ENDLESS-V6-BALANCE-AUDIT.md`) found legal permanent growth can flatten damage: free defensive training first reaches zero primary-route damage at floor6 and sustains it from floor8; the brace/twin-sentry policy is zero-loss from floor1 in the audited run. Basic per-floor supplies also exceed baseline route losses. New mechanics do not remove that numerical issue. A subsequent rule version must redesign long-run budgets and meaningful choices rather than mask the problem with arbitrary unavoidable damage.

Rankings remain device-local; no service/account/payment or player-data upload was created. Real-browser storage testing is distinct from the still-unverified Godot Web engine in the cloud WebGL-blocklisted browser.
