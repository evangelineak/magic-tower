/* Full-World production bridge. Independent DB; tested tools prototype is unchanged. */
(()=>{
if(globalThis.MagicTowerJourneys)return;
/* Production IndexedDB implementation loaded by session_storage.gd.
 * Profile/receipt validation shares the proven prototype schema. The inherited
 * prototype settlement helper is not exposed. Production settleJourney validates
 * the complete base and ended World payload and commits its profile atomically.
 */
class StorageFault extends Error {
  constructor(code) { super(code); this.name = 'StorageFault'; this.code = code; }
}
const req = r => new Promise((ok, no) => { r.onsuccess = () => ok(r.result); r.onerror = () => no(r.error); });
const must = (value, code) => { if (!value) throw new StorageFault(code); };
const integer = (n, max = Number.MAX_SAFE_INTEGER) => Number.isSafeInteger(n) && n >= 0 && n <= max;
function nextCounter(value) {
  must(integer(value,10000000) && value < 10000000, 'COUNTER_EXHAUSTED');
  return value + 1;
}
const MAX_RUNS=4096;
const MAX_SNAPSHOT_BYTES=1048576;
const IDS = ['legacy_scout', 'legacy_tactician', 'legacy_veteran'];
const LEVELS = [3, 5, 8];
const fresh = () => ({ revision: 1, milestones: [], receipts: {}, unlocked: [] });
const STRATEGY_IDS=['study','forager','channel','reserve','ambush_hunter','last_gambit'];
function strategyPool(profile){
 must(validateProfile(profile),'CORRUPT_PROFILE');
 return profile.milestones.length?STRATEGY_IDS.slice(0,profile.milestones.length+3):[];
}
function validStrategyPool(pool){return Array.isArray(pool)&&[0,4,5,6].includes(pool.length)&&pool.every((id,i)=>id===STRATEGY_IDS[i]);}
function strategyRank(seed,id){let h=2166136261;for(const b of new TextEncoder().encode('legacy-strategy-v1|'+seed+'|'+id))h=Math.imul(h^b,16777619)>>>0;return h;}
function strategyOffers(seed,pool){
 if(!integer(seed,2147483647)||!validStrategyPool(pool))return [];
 return [...pool].sort((a,b)=>strategyRank(seed,a)-strategyRank(seed,b)||(a<b?-1:a>b?1:0)).slice(0,3);
}
function strategyDraft(seed,pool){
 if(!integer(seed,2147483647)||!validStrategyPool(pool))return {};
 return {version:1,pool:[...pool],offers:strategyOffers(seed,pool),choice:pool.length?'':'none'};
}
function validDraft(seed,draft){
 if(!keysExactly(draft,['version','pool','offers','choice'])||typeof draft.choice!=='string')return false;
 if(draft.version===0)return Array.isArray(draft.pool)&&draft.pool.length===0&&Array.isArray(draft.offers)&&draft.offers.length===0&&draft.choice==='none';
 if(draft.version!==1||!integer(seed,2147483647)||!validStrategyPool(draft.pool)||!same(draft.offers,strategyOffers(seed,draft.pool)))return false;
 return draft.pool.length?draft.choice===''||draft.choice==='none'||draft.offers.includes(draft.choice):draft.choice==='none';
}
const TALENT_TIERS=[['iron_skin','keen_edge','clean_finish'],['last_stand','sentinel_lore','trained_focus'],['giant_slayer','battle_medic','unbroken']];
const TALENT_POOLS=[ [...TALENT_TIERS[0],'tactical_review'], [...TALENT_TIERS[1],'adversity_charge'] ];
function talentRank(seed,tier,id){let h=2166136261;for(const b of new TextEncoder().encode('talent-draft-v1|'+seed+'|'+tier+'|'+id))h=Math.imul(h^b,16777619)>>>0;return h;}
function talentDraft(seed,version=1){
 if(!integer(seed,2147483647)||![0,1].includes(version))return {};
 return {version,offers:version===0?structuredClone(TALENT_TIERS):[...TALENT_POOLS.map((pool,tier)=>[...pool].sort((a,b)=>talentRank(seed,tier,a)-talentRank(seed,tier,b)||(a<b?-1:a>b?1:0)).slice(0,3)),[...TALENT_TIERS[2]]]};
}
function validTalentDraft(seed,draft){return keysExactly(draft,['version','offers'])&&[0,1].includes(draft.version)&&same(draft,talentDraft(seed,draft.version));}
function pointCapacity(draft){return draft.pool.length?draft.pool.length-3:0;}
function allocationCopy(value={}){
 if(keysExactly(value,[]))return {study:0,reserve:0};
 must(keysExactly(value,['study','reserve'])&&integer(value.study,2)&&integer(value.reserve,2),'INVALID_ALLOCATION');
 return {study:value.study,reserve:value.reserve};
}
function validLegacyPoints(s){
 const p=s.legacy_points;
 if(!keysExactly(p,['version','capacity','study','reserve'])||![0,1].includes(p.version)||!integer(p.capacity,3)||!integer(p.study,2)||!integer(p.reserve,2)||p.study+p.reserve>p.capacity||!integer(s.legacy_reserves,p.reserve))return false;
 if(p.version===0)return p.capacity===0&&p.study===0&&p.reserve===0&&s.legacy_reserves===0;
 if(p.capacity!==pointCapacity(s.draft))return false;
 return s.draft.choice!==''||(p.study===0&&p.reserve===0&&s.legacy_reserves===0);
}
function cargoBirth(seed,layout){return layout===2?{version:1,state:'waiting',destination:seed%2===0?'vault':'crown'}:{version:0,state:'off',destination:''};}
function validCargo(s){
 const c=s.cargo;if(!keysExactly(c,['version','state','destination']))return false;
 if(c.version===0)return c.state==='off'&&c.destination==='';
 return c.version===1&&s.layout_revision===2&&['waiting','shipped','claimed','opened'].includes(c.state)&&c.destination===(s.seed_value%2===0?'vault':'crown');
}
function ropeBirth(layout){return layout===2?{version:1,state:'ready'}:{version:0,state:'off'};}
function validRope(s){
 const r=s.rope;if(!keysExactly(r,['version','state']))return false;
 if(r.version===0)return r.state==='off';
 if(r.version!==1||s.layout_revision!==2||typeof s.expedition_started!=='boolean'||!['ready','spent'].includes(r.state)||(s.expedition_started===true&&s.expedition_revision!==3))return false;
 return r.state!=='spent'||(s.expedition_started===true&&s.floor_seen?.length===8&&s.floor_seen[5]===true);
}
function snapshotCopy(snapshot, allowEnded=false) {
  const s = structuredClone(snapshot);
  let encoded; try {encoded=JSON.stringify(s);}catch{throw new StorageFault('INVALID_SNAPSHOT');}
  must(typeof encoded==='string' && new TextEncoder().encode(encoded).length<=MAX_SNAPSHOT_BYTES,'SNAPSHOT_TOO_LARGE');
  must(s && [5, 8].includes(s.floor_seen?.length) && s.floor_seen.every(x => typeof x === 'boolean') && s.floor_seen[0], 'INVALID_SNAPSHOT');
  must(!s.floor_seen.some((seen,i) => seen && s.floor_seen.slice(0,i).includes(false)), 'INVALID_SNAPSHOT');
  must(integer(s.floor) && s.floor < s.floor_seen.length && s.floor_seen[s.floor], 'INVALID_SNAPSHOT');
  must(typeof s.won === 'boolean' && Number.isSafeInteger(s.hp) && s.hp >= 0 && integer(s.moves, 10000000) && integer(s.seed_value, 2147483647), 'INVALID_SNAPSHOT');
  must([13,14,15,16,17,18,19].includes(s.version) && validId(s.run_id) && ['safe','risk'].includes(s.mode) && (s.ended_reason==='' || (allowEnded && ['retired','victory','death'].includes(s.ended_reason))), 'INVALID_WORLD');
  must([1,2].includes(s.layout_revision) && Array.isArray(s.floors) && s.floors.length===s.floor_seen.length, 'INVALID_WORLD');
  must(integer(s.x,9)&&s.x>=1&&integer(s.y,9)&&s.y>=1&&integer(s.atk,1000000)&&s.atk>0&&integer(s.def,1000000), 'INVALID_WORLD');
  must(s.floors.every(grid=>Array.isArray(grid)&&grid.length===11&&grid.every(row=>Array.isArray(row)&&row.length===11&&row.every(t=>typeof t==='string'&&t.length===1))), 'INVALID_WORLD');
  must(s.floors[s.floor][s.y][s.x]!=='#' && Array.isArray(s.inventory)&&s.inventory.includes(s.equipped)&&s.inventory.includes('balanced'), 'INVALID_WORLD');
  must(['warden','ranger','scholar'].includes(s.hero_id)&&typeof s.skill_armed==='boolean'&&integer(s.focus,4)&&[3,4].includes(s.focus_cap)&&s.focus<=s.focus_cap,'INVALID_WORLD');
  must(s.gear_offers && typeof s.gear_offers==='object' && s.gear_choices && typeof s.gear_choices==='object' && s.attunement_version===1, 'INVALID_WORLD');
  const record=s.version===13?{}:s.death_record;
  must(record&&typeof record==='object'&&!Array.isArray(record),'INVALID_DEATH_RECORD');
  if(s.ended_reason==='death'){
   must(s.version>=14&&s.mode==='risk'&&s.hp===0&&!s.won&&s.moves>=1,'INVALID_DEATH_RECORD');
   must(keysExactly(record,['floor','x','y','enemy','start_hp','skill_armed'])&&integer(record.floor,7)&&record.floor===s.floor&&integer(record.x,9)&&record.x>=1&&integer(record.y,9)&&record.y>=1&&integer(record.start_hp,1000000)&&record.start_hp>0&&typeof record.skill_armed==='boolean','INVALID_DEATH_RECORD');
   must(Math.abs(record.x-s.x)+Math.abs(record.y-s.y)===1&&['s','g','u','b','w','V','K','W','H','Z','B'].includes(record.enemy)&&s.floors[s.floor][record.y][record.x]===record.enemy,'INVALID_DEATH_RECORD');
  }else must(s.hp>0&&Object.keys(record).length===0,'INVALID_DEATH_RECORD');
  if(s.version>=15){
   must(validDraft(s.seed_value,s.draft),'INVALID_DRAFT');
   if(s.draft.choice==='')must(s.moves===0&&s.ended_reason===''&&s.hp>0,'DRAFT_PENDING');
  }
  if(s.version>=16){must(validTalentDraft(s.seed_value,s.talent_draft),'INVALID_TALENT_DRAFT');must(Array.isArray(s.talents)&&s.talents.every(id=>s.talent_draft.offers.some(tier=>tier.includes(id))),'INVALID_TALENT_CHOICE');must(['','s','g','u','b','w','V','K','W','H','Z','B'].includes(s.last_kill_kind)&&integer(s.kills,10000000)&&(s.kills>0||s.last_kill_kind===''),'INVALID_LAST_KILL');}
  if(s.version>=17)must(validLegacyPoints(s),'INVALID_LEGACY_POINTS');
  if(s.version>=18){
   must(validCargo(s),'INVALID_CARGO');const c=s.cargo,count=s.floors.flat(2).filter(t=>t==='c').length;
   if(c.version===0)must(count===0,'INVALID_CARGO_MAP');
   else {
    must(count===(c.destination==='vault'?1:0)&&(c.destination!=='vault'||s.floors[2][2][9]==='c'),'INVALID_CARGO_MAP');
    const door=s.floors[0][2][8],box=s.floors[0][2][9];
    must(c.state==='waiting'?door==='D'&&box==='h':c.state==='opened'?door==='.'&&['h','.'].includes(box):door==='.'&&box==='.', 'INVALID_CARGO_MAP');
    if(c.state==='claimed')must(c.destination==='vault'?s.floors[2][3][8]!=='V':s.expedition_started&&!s.floors[4].flat().includes('K'),'INVALID_CARGO_MAP');
   }
  }
  if(s.version>=19)must(validRope(s),'INVALID_ROPE');
  return s;
}
function upgradeSnapshot(snapshot){
 const s=structuredClone(snapshot);if(s.version===13){s.version=14;s.death_record={};}if(s.version===14){s.version=15;s.draft={version:0,pool:[],offers:[],choice:'none'};}if(s.version===15){s.version=16;s.talent_draft=talentDraft(s.seed_value,0);s.last_kill_kind='';}if(s.version===16){s.version=17;s.legacy_points={version:0,capacity:0,study:0,reserve:0};s.legacy_reserves=0;}if(s.version===17){s.version=18;s.cargo={version:0,state:'off',destination:''};}if(s.version===18){s.version=19;s.rope={version:0,state:'off'};}return s;
}
function summaryOf(snapshot, outcome) {
 const s=snapshotCopy(snapshot,true);
 must(['withdrawn','chapter1','victory','defeat'].includes(outcome),'INVALID_OUTCOME');
 const max_floor=s.floor_seen.filter(Boolean).length;
 const count=token=>s.floors.reduce((n,g)=>n+g.flat().filter(t=>t===token).length,0);
 must(s.ended_reason===(outcome==='defeat'?'death':outcome==='victory'?'victory':'retired'),'INVALID_OUTCOME');
 if(outcome==='defeat')must(s.mode==='risk'&&s.hp===0&&s.ended_reason==='death','INVALID_OUTCOME');
 if(outcome==='withdrawn')must(!s.won,'INVALID_OUTCOME');
 if(outcome==='chapter1')must(s.won&&!s.expedition_started&&s.floors.length===5&&max_floor===5&&count('K')===0,'INVALID_OUTCOME');
 if(outcome==='victory')must(s.won&&s.expedition_started&&s.floors.length===8&&max_floor===8&&count('Z')===0,'INVALID_OUTCOME');
 return {seed:s.seed_value,max_floor,moves:s.moves,outcome};
}
const keysExactly=(o,keys)=>o && typeof o==='object' && !Array.isArray(o) && Object.keys(o).length===keys.length && keys.every(k=>Object.hasOwn(o,k));
function validSummary(x) { return keysExactly(x,['seed','max_floor','moves','outcome']) && integer(x.seed,2147483647) && integer(x.max_floor,8) && x.max_floor>=1 && integer(x.moves,10000000) && ['withdrawn','chapter1','victory','defeat'].includes(x.outcome) && (x.outcome!=='chapter1'||x.max_floor>=5) && (x.outcome!=='victory'||x.max_floor===8); }
function validateProfile(p) {
  if (!keysExactly(p,['revision','milestones','receipts','unlocked']) || p.revision !== 1 || !Array.isArray(p.milestones) || !Array.isArray(p.unlocked) || !p.receipts || typeof p.receipts !== 'object' || Array.isArray(p.receipts) || Object.keys(p.receipts).length > 4096) return false;
  const reached = new Set(), granted = new Set();
  for (const [id, r] of Object.entries(p.receipts)) {
    const x = r?.summary;
    if(!keysExactly(r,['run_id','summary','milestones','unlocked']) || !validSummary(x)) return false;
    if (!/^[A-Za-z0-9_-]{16,64}$/.test(id) || r?.run_id !== id || !x || !integer(x.seed,2147483647) || !integer(x.max_floor,8) || x.max_floor < 1 || !integer(x.moves,10000000) || !['withdrawn','chapter1','victory','defeat'].includes(x.outcome)) return false;
    if (x.outcome === 'chapter1' && x.max_floor < 5 || x.outcome === 'victory' && x.max_floor !== 8) return false;
    const eligible = LEVELS.filter(f => f <= x.max_floor);
    for (const f of eligible) reached.add(f);
    if (!Array.isArray(r.milestones) || !Array.isArray(r.unlocked) || JSON.stringify(r.milestones) !== JSON.stringify(LEVELS.filter(f => r.milestones.includes(f))) || r.milestones.some(f => !eligible.includes(f) || granted.has(f))) return false;
    if (JSON.stringify(r.unlocked) !== JSON.stringify(r.milestones.map(f => IDS[LEVELS.indexOf(f)]))) return false;
    for (const f of r.milestones) granted.add(f);
  }
  const exact = LEVELS.filter(f => reached.has(f));
  return JSON.stringify(p.milestones) === JSON.stringify(exact) && exact.every(f => granted.has(f)) && JSON.stringify(p.unlocked) === JSON.stringify(exact.map(f => IDS[LEVELS.indexOf(f)]));
}
function settleProfile(profile,run_id,summary) {
 const result=(ok,status,p,receipt={},new_unlocks=[])=>({ok,status,reason:'',profile:p && typeof p==='object' && !Array.isArray(p)?structuredClone(p):null,receipt:structuredClone(receipt),new_unlocks:structuredClone(new_unlocks)});
 if(!validateProfile(profile)||!validId(run_id)||!validSummary(summary)) return result(false,'invalid',profile);
 const canonicalSummary={seed:summary.seed,max_floor:summary.max_floor,moves:summary.moves,outcome:summary.outcome};
 if(Object.hasOwn(profile.receipts,run_id)) {const old=profile.receipts[run_id];return result(same(old.summary,canonicalSummary),same(old.summary,canonicalSummary)?'duplicate':'conflict',profile,old);}
 if(Object.keys(profile.receipts).length>=4096)return result(false,'full',profile);
 const next=structuredClone(profile),milestones=LEVELS.filter(f=>f<=summary.max_floor&&!profile.milestones.includes(f)),unlocked=milestones.map(f=>IDS[LEVELS.indexOf(f)]);
 const receipt={run_id,summary:canonicalSummary,milestones,unlocked};next.receipts[run_id]=receipt;
 next.milestones=LEVELS.filter(f=>profile.milestones.includes(f)||milestones.includes(f));next.unlocked=next.milestones.map(f=>IDS[LEVELS.indexOf(f)]);
 return result(true,'applied',next,receipt,unlocked);
}
const same = (a,b) => JSON.stringify(canonical(a)) === JSON.stringify(canonical(b));
function canonical(x) { return Array.isArray(x) ? x.map(canonical) : x && typeof x==='object' ? Object.fromEntries(Object.keys(x).sort().map(k=>[k,canonical(x[k])])) : x; }
const validId=id=>typeof id==='string' && /^[A-Za-z0-9_-]{16,64}$/.test(id);
function validRun(r) {
 try {
  if(!keysExactly(r,['id','revision','status','snapshot','last_op'])||!validId(r.id)||!integer(r.revision,10000000)||!['active','archived','abandoned'].includes(r.status))return false;
  const op=r.last_op;
  if(!keysExactly(op,['request_id','kind','expected_slot','expected_revision','hash','result_slot','result_revision'])||!validId(op.request_id)||!['create','save','settle','death','strategy'].includes(op.kind))return false;
  if(!integer(op.expected_slot,10000000)||!Number.isSafeInteger(op.expected_revision)||op.expected_revision< -1||op.expected_revision>10000000||!integer(op.result_slot,10000000)||!integer(op.result_revision,10000000))return false;
  if(typeof op.hash!=='string'||!/^[a-f0-9]{64}$/.test(op.hash)||op.result_revision!==r.revision)return false;
  if(op.kind==='create'&&(op.request_id!==r.id||op.expected_revision!==-1||r.revision!==0||op.result_slot!==op.expected_slot+1))return false;
  if(op.kind!=='create'&&(op.expected_revision<0||op.result_revision!==op.expected_revision+1||op.result_slot!==op.expected_slot+(['settle','death'].includes(op.kind)?1:0)))return false;
  if((r.status==='archived')!==(['settle','death'].includes(op.kind)))return false;
  if(r.status==='abandoned'&&r.snapshot===null)return true;
  if(r.snapshot?.run_id!==r.id)return false;
  if(r.status==='archived'&&((r.snapshot.ended_reason==='death')!==(op.kind==='death')))return false;
  snapshotCopy(r.snapshot,r.status==='archived');
  return r.status!=='archived'||r.snapshot.ended_reason!=='';
 }catch{return false;}
}

function checkRunLedger(run,profile){
 if(!run)return;
 must(validRun(run),'CORRUPT_RUN');
 if(run.snapshot){const pool=upgradeSnapshot(run.snapshot).draft.pool,entitled=strategyPool(profile);must(pool.every(id=>entitled.includes(id)),'UNENTITLED_DRAFT');}
 const receipt=profile.receipts[run.id];
 if(run.status==='archived')must(receipt&&same(summaryOf(run.snapshot,receipt.summary.outcome),receipt.summary),'CORRUPT_RECEIPT');
 else must(!receipt,'CLOSED_RECEIPT_ACTIVE');
}
async function loadProfile(stores) {
  const envelope=await req(stores('profiles').get('local')), indexes=await req(stores('receipts').getAll());
  if (envelope===undefined) { must(indexes.length===0,'CORRUPT_PROFILE'); return {id:'local',commitRevision:0,profile:fresh()}; }
  must(envelope && envelope.id==='local' && integer(envelope.commitRevision) && validateProfile(envelope.profile),'CORRUPT_PROFILE');
  must(indexes.length===Object.keys(envelope.profile.receipts).length && envelope.commitRevision===indexes.length,'CORRUPT_PROFILE');
  for(const entry of indexes) must(entry && validId(entry.id) && same(entry.receipt,envelope.profile.receipts[entry.id]),'CORRUPT_PROFILE');
  return envelope;
}
async function loadSlot(stores) {
  const slot=await req(stores('slots').get('active'));
  if(slot===undefined) {must(await req(stores('runs').count())===0,'CORRUPT_SLOT');return {id:'active',revision:0,activeRunId:null,lastFence:0,writer:null};}
  must(slot && slot.id==='active' && integer(slot.revision,10000000) && integer(slot.lastFence,10000000) && (slot.activeRunId===null || validId(slot.activeRunId)),'CORRUPT_SLOT');
  if(slot.writer!==null) must(slot.writer && typeof slot.writer.owner==='string' && slot.writer.owner.length>0 && slot.writer.owner.length<200 && integer(slot.writer.fence,10000000) && slot.writer.fence>0 && slot.writer.fence===slot.lastFence && integer(slot.writer.leaseUntil),'CORRUPT_SLOT');
  if(slot.activeRunId!==null) { const run=await req(stores('runs').get(slot.activeRunId));must(validRun(run),'CORRUPT_RUN'); }
  return slot;
}
function checkSlot(slot, auth, activeId = undefined) {
  must(auth && slot.writer && slot.writer.owner === auth.owner && slot.writer.fence === auth.fence && slot.writer.leaseUntil > Date.now(), 'STALE_WRITER');
  must(slot.revision === auth.expectedSlotRevision, 'STALE_SLOT_REVISION');
  if (activeId !== undefined) must(slot.activeRunId === activeId, 'NOT_ACTIVE_RUN');
}
class ProfileStorage {
  static async open(name = 'magic-tower-journeys-v1') {
    must(name==='magic-tower-journeys-v1' || name.startsWith('magic-tower-journeys-v1-test-'), 'UNSAFE_DATABASE_NAME');
    const opening = indexedDB.open(name, 2);
    opening.onupgradeneeded = () => {
      for (const name of ['profiles', 'runs', 'receipts', 'slots']) if (!opening.result.objectStoreNames.contains(name)) opening.result.createObjectStore(name, { keyPath: 'id' });
    };
    const db = await req(opening); db.onversionchange = () => db.close();
    return new JourneyStorage(db);
  }
  constructor(db) { this.db = db; }
  close() { this.db.close(); }
  transaction(names, mode, body) {
    return new Promise((resolve, reject) => {
      let tx;
      try { tx = this.db.transaction(names, mode, mode === 'readwrite' ? { durability: 'strict' } : {}); }
      catch { tx = this.db.transaction(names, mode); }
      let result, failure;
      tx.oncomplete = () => resolve(result); // Never report success at put.onsuccess.
      tx.onabort = () => reject(failure || tx.error || new StorageFault('TRANSACTION_ABORTED'));
      tx.onerror = () => {};
      Promise.resolve().then(() => body(name => tx.objectStore(name))).then(value => { result = value; }, error => {
        failure = error; try { tx.abort(); } catch { reject(error); }
      });
    });
  }
  readRun(id) { return this.transaction(['runs'], 'readonly', async s => {const run=await req(s('runs').get(id));must(run===undefined || validRun(run),'CORRUPT_RUN');return run;}); }
  readReceipt(id) { return this.transaction(['profiles','receipts'], 'readonly', async s => (await loadProfile(s)).profile.receipts[id]); }
  readProfile() { return this.transaction(['profiles','receipts'],'readonly',async s=>(await loadProfile(s)).profile); }
  readSlot() { return this.transaction(['slots','runs'],'readonly',s=>loadSlot(s)); }
  claimWriter(owner, leaseMs = 15000) {
    must(typeof owner === 'string' && owner.length > 0 && owner.length < 200 && integer(leaseMs) && leaseMs >= 50 && leaseMs <= 60000, 'INVALID_LEASE');
    return this.transaction(['slots','runs'], 'readwrite', async s => {
      const slot = await loadSlot(s);
      if (slot.writer && slot.writer.leaseUntil > Date.now()) must(slot.writer.owner === owner, 'WRITER_BUSY');
      else { slot.lastFence = nextCounter(slot.lastFence); slot.writer = { owner, fence: slot.lastFence, leaseUntil: 0 }; }
      slot.writer.leaseUntil = Date.now() + leaseMs;
      await req(s('slots').put(slot));
      return { ...slot.writer, expectedSlotRevision: slot.revision };
    });
  }
  renewWriter(auth, leaseMs = 15000) {
    must(integer(leaseMs) && leaseMs >= 50 && leaseMs <= 60000, 'INVALID_LEASE');
    return this.transaction(['slots','runs'], 'readwrite', async s => {
      const slot = await loadSlot(s); checkSlot(slot, auth);
      slot.writer.leaseUntil = Date.now() + leaseMs; await req(s('slots').put(slot));
      return { ...slot.writer, expectedSlotRevision: slot.revision };
    });
  }
  createRun(auth, snapshot, replaceActive = false) {
    const copied = snapshotCopy(snapshot), id = crypto.randomUUID();
    return this.transaction(['slots', 'runs'], 'readwrite', async s => {
      const slot = await loadSlot(s); checkSlot(slot, auth);
      must(await req(s('runs').count())<MAX_RUNS,'RUNS_FULL');
      const prior = slot.activeRunId ? await req(s('runs').get(slot.activeRunId)) : null;
      must(!prior || prior.status !== 'active' || replaceActive === true, 'ACTIVE_RUN_EXISTS');
      if (prior?.status === 'active') { prior.status = 'abandoned'; prior.revision = nextCounter(prior.revision); await req(s('runs').put(prior)); }
      const run = { id, revision: 0, status: 'active', snapshot: copied };
      await req(s('runs').add(run)); slot.activeRunId = id; slot.revision = nextCounter(slot.revision); await req(s('slots').put(slot));
      return { run, slotRevision: slot.revision };
    });
  }
  saveRun(id, auth, expectedRevision, snapshot) {
    const copied = snapshotCopy(snapshot);
    return this.transaction(['runs', 'slots'], 'readwrite', async s => {
      const slot = await loadSlot(s); checkSlot(slot, auth, id);
      const run = await req(s('runs').get(id)); must(validRun(run), 'CORRUPT_RUN'); must(run.status === 'active', 'RUN_NOT_ACTIVE'); must(run.revision === expectedRevision, 'STALE_REVISION');
      run.snapshot = copied; run.revision = nextCounter(run.revision); await req(s('runs').put(run)); return run;
    });
  }
  settleRun(id, auth, expectedRevision, outcome, testAbortAt = '') {
    const fail = point => { if (testAbortAt === point) throw new StorageFault('INJECTED_ABORT_' + point); };
    return this.transaction(['profiles', 'runs', 'receipts', 'slots'], 'readwrite', async s => {
      const run = await req(s('runs').get(id)); must(run, 'RUN_NOT_FOUND'); must(validRun(run), 'CORRUPT_RUN');
      const envelope=await loadProfile(s);
      const summary = summaryOf(run.snapshot, outcome); // Caller cannot supply floor or score.
      const decision=settleProfile(envelope.profile,id,summary);
      if(decision.status!=='applied')return decision;
      const slot = await loadSlot(s); checkSlot(slot, auth, id);
      must(run.status === 'active', 'RUN_NOT_ACTIVE'); must(run.revision === expectedRevision, 'STALE_REVISION');
      envelope.profile=decision.profile;envelope.commitRevision=nextCounter(envelope.commitRevision);
      const receipt=decision.receipt;
      fail('before_writes'); await req(s('profiles').put(envelope)); fail('after_profile');
      await req(s('receipts').add({ id, receipt })); fail('after_receipt');
      run.status = 'archived'; run.revision = nextCounter(run.revision); await req(s('runs').put(run)); fail('after_archive');
      slot.revision = nextCounter(slot.revision); await req(s('slots').put(slot)); fail('after_slot');
      return {...decision,slotRevision:slot.revision};
    });
  }
}
function validateDeathTransition(rawBase,ended,delta){
 const base=upgradeSnapshot(rawBase),r=ended.death_record;
 must(base.mode==='risk'&&ended.ended_reason==='death'&&!base.won,'INVALID_LETHAL_FIGHT');
 must(r&&r.floor===base.floor&&r.x===base.x+delta[0]&&r.y===base.y+delta[1],'INVALID_DEATH_RECORD');
 // A retry may prepare from the already archived exact payload. The transaction
 // still verifies its operation receipt and CAS before acknowledging it.
 if(base.ended_reason==='death'){must(same(base,ended),'INVALID_END_TRANSITION');return;}
 must(base.ended_reason===''&&base.hp>0&&r.start_hp===base.hp&&r.skill_armed===base.skill_armed,'INVALID_DEATH_RECORD');
 const expected=structuredClone(base);expected.hp=0;expected.moves=base.moves+1;expected.ended_reason='death';expected.death_record=structuredClone(r);
 if(base.skill_armed&&base.focus>0&&['warden','ranger'].includes(base.hero_id)){expected.focus=base.focus-1;expected.skill_armed=false;}
 must(same(expected,ended),'INVALID_END_TRANSITION');
 // Godot validates/replays the combat before preparation and again on read.
 // JS verifies atomic full-base/allowed-change invariants, not GDScript damage.
}
async function digestSnapshot(snapshot) {
 const bytes=new TextEncoder().encode(JSON.stringify(canonical(snapshot)));
 return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),b=>b.toString(16).padStart(2,'0')).join('');
}
class JourneyStorage extends ProfileStorage {
 async writeJourney(kind,args) {
  must(validId(args.request_id),'INVALID_REQUEST_ID');
  const snapshot=snapshotCopy(args.snapshot),id=kind==='create'?args.request_id:args.id;
  must(snapshot.run_id===id,'IDENTITY_MISMATCH');
  const hash=await digestSnapshot(snapshot); // Crypto finishes BEFORE the IDB transaction.
  return this.transaction(['slots','runs','profiles','receipts'],'readwrite',async s=>{
   const slot=await loadSlot(s),profile=(await loadProfile(s)).profile;
   checkSlot(slot,{...args.auth,expectedSlotRevision:slot.revision}); // fence first; retry may acknowledge an earlier slot CAS.
   const run=await req(s('runs').get(id)),expected=kind==='create'?-1:args.expected;
   if(run && run.last_op.request_id===args.request_id){
    const op=run.last_op;
    must(op.kind===kind && (op.hash===hash || (run.snapshot?.version<19&&same(upgradeSnapshot(run.snapshot),snapshot))) && op.expected_revision===expected && (kind==='create'||op.expected_slot===args.auth.expectedSlotRevision),'REQUEST_CONFLICT');
    must(slot.activeRunId===id && slot.revision===op.result_slot && run.revision===op.result_revision && run.status==='active','SUPERSEDED_OPERATION');
    return {ok:true,run,slotRevision:slot.revision,leaseUntil:slot.writer.leaseUntil,profile,duplicate:true};
   }
   checkRunLedger(run,profile);
   checkSlot(slot,args.auth);
   if(kind==='create'){
    must(!run&&!Object.hasOwn(profile.receipts,id),'ID_COLLISION');must(await req(s('runs').count())<MAX_RUNS,'RUNS_FULL');
    // Full canonical fresh-World comparison is performed on the Godot side.
    // JS independently rejects partial stub, legacy identity and visibly progressed input.
    must(snapshot.version===19&&same(snapshot.rope,ropeBirth(snapshot.layout_revision))&&same(snapshot.cargo,cargoBirth(snapshot.seed_value,snapshot.layout_revision))&&same(snapshot.legacy_points,{version:1,capacity:pointCapacity(snapshot.draft),study:0,reserve:0})&&snapshot.legacy_reserves===0&&same(snapshot.talent_draft,talentDraft(snapshot.seed_value))&&snapshot.last_kill_kind===''&&same(snapshot.draft,strategyDraft(snapshot.seed_value,strategyPool(profile))),'INVALID_BIRTH_DRAFT');
    must(snapshot.moves===0 && snapshot.floor===0 && snapshot.floors.length===5 && snapshot.x===1 && snapshot.y===1 && !snapshot.won && snapshot.floor_seen.slice(1).every(v=>!v) && snapshot.inventory.length===1,'NOT_FRESH_RUN');
    const prior=slot.activeRunId?await req(s('runs').get(slot.activeRunId)):null;
    checkRunLedger(prior,profile);
    if(prior?.status==='active'){must(args.replace===true,'ACTIVE_RUN_EXISTS');prior.status='abandoned';prior.snapshot=null;await req(s('runs').put(prior));}
    slot.activeRunId=id;slot.revision=nextCounter(slot.revision);
    const created={id,revision:0,status:'active',snapshot,last_op:{request_id:args.request_id,kind,expected_slot:args.auth.expectedSlotRevision,expected_revision:-1,hash,result_slot:slot.revision,result_revision:0}};
    slot.writer.leaseUntil=Date.now()+60000;await req(s('runs').add(created));await req(s('slots').put(slot));
    return {ok:true,run:created,slotRevision:slot.revision,leaseUntil:slot.writer.leaseUntil,profile};
   }
   must(slot.activeRunId===id && validRun(run)&&run.status==='active','NOT_ACTIVE_RUN');must(integer(args.expected)&&run.revision===args.expected,'STALE_REVISION');
   must(snapshot.mode===run.snapshot.mode,'MODE_IMMUTABLE');const prior=upgradeSnapshot(run.snapshot);must(same(snapshot.draft,prior.draft),'DRAFT_IMMUTABLE');must(same(snapshot.talent_draft,prior.talent_draft),'TALENT_DRAFT_IMMUTABLE');must(same(snapshot.legacy_points,prior.legacy_points),'LEGACY_POINTS_IMMUTABLE');must(snapshot.cargo.version===prior.cargo.version&&snapshot.cargo.destination===prior.cargo.destination,'CARGO_BIRTH_IMMUTABLE');must(snapshot.rope.version===prior.rope.version,'ROPE_BIRTH_IMMUTABLE');if(prior.draft.choice==='')must(same(snapshot,prior),'DRAFT_PENDING');run.snapshot=snapshot;run.revision=nextCounter(run.revision);
   run.last_op={request_id:args.request_id,kind,expected_slot:args.auth.expectedSlotRevision,expected_revision:args.expected,hash,result_slot:slot.revision,result_revision:run.revision};
   slot.writer.leaseUntil=Date.now()+60000;await req(s('runs').put(run));await req(s('slots').put(slot));return {ok:true,run,slotRevision:slot.revision,leaseUntil:slot.writer.leaseUntil,profile};
  });
 }
 async chooseStrategy(args){
  must(validId(args.request_id)&&typeof args.choice==='string'&&(args.choice==='none'||STRATEGY_IDS.includes(args.choice)),'INVALID_STRATEGY');
  const allocation=allocationCopy(args.allocation);
  // Prepare a digest before opening the write transaction; compare the complete
  // prepared base again inside the transaction, in addition to slot/run CAS.
  const prepared=await this.active();const base=prepared.run?.snapshot;
  must(base&&prepared.run.id===args.id,'SUPERSEDED_OPERATION');
  const chosen=upgradeSnapshot(base);chosen.draft.choice=args.choice;chosen.legacy_points.study=allocation.study;chosen.legacy_points.reserve=allocation.reserve;chosen.legacy_reserves=allocation.reserve;
  const hash=await digestSnapshot(chosen);
  return this.transaction(['slots','runs','profiles','receipts'],'readwrite',async s=>{
   const slot=await loadSlot(s),profile=(await loadProfile(s)).profile;
   checkSlot(slot,{...args.auth,expectedSlotRevision:slot.revision});
   const run=await req(s('runs').get(args.id));must(validRun(run),'CORRUPT_RUN');checkRunLedger(run,profile);
   const last=run.last_op;
   if(last.request_id===args.request_id){
    must(last.kind==='strategy'&&last.expected_slot===args.auth.expectedSlotRevision&&last.expected_revision===args.expected&&run.snapshot.draft.choice===args.choice&&upgradeSnapshot(run.snapshot).legacy_points.study===allocation.study&&upgradeSnapshot(run.snapshot).legacy_points.reserve===allocation.reserve,'REQUEST_CONFLICT');
    must(slot.activeRunId===args.id&&slot.revision===last.result_slot&&run.revision===last.result_revision&&run.status==='active','SUPERSEDED_OPERATION');
    return {ok:true,run,slotRevision:slot.revision,leaseUntil:slot.writer.leaseUntil,profile,duplicate:true};
   }
   checkSlot(slot,args.auth,args.id);must(run.status==='active','RUN_NOT_ACTIVE');must(integer(args.expected)&&run.revision===args.expected,'STALE_REVISION');
   must(same(run.snapshot,base),'STALE_BASE');
   const prior=upgradeSnapshot(run.snapshot);
   must(prior.moves===0&&prior.ended_reason===''&&prior.draft.version===1&&prior.draft.choice===''&&(args.choice==='none'||prior.draft.offers.includes(args.choice)),'INVALID_STRATEGY');
   must(validDraft(chosen.seed_value,chosen.draft),'INVALID_DRAFT');must(validLegacyPoints(chosen),'INVALID_ALLOCATION');
   run.snapshot=chosen;run.revision=nextCounter(run.revision);slot.writer.leaseUntil=Date.now()+60000;
   run.last_op={request_id:args.request_id,kind:'strategy',expected_slot:args.auth.expectedSlotRevision,expected_revision:args.expected,hash,result_slot:slot.revision,result_revision:run.revision};
   await req(s('runs').put(run));
   if(databaseName.startsWith('magic-tower-journeys-v1-test-')&&args.test_abort==='after_choice')throw new StorageFault('INJECTED_ABORT_after_choice');
   await req(s('slots').put(slot));return {ok:true,run,slotRevision:slot.revision,leaseUntil:slot.writer.leaseUntil,profile};
  });
 }
 async settleJourney(args,isDeath=false) {
  const operation=isDeath?'death':'settle';
  if(isDeath){args={...args,outcome:'defeat'};must(Array.isArray(args.delta)&&args.delta.length===2&&args.delta.every(Number.isSafeInteger)&&Math.abs(args.delta[0])+Math.abs(args.delta[1])===1,'INVALID_DELTA');}
  must(validId(args.request_id)&&(isDeath?['defeat']:['withdrawn','chapter1','victory']).includes(args.outcome),'INVALID_OUTCOME');
  const base=snapshotCopy(args.base,true),ended=snapshotCopy(args.ended,true);
  const hash=await digestSnapshot(ended);
  must(base.run_id===args.id&&ended.run_id===args.id,'IDENTITY_MISMATCH');
  if(isDeath)validateDeathTransition(base,ended,args.delta);
  else {const onlyEnd=upgradeSnapshot(base);onlyEnd.ended_reason=ended.ended_reason;must(same(onlyEnd,ended),'INVALID_END_TRANSITION');}
  const expectedSummary=summaryOf(ended,args.outcome);
  const fail=point=>{if(databaseName.startsWith('magic-tower-journeys-v1-test-')&&args.test_abort===point)throw new StorageFault('INJECTED_ABORT_'+point)};
  return this.transaction(['slots','runs','profiles','receipts'],'readwrite',async s=>{
   const slot=await loadSlot(s),envelope=await loadProfile(s);
   checkSlot(slot,{...args.auth,expectedSlotRevision:slot.revision});
   const run=await req(s('runs').get(args.id));must(validRun(run),'CORRUPT_RUN');
   checkRunLedger(run,envelope.profile);
   const last=run.last_op;
   if(last.request_id===args.request_id){
    must(last.kind===operation&&(last.hash===hash||(run.snapshot.version<19&&same(upgradeSnapshot(run.snapshot),ended)))&&last.expected_revision===args.expected&&last.expected_slot===args.auth.expectedSlotRevision,'REQUEST_CONFLICT');
    const receipt=envelope.profile.receipts[args.id];
    must(receipt&&same(receipt.summary,expectedSummary),'REQUEST_CONFLICT');
    must(slot.activeRunId===args.id&&slot.revision===last.result_slot&&run.revision===last.result_revision&&run.status==='archived','SUPERSEDED_OPERATION');
    must(same(upgradeSnapshot(run.snapshot),ended),'REQUEST_CONFLICT');
    return {ok:true,run,slotRevision:slot.revision,leaseUntil:slot.writer.leaseUntil,receipt,profile:envelope.profile,duplicate:true};
   }
   checkSlot(slot,args.auth,args.id);
   must(run.status==='active','RUN_NOT_ACTIVE');must(integer(args.expected)&&run.revision===args.expected,'STALE_REVISION');
   must(run.snapshot.ended_reason===''&&same(run.snapshot,base),'STALE_BASE');
   must(upgradeSnapshot(run.snapshot).draft.choice!=='','DRAFT_PENDING');
   let authoritative;
   if(isDeath){validateDeathTransition(run.snapshot,ended,args.delta);authoritative=ended;}
   else {authoritative=upgradeSnapshot(run.snapshot);authoritative.ended_reason=ended.ended_reason;must(same(authoritative,ended),'INVALID_END_TRANSITION');}
   const summary=summaryOf(authoritative,args.outcome);
   const decision=settleProfile(envelope.profile,args.id,summary);
   must(decision.ok&&decision.status==='applied','PROFILE_'+decision.status.toUpperCase());
   envelope.profile=decision.profile;envelope.commitRevision=nextCounter(envelope.commitRevision);
   fail('before_writes');await req(s('profiles').put(envelope));fail('after_profile');
   await req(s('receipts').add({id:args.id,receipt:decision.receipt}));fail('after_receipt');
   run.snapshot=authoritative;run.status='archived';run.revision=nextCounter(run.revision);
   slot.revision=nextCounter(slot.revision);slot.writer.leaseUntil=Date.now()+60000;
   run.last_op={request_id:args.request_id,kind:operation,expected_slot:args.auth.expectedSlotRevision,expected_revision:args.expected,hash,result_slot:slot.revision,result_revision:run.revision};
   await req(s('runs').put(run));fail('after_archive');await req(s('slots').put(slot));fail('after_slot');
   return {ok:true,run,slotRevision:slot.revision,leaseUntil:slot.writer.leaseUntil,receipt:decision.receipt,profile:decision.profile};
  });
 }
 async active() {
  return this.transaction(['slots','runs','profiles','receipts'],'readonly',async s=>{
   const slot=await loadSlot(s),profile=(await loadProfile(s)).profile;
   const run=slot.activeRunId?await req(s('runs').get(slot.activeRunId)):null;
   checkRunLedger(run,profile);
   return {ok:true,run,slotRevision:slot.revision,profile,receipt:run?profile.receipts[run.id]||null:null};
  });
 }
}
const databaseName=typeof globalThis.MagicTowerJourneysTestDatabase==='string' && globalThis.MagicTowerJourneysTestDatabase.startsWith('magic-tower-journeys-v1-test-')?globalThis.MagicTowerJourneysTestDatabase:'magic-tower-journeys-v1';
let storePromise;
async function dispatch(operation,args){
 if(!storePromise)storePromise=ProfileStorage.open(databaseName).catch(e=>{storePromise=null;throw e});
 const store=await storePromise;
 if(operation==='open')return {ok:true};
 if(operation==='claim')return {ok:true,auth:await store.claimWriter(args.owner,args.lease_ms)};
 if(operation==='renew')return {ok:true,auth:await store.renewWriter(args.auth,args.lease_ms)};
 if(operation==='read')return store.active();
 if(operation==='strategy')return store.chooseStrategy(args);
 if(operation==='settle'||operation==='death')return store.settleJourney(args,operation==='death');
 if(operation==='create'||operation==='save')return store.writeJourney(operation,args);
 throw new StorageFault('UNSUPPORTED_OPERATION');
}
globalThis.MagicTowerJourneys={databaseName,request(encoded,callback){
 let message;try{message=JSON.parse(encoded)}catch{callback(JSON.stringify({request:-1,result:{ok:false,code:'INVALID_REQUEST'}}));return;}
 Promise.resolve().then(()=>dispatch(message.operation,message.args||{})).then(result=>callback(JSON.stringify({request:message.request,result})),error=>callback(JSON.stringify({request:message.request,result:{ok:false,code:error.code||error.name||'WEB_IO'}})));
}};
})();
