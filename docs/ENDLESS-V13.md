# Endless v13: a floor rule worth deciding, not another permanent stat

New journeys use v13; existing v1–v12 logs keep their rules. Five map families, guard positions, valuable sealed doors and paired stairs are unchanged. This release adds a seeded optional rule at the entrance, not new room geometry.

## Entrance inscriptions

The small original flat mechanical badge on the entrance staircase opens a read-only comparison of both remaining routes before/after activation. Only standing on or orthogonally adjacent to that floor's entrance permits payment. The explicitly labelled confirmation button states the price and irreversible scope. Closing, inspecting, unavailable purchases and failed saves do not charge. Activation lasts for that floor, including revisits, and cannot be bought twice. No permanent attributes or equipped consumables are spent or restored.

- **Shock, 18 gold:** the player's first hit in each battle deals twice its normal post-armour damage. The enemy's first active attack also doubles: scout opening first, otherwise its first counterattack. The charging guard's first counterattack therefore reaches four times normal. Fixed brace/mantle/ward reductions are applied afterward and do not double. The thorn guard's first reflection becomes four; later reflections remain two.
- **Silence, 10 gold:** neither side can recover HP inside combat. Priest regeneration and the player's reaping recovery both stop. Medicine and supplies outside combat are unchanged. Silence is a seeded candidate only on floors containing a priest; otherwise the inscription is shock.

Zero-effect purchases are refused based on remaining enemies and current build. Default unactivated combat delegates to v12 unchanged. Activated battles resolve actual events in order and stop at death; fatal reflection, opening attacks and recovery timing remain explicit. A purchase can worsen the route. The comparison includes the current tactic, equipment and sequential one-use items, not future growth or a promise to clear the tower.

## Play and persistence evidence

Native play restored the old v12 journey unchanged, then explicitly created v13 seed929016075. With no gold the badge displayed the 18-gold price and disabled purchase. A legitimate key and sealed 40-gold chest funded activation at the entrance: gold40→22, HP150 unchanged, no training/stat injection. The panel showed the single scout route20→20 HP loss, but charging guard/wizard route34→0. Actual adjacent-click battles each killed in one hit with zero damage; HP150, gold69 and kills2 survived reload. This manually verifies shock, not a manual silence playthrough; silence's timing is covered by automated independent checks.

The route's rune badge, comparison, readable tooltip and adjacent interaction were inspected at actual game scale. Remote object clicks now explain 'move orthogonally adjacent' beside the target rather than solely in the sidebar. Native remote-door clicking left position/resources unchanged. A native-discovered overlay issue was fixed: target tooltips no longer overlap combat settlement, with hide/restore regression checks.

Core11080 checks and independent68880 controlled event combinations/887880 assertions passed. Twelve legal100-floor independent policies and full action replay passed, with intermediate50-floor states retained. Native storage477, atomic safe-walk120, Node574, actual Chrome production localStorage/Web Locks/callback/second-context271 checks passed. The browser harness restores its test-origin data. Final aggregate and exact-commit publication gates are checked separately.

[Independent audit and raw evidence](benchmarks/ENDLESS-V13-RUNE-AUDIT.md) show why blindly buying is not optimal: seed42 main route spent1568 gold on92 inscriptions but total damage rose143→151. A simple lower-net-damage policy spent162 and reduced it to107. That policy selected no silence inscriptions on the two sampled seeds, so the two options are not advertised as equally useful. Gold still accumulates strongly; this adds a decision, not a complete economy fix.

Godot Web-engine gameplay remains unverified in the WebGL-blocklisted cloud browser. Browser persistence testing is not engine play. Rankings remain device-local; no global backend, account, fee or player-data upload was created.
