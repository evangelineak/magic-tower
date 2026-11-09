/* Independent device-only endless saves. No network or global leaderboard. */
(function(root){
'use strict';
const KEY='magic-tower.endless.v1', LOCK='magic-tower.endless.v1.write', MAX=2*1024*1024;
// Kept in parity with the explicit GDScript router by the protocol test.
const SUPPORTED_VERSIONS=Object.freeze([1,2,3,4,5,6,7,8,9,10,11,12,13]);
const rulesVersion=v=>Number.isSafeInteger(v)&&SUPPORTED_VERSIONS.includes(v);
const integer=(v,a,b)=>Number.isSafeInteger(v)&&v>=a&&v<=b;
const exact=(v,keys)=>v&&typeof v==='object'&&!Array.isArray(v)&&Object.keys(v).length===keys.length&&keys.every(k=>Object.hasOwn(v,k));
function snapshot(s){return exact(s,['version','mode','seed','actions'])&&rulesVersion(s.version)&&s.mode==='endless'&&integer(s.seed,0,2147483647)&&Array.isArray(s.actions)&&s.actions.length<=100000&&s.actions.every(a=>typeof a==='string'&&a.length>0&&a.length<=40);}
function same(a,b){return snapshot(a)&&snapshot(b)&&a.version===b.version&&a.seed===b.seed&&a.actions.length===b.actions.length&&a.actions.every((x,i)=>x===b.actions[i]);}
function record(r){return (exact(r,['run_id','seed','max_floor','kills','gold','reason'])||exact(r,['run_id','seed','max_floor','kills','gold','reason','rule_version']))&&rulesVersion(r.rule_version===undefined?1:r.rule_version)&&integer(r.run_id,1,10000000)&&integer(r.seed,0,2147483647)&&integer(r.max_floor,1,1000000000)&&integer(r.kills,0,1000000000)&&integer(r.gold,0,1000000000)&&['death','retired','action_limit'].includes(r.reason);}
function fresh(){return {version:1,revision:0,run_id:0,active:null,finished:false,records:[]};}
function valid(e){return exact(e,['version','revision','run_id','active','finished','records'])&&e.version===1&&integer(e.revision,0,10000000)&&integer(e.run_id,0,10000000)&&(e.active===null||snapshot(e.active))&&typeof e.finished==='boolean'&&Array.isArray(e.records)&&e.records.length<=10&&e.records.every(record)&&new Set(e.records.map(r=>r.run_id)).size===e.records.length&&e.records.every(r=>r.run_id<=e.run_id)&&((e.run_id===0&&e.active===null&&!e.finished&&e.records.length===0)||(e.run_id>0&&e.active!==null));}
function error(status){return {ok:false,status};}
function result(e){return {ok:true,status:e.active===null?'empty':(e.finished?'finished':'active'),snapshot:e.active||{},revision:e.revision,run_id:e.run_id,records:e.records};}
function read(storage){try{const text=storage.getItem(KEY);if(text===null)return {ok:true,envelope:fresh()};if(text.length>MAX)return error('corrupt');const e=JSON.parse(text);return valid(e)?{ok:true,envelope:e}:error('corrupt');}catch(_){return error('unavailable');}}
function transition(e,op,a){
 if(op==='read')return {ok:true,envelope:e,write:false};
 if(!exact(a,['snapshot','expected_revision','record'])||!snapshot(a.snapshot)||!integer(a.expected_revision,0,10000000))return error('invalid');
 const s=a.snapshot;
 // A lost finish acknowledgement is idempotent, but only for the same current run.
 if(op==='finish'&&e.finished&&same(s,e.active)&&a.expected_revision===e.revision-1)return {ok:true,envelope:e,write:false};
 if(!e.finished&&same(s,e.active)&&a.expected_revision===e.revision-1&&((op==='start'&&s.actions.length===0)||(op==='commit'&&s.actions.length>0)||(op==='commit_walk'&&[10,11,12,13].includes(s.version)&&s.actions.length>0)))return {ok:true,envelope:e,write:false};
 if(a.expected_revision!==e.revision)return error('conflict');
 if(e.revision>=10000000)return error('limit');
 const n=JSON.parse(JSON.stringify(e));n.revision++;
 if(op==='start'){
  if(s.actions.length!==0||e.run_id>=10000000)return error('invalid');
  n.run_id++;n.active=s;n.finished=false;
 }else if(op==='commit'){
  if(e.active===null||e.finished||s.version!==e.active.version||s.seed!==e.active.seed||s.actions.length!==e.active.actions.length+1||!e.active.actions.every((v,i)=>v===s.actions[i]))return error('invalid');
  n.active=s;
 }else if(op==='commit_walk'){
  // Shape/CAS only. Godot verifies the actual safe camp route before this bridge.
  if(e.active===null||e.finished||![10,11,12,13].includes(s.version)||e.active.version!==s.version||s.seed!==e.active.seed||!e.active.actions.every((v,i)=>v===s.actions[i]))return error('invalid');
  const suffix=s.actions.slice(e.active.actions.length);
  if(suffix.length<1||suffix.length>224||!suffix.every(v=>['U','D','L','R'].includes(v)))return error('invalid');
  n.active=s;
 }else if(op==='finish'){
  if(e.active===null||e.finished||!same(s,e.active)||!record(a.record)||a.record.run_id!==e.run_id||a.record.seed!==s.seed||(a.record.rule_version===undefined?1:a.record.rule_version)!==s.version)return error('invalid');
  n.finished=true;n.records.push(a.record);n.records.sort((a,b)=>b.max_floor-a.max_floor||b.kills-a.kills||b.gold-a.gold||a.run_id-b.run_id);n.records=n.records.slice(0,10);
 }else return error('invalid');
 return {ok:true,envelope:n,write:true};
}
function execute(storage,op,args){
 const loaded=read(storage);if(!loaded.ok)return loaded;
 const changed=transition(loaded.envelope,op,args);if(!changed.ok)return changed;
 if(changed.write){const text=JSON.stringify(changed.envelope);if(text.length>MAX)return error('limit');try{storage.setItem(KEY,text);}catch(e){return error(e&&e.name==='QuotaExceededError'?'quota':'io_error');}}
 return result(changed.envelope);
}
const api={request:function(raw,callback){let q;try{q=JSON.parse(raw);}catch(_){return;}
 const reply=r=>callback(JSON.stringify({request:q.request,result:r}));
 if(!root.navigator||!root.navigator.locks){reply(error('unavailable'));return;}
 root.navigator.locks.request(LOCK,{mode:'exclusive'},()=>execute(root.localStorage,q.operation,q.args)).then(reply,()=>reply(error('io_error')));
}};
root.MagicTowerEndless=api;
if(typeof module!=='undefined'&&module.exports)module.exports={KEY,MAX,SUPPORTED_VERSIONS,snapshot,valid,fresh,transition,execute,read};
})(typeof globalThis!=='undefined'?globalThis:this);
