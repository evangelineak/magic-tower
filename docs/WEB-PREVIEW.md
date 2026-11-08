# Optional legacy allocation Web preview

Root remains v0.17, rebuilt from pinned Web source `4122fa416091eb3d89c7825b6d9eabd55d7c273e`.
Optional `/preview/` game source is `add23ffbf8e17549f9eb34ffc478f3da46190333`.

Actual Linux gameplay, finite legacy point allocation, emergency focus, persistence,
and production JavaScript IndexedDB transactions are verified. The cloud Chromium
browser blocklists WebGL2; no security setting was bypassed. **Godot Web gameplay
and its engine-to-JavaScript bridge remain unverified.** Export is not runtime QA.

The Session database does not import or delete old v0.17 saves. Schema16 and older
journeys retain zero allocation and their original talent offers. Start an explicit
new journey to allocate capacity earned from first recorded floors3/5/8. Repeated
death does not earn more. Existing records remain. Close old game tabs before
reloading the new version; concurrent stale writers cannot overwrite newer data.

Single-thread Web includes `scripts/*.js`; no SharedArrayBuffer, COOP/COEP or service
worker is required. Root remains separate while this optional build is playtested.
Windows exports are not actual Windows runtime validation; audio remains unaudited.
