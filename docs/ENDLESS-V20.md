# Endless v20: three heroes and finite focus

Source acceptance record: v20 implementation and the checks below are local; the last verified public-page version is v19 until a separate deployment is confirmed. Consult the live `BUILD.txt` for the deployed version. Native visual/play acceptance is recorded below; final aggregate acceptance remains pending and must be recorded separately when completed.

## Scope

All three heroes are available at the start of a new v20 run, with identical starting HP, attack, defense and ordinary resources. Identity is selected once before movement. Heroes have different active skills; they are not renamed versions of the existing camp-switchable brace/pierce/reap tactics. Tactics, equipment, consumables and heroes coexist.

This release does not add seeded talent drafts, cross-run reincarnation points, permanent unlocks, focus purchases, or a new map. Those are later designs. Versions 1–19 remain frozen.

## Exact skills

| Hero | One-focus skill | Timing and limits |
|---|---|---|
| Warden / 护卫 | Prepare double guard | During the next real battle, reduce each of the enemy's first two active attack events by floor(remaining damage / 2), **after** existing fixed reductions. Scout opening attacks count. Zero-damage attacks also use an event slot. Reflection is not an active attack and is neither reduced nor counted. |
| Ranger / 游侠 | Prepare precision | During the next real battle, every player hit ignores an additional 8 enemy defense. This stacks with the prepared piercing item and the current pierce tactic, but final defense cannot become negative. |
| Scholar / 学者 | Immediate repair | Outside combat, spend one focus to heal up to **24** HP, capped at 180. At full HP, refuse without spending or recording an action. It cannot revive a dead hero. |

Preparing and cancelling a combat skill do not spend focus. A duplicate preparation or cancellation without a prepared skill is a no-op. An actual battle spends one focus and clears preparation, even if it has zero damage or the hero dies. Merely viewing a forecast, asking for fatal-battle confirmation, cancelling that confirmation, failing to penetrate armor, or refusing a regeneration loop does not spend it.

The skill is a one-battle resource, not a buff for an entire route. Route forecasts consume it after the first actual remaining battle; the second guardian does not receive it again. Fatal damage is resolved before post-victory recovery, gold or kill rewards.

## Focus resource

Start with 2 focus, maximum 3. First reaching a new maximum depth divisible by four (4, 8, 12, …) grants one. Excess at the cap is discarded immediately, not stored for later. Descending and returning, changing gear/tactics, or revisiting a camp cannot claim it again. There is no paid recharge in v20.

These are real additional resources. Scholar can convert an available charge into at most 24 HP, so the recurring upper bound is 6 HP per newly reached floor on average before overflow, unused charges and healing caps. That can reduce late-game medicine spending. This release must not be described as an economic tightening or proof that prior gold surplus is solved. Actual hero comparisons need policy-specific 50/100-floor evidence, not only maximum theoretical skill values.

## Combat implementation and compatibility boundary

`endless_combat_v20.gd` is a pure deterministic simulator. It first checks whether the enemy can eventually be killed, using enemy-health state plus first-hit/first-counter and first-two-attack phases. It then resolves actual player-HP events in order:

1. Scout opening attack, if present.
2. Player hit.
3. Thorn reflection, including a killing hit.
4. A surviving enemy's counterattack.
5. Priest regeneration only after actual positive counter damage while the player remains alive.
6. Victory recovery only after survival.

Fixed brace, cloak and ward reductions retain their existing first-counter ordering. Warden percentage reduction applies afterwards. A priest cannot regenerate on a fully blocked counter; zero-damage attack events still count toward Warden's first two. Shock and silence retain their existing first-active-attack and healing semantics. No hidden combat roll or enemy adjustment based on the player's current wealth is added.

All eight enemy tokens use this event model in v20. Earlier versions sometimes displayed full-battle lethal totals for older enemies rather than stopping at the first lethal event. v20 now reports only events that actually occurred before death. It is therefore not a promise of field-for-field identical lethal forecasts to v19; old saved versions continue using their frozen forecasts.

## API and storage contract

