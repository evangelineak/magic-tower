#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
for test in test_world test_choices test_adventure test_progression test_events test_main test_adversarial test_generation; do
  echo "=== ${test} ==="
  "$GODOT_BIN" --headless --path . --script "tests/${test}.gd"
done
"$GODOT_BIN" --headless --path . --quit-after 30
