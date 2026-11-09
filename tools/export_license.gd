extends SceneTree
# Obtain notices from the exact engine used to build the distribution.
func _initialize():
	var args := OS.get_cmdline_user_args()
	if args.size()!=1:
		printerr('Usage: godot --headless --script tools/export_license.gd -- OUTPUT_FILE')
		quit(1)
		return
	var file := FileAccess.open(args[0],FileAccess.WRITE)
	if file==null:
		printerr('Cannot write license file: ',args[0])
		quit(1)
		return
	file.store_string(Engine.get_license_text()+"\n\nTHIRD-PARTY COMPONENTS\n\n")
	for entry in Engine.get_copyright_info():
		file.store_string(JSON.stringify(entry,'  ')+"\n\n")
	file.store_string("LICENSE TEXTS\n\n")
	var licenses := Engine.get_license_info()
	for key in licenses:
		file.store_string(str(key)+"\n"+str(licenses[key])+"\n\n")
	file.close()
	quit()
