# Endless v4: tactical builds and original actor silhouettes

New runs use rule v4. v1/v2/v3 replays remain frozen and keep their original rules. This extends v3's 15×15 exploration, two route layouts and historical messenger deduction; it is not a new global ranking service.

## Decisions, not just bigger numbers

Press B for the build panel. Beside a merchant, freely choose one stance; away from a merchant the panel is read-only. Switching is saved as a replayable action, not a temporary UI setting.

- Pierce reduces enemy defence by 2 + effective level.
- Brace reduces the first retaliation by up to 3 + effective level.
- Reap restores up to 2 + effective level after a surviving victory, capped at actual battle damage. It cannot rescue a lethal hit.

Training begins at 1 and each floor's skill choice advances it to a normal cap of 3. Optional vault relics add one each, capped at two, allowing an effective cap of 5. Combat shows gross damage, post-victory recovery and net loss separately. Route summaries check sequential survival rather than assuming future healing can pay for a fatal fight.

## Art

Original flat vector silhouettes replace the endless hero and four enemy archetypes. Traveller, spear wielder, shield bearer and crescent-blade reaper have different shapes, not merely recolours. Heavy sentry, twin-route raider, caster and vault guardian use a shared dark-outline palette. No third-party character assets are used. `tests/actor_art_preview.tscn` shows 40/64/128 pixel contact sheets.

## Verified scope

- 70 Godot test scripts plus protocol suites passed locally. v4 core has 11,332 assertions; UI has 163, actor callbacks 36, Node storage 156.
- Actual Chrome production storage harness: 54 checks, including four rule versions, Web Locks/localStorage and a second browsing context. This does **not** execute Godot Web gameplay.
- Native game: restored an existing v3 floor-4 run, then explicitly started v4 seed 1474480157. Selected Reap at camp, trained to level 2, confirmed remote switch unavailable, and fought the first heavy sentry. HP 170→168 matched gross damage 6 and recovery 4; L reload preserved HP, stance, kill and resources without duplicate reward.
- Native contact sheet and live game checked actor silhouettes and build panel text. Real-event core tests separately cover both relics, level 5, stance tradeoffs and lethal-before-heal cases.

Cloud browser WebGL remains blocklisted; no claim of Godot Web engine play verification. Records remain device-local, version-labelled and untrusted for a global leaderboard. No ranking backend or new account has been created.

New runs now use v5; see [ENDLESS-V5.md](ENDLESS-V5.md). Existing v4 journeys retain these rules.
