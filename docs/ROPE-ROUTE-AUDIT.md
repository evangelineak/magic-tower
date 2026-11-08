# Single-use ferry rope: legal-route audit

Run `tools/audit_rope_routes.gd` with Godot headless. The audit first earns
milestones [3,5,8] with an actual seed-1 scholar victory and a validated profile
receipt. It then replays ordinary first-chapter routes for Warden, Ranger and
Scholar (seed 0), plus an actually unlocked Channel scholar with study2/reserve1
(seed 23). Talents and skills are acquired/used through World actions, not
injected fields. The resulting Channel checkpoint has effective skill level 14.

Each independently cloned, legally reached first-ferry checkpoint compares:

* One `rope_cross`: exactly one focus spent, no HP/gold/kills gained, H still
  alive, rope spent. A second crossing is rejected without mutation.
* Normal combat, including actual arm actions for the martial classes.
* Scholar combat followed by actual Mend until its remaining focus equals the
  rope branch, making the opportunity-cost comparison explicit.
* A real 80-gold bridge purchase and a cleared route to the same landing,
  preserving focus/HP and the living guardian. Rope is then unavailable rather
  than wasting another focus.
* After crossing, actually turning back to fight the still-living H from the
  flank. Any subsequent victory recovery comes from that fight, not the rope.

## Observed alternatives

| Build | Focus before | HP after rope | HP after fight, equal focus | Bridge cost / focus |
|---|---:|---:|---:|---|
| Warden | 2 | 837 | 758 | 80 gold / unchanged |
| Ranger | 1 | 762 | 670 | 80 gold / unchanged |
| Scholar | 1 | 1073 | 1027 (fight + Mend) | 80 gold / unchanged |
| Channel scholar, level 14 | 3 | 1465 | 1427 (fight + Mend) | 80 gold / unchanged |

All fight alternatives also earn the actual 60 gold and one kill; bypasses do
not. These numbers describe these checkpoints, not a universal balance claim.
The Ranger also performs a genuine `arm` followed by crossing with its last
focus: focus becomes zero and the armed skill is cancelled.

There is a useful build-specific positional interaction: the high-Channel
scholar crosses, fights back from the flank and finishes at 1364 HP / 3 focus,
versus 1327 HP / 3 focus for the frontal fight. The one-use rope converts its
focus cost into positional advantage, and the later fight genuinely refunds
focus. In contrast, the Ranger's crossing-plus-return-fight ends with the same
670 HP / 0 focus as its frontal fight while spending the rope and an extra move.
No resource is granted by crossing itself. The script asserts these actual
movement, combat and reward boundaries without treating every branch as best.

Evidence: `docs/rope-route-audit.jsonl` contains the earned receipt and four
complete branch records. This is automated legal model replay, not manual GUI
play or a browser engine test.

## Real native GUI checkpoint

`tools/export_rope_gui_checkpoint.gd` creates a genuinely fresh registered
native journey, records every successful action/step, and commits the resulting
same-ID snapshot through the production adapter. It exports an isolated native
container to `/tmp/rope-gui-checkpoint.json` and full action provenance to
`/tmp/rope-gui-checkpoint-provenance.json`. The initial exported checkpoint is
seed0 Ranger, floor6 (6,2), 486 HP, 1 focus, 362 gold, 263 moves, rope ready.
It is suitable for real confirmation/Undo/reload UI validation, not a migrated
old `off` save with its fields edited. Tests must wait for the original writer's
lease to expire before taking over; no lease metadata should be rewritten.

Genuine schema18 migration fixtures are separate under
`tests/fixtures/rope_schema18_*`; their isolated-source commit and SHA-256 values
are recorded in `rope_schema18_PROVENANCE.md`.
