// Pure cross-language protocol verification. This is NOT an IndexedDB test.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const source=fs.readFileSync(path.join(root,'tools/profile_storage.js'),'utf8');
const {validateProfile,settleProfile,nextCounter}=await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
const vectors=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/legacy-profile-vectors.json'),'utf8'));
const canonical=x=>Array.isArray(x)?x.map(canonical):x&&typeof x==='object'?Object.fromEntries(Object.keys(x).sort().map(k=>[k,canonical(x[k])])):x;
const equal=(a,b)=>JSON.stringify(canonical(a))===JSON.stringify(canonical(b));
let checks=0;const failures=[];
for(const v of vectors.cases){
 checks++;if(validateProfile(v.profile)!==v.expected_validation.ok)failures.push(v.id+': validation');
 const before=JSON.stringify(v),got=settleProfile(v.profile,v.run_id,v.summary);
 for(const k of ['ok','status','profile','receipt','new_unlocks']){checks++;if(!equal(got[k],v.expected_settlement[k]))failures.push(v.id+': '+k)}
 checks++;if(JSON.stringify(v)!==before)failures.push(v.id+': input mutation');
}
for(const [input,expected] of [[0,1],[1,2],[Number.MAX_SAFE_INTEGER-1,Number.MAX_SAFE_INTEGER]]) {
 checks++;if(nextCounter(input)!==expected)failures.push('counter successor '+input);
}
for(const input of [Number.MAX_SAFE_INTEGER,Number.MAX_SAFE_INTEGER+1,-1,1.5,true,NaN,Infinity]) {
 checks++;try{nextCounter(input);failures.push('counter should reject '+input)}catch(error){if(error.code!=='COUNTER_EXHAUSTED')failures.push('counter wrong error '+input)}
}
console.log(JSON.stringify({suite:'profile cross-language pure vectors',cases:vectors.cases.length,checks,failures},null,2));
if(failures.length)process.exitCode=1;
