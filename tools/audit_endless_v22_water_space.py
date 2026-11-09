#!/usr/bin/env python3
"""Independent full-map water state graph, not the production validator.
Guard wins/key availability are spatial assumptions, not economic solvability.
Staircases are terminals, never intermediate same-floor flood cells.
"""
import argparse, json
from collections import deque
DIRS=((0,-1),(0,1),(-1,0),(1,0))
ASCII='''###############
#>............#
#.........#####
#....F....D.$##
#.....#b#.#####
#....#AAA######
#....#AAA######
###g#F....V.T##
#....#BBB######
#....#BBB#....#
#.....#b#.....#
#....F.....k..#
#..........SM.#
#..........Ca<#
###############'''.splitlines()
OVERRIDES={4:'#.....b##.#####',6:'#....###A######',8:'#....#B########',10:'#.....##b.....#'}
CONTROLS=((5,3),(5,7),(5,11));ISLAND=tuple((x,7) for x in range(6,10))
ENTRY=(13,13);EXIT=(1,1);DOOR=(10,3);CASH=(12,3);RELIC=(12,7)
KINDS='gbwrctp'
def adjacent(p):return [(p[0]+dx,p[1]+dy) for dx,dy in DIRS]
def fixture(variant):
 rows=ASCII.copy()
 if variant==1:
  for y,row in OVERRIDES.items():rows[y]=row
 assert len(rows)==15 and all(len(row)==15 for row in rows)
 grid={(x,y):c for y,row in enumerate(rows) for x,c in enumerate(row)}
 pools={label:frozenset(p for p,c in grid.items() if c==symbol) for label,symbol in [('north','A'),('south','B')]}
 guards=((3,7),(7,4) if variant==0 else (6,4),(7,10) if variant==0 else (8,10),(10,7))
 return grid,pools,guards
class ContractError(AssertionError):pass
def require(condition,code,details=None):
 if not condition:raise ContractError({'code':code,'details':details})
def check_grid(variant,initial,production):
 grid,pools,guards=fixture(variant)
 require(len(production)==15 and all(len(row)==15 for row in production),'grid_dimensions')
 actual={(x,y):c for y,row in enumerate(production) for x,c in enumerate(row)}
 expected=grid.copy()
 for p in pools['north']:expected[p]='.' if initial==0 else '~'
 for p in pools['south']:expected[p]='~' if initial==0 else '.'
 for p,canonical in zip(guards[:3],['g','b','b']):
  require(actual.get(p) in KINDS,'missing_route_guard',p);actual[p]=canonical
 require(actual==expected,'independent_ascii_mismatch')
def check_manifest(sample):
 grid,pools,guards=fixture(sample['variant']);m=sample['manifest']
 require(m.get('present') is True and m['variant']==sample['variant'] and m['initial_state']==sample['initial_state'] and m['floor']==sample['floor'],'manifest_identity')
 require(tuple(map(tuple,m['controls']))==CONTROLS,'manifest_controls')
 require(set(map(tuple,m['island']))==set(ISLAND),'manifest_island')
 require(tuple(m['entry'])==ENTRY and tuple(m['exit'])==EXIT and tuple(m['relic'])==RELIC,'manifest_terminals')
 require({k:tuple(v) for k,v in m['guardians'].items()}==dict(zip(['main','north','south','vault'],guards)),'manifest_guardians')
 require({k:frozenset(map(tuple,v)) for k,v in m['pools'].items()}==pools,'manifest_pools')
 check_grid(sample['variant'],0,sample['state0']);check_grid(sample['variant'],1,sample['state1'])
 require(sample['grid']==sample['state'+str(sample['initial_state'])],'initial_grid_state')
