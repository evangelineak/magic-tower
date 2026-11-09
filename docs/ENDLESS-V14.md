# Endless v14: a ring courtyard, not another menu

Explicit new journeys use v14. Existing v1–v13 action logs replay their original rules. Combat, prices, equipment and entrance inscriptions are unchanged.

## One new layout family, three local variants

The seeded **ring-and-bridge** family joins the five previous layouts. A narrow single-guard bridge crosses between the two entrance courts. The alternative passes a required guard into a middle courtyard, circles a solid central pillar, then passes a second required guard. Both local left/right arcs are real paths; neither bypasses either guard or joins the single-guard bridge midway.

Seeded pillar variants give local left/right distances4/4,6/4 or6/6, measured between courtyard endpoints and excluding guards. These are three variants of one family, not three entirely different games. The first implementation accidentally correlated family and variant hashes; coverage testing caught the missing variant, the hash was corrected, and final audits reran rather than relaxing coverage.

Valuable key-door and strong-guard treasure rooms retain single gated access. Stairs remain paired at identical coordinates. New-family camps and training stations are safely reachable from the current floor's entrance; revisit state and atomic safe return use the actual geometry.

A quiet original flat paving treatment marks connected empty ground around the actual camp. It stays beneath actors, resource icons and safe-path dots, does not cross walls/doors/enemies/items, and expands visually when supplies are collected. It adds spatial identity without another button, interaction or fake reward.

## Native play and evidence

The previous v13 journey restored HP150/gold69/kills2 unchanged. The third ordinary random new journey produced v14 seed243624511, ring family with the6/4 local arcs. Normal training and supplies gave HP158/attack23/defence12. The required charging guard cost the predicted14HP; the left outer arc and right inner arc were both manually traversed. Attempting the blocked inner-left passage did not move through the pillar. The second wizard guard cost another14, giving HP130/gold47/kills2.

The player climbed at(13,13), appeared on the next floor's same-coordinate entrance, returned to the first floor and reloaded without losing cleared guards. Safe return then traversed25 recorded empty steps to the camp without changing resources or triggering the untouched scout. Camp paving was also inspected natively at64px in supplies-present, supplies-cleared and wall-cut comparison scenes. Combat settlement no longer had the overlapping target tooltip found during v13 play.

Core11775 checks passed. Independent512-map geometry audit20818 checks and twelve legal100-floor journeys6810 checks passed, with final hashes and full replay. The audit uses its own BFS/path metrics, includes all enemy types and separately blocks each mandatory guard. It distinguishes D4 wall shapes from genuinely new layout families and records three observed pillar variants. Native storage534, atomic safe-walk155 and Node656 checks passed. Actual Chrome production localStorage/Web Locks/callback/second-context315 checks passed and restored test-origin data. Final aggregate/publication gates are verified separately.

[Independent report and raw data](benchmarks/ENDLESS-V14-TOPOLOGY-AUDIT.md) also expose inherited old-layout issues: isolated decorative empty tiles and some older camp stations beyond combat. Those were not silently changed in frozen old rules, nor advertised as fixed. The new family passes strict connectedness and entrance-camp checks. This is incremental spatial variety; the broad single-versus-double-guard structure and generous economy remain.

Godot Web-engine play remains unverified in the cloud browser because WebGL is blocklisted. Browser storage testing is not engine play. Ranking remains device-local with no backend, account, fee or player-data upload.
