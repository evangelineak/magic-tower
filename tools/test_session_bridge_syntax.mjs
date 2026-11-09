// Static packaging/parse guard, not a replacement for browser transaction tests.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
let checks=0;
const production=fs.readFileSync(path.join(root,'scripts/profile_storage_web.js'),'utf8');
new vm.Script(production,{filename:'profile_storage_web.js'});checks++;
const runtime=path.join(root,'tools/session_storage_runtime.js');
assert.equal(fs.realpathSync(runtime),fs.realpathSync(path.join(root,'scripts/profile_storage_web.js')));checks++;
assert.equal(fs.readFileSync(runtime,'utf8'),production);checks++;
const html=fs.readFileSync(path.join(root,'tools/session_storage_harness.html'),'utf8');
let inline=0;const inlineScripts=[];
for(const match of html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)){
 if(/\bsrc\s*=/.test(match[1]))continue;
 inlineScripts.push(match[2]);
 new vm.Script(match[2],{filename:`session_storage_harness.inline${++inline}.js`});checks++;
}
assert.ok(inline>=2,'harness inline scripts must actually be discovered');checks++;
assert.match(html,/<script\s+src="session_storage_runtime\.js"/);checks++;
const exports=fs.readFileSync(path.join(root,'export_presets.cfg'),'utf8');
for(const preset of exports.split(/\[preset\.\d+\]/).slice(1)){
 assert.match(preset,/include_filter="[^"]*scripts\/\*\.js/);checks++;
}
// Execute the real auto-test failure branch, without a browser or IndexedDB.
// A bridge rejection must reach the parent without masking its original error.
for(const failure of ['throw','negative-result']){
 const messages=[];const nodes=new Map();
 const database='magic-tower-journeys-v1-test-vm-failure';
 const context=vm.createContext({URL,console,structuredClone,
  location:{href:`http://localhost/session_storage_harness.html?auto=1&db=${database}`,origin:'http://localhost'},
  crypto:{randomUUID:()=> 'vm-owner'},
  fetch:async()=>({json:async()=>({first:{run_id:'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'}})}),
  document:{querySelector:id=>{if(!nodes.has(id))nodes.set(id,{});return nodes.get(id)}},
  setTimeout:()=>1,clearTimeout:()=>{},
  parent:{postMessage:(value,origin)=>messages.push({value,origin})},
  MagicTowerJourneys:{databaseName:database,request:(encoded,callback)=>{
   if(failure==='throw')throw new Error('INJECTED_RPC_FAILURE');
   callback(JSON.stringify({request:JSON.parse(encoded).request,result:{ok:false,code:'INJECTED_REJECTION'}}));
  }}
 });
 context.window=context;
 for(const source of inlineScripts)await new vm.Script(source).runInContext(context);
 assert.equal(messages.length,1,'failed self-test must report once');checks++;
 const report=messages[0].value;
 assert.equal(report.type,'session-results');assert.equal(report.result.PASS,false);checks++;
 assert.equal(report.result.error,failure==='throw'?'INJECTED_RPC_FAILURE':'FAIL claim global writer');checks++;
 assert.equal(report.result.database,database);assert.equal(messages[0].origin,'http://localhost');checks++;
}
console.log(`SESSION BRIDGE STATIC: PASS (${checks} checks; syntax/path/config + simulated harness failure reporting, no browser storage)`);
