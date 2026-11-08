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
for test in test_world test_choices test_adventure test_progression test_events test_reward_gates test_main test_adversarial test_generation; do
  echo "=== ${test} ==="
  run_godot --headless --path . --script "tests/${test}.gd"
done
run_godot --headless --path . --quit-after 30
