# Endless v21: seeded talents and horizontal legacies

## Two separate systems

Talents are choices earned inside the current run. Legacies are optional starting exchanges unlocked between runs. Neither adds unlimited permanent attack or defense. Old rules 1–20 remain frozen; ending an old-version run does not retroactively award v21 legacy milestones.

## Seeded talent draft

At 3, 8 and 15 surviving kills, the next of three talent rounds becomes available. The player may defer a choice; delay, HP, inventory, hero, previous choice, equipment and reload do not reroll it. Nine distinct cards are deterministically shuffled by seed and split into three disjoint groups of three. Only one card from the current group may be chosen, in round order, for at most three talents.

An already prepared hero skill must first be cancelled for free before any talent selection. This prevents changing its cost or power between preparation and execution. Learning never refills focus or grants an immediate HP/stat reward. It is legal to select a currently unhelpful card, such as extra capacity while already below the cap; offers are not filtered into a stronger draw.

| ID | Talent | Exact effect and cost |
|---|---|---|
| reserve | 储备 | Focus cap becomes 4 instead of 3; current focus is unchanged. |
| tracker | 追猎 | If this enemy has the same token as the last surviving kill, the player's first hit gains 3 damage. No bonus before the first kill; death does not update kill history. |
| laststand | 背水 | At **pre-battle** HP ≤ 60, multiply the first player hit by 1.2, rounding down. It does not activate midway through a battle. |
| alert | 留神 | If no hero skill is prepared and focus ≥ 1, reduce the enemy's first active attack by an additional fixed 2. Opening attacks count; reflection does not. |
| light | 轻装 | With no persistent gear equipped, reduce the first counterattack by an additional fixed 3. Wearing cloak or lens disables it. |
| wardweave | 护符编织 | With an actual ward prepared and available, the first counterattack gains fixed reduction 3, but effective attack is reduced by 1 for that battle. The item is still consumed by real combat. |
| deepdrill | 深凿 | With an actual piercing tool prepared and available, ignore 2 additional defense, but every enemy active attack gets 2 additional raw damage before charge/shock multipliers. This surcharge can turn a previously zero-damage attack into damage. No counterattack is invented after an enemy is killed. |
| mender | 修复学 | Merchant potion nominal healing +4 and Scholar healing +4; Reap's post-victory recovery −2, minimum zero. Free supply boxes, vault infirmaries and relics are not enhanced. |
| overload | 透支 | Hero skills cost 2 focus: Warden prevents 75%, Ranger ignores 14 defense, Scholar heals up to 42. Mender can add 4 to that 42. Insufficient focus cannot prepare or cast the skill. |

### Deterministic combat order

Effective gear/Weave attack → effective armor after item/tactic/hero/Deep Drill → first-hit Tracker +3 → Last Stand/背水 floor ×1.2 → Shock ×2. Later hits do not receive first-hit bonuses. If the ordinary later hit cannot penetrate but the special first hit can kill, the battle is valid; otherwise an unfinishable battle is refused before spending resources.

Enemy base damage is `max(0, enemy attack − effective defense)`. Deep Drill adds 2 to that damage, then charge and shock multipliers apply. Existing brace → cloak → ward fixed reductions occur first. First-counter Light and Weave reductions, then first-active Alert, apply to the remainder. Hero percentage reduction applies last. Reflection is independent of these attack reductions. Zero-damage active attacks still count for first/two-attack effects.

Priest regeneration depends on the resulting actual positive counter damage, and death stops the event stream before later regeneration, rewards or Reap. Silence still suppresses battle healing, not paid non-battle treatment. Talent effects use the same pure v21 combat simulation for preview and actual play.

## Horizontal legacy exchanges

Every run may carry one unlocked legacy, or freely choose none. Unlocking costs points once; selecting an already unlocked legacy in a later run does not spend another point. All three heroes remain freely available regardless of unlocks.

| ID | Unlock cost | Starting exchange |
|---|---:|---|
| none | 0 | Original 150 HP, 2 focus and original inventory. |
| kit | 1 | Start with 1 focus instead of 2; gain one ward and one piercing tool. |
| coin | 2 | Start with 1 focus instead of 2; the run's first actual cash-vault pickup has a one-time extra 12 gold. It does not modify monster rewards, deposit refunds, medicine or tool vaults. |
| mind | 2 | Start with 120 HP instead of 150 and 3 focus instead of 2. Maximum HP is unchanged. |

Coin's preview shows 52 nominal cash and the actual amount allowed by the numerical gold ceiling. If there is no capacity, the cache and entitlement remain. A partial ceiling payout consumes that one actual cache opportunity, including any unpaid overflow; it cannot be repeatedly collected for another bonus. Killing a monster or opening a door alone does not use the bonus.

