extends SceneTree
## Headless micro-benchmark for the Law Engine.
##   godot --headless --path game --script res://tests/bench.gd
## Worst case we plan for: a boss with three Writs and an Edict standing, a
## player law standing, and every strike judged by all of them.

func _init() -> void:
	var reg := LawRegistry.new()
	reg.load_roots("res://data/roots.json")
	reg.load_laws_dir("res://data/laws")
	var w := LawWorld.new(reg)
	w.add_entity({"id": 1, "team": 1, "hp": 1000000000, "resonance": 1000, "tags": ["recognised"], "pos": [0, 0]})
	w.add_entity({"id": 2, "team": 2, "hp": 1000000000, "resonance": 1000, "pos": [0, 400]})
	for def: String in ["voss.writ_of_standing", "voss.writ_of_order", "voss.writ_of_licence"]:
		w.impose(2, def)
	w.impose(1, "debt.creditor")
	var standing := w.laws.size()
	var n := 20000
	var acts := ["light", "heavy"]
	var t0 := Time.get_ticks_usec()
	for i in n:
		if i % 2 == 0:
			w.strike(1, 2, 10, ["from_front"], {"act": acts[(i / 2) % 2], "combo_index": 1 + i % 3})
		else:
			w.strike(2, 1, 10, ["from_front"])
		if i % 4 == 3:
			w.strike(1, 2, 5, ["from_front", "call_in"])
		w.records.clear()
	var per_strike := float(Time.get_ticks_usec() - t0) / float(n + n / 4)
	t0 = Time.get_ticks_usec()
	w.advance(6000)
	var per_tick := float(Time.get_ticks_usec() - t0) / 6000.0
	t0 = Time.get_ticks_usec()
	for i in 200:
		w.state_hash()
	var per_hash := float(Time.get_ticks_usec() - t0) / 200.0
	print("laws standing during strikes: %d" % standing)
	print("strike, fully judged:  %.1f us" % per_strike)
	print("idle tick:             %.2f us" % per_tick)
	print("save + hash:           %.1f us" % per_hash)
	print("budget: 16667 us per frame at 60 Hz; engine target is under 500 us")
	quit(0)
