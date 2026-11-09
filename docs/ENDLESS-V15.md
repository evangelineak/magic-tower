# Endless v15: repair the old floor families, keep their rewards

New journeys use v15; v1–v14 logs keep their original rules. This batch fixes known geometry problems rather than adding more menus, prices or combat systems.

## Connected space and an entrance-side camp

Previously documented isolated decorative floor cells are retained and connected by the least-cost eligible straight passage. Each candidate is checked against the existing required-guard and valuable-door cut rules before acceptance. A candidate that bypasses a guard or treasure gate is rejected. If no safe connection exists, generation reports failure rather than silently reverting to the old bad map. Original rewards, keys, training, supplies, enemies and stair coordinates remain intact; the fix does not turn inconvenient empty floor into walls to hide it.

Camps and skill stations now sit on the current floor's entrance side: odd floorsM(2,2)/S(3,2), even floorsM(12,12)/S(11,12). Old station cells become ordinary floor. New validation requires every non-wall cell to be connected and both station interaction positions to be reachable without battle or a key door. Combat, equipment, inscriptions, prices and the six families remain otherwise unchanged.

## Native play

The old v14 journey restored HP130/gold47/kills2 unchanged. A legitimate random v15 journey, seed1884743680, generated the old causeway family. Normal training and supplies gave HP158/attack23/defence12. The player walked through the new side passage to formerly isolated(13,5), then safely returned without paying or fighting. The required priest still cost the predicted8HP and awarded24 gold; no new passage bypassed the main gate.

Climbing at(13,13) entered the second-floor bastions family at the paired coordinate. Its relocated camp was immediately reachable by stepping up and interacting left, before any floor2 battle. Buying medicine charged15 gold and restored the displayed30HP, reaching HP180/gold9/key1/kills1; reload preserved both state and station location. The camp paving followed the actual new position.

## Verification and limits

Core15778 checks plus a separate1024-case large-seed/depth generation stress sample passed. Independent512-map130930 assertions now enforce all-cell connectedness and entrance-side station access for every family: the old458 isolated-floor and114 unsafe-station diagnostic exemptions are gone. Per-cell old/new comparison checks that original floor and rewards were not erased. Twelve legal100-floor journeys6810 checks passed with full replay, and16 actual headless journeys reached floor2 for670 UI/geometry integration checks. Native storage595, atomic safe-walk192 and Node744 checks passed. Actual Chrome production localStorage/Web Locks/callback/second-context363 checks passed, restoring test-origin data. Final aggregate/publication checks are recorded separately.

The same independent route policy also walked less: seed42 unequipped main route3584→2985 recorded events, alternate3371→2885. These are genuine movement/action reductions, not compressed logs or a claim about every player's time. [Audit and raw evidence](benchmarks/ENDLESS-V15-CONNECTIVITY-AUDIT.md).

No new economy balance is claimed; gold remains generous. A [two-arm bridge design](OPTIONAL-BRIDGE-DESIGN.md) is explicitly an unimplemented future proposal, not playable content. [Global leaderboard options](GLOBAL-LEADERBOARD-OPTIONS.md) document researched infrastructure constraints, not a deployed service. Rankings remain device-local; no account, backend, credential, fee or player upload was created.

Godot Web-engine play remains unverified in the cloud WebGL-blocklisted browser. Browser storage testing is not engine play. The sampled tests are not a proof over every possible seed and depth.
