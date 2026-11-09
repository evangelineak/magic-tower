#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
run_godot() {
  # GDScript can emit SCRIPT ERROR while a SceneTree test still exits zero.
  # Preserve the full output and fail the gate on either failure signal.
  local log status=0
  log="$(mktemp)"
  if command -v timeout >/dev/null 2>&1; then
    timeout 240 "$GODOT_BIN" "$@" >"$log" 2>&1 || status=$?
  else
    "$GODOT_BIN" "$@" >"$log" 2>&1 || status=$?
  fi
  cat "$log"
  if grep -q '^SCRIPT ERROR:' "$log"; then
    printf 'Gate failed: GDScript runtime error, regardless of process exit.\n' >&2
    status=1
  fi
  rm -f "$log"
  return "$status"
}

# Fresh checkouts contain import settings, not the generated .godot cache.
# Reimport first so asset/font edits are exercised rather than stale binaries.
run_godot --headless --path . --editor --import --quit
for test in test_world test_choices test_adventure test_progression test_battle_timeline test_risk_world test_session_world test_session test_session_storage test_session_settlement test_death_storage test_settlement_routes test_legacy_profile test_legacy_points_world test_legacy_points_battle test_legacy_points_storage test_cargo_storage test_cargo_world test_exploration test_exploration_review test_tactical_forecast test_tactical_review test_rope_world test_rope_storage test_legacy_strategy test_strategy_world test_strategy_battle test_strategy_storage test_talent_storage test_talent_draft_world test_talent_draft_battle test_legacy_store_native test_attunement test_attunement_world test_events test_reward_gates test_branches test_audio test_tactics test_riddle test_calibration test_expedition test_rescue test_oath test_oath_progression test_travel_audit test_navigation test_audit_puzzle test_winch_flank test_maul test_usability test_safe_walk test_mouse_guidance test_map_symbols test_map_dimensions test_endless_generation test_endless_world test_endless_v2 test_endless_v3 test_endless_v4 test_endless_v5 test_endless_v6 test_endless_v7 test_endless_v8 test_endless_v9 test_endless_v10 test_endless_v11 test_endless_v16 test_endless_bridge_ui test_endless_bridge_art test_endless_v15 test_endless_v15_visual_ui test_endless_v14 test_endless_camp_floor test_endless_v13 test_endless_v13_oracle test_endless_rune_ui test_endless_target_feedback_ui test_endless_v12 test_endless_v12_oracle test_endless_v12_ui test_endless_gear_ui test_endless_camp_ui test_endless_walk_store test_endless_contract_ui test_endless_growth_ui test_endless_actor_art test_endless_enemy_v7_art test_endless_interaction_art test_endless_store test_endless_ui test_adjacent_click test_layout test_expedition_generation test_localization test_main test_adversarial test_generation; do
  echo "=== ${test} ==="
  run_godot --headless --path . --script "tests/${test}.gd"
done
run_godot --headless --path . --quit-after 30

# Pure cross-runtime protocol checks; browser IndexedDB QA is separate.
node tools/test_profile_vectors.mjs

node tools/test_session_bridge_syntax.mjs

node tools/test_session_storage_protocol.mjs

node tools/test_strategy_storage_protocol.mjs

node tools/test_talent_storage_protocol.mjs

node tools/test_legacy_points_storage_protocol.mjs

node tools/test_cargo_storage_protocol.mjs

node tools/test_rope_storage_protocol.mjs

node tests/test_endless_storage_web.js
