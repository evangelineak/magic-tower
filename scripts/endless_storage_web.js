/* Device-only envelope/CAS protocol. Godot validates replay/previous_ended; this is not a server verifier. */
(function(root){
'use strict';
const KEY='magic-tower.endless.v1', LOCK='magic-tower.endless.v1.write', MAX=2*1024*1024;
const SUPPORTED_VERSIONS=Object.freeze([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21]);
const WALK_VERSIONS=Object.freeze([10,11,12,13,14,15,16,17,18,19,20,21]);
const MILESTONES=Object.freeze([3,8,15,30,50]);
const LEGACIES=Object.freeze(['kit','coin','mind']);
const COSTS=Object.freeze({kit:1,coin:2,mind:2});
const HERO_ACTIONS=Object.freeze(['hero_warden','hero_ranger','hero_scholar']);
const integer=(v,a=0,b=10000000)=>Number.isSafeInteger(v)&&v>=a&&v<=b;
const exact=(v,keys)=>v&&typeof v==='object'&&!Array.isArray(v)&&Object.keys(v).length===keys.length&&keys.every(k=>Object.hasOwn(v,k));
const copy=v=>JSON.parse(JSON.stringify(v));
const rulesVersion=v=>integer(v)&&SUPPORTED_VERSIONS.includes(v);
function snapshot(s){return exact(s,['version','mode','seed','actions'])&&rulesVersion(s.version)&&s.mode==='endless'&&integer(s.seed,0,2147483647)&&Array.isArray(s.actions)&&s.actions.length<=100000&&s.actions.every(a=>typeof a==='string'&&a.length>0&&a.length<=40);}
const initialStart=s=>s.version<20&&s.actions.length===0;
const initialHero=s=>s.version===20&&s.actions.length===1&&HERO_ACTIONS.includes(s.actions[0]);
const initialLegacy=s=>s.version===21&&s.actions.length===2&&HERO_ACTIONS.includes(s.actions[0])&&['legacy_none',...LEGACIES.map(x=>'legacy_'+x)].includes(s.actions[1]);
const hasCommitEvent=s=>s.actions.length>0&&!initialHero(s)&&!initialLegacy(s);
function activeInitialized(s){
 if(s.version<20)return true;
 if(!s.actions.length||!HERO_ACTIONS.includes(s.actions[0])||s.actions.slice(1).some(a=>a.startsWith('hero_')))return false;
 if(s.version===20)return true;
 return s.actions.length>=2&&['legacy_none',...LEGACIES.map(x=>'legacy_'+x)].includes(s.actions[1])&&!s.actions.slice(2).some(a=>a.startsWith('legacy_'));
}
function same(a,b){return snapshot(a)&&snapshot(b)&&a.version===b.version&&a.seed===b.seed&&a.actions.length===b.actions.length&&a.actions.every((x,i)=>x===b.actions[i]);}
function record(r){return (exact(r,['run_id','seed','max_floor','kills','gold','reason'])||exact(r,['run_id','seed','max_floor','kills','gold','reason','rule_version']))&&rulesVersion(r.rule_version===undefined?1:r.rule_version)&&integer(r.run_id,1)&&integer(r.seed,0,2147483647)&&integer(r.max_floor,1,1000000000)&&integer(r.kills,0,1000000000)&&integer(r.gold,0,1000000000)&&['death','retired','action_limit'].includes(r.reason);}
const freshProfile=()=>({version:1,milestones:[],unlocks:[]});
const points=p=>p.milestones.length-p.unlocks.reduce((n,id)=>n+COSTS[id],0);
function validProfile(p){
 if(!exact(p,['version','milestones','unlocks'])||p.version!==1||!Array.isArray(p.milestones)||p.milestones.length>5||!p.milestones.every((v,i)=>v===MILESTONES[i])||!Array.isArray(p.unlocks)||p.unlocks.length>3)return false;
 let last=-1;for(const id of p.unlocks){const n=LEGACIES.indexOf(id);if(n<=last)return false;last=n;}
 return points(p)>=0;
}
function validBase(e){return integer(e.revision)&&integer(e.run_id)&&typeof e.finished==='boolean'&&(e.active===null||(snapshot(e.active)&&activeInitialized(e.active)))&&Array.isArray(e.records)&&e.records.length<=10&&e.records.every(record)&&new Set(e.records.map(r=>r.run_id)).size===e.records.length&&e.records.every(r=>r.run_id<=e.run_id&&(e.finished||r.run_id!==e.run_id))&&((e.run_id===0&&e.active===null&&!e.finished&&e.records.length===0)||(e.run_id>0&&e.active!==null));}
function validSettlement(e){
 const s=e.settlement;
 if(exact(s,[]))return !e.finished||e.active.version<21;
 return e.finished&&exact(s,['run_id','awarded','balance_after'])&&s.run_id===e.run_id&&Array.isArray(s.awarded)&&s.awarded.length<=5&&s.awarded.every((m,i)=>e.profile.milestones.includes(m)&&(i===0||s.awarded[i-1]<m))&&integer(s.balance_after,0,5)&&s.balance_after>=points(e.profile)&&s.balance_after<=e.profile.milestones.length&&(e.active.version>=21||s.awarded.length===0);
}
function valid(e){
 if(!e||typeof e!=='object')return false;
 if(e.version===1)return exact(e,['version','revision','run_id','active','finished','records'])&&validBase(e)&&(e.active===null||e.active.version<21)&&e.records.every(r=>(r.rule_version||1)<21);
 return e.version===2&&exact(e,['version','revision','run_id','active','finished','records','profile','settlement'])&&validBase(e)&&validProfile(e.profile)&&validSettlement(e)&&(e.active===null||e.active.version!==21||e.active.actions[1]==='legacy_none'||e.profile.unlocks.includes(e.active.actions[1].slice(7)));
}
const fresh=()=>({version:2,revision:0,run_id:0,active:null,finished:false,records:[],profile:freshProfile(),settlement:{}});
const normalize=e=>e.version===1?{...copy(e),version:2,profile:freshProfile(),settlement:{}}:copy(e);
const error=status=>({ok:false,status});
function result(e){return {ok:true,status:e.active===null?'empty':(e.finished?'finished':'active'),snapshot:e.active===null?{}:copy(e.active),revision:e.revision,run_id:e.run_id,records:copy(e.records),profile:copy(e.profile),points:points(e.profile),settlement:copy(e.settlement)};}
function read(storage){try{const text=storage.getItem(KEY);if(text===null)return {ok:true,envelope:fresh()};if(text.length>MAX)return error('corrupt');const e=JSON.parse(text);return valid(e)?{ok:true,envelope:normalize(e)}:error('corrupt');}catch(_){return error('unavailable');}}
function transition(e,op,a){
 if(op==='read')return {ok:true,envelope:e,write:false};
 if(op==='unlock_legacy'){
  if(!exact(a,['legacy_id','expected_revision'])||!LEGACIES.includes(a.legacy_id)||!integer(a.expected_revision))return error('invalid');
  if(e.profile.unlocks.includes(a.legacy_id))return {ok:true,envelope:e,write:false};
  if(a.expected_revision!==e.revision)return error('conflict');
  if(e.revision>=10000000)return error('limit');
  if(points(e.profile)<COSTS[a.legacy_id])return error('insufficient_points');
  const n=copy(e);n.revision++;n.profile.unlocks=LEGACIES.filter(id=>id===a.legacy_id||e.profile.unlocks.includes(id));
  return {ok:true,envelope:n,write:true};
 }
 if(!exact(a,['snapshot','expected_revision','record','previous_ended'])||!snapshot(a.snapshot)||!integer(a.expected_revision)||typeof a.previous_ended!=='boolean')return error('invalid');
 if(op==='finish'&&!a.previous_ended)return error('invalid');
 const s=a.snapshot;
 if(!activeInitialized(s)&&s.version>=20)return error('invalid');
 if((op==='start'&&!initialStart(s))||(op==='start_hero'&&!initialHero(s))||(op==='start_legacy'&&!initialLegacy(s)))return error('invalid');
 if(op==='finish'&&e.finished&&same(s,e.active)&&a.expected_revision<=e.revision)return {ok:true,envelope:e,write:false};
 if(!e.finished&&same(s,e.active)&&a.expected_revision===e.revision-1&&((op==='start'&&initialStart(s))||(op==='start_hero'&&initialHero(s))||(op==='start_legacy'&&initialLegacy(s))||(op==='commit'&&hasCommitEvent(s))||(op==='commit_walk'&&WALK_VERSIONS.includes(s.version)&&hasCommitEvent(s))))return {ok:true,envelope:e,write:false};
 if(a.expected_revision!==e.revision)return error('conflict');
 if(e.revision>=10000000)return error('limit');
 const n=copy(e);n.revision++;
 if(['start','start_hero','start_legacy'].includes(op)){
  if(e.active!==null&&!e.finished&&a.previous_ended)return error('pending_settlement');
  if(e.run_id>=10000000)return error('limit');
  if(op==='start_legacy'){const id=s.actions[1].slice(7);if(id!=='none'&&!e.profile.unlocks.includes(id))return error('locked_legacy');}
  n.run_id++;n.active=copy(s);n.finished=false;n.settlement={};
 }else if(op==='commit'){
  if(e.active===null||e.finished||s.version!==e.active.version||s.seed!==e.active.seed||s.actions.length!==e.active.actions.length+1||!e.active.actions.every((v,i)=>v===s.actions[i]))return error('invalid');
  n.active=copy(s);
 }else if(op==='commit_walk'){
  if(e.active===null||e.finished||!WALK_VERSIONS.includes(s.version)||e.active.version!==s.version||s.seed!==e.active.seed||!e.active.actions.every((v,i)=>v===s.actions[i]))return error('invalid');
  const suffix=s.actions.slice(e.active.actions.length);if(suffix.length<1||suffix.length>224||!suffix.every(v=>['U','D','L','R'].includes(v)))return error('invalid');
  n.active=copy(s);
 }else if(op==='finish'){
  if(e.active===null||e.finished||!same(s,e.active)||!record(a.record)||a.record.run_id!==e.run_id||a.record.seed!==s.seed||(a.record.rule_version===undefined?1:a.record.rule_version)!==s.version)return error('invalid');
  const awarded=s.version===21?MILESTONES.filter(m=>m<=a.record.max_floor&&!e.profile.milestones.includes(m)):[];
  n.profile.milestones=[...e.profile.milestones,...awarded];n.finished=true;
  n.settlement={run_id:e.run_id,awarded,balance_after:points(n.profile)};
  n.records.push(copy(a.record));n.records.sort((a,b)=>b.max_floor-a.max_floor||b.kills-a.kills||b.gold-a.gold||a.run_id-b.run_id);n.records=n.records.slice(0,10);
 }else return error('invalid');
 if(!valid(n))return error('invalid');
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
if(typeof module!=='undefined'&&module.exports)module.exports={KEY,MAX,SUPPORTED_VERSIONS,MILESTONES,LEGACIES,COSTS,snapshot,valid,fresh,transition,execute,read,points};
})(typeof globalThis!=='undefined'?globalThis:this);
