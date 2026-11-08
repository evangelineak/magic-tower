# Optional single-use ferry-rope Web preview

Root remains v0.17, rebuilt from fixed source4122fa416091eb3d89c7825b6d9eabd55d7c273e.
Optional /preview/ game sourceb497f2d4eee6a5ed7ab32c6c717a0b89b530d6e5.

Six-floor one-use rope trades1focus for crossing behind the living guardian. No kill,
gold, recovery or new resources. It snaps, so return needs a real route; ordinary
Undo remains available. New journeys only; old schema18 or earlier receive rope-off,
not a map reset. Existing Session journeys can use the V real-position inset.

Actual native keyboard play from new seed1 reached309moves, crossed at310,
verified unchanged356HP/362gold/19kills, used1focus, Undo and load equality.
Production JavaScript callback+IndexedDB109 tests passed separately.
Cloud Chromium blocklists WebGL2. No security setting was bypassed. Godot Web
engine gameplay and its engine-to-JavaScript bridge remain unverified; successful
export is not runtime QA. Windows remains cross-export-only, audio unaudited.

Session storage does not import or delete legacy v0.17 saves. Close old game tabs
before reloading; stale writers cannot overwrite the active state. Single-thread
Web includes scripts/*.js, requires no SharedArrayBuffer/COOP/COEP or service
worker. Keep root stable while this optional build is playtested.
