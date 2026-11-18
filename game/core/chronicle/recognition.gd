class_name Recognition
extends RefCounted
## Recognition Trials: what a bearer has done with each law, measured
## against what that law's Instrument asks before it will wake.
##
## Pure: it is fed what the Law Engine noted (which clause of which law
## spoke, and how much it moved) and keeps a count. It belongs to a
## character and will be saved with their Chronicle.

var trials: Dictionary = {}
var have: Dictionary = {}


func _init(path: String = "res://data/trials.json") -> void:
	var data: Variant = LawRegistry.read_json(path)
	if data is Dictionary:
		trials = data.get("trials", {})


func observe(law_id: String, clause: String, amount: int) -> void:
	if not trials.has(law_id):
		return
	var t: Dictionary = trials[law_id]
	if t.clause != clause:
		return
	var step: int = amount if t.measure == "SUM" else 1
	have[law_id] = mini(int(t.need), int(have.get(law_id, 0)) + step)


func progress(law_id: String) -> Array:
	if not trials.has(law_id):
		return [0, 0]
	return [int(have.get(law_id, 0)), int(trials[law_id].need)]


func complete(law_id: String) -> bool:
	var p := progress(law_id)
	return p[1] > 0 and p[0] >= p[1]


func text(law_id: String) -> String:
	return trials.get(law_id, {}).get("text", "")


func to_dict() -> Dictionary:
	return {"have": have.duplicate()}


func from_dict(d: Dictionary) -> void:
	have = LawRegistry.intify(d.get("have", {}))