def inspect(variant,initial,production=None,mutation=None):
 grid,pools,guards=fixture(variant)
 if production is not None:check_grid(variant,initial,production)
 if mutation:
  mutation(grid)
  # Recompute physical pools from edited marker cells, not supplied manifest.
  pools={label:frozenset(p for p,c in grid.items() if c==symbol) for label,symbol in [('north','A'),('south','B')]}
 require(initial in (0,1),'initial_state')
 require(all(grid.get(p)=='F' for p in CONTROLS),'permanent_controls')
 require(all(grid.get(p)=='.' for p in ISLAND),'permanent_island')
 require(grid.get(ENTRY)=='<' and grid.get(EXIT)=='>','paired_stairs')
 require(grid.get(DOOR)=='D' and grid.get(CASH)=='$' and grid.get(RELIC)=='T','fixed_reward_contract')
 require(all(grid.get(p) in 'gbV' for p in guards),'permanent_guardians')
 require(not (pools['north'] & pools['south']),'disjoint_pools')
 forbidden=set(CONTROLS)|set(ISLAND)|set(guards)|{ENTRY,EXIT,DOOR,CASH,RELIC}
 require(not ((pools['north']|pools['south'])&forbidden),'entity_on_water')
 guard_index={p:i for i,p in enumerate(guards)}
 def walkset(water,cleared,opened):
  cells=set()
  for p,c in grid.items():
   if c in '#FMS<>':continue
   if c=='A' and water==1:continue
   if c=='B' and water==0:continue
   if p in guard_index and not (cleared>>guard_index[p]&1):continue
   if c=='D' and not opened:continue
   cells.add(p)
  return cells
 def flood(cells,start):
  require(start in cells,'player_not_dry',start)
  seen={start};queue=deque([start])
  while queue:
   for p in adjacent(queue.popleft()):
    if p in cells and p not in seen:seen.add(p);queue.append(p)
  return frozenset(seen)
 def state(water,cleared,opened,player):return water,cleared,opened,flood(walkset(water,cleared,opened),player)
 def touch(comp,stair):return any(p in comp for p in adjacent(stair))
 def toggles(cur):
  water,cleared,opened,comp=cur;targets=set()
  for valve in CONTROLS:
   for p in adjacent(valve):
    if p not in comp:continue
    require(p not in pools['north']|pools['south'],'valve_can_flood_player',p)
    targets.add(state(1-water,cleared,opened,p))
  return targets
 def recover(cur,origin):
  seen={cur};todo=[cur]
  while todo:
   node=todo.pop()
   if touch(node[3],origin):return True
   for new in toggles(node):
    if new not in seen:seen.add(new);todo.append(new)
  return False
 reports=[]
 for origin,destination in [(ENTRY,EXIT),(EXIT,ENTRY)]:
  starts=[p for p in adjacent(origin) if p in walkset(initial,0,False)]
  require(starts,'entrance_cannot_depart')
  begin=state(initial,0,False,starts[0])
  require(all(p in begin[3] for p in starts),'stair_only_connects_entrance_pockets')
  seen={begin:[]};queue=deque([begin]);terminal_masks=set();recovery_cache={}
  while queue:
   cur=queue.popleft();water,cleared,opened,comp=cur;path=seen[cur]
   require(ENTRY not in comp and EXIT not in comp,'stair_used_as_shortcut')
   require(opened or CASH not in comp,'door_reward_bypass',path)
   require(cleared&8 or RELIC not in comp,'island_guard_bypass',path)
   if touch(comp,destination):
    terminal_masks.add(cleared)
    require(cleared!=0,'zero_combat_traversal',path)
    require(cleared&1 or cleared&6==6,'branch_guard_bypassed',{'mask':cleared,'path':path})
   if cur not in recovery_cache:recovery_cache[cur]=recover(cur,origin)
   require(recovery_cache[cur],'softlock_needs_new_combat_or_key',path)
   edges=[('toggle',n) for n in toggles(cur)]
   for p,index in guard_index.items():
    if not cleared>>index&1 and any(n in comp for n in adjacent(p)):
     edges.append(('fight_'+str(index),state(water,cleared|1<<index,opened,p)))
   if not opened and any(n in comp for n in adjacent(DOOR)):
    edges.append(('open_D',state(water,cleared,True,DOOR)))
   for action,new in edges:
    if new not in seen:seen[new]=path+[action];queue.append(new)
  covered=set().union(*(node[3] for node in seen))
  potential=walkset(0,15,True)|walkset(1,15,True)
  require(potential<=covered,'orphan_floor_cells',sorted(potential-covered))
  require(1 in terminal_masks,'main_single_guard_path_missing',sorted(terminal_masks))
  require(6 in terminal_masks,'branch_two_guard_path_missing',sorted(terminal_masks))
  require(any(RELIC in node[3] for node in seen),'relic_unreachable')
  require(any(CASH in node[3] for node in seen),'cash_unreachable')
  reports.append({'origin':origin,'states':len(seen),'terminal_guard_masks':sorted(terminal_masks),'all_states_recover_without_new_battle_or_key':True})
 return {'variant':variant,'initial_state':initial,'directions':reports}
def mutation_tests():
 mutations=[('main_bypass',lambda g:g.__setitem__((4,7),'.')),
 ('north_bypass_0',lambda g:g.__setitem__((6,4),'.')),
 ('south_bypass_0',lambda g:g.__setitem__((6,10),'.')),
 ('cash_bypass',lambda g:[g.__setitem__((x,2),'.') for x in range(10,13)]),
 ('relic_bypass',lambda g:[g.__setitem__((x,6),'.') for x in range(9,13)]),
 ('lost_island_valve',lambda g:g.__setitem__((5,7),'#')),
 ('water_on_guardian',lambda g:g.__setitem__((3,7),'A')),
 ('isolated_floor_pocket',lambda g:g.__setitem__((11,5),'.'))]
 results=[]
 for name,mutate in mutations:
  try:inspect(0,0,mutation=mutate)
  except ContractError as e:results.append({'mutation':name,'rejected':True,'reason':e.args[0]['code']})
  else:raise ContractError({'code':'mutation_not_rejected','mutation':name})
 return results
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--production-json');args=parser.parse_args()
 results=[inspect(v,s) for v in (0,1) for s in (0,1)]
 samples=[]
 if args.production_json:
  export=json.load(open(args.production_json))
  require(not export.get('problems'),'export_problems',export.get('problems'))
  require(export.get('distribution_samples')==40000,'distribution_sample_count')
  distribution=export.get('distribution',{})
  require(set(distribution)=={'0:0','0:1','1:0','1:1'} and sum(distribution.values())==40000 and all(9000<=n<=11000 for n in distribution.values()),'shape_state_sampling_regression',distribution)
  for sample in export['samples']:
   check_manifest(sample)
   result=inspect(sample['variant'],sample['initial_state'],sample['grid']);result.update(seed=sample['seed'],floor=sample['floor']);samples.append(result)
  require({(s['variant'],s['initial_state']) for s in samples}=={(0,0),(0,1),(1,0),(1,1)},'sample_missing_variant_state')
 print(json.dumps({'ok':True,'independent':results,'production_cross_checks':samples,'mutations':mutation_tests(),'distribution':export.get('distribution',{}) if args.production_json else {},'distribution_scope':'40k fixed sample with broad regression bounds, not a randomness proof','scope':'Independent spatial abstraction: optional fight transitions assume survivability and D opening assumes a key; no resource or universal gameplay solvability guarantee.'},ensure_ascii=False))
