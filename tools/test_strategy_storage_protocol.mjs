// Compare the exact production JS draft algorithm to GDScript-generated vectors.
import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';import path from 'node:path';import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
let source=fs.readFileSync(path.join(root,'scripts/profile_storage_web.js'),'utf8');
source=source.replace(/\}\)\(\);\s*$/, 'globalThis.testAPI={strategyRank,strategyOffers,strategyDraft,validDraft,validStrategyPool,strategyPool};})();');
const context=vm.createContext({structuredClone,TextEncoder});new vm.Script(source).runInContext(context);const api=context.testAPI;
const v=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/legacy-strategy-vectors.json'),'utf8'));let checks=0;
const json=x=>JSON.parse(JSON.stringify(x));
for(const c of v.cases){
 assert.deepEqual(json(api.strategyOffers(c.seed,c.pool)),c.expected_offers);checks++;
 assert.deepEqual(json(api.strategyDraft(c.seed,c.pool)),c.expected_draft);checks++;
 assert.equal(api.validDraft(c.seed,c.expected_draft),true);checks++;
 for(const [id,rank] of Object.entries(c.ranks)){assert.equal(api.strategyRank(c.seed,id),rank);checks++;}
 for(const choice of ['none',...c.expected_offers]){assert.equal(api.validDraft(c.seed,{...c.expected_draft,choice}),true);checks++;}
}
for(const c of v.invalid_cases){assert.equal(api.validStrategyPool(c.pool),c.valid_pool);checks++;assert.deepEqual(json(api.strategyOffers(c.seed,c.pool)),c.expected_offers);checks++;}
for(const patch of [{extra:1},{version:true},{version:1.5},{offers:['study','study','study']},{choice:'unknown'}]){
 const draft=api.strategyDraft(0,['study','forager','channel','reserve']);Object.assign(draft,patch);assert.equal(api.validDraft(0,draft),false);checks++;
}
assert.equal(api.validDraft(0,{version:0,pool:[],offers:[],choice:'none'}),true);checks++;
assert.equal(api.validDraft(0,{version:0,pool:['study'],offers:[],choice:'none'}),false);checks++;
console.log(`STRATEGY STORAGE PROTOCOL: PASS (${checks} checks; real production JS vs GDScript draft/rank vectors, no combat or IDB)`);
