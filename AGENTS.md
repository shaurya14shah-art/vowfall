# Working on VOWFALL

Godot 4.7.2, typed GDScript, macOS (Apple M4, 16 GB, Metal, Forward+).
Started 2026-11-10. Read `docs/STATUS.md` first, then `docs/DECISIONS.md`.

## Rules

* Never commit or push unless asked. There is no project git repo yet.
* Never open a game window without asking. Tests and the benchmark are
  headless. Batch visual checks into one contact sheet.
* Never report a feature past its real status. The words are Designed,
  Prototyped, Implemented, Tested, Polished, Complete, and a document is not
  an implementation. Update `docs/STATUS.md` in the same change.
* A change to the concept or the architecture gets an entry in
  `docs/DECISIONS.md` in the seven-question form.
* Unreal is not available on this machine (D-001). Do not plan around it.

## Commands

```bash
./tools/test.sh                    # every headless test; also fails on any printed script error
./tools/test.sh -- --verbose

G=/Applications/Godot.app/Contents/MacOS/Godot
$G --headless --path game --import                              # after adding a class_name or an asset
$G --headless --path game --script res://tests/run_tests.gd     # Law Engine only
$G --headless --fixed-fps 60 --path game res://scenes/tools/TestM1.tscn   # action machine + arena
$G --headless --fixed-fps 60 --path game res://scenes/tools/TestM2.tscn   # Axioms in play; rewrites docs/m2_logs/
$G --headless --fixed-fps 60 --path game res://scenes/tools/TestM3.tscn   # Instruments and Unveiling
$G --headless --fixed-fps 60 --path game res://scenes/tools/TestM4.tscn   # Aurel Voss: rules, then six fights; rewrites docs/m4_logs/. Add -- --rules or -- --lines
$G --headless --path game --script res://tools/measure_clips.gd -- Punch  # when a clip connects (for anim_hit)
$G --headless --path game --script res://tests/bench.gd
$G --headless --fixed-fps 60 --path game res://scenes/tools/TestM5.tscn   # the Assize Quarter: routes walked, stones, posts, the Hall, records
$G --headless --path game res://scenes/tools/MapQuarter.tscn -- /abs/out.svg   # a plan of the Quarter from its real collision (then qlmanage -t for a PNG)
$G --path game                                                  # THE GAME, IN A WINDOW (the yard; T goes to the Quarter). Ask first.
$G --path game res://scenes/Quarter.tscn                        # the Quarter directly. WINDOW. Ask first.
$G --path game res://scenes/tools/Capture.tscn -- /abs/out/dir  # WINDOW, about 20 s: 12 shots + metrics.json. Ask first.
$G --path game res://scenes/tools/CaptureM2.tscn -- /abs/out/dir   # WINDOW, about 30 s: 16 M2 shots. Ask first.
$G --path game res://scenes/tools/CaptureM3.tscn -- /abs/out/dir   # WINDOW, about 35 s: Instruments and the Unveiling. Ask first.
$G --path game res://scenes/tools/CaptureM4.tscn -- /abs/out/dir   # WINDOW, about 40 s: the fight with Voss, 11 shots. Ask first.
$G --path game res://scenes/tools/CaptureM5.tscn -- /abs/out/dir   # WINDOW, about 45 s: round the Quarter, 19 shots. Ask first.
$G --headless --fixed-fps 60 --path game res://scenes/tools/CaptureM2.tscn -- /tmp/x   # either capture script, dry: no window, no images, finds script errors
blender -b -P tools/blender/build.py               # rebuild every model into game/assets/models (no window)
blender -b -P tools/blender/build.py -- witness    # or one
blender -b -P tools/blender/build.py -- world      # the Quarter's fourteen models (tools/blender/world.py)
blender -b -P tools/blender/review.py              # render review images to docs/screenshots/models (no window)
blender -b -P tools/blender/review.py -- world     # only the Quarter's
$G --headless --script tools/contact_sheet.gd -- /abs/dir /abs/sheet.png 3 620
```

