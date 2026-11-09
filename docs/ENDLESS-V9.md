# Endless v9: optional route orders and discounted supplies

New journeys use v9; existing v1–v8 journeys keep their rules. This batch adds an optional economic/quest loop, **not new geometry, enemy types, permanent stats, or a claim that the long-run economy is fully balanced**.

## One camp opportunity, two ways to buy

Open R, then choose the route-order tab with the mouse or Tab. The existing camp encounter remains separate.

- Buy one ward for12 gold or one piercing spike for18 gold immediately; this uses the floor's order opportunity.
- Alternatively, deposit12 gold before killing any designated route guard. The seed/floor fixes the target and quantity. Clear that route and return to that floor's merchant to recover the12 deposit. Then optionally spend8 gold for one item on a single-guard order or two items on a double-guard order. Choose wards or spikes, or decline without further cost.
- Refunding is independent of inventory capacity; full inventory preserves the exchange opportunity. Insufficient money or space never partially charges. Only one global order can be outstanding, including an unspent exchange opportunity.
- There is no timer or walking interest. Cancelling an unfinished order loses the12 deposit and requires confirmation. Ending the journey loses any unreturned deposit. Viewing or dismissing cancellation does not cancel it.

The deposit is a return of the player's own money, not income. The real fulfilled-order expense is8. Immediate procurement and delayed discounted procurement have different timing, inventory and walking costs.

## Verification

The independent [economic and transaction audit](benchmarks/ENDLESS-V9-CONTRACT-AUDIT.md) contains20 legal50-floor comparisons, all completed and replayed, plus30 legal boundary checks. It includes returning from later floors, already-killed targets, cancellation, full inventory, independent refund and single-use exchange. No statistics, floor positions or gold were injected.

Native play used seed1609859073. The old v8 journey restored unchanged before explicitly starting v9. A first guard supplied18 gold; the untouched double route was accepted for12, leaving6. The cancellation confirmation was opened and dismissed without abandoning the order. Fighting both targets left48 gold; returning to the original merchant refunded12, then8 bought two piercing spikes, leaving52. Reload preserved HP110, attack23, defence12, gold52, kills3 and two spikes. Both order tabs, target states, refund, optional exchange and item inventory were visually inspected. No teleport or injected money was used.

Directed core tests:1,327 checks. Order UI:19 fixture checks, separate from legal-play evidence. Existing UI221 and growth UI15 pass. Native storage289, Node storage306. Actual Chrome production storage harness135 checks across nine rule versions. Full regression and exact-commit CI are verified separately before publication.

Godot Web-engine gameplay remains unverified in the cloud WebGL-blocklisted browser; browser storage tests do not replace it. Rankings are device-local, not a global service; no backend account, fee or player-data upload was created.

## Remaining design debt

Gold still accumulates in the measured policies. Orders add real discretionary spending, but are not a cure for the generous economy. Repeated returns also add actions: the audited main-route order policy needed about423 more actions across50 floors than no procurement; the alternate route about566. This batch therefore cannot be advertised as removing mechanical repetition. A later version should evaluate safe cleared-route return shortcuts and more genuinely different encounter/map structures without silently changing this contract or old replay rules.
