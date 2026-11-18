class_name Seal
extends Actor
## What the Imprimatur leaves on the floor where it comes down: a seal of
## wax and gold a stride and a half across. It is a thing in the fight. It
## can be struck, and it can be bound as one half of a pair, which is one of
## the ways the Arbiter's Writs can be got around: they protect him, not it.

const LIFE_TICKS := 1500

var life: int = LIFE_TICKS
var spent: bool = false         # broken or faded: its maker should clear it away


func _init() -> void:
	display_name = "The Arbiter's seal"
	team = 2
	max_hp = 50
	max_poise = 0
	immovable = true
	hurt_radius = 0.75
	tags = ["construct", "seal"]
	collision_layer = 0
	collision_mask = 0


func _build_model() -> void:
	var scene := load("res://assets/models/props/seal_mark.glb") as PackedScene
	if scene != null:
		add_child(scene.instantiate())


func _physics_process(_delta: float) -> void:
	if bridge == null:
		return
	machine.tick(false, false, false, false)
	life -= 1
	if life <= 0:
		spent = true


func on_hit(_from: Actor, _m: Dictionary) -> void:
	pass


func on_death() -> void:
	machine.die()
	spent = true
