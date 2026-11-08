class_name TowerAuditPuzzle
extends RefCounted
const VERSION=1
const BOXES=["A","B","C"]
static func integer(value)->bool:
 return (value is int or value is float) and is_finite(float(value)) and value==floor(value)
static func generate(seed_value:int)->Dictionary:
 var rng=RandomNumberGenerator.new()
 rng.seed=seed_value ^ 0x6A17C3
 var solution=rng.randi_range(0,2)
 var other=(solution+rng.randi_range(1,2))%3
 var truth_count=rng.randi_range(1,2)
 # Complementary first two propositions contribute exactly one true label.
 # The third, different proposition uniquely identifies the genuine box.
 var claims=[{"box":other,"positive":true},{"box":other,"positive":false},{"box":solution,"positive":truth_count==2}]
 for i in range(2,0,-1):
  var j=rng.randi_range(0,i)
  var swap=claims[i]; claims[i]=claims[j]; claims[j]=swap
 return {"version":VERSION,"truth_count":truth_count,"claims":claims,"solution":solution}
static func truth(claim:Dictionary,box:int)->bool:
 return (int(claim.box)==box)==claim.positive
static func solutions(puzzle:Dictionary)->Array:
 var result=[]
 for box in range(3):
  var count=0
  for claim in puzzle.claims:
   if truth(claim,box): count+=1
  if count==int(puzzle.truth_count): result.append(box)
 return result
static func valid(puzzle)->bool:
 if not puzzle is Dictionary or puzzle.size()!=4: return false
 if not integer(puzzle.get("version")) or puzzle.version!=VERSION: return false
 if not integer(puzzle.get("truth_count")) or puzzle.truth_count<1 or puzzle.truth_count>2: return false
 if not integer(puzzle.get("solution")) or puzzle.solution<0 or puzzle.solution>2: return false
 if not puzzle.get("claims") is Array or puzzle.claims.size()!=3: return false
 var unique={}; var boxes={}
 for claim in puzzle.claims:
  if not claim is Dictionary or claim.size()!=2 or not integer(claim.get("box")) or claim.box<0 or claim.box>2 or not claim.get("positive") is bool: return false
  var key="%d:%s" % [int(claim.box),str(claim.positive)]
  if unique.has(key): return false
  unique[key]=true; boxes[int(claim.box)]=true
 if boxes.size()<2: return false
 var matches=solutions(puzzle)
 return matches.size()==1 and int(matches[0])==int(puzzle.solution)
static func canonical(puzzle:Dictionary)->Dictionary:
 var claims=[]
 for claim in puzzle.claims: claims.append({"box":int(claim.box),"positive":claim.positive})
 return {"version":VERSION,"truth_count":int(puzzle.truth_count),"claims":claims,"solution":int(puzzle.solution)}
static func lines(puzzle:Dictionary)->Array:
 var result=["One box holds the genuine certificate. Exactly %d labels are true." % int(puzzle.truth_count)]
 for i in range(3):
  var claim:Dictionary=puzzle.claims[i]
  result.append(("Label %s: the certificate is in box %s." if claim.positive else "Label %s: the certificate is NOT in box %s.") % [BOXES[i],BOXES[int(claim.box)]])
 return result
static func explanation(puzzle:Dictionary)->Array:
 var result=["Only box %s satisfies the stated truth count." % BOXES[int(puzzle.solution)]]
 for i in range(3):
  result.append(("Label %s is true." if truth(puzzle.claims[i],int(puzzle.solution)) else "Label %s is false.") % BOXES[i])
 return result
