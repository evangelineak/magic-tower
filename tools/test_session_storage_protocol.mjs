// Pure production validator checks. Real IDB transactions are verified separately.
import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';import {fileURLToPath} from 'node:url';import path from 'node:path';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
let source=fs.readFileSync(path.join(root,'scripts/profile_storage_web.js'),'utf8');
source=source.replace(/\}\)\(\);\s*$/, 'globalThis.testAPI={snapshotCopy,upgradeSnapshot,validateDeathTransition,nextCounter,validRun,summaryOf,checkRunLedger,fresh,settleProfile};})();');
const context=vm.createContext({structuredClone,TextEncoder});new vm.Script(source).runInContext(context);
const api=context.testAPI;assert.ok(api);
const f=JSON.parse(fs.readFileSync(path.join(root,'tools/session_bridge_fixtures.json'),'utf8'));let checks=0;
const check=(value,label)=>{assert.ok(value,label);checks++};
check(f.risk_fresh.moves===0&&f.risk_fresh.floor===0&&f.risk_fresh.floor_seen[0]&&f.risk_fresh.floor_seen.slice(1).every(v=>!v),'fresh risk fixture did not alias later route discovery');
check(JSON.stringify(f.risk_fresh.floors)===JSON.stringify(f.first.floors),'same-seed fresh maps were not mutated by later fixture replay');
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
api.validateDeathTransition(f.risk_base,f.risk_dead,f.risk_delta);checks++;
const deathSummary=api.summaryOf(f.risk_dead,'defeat');
check(deathSummary.moves===f.risk_base.moves+1&&deathSummary.max_floor===f.risk_base.floor_seen.filter(Boolean).length,'death summary reflects real attempted fight');
for(const field of ['gold','kills','x','atk','focus','moves']){
 const bad=structuredClone(f.risk_dead);bad[field]+=2;
 assert.throws(()=>api.validateDeathTransition(f.risk_base,bad,f.risk_delta));checks++;
}
const deleted=structuredClone(f.risk_dead);deleted.floors[deleted.death_record.floor][deleted.death_record.y][deleted.death_record.x]='.';
assert.throws(()=>api.snapshotCopy(deleted,true));checks++;
for(const change of [r=>r.x=4294967296,r=>r.enemy='not-enemy',r=>r.start_hp=true,r=>r.extra=1]){
 const bad=structuredClone(f.risk_dead);change(bad.death_record);assert.throws(()=>api.snapshotCopy(bad,true));checks++;
}
assert.throws(()=>api.snapshotCopy({...f.risk_dead,mode:'safe'},true));checks++;
assert.throws(()=>api.snapshotCopy(f.risk_dead,false));checks++;
const living13=f.schema13_active.runs[f.schema13_active.slot.activeRunId].snapshot;
check(api.snapshotCopy(living13).version===13,'real old store payload remains readable without mutation');
const upgraded=api.upgradeSnapshot(living13);check(upgraded.version===19&&Object.keys(upgraded.death_record).length===0&&upgraded.run_id===living13.run_id,'old identity preserved, no death fabricated');
const archived13=f.schema13_archived.runs[f.schema13_archived.slot.activeRunId].snapshot;
check(api.summaryOf(archived13,'withdrawn').moves===archived13.moves,'real old archive summary unchanged');
console.log(`SESSION STORAGE PROTOCOL: PASS (${checks} checks; production pure validation, no IDB)`);
