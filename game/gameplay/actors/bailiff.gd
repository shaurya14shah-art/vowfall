class_name Bailiff
extends Enemy
## The plain Court Bailiff. Everything it is lives in data/enemies/bailiff.json.


func _init() -> void:
	super._init()
	load_archetype("bailiff")