- `hero_catalog()` returns an array of three cards with `id`, `name`, description, skill name/description and focus-recovery explanation.
- `hero_view()` includes identity, focus/cap, preparation state, legal options, next focus depth and Scholar's current actual healing.
- `hero_warden`, `hero_ranger`, or `hero_scholar` must be the run's first event. Until selected, other actions and movement are refused. Hero switching is not allowed.
- `skill_use` prepares Warden/Ranger or immediately heals Scholar. `skill_cancel` cancels a prepared combat skill.
- DTO remains exactly `version`, `mode`, `seed`, `actions`. Hero identity, focus, preparation and milestone consumption are reconstructed from events, not accepted as injected saved fields.
- An empty new world is a selection-screen draft, not an authorized active run. The store's separate `start_hero` transaction validates and saves the selected-hero prefix atomically; the old empty-log `start` contract is not broadened.
- `clone`, route simulation, rune before/after previews, safe camp return and replay use the v20 factory and preserve hero state alongside prior cart, bridge, cargo, equipment and rune state.

## Verification boundaries

Core tests cover selection, invalid or repeated identity, preparation/cancellation costs, capped Scholar healing, action/ended guards, clone/replay, sequential route forecasts, earned depth milestones and real stair revisits without focus farming. Actual 100-floor policies compare all three heroes across two seeds and both routes with explicit skill/medicine choices.

The separate independent combat oracle enumerates controlled combat inputs and compares preview plus actual confirmed movement against a separately written event simulator. Its synthetic fixtures are not described as legally earned builds. Independent resource histories and store/native/Web protocol tests are separate evidence. Headless correctness alone is not a native or browser visual acceptance.

### Core verification result

Final core suite: 6,225 checks, zero failures, including 12 actual 100-floor journeys (two seeds × two routes × three heroes) and full replay. These policies did not use optional vaults, equipment, runes or permanent optional attack/defense growth. They prepared combat skills only when the visible forecast improved, and Scholar healed when missing at least 24 HP.

For seed 42, main/alternate-route medicine spending was 315/675 gold for Warden, 285/645 for Ranger, and 165/525 for Scholar; the corresponding no-skill baseline was 360/720. All completed 100 floors, but this does not establish equally efficient hero balance. Scholar was the strongest medicine saver in this policy, while combat skills can matter at thresholds or when HP is already full.

Frozen SHA-256 identities:
- `endless_world_v20.gd`: `d84f1a594ff233baf2521c9185c08224258acc3b6eb995a5e078894d1c1d81be`
- `endless_combat_v20.gd`: `3c25e29c4b6b003829e127eb683f31f738a7cacc4dbedcbb75c8075fb38b677c`

### Independent persistence protocol acceptance

Native **1,033** checks, native safe-walk **408**, and production Node storage **1,343** passed. The release coordinator ran the updated production JS harness in real Chrome: **699** checks covering callback delivery, Web Locks, localStorage and a second browsing context. This is not Godot Web-engine gameplay acceptance.

The dedicated `start_hero(snapshot, revision)` accepts only version20 with exactly one canonical `hero_warden`, `hero_ranger`, or `hero_scholar` event. Versions1–19 still start through the old empty-log `start`; version20 cannot be persisted unselected. Creating the new run and choosing the hero is one CAS write. A selection preview never replaces the old run before successful persistence.

Tests include each hero, malformed/multiple initial events, unknown version21, cross-version commits, fresh reads, failed native writes and browser quota errors preserving old bytes, two-writer conflicts and lost acknowledgements. A retry must be the matching `start_hero` operation; `commit` or `commit_walk` cannot impersonate its acknowledgement. Ordinary commits remain one-event extensions, and safe-walk remains the dedicated exact-route operation. The envelope, file/key and lock remain version1: no reincarnation profile migration is hidden in this release.

### Independent 24-journey economic comparison

[Raw final results](benchmarks/endless-v20-heroes.json): **65,808 checks**, zero failures; all **24 real 100-floor journeys** and their full event logs replayed the final hero, focus, preparation, HP, gold, items and map deltas. This used the frozen world/combat hashes above.

This is a **different policy from the core's 12-journey suite**: two seeds (0/42) × two routes × three heroes × never-use/greedy-use policies. It uses the finite shared lessons and capped optional attack/defense growth, with camp tactics and medicine when camp HP≤130. It takes no ordinary key-vault rewards, cart claims, purchased equipment, rune activation or consumable tools. These growth choices explain why medicine costs are much lower than in the core's no-optional-growth suite; do not mix the two tables.

The greedy policy prepares Warden/Ranger only when the player-visible immediate net-loss forecast improves, and Scholar heals a full24 before a battle when missing at least24. It does not optimize future charge allocation, and it visits the camp before that battle-time healing decision. Forecast-guided decision-making is a player policy, **not an independent combat oracle**. Results measure actual committed resource changes and conserve focus; the separate oracle handles formula correctness. No attributes, position, growth or focus were injected.

