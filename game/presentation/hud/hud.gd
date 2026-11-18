class_name Hud
extends CanvasLayer
## The combat HUD (docs/09_ui_ux.md): marginalia. Thin ruled lines, opaque
## vellum strips, gold for what you own, vermilion for what is happening now,
## a matte black bar for a law you cannot yet read.
##
## It only draws what the bridge and the Law Engine report.

var _canvas: HudCanvas


func _init() -> void:
	layer = 10
	_canvas = HudCanvas.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)


func bind(bridge: CombatBridge, player: Player, camera: FollowCamera) -> void:
	_canvas.bridge = bridge
	_canvas.player = player
	_canvas.camera = camera
	bridge.verdict.connect(_canvas.on_verdict)
	bridge.struck.connect(_canvas.on_struck)
	bridge.consequence.connect(_canvas.on_consequence)
	bridge.law_ended.connect(_canvas.on_law_ended)


## A line of text shown large for a moment: an encounter's name, a Writ
## being spoken, a Revelation.
func announce(text: String, seconds: float = 2.6) -> void:
	_canvas.banner = text
	_canvas.banner_age = 0.0
	_canvas.banner_life = seconds


## A Sovereign is here: their name, title and laws stay at the top of the
## screen whether or not they are locked on.
func set_boss(actor: Actor) -> void:
	_canvas.boss = actor


## What the interact button would do here, or "" for nothing.
func set_prompt(text: String) -> void:
	_canvas.prompt = text


## Something being read: a title and its text. Empty strings close it.
func set_record(title: String, text: String) -> void:
	_canvas.record_title = title
	_canvas.record_text = text


## The lines of the help panel, for a place whose keys differ from the yard's.
func set_help(lines: Array, shown: bool = true) -> void:
	_canvas.help_lines = lines
	_canvas.show_help = shown


## Options put to the player, or [] for none.
func set_choice(options: Array) -> void:
	_canvas.choice = options