## The core is pure

`game/core/` has no `Node`, no `float`, no `randf`, no `Time`. Positions are
integer centimetres. Gameplay code never changes hp, position or laws: it
calls `LawWorld.strike / move / impose / advance` and reads the record.
`law_world.gd` names no law; behaviour is data in `game/data/laws/`.

## How a fight is wired

`Actor._physics_process`: `_think()` fills the intent (the player's input or
an AI; both press the same buttons), `ActionMachine.tick()` (pure, in
`core/combat/`) advances the action, the actor moves, and on active ticks a
reach-and-arc test finds who was reached. `CombatBridge.resolve_strike` tags
the attempt, calls `LawWorld.strike`, and tells both actors and the HUD what
the engine decided. Only the bridge calls the Law Engine. Movesets are JSON
in `game/data/instruments/`.

To test combat, drive the real scene with `ScriptedInput` (see
`game/tests/test_m1.gd`). Set `Arena.test_mode = true` before instancing.

## The Assize Quarter

`Quarter` (`gameplay/world/quarter.gd`) extends `Arena`: same bridge,
player, camera, HUD. It overrides what the place is (`_build_world`), what
stands in it before the player (`_place_fixtures`), who is here
(`_populate`) and when they fight. Stone is `Massing` blocks written in
`_build_stone`; who, what and where is `data/world/assize_quarter.json`.
After moving a wall, a stone, a keeper or a record: run TestM5 (it ray
casts every one of them onto its floor and walks both routes) and redraw
the plan. Read `docs/13_assize_quarter.md`.

* The Law Engine's space is flat. Never put one walkable place above
  another in plan, or a line drawn upstairs bars the cellar.
* A prop's `solid` box is in the prop's own frame (width, height, depth),
  turned with it.
* In the Quarter `Arena.test_mode` keeps keepers asleep even when roused;
  `quarter.force_ai = true` lets them fight in a test.
* Voss says nothing until `hearing_open` (D-031).
* A Vow is a law (`data/laws/vow.json`, tier VOW). The engine decides when
  it falls; the place decides when it is kept (`bridge.keep_vows`). Never
  special-case a Vow in gameplay code: add a breach to its data.
* A test that harms the player with `world.strike` goes through every
  standing law. One was silently refused by a Gatekeeper line drawn three
  lines earlier.

## Adding or changing a law

1. Edit `game/data/laws/<root>.json`.
2. Add a scenario for what it does and one for how it is answered, in
   `game/tests/scenarios/`.
3. Run the tests. The validator runs first and will refuse a law with no
   end, no price, fewer than two answers, a loop, or too much power.

Every clause needs a `reason`: a plain sentence the Codex can show a player.

## Traps

* JSON numbers load as floats. Always go through `LawRegistry.read_json` or
  `LawRegistry.intify`, or integer comparisons fail silently.
* `:=` cannot infer a type from a Dictionary lookup. Write the type.
* Do not use `void`, `match`, `do` or other keywords as dictionary keys you
  access with a dot.
* A path that touches a line's end point counts as crossing it.
* Touching a scenario's numbers: work the arithmetic by hand first. Integer
  division rounds down (15 * 150 / 100 is 22).
* Assets and capture tools exist in `~/AG/Crownfall`. Reference them; do
  not import that project's code. The KayKit and Kenney files in
  `game/assets/placeholder/` were copied from there (CC0).
* Headless Godot compiles no shaders and renders nothing. A passing test
  says nothing about how a thing looks. Say so in `docs/STATUS.md`.
* `SceneTree.physics_frame` fires before the frame's `_physics_process`
  calls. A test that reads state after `await physics_frame` sees last
  tick's result.
* A lambda body inside a call's parentheses must close the parenthesis on
  its last statement's line.
* +X is the camera's LEFT when it looks along +Z (yaw 0). The first look
  had the two posts on the wrong sides because of this.
