extends Node
## Autoload "Sfx". Placeholder sound: a small pool of 3D players and a table
## of CC0 clips. Presentation only; silent and harmless when headless.

const CLIPS := {
	"swing": ["res://assets/placeholder/sfx/cloth1.ogg", "res://assets/placeholder/sfx/cloth2.ogg"],
	"cloth": ["res://assets/placeholder/sfx/cloth2.ogg"],
	"hit": ["res://assets/placeholder/sfx/knifeSlice.ogg", "res://assets/placeholder/sfx/knifeSlice2.ogg"],
	"heavy": ["res://assets/placeholder/sfx/chop.ogg"],
	"guard": ["res://assets/placeholder/sfx/metalPot1.ogg", "res://assets/placeholder/sfx/metalPot2.ogg"],
	"parry": ["res://assets/placeholder/sfx/metalClick.ogg"],
	"denied": ["res://assets/placeholder/sfx/metalLatch.ogg"],
	"seal": ["res://assets/placeholder/sfx/bookClose.ogg"],
	"dodge": ["res://assets/placeholder/sfx/drawKnife1.ogg"],
	"death": ["res://assets/placeholder/sfx/doorClose_1.ogg"],
}
const POOL := 12

var _streams: Dictionary = {}
var _players: Array = []
var _next: int = 0


func _ready() -> void:
	for key: String in CLIPS:
		var list: Array = []
		for path: String in CLIPS[key]:
			if ResourceLoader.exists(path):
				list.append(load(path))
		_streams[key] = list
	for i in POOL:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 6.0
		p.max_distance = 40.0
		add_child(p)
		_players.append(p)


func _exit_tree() -> void:
	for p: AudioStreamPlayer3D in _players:
		p.stop()
		p.stream = null


func play_at(key: String, where: Vector3, db: float = 0.0, pitch: float = 1.0) -> void:
	var list: Array = _streams.get(key, [])
	if list.is_empty():
		return
	var p: AudioStreamPlayer3D = _players[_next]
	_next = (_next + 1) % POOL
	p.stream = list[_next % list.size()]
	p.global_position = where
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()
