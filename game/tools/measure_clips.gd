extends SceneTree
## When does each clip connect? Prints, per clip, its length and the moment
## each hand and the right foot moves fastest. Frame data in
## data/instruments/*.json is fitted to these numbers (anim_hit).
##   godot --headless --path game --script res://tools/measure_clips.gd -- [clip name contains...]

func _initialize() -> void:
	_go()


func _go() -> void:
	await process_frame
	var want := OS.get_cmdline_user_args()
	var m := CharacterModel.new()
	root.add_child(m)
	m.setup("res://assets/models/figures/witness.glb")
	var bones := {"right hand": m.skeleton.find_bone("handslot.r"), "left hand": m.skeleton.find_bone("handslot.l"), "right foot": m.skeleton.find_bone("toes.r")}
	for clip: String in m.anim.get_animation_list():
		var keep := want.is_empty()
		for w: String in want:
			if clip.contains(w):
				keep = true
		if not keep:
			continue
		var length := m.anim.get_animation(clip).length
		var line := "%-34s %.2fs " % [clip, length]
		for label: String in bones:
			var prev := Vector3.ZERO
			var best := 0.0
			var at := 0.0
			var reach := 0.0
			for i in int(length * 60.0) + 1:
				var t := float(i) / 60.0
				m.anim.play(clip, 0.0)
				m.anim.seek(t, true)
				m.anim.advance(0.0)
				m.skeleton.force_update_all_bone_transforms()
				var p: Vector3 = m.skeleton.get_bone_global_pose(bones[label]).origin
				if i > 0 and (p - prev).length() * 60.0 > best:
					best = (p - prev).length() * 60.0
					at = t
				reach = maxf(reach, p.z)
				prev = p
			line += " | %s %4.1f m/s at %.2fs, fwd %.2f" % [label, best, at, reach]
		print(line)
	quit()
