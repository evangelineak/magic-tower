# Distinct B / H / W combat portraits

Original models from this project's editable `assets/map_icons/map_icons.blend`, appended as geometry and newly rendered, not enlarged map PNGs. `gate_brute` is the horned gate brute, `ferryman` the broad one-sided shield guard, and `jailer` the cage-helmet/chain/key guard. This matches their distinct map silhouettes instead of substituting the regent, stalker or sentinel.

Combat portraits are 384×384 transparent RGBA, a three-quarter orthographic camera, individually fitted with breathing room, cool key/gold rim lighting, Cycles CPU 128 samples without denoising. The standalone `combat_supplement.blend` includes all three editable collections and the combat camera/light rig. Existing character PNGs and `characters.blend` are not rewritten.

```sh
blender -b -t 4 -P tools/build_combat_supplement.py
blender -b -t 4 -P tools/build_combat_supplement.py -- --only jailer
```

UI mapping required: `B -> gate_brute`, `H -> ferryman`, `W -> jailer`; load these names from `res://assets/combat/`. Map icons remain unchanged. Sources are original procedural geometry/materials; no third-party art or new project license is introduced. SHA256 and sizes are in `supplement_manifest.json`.
