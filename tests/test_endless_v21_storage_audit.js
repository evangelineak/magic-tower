'use strict';
// Consumes an actual legally acquired native journey exported by the independent
// GD audit. This validates production JS protocol parity, not world replay or WebGL.
const fs=require('fs'),assert=require('assert');
const api=require('../scripts/endless_storage_web.js');
const trace=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
const values=new Map();let writes=0,quota=false,checks=0;
const storage={getItem:k=>values.has(k)?values.get(k):null,setItem:(k,v)=>{if(quota){const e=new Error('test quota');e.name='QuotaExceededError';throw e;}values.set(k,v);writes++;}};
function check(v,n){checks++;assert.ok(v,n);}
function world(op,s,rev,ended=false,record={}){return api.execute(storage,op,{snapshot:s,expected_revision:rev,record,previous_ended:ended});}
function unlock(id,rev){return api.execute(storage,'unlock_legacy',{legacy_id:id,expected_revision:rev});}
function same(){return values.get(api.KEY);}
const final=trace.snapshot;
const initial={...final,actions:final.actions.slice(0,2)};
let r=world('start_legacy',initial,0);
check(r.ok&&r.points===0,'JS initial real prefix accepted');
for(let i=3;i<=final.actions.length;i++){
 r=world('commit',{...final,actions:final.actions.slice(0,i)},r.revision,false);
 check(r.ok,'JS native lawful action prefix '+i);
}
const finishRevision=r.revision,prior=same();
let falseFinish=world('finish',final,finishRevision,false,trace.record);
check(!falseFinish.ok&&same()===prior,'JS false ended context refuses finish before write');
const replacement={...initial,seed:7};
let bad=world('start_legacy',replacement,r.revision,true);
check(!bad.ok&&same()===prior,'JS pending semantic flag/CAS prohibits overwrite');
quota=true;bad=world('finish',final,finishRevision,true,trace.record);
check(!bad.ok&&same()===prior,'JS quota leaves no finish nor award');quota=false;
r=world('finish',final,finishRevision,true,trace.record);
check(r.ok&&r.points===1&&require('node:util').isDeepStrictEqual(r.settlement,trace.settlement),'native and JS first award/receipt agree');
const fixed=same(),fixedWrites=writes;
let retry=world('finish',final,finishRevision,true,trace.record);
check(retry.ok&&same()===fixed&&writes===fixedWrites,'JS lost finish reply is read-only idempotent');
let receipt=JSON.stringify(r.settlement),oldRevision=r.revision;
bad=unlock('coin',r.revision);check(!bad.ok&&same()===fixed,'JS two-point price not affordable with one');
quota=true;bad=unlock('kit',r.revision);check(!bad.ok&&same()===fixed,'JS failed unlock retains full envelope');quota=false;
r=unlock('kit',r.revision);
check(r.ok&&r.points===0&&JSON.stringify(r.settlement)===receipt,'JS unlock spending preserves awarded receipt');
const unlocked=same(),unlockWrites=writes;
let delayed=world('finish',final,finishRevision,true,trace.record);
check(delayed.ok&&same()===unlocked&&writes===unlockWrites&&JSON.stringify(delayed.settlement)===receipt,'JS delayed finish after unlock returns receipt without paying twice');
retry=unlock('kit',oldRevision);check(retry.ok&&same()===unlocked&&writes===unlockWrites,'JS repeat owned unlock does not charge or write');
bad=unlock('mind',oldRevision);check(!bad.ok&&same()===unlocked,'JS competing other stale unlock rejected');
const kit={...initial,actions:[initial.actions[0],'legacy_kit']};
r=world('start_legacy',kit,r.revision,true);
check(r.ok&&r.points===0&&Object.keys(r.settlement).length===0,'JS unlocked next run clears receipt, not profile');
bad=world('finish',final,finishRevision,true,trace.record);check(!bad.ok,'JS old completed run cannot pay after start');
// Explicit raw protocol/corruption fixtures; no claim of earned deep progress.
const old={version:1,revision:7,run_id:4,active:trace.old_snapshot,finished:false,records:[]};
values.set(api.KEY,JSON.stringify(old));let oldBytes=same(),oldWrites=writes;
r=api.execute(storage,'read',{});
check(r.ok&&same()===oldBytes&&writes===oldWrites,'JS v1 read does not migrate bytes');
const oldEnded={...trace.old_snapshot,actions:[...trace.old_snapshot.actions,'retire']};
quota=true;bad=world('commit',oldEnded,7,false);check(!bad.ok&&same()===oldBytes,'JS failed migration retains v1 bytes');quota=false;
r=world('commit',oldEnded,7,false);check(r.ok&&JSON.parse(same()).version===2,'JS successful first commit upgrades atomically');
const oldRecord={run_id:4,seed:oldEnded.seed,max_floor:1,kills:0,gold:0,reason:'retired',rule_version:20};
r=world('finish',oldEnded,r.revision,true,oldRecord);
check(r.ok&&r.points===0&&r.profile.milestones.length===0&&r.settlement.awarded.length===0,'JS old version receives zero retroactive reward');
// Shape/schema failures retain their evidence byte-for-byte. These are not earned saves.
const settled=JSON.parse(same());
for(const [label,mutate] of [
 ['unknown envelope version',e=>e.version=99],
 ['negative profile balance',e=>e.profile.unlocks=['kit']],
 ['nonprefix milestones',e=>e.profile.milestones=[8]],
 ['unknown profile key',e=>e.profile.extra=true],
 ['receipt wrong run',e=>e.settlement.run_id=999],
 ['unfinished current record',e=>{e.finished=false;e.settlement={};}],
 ['v1 contains v21 active',e=>{e.version=1;delete e.profile;delete e.settlement;e.active=initial;}]
]){
 const corrupt=structuredClone(settled);mutate(corrupt);values.set(api.KEY,JSON.stringify(corrupt));const retained=same();
 const refusal=api.execute(storage,'read',{});
 check(!refusal.ok&&same()===retained,'JS rejects '+label+' without rewriting');
}
console.log('V21 STORAGE JS INDEPENDENT: PASS ('+checks+' checks; native earned trace protocol parity, no browser or independent game replay)');
