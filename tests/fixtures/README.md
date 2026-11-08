# Save compatibility fixtures

`schema6-expedition.json` is synthetic gameplay state, not user data. It was
produced from the published local v0.12 commit `6a780c4`, using that revision's
actual World, Generator and Expedition implementation in an isolated directory.
It is deliberately not a current map with its version number edited downward.

Reproduction:

1. Export `git archive 6a780c4` into a disposable directory.
2. Run a Godot `SceneTree` script with that directory as `--path`.
3. Construct `World.new(0)`; obtain `Generator.validate(world.floors).route`.
4. Replay each U/D/L/R using `world.step(direction)`, reaching the first ending.
5. Call `world.action("expedition")` once, assert `save_data().version == 6`,
   and write `JSON.stringify(world.save_data())` to the fixture path.

The fixture is at the start of the old eight-floor expedition. It contains no
Mira (`t`) or gaoler (`W`). Schema 7 must preserve its existing maps, classify it
as expedition revision 1, and not mint new rescue progress, gear or camp stock.

## Schema 7 earned rewards

`schema7-expedition.json`, `schema7-repeater.json` and
`schema7-supplies.json` originate from published local commit `4382454`, exported
into an isolated directory. These are synthetic gameplay fixtures, not user saves.
The expedition fixture follows the same first-chapter witness procedure above.
The two reward fixtures replay that revision's `test_rescue.gd` real route:
walk from spawn to J, accept, beat the first chapter, continue, follow the second
chapter witness until just before Z, return to seventh-floor W and rescue t.
From that saved branch, walk back to J and choose `rescue_repeater`, or walk to
sixth-floor U and choose `rescue_supplies`. Capture immediately after each choice.
The supplies capture uses actual stair/path walking to U, not the targeted
resource/position fixtures elsewhere in the test; its three stocks are earned.
The old World writes these files directly with `JSON.stringify(save_data())`.
Schema 8 must add only a fresh oath: maps, earned gear, rescue outcome, money,
loan state and both three-use camp inventories must remain intact.
