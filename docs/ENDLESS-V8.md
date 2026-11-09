# Endless v8: finite optional growth and an auditable long-run budget

New journeys use v8; saved v1–v7 journeys retain their exact rules. The four map families, same-coordinate stairs, sealed reward rooms and safe distant-click navigation remain. The root game is the publication target, not a preview-only page.

## What changed

- Entrance training still adds +3 attack/+2 defence once per floor. This is counted by packs actually collected, not the current floor; old enemies do not follow the player upward in strength.
- Optional permanent growth from training, shops, relics and quests shares +6 attack/+4 defence ceilings. Six training lessons are shared across the entire journey, including emergency healing. Exhausted offers do not charge; partial gains are explicitly labelled.
- Health capacity is 180. Ten free relief boxes are shared across the journey; each restores up to8HP. Later boxes cost4 gold, with a free option to discard the box and open the path. Full-health purchases are refused without charging. Transport pays once when accepted, not again when opened.
- Enemy identities follow fixed seed/floor combinations. Both routes can contain distinct guard types; longer fights, interception and charged retaliation retain different tactical incentives. There are no hidden hit rolls, minimum unavoidable damage, or player-adaptive enemy scaling.
- The G panel distinguishes automatic progression, optional stat budgets, tactical levels, remaining lessons/relief and sequential route forecasts. Hover and shop text display actual capped gains rather than promising discarded rewards.

## Evidence and limits

The independent [50/100-floor audit](benchmarks/ENDLESS-V8-BALANCE-AUDIT.md) retains failures rather than filtering them out:72 legal policy journeys,44 reaching100 floors and28 dying, all replaying identically. All36 policies using reachable medicine shops reached100. Eight additional legal double-relic return journeys reached100 with level5 tactics. No attributes or floor positions were injected.

The tested journeys no longer collapse into permanently free combat or thousands of accumulated HP. However, gold remains generous: some100-floor builds retain thousands, and strong builds can spend a25-floor window drawing down existing HP without buying healing. This is a scoped improvement, not proof that all seeds, infinite depth, or the complete economy are balanced. There is no universal v8 solvability certificate; the old version's constant8-damage certificate is explicitly not reused.

Native UI play used seed657679191: restored the old v7 journey unchanged, explicitly created v8, inspected G, claimed one8HP relief, used one guard lesson and Brace, took9 damage from the floor1 scout and8 from floor2's caster. Discarding floor2's box opened the route without changing the remaining9 relief. A15-gold shop potion advertised and delivered39HP to the180 cap. Reload preserved floor2, HP180, attack26, defence15, gold30, key1, kills2, one lesson and nine relief. No stat injection or teleporting was used. Paid-after-ten-box and exhausted-growth boundaries were exercised by automated tests, not claimed as manually played here.

Real Chrome production storage harness:115 checks, covering eight rule versions and cross-context storage locking. This is **not** Godot Web-engine gameplay; the cloud browser's WebGL block remains a separate unverified stage. Rankings remain device-local; no backend account, bill or player-data upload was created.

Core directed tests:2,873 checks. Budget UI:15 checks; existing UI:221; native storage:252; Node storage:268. Full regression and exact-commit deployment results are recorded by the release process, not inferred from these directed tests.
