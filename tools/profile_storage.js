/* Standalone IndexedDB prototype. NOT imported by the game or its user:// save.
 * Profile/receipt schema matches legacy_profile.gd; storage versions are separate.
 */
export class StorageFault extends Error {
  constructor(code) { super(code); this.name = 'StorageFault'; this.code = code; }
}
const req = r => new Promise((ok, no) => { r.onsuccess = () => ok(r.result); r.onerror = () => no(r.error); });
const must = (value, code) => { if (!value) throw new StorageFault(code); };
const integer = (n, max = Number.MAX_SAFE_INTEGER) => Number.isSafeInteger(n) && n >= 0 && n <= max;
export function nextCounter(value) {
  must(integer(value) && value < Number.MAX_SAFE_INTEGER, 'COUNTER_EXHAUSTED');
  return value + 1;
}
export const MAX_RUNS=4096;
export const MAX_SNAPSHOT_BYTES=1048576;
const IDS = ['legacy_scout', 'legacy_tactician', 'legacy_veteran'];
const LEVELS = [3, 5, 8];
const fresh = () => ({ revision: 1, milestones: [], receipts: {}, unlocked: [] });
function snapshotCopy(snapshot) {
  const s = structuredClone(snapshot);
  let encoded; try {encoded=JSON.stringify(s);}catch{throw new StorageFault('INVALID_SNAPSHOT');}
  must(typeof encoded==='string' && new TextEncoder().encode(encoded).length<=MAX_SNAPSHOT_BYTES,'SNAPSHOT_TOO_LARGE');
  must(s && [5, 8].includes(s.floor_seen?.length) && s.floor_seen.every(x => typeof x === 'boolean') && s.floor_seen[0], 'INVALID_SNAPSHOT');
  must(!s.floor_seen.some((seen,i) => seen && s.floor_seen.slice(0,i).includes(false)), 'INVALID_SNAPSHOT');
  must(integer(s.floor) && s.floor < s.floor_seen.length && s.floor_seen[s.floor], 'INVALID_SNAPSHOT');
  must(typeof s.won === 'boolean' && Number.isSafeInteger(s.hp) && s.hp > 0 && integer(s.moves, 10000000) && integer(s.seed_value, 2147483647), 'INVALID_SNAPSHOT');
  return s;
}
function summaryOf(snapshot, outcome) {
  const s = snapshotCopy(snapshot);
  must(['withdrawn', 'chapter1', 'victory'].includes(outcome), 'INVALID_OUTCOME');
  const max_floor = s.floor_seen.reduce((n, seen, i) => seen ? i + 1 : n, 0);
  if (outcome === 'chapter1') must(s.won && s.floor_seen.length === 5 && max_floor === 5, 'NOT_CHAPTER1_WIN');
  if (outcome === 'victory') must(s.won && s.floor_seen.length === 8 && max_floor === 8, 'NOT_FINAL_WIN');
  return { seed: s.seed_value, max_floor, moves: s.moves, outcome };
}
const keysExactly=(o,keys)=>o && typeof o==='object' && !Array.isArray(o) && Object.keys(o).length===keys.length && keys.every(k=>Object.hasOwn(o,k));
function validSummary(x) { return keysExactly(x,['seed','max_floor','moves','outcome']) && integer(x.seed,2147483647) && integer(x.max_floor,8) && x.max_floor>=1 && integer(x.moves,10000000) && ['withdrawn','chapter1','victory','defeat'].includes(x.outcome) && (x.outcome!=='chapter1'||x.max_floor>=5) && (x.outcome!=='victory'||x.max_floor===8); }
export function validateProfile(p) {
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
export function settleProfile(profile,run_id,summary) {
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
  try { return r && validId(r.id) && integer(r.revision) && ['active','archived','abandoned'].includes(r.status) && !!snapshotCopy(r.snapshot); } catch { return false; }
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
  must(slot && slot.id==='active' && integer(slot.revision) && integer(slot.lastFence) && (slot.activeRunId===null || validId(slot.activeRunId)),'CORRUPT_SLOT');
  if(slot.writer!==null) must(slot.writer && typeof slot.writer.owner==='string' && slot.writer.owner.length>0 && slot.writer.owner.length<200 && integer(slot.writer.fence) && slot.writer.fence>0 && slot.writer.fence===slot.lastFence && integer(slot.writer.leaseUntil),'CORRUPT_SLOT');
  if(slot.activeRunId!==null) { const run=await req(stores('runs').get(slot.activeRunId));must(validRun(run),'CORRUPT_RUN'); }
  return slot;
}
function checkSlot(slot, auth, activeId = undefined) {
  must(auth && slot.writer && slot.writer.owner === auth.owner && slot.writer.fence === auth.fence && slot.writer.leaseUntil > Date.now(), 'STALE_WRITER');
  must(slot.revision === auth.expectedSlotRevision, 'STALE_SLOT_REVISION');
  if (activeId !== undefined) must(slot.activeRunId === activeId, 'NOT_ACTIVE_RUN');
}
export class ProfileStorage {
  static async open(name = 'magic-tower-profile-harness-v2') {
    must(name.startsWith('magic-tower-profile-harness'), 'UNSAFE_DATABASE_NAME');
    const opening = indexedDB.open(name, 2);
    opening.onupgradeneeded = () => {
      for (const name of ['profiles', 'runs', 'receipts', 'slots']) if (!opening.result.objectStoreNames.contains(name)) opening.result.createObjectStore(name, { keyPath: 'id' });
    };
    const db = await req(opening); db.onversionchange = () => db.close();
    return new ProfileStorage(db);
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
