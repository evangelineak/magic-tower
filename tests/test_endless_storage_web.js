const assert=require('node:assert/strict');
const S=require('../scripts/endless_storage_web.js');
let count=0;function check(x){count++;assert.ok(x);}
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
console.log(`ENDLESS WEB STORAGE: PASS (${count} checks; production envelope/CAS/quota/idempotence, not browser nor World replay)`);