These are finite opening choices, not infinite account stat growth. Coin has limited value to a rich late-game character; it is an early vault-routing incentive. Mind exchanges 30 HP for one skill resource, not free healing, and its value differs by hero and later talents.

## Cross-run milestone accounting

The agreed profile contract awards one point for each newly recorded lifetime maximum-depth milestone **3, 8, 15, 30, 50**, on death or voluntary retirement. Each milestone is awarded only once across runs, for a lifetime total of five points. The three unlock costs total five. Repeated early death, another retirement, reloading a finished run or settling the same run ID again cannot create more points.

Store ownership is separate from core replay: the profile, receipt, finished run and ranking changes must use one versioned compare-and-swap transaction. Unspent points derive from awarded milestones minus unlocked costs, not a client-provided free balance. A run's already recorded starting legacy never changes because a later run unlocks something else. Local persistence is not server-backed anti-cheat or a global leaderboard guarantee.

## Replay and APIs

`endless_world_v21.gd` and `endless_combat_v21.gd` are new files; prior versions are untouched. DTO remains the exact four fields `version/mode/seed/actions`.

- First events are `hero_*` then `legacy_*`, including `legacy_none`. Other actions are blocked until both are selected. Neither can be changed afterwards.
- Core replay verifies the fixed legacy directory and applies its starting exchange. It does not consult the current device profile. The store's atomic `start_legacy` operation separately verifies that the chosen legacy is unlocked before creating the run. The distinction is intentional: reproducible history and live authorization are different checks.
- Talent events are `tal_<id>`, each at most 16 characters. Core checks actual surviving kills, current round, fixed offers, preparation status and action budget.
- `talent_catalog()` returns card definitions; `talent_draft()` returns three arrays of IDs. `talent_view()` provides chosen cards, current offers, tier, kill threshold, availability and refusal reason. `talent_preview(id,target)` compares cloned before/after forecasts without altering resources.
- `legacy_catalog()` supplies IDs, costs, names and descriptions for UI/store. `hero_view()` now reports actual focus capacity/cost, healing and dynamic skill description.
- Runtime talents, prior-kill token, selected legacy and the coin-use flag are replay-derived. Clone and route forecasts carry them forward. Sequential route simulation updates prior-kill history after each surviving fight and consumes a prepared hero skill/item only once.

## Core evidence and limits

The initial core pass contains 11,358 checks with zero failures, including a finite 5,000-seed shuffle regression, deferred three-round choices, startup prefixes, actual legacy exchanges, capped focus milestones, Mender/Overload resource costs, and real first cash-vault pickup with full replay. In that fixed shuffle sample, per-slot card counts ranged from 504 to 593 and per-tier card counts from 1,613 to 1,715. These are regression observations, not a mathematical randomness guarantee.

Twelve actual 100-floor policies cover seeds 0/42, all three heroes, and either no talents with no legacy or the actual first offered card each round with kit/coin/mind respectively. Seed 0 uses the main route; seed 42 uses the alternate route. All survived and replayed. These are explicit samples, not every build/seed or an optimal-policy claim; independent policy and combat-oracle reports provide additional evidence. The ordinary vault was not required by these 100-floor policies; a separate earned history tests Coin's real vault claim.

The selected talents can reduce damage and medicine spending. Nothing in this release proves that late-game currency inflation or repetitive deep-floor objectives are solved. Headless and independent oracle checks do not replace native or browser visual acceptance.

## Integrated acceptance

- Independent ordered-battle oracle: 57,384 battle cases / 989,323 assertions, including all 84 possible three-card combinations, 252 chained route/rune fixtures and capped legacy resources. Separate 24 legal sixteen-floor runs passed 7,920 replay checks. Conservative policies remained healthy; this is not a difficulty-balance proof.
- Storage: 1,120 native checks, 459 safe-walk checks, 1,550 Node checks. Independent audit added 323 native and 82 production-JS assertions with genuine 58-action third-floor retirement and 165-action seventh-floor death, failed native writes, migration and lost acknowledgments.
- Actual Chrome harness: 794 checks passed using production callback, Web Locks, localStorage and a second browsing context. Original test-site data restored. This is **not Godot WebGL gameplay**.
- Native Godot manual play: seed 1186396894, Warden/no legacy, walked three floors and defeated three guards, chose Alert from fixed Light/Laststand/Alert offers with a distinct confirmation. Retired at floor 3 and received exactly one point; restarted the application and read the same one-point receipt. Spent that point on Kit, then started Ranger/Kit seed 374716464: UI showed focus 1/3 and exactly one ward plus one piercing item. Older v20 ended history loaded unchanged and explicitly awarded no points. Classic save remained separate.
- Talent, legacy and hero views were visually read in the native game at 1280×800. Full Web engine play remains unverified in this cloud browser due its WebGL limitation. Public global ranking remains absent; these points and records are device-local.
