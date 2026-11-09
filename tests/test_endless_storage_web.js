const assert=require('node:assert/strict');
const S=require('../scripts/endless_storage_web.js');
let count=0;function check(x){count++;assert.ok(x);}
const router=require('node:fs').readFileSync(require('node:path').join(__dirname,'../scripts/endless_world.gd'),'utf8');
const routerVersions=JSON.parse(router.match(/const SUPPORTED_VERSIONS=(\[[0-9,]+\])/)[1]);
check(JSON.stringify(routerVersions)===JSON.stringify(S.SUPPORTED_VERSIONS));
check(Number(router.match(/const CURRENT_VERSION:=(\d+)/)[1])===Math.max(...S.SUPPORTED_VERSIONS));
for(const version of routerVersions)check(router.includes(version+':"res://scripts/endless_world_v'+version+'.gd"'));
const store={value:null,getItem(){return this.value;},setItem(k,v){this.value=v;}};
const snap={version:1,mode:'endless',seed:8,actions:[]};
const args=(snapshot,expected_revision,record={})=>({snapshot,expected_revision,record});
check(S.execute(store,'read',{}).status==='empty');
check(S.execute(store,'start',args(snap,0)).revision===1);
check(S.execute(store,'start',args(snap,0)).revision===1);
const moved={...snap,actions:['R']};
check(S.execute(store,'commit',args(moved,1)).revision===2);
check(S.execute(store,'commit',args(moved,1)).revision===2);
check(S.execute(store,'commit',args({...snap,actions:['L']},1)).status==='conflict');
check(S.execute(store,'commit',args({...snap,actions:['L','R']},2)).status==='invalid');
const before=store.value;store.setItem=()=>{let e=new Error();e.name='QuotaExceededError';throw e;};
check(S.execute(store,'commit',args({...snap,actions:['R','L']},2)).status==='quota');check(store.value===before);
store.setItem=function(k,v){this.value=v;};
const done={...snap,actions:['R','retire']};
check(S.execute(store,'commit',args(done,2)).revision===3);
const r={run_id:1,seed:8,max_floor:1,kills:0,gold:0,reason:'retired'};
check(S.execute(store,'finish',args(done,3,r)).records.length===1);
check(S.execute(store,'finish',args(done,3,r)).records.length===1);
check(S.execute(store,'commit',args({...done,actions:['R','retire','R']},4)).status==='invalid');
for(let i=0;i<15;i++){
 let e=S.read(store).envelope;check(S.execute(store,'start',args(snap,e.revision)).ok);
 e=S.read(store).envelope;let end={...snap,actions:['retire']};check(S.execute(store,'commit',args(end,e.revision)).ok);
 e=S.read(store).envelope;check(S.execute(store,'finish',args(end,e.revision,{...r,run_id:e.run_id,max_floor:i+1})).ok);
}
check(S.execute(store,'read',{}).records.length===10);check(S.execute(store,'read',{}).records[0].max_floor===15);
store.value='bad json';check(!S.execute(store,'read',{}).ok);
store.value=JSON.stringify({...S.fresh(),unexpected:1});check(S.execute(store,'read',{}).status==='corrupt');
store.value=' '.repeat(S.MAX+1);check(S.execute(store,'read',{}).status==='corrupt');
check(!S.snapshot({...snap,atk:999}));check(!S.snapshot({...snap,actions:['x'.repeat(41)]}));
// Rules version is part of run identity, including acknowledgement retries.
store.value=null;
check(S.execute(store,'start',args(snap,0)).ok);
const v2={...snap,version:2};
check(S.execute(store,'start',args(v2,0)).status==='conflict');
check(S.execute(store,'commit',args({...v2,actions:['R']},1)).status==='invalid');
check(S.execute(store,'start',args(v2,1)).snapshot.version===2);
check(S.execute(store,'start',args(v2,1)).revision===2);
check(S.execute(store,'commit',args({...snap,actions:['R']},2)).status==='invalid');
const v2done={...v2,actions:['retire']};
check(S.execute(store,'commit',args(v2done,2)).ok);
check(S.execute(store,'finish',args({...v2done,version:1},3,{...r,run_id:2,rule_version:2})).status==='invalid');
check(S.execute(store,'finish',args(v2done,3,{...r,run_id:2})).status==='invalid');
check(S.execute(store,'finish',args(v2done,3,{...r,run_id:2,rule_version:2})).records[0].rule_version===2);
check(S.execute(store,'finish',args({...v2done,version:1},3,{...r,run_id:2,rule_version:2})).status==='conflict');
for(const version of [0,21,1.5,'1',true,null,{},[],NaN,Infinity]){
 check(!S.snapshot({...snap,version}));
 check(S.execute(store,'start',args({...snap,version},4)).status==='invalid');
}
store.value=JSON.stringify({...S.fresh(),revision:1,run_id:1,active:{...snap,version:21}});
check(S.execute(store,'read',{}).status==='corrupt');
const legacy={version:1,revision:3,run_id:1,active:done,finished:true,records:[r]};
check(S.valid(legacy));
for(const rule_version of [0,21,'2',null,1.5,true]){
 check(!S.valid({...legacy,records:[{...r,rule_version}]}));
}
check(S.valid({...legacy,records:[{...r,rule_version:1}]}));
check(!S.valid({...legacy,records:[{...r,rule_version:1,extra:true}]}));
store.value=null;
for(const version of [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20]){
 let current=S.execute(store,'read',{});
 const started={...snap,version,actions:version===20?['hero_warden']:[]};
 current=S.execute(store,version===20?'start_hero':'start',args(started,current.revision));
 check(current.ok&&current.snapshot.version===version);
 for(const targetVersion of [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20]){
  if(targetVersion===version)continue;
  const original=store.value;
  check(S.execute(store,'commit',args({...started,version:targetVersion,actions:['retire']},current.revision)).status==='invalid');
  check(store.value===original);
 }
 const end={...started,actions:[...started.actions,'retire']};
 current=S.execute(store,'commit',args(end,current.revision));check(current.ok);
 current=S.execute(store,'finish',args(end,current.revision,{...r,run_id:current.run_id,rule_version:version,max_floor:version+1}));check(current.ok);
 check(current.records.find(x=>x.run_id===current.run_id).rule_version===version);
 check(S.execute(store,'read',{}).snapshot.version===version);
}
// Dedicated v10-v20 operation, never general batch commit.
for(const walkVersion of [10,11,12,13,14,15,16,17,18,19,20]){
store.value=null;
const walkBase={...snap,version:walkVersion,actions:walkVersion===20?['hero_warden']:[]};
check(S.execute(store,walkVersion===20?'start_hero':'start',args(walkBase,0)).ok);
const walkTarget={...walkBase,actions:[...walkBase.actions,'R','R']};
check(S.execute(store,'commit',args(walkTarget,1)).status==='invalid');
check(S.execute(store,'commit_walk',args(walkBase,1)).status==='invalid');
for(const actions of [['R!'],['cargo_use'],Array(225).fill('R')]){
 check(S.execute(store,'commit_walk',args({...walkBase,actions},1)).status==='invalid');
}
check(S.execute(store,'commit_walk',args({...walkTarget,version:9},1)).status==='invalid');
for(const targetVersion of [10,11,12,13,14,15,16,17,18,19,20]){if(targetVersion!==walkVersion)check(S.execute(store,'commit_walk',args({...walkTarget,version:targetVersion},1)).status==='invalid');}
check(S.execute(store,'commit_walk',args({...walkTarget,seed:9},1)).status==='invalid');
const walkBytes=store.value;
store.setItem=()=>{let e=new Error();e.name='QuotaExceededError';throw e;};
check(S.execute(store,'commit_walk',args(walkTarget,1)).status==='quota');check(store.value===walkBytes);
store.setItem=function(k,v){this.value=v;};
check(S.execute(store,'commit_walk',args(walkTarget,1)).revision===2);
check(S.execute(store,'commit_walk',args(walkTarget,1)).revision===2);
check(S.execute(store,'commit_walk',args({...walkBase,actions:[...walkBase.actions,'L','L']},1)).status==='conflict');
check(S.execute(store,'commit_walk',args({...walkBase,actions:[...walkBase.actions,'L','L','U']},2)).status==='invalid');
check(S.execute(store,'commit_walk',args({...walkTarget,actions:[...walkTarget.actions,'L']},2)).revision===3);
check(S.execute(store,'read',{}).snapshot.actions.length===walkBase.actions.length+3);
}
// Dedicated atomic hero start, not a relaxation of legacy start.
for(const hero of ['hero_warden','hero_ranger','hero_scholar']){
 store.value=null;
 check(S.execute(store,'start',args(snap,0)).ok);
 const selected={...snap,version:20,actions:[hero]}, oldBytes=store.value;
 for(const bad of [[],['hero_unknown'],[hero,'R'],[hero,hero]]){
  check(S.execute(store,'start_hero',args({...selected,actions:bad},1)).status==='invalid');check(store.value===oldBytes);
 }
 check(S.execute(store,'start_hero',args({...selected,version:19},1)).status==='invalid');
 check(S.execute(store,'start',args(selected,1)).status==='invalid');
 check(S.execute(store,'start',args({...selected,actions:[]},1)).status==='invalid');
 store.setItem=()=>{const e=new Error();e.name='QuotaExceededError';throw e;};
 check(S.execute(store,'start_hero',args(selected,1)).status==='quota');check(store.value===oldBytes);
 store.setItem=function(k,v){this.value=v;};
 const accepted=S.execute(store,'start_hero',args(selected,1));check(accepted.ok&&accepted.run_id===2&&accepted.revision===2);
 check(S.execute(store,'start_hero',args(selected,1)).revision===2);
 check(S.execute(store,'commit',args(selected,1)).status==='conflict');
 check(S.execute(store,'commit_walk',args(selected,1)).status==='conflict');
 check(S.execute(store,'start_hero',args({...selected,seed:9},1)).status==='conflict');
 check(S.execute(store,'commit',args({...selected,actions:[hero,'hero_scholar']},2)).status==='invalid');
 check(S.execute(store,'commit',args({...selected,actions:[hero,'R']},2)).ok);
 check(S.execute(store,'read',{}).snapshot.actions[0]===hero);
 store.value=JSON.stringify({...S.fresh(),run_id:1,revision:1,active:{...selected,actions:[]}});
 check(S.execute(store,'read',{}).status==='corrupt');
}
console.log(`ENDLESS WEB STORAGE: PASS (${count} checks; production envelope/CAS/quota/idempotence, not browser nor World replay)`);
