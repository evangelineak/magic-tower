# Original freight map icons

Authored low-poly Blender geometry and procedural materials only; no external models or textures. `cargo.png` is a sealed teal medical supply crate; `cargo_empty.png` is an unmistakably empty freight berth. Both are transparent 128px PNGs for 60px drawing inside a 64px map tile. `cargo.blend` contains separately editable cargo/cargo_empty collections.

Rebuild with installed Blender 4.3:

```sh
blender -b -t 4 -P tools/build_cargo.py
# Optional incremental render:
blender -b -t 4 -P tools/build_cargo.py -- --only cargo
```

Cycles CPU, 64 samples, no denoising. The original combat, map-character and prop files are not rewritten. This addition does not select a project-wide license.

State mapping is the game's responsibility: render a full crate at the source only while its real `h` remains and state is waiting/opened. At destination render full cargo only when shipped, otherwise the empty berth; never show a second supply. Keep the 5F Q calibration token visible and use an adjacent marker there. Old cargo version 0 has no freight overlay.
