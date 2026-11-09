extends SceneTree
const Symbols=preload("res://scripts/map_symbols.gd")
func _init():
	assert(Symbols.TOKENS.size()==16)
	var unique:Dictionary={}
	for token in Symbols.TOKENS:
		assert(Symbols.supports(token));assert(not unique.has(token));unique[token]=true
	assert(not Symbols.supports("?"))
	assert(not Symbols.supports("s"))
	print("MAP SYMBOLS: PASS (coverage and unknown-token guard)")
	quit()
