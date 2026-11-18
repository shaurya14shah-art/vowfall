extends Node
## Draws a plan of the Assize Quarter from what is actually built: the solid
## blocks of its stone, and where its data puts stones, keepers, records and
## gates. Headless; writes an SVG. North (+Z) is up, so +X is to the left.
##
##   godot --headless --path game res://scenes/tools/MapQuarter.tscn -- /abs/out.svg

const SCALE := 9.0          # pixels per metre
const X0 := 62.0            # world x at the left edge (+X is left)
const Z1 := 126.0           # world z at the top edge
const W := 112.0
const H := 152.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://assize_quarter.svg")
	Arena.test_mode = true
	var q: Quarter = (load("res://scenes/Quarter.tscn") as PackedScene).instantiate()
	add_child(q)
	await get_tree().physics_frame
	var svg: Array = []
	svg.append('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" font-family="Georgia, serif">' % [int(W * SCALE), int(H * SCALE)])
	svg.append('<rect width="100%" height="100%" fill="#d9d3c1"/>')
	# Every solid block, lowest first so that walls are drawn over floors.
	var blocks: Array = []
	for body_name: String in ["Massing"]:
		for shape: Node in q.get_node(body_name).get_children():
			if shape is CollisionShape3D:
				var box := (shape as CollisionShape3D).shape as BoxShape3D
				var t := (shape as CollisionShape3D).global_transform
				var h := box.size * 0.5
				var pts: Array = []
				var top := -999.0
				for c: Vector3 in [Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]:
					var p := t * c
					pts.append(p)
					top = maxf(top, p.y)
				var slope := absf(t.basis.y.y) < 0.999
				blocks.append({"pts": pts, "top": top, "thin": box.size.y <= 1.01, "slope": slope})
	blocks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.top < b.top)
	for b: Dictionary in blocks:
		var fill := "#2b2f3e"                                       # a wall: ink
		if b.thin or b.slope:                                       # something walked on
			fill = {-4: "#7fa79a", 0: "#efe9d8", 4: "#e6dcc0", 8: "#dccfa8"}.get(int(round(b.top / 4.0)) * 4, "#e9e2cd")
			if b.slope:
				fill = "#cfc6ad"
		var path := ""
		for p: Vector3 in b.pts:
			path += "%.1f,%.1f " % [_x(p.x), _y(p.z)]
		svg.append('<polygon points="%s" fill="%s" stroke="#2b2f3e" stroke-width="0.6"/>' % [path, fill])
	for g: Dictionary in q.data.gates:
		var at := Quarter._v(g.at)
		var half := float(g.width) * 0.5
		var a := Vector3(at.x, 0, at.z - half) if g.axis == "x" else Vector3(at.x - half, 0, at.z)
		var b := Vector3(at.x, 0, at.z + half) if g.axis == "x" else Vector3(at.x + half, 0, at.z)
		svg.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#3f6f63" stroke-width="5"/>' % [_x(a.x), _y(a.z), _x(b.x), _y(b.z)])
	for e: Dictionary in q.data.encounters:
		var at := Quarter._v(e.at)
		svg.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="#c8371f" stroke-width="1.2" stroke-dasharray="6 5"/>' % [_x(at.x), _y(at.z), float(e.radius) * SCALE])
		for entry: Array in e.spawn:
			var s := Quarter._v(entry[1])
			svg.append('<circle cx="%.1f" cy="%.1f" r="5" fill="#c8371f"/>' % [_x(s.x), _y(s.z)])
	for r: Dictionary in q.data.records:
		var at := Quarter._v(r.at)
		svg.append('<rect x="%.1f" y="%.1f" width="9" height="9" fill="#1a1f30"/>' % [_x(at.x) - 4.5, _y(at.z) - 4.5])
	for s: Dictionary in q.data.stones:
		var at := Quarter._v(s.at)
		svg.append('<circle cx="%.1f" cy="%.1f" r="8" fill="#d4a847" stroke="#1a1f30" stroke-width="1.5"/>' % [_x(at.x), _y(at.z)])
	var start := Quarter._v(q.data.start.at)
	svg.append('<path d="M %.1f %.1f l -8 14 l 16 0 z" fill="#1a1f30"/>' % [_x(start.x), _y(start.z) - 8])
	# Names.
	for label: Array in [["THE OATH-MARKET", -0.0, 0.0, 26], ["THE SCRIVENERS' STAIR", -27.0, 42.0, 18], ["THE DROWNED DOCKET", 45.0, 56.0, 18],
			["THE HALL OF STANDING", 0.0, 121.5, 22], ["forecourt", 0.0, 70.0, 15], ["landing", -6.5, 38.0, 15],
			["Witness Gate (shut)", 0.0, -21.5, 14], ["fallen Oath Hall", -27.8, 0.6, 13, "#efe9d8"],
			["Docket Gate: opens from", 24.0, 38.6, 13], ["the Docket side only", 24.0, 36.8, 13],
			["way down", 28.0, -6.4, 13], ["way up", 24.0, 51.0, 13]]:
		svg.append('<text x="%.1f" y="%.1f" font-size="%d" text-anchor="middle" fill="%s" letter-spacing="1">%s</text>'
			% [_x(float(label[1])), _y(float(label[2])), int(label[3]), String(label[4]) if label.size() > 4 else "#1a1f30", String(label[0]).xml_escape()])
	# Legend.
	var lx := 28.0
	var ly := 64.0
	svg.append('<rect x="%.1f" y="%.1f" width="360" height="132" fill="#efe9d8" stroke="#1a1f30"/>' % [lx - 10, ly - 22])
	var rows := [["circle", "#d4a847", "vow-stone: rest, and stand again here"], ["dot", "#c8371f", "a keeper; the dashed ring is where they notice you"],
		["square", "#1a1f30", "something to read"], ["bar", "#3f6f63", "a gate"], ["tri", "#1a1f30", "where the Witness starts.  North is up."]]
	for i in rows.size():
		var y := ly + 24.0 * i
		var kind: String = rows[i][0]
		if kind == "circle":
			svg.append('<circle cx="%.1f" cy="%.1f" r="7" fill="%s" stroke="#1a1f30"/>' % [lx + 8, y - 5, rows[i][1]])
		elif kind == "dot":
			svg.append('<circle cx="%.1f" cy="%.1f" r="5" fill="%s"/>' % [lx + 8, y - 5, rows[i][1]])
		elif kind == "square":
			svg.append('<rect x="%.1f" y="%.1f" width="9" height="9" fill="%s"/>' % [lx + 3.5, y - 9.5, rows[i][1]])
		elif kind == "bar":
			svg.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="5"/>' % [lx, y - 5, lx + 16, y - 5, rows[i][1]])
		else:
			svg.append('<path d="M %.1f %.1f l -7 12 l 14 0 z" fill="%s"/>' % [lx + 8, y - 12, rows[i][1]])
		svg.append('<text x="%.1f" y="%.1f" font-size="14" fill="#1a1f30">%s</text>' % [lx + 28, y, String(rows[i][2]).xml_escape()])
	svg.append('</svg>')
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string("\n".join(svg))
	f.close()
	print("MAP %s  (%d solid blocks)" % [out, blocks.size()])
	get_tree().quit()


func _x(world_x: float) -> float:
	return (X0 - world_x) * SCALE


func _y(world_z: float) -> float:
	return (Z1 - world_z) * SCALE
