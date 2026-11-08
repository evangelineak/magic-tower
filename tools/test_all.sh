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
for test in test_world test_choices test_adventure test_progression test_events test_reward_gates test_branches test_audio test_tactics test_riddle test_calibration test_expedition test_rescue test_oath test_oath_progression test_expedition_generation test_localization test_main test_adversarial test_generation; do
  echo "=== ${test} ==="
  run_godot --headless --path . --script "tests/${test}.gd"
done
run_godot --headless --path . --quit-after 30
