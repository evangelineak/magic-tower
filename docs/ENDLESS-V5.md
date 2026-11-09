# Endless v5: four route geometries and readable interactions

New journeys use v5. Existing v1–v4 journeys replay their original immutable rules, not the new maps. v5 keeps v4 tactical combat and v3 messenger deductions.

## What changes

Two new authored geometry families join courtyard and causeway:

- **Vertical bastions** split the floor into left/right courts. A northern heavy gate competes with a southern two-sentry passage.
- **Switchback gorge** uses a stepped partition across the floor. A caster guards the short crossing while two sentries cover the longer offset passage.

This is four deterministic layout families, not arbitrary unbounded procedural variety. Seeds choose the family sequence; floor statistics continue scaling within safety limits. Every generated floor checks both routes, mandatory guards, closed treasure/vault rooms, an outside key, and matched entry/exit stairs. Structural reachability is not a claim that every player decision remains survivable.

New original flat interaction art distinguishes a training stele, sealed cargo, caravan, sword/shield training kit, flask, key and closed arch door. Their silhouettes were inspected natively at 24/40/64/128 pixels. Existing treasure symbols and stairs remain to avoid unnecessary visual clutter.

Nearby mouse tooltips now explain training, relic caps, cargo and camp actions, and fit up to fourteen lines instead of clipping tactical information after eight. First aid wording explicitly distinguishes foregoing attack/defence growth from still gaining capped tactical training.

## Verification

- Core: 21,242 checks including 96 seeds × 6 floor indices (including 1,000,000), independent bidirectional graph checks, and 8 seeds × 2 routes × 32 floors of actual actions, battle costs and replay.
- UI: 186 checks, including all four layouts, stance persistence and bounded tooltip geometry.
- Native gameplay seed 137239272: restored the previous v4 save before explicitly starting v5. Cleared floor 1 causeway, floor 2 vertical-bastion twin sentries, and floor 3 switchback caster by normal controls. Reached floor 4 at HP202/ATK29/DEF17, 60 gold, one key, four kills. L reload preserved this state. Floor-to-floor stairs remained at the same coordinate.
- Interaction art: 35 actual drawing callbacks plus native contact sheet.
- Real Chrome production storage: 67 checks across five rule versions, Web Locks/localStorage and second browsing context. This is storage verification, not Godot Web engine gameplay.

Cloud WebGL remains blocked; Godot Web gameplay is not verified here. Rankings remain explicitly device-local. `GLOBAL-RANKING-PLAN.md` is research only: no backend, account, payment or player-data upload has been performed.

New runs now use v6; see [ENDLESS-V6.md](ENDLESS-V6.md). Existing v5 journeys keep their rules.