* World surfaces use `Look.STONE` (0.70), not the HUD's `Look.VELLUM`
  (0.86). At 0.86 under the sun the whole yard rendered white. Fog must stay
  off the sky (`fog_sky_affect`).
* A freed node cannot be passed to a typed parameter or assigned to a typed
  variable; the call itself errors. Anything that may hold a reference to
  an actor that an encounter change frees must be cleared first or handled
  as `Variant` with `is_instance_valid`.
* Never capture a node in a lambda given to a timer; bind its instance id.
* A capture window takes keyboard focus. Tell the owner not to type while
  it runs. Capture runs ignore the yard's keys (`Arena.capture_mouse` off),
  but H still folds the help panel.
* A new or changed shader is not compiled by any headless run. Read it
  twice, and say in `STATUS.md` that it is uncompiled until a capture.
* A landmark has to clear the walls. From the market a 12 m wall 30 m away
  hides everything below 22 degrees, and the default camera shows nothing
  above 14. Work the angle out before placing anything in the sky.
* Before trusting a capture's frame times, check `pmset -g | grep
  lowpowermode` and what else is running. One capture on battery in Low
  Power Mode beside another game read 30 ms where the same scene read 16.7.
* Dry-run a capture script headless before asking for a window. It finds
  script errors for free.
* Bots with perfect timing are not players. A scripted win says a law
  works, not that it is fun or fair.
* Tests written before Instruments set `Arena.fixed_instrument =
  "counterpart"`; M3's set it to "". A new test must choose.
* A strike's active ticks are stretched by hit-stop. Do not move an actor
  into reach until the swing is over, or the same swing hits it too.
* `EditBone.transform` re-derives roll. To turn a bone chain rigidly in
  Blender set `bone.matrix`, or hand slots end up twisted against hands.
* `./tools/test.sh` can take longer than a ten-minute tool timeout (M4's
  six fights are most of it). Run it in the background and read the result when it is done.
* One swing can reach several bodies. Anything that counts or judges
  "acts" must go by `data.swing`, not by strikes (D-026).
* Keep an entity id before the actor that owns it can be freed (a broken
  seal is freed at once); reading `actor.entity_id` afterwards errors.
* A yielded actor is alive in the engine and not `_valid` as a target.
  Check `yielded`, not hp, to know a boss fight is over.
* An enemy's law the player has not met is hidden on its panel. If an
  enemy announces a law, call `bridge.declare` or the HUD contradicts the
  banner (seen in M4's first capture).
* `status` is read-only in zsh. Do not use it as a variable in scripts.
* KayKit clips: attacks are about one second long with contact at 0.25 to
  0.6 s; movesets carry `anim_hit` so the clip is sped up to land on the
  last startup tick. Measure a new clip before giving it frame data.

## Owner preferences carried from earlier projects

**No chibi or cute models (2026-11-11).** The KayKit characters are rejected
and deleted. Models are made from scratch in `tools/blender/` to a
theatrical, dramatic style: `kit.py` (shapes and skinning), `figure.py`
(anatomy), `characters.py`, `props.py`, `rig.py` (the tall rig that keeps
the pack's motion), `build.py`, `review.py`. Only motion is reused. Change a
model by editing its script, render with `review.py`, look, then `build.py`
and re-import. Things learnt:

* A robe skinned by distance to the leg bones lets a lifted knee punch
  through; glued to the thigh it flaps like a board. `figure.skirt_skin`
  with `follow=0.5` is the compromise. Under a long robe do not model
  thighs at all (`legs(from_knee=True)`).
* An open shell is invisible from inside (back faces are culled). Give
  cloth a cap or a thickness (`strip`).
* Held items: length along Blender +Z (the hand slot's +Y in game), grip at
  the origin; a shield's plate in the X-Z plane at negative Y.
* After `anim.play` with a blend time, a seek shows the old pose. Use a
  blend of 0 when sampling poses in a script.

Stylised over realistic. No glassmorphism, no crowded text. Lag is a top
complaint: measure frame time after every visual change. Build, do not
re-research.
