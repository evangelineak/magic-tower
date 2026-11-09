'use strict';
// Native-earned action logs and records, consumed only for JS protocol parity.
const fs=require('node:fs'),assert=require('node:assert/strict');
const api=require('../scripts/endless_storage_web.js');
const trace=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
const mem=new Map();let writes=0,checks=0;
const storage={getItem:k=>mem.get(k)??null,setItem:(k,v)=>{mem.set(k,v);writes++;}};
function check(ok,label){checks++;assert.ok(ok,label);}
function call(op,snapshot,expected_revision,previous_ended=false,record={}){return api.execute(storage,op,{snapshot,expected_revision,previous_ended,record});}
function prefix(s){return {...s,actions:s.actions.slice(0,2)};}
function play(s,r){
 r=call('start_legacy',prefix(s),r.revision,true);check(r.ok,'cross-rule run start');
 for(let i=3;i<=s.actions.length;i++){
  r=call('commit',{...s,actions:s.actions.slice(0,i)},r.revision);
  check(r.ok,'native-earned prefix '+s.version+'/'+i);
 }
 return r;
}
let r=api.execute(storage,'read',{});
r=play(trace.old_snapshot,r);
r=call('finish',trace.old_snapshot,r.revision,true,trace.old_record);
check(r.ok&&r.points===1&&r.profile.milestones.join(',')==='3','real v21 result awards shared milestone');
r=api.execute(storage,'unlock_legacy',{legacy_id:'kit',expected_revision:r.revision});
check(r.ok&&r.points===0,'v21 point buys shared kit');
const preStart=r.revision;
r=call('start_legacy',prefix(trace.same_snapshot),preStart,true);
check(r.ok&&r.profile.unlocks[0]==='kit'&&r.settlement.run_id===undefined,'v22 inherits kit, clears receipt');
const retained=mem.get(api.KEY),count=writes;
let retry=call('start_legacy',prefix(trace.same_snapshot),preStart,true);
check(retry.ok&&mem.get(api.KEY)===retained&&writes===count,'v22 start lost reply read-only');
let other={...prefix(trace.same_snapshot),seed:43};
check(!call('start_legacy',other,preStart,false).ok&&mem.get(api.KEY)===retained,'different stale v22 start conflict');
// The native test intentionally abandons an alive initial run; mirror run IDs.
r=call('start_legacy',prefix(trace.same_snapshot),r.revision,false);
check(r.ok,'alive run abandoned without award');
for(let i=3;i<=trace.same_snapshot.actions.length;i++){
 r=call('commit',{...trace.same_snapshot,actions:trace.same_snapshot.actions.slice(0,i)},r.revision);
 check(r.ok,'v22 same-depth native prefix '+i);
}
r=call('finish',trace.same_snapshot,r.revision,true,trace.same_record);
check(r.ok&&r.points===0&&r.settlement.awarded.length===0,'v22 cannot re-award old third floor');
r=play(trace.deep_snapshot,r);
r=call('finish',trace.deep_snapshot,r.revision,true,trace.deep_record);
check(r.ok&&r.points===1&&r.settlement.awarded.join(',')==='8'&&r.profile.milestones.join(',')==='3,8','real v22 eighth floor awards only new milestone');
const final=mem.get(api.KEY);
check(!call('start_legacy',{...prefix(trace.deep_snapshot),version:23},r.revision,true).ok&&mem.get(api.KEY)===final,'version23 refused unchanged');
for(const version of [21,22]){
 const corrupt=JSON.parse(final);corrupt.active={...prefix(trace.deep_snapshot),version,actions:['hero_scholar','legacy_mind']};
 corrupt.finished=false;corrupt.settlement={};corrupt.records=[];
 mem.set(api.KEY,JSON.stringify(corrupt));const original=mem.get(api.KEY);
 check(!api.execute(storage,'read',{}).ok&&mem.get(api.KEY)===original,'unowned active legacy rejected rules'+version);
}
console.log('V22 CROSS-RULE JS INDEPENDENT: PASS ('+checks+' checks; native earned logs, protocol parity only)');
