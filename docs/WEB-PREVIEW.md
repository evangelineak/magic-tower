# Public browser playtest

This isolated deployment branch publishes verified v0.17 usability fixes. GitHub Pages builds on pushes to `pages/playtest`; in-progress development does not auto-deploy. The old `pages/stable-v0.15` branch remains a rollback reference.

Godot 4.6.3 Compatibility, single-thread Web export; no service worker or SharedArrayBuffer requirement. Workflow verifies official engine/template SHA-256 and exports only public game resources.

Hover a tile for nearby information. Click clear floor to walk safely; clicking monsters, doors, items, stairs or events only inspects. Use arrows/WASD for deliberate interaction. Start a new run for this playtest to experience aligned stairs and sealed reward rooms. Legacy-save loading remains available but is not required.

Saves stay in this browser IndexedDB, not a server or desktop. Reload then L to continue; clearing site data removes saves. A new run replaces the active save, so preserve it first if needed.

Public development preview, not final release. Cloud Chromium blocks WebGL2 so public delivery can be checked but cloud Web gameplay/save-refresh is not claimed; native Godot gameplay has been tested. Windows runtime and subjective audio testing remain separate.
