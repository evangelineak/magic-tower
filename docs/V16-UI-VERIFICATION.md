# v16 bridge UI verification

This records targeted UI checks, not a deployment or complete game verification claim.

- `tests/test_endless_bridge_ui.gd`: **42 checks passed**. Both paid choices use actual new-run training/key pickups and safe step-by-step approaches. Covers remote approach without automatic interaction, repeated clicks, Escape, adjacent mouse opening, adjacent directional-key opening without an intermediate menu, explicit arm selection, failed storage, once-only payment, persisted visual states, ordinary free traversal after lowering, retained guards and legacy v15 behavior. The no-key branch deliberately uses an isolated UI position fixture, not a claimed legal playthrough.
- `tests/test_endless_bridge_art.gd`: **32 actual drawing calls passed**, including both orientations and raised/open/locked states. The parent reported native 40/64/128px contact-sheet approval.
- After the directional-key correction: original UI **221 checks**, target feedback **14 checks**, and `git diff --check` passed.

The confirmation surface shows the real core previews, temporary forgone kill gold, tool reward and irreversible loss of the other arm. Looking, approaching, closing and generic Enter do not choose an arm. Only an explicit short/loot confirmation submits the confirmed core action.

Parent-native gameplay validation and final whole-suite/deployment checks remain the release coordinator's responsibility. This file does not assert that v16 has been published or that browser gameplay passed.
