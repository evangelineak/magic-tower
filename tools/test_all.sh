#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
run_godot() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 240 "$GODOT_BIN" "$@"
  else
    "$GODOT_BIN" "$@"
  fi
}
# Fresh checkouts contain import settings, not the generated .godot cache.
# Reimport first so asset/font edits are exercised rather than stale binaries.
run_godot --headless --path . --editor --import --quit
for test in test_world test_choices test_adventure test_progression test_session_world test_session test_session_storage test_session_settlement test_settlement_routes test_legacy_profile test_legacy_store_native test_attunement test_attunement_world test_events test_reward_gates test_branches test_audio test_tactics test_riddle test_calibration test_expedition test_rescue test_oath test_oath_progression test_travel_audit test_navigation test_audit_puzzle test_winch_flank test_maul test_usability test_safe_walk test_layout test_expedition_generation test_localization test_main test_adversarial test_generation; do
  echo "=== ${test} ==="
  run_godot --headless --path . --script "tests/${test}.gd"
done
run_godot --headless --path . --quit-after 30

# Pure cross-runtime protocol checks; browser IndexedDB QA is separate.
node tools/test_profile_vectors.mjs

node tools/test_session_bridge_syntax.mjs

node tools/test_session_storage_protocol.mjs
