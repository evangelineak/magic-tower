# Map-specific original character icons

Authored procedural low-poly models for Magic Tower. No downloaded models, textures or third-party artwork. These chunky close-view silhouettes are separate from the combat portrait assets. No project-wide license is selected by this asset addition.

Rebuild with installed Blender 4.3:

```sh
blender -b -t 4 -P tools/build_map_icons.py
blender -b -t 4 -P tools/build_map_icons.py -- --only ferryman jailer
```

The script produces 128×128 transparent RGBA PNGs and `map_icons.blend`, with one editable collection per model. Cycles CPU, 64 samples, no denoising. Incremental renders preserve unselected PNGs. Each silhouette has a fitted orthographic camera, enlarged head/equipment, and broad surfaces for readability rather than battle-portrait downscaling.

NPCs: `J=ilen` (navy map and brass survey ring), `t=mira` (teal scarf, backpack and map tube).

Mappings: heroes `warden/ranger/scholar`; `s=mossling`, `u=stalker`, `H=ferryman`, `W=jailer`, `g=sentinel`, `b=briar`, `w=juggernaut`, `V=colossus`, `K=regent`, `Z=archivist`, `B=gate_brute`. Suggested drawing size 60×60 inside a 64×64 tile, with separate UI mechanism badges. Original battle portraits remain untouched. All active enemy tokens now have map-specific silhouettes; B has a distinct horned legacy fallback, not a royal duplicate.
