# Optional talent folio Web preview

The stable root remains the v0.17 game, rebuilt from fixed Web source
`4122fa416091eb3d89c7825b6d9eabd55d7c273e`.
The optional `/preview/` path uses verified development game source
`32b8228cfddb99995fb822ef6516693323c8af94`.

Native Linux gameplay, persistence, actual strategy and talent folio effects and production
JavaScript IndexedDB transactions are verified. The cloud browser explicitly
blocklists WebGL2; a normal fresh Chromium profile has the same result, and no
other installed supported browser was found. No sandbox, blocklist or security
setting was bypassed. **Godot Web gameplay and the engine-to-JavaScript bridge
remain unverified.** Export success is not a substitute for this test.

The new Session database does not import or delete legacy v0.17 save files.
Keep the stable root available while this opt-in path receives real playtesting.
This Web preset includes `scripts/*.js`, required by the Session bridge. The Web
PCK's production JS and compiled World match the verified desktop package.
Single-thread export needs WebGL2, but no SharedArrayBuffer/COOP/COEP or service
worker. Windows binaries remain cross-exported, not Windows runtime certified.

Existing schema15 journeys keep their original talent choices on upgrade. Start
an explicit new journey for the new four-choose-three folios; old profiles and
receipts are retained.
