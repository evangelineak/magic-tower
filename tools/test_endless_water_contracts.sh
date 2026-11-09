#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/tower-water-contracts.XXXXXX")"
trap 'status=$?; if [ "$status" -eq 0 ]; then rm -rf "$tmp"; else printf "Water test evidence retained: %s\n" "$tmp" >&2; fi' EXIT
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
rows=[line[len(sys.argv[2]):] for line in open(sys.argv[1]) if line.startswith(sys.argv[2])]
assert len(rows)==1, 'missing or duplicate structured test result'
data=json.loads(rows[0]);assert data.get('failures',0) in (0,[]),data
assert not data.get('problems',[]),data
with open(sys.argv[3],'w') as out:json.dump(data,out)
print(sys.argv[2].strip(),'PASS','checks',data.get('checks',''),'samples',len(data.get('samples',[])))
PY
}
run_godot grids tools/export_endless_v22_water_space.gd
extract_json grids 'WATER_SPACE_EXPORT '
python3 tools/audit_endless_v22_water_space.py --production-json "$tmp/grids.json" >"$tmp/proof.json"
python3 - "$tmp/proof.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1]));assert x['ok'] and len(x['production_cross_checks'])==128
assert len(x['independent'])==4 and len(x['mutations'])>=8
assert all(m['rejected'] for m in x['mutations'])
assert all(d['all_states_recover_without_new_battle_or_key'] for r in x['independent']+x['production_cross_checks'] for d in r['directions'])
print('WATER INDEPENDENT SPACE: PASS',len(x['production_cross_checks']),'generated maps;',len(x['mutations']),'rejected mutations')
PY
run_godot world tests/test_endless_v22_water_independent.gd
extract_json world 'WATER_INDEPENDENT_WORLD '
python3 - "$tmp/world.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1]));assert len(x['reports'])==4
assert {(r['variant'],r['initial']) for r in x['reports']}=={(0,0),(0,1),(1,0),(1,1)}
print('WATER LEGAL WORLD: PASS four variant/state histories')
PY
printf 'WATER CONTRACT GATE: PASS\n'
