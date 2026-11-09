# v18 proposal: physical exploration and visible vault contents

Status: historical proposal. The cart courtyard is deferred and unimplemented. The vault proposal was selected with different final quantities: gold40 / direct healing100 / wards6 / piercing3, one of each per four floors. See ENDLESS-V18.md for the actual implementation contract. The candidate quantities and tests below describe the earlier proposal, not the released rules. Versions 1–17 stay frozen.

## Recommended event: the stone-hauling courtyard

A rare, optional side courtyard contains one movable stone cart, two visible pressure sockets, two wired gates, and a shared cache mechanism. The player sees the full local board, wires, guardians, and exact rewards before acting. This is a spatial puzzle rather than a new purchase menu or another choose-left/right prompt.

- Push the cart from an orthogonally adjacent tile. Ordinary safe walking never pushes it. A cart cannot move through an actor, item, wall, door, stair, or player.
- One socket opens a short unguarded supply recess: one ward and one piercing tool. The other opens a visibly guarded archive with one existing relic reward. No extra permanent-stat system is introduced.
- The two sockets cannot be occupied together. Moving the cart changes which gate is open. Until a reward is claimed, an adjacent reset winch freely returns the cart to its marked origin. Reset cannot damage, trap, or move the player.
- Claiming either reward spends the shared cache opportunity exactly once; the alternative is explicitly forfeited. Confirm this at the cache, not at every push. The selected gate then latches open, preserving a safe way out. The cart becomes fixed rather than being reset under a player.
- The guardian is not auto-fought. A player may solve the archive route, inspect its battle preview, leave, grow, and revisit. A consumed guardian stays consumed. Killing it alone does not create another cache reward.
- Relic pickup uses v17 actual-gain preview. If all four gains are zero, do not consume the relic or commit the exclusive choice. A full tool inventory likewise preserves the supply cache.

The normal two combat routes, ordinary key vault, strong-enemy relic room, paired stairs, and safe entry camp are outside the event pocket. The event may not bypass any existing guard or reward gate. Do not graft it into every family: first make one dedicated family with enough space. Fit the board before promising a frequency. The local board should have two seed variants with different push sequences, not only mirrored artwork.

### Readability and limits

Original flat artwork: stone block with push handles, outlined floor rails, two distinct socket shapes, visible cables, gate bars, and a shared sealed chest emblem. Hover explains the current legal push and why a blocked push fails. No letters as interaction art. No timer, hidden roll, step damage, or interest punishing exploration. No new hotkey/menu is required.

This event risks being too similar to the existing twin bridge unless the board genuinely requires positioning behind the cart and choosing a push sequence. Reject a trivial one-push binary fork. Conversely reject a long Sokoban puzzle that obstructs the main game: target 3–6 deliberate pushes, optional and resettable.

## Economic diagnosis

Verified source: v1 pickup gives $ +40; current generators supply one free k per floor and preserve a genuine D cut to that cache. v17 ordinary bounties are 3–6, optional V 18, special bridge guard 22. Existing independent v17 audit shows exactly +4000 gold for visiting all 100 ordinary vaults, with no additional vault combat. Medicines really heal up to 50 for 15 gold; a smaller observed gain is the 180 HP cap, not a 30-point potion bug.

Thus the large vault income is not a reward for a scarce key decision on most floors. Keys can be saved, spent on rare bridges, exchanged in encounters, and supplemented by other finite rewards, but ordinary one-key-per-floor delivery largely funds one door per floor. Merely increasing potion prices would tax everyone while leaving the vault loop dominant. Removing doors or secretly emptying chests would violate their purpose.

## Suggested economic candidate: visible specialized vaults

Keep the paid door and its closed-room proof on every floor. Change only the contents in v18:

- Each block of four floors has a deterministic seeded permutation of one treasury, one infirmary cache, and two tool caches.
- Treasury: the existing 40 gold.
- Infirmary: up to 50 HP, actual gain shown, zero-gain pickup refused and cache retained for a later visit.
- Tool cache: one ward plus one piercing tool, capacity checked atomically; full inventory retains the cache.
- Contents and current usefulness are visible before paying the key; no blind chest or reroll. The floor's immutable manifest records its type. Do not change ordinary free key supply in the same experiment.

For 100 complete floors the ordinary treasury contribution becomes exactly 1000 gold instead of 4000, before all other sources. This is a budget bound, NOT a tested survival result or a claim that total inflation ends. Non-cash caches retain real value when injured or using tools, and may reasonably be skipped at full resources. Keys then have more contextual value against a bridge or exchange, though continued abundant keys remain a limitation. A gold-maximizer can open only the 25 treasuries; opening all doors must not be framed as required play.

This candidate reduces 75% of recurring door cash without increasing unavoidable battle damage, taxing every step, or adapting prices to wealth. It also reduces unconditional purchasing power, so actual no-vault strategies must still be audited. Compare against the existing v17 baseline before approving final rules. Do not simultaneously reduce key supply, add a paid gate, and change bounties; that would conceal which change causes failure.

## Required tests before implementation approval becomes release approval

1. Independent local-state graph search over cart position, player reachability, sockets, and claimed reward proves both solutions, a safe reset, and no stranded player. Test every reachable state, not only the intended solution.
2. Every main guard and D/V cut still holds with either event gate open, cart on any legal square, and either claim latched. Stairs/camp unchanged; unreachable optional rooms are declared, not silently connected by the v15 island repair.
3. Exclusive reward is once-only across moving cart, reset, revisits, saving, quitting, confirmed death, and retirement. Reject malformed or unconfirmed irreversible events. Four-field deterministic replay remains authoritative.
4. No action or item is consumed on blocked pushes, failed resets, full inventory, full-health cache, or zero-benefit relic. Safe paths never push the cart or activate mechanisms.
5. For each four-floor block, exactly one cash cache; generated type cannot change when revisiting, changing equipment, or holding more money. Both floor orientations preserve the actual door cut.
6. Real seed 0/42 and wider samples: 50/100 floors, primary/alternate routes, none/cloak/lens, no doors/cash-only/useful caches, with tool and medicine policies. Record deaths honestly, cash sources separately, keys held/spent, tool use, HP gained/wasted, physical detour actions, and last-25-floor budgets. No-vault viable policies must remain; all-cache policy need not dominate.

## Counterexamples to guard against

- A cart moved off a socket closes the only exit while the player is inside: forbid this topology, do not rely on a rescue menu.
- Player takes the supply, resets, then takes the relic: shared claim must permanently exclude it, including after replay.
- A full-health player pays a key for a supposedly valuable medicine cache and it vanishes for zero healing: display actual gain before opening, and retain the reward until useful.

Recommendation: approve the small physical event and the specialized-vault economic experiment separately. If board fit or visual clarity fails, ship neither under a claim of completed map variety; do not replace it with another abstract modal choice.
