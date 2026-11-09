# Endless v12: enemies whose timing changes the decision

New journeys use v12; v1–v11 logs remain frozen. The existing five map families keep their doors, reward chambers, alternate routes and paired stairs. Seeded rosters now mix two new enemy types into existing guard positions without adding mandatory fights. This is roster variation, not a new geometry family.

## Two distinct rules, visible before fighting

**Thorn guard:** HP32, attack14+2×floor, defence2+3×floor, reward22 gold. Every successful player hit immediately reflects two damage, including the killing hit. Reflection is not a counterattack and is not reduced by brace, the mantle or a ward. If reflection kills the player, no later counterattack, kill reward or reaping recovery occurs. Killing the enemy and dying to its final reflection is not a victory.

**Renewal priest:** HP34, attack18+2×floor, defence1+3×floor, reward24 gold. After a counterattack deals positive actual damage, it restores three HP up to its initial maximum, only while both sides remain alive. Completely blocking that counterattack prevents recovery. Killing it prevents the counterattack and recovery. Once the special first-counter phase is past, a stable no-progress healing loop is refused without charging HP or items, rather than hanging or using an arbitrary round limit.

Previews explain attack count, reflection or enemy recovery, actual damage and survival. The settlement panel uses original distinct flat sprites and names the mechanic. Invalid routes distinguish regeneration stalemate from an otherwise unbreakable defence; unavailable victory rewards are not promised. Equipment, tactics and one-use items retain their explicit existing costs and limitations.

## Independent correctness and balance checks

Core: 8,286 checks including twelve legal 100-floor journeys and seeded generation through the million-floor safety boundary. Independent event reference: 8,610 controlled combinations and101,640 assertions, comparing an independently implemented small-step model with production previews and actual step outcomes. These controlled fixtures are not advertised as player progression.

Independent legal audit: twelve actual100-floor policies,6,808 checks,312 thorn and291 priest battles, full replay, no injected money/stat/position. [Audit and raw evidence](benchmarks/ENDLESS-V12-ROSTER-AUDIT.md) retain50-floor intermediate states and100-floor results. Gold remains generous, and the mantle often beats the lens in those policies; all sample runs surviving does not prove every seed or choice can succeed.

Native storage424, exact safe-walk storage87, Node production protocol498. Actual Chrome production localStorage/Web Locks/callback/second-context harness231 checks; test-origin data restored afterward. UI17 new checks plus existing UI regressions. Full suite and exact-commit CI are publication gates verified separately.

## Native play, not injected demonstrations

The v11 journey first restored unchanged (HP117/gold25/kills3). A legitimate new v12 journey, seed1634555469, began with a priest on the single route. Without taking the training pack, the preview showed three attacks, two enemy recoveries totalling6,20 damage and24 gold. Clicking the adjacent priest left HP130, gold24, kills1 as predicted; reload preserved it.

A later legitimate new journey, seed1085602699, had a thorn guard on the channel route. Training, one supply box and free camp brace produced HP158, attack23/defence12. The preview showed two hits, four reflection damage and the full four-point counterattack blocked. Adjacent mouse combat still cost four HP, including the killing hit's reflection, leaving HP154, gold22, kills1. The settlement panel explained why brace did not eliminate reflection; reload retained state. Death/stalemate boundary checks were automated, not claimed as manual deaths.

Eight enemy silhouettes were inspected natively together at64/40/24/128px. The new round thorn-root body and narrow hollow-mask branching-staff figure are not recoloured existing guards. Text was further tightened after native inspection to avoid mentioning priest recovery in thorn tooltips.

Godot Web-engine gameplay is still unverified in the cloud WebGL-blocklisted browser. Browser storage QA is not engine play. Rankings remain device-local; no global backend, account, fee or player-data upload was created.
