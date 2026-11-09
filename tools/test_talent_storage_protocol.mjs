import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';import path from 'node:path';import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
let source=fs.readFileSync(path.join(root,'scripts/profile_storage_web.js'),'utf8');
source=source.replace(/\}\)\(\);\s*$/, 'globalThis.testAPI={talentDraft,validTalentDraft,snapshotCopy,upgradeSnapshot,validateDeathTransition};})();');
const context=vm.createContext({structuredClone,TextEncoder});new vm.Script(source).runInContext(context);const a=context.testAPI;
let checks=0;const json=x=>JSON.parse(JSON.stringify(x));
const vectors=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/talent-storage-vectors.json')));
for(const c of vectors.cases){assert.deepEqual(json(a.talentDraft(c.seed,c.expected.version)),c.expected);checks++;assert.equal(a.validTalentDraft(c.seed,c.expected),true);checks++;}
for(const patch of [{version:true},{version:0.5},{extra:1},{offers:[[],[],[]]}]){assert.equal(a.validTalentDraft(0,{...a.talentDraft(0),...patch}),false);checks++;}
for(const label of ['active','death']){
 const old=JSON.parse(fs.readFileSync(path.join(root,`tests/fixtures/schema15-${label}.json`)));a.snapshotCopy(old,label==='death');checks++;
 const up=a.upgradeSnapshot(old);assert.equal(up.version,19);assert.equal(up.last_kill_kind,'');assert.deepEqual(json(up.talent_draft),json(a.talentDraft(old.seed_value,0)));checks+=3;
}
const f=JSON.parse(fs.readFileSync(path.join(root,'tools/session_bridge_fixtures.json')));
a.validateDeathTransition(f.risk_base,f.risk_dead,f.risk_delta);checks++;
const bad=structuredClone(f.risk_dead);bad.last_kill_kind=bad.last_kill_kind==='s'?'g':'s';assert.throws(()=>a.validateDeathTransition(f.risk_base,bad,f.risk_delta));checks++;
for(const patch of [{last_kill_kind:'garbage'},{talent_draft:{version:1,offers:[['iron_skin','iron_skin','iron_skin'],[],[]]}}]){assert.throws(()=>a.snapshotCopy({...f.first,...patch}));checks++;}
console.log(`TALENT STORAGE PROTOCOL: PASS (${checks} checks; production JS vs actual GDScript vectors and genuine schema15, no IDB)`);
