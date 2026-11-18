"""Renders review images of every model, headless, into docs/screenshots/models/.

    blender -b -P tools/blender/review.py
    godot --headless --script tools/contact_sheet.gd -- <abs>/docs/screenshots/models/figures <abs>/figures.png 8 230

No game window is involved. This is how a model is judged before it is
exported: four views of each figure (front, back, a walk, a strike) and one
of each prop.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig
import kit
import characters
import props
import world

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../docs/screenshots/models"))
os.makedirs(os.path.join(OUT, "figures"), exist_ok=True)
os.makedirs(os.path.join(OUT, "props"), exist_ok=True)

ONLY = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []       # e.g. "-- world"
os.makedirs(os.path.join(OUT, "world"), exist_ok=True)
# What stands in the Assize Quarter: (look at, angle, distance, camera height)
WORLD_SHOTS = {"vow_stone": ((0, 0, 0.9), 28, 7.0, 1.5), "lectern": ((0, 0, 0.65), 32, 5.0, 1.3),
               "stall": ((0, 0, 1.3), 30, 11.0, 2.2), "shelf": ((0, 0, 1.6), 24, 12.0, 2.0),
               "statue": ((0, 0, 3.1), 26, 21.0, 3.2), "plinth_struck": ((0, 0, 1.4), 26, 10.0, 2.2),
               "rubble": ((0, 0, 0.5), 35, 9.0, 2.6), "lamp": ((0, 0, 1.75), 20, 12.0, 2.0),
               "banner": ((0, 0, -3.5), 22, 23.0, -3.0), "gate": ((0, 0, 2.5), 22, 17.0, 2.4),
               "door": ((0, 0, 4.8), 18, 34.0, 3.4), "desk": ((0, -0.3, 0.7), 34, 6.5, 1.7),
               # The Courts are judged from where they will be seen: far below, looking up.
               "hanging_courts": ((0, 0, 24), 12, 330.0, -70.0), "oath_hall_ruin": ((0, 2, 4.5), 16, 62.0, 5.0)}
for i, (name, (target, ang, dist, height)) in enumerate(WORLD_SHOTS.items()):
    if ONLY and "world" not in ONLY and name not in ONLY:
        continue
    objs, model = getattr(world, name)()
    cam, ground = kit.studio(520, 700)
    if name == "banner":
        ground.location.z = -7.4
    if name == "hanging_courts":
        ground.location.z = -400.0
        cam.data.clip_end = 3000.0
    if name == "oath_hall_ruin":
        cam.data.clip_end = 400.0
    kit.look(cam, target, ang, dist, height)
    kit.render(os.path.join(OUT, "world", "%02d_%s.png" % (i, name)))
if ONLY:
    sys.exit(0)

for idx, name in enumerate(["witness", "bailiff", "ward", "clerk", "voss"]):
    arm, objs, model = getattr(characters, name)()
    cam, ground = kit.studio(600, 900)
    for i, (clip, frame, ang) in enumerate([("Idle", 5, 18), ("Idle", 5, 205), ("Walking_A", 8, 75),
                                            ("1H_Melee_Attack_Slice_Horizontal", 6, 30)]):
        rig.pose(arm, clip, frame)
        kit.look(cam, (0, 0, 1.0), ang, 5.2, 1.35)
        kit.render(os.path.join(OUT, "figures", "%d_%s_%d.png" % (idx, name, i)))

SHOTS = {"lintel": ((0, 0, 0.25), 35, 4.2, 0.7), "lintel_awakened": ((0, 0, 0.25), 35, 4.2, 0.7),
         "lintel_short": ((0, 0, 0.22), 40, 2.2, 0.5), "tally": ((0.1, 0, 0), 150, 1.2, 0.35),
         "tally_awakened": ((0.1, 0, -0.1), 150, 1.5, 0.3), "counterpart_reflection": ((0, 0, 0.42), 60, 2.6, 0.6),
         "counterpart": ((0, 0, 0.42), 60, 2.6, 0.6), "tipstaff": ((0, 0, 0.36), 40, 2.6, 0.6),
         "tablet": ((0, 0, 0.05), 25, 2.8, 0.3), "knife": ((0, 0, 0.12), 60, 1.2, 0.25),
         "stylus": ((0, 0, 0.12), 60, 1.2, 0.25), "ledger": ((0, 0, 0.02), 30, 1.3, 0.3),
         "post_plain": ((0, 0, 1.0), 25, 6.5, 1.5), "post_sealed": ((0, 0, 1.0), 25, 6.5, 1.5),
         "column": ((0, 0, 5.0), 30, 30, 4.0)}
for i, (name, (target, ang, dist, height)) in enumerate(SHOTS.items()):
    objs, model = getattr(props, name)()
    cam, ground = kit.studio(520, 700)
    if name not in ("post_plain", "post_sealed", "column"):
        ground.location.z = -0.6
    kit.look(cam, target, ang, dist, height)
    kit.render(os.path.join(OUT, "props", "%d_%s.png" % (i, name)))
