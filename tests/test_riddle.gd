extends SceneTree
const R=preload("res://scripts/riddle.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String):
	checks+=1
	if not ok: failures+=1;push_error("RIDDLE: "+text)
func _init():
	var unique:Dictionary={}
	for seed_value in range(24):
		var answer=R.solution(seed_value)
		unique[JSON.stringify(answer)]=true
		check(answer.size()==4 and R.valid_input(answer),"every seed gives four distinct valid symbols")
		check(answer==R.solution(seed_value+24),"permutation selection repeats only after24")
		check(R.clues(seed_value).size()==3,"exactly three independent clue sources")
		var matches=0
		var missing=[0,0,0]
		for candidate_seed in range(24):
			var candidate=R.solution(candidate_seed)
			if R.satisfies_clues(seed_value,candidate):
				matches+=1
				check(candidate==answer,"the satisfying arrangement equals generated target")
			for i in range(3):
				if R.satisfies_clues(seed_value,candidate,7^(1<<i)): missing[i]+=1
		check(matches==1,"all three clues have a unique solution")
		check(missing==[3,6,2],"each individual clue is needed; deleting it leaves multiple solutions")
		var a=answer[1];var b=answer[2];var c=answer[3];var d=answer[0]
		check(R.SYMBOLS[a] in R.clues(seed_value)[0],"first clue describes interior symbol")
		check(R.SYMBOLS[b] in R.clues(seed_value)[1] and R.SYMBOLS[c] in R.clues(seed_value)[1],"second clue names adjacent pair")
		check(R.SYMBOLS[d] in R.clues(seed_value)[2] and R.SYMBOLS[a] in R.clues(seed_value)[2],"third clue names ordering pair")
	check(unique.size()==24,"all24 permutations reachable")
	check(R.solution(-1)==R.solution(23),"negative direct seeds normalize safely")
	check(R.solution(2147483647)==R.solution(2147483647%24),"large seed stable")
	check(R.valid_input([]) and R.valid_input(["sun","key"]),"empty and partial inputs valid")
	check(not R.valid_input(R.solution(0),false),"unsolved save cannot contain four entries")
	for bad in [["sun","sun"],["unknown"],[1],[null],["Sun"],["sun","moon","tower","key","sun"]]:
		check(not R.valid_input(bad),"bad symbols or repeats rejected")
		check(not R.satisfies_clues(0,bad),"invalid arrangement cannot satisfy clues")
	var copy=R.solution(0);copy.clear()
	check(R.solution(0).size()==4 and R.SYMBOL_IDS.size()==4,"returned array cannot mutate source or future answer")
	print("RIDDLE: %s (%d checks)"%["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
