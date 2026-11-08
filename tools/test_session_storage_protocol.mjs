// Pure production validator checks. Real IDB transactions are verified separately.
import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';import {fileURLToPath} from 'node:url';import path from 'node:path';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
let source=fs.readFileSync(path.join(root,'scripts/profile_storage_web.js'),'utf8');
source=source.replace(/\}\)\(\);\s*$/, 'globalThis.testAPI={nextCounter,validRun,summaryOf,checkRunLedger,fresh,settleProfile};})();');
const context=vm.createContext({structuredClone,TextEncoder});new vm.Script(source).runInContext(context);
const api=context.testAPI;assert.ok(api);
const f=JSON.parse(fs.readFileSync(path.join(root,'tools/session_bridge_fixtures.json'),'utf8'));let checks=0;
const check=(value,label)=>{assert.ok(value,label);checks++};
const active={id:f.first.run_id,revision:0,status:'active',snapshot:f.first,last_op:{request_id:f.first.run_id,kind:'create',expected_slot:0,expected_revision:-1,hash:'a'.repeat(64),result_slot:1,result_revision:0}};
check(api.validRun(active),'actual full fresh world accepts exact operation shape');
for(const field of ['expected_slot','expected_revision','result_slot','result_revision'])for(const value of [true,'1',1.5,-2,1e100]){
 const bad=structuredClone(active);bad.last_op[field]=value;check(!api.validRun(bad),'bad counter '+field);
}
for(const change of [o=>o.extra=1,o=>o.hash='x'.repeat(64),o=>o.result_slot=3,o=>o.request_id='invalid']){
 const bad=structuredClone(active);change(bad.last_op);check(!api.validRun(bad),'malformed operation metadata');
}
const archived={id:f.first.run_id,revision:2,status:'archived',snapshot:f.withdrawn,last_op:{request_id:'f'.repeat(32),kind:'settle',expected_slot:1,expected_revision:1,hash:'a'.repeat(64),result_slot:2,result_revision:2}};
check(api.validRun(archived),'archived shape valid');
const summary=api.summaryOf(f.withdrawn,'withdrawn');
check(summary.moves===1&&summary.max_floor===1&&summary.outcome==='withdrawn','actual summary not caller supplied');
const decision=api.settleProfile(api.fresh(),f.first.run_id,summary);check(decision.ok,'pure ledger accepts derived summary');
api.checkRunLedger(archived,decision.profile);checks++;
for(const bad of ['missing','wrong-summary','active-receipt']){
 const p=structuredClone(decision.profile),r=structuredClone(archived);
 if(bad==='missing')delete p.receipts[r.id];else if(bad==='wrong-summary')p.receipts[r.id].summary.moves++;else {r.status='active';r.last_op.kind='save';r.last_op.result_slot=1;r.snapshot=f.first_after_step;}
 assert.throws(()=>api.checkRunLedger(r,p));checks++;
}
for(const [base,outcome,floor] of [[f.chapter1_ended,'chapter1',5],[f.victory_ended,'victory',8]])check(api.summaryOf(base,outcome).max_floor===floor,'real legal win summary');
for(const outcome of ['chapter1','victory','defeat']){assert.throws(()=>api.summaryOf(f.withdrawn,outcome));checks++;}
check(api.nextCounter(9999999)===10000000,'last valid counter value');
assert.throws(()=>api.nextCounter(10000000),/COUNTER_EXHAUSTED/);checks++;
console.log(`SESSION STORAGE PROTOCOL: PASS (${checks} checks; production pure validation, no IDB)`);
