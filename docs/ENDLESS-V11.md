# Endless v11: persistent equipment with explicit trade-offs

New journeys use v11; existing v1–v10 journeys retain their rules. This release adds two persistent items and original flat artwork, not additional enemy species or new map geometry.

## One equipment slot, not another permanent-stat stack

I opens consumables and persistent-equipment tabs. Each piece costs 40 gold once per journey. Buying does not automatically equip. Equip, switch or remove for free beside a merchant; away from camp the panel is read-only. Owning both does not stack their effects. Choosing no equipment remains valid.

- Bastion mantle: combat attack −2, defence −1 (minimum zero), first counterattack absorbs up to four damage. It does not block a scout's preemptive attack.
- Hunter lens: combat attack +3, defence −3 (minimum zero). Crossing a hit-count threshold can avoid a counterattack, but each received hit can hurt more.

Equipment does not change permanent growth, maximum HP, or the v8 shared bonus budgets. The HUD distinguishes permanent and combat attack/defence. Previews show both and include equipment before combat is committed. First-counter reduction applies in order: brace, mantle, consumable ward, capped at actual first-counter damage. Death cannot be rescued by post-victory healing. Equipment persists through fights; consumables retain their separate single-use rule.

## Balance review, not a claim of solved balance

An initial mantle lacking the defence penalty was rejected: an independent full-build policy suffered only 2/10 net damage across the final 25 floors on main/alternate routes. The final defence −1 version was genuinely rerun and produced 20/43. It is still strong. The same no-equipment policy produced 45/97 and the lens 136/240. There are concrete local trade-offs: against an unenhanced iron guard the mantle raises damage from 18 to 24, while against the mage it lowers 14 to 11. The lens can cross a one-hit threshold against a hammer guard, but it is not generally better.

See [independent six-policy audit](benchmarks/ENDLESS-V11-GEAR-AUDIT.md). Gold remains generous and these two items do not fix the long-term economy. Do not confuse replay correctness with complete balancing.

## Verification

Core: 7,648 checks, including twelve legal 100-floor trajectories (two seeds, both routes, no equipment/mantle/lens), all replayed. Independent audit: 1,832 checks across six legal 50-floor journeys and 450 individual battle-preview/actual-result comparisons. Equipment UI: 21 checks. Native storage: 375; v10/v11 exact safe-walk storage: 56; Node production protocol: 428. Actual Chrome production storage harness: 195 checks, restoring the test origin afterward. Full regression and exact-commit CI are separate publication gates.

Native manual journey seed 716372972 restored the old v10 journey unchanged before explicitly starting v11. Training and a supply box yielded HP158, permanent attack23/defence12. A keyed treasure paid40 gold, spent on the mantle without automatically equipping it. Equipping produced combat21/11, preserved HP and permanent values, and survived reload. Its two alternate guards were previewed at12 and11 damage and actually left HP135 with47 gold. The lens then cost40, did not automatically replace the mantle, and when explicitly equipped produced26/9. Away from camp it was read-only. The remaining iron guard dealt the forecast18, leaving HP117, gold25, kills3. Safe return and reload retained the same state and ownership. No injected funds, stats or position were used. Both icons were inspected natively at24/40/64/128px and in the real panel; mouse and Tab navigation were exercised.

Godot Web-engine gameplay remains unverified in this cloud browser because WebGL is blocked. Browser storage checks are not engine play. Rankings remain device-local, with no backend account, fee or player-data upload.
