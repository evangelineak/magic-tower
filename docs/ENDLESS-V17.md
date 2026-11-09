# Endless v17: budget choices and rewards worth keeping

New journeys use v17. Old v1–v16 saves retain their original rules. Final aggregate tests, exact-commit CI and original-homepage identity gate publication separately.

## Scope and boundaries

This release separates ordinary guard income from deliberate treasure-door income. Simply lowering enemy bounties cannot remove the40-gold cache behind every keyed door. Comparisons must include legal no-door and all-door policies, rather than silently assuming either. A reasonable route should not require opening every cash vault. There is no wealth-adaptive enemy scaling or hidden price increase.

Medicine restores up to50HP, capped at180. A player at150 receives30, not a defective30-HP potion. Existing dynamic option text already reflects this. The UI change makes the before/after health, price and unused healing easier to compare, without adding a permanent menu.

The genuine reward defects are different: helping the messenger still promises defence+3 before explaining the later budget conversion; and a completely capped, full-health player can consume a relic with zero gain. v17 discloses the messenger conversion at the choice, and leaves a zero-benefit relic on the floor for a later wounded visit. It does not invent unlimited stat growth or extra cash to guarantee every fully stocked player gains something from every tile.

## Final fixed budget

Ordinary guard bounties are4–6 gold (the long-life alternate sentry3), vault guardian18. Tool prices are4 for a ward and8 for a spike, with fulfilled-order exchange costing2 for a one-piece order or4 for a two-piece order. The12-gold refundable deposit,15-gold/50HP medicine, other permanent purchases and40-gold keyed cache remain unchanged. Prices are not secretly adapted to wealth or the player's build.

Reducing both bounty and tool price would otherwise devalue the paid treasure bridge against a40-gold cache. Its dedicated guardian therefore retains22 gold, and its box supplies2 wards+2 spikes, requiring two spaces in each inventory. It is not a universal bounty increase: ordinary charged guards still pay5. The box gives no cash. Nominal tool value24 plus guardian22 is not a proof that the bridge is better: combat damage, inventory and the player's actual use of tools matter. The closed/short/treasure geometry remains v16's audited contract.

## Evidence, not a claim of perfect balance

Independent16-policy100-floor comparisons include no-door/all-door, main/alternate, no equipment/cloak, with legal actions and full replay. For seed42, main/no-equipment/no-door final gold fell2164→490; alternate4175→950. All-door policies still add4000 gold. Both no-door and all-door sampled policies survive; the player is not forced to open every cash vault. Passive accumulation is reduced, not eliminated. [Audit and raw data](benchmarks/ENDLESS-V17-ECONOMY-AUDIT.md).

A separate pre-final A/B comparison without free skills/tactics bought tools only for a forecast damage reduction while reserving15 for medicine. With seed42's main route, the expensive-tool candidate bought14 tools, spent168 and took1204 damage; the chosen cheaper-tool candidate bought61, spent244 and took934. This makes purchases more accessible, not necessarily optimal against medicine. That comparison did not visit bridges, so it is not evidence for the final bridge compensation.

A genuinely legal888-action journey demonstrated keeping a zero-benefit third relic after filling growth on earlier floors, then taking30HP damage elsewhere and returning to collect exactly30HP. No attributes, position or inventory were injected into that journey. It remains a long walk, not a new instant or infinitely repeatable growth reward. Controlled quote and inventory fixtures are separately labelled in the audit.

## Native play

The old v16 seed1246616216 restored unchanged. A legitimate random v17 seed404467571 produced a bridge courtyard. Supplies showed150→158 with their non-cash relief cost. The bridge comparison correctly separated the dedicated guardian's22 gold from the box's2+2 tools. Choosing the treasure arm spent one key; the guardian cost the predicted14HP, leaving144HP/22gold, and the box gave exactly two of each tool without more gold.

The camp quote showed medicine144→180, actual+36, nominal50 and14 unused, costing15. An attempted25-gold sword purchase at22 gold was refused without loss. Buying the medicine left180HP/7gold. The encounter quoted ward4/spike8; spike purchase at7 gold was refused, then the ward cost4 and increased ward inventory2→3. Reload preserved180HP/3gold, ward3/spike2, one kill and the selected bridge. These were actual native UI actions, not injected state. The zero-benefit relic's long return was verified in the independent headless legal journey, not claimed as manually played.

Core5319 checks, independent budget2448, quote122, bridge317 and legal revisit67 passed; native729, walk272 and Node938 passed. Economic UI31 and related old-version UI regressions passed. Actual Chrome production localStorage/Web Locks/callback/second-context471 checks passed across17 versions. Final full-suite and public deployment identities are recorded separately.

Rankings remain device-local. No global service, account, billing or player-log sharing is part of this batch. Browser storage tests do not verify Godot Web-engine gameplay.
