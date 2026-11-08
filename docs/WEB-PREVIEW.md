# Stable browser preview

This isolated deployment branch uses the verified v0.15 game source, not in-progress v0.16 changes. GitHub Pages builds on pushes to `pages/stable-v0.15`. It does not merge or modify the development branch.

Godot 4.6.3 Compatibility renderer, single-thread Web export, no SharedArrayBuffer/COOP requirement, no service-worker cache. The workflow checks official engine and template SHA-256 digests and publishes only export/web. Open the page in a desktop browser, choose a hero, use arrows/WASD and E/C/H/J/T. Saves are browser-local IndexedDB, not synchronized with desktop saves or other browsers. Reload then press L to continue. Clearing site data removes the browser save.

This is a public development preview, not a final game release. Windows executable runtime and audio subjective testing remain separate from browser validation.