class HudCanvas extends Control:
	const VERDICT_LIFE := 3.2
	const CONTACT_LIFE := 0.9
	const NOTE_LIFE := 0.7
	const GLYPHS := ["REJECTION", "OVERRIDE", "CONTEST", "CANCELLATION", "CONVERSION"]

	var bridge: CombatBridge
	var player: Player
	var camera: FollowCamera
	var serif: Font = load("res://assets/placeholder/fonts/Cinzel.ttf")
	var sans: Font = load("res://assets/placeholder/fonts/Inter.ttf")
	var show_help: bool = true
	var draws: int = 0           # frames drawn; lets a headless test prove the draw code ran

	var banner: String = ""
	var banner_age: float = 99.0
	var banner_life: float = 2.6
	var boss: Actor
	var choice: Array = []
	var prompt: String = ""
	var record_title: String = ""
	var record_text: String = ""
	var help_lines: Array = [
		"WASD move   ·   mouse look   ·   Tab lock on   ·   LMB light   ·   RMB heavy",
		"Space dodge   ·   Shift guard (tap to parry)   ·   1 to 6 choose your law",
		"Q impose (hold to commit; walk to draw a line)   ·   Q + strike inscribes",
		"R rest   ·   U unveil   ·   N next opponents   ·   L save the verdict log   ·   T the Assize Quarter",
		"Esc free the mouse   ·   Backspace reset   ·   H hide this",
	]

	var _top: float = 0.0        # room taken at the top of the screen by a sworn Vow
	var _verdicts: Array = []    # {type, name, reason, age, count}
	var _contacts: Array = []    # {type, text, at, age, colour}
	var _hp_shown: float = 100.0
	var _hp_lag: float = 100.0

	func _process(delta: float) -> void:
		for v: Dictionary in _verdicts:
			v.age += delta
		_verdicts = _verdicts.filter(func(v: Dictionary) -> bool: return v.age < VERDICT_LIFE)
		for c: Dictionary in _contacts:
			c.age += delta
		_contacts = _contacts.filter(func(c: Dictionary) -> bool: return c.age < c.life)
		banner_age += delta
		if Input.is_action_just_pressed("toggle_help"):
			show_help = not show_help
		if player != null and bridge != null:
			var hp := float(player.hp())
			_hp_shown = hp
			_hp_lag = maxf(hp, _hp_lag - 30.0 * delta) if _hp_lag > hp else hp
		queue_redraw()

	# ------------------------------------------------------------- signals

	func on_verdict(rec: Dictionary, at: Vector3) -> void:
		var o := _first_outcome(rec)
		if o.is_empty():
			# A law that could not be imposed at all: no price, no pair, no line.
			if rec.kind != "IMPOSE" or rec.outcomes.is_empty():
				return
			o = {"type": "REJECTION", "name": "Not imposed", "reason": rec.outcomes[0].reason}
		var reason: String = o.reason
		var sanction := _sanction(rec)
		if sanction > 0:
			reason += "  ·  sanction %d" % sanction
		_push(String(o.type), String(o.get("name", "")), reason)
		var label := _short(String(o.reason))
		for c: Dictionary in _contacts:
			if c.text == label and c.age < 0.6:
				c.at = at          # the same thing again at once: move the label, do not stack another
				c.age = 0.0
				return
		_contacts.append({"type": o.type, "text": label, "at": at, "age": 0.0,
			"life": CONTACT_LIFE, "colour": Look.VERMILION})

	## The same law doing the same thing again within a moment is one line
	## with a count, not a column of copies (a Creditor among clerks).
	func _push(type: String, title: String, reason: String) -> void:
		if not _verdicts.is_empty():
			var top: Dictionary = _verdicts[0]
			if top.type == type and top.name == title and top.age < 1.6:
				top.reason = reason
				top.age = 0.0
				top.count += 1
				return
		_verdicts.push_front({"type": type, "name": title, "reason": reason, "age": 0.0, "count": 1})
		if _verdicts.size() > 5:
			_verdicts.resize(5)

	func on_consequence(info: Dictionary) -> void:
		var words := {"mirrored": "MIRRORED", "returned": "RETURNED", "copied": "TWINNED",
			"paid_forward": "PAID FORWARD", "debt_due": "DUE", "defaulted": "DEFAULT"}
		if not words.has(info.kind):
			return
		var mine: bool = info.target == player
		_contacts.append({"type": "", "text": "%s  %d" % [words[info.kind], info.amount], "at": info.at, "age": 0.0,
			"life": CONTACT_LIFE, "colour": Look.VERMILION if mine else Look.GOLD})

	func on_law_ended(def_id: String, owner: Actor, reason: String) -> void:
		if owner != player:
			return
		_push("", String(bridge.registry.resolve(def_id).get("name", def_id)), "ended: " + reason)

	func on_struck(info: Dictionary) -> void:
		var word := ""
		if info.kind == "parried":
			word = "ANSWERED"
		elif info.kind == "perfect_dodge":
			word = "UNTOUCHED"
		elif info.kind == "held" and info.defender == player:
			word = "OWED  %d" % info.amount
		if word != "":
			_contacts.append({"type": "", "text": word, "at": info.at, "age": 0.0,
				"life": NOTE_LIFE, "colour": Look.GOLD})

	func _first_outcome(rec: Dictionary) -> Dictionary:
		for o: Dictionary in rec.outcomes:
			if GLYPHS.has(o.type) and o.has("law"):
				return o
		for c: Dictionary in rec.children:
			var found := _first_outcome(c)
			if not found.is_empty():
				return found
		return {}

	func _sanction(rec: Dictionary) -> int:
		var total := 0
		for c: Dictionary in rec.children:
			if c.tags.has("sanction") and c.verdict == "APPLIED":
				total += int(c.amount_out)
			total += _sanction(c)
		return total

	static func _short(text: String) -> String:
		var words := text.split(" ")
		if words.size() <= 6:
			return text
		return " ".join(words.slice(0, 6)) + " …"

	# --------------------------------------------------------------- drawing

	func _draw() -> void:
		if player == null or bridge == null:
			return
		draws += 1
		var size := get_viewport_rect().size
		_draw_vitals(size)
		_draw_resonance(size)
		if choice.size() <= 2:      # a stone's long list needs the room the law panel takes
			_draw_law(size)
		_draw_verdicts(size)
		_top = _draw_vow(size)
		_draw_target(size)
		_draw_contacts()
		if show_help and choice.is_empty() and record_text == "":
			_draw_help(size)
		if record_text != "":
			_draw_record(size)
		elif prompt != "" and choice.is_empty():
			# Under the Witness's feet, not across their back (the first
			# capture of the Quarter had it at mid-screen, over the figure).
			var pw := sans.get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			var py := size.y - 78.0
			if show_help:
				py = size.y - 36.0 - 26.0 * help_lines.size() - 66.0
			_strip(Rect2(Vector2(size.x * 0.5 - pw * 0.5 - 22, py - 28), Vector2(pw + 44, 42)))
			_centre_text(Vector2(size.x * 0.5, py), prompt, sans, 22, Look.INK)
		if not show_help and choice.is_empty() and record_text == "":
			_centre_text(Vector2(size.x * 0.5, size.y - 18.0), "H   keys", sans, 15, Color(Look.INK, 0.55))
		if banner_age < banner_life:
			var fade := clampf((banner_life - banner_age) / 0.6, 0.0, 1.0)
			# Long lines (a Writ being spoken) are set smaller so they fit.
			var px := 34 if banner.length() < 34 else 24
			var bw := serif.get_string_size(banner.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			_strip(Rect2(Vector2(size.x * 0.5 - bw * 0.5 - 30, size.y * 0.24 - 40), Vector2(bw + 60, 58)), fade)
			_centre_text(size * Vector2(0.5, 0.24), banner.to_upper(), serif, px, Color(Look.INK, fade))
		if not choice.is_empty():
			# A question sits at the foot of the screen, where the help was,
			# so it never covers the one who asked it.
			# Two short answers are set large; a stone's list of Vows smaller,
			# in a strip as wide as its longest line.
			var px := 24 if choice.size() <= 2 else 19
			var step := 40.0 if choice.size() <= 2 else 32.0
			var wide := 380.0
			for line: String in choice:
				wide = maxf(wide, serif.get_string_size(line.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
			var top := size.y - 46.0 - step * choice.size()
			_strip(Rect2(Vector2(size.x * 0.5 - wide * 0.5 - 30, top - 34), Vector2(wide + 60, step * choice.size() + 30)))
			for n in choice.size():
				draw_string(serif, Vector2(size.x * 0.5 - wide * 0.5, top + step * n), String(choice[n]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, px, Look.INK)
		if player.machine.dead():
			_centre_text(size * Vector2(0.5, 0.46), "YOU FELL", serif, 54, Look.INK)
			_centre_text(size * Vector2(0.5, 0.46) + Vector2(0, 44), "standing again in a moment", sans, 20, Look.INK)

	## A record being read: a leaf of vellum with a ruled margin.
	func _draw_record(size: Vector2) -> void:
		var width := 640.0
		var body := 22
		var lines := sans.get_multiline_string_size(record_text, HORIZONTAL_ALIGNMENT_LEFT, width - 96.0, body).y
		var height := lines + 150.0
		var origin := Vector2(size.x * 0.5 - width * 0.5, maxf(40.0, size.y * 0.5 - height * 0.5))
		draw_rect(Rect2(origin, Vector2(width, height)), Color(Look.VELLUM, 0.97))
		draw_rect(Rect2(origin, Vector2(width, height)), Look.INK, false, 1.5)
		draw_line(origin + Vector2(34, 0), origin + Vector2(34, height), Color(Look.VERMILION, 0.55), 1.5)
		draw_string(serif, origin + Vector2(56, 52), record_title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, width - 96.0, 22, Look.INK)
		draw_line(origin + Vector2(56, 66), origin + Vector2(width - 40, 66), Color(Look.INK, 0.5), 1.0)
		draw_multiline_string(sans, origin + Vector2(56, 104), record_text, HORIZONTAL_ALIGNMENT_LEFT, width - 96.0, body, -1, Look.INK)
		draw_string(sans, origin + Vector2(56, height - 22), "E to put it down", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Look.INK, 0.6))

	func _strip(rect: Rect2, alpha: float = 1.0) -> void:
		draw_rect(rect, Color(Look.VELLUM, 0.94 * alpha))
		draw_line(Vector2(rect.position.x, rect.end.y), rect.end, Color(Look.INK, alpha), 1.5)

	func _draw_vitals(size: Vector2) -> void:
		var origin := Vector2(56, size.y - 118)
		var width := 340.0
		_strip(Rect2(origin - Vector2(14, 14), Vector2(width + 28, 62)))
		# Health: an ink line on a faint rule. The paler tail is what was just lost.
		var hp_max := float(bridge.hp_max(player.entity_id))
		var y := origin.y + 8
		draw_line(Vector2(origin.x, y), Vector2(origin.x + width, y), Color(Look.INK, 0.22), 2.0)
		draw_line(Vector2(origin.x, y), Vector2(origin.x + width * _hp_lag / hp_max, y), Color(Look.VERMILION, 0.75), 7.0)
		draw_line(Vector2(origin.x, y), Vector2(origin.x + width * _hp_shown / hp_max, y), Look.INK, 7.0)
		# A Debtor's health line shows what is owed: an outlined bite out of
		# the end of it, and when the first part falls due.
		var debts := bridge.debts_of(player)
		if not debts.is_empty():
			var owed := 0
			for d: Dictionary in debts:
				owed += int(d.amount)
			var x1 := origin.x + width * _hp_shown / hp_max
			var x0 := origin.x + width * maxf(0.0, _hp_shown - float(owed)) / hp_max
			draw_rect(Rect2(Vector2(x0, y - 7), Vector2(x1 - x0, 14)), Look.VERMILION, false, 2.0)
			var note := "owed %d  ·  due in %.1f s" % [owed, float(debts[0].ticks) / 60.0]
			_strip(Rect2(origin + Vector2(-14, -52), Vector2(sans.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 28, 32)))
			draw_string(sans, origin + Vector2(0, -29), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Look.VERMILION)
		# Poise: thinner, gold.
		var py := origin.y + 28
		var poise := clampf(float(player.poise) / float(maxi(1, player.max_poise)), 0.0, 1.0)
		draw_line(Vector2(origin.x, py), Vector2(origin.x + width * 0.62, py), Color(Look.INK, 0.22), 1.5)
		draw_line(Vector2(origin.x, py), Vector2(origin.x + width * 0.62 * poise, py), Look.GOLD, 4.0)

	func _draw_resonance(size: Vector2) -> void:
		var res := bridge.resonance(player.entity_id)
		var x := size.x - 96.0
		var bottom := size.y - 104.0
		_strip(Rect2(Vector2(x - 16, bottom - 10 * 17 - 22), Vector2(72, 10 * 17 + 36)))
		for i in 10:
			var r := Rect2(Vector2(x, bottom - float(i + 1) * 17.0), Vector2(40, 9))
			if res >= (i + 1) * 10:
				draw_rect(r, Look.GOLD)
				draw_rect(r, Look.INK, false, 1.0)
			else:
				var part := clampf(float(res - i * 10) / 10.0, 0.0, 1.0)
				if part > 0.0:
					draw_rect(Rect2(r.position, Vector2(r.size.x * part, r.size.y)), Color(Look.GOLD, 0.55))
				draw_rect(r, Color(Look.INK, 0.55), false, 1.0)

	## Your law, beside your Resonance: its name and thesis; standing, its
	## term as a ruled line and its acts as pips; not standing, its price,
	## with the Resonance it would take outlined on the column.
	func _draw_law(size: Vector2) -> void:
		var def := bridge.registry.resolve(player.law_id, bridge.form(player))
		if def.is_empty():
			return
		var width := 480.0
		var origin := Vector2(size.x - 128.0 - width, size.y - 362.0)
		_strip(Rect2(origin - Vector2(16, 14), Vector2(width + 32, 150)))
		var index := Player.LAWS.find(player.law_id) + 1
		var title: String = String(def.name).to_upper()
		draw_string(sans, origin + Vector2(0, 12), str(index), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Look.INK, 0.6))
		draw_string(serif, origin + Vector2(24, 14), title, HORIZONTAL_ALIGNMENT_LEFT, width - 24, 22, Look.INK)
		# The Instrument this law's Root binds, and whether it has woken.
		var held := String(player.instrument.get("name", ""))
		if bridge.form(player) == "UNVEILED":
			held += "  ·  unveiled"
		draw_string(sans, origin + Vector2(0, 13), held, HORIZONTAL_ALIGNMENT_RIGHT, width, 16,
			Look.GOLD.darkened(0.3) if bridge.form(player) == "UNVEILED" else Color(Look.INK, 0.6))
		draw_string(sans, origin + Vector2(0, 42), String(def.thesis), HORIZONTAL_ALIGNMENT_LEFT, width, 18, Color(Look.INK, 0.85))
		var standing: Dictionary = {}
		for law: Dictionary in bridge.laws_of(player, player.team):
			if law.id == player.law_id:
				standing = law
		var y := origin.y + 66
		if not standing.is_empty():
			var frac := clampf(float(standing.ticks_left) / float(maxi(1, standing.ticks)), 0.0, 1.0)
			draw_line(Vector2(origin.x, y), Vector2(origin.x + width, y), Color(Look.INK, 0.22), 2.0)
			draw_line(Vector2(origin.x, y), Vector2(origin.x + width * frac, y), Look.GOLD, 5.0)
			for i in int(standing.events):
				var pip := Rect2(Vector2(origin.x + i * 20.0, y + 12), Vector2(13, 13))
				if i < int(standing.events_left):
					draw_rect(pip, Look.GOLD)
				draw_rect(pip, Look.INK, false, 1.0)
		elif player.marking:
			draw_string(sans, Vector2(origin.x, y + 14), "the blade is armed  ·  shown to %d of 2" % player.marks.size(), HORIZONTAL_ALIGNMENT_LEFT, width, 18, Look.VERMILION)
		elif player.imposing:
			draw_string(sans, Vector2(origin.x, y + 14), "drawing  ·  committed %d" % player.commit_now(), HORIZONTAL_ALIGNMENT_LEFT, width, 18, Look.VERMILION)
		else:
			var price := int(def.price.get("resonance", 0))
			var can := bridge.resonance(player.entity_id) >= price
			draw_string(sans, Vector2(origin.x, y + 14), "Q to impose  ·  %d Resonance" % price, HORIZONTAL_ALIGNMENT_LEFT, width, 18,
				Look.INK if can else Color(Look.INK, 0.45))
		# Recognition: what this law asks before its Instrument will wake.
		var ty := origin.y + 116
		if bridge.form(player) == "UNVEILED":
			return
		var trial := player.recognition.progress(player.law_id)
		if player.rite_ticks > 0:
			var k := float(player.rite_ticks) / float(Player.RITE_TICKS)
			draw_line(Vector2(origin.x, ty - 6), Vector2(origin.x + width, ty - 6), Color(Look.INK, 0.22), 2.0)
			draw_line(Vector2(origin.x, ty - 6), Vector2(origin.x + width * k, ty - 6), Look.VERMILION, 6.0)
			draw_string(sans, Vector2(origin.x, ty + 16), "unveiling: hold, and do not be struck", HORIZONTAL_ALIGNMENT_LEFT, width, 18, Look.VERMILION)
		elif player.can_unveil():
			draw_string(sans, Vector2(origin.x, ty), "RECOGNISED  ·  hold Q + Shift to unveil", HORIZONTAL_ALIGNMENT_LEFT, width, 18, Look.VERMILION)
		elif trial[1] > 0:
			draw_string(sans, Vector2(origin.x, ty), "%s  %d / %d" % [player.recognition.text(player.law_id), trial[0], trial[1]],
				HORIZONTAL_ALIGNMENT_LEFT, width, 15, Color(Look.INK, 0.7))

	func _draw_verdicts(size: Vector2) -> void:
		var y := size.y * 0.40
		for v: Dictionary in _verdicts:
			var alpha := clampf((VERDICT_LIFE - float(v.age)) / 0.5, 0.0, 1.0)
			var title: String = String(v.name).to_upper()
			if int(v.count) > 1:
				title += "   x%d" % v.count
			var title_w := serif.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			var reason_w := sans.get_string_size(v.reason, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
			var w := 64.0 + maxf(title_w, reason_w) + 28.0
			var rect := Rect2(Vector2(48, y), Vector2(w, 62))
			_strip(rect, alpha)
			if String(v.type) == "":
				draw_line(rect.position + Vector2(18, 31), rect.position + Vector2(42, 31), Color(Look.INK, 0.6 * alpha), 2.0)
			else:
				_glyph(String(v.type), rect.position + Vector2(30, 31), 15.0, Color(Look.VERMILION, alpha))
			draw_string(serif, rect.position + Vector2(64, 27), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(Look.INK, alpha))
			draw_string(sans, rect.position + Vector2(64, 50), v.reason, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(Look.INK, 0.85 * alpha))
			y += 72.0

	## What the Witness has sworn, and what their word weighs, at the top
	## of the page. Returns how far down the next thing must start.
	func _draw_vow(size: Vector2) -> float:
		var sworn := bridge.vow_of(player)
		var weight := bridge.standing(player)
		if sworn.is_empty() and weight <= 0:
			return 0.0
		var text := ""
		if not sworn.is_empty():
			text = "SWORN  ·  " + String(sworn.thesis)
			if weight > 0:
				text += "   ·   WORD +%d" % weight
		else:
			text = "YOUR WORD WEIGHS +%d" % weight
		var w := serif.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		var left := size.x * 0.5 - w * 0.5
		_strip(Rect2(Vector2(left - 22, 8), Vector2(w + 44, 32)))
		draw_string(serif, Vector2(left, 31), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Look.INK)
		draw_line(Vector2(left - 22, 40), Vector2(left + w + 22, 40), Look.GOLD, 2.0)
		return 44.0

	func _draw_target(size: Vector2) -> void:
		var target: Actor = player.lock_target
		var locked := target != null and is_instance_valid(target) and not target.machine.dead()
		if not locked:
			# No lock: a Sovereign's name and laws are shown regardless.
			if boss == null or not is_instance_valid(boss) or boss.yielded:
				return
			target = boss
		var laws := bridge.laws_of(target, player.team)
		var owes := bridge.owed_by(target, player)
		var width := 420.0
		for law: Dictionary in laws:
			if law.known >= 2:  # a read law shows its sentence: make room for it
				var line := String(law.name).to_upper() + "  ·  " + String(law.thesis)
				width = maxf(width, serif.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 24.0)
		width = minf(width, 720.0)
		var height := 66.0 + 32.0 * laws.size() + (10.0 if laws.size() > 0 else 0.0) + (30.0 if owes > 0 else 0.0)
		var origin := Vector2(size.x * 0.5 - width * 0.5, 44 + _top)
		_strip(Rect2(origin - Vector2(18, 12), Vector2(width + 36, height)))
		var shown: String = target.display_name.to_upper()
		if target is Voss:
			shown += "  ·  " + (target as Voss).title().to_upper()
		draw_string(serif, origin + Vector2(0, 18), shown, HORIZONTAL_ALIGNMENT_CENTER, width, 22 if shown.length() < 26 else 17, Look.INK)
		var frac := clampf(float(target.hp()) / float(maxi(1, bridge.hp_max(target.entity_id))), 0.0, 1.0)
		var y := origin.y + 32
		draw_rect(Rect2(Vector2(origin.x, y - 5), Vector2(width, 10)), Color(Look.INK, 0.16))
		draw_rect(Rect2(Vector2(origin.x, y - 5), Vector2(width * frac, 10)), Look.INK)
		if target is Voss:
			# Where the hearing turns: two thirds, one third.
			for mark: float in (target as Voss).phase_marks():
				draw_line(Vector2(origin.x + width * mark, y - 8), Vector2(origin.x + width * mark, y + 8), Look.GOLD, 2.0)
		y += 14
		for law: Dictionary in laws:
			y += 32
			if law.known == 0:
				# A law not yet met: struck out.
				draw_string(serif, Vector2(origin.x, y - 2), "A LAW NOT YET MET", HORIZONTAL_ALIGNMENT_CENTER, width, 15, Color(Look.INK, 0.55))
				draw_line(Vector2(origin.x + width * 0.5 - 96, y - 8), Vector2(origin.x + width * 0.5 + 96, y - 8), Look.STRUCK, 2.0)
			elif law.known == 1:
				draw_string(serif, Vector2(origin.x, y - 2), String(law.name).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, width, 18, Look.INK)
			else:
				draw_string(serif, Vector2(origin.x, y - 2), String(law.name).to_upper() + "  ·  " + String(law.thesis),
					HORIZONTAL_ALIGNMENT_CENTER, width, 15, Look.INK)
		if owes > 0:
			y += 30
			draw_string(sans, Vector2(origin.x, y - 2), "owes you %d" % owes, HORIZONTAL_ALIGNMENT_CENTER, width, 18, Look.GOLD.darkened(0.25))
		if not locked:
			return
		# Lock bracket on the target itself.
		var cam := camera.camera()
		var chest := target.global_position + Vector3.UP * 1.35
		if not cam.is_position_behind(chest):
			var p := cam.unproject_position(chest)
			var s := 16.0
			for sx: float in [-1.0, 1.0]:
				for sy: float in [-1.0, 1.0]:
					var corner := p + Vector2(sx * s, sy * s)
					draw_line(corner, corner - Vector2(sx * 7, 0), Look.GOLD, 2.0)
					draw_line(corner, corner - Vector2(0, sy * 7), Look.GOLD, 2.0)

	func _draw_contacts() -> void:
		var cam := camera.camera()
		for c: Dictionary in _contacts:
			var at: Vector3 = c.at
			if cam.is_position_behind(at):
				continue
			var k := float(c.age) / float(c.life)
			var alpha := clampf((1.0 - k) / 0.3, 0.0, 1.0)
			var p := cam.unproject_position(at) + Vector2(0, -24.0 - 18.0 * k)
			var colour := Color(c.colour, alpha)
			var text: String = c.text
			var w := sans.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			var has_glyph: bool = c.type != ""
			var total := w + (34.0 if has_glyph else 0.0)
			var left := p.x - total * 0.5
			draw_rect(Rect2(Vector2(left - 10, p.y - 20), Vector2(total + 20, 30)), Color(Look.VELLUM, 0.92 * alpha))
			if has_glyph:
				_glyph(String(c.type), Vector2(left + 11, p.y - 5), 10.0, colour)
				left += 34.0
			draw_string(sans, Vector2(left, p.y + 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Look.INK, alpha))
			draw_line(Vector2(p.x - total * 0.5 - 10, p.y + 10), Vector2(p.x + total * 0.5 + 10, p.y + 10), colour, 2.0)

	func _draw_help(size: Vector2) -> void:
		var lines := help_lines
		var y := size.y - 36.0 - 26.0 * lines.size()
		var x := size.x * 0.5 - 430.0
		_strip(Rect2(Vector2(x - 16, y - 24), Vector2(892, 26.0 * lines.size() + 26)))
		for line: String in lines:
			draw_string(sans, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_CENTER, 860, 18, Look.INK)
			y += 26.0

	func _centre_text(at: Vector2, text: String, font: Font, px: int, colour: Color) -> void:
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string(font, at - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, colour)

	## The five outcome marks. Each is a pen stroke with its own shape, so
	## they can be told apart without colour.
	func _glyph(type: String, c: Vector2, r: float, colour: Color) -> void:
		var w := maxf(2.0, r * 0.2)
		if type == "REJECTION":           # a bar across a stroke
			draw_line(c + Vector2(-r * 0.7, r), c + Vector2(r * 0.7, -r), colour, w)
			draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), colour, w * 1.4)
		elif type == "OVERRIDE":          # one stroke over another
			draw_line(c + Vector2(-r, -r * 0.45), c + Vector2(r, -r * 0.45), colour, w * 1.6)
			draw_line(c + Vector2(-r * 0.6, r * 0.5), c + Vector2(r * 0.6, r * 0.5), colour, w * 0.8)
		elif type == "CONTEST":           # two strokes meeting
			draw_line(c + Vector2(-r, -r), c, colour, w)
			draw_line(c + Vector2(r, -r), c, colour, w)
			draw_line(c, c + Vector2(0, r), colour, w)
		elif type == "CANCELLATION":      # two strokes, both broken
			for dy: float in [-r * 0.5, r * 0.5]:
				draw_line(c + Vector2(-r, dy), c + Vector2(-r * 0.2, dy), colour, w)
				draw_line(c + Vector2(r * 0.2, dy), c + Vector2(r, dy), colour, w)
		elif type == "CONVERSION":        # a stroke that turns a corner
			draw_line(c + Vector2(-r, -r * 0.6), c + Vector2(r * 0.4, -r * 0.6), colour, w)
			draw_line(c + Vector2(r * 0.4, -r * 0.6), c + Vector2(r * 0.4, r), colour, w)
			draw_line(c + Vector2(r * 0.4, r), c + Vector2(-r * 0.1, r * 0.5), colour, w)
			draw_line(c + Vector2(r * 0.4, r), c + Vector2(r * 0.9, r * 0.5), colour, w)
