#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
# Install the matching official export templates in Godot first. Never downloads
# or runs an unverified helper, changes credentials, or publishes a release.
mkdir -p export/linux export/windows
"$GODOT_BIN" --headless --path . --editor --import --quit
"$GODOT_BIN" --headless --path . --export-release 'Linux x86_64'
"$GODOT_BIN" --headless --path . --export-release 'Windows x86_64'
for target in linux windows; do
  "$GODOT_BIN" --headless --path . --script tools/export_license.gd -- "export/$target/GODOT-LICENSES.txt"
  cp docs/PLAYING.txt "export/$target/PLAYING.txt"
  cp assets/fonts/LICENSE-OFL.txt "export/$target/FONT-LICENSE.txt"
  (cd "export/$target" && sha256sum magic-tower* GODOT-LICENSES.txt FONT-LICENSE.txt PLAYING.txt > SHA256SUMS)
done
# This is a Linux runtime check, not a claim of Windows execution.
timeout 60 export/linux/magic-tower.x86_64 --headless --quit-after 30 -- --seed=0
printf '\nDesktop builds are in export/{linux,windows}. Windows must still be tested on Windows.\n'