Seed42 results (HP/gold are actual endpoints; medicine is total paid gold):

| Route | Policy | Floor50 HP / gold | Floor100 HP / gold | Medicine | Focus spent / overflow |
|---|---|---|---|---:|---:|
| Main | Never, all three heroes | 138 / 261 | 178 / 490 | 30 | 0 / 24 |
| Main | Warden greedy | 163 / 261 | 135 / 520 | 0 | 26 / 0 |
| Main | Ranger greedy | 168 / 261 | 132 / 520 | 0 | 18 / 6 |
| Main | Scholar greedy | 162 / 261 | 174 / 520 | 0 | 4 / 20 |
| Alternate | Never, all three heroes | 179 / 473 | 145 / 950 | 60 | 0 / 24 |
| Alternate | Warden greedy | 163 / 488 | 165 / 965 | 45 | 26 / 0 |
| Alternate | Ranger greedy | 156 / 488 | 149 / 965 | 45 | 21 / 4 |
| Alternate | Scholar greedy | 175 / 503 | 161 / 1010 | 0 | 10 / 14 |

All three never-use baselines agree within each seed/route, consistent with identical starting panels and no hidden passive hero bonuses. Lower final HP in a skill policy does not by itself mean a weaker result: that policy may have avoided buying a large potion and retained more money.

For seed42's last25 floors, actual gross/net battle loss was main84/28 and alternate182/62 without skills; Warden66/13 and162/43; Ranger68/16 and162/47. Scholar leaves battle damage unchanged but spent4/10 charges over the full main/alternate journey for96/240 total healing. Its unused/overflow charges show that full-charge throughput is not needed in these already comfortable builds.

These observations do not establish equally strong heroes or an optimal strategy. Skill choice can save medicine or cross a particular combat threshold; Scholar was particularly efficient at saving medicine in this sample. The pre-existing late-game surplus remains, and focus adds usable resources rather than correcting that surplus. Talent drafts, reincarnation, cross-run unlocks and global ranking are still absent; [the meta-profile design](ENDLESS-META-PLAN.md) is a deferred plan, not a delivered feature.

### Actual native three-hero play acceptance

The release coordinator exercised these flows in the real native application, not in a headless fixture or Godot Web engine:

- **Old-run protection:** the existing v19 run retained HP 41, gold 39, keys 5 and kills 5 after loading the v20 code. Opening a new-run selection with N, choosing Ranger and then cancelling with Esc returned to that old run with all those values unchanged. All three hero cards/preparation presentation and the B interface were inspected, alongside the 40/64/128-scale visual samples.
- **Warden, seed 155686682:** started with 2 focus. Preparing and cancelling did not spend it. After training, HP 158/ATK 23/DEF 13 faced a scout: the forecast changed from 14 damage without the skill to 8 when prepared, including 4 opening damage and 6 total hero reduction. Actual combat ended at **HP 150, gold 5, kills 1, focus 1**, matching the prepared forecast.
- **Ranger, seed 1041426549:** after training, HP 158/ATK 23/DEF 13 faced an armored guard. Prepared ignore 8 reduced effective enemy defense to 3, with 3 player hits and 10 predicted damage. Actual combat ended at **HP 148, gold 4, kills 1, focus 1**.
- **Scholar, seed 785562916:** initial HP 150 became 174 after one skill, leaving 1 focus. A supply healed only the missing 6 to 180; a full-health skill attempt spent nothing. The route priest caused 7 real damage, leaving **HP 173, gold 6, kills 1**. A second skill healed the actual missing 7 to 180 and left 0 focus. A real native stop/restart and mode return (F8/F5/F3 in this test) restored **HP 180, gold 6, kills 1, focus 0 and position (3,7)** exactly.
- **Fatal confirmation and settlement:** that Scholar then voluntarily approached the old strong guardian, whose forecast showed 187 damage and 11 hits. Cancelling the dangerous-fight confirmation preserved the run. Confirming the fight caused actual death at HP 0, with no additional gold or kill reward; the end screen displayed that the result had been saved.

These are specific native interaction, combat, persistence and death-settlement observations. They do not replace the independent replay/oracle checks, prove that all builds are balanced, or establish Godot Web-engine play/reload acceptance. The final aggregate gate subsequently passed: 110 Godot suites, the Node protocol checks and the separate cart contract gate, exit 0 with no SCRIPT ERROR or ERROR signal.
