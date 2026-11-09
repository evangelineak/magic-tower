extends RefCounted
# English is the source language; rules are exact strings or anchored format templates.
const UI = preload("res://scripts/localization_ui.gd")
static var exact: Dictionary = {}
static var rules: Array = []
static var initialized := false
static func initialize():
	if initialized: return
	initialized=true
	var catalogs: Array=[UI]
	for path in ["res://scripts/localization_world.gd","res://scripts/localization_progression.gd"]:
		if ResourceLoader.exists(path): catalogs.append(load(path))
	for catalog in catalogs:
		exact.merge(catalog.EXACT,true)
		for pair in catalog.TEMPLATES:
			var pattern := "^"
			var i := 0
			while i<pair[0].length():
				var c: String=pair[0][i]
				if c=="%" and i+1<pair[0].length():
					var spec: String=pair[0][i+1]
					if spec in ["s","d"]:
						pattern+="(.*?)" if spec=="s" else "(-?[0-9]+)"
						i+=2; continue
					if spec=="%": pattern+="%"; i+=2; continue
				if c in ["\\",".","+","*","?","[","]","(",")","{","}","^","$","|"]: pattern+="\\"
				pattern+=c; i+=1
			var regex := RegEx.new()
			regex.compile(pattern+"$")
			rules.append([regex,pair[1],pair[0].replace("%s","").replace("%d","").length()])
	rules.sort_custom(func(a,b): return a[2]>b[2])
static func text(source: String, language: String="zh", depth: int=0) -> String:
	if language!="zh" or source.is_empty() or depth>6: return source
	initialize()
	if exact.has(source): return exact[source]
	for rule in rules:
		var result: RegExMatch=rule[0].search(source)
		if result:
			var out := ""
			var template: String=rule[1]
			var capture := 1
			var i := 0
			while i<template.length():
				if template[i]=="%" and i+1<template.length():
					if template[i+1] in ["s","d"]:
						out+=text(result.get_string(capture),language,depth+1)
						capture+=1; i+=2; continue
					if template[i+1]=="%": out+="%"; i+=2; continue
				out+=template[i]; i+=1
			return out
	if source==source.to_upper():
		for key in exact:
			if key.to_upper()==source: return exact[key]
	if source.contains(", "):
		var parts: PackedStringArray=source.split(", ")
		for i in parts.size(): parts[i]=text(parts[i],language,depth+1)
		return "、".join(parts)
	return source
