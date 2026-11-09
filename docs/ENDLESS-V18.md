# Endless v18: visible specialized vaults

v18 changes ordinary key-vault rewards, not combat, map geometry, key supply, bridges, or permanent growth. Rules 1–17 and their event histories remain frozen. The stone-cart courtyard in the separate proposal is future design only, not part of this release.

## Fixed, inspectable rewards

Each four-floor block deterministically shuffles one of each:

| Vault | Reward | Pickup condition |
|---|---|---|
| Treasury | 40 gold | Some room below the numerical gold ceiling |
| Infirmary | Directly heal up to 100 HP, capped at 180 | At least 1 missing HP |
| Ward store | 6 wards together | At least 6 free ward slots; current count ≤ 3 |
| Piercing store | 3 piercing tools together | At least 3 free piercing slots; current count ≤ 6 |

The shuffle advances a mixed state at each Fisher–Yates swap rather than using correlated linear salts independently. A fixed 10,000-seed regression checks all 24 orders and guards against the earlier first-floor skew; this is not a guarantee of uniformity for every seed range. Pre-release linear-salt candidate histories are superseded and must not be cited as final v18 replay evidence.

Contents are visible before opening the door. Opening still costs one key and requires confirmation. The confirmation gives actual healing and discarded excess, or held inventory and required capacity. A player may explicitly open a vault whose reward cannot currently be collected, leaving it for a later visit.

Adjacent movement into the chest collects it exactly once. A full-health infirmary, full numerical gold balance, or insufficient tool capacity causes no movement, event, partial reward, or chest consumption. Tools are all-or-nothing. Infirmary treatment is not a bottled medicine: at 150 HP it restores 30 and the other 70 is lost if the player chooses to take it now. Full-health players retain the chest instead.

A four-floor block always has each kind once; seed determines order. The manifest does not depend on current HP, money, inventory, build, visit order, or equipment. No rerolls, new inventory currency, or claim menu were added.

## Economy boundary

Over 100 complete floors, collecting all ordinary cash vaults yields exactly 1000 gold rather than v17's 4000. Other reward types are non-cash and cannot be sold through a new exchange. This does not prove that cash inflation is solved: existing bounties, low late-game damage, and abundant keys can still leave savings. A vault can reasonably be useless at the moment and worth revisiting later. Do not equate 100 nominal healing with 100 actual healing or a full tool bundle with immediately useful damage prevention.

The v17 special bridge remains: the island guard alone awards 22 gold and its chest gives two wards plus two piercing tools. Ordinary chargers still award 5. Its comparison text now tells the player to inspect this floor's ordinary vault rather than assuming every door contains 40 gold.

## Implementation

- `endless_world_v18.gd` extends frozen v17; no new generator or topology.
- `vault_kind(floor=-1)` returns `gold`, `medicine`, `ward`, or `pierce` using a deterministic four-entry shuffle.
- `vault_quote(target=Vector2i(12,3))` exposes kind, title, nominal and actual quantity, heal/gold/ward/pierce, allowed/reason, required tool spaces, availability, HP before/after, and excess healing.
- Door/chest `preview` includes this quote. Quotes are read-only and do not require proximity; actual pickup is still orthogonal movement.
- Confirmed door opening remains the existing direction-plus-`!` event. Chest pickup remains an ordinary direction event. There are no additional DTO fields or special pickup actions.
- Current-version `new_run`, `from_data`, `clone`, and route simulation retain v18 factories. Runtime reward state derives from seed and consumed-tile events, not persisted arbitrary reward payloads.

## Verification status

Core suite includes four-floor permutation checks across multiple seeds and depths up to the engine ceiling, exact controlled pickup/capacity/HP cases, zero-effect preservation, door confirmation for presently unusable rewards, clone identity, and all prior v17 battle/bridge economy boundary checks.

Eight real 100-floor no-vault histories (seeds 0/42, both routes, with/without preview-selected purchased tools) survive and replay. These show the baseline route is unchanged, not that every seed or policy is solvable. Their outcomes match v17 because none enters the changed vaults.

Independent cash/medicine/tool-vault policies and final counts belong to the v18 audit report after those runs complete. Headless checks are not evidence of native or browser visual acceptance; those must be recorded separately by the release coordinator.

Final core identity after shuffle correction: `618ad3a84706e25485bb9ff49a4b9a20a0f83a1ceb3510c0e1089407ef409f3f` (SHA-256 of `scripts/endless_world_v18.gd`). Core suite: 5411 checks passed, including the finite distribution regression and eight real 100-floor no-vault histories. Independent vault-policy results must match this identity, not the superseded linear-salt candidate.

## Final independent audit and native play

The final core hash is `618ad3a84706e25485bb9ff49a4b9a20a0f83a1ceb3510c0e1089407ef409f3f`. Independent 24-policy100-floor runs passed3672 checks for v18 and another3672 for the frozen v17 baseline, including exact inventory, consumed-tile and action replay. [Final data](benchmarks/endless-v18-final.json), [baseline](benchmarks/endless-v18-baseline17.json), [controlled boundaries](benchmarks/endless-v18-boundaries.json), [shuffle sample](benchmarks/endless-v18-distribution.json). The separate core suite passed5411 checks. Native storage802, walk315, Node1044 and actual Chrome production-storage531 checks passed; the browser result is not Godot Web-engine gameplay.

These policies are not optimal-player proofs. For seed42, no-vault main/alternate end with490/950 gold without gear. Cash-and-medicine policies end with1520/2010 gold; cloak variants1480/1970. Selectively using useful tools consumes36/51 on the main route and57/82 on the alternate route, but still ends with those same cash totals and180HP. The last25 floors of these vault policies have zero spending. The piercing-tool inventory can reach9. Thus free healing/tools replace purchases: recurring cash is lower, but late-game surplus and weak spending pressure remain unresolved. No enemies or prices secretly adapt to wealth.

Native play on the final hash used ordinary new-game UI, not injected state. Seed1718908052 showed a three-spike vault; cancelling the door kept the key, then confirming and adjacent-clicking the chest granted exactly three spikes and no money. Reload preserved them. Seed977610433 showed a medicine vault. Taking the existing healing lesson reached180HP; the door confirmation explicitly showed actual recovery0, and opening it did not consume the medicine. Adjacent clicking the full-health medicine refused pickup and displayed the return tag. A real16-damage scout fight reduced HP to164; walking back removed the tag, preview showed164→180 and84 unused healing, and clicking collected exactly16HP. Leaving/re-entering and reloading did not respawn the reward.

The four original flat vault silhouettes were also inspected in the native40/64/128px preview. Earlier cash/ward native checks used the pre-shuffle candidate and are not presented as final seed-identity evidence. Final aggregate tests and exact-commit CI are separate release gates. The physical stone-cart courtyard remains a design proposal, not an implemented event. Global rankings remain device-local only.
