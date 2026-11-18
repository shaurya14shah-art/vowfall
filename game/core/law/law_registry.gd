class_name LawRegistry
extends RefCounted
## Loads Root and Law definitions from JSON and resolves a law's form.
## Definitions are data. Nothing here knows what any particular law does.

var roots: Dictionary = {}
var defs: Dictionary = {}
var _resolved: Dictionary = {}


## JSON numbers arrive as floats. The engine works in integers only.
static func intify(v: Variant) -> Variant:
	if v is float:
		var f: float = v
		if f == floorf(f):
			return int(f)
		return v
	if v is Array:
		var a: Array = []
		for x: Variant in v:
			a.append(intify(x))
		return a
	if v is Dictionary:
		var d: Dictionary = {}
		for k: Variant in v:
			d[k] = intify(v[k])
		return d
	return v


static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("LawRegistry: missing file " + path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		push_error("LawRegistry: invalid JSON in " + path)
		return null
	return intify(parsed)


func load_roots(path: String) -> bool:
	var data: Variant = read_json(path)
	if not (data is Dictionary):
		return false
	roots = data.get("roots", {})
	return not roots.is_empty()


## Loads every *.json in a folder. Each file holds {"laws": [ ... ]}.
func load_laws_dir(dir: String) -> int:
	var count := 0
	var files := DirAccess.get_files_at(dir)
	files.sort()
	for f: String in files:
		if not f.ends_with(".json"):
			continue
		var data: Variant = read_json(dir.path_join(f))
		if not (data is Dictionary):
			continue
		for d: Dictionary in data.get("laws", []):
			add_def(d)
			count += 1
	return count


func add_def(d: Dictionary) -> void:
	defs[d["id"]] = d
	_resolved.clear()


func has_def(id: String) -> bool:
	return defs.has(id)


## A law as it stands for an owner in the given form. UNVEILED merges the
## "unveiled" block over the base: top-level keys replace, "add_clauses"
## appends.
func resolve(id: String, form: String = "DORMANT") -> Dictionary:
	var key := id + "|" + form
	if _resolved.has(key):
		return _resolved[key]
	if not defs.has(id):
		return {}
	var base: Dictionary = defs[id].duplicate(true)
	var over: Dictionary = base.get("unveiled", {})
	base.erase("unveiled")
	if form == "UNVEILED":
		for k: String in over:
			if k == "add_clauses":
				base["clauses"] = base["clauses"] + over[k]
			else:
				base[k] = over[k]
	_resolved[key] = base
	return base


func forms_of(id: String) -> Array:
	if defs.has(id) and defs[id].has("unveiled"):
		return ["DORMANT", "UNVEILED"]
	return ["DORMANT"]
