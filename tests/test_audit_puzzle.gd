extends SceneTree
const A=preload("res://scripts/audit_puzzle.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok: failures+=1; push_error(label)
func _init():
 var orders=[[0,1,2],[0,2,1],[1,0,2],[1,2,0],[2,0,1],[2,1,0]]
 for answer in range(3):
  for base in range(3):
   if answer==base: continue
   for required in [1,2]:
    var raw=[{"box":base,"positive":true},{"box":base,"positive":false},{"box":answer,"positive":required==2}]
    for order in orders:
     var p={"version":1,"truth_count":required,"claims":[raw[order[0]],raw[order[1]],raw[order[2]]],"solution":answer}
     check(A.valid(p),"all 72 supported label layouts have one proven answer")
     # Independent truth tally, not just module's solution helper.
     var winners=[]
     for candidate in range(3):
      var total=0
      for claim in p.claims:
       if (candidate==claim.box and claim.positive) or (candidate!=claim.box and not claim.positive): total+=1
      if total==required: winners.append(candidate)
     check(winners==[answer],"independent candidate enumeration agrees")
 for n in range(100):
  var p=A.generate(n)
  check(A.valid(p) and p==A.generate(n),"seed gives reproducible valid evidence")
  var restored=JSON.parse_string(JSON.stringify(p))
  check(A.valid(restored) and A.canonical(restored)==p,"JSON preserves claims and exact answer")
  check(A.lines(p).size()==4 and A.explanation(p).size()==4,"four-line clues plus four-line explanation")
 var p=A.generate(42)
 var bad=p.duplicate(true); bad.solution=(int(p.solution)+1)%3
 check(not A.valid(bad),"wrong stored solution rejected")
 bad=p.duplicate(true); bad.claims[1]=bad.claims[0].duplicate()
 check(not A.valid(bad),"duplicate propositions rejected")
 bad=p.duplicate(true); bad.truth_count=1.5
 check(not A.valid(bad),"fractional truth count rejected")
 bad=p.duplicate(true); bad.claims[0].positive=1
 check(not A.valid(bad),"nonboolean polarity rejected")
 bad={"version":1,"truth_count":1,"claims":[{"box":0,"positive":true},{"box":1,"positive":true},{"box":2,"positive":true}],"solution":0}
 check(not A.valid(bad),"three valid answers rejected even if stored answer is one of them")
 for value in [4294967296,1e100,-1,INF,NAN]:
  bad=p.duplicate(true); bad.solution=value
  check(not A.valid(bad),"unbounded answer rejected before integer conversion")
 for value in [true,false,4294967296,1e100,-1,INF,NAN]:
  bad=p.duplicate(true); bad.truth_count=value
  check(not A.valid(bad),"invalid truth-count type/range rejected")
  bad=p.duplicate(true); bad.claims[0].box=value
  check(not A.valid(bad),"invalid proposition box rejected before integer conversion")
 seed(411); var first=randi(); A.generate(123); var after=randi()
 seed(411); check(randi()==first and randi()==after,"puzzle RNG never consumes global/map RNG stream")
 print("AUDIT PUZZLE: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
 quit(0 if failures==0 else 1)
