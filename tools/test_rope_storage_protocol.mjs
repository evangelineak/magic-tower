// Production JS validator, migration and death-boundary tests. This is not IDB.
import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';import path from 'node:path';import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
let source=fs.readFileSync(path.join(root,'scripts/profile_storage_web.js'),'utf8');source=source.replace(/\}\)\(\);\s*$/, 'globalThis.testAPI={ropeBirth,validRope,snapshotCopy,upgradeSnapshot,validateDeathTransition};})();');
const context=vm.createContext({structuredClone,TextEncoder});new vm.Script(source).runInContext(context);const a=context.testAPI;let checks=0;const json=x=>JSON.parse(JSON.stringify(x));
for(const layout of [1,2]){assert.deepEqual(json(a.ropeBirth(layout)),layout===2?{version:1,state:'ready'}:{version:0,state:'off'});checks++;}
for(const label of ['active','death','pending','allocated']){
 const old=JSON.parse(fs.readFileSync(path.join(root,`tests/fixtures/rope_schema18-${label}.json`)));assert.equal(old.version,18);a.snapshotCopy(old,label==='death');checks+=2;
 const up=a.upgradeSnapshot(old);assert.equal(up.version,19);assert.deepEqual(json(up.rope),{version:0,state:'off'});checks+=2;
 for(const key of Object.keys(old))if(key!=='version'){assert.deepEqual(json(up[key]),old[key]);checks++;}
 a.snapshotCopy(up,label==='death');checks++;
}
const f=JSON.parse(fs.readFileSync(path.join(root,'tools/session_bridge_fixtures.json')));
assert.equal(f.first.version,19);a.snapshotCopy(f.first);assert.deepEqual(f.first.rope,{version:1,state:'ready'});checks+=3;
for(const rope of [{version:true,state:'ready'},{version:1.5,state:'ready'},{version:1,state:'off'},{version:0,state:'spent'},{version:1,state:'ready',extra:1},null,[],{version:2,state:'ready'}]){
 const s=structuredClone(f.first);s.rope=rope;assert.equal(a.validRope(s),false);assert.throws(()=>a.snapshotCopy(s));checks+=2;
}
for(const value of [null,0,1,'true']){const bad=structuredClone(f.first);bad.expedition_started=value;assert.equal(a.validRope(bad),false);checks++;}
for(const state of ['ready','spent']){
 const s=structuredClone(f.victory_ended);s.rope={version:1,state};assert.equal(a.validRope(s),true);checks++;
 for(const revision of [0,1,2,4]){const bad=structuredClone(s);bad.expedition_revision=revision;assert.equal(a.validRope(bad),false);assert.throws(()=>a.snapshotCopy(bad,true));checks+=2;}
}
for(const change of [s=>s.expedition_started=false,s=>s.floor_seen=s.floor_seen.slice(0,5),s=>s.floor_seen[5]=false,s=>s.layout_revision=1]){
 const s=structuredClone(f.victory_ended);s.rope={version:1,state:'spent'};change(s);assert.equal(a.validRope(s),false);assert.throws(()=>a.snapshotCopy(s,true));checks+=2;
}
const death=structuredClone(f.risk_dead);death.rope={version:0,state:'off'};assert.throws(()=>a.validateDeathTransition(f.risk_base,death,f.risk_delta));checks++;
console.log(`ROPE STORAGE PROTOCOL: PASS (${checks} checks; production JS and genuine schema18 migration, no IDB)`);
