#!/usr/bin/env python3
"""Independent cart state graph; no production validator or path-finder.
Optional --production-json accepts a Godot export of actual generated grids.
"""
import argparse,json,sys
from collections import deque,Counter
D={'U':(0,-1),'D':(0,1),'L':(-1,0),'R':(1,0)}
def add(a,b):return(a[0]+b[0],a[1]+b[1])
def flood(walk,start,cart):
 seen={start};q=deque([start])
 while q:
  p=q.popleft()
  for d in D.values():
   n=add(p,d)
   if n in walk and n!=cart and n not in seen:seen.add(n);q.append(n)
 return frozenset(seen)

ASCII='''###############
#<aC#J##L######
#.M.#.##V######
#..k#u##v.D.$##
#.S.#.q...#####
#...#o.#......#
#......O......#
#...R.........#
#.............#
###g##b########
#....#b#..V.T##
#.........#####
#.............#
#............>#
###############'''.splitlines()
assert all(len(r)==15 for r in ASCII)
base={(x,y):c for y,r in enumerate(ASCII) for x,c in enumerate(r)}
SLOTS={'supply':(5,5),'archive':(6,4)};GATES={'supply':(5,3),'archive':(8,3)};REWARDS={'supply':(5,1),'archive':(8,1)}
START=(3,7);RESET=(4,7);GUARD=(8,2)
def full(variant,production=None):
 grid=base.copy();origin=(7,6) if variant==1 else (7,7)
 if variant==2:
  grid[7,5]='.';grid[6,6]='#';grid[7,6]='.';grid[7,7]='O'
 if production is not None:
  actual={(x,y):c for y,row in enumerate(production) for x,c in enumerate(row)}
  for p,canonical in [((3,9),'g'),((6,9),'b'),((6,10),'b')]:
   assert actual[p] in 'gbwrctp', ('missing main guard',p,actual[p])
   actual[p]=canonical
  assert actual==grid, 'production grid differs from independently specified ASCII'
  grid=actual
 track={(x,y) for x in range(5,9) for y in range(4,8) if grid[x,y]!='#'}
 def walkset(cart,claim,alive,extra_block=set(),combat=False):
  allowed={p for p,t in grid.items() if t not in '#RMS' and p!=cart and p not in extra_block}
  for label,gate in GATES.items():
   if (claim!=label if claim else cart!=SLOTS[label]):allowed.discard(gate)
  if not combat:
   for p,t in grid.items():
    if t in '<>':allowed.discard(p)
   for p,t in grid.items():
    if t in 'gbDV':allowed.discard(p)
   if not alive:allowed.add(GUARD)
  for label,reward in REWARDS.items():
   if not claim:allowed.discard(reward)
   # Once claimed both rewards gone; chosen gate latched, other gate closed.
  return allowed
 def component(cart,player,claim,alive):return flood(walkset(cart,claim,alive),player,cart)
 def state(cart,player,claim,alive):return cart,component(cart,player,claim,alive),claim,alive
 initial=state(origin,START,'',True);seen={initial:[]};queue=deque([initial]);viol=[];minpush={};metrics=Counter()
 while queue:
  cur=queue.popleft();cart,comp,claim,alive=cur;path=seen[cur];metrics['states']+=1
  if START not in comp:viol.append(('no_safe_exit',path))
  for required in [(2,1),(3,1)]:
   if required not in comp:viol.append(('entry_training_requires_stair_transition',required,path))
  if not claim and not any(add(RESET,d) in comp for d in D.values()):viol.append(('no_adjacent_reset',path))
  for label,slot in SLOTS.items():
   if cart==slot and not claim:
    pushes=sum(x.startswith('push') for x in path)
    minpush[label]=min(minpush.get(label,999),pushes)
  # Independent full-map cuts, removing combat/reward obstacles except tested blockers.
  def reachable(blocks):return flood(walkset(cart,claim,False,set(blocks),True),(1,1),cart)
  main=(3,9);side=[(6,9),(6,10)];exit=(13,13)
  if exit in reachable([main]+side):viol.append(('zero_guard_route',path))
  if exit not in reachable(side):viol.append(('main_route_broken',path))
  if exit not in reachable([main]):viol.append(('side_route_broken',path))
  for g in side:
   if exit in reachable([main,g]):viol.append(('side_guard_bypassed',g,path))
  if (12,3) in reachable([(10,3)]):viol.append(('D_bypass',path))
  if (12,10) in reachable([(10,10)]):viol.append(('V_bypass',path))
  edges=[]
  if not claim:
   for code,d in D.items():
    back=(cart[0]-d[0],cart[1]-d[1]);front=add(cart,d)
    if back in comp and front in track:edges.append(('push'+code,state(front,cart,claim,alive)))
   for p in comp:
    if abs(p[0]-RESET[0])+abs(p[1]-RESET[1])==1 and p!=origin:
     edges.append(('reset',state(origin,p,claim,alive)));break
   for label,reward in REWARDS.items():
    if any(add(reward,d) in comp for d in D.values()):edges.append(('claim_'+label,state(cart,reward,label,alive)))
  if alive and any(add(GUARD,d) in comp for d in D.values()):edges.append(('fight_guard',state(cart,GUARD,claim,False)))
  for code,nxt in edges:
   if nxt not in seen:seen[nxt]=path+[code];queue.append(nxt)
 result={'variant':variant,'states':len(seen),'claim_states':dict(Counter(s[2] or 'none' for s in seen)),'minimum_pushes':minpush,'violations':viol[:8],'violation_count':len(viol),'scope':'independent spatial abstraction; guard fight assumes survivable, reward claim assumes nonzero gain/capacity'}
 assert not viol,result
 assert minpush=={'archive':3 if variant==1 else 4,'supply':3 if variant==1 else 4},result
 return result
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--production-json');args=parser.parse_args()
 results=[full(v) for v in (1,2)]
 samples=[]
 if args.production_json:
  for sample in json.load(open(args.production_json))['samples']:
   result=full(sample['variant'],sample['grid']);result.update(seed=sample['seed'],floor=sample['floor']);samples.append(result)
 print(json.dumps({'independent':results,'production_cross_checks':samples,'ok':True},ensure_ascii=False))
