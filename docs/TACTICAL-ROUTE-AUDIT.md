# Tactical forecast legal-route audit

`tools/audit_tactical_routes.gd` replays actual seed-0 journeys for Warden and
Ranger. It follows the generated first-chapter witness, returns along actual
open corridors to the waterworks, drains the water and obtains the heavy buckler
from the relic chest. It continues the expedition and learns the actually
available/earned Keen edge and Adversity charge talents. No resources, equipment,
positions, talent offers or map cells are injected.

At each of the three real Ferry Wardens, it freezes a legal checkpoint and
clones alternatives. Each alternative uses ordinary equipment/arm actions,
executes the actual attack, and compares the complete combat preview, resulting
HP and resulting focus against `World.tactical_forecast`. It also verifies that
reading the table did not alter the checkpoint, message or prior battle record.

For an actual flank approach, a separate clone pays the real 80-gold roadworks
price, traverses the opened bridge without killing the guard, reaches the side,
and retreats one cleared cell. The trial's nonempty safe-walk path is executed
with `safe_walk_step` before attacking. This is not an assumption that the
original front approach already has a free flank route. The script separately
executes 24 front alternatives and 8 flank alternatives: **32 matches**.

Selected actual outcomes at the first ferry (417 HP checkpoint):

| Warden build | Loss | Final focus |
|---|---:|---:|
| Traveler kit, unarmed, front | 136 | 3 |
| Traveler kit, armed, front | 89 | 3 |
| Buckler, armed, front | 55 | 3 |
| Buckler, armed, flank | 37 | 2 |

The last row is deliberately important: lower damage falls below Adversity
charge's 40-damage trigger, so the spent focus is **not** refunded. The audit
checks the actual action result, not only an arithmetic formula or a UI label.
This is a tradeoff, not a claim that one build is globally optimal.

Evidence: `docs/tactical-route-audit.jsonl` contains the two checkpoint summaries
and all 32 executed alternatives. These are automated legal model replays, not
claims of manual GUI play, browser engine execution, or injected test-fixture
progress. Optional maul/gaoler combinations are not claimed by this audit.

Run:

```sh
godot --headless --path . --script tools/audit_tactical_routes.gd
```
