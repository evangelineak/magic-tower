import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';import path from 'node:path';import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
let source=fs.readFileSync(path.join(root,'scripts/profile_storage_web.js'),'utf8');
source=source.replace(/\}\)\(\);\s*$/, 'globalThis.testAPI={allocationCopy,validLegacyPoints,snapshotCopy,upgradeSnapshot,validateDeathTransition};})();');
const context=vm.createContext({structuredClone,TextEncoder});new vm.Script(source).runInContext(context);const a=context.testAPI;
let checks=0;const json=x=>JSON.parse(JSON.stringify(x));
for(const input of [undefined,{}, {study:0,reserve:0}]){assert.deepEqual(json(a.allocationCopy(input)),{study:0,reserve:0});checks++;}
for(const input of [null,[],true,{study:true,reserve:0},{study:0.5,reserve:0},{study:3,reserve:0},{study:-1,reserve:0},{study:1},{study:1,reserve:0,extra:0}]){assert.throws(()=>a.allocationCopy(input));checks++;}
for(const label of ['active','death']){
 const old=JSON.parse(fs.readFileSync(path.join(root,`tests/fixtures/schema16-${label}.json`)));a.snapshotCopy(old,label==='death');checks++;
 const up=a.upgradeSnapshot(old);assert.equal(up.version,18);assert.equal(up.legacy_reserves,0);assert.deepEqual(json(up.legacy_points),{version:0,capacity:0,study:0,reserve:0});assert.equal(a.validLegacyPoints(up),true);checks+=4;
}
const f=JSON.parse(fs.readFileSync(path.join(root,'tools/session_bridge_fixtures.json')));
// The browser's forged-pool probe must remain internally consistent, so the
// transaction rejects its unauthorized birth pool, not an unrelated points cap.
const deniedBirth=structuredClone(f.draft_fresh);deniedBirth.draft={version:1,pool:[],offers:[],choice:'none'};deniedBirth.legacy_points={version:1,capacity:0,study:0,reserve:0};deniedBirth.legacy_reserves=0;
a.snapshotCopy(deniedBirth);checks++;
for(const key of ['first','draft_fresh','draft_selected','risk_dead']){a.snapshotCopy(f[key],key==='risk_dead');checks++;}
for(const patch of [{version:true},{capacity:3},{study:3},{study:1,reserve:2},{extra:0}]){
 const bad=structuredClone(f.draft_selected);Object.assign(bad.legacy_points,patch);assert.equal(a.validLegacyPoints(bad),false);checks++;
}
const pending=structuredClone(f.draft_fresh);pending.legacy_points.study=1;assert.equal(a.validLegacyPoints(pending),false);checks++;
const lethal=structuredClone(f.risk_dead);lethal.legacy_reserves++;assert.throws(()=>a.validateDeathTransition(f.risk_base,lethal,f.risk_delta));checks++;
console.log(`LEGACY POINTS STORAGE PROTOCOL: PASS (${checks} checks; production validation and authentic16 migration, no IDB)`);
