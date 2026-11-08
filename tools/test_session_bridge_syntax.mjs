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
let inline=0;
for(const match of html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)){
 if(/\bsrc\s*=/.test(match[1]))continue;
 new vm.Script(match[2],{filename:`session_storage_harness.inline${++inline}.js`});checks++;
}
assert.ok(inline>=2,'harness inline scripts must actually be discovered');checks++;
assert.match(html,/<script\s+src="session_storage_runtime\.js"/);checks++;
const exports=fs.readFileSync(path.join(root,'export_presets.cfg'),'utf8');
for(const preset of exports.split(/\[preset\.\d+\]/).slice(1)){
 assert.match(preset,/include_filter="[^"]*scripts\/\*\.js/);checks++;
}
console.log(`SESSION BRIDGE STATIC: PASS (${checks} checks; syntax/path/config only)`);
