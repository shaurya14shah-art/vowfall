# VOWFALL models

Every mesh and material in this folder was made for VOWFALL, from scratch,
by the scripts in `tools/blender/` (`kit.py`, `figure.py`, `characters.py`,
`props.py`). No geometry or texture from any other source is in them. To
rebuild: `blender -b -P tools/blender/build.py`.

**Motion is not ours.** The figures carry 76 animation clips, and the bone
names they play on, from the KayKit Character Pack: Adventurers 1.0 by Kay
Lousberg (CC0, github.com/KayKit-Game-Assets). `tools/blender/rig.py`
re-proportions that skeleton from a 1.5 m figure to a 1.86 m one and keeps
the clips. Credit is given although CC0 does not ask for it. Bespoke
animation is planned for milestone M3 and later.
