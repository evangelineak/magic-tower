# Original one-use rope anchor markers

`rope_ready.png` shows a complete gold rope loop and teal binding. `rope_spent.png` shows visibly severed/frayed ends, a fallen rope and dark binding. Both retain the same anchor/base silhouette so the changed mechanism is recognizable without relying on color alone. There is no baked screen-east/west arrow; UI must derive travel direction from Layout.

Original procedural Blender geometry/materials only, no outside assets. 128×128 RGBA transparent, intended for 60px rendering in a 64px tile. Editable collections in `rope.blend`.

```sh
blender -b -t 4 -P tools/build_rope.py
blender -b -t 4 -P tools/build_rope.py -- --only rope_spent
```

Blender 4.3, Cycles CPU, 64 samples, denoising disabled. Existing art is not overwritten. This asset addition does not establish a project-wide license. Actual route rules, focus cost and Undo remain in game code, not these images. File sizes and SHA256 are in `manifest.json`.
