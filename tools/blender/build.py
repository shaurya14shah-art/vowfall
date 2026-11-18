"""Builds every VOWFALL model and writes it to game/assets/models/.

    blender -b -P tools/blender/build.py              # everything
    blender -b -P tools/blender/build.py -- witness   # one thing

Headless: no window opens. Figures are exported with the 76 motion clips of
the re-proportioned rig (rig.py). Nothing here imports geometry.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig
import characters
import props
import world

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../game/assets/models"))
FIGURES = ["witness", "bailiff", "ward", "clerk", "voss"]
PROPS = ["counterpart", "counterpart_reflection", "lintel", "lintel_awakened", "lintel_short", "tally",
         "tally_awakened", "imprimatur", "seal_mark", "tipstaff", "tablet", "knife", "stylus", "ledger", "post_plain", "post_sealed", "column"]

WORLD = world.ALL        # what stands in the Assize Quarter

wanted = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else FIGURES + PROPS + WORLD
if wanted == ["world"]:
    wanted = WORLD
os.makedirs(os.path.join(OUT, "world"), exist_ok=True)
os.makedirs(os.path.join(OUT, "figures"), exist_ok=True)
os.makedirs(os.path.join(OUT, "props"), exist_ok=True)
for name in wanted:
    if name in FIGURES:
        arm, objs, model = getattr(characters, name)()
        rig.unpose(arm)
        rig.export(arm, objs, os.path.join(OUT, "figures", name + ".glb"), animations=True)
    elif name in WORLD:
        objs, model = getattr(world, name)()
        rig.export(None, objs, os.path.join(OUT, "world", name + ".glb"), animations=False)
    else:
        objs, model = getattr(props, name)()
        rig.export(None, objs, os.path.join(OUT, "props", name + ".glb"), animations=False)
    print("BUILT %-12s %5d triangles" % (name, model.triangles()))
