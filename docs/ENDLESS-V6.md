# Endless v6: camp encounters and one-use tactical items

New runs use v6; v1–v5 replays retain their original rules. Four map families and four enemy archetypes remain unchanged in this batch.

## Choices

R opens the current floor's camp encounter. The seed/floor hash selects one of three offers; players see all costs before choosing. Each floor allows one choice or a permanent refusal, never unlimited purchases. Stand beside its merchant to act.

- Quartermaster: 12 gold buys a ward; 18 gold buys a piercing spike.
- Medicine exchange: pay 30 HP for one key, or 12 gold to restore 35 HP.
- Old altar: pay one key for a spike, or 20 HP for a ward.

Life payments must leave at least 1 HP. Full inventory or insufficient resources do not spend anything or resolve the encounter. Each item type is capped at nine.

I opens inventory. Equip one item or put it away without consuming it. The next actual battle consumes it, including a zero-damage or lethal battle; cancelling a confirmation or being unable to penetrate armour does not. Wards mitigate up to six damage from the first retaliation; spikes reduce enemy defence by six. They combine with the existing stance, without negative damage or healing out of a lethal hit. Route forecasts consume the item in their simulation after the first remaining guard, not once per enemy.

A real-action regression demonstrates a strategic change: seed8 floor1 costs 8 HP on the primary route versus 6 on the twin-sentry route. Buying and equipping a ward changes these to 2 versus 3. This is not merely a larger stat counter.

## New-player clarity

The classic homepage labels the newer endless entry explicitly, including when the classic save cannot load. New/old rules are explained at restart and restore. H opens a read-only guide; the first-run introduction gives three concrete steps. B/Q have visible button backgrounds; R/I are clickable buttons as well as keys. All save changes still commit before the visible state changes.

## Verification and limits

- v6 core: 21,926 checks, including actual cost/reward actions, boundary cases, route simulations and JSON replay.
- UI: 198 checks, including failed-save rollback, encounter exclusivity, arming/unarming, reload and old-version rejection.
- Real Chrome production storage: 81 checks across six rules versions. This does not test the Godot Web engine.
- Native seed623936153: restored v5, explicitly started v6, paid20HP at the altar for one ward, equipped it, used the normal20HP supply, then fought the northern heavy guard. HP150→130→150→146 matched mitigation. The ward became zero and unarmed; L reload preserved both inventory and combat result. New entry, restart text and encounter/item panels visually inspected.

The new enemies requested by the user are not yet added here. Global ranking remains unimplemented. Offline replay benchmarks in `docs/benchmarks/` establish costs on this machine only, not Cloudflare CPU performance. No service/account/payment or player-data upload was created. Cloud browser WebGL is still blocked, so Godot Web engine gameplay is not claimed as verified.

New runs now use v7; see [ENDLESS-V7.md](ENDLESS-V7.md). Existing v6 runs retain their rules.
