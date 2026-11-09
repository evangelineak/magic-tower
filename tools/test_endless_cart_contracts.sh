#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/tower-cart-contracts.XXXXXX")"
trap 'status=$?; if [ "$status" -eq 0 ]; then rm -rf "$tmp"; else printf "Cart test evidence retained: %s\n" "$tmp" >&2; fi' EXIT
run_godot() {
 local name="$1"; shift
 local status=0
 if command -v timeout >/dev/null 2>&1; then
  timeout 240 "$GODOT_BIN" --headless --path . --script "$@" >"$tmp/$name.log" 2>&1 || status=$?
 else
  "$GODOT_BIN" --headless --path . --script "$@" >"$tmp/$name.log" 2>&1 || status=$?
 fi
 if [ "$status" -ne 0 ] || grep -Eq '^(SCRIPT ERROR:|ERROR:)' "$tmp/$name.log"; then
  cat "$tmp/$name.log"; return 1
 fi
}
extract_json() {
 python3 - "$tmp/$1.log" "$2" "$tmp/$1.json" <<'PY'
import json,sys
lines=[line[len(sys.argv[2]):] for line in open(sys.argv[1]) if line.startswith(sys.argv[2])]
assert len(lines)==1, 'missing or duplicate structured test result'
data=json.loads(lines[0])
assert data.get('failures',0) in (0,[]),data
assert data.get('schedule_failures',[])==[],data
with open(sys.argv[3],'w') as output:json.dump(data,output)
print(sys.argv[2].strip(), 'PASS', data.get('checks',''), 'samples',len(data.get('samples',[])))
PY
}
run_godot space tools/export_endless_v19_space.gd
extract_json space 'SPACE_EXPORT '
python3 tools/audit_endless_v19_space.py --production-json "$tmp/space.json" >"$tmp/space-proof.json"
python3 - "$tmp/space-proof.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1]));assert x['ok'] and len(x['production_cross_checks'])>0
assert all(not r['violations'] for r in x['independent']+x['production_cross_checks'])
print('CART INDEPENDENT SPACE: PASS',len(x['production_cross_checks']),'generated maps')
PY
run_godot resources tests/test_endless_v19_cart_independent.gd
extract_json resources 'CART_INDEPENDENT_RESULT '
run_godot native tests/test_endless_v19_snapshot_store.gd -- "$tmp/resources.json"
extract_json native 'CART_NATIVE_RESULT '
printf 'CART CONTRACT GATE: PASS\n'
