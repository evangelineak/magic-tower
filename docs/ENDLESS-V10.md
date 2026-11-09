# Endless v10: safe camp return and a fifth map family

New journeys use v10. Existing v1–v9 journeys retain their frozen rules; starting a new journey is explicit. Classic play remains separate.

## Less repetitive input, not teleportation

Press T or the safe-return button to return to an empty tile beside the current floor's merchant. The route uses only empty orthogonal tiles, never passing through resources, monsters, closed doors, stairs or interactions. It cannot cross floors. Unreachable camps, finished journeys and insufficient action-log capacity refuse without changes. Space still centres the viewport.

Every real U/D/L/R step remains in the replay. The entire preflighted walk saves atomically once; the visible position advances only after success. It cannot be cancelled partway once triggered. Save uncertainty leaves the previous visible world and requests verification rather than pretending success. The new `commit_walk` API accepts only the exact computed return route in the Godot/native validation layer; ordinary commits still require one action. Browser JavaScript checks protocol shape, prefix and CAS, not independent map legality. This is not an anti-cheat system.

## Real structural variation

A deterministic fifth family, branched channels, places a direct guarded west passage against a bent two-guard east passage between upper and lower courts. The treasure branch and relic enclosure remain sealed and have meaningful rewards. On even channel floors the camp is near the south-east entrance, and all camp-dependent UI locates its actual tile. Stairs retain paired coordinates. The channel name describes the geometry; this release does not add water mechanics.

Independent D4-canonical wall comparisons distinguish this family from rotations/reflections of all four previous families. Existing enemy, reward, growth and contract budgets remain unchanged.

## Verification

See [independent safety and geometry audit](benchmarks/ENDLESS-V10-SAFETY-AND-GEOMETRY.md): 384 maps across 48 seeds and eight depths, 6,145 checks; four legal 100-floor trajectories and their manual-step twins, 9,222 checks. Returning every floor is an audit workload, not a requirement imposed on players. The shortcut saved 668–1,056 directional inputs but retained all real walking and replay events. It does not make the economy balanced or prove unlimited-depth solvability.

Directed core: 4,206 checks. New UI: 35. Native storage: 330 ordinary plus 27 walk-specific. Node production storage: 364. Actual Chrome production JS, Web Locks, localStorage and second-context harness: 163 checks, restored test-origin data afterward.

Native manual play used legitimate new-journey seed 1354002840. On floor 1, collecting the key and defeating the direct guard left HP 140, attack 23, defence 12, gold 18, key 1 and kills 1. T returned from the lower court along 19 safe steps. The mouse button returned from beside the still-living alternate guard along five steps; reload preserved state. Opening the sealed treasure door required confirmation and consumed the key, then yielded 40 gold. A 10-step return preserved gold 58. Walking through the exit reached floor 2 at the same (13,13) stair coordinate. Its relocated camp accepted a one-step return to (13,12); reload retained resources. No position/stat injection was used.

Full regression and exact-commit CI are publication gates, verified separately. Godot Web-engine gameplay remains unverified in this cloud browser because WebGL is blocked; browser storage QA is not engine gameplay. Rankings are device-local; no global service, account, fee or player-data upload was created.

## Remaining work

This batch removes repeated input, not travel costs or all repetition. The measured economy is still generous. More distinct environmental interactions, richer enemy/hero identities and public ranking infrastructure remain future work, not completed claims.
