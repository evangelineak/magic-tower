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
