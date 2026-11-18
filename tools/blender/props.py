"""Things held, and things that stand in the yard. Modelled from scratch.

Held items are built so that, in the game's hand slot, their length runs
along the slot's +Y: here that is Blender's +Z, with the grip at the origin.
A shield lies in the X-Z plane, in front of the hand at -Y.
"""
import math
import bpy
from mathutils import Vector
import kit


def _fresh(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return kit.Model(name)


def counterpart():
    """The Witness's blade, dormant: single-edged, its flat polished to show
    what is behind its bearer. (The second blade is not there yet.)"""
    m = _fresh("Counterpart")
    rings = []
    for i in range(9):
        t = i / 8.0
        z = 0.085 + 0.90 * t
        w = 0.066 * (1.0 - 0.25 * t) if t < 0.86 else 0.066 * 0.785 * (1.0 - (t - 0.86) / 0.14) + 0.002
        back = -0.030 - 0.034 * t * t           # the spine leans back: a slight curve
        thick = 0.016 * (1.0 - 0.6 * t)
        rings.append([Vector((back, -thick / 2, z)), Vector((back + w, 0, z)), Vector((back, thick / 2, z)),
                      Vector((back - 0.003, 0, z))])
    m.loft(rings, "steel", None, smooth=False)
    m.box((0.004, 0, 0.074), (0.115, 0.030, 0.020), "gold", None)
    m.tube([Vector((0, 0, -0.105)), Vector((0, 0, 0.066))], [(0.015, 0.018), (0.016, 0.019)], "cord", None, n=8, up=(0, 1, 0))
    m.ball((0, 0, -0.122), (0.022, 0.022, 0.024), "gold", None, n=8, m=6)
    return [m.build()], m


def tipstaff():
    """A Bailiff's rod of office: a seal-press on a staff. It stamps as it strikes."""
    m = _fresh("Tipstaff")
    m.tube([Vector((0, 0, -0.14)), Vector((0, 0, 0.09))], [(0.019, 0.019), (0.020, 0.020)], "leather", None, n=8, up=(0, 1, 0))
    m.tube([Vector((0, 0, 0.09)), Vector((0, 0, 0.66))], [(0.017, 0.017), (0.019, 0.019)], "ink", None, n=8, up=(0, 1, 0))
    m.stack([(0.640, 0.030, 0.030), (0.665, 0.034, 0.034)], "gold", None, n=12)
    m.stack([(0.665, 0.050, 0.050), (0.700, 0.066, 0.066), (0.820, 0.070, 0.070), (0.850, 0.052, 0.052)], "lead", None, n=8, smooth=False)
    m.stack([(0.850, 0.074, 0.074), (0.872, 0.074, 0.074)], "gold", None, n=16)     # the seal's face
    m.ball((0, 0, -0.158), (0.026, 0.026, 0.026), "lead", None, n=8, m=6)
    return [m.build()], m


def tablet():
    """A Bailiff's shield: a tablet of the law, arched at the top, the meridian on its face."""
    m = _fresh("Tablet")
    y = -0.055

    def outline(w, h, grow=0.0):
        pts = [Vector((-w / 2 - grow, y, -h / 2 - grow)), Vector((w / 2 + grow, y, -h / 2 - grow))]
        for i in range(9):
            a = math.pi * i / 8.0
            pts.append(Vector((math.cos(a) * (w / 2 + grow), y, h / 2 - w / 2 + math.sin(a) * (w / 2 + grow))))
        return pts

    m.slab(outline(0.40, 0.92, 0.018), 0.030, "lead", None)
    m.slab([p + Vector((0, -0.016, 0)) for p in outline(0.40, 0.92)], 0.014, "vellum", None)
    centre = Vector((0, y - 0.028, 0.10))
    ring = [centre + Vector((math.sin(a) * 0.085, 0, math.cos(a) * 0.085)) for a in [2 * math.pi * i / 20 for i in range(20)]]
    m.strip(ring, (0, -1, 0), 0.010, 0.016, "gold", None, loop=True)
    m.box(centre, (0.014, 0.010, 0.30), "gold", None)
    m.box((0, -0.02, 0.0), (0.05, 0.06, 0.13), "leather", None)                   # the grip behind it
    return [m.build()], m


def knife():
    m = _fresh("Knife")
    rings = []
    for i in range(5):
        t = i / 4.0
        z = 0.05 + 0.27 * t
        w = 0.030 * (1 - t) + 0.002
        rings.append([Vector((-0.010, -0.004, z)), Vector((-0.010 + w, 0, z)), Vector((-0.010, 0.004, z)), Vector((-0.013, 0, z))])
    m.loft(rings, "steel", None, smooth=False)
    m.box((0, 0, 0.044), (0.062, 0.020, 0.012), "lead", None)
    m.tube([Vector((0, 0, -0.085)), Vector((0, 0, 0.040))], [(0.013, 0.015), (0.014, 0.016)], "leather", None, n=8, up=(0, 1, 0))
    return [m.build()], m


def stylus():
    """A Clerk's pen-knife: what the Court's minutes are cut with."""
    m = _fresh("Stylus")
    m.tube([Vector((0, 0, -0.10)), Vector((0, 0, 0.05))], [(0.010, 0.010), (0.012, 0.012)], "ink", None, n=8, up=(0, 1, 0))
    m.stack([(0.050, 0.016, 0.016), (0.062, 0.016, 0.016)], "gold", None, n=10)
    m.tube([Vector((0, 0, 0.062)), Vector((0, 0, 0.30)), Vector((0, 0, 0.36))], [(0.008, 0.008), (0.005, 0.005), (0.001, 0.001)], "steel", None, n=6, up=(0, 1, 0))
    return [m.build()], m


def ledger():
    """A Clerk's ledger, held in the left hand."""
    m = _fresh("Ledger")
    m.box((0, -0.050, 0.02), (0.20, 0.052, 0.27), "leather", None)
    m.box((0.006, -0.050, 0.02), (0.19, 0.040, 0.255), "vellum", None)
    m.box((0.070, -0.078, 0.02), (0.03, 0.006, 0.28), "vermilion", None)            # a ribbon marking the place
    return [m.build()], m


def _post(m, sealed):
    # A stele: stepped plinth, eight-sided tapering shaft, a band, a cap, and a round face.
    m.box((0, 0, 0.06), (0.86, 0.86, 0.12), "stone_dark", None)
    m.box((0, 0, 0.17), (0.70, 0.70, 0.10), "stone", None)
    m.stack([(0.22, 0.300, 0.300), (1.40, 0.240, 0.240), (1.76, 0.226, 0.226)], "stone", None, n=8, smooth=False, cap_start=False)
    m.stack([(1.36, 0.262, 0.262), (1.44, 0.260, 0.260)], "stone_dark", None, n=8, smooth=False)
    m.stack([(1.76, 0.300, 0.300), (1.80, 0.320, 0.320), (1.88, 0.320, 0.320), (1.98, 0.130, 0.130)], "stone_dark", None, n=8, smooth=False)
    face_y = -0.262
    m.disc((0, face_y, 1.13), (0, -1, 0), 0.150, 0.050, "stone_dark", None, n=20)
    if not sealed:
        m.disc((0, face_y - 0.030, 1.13), (0, -1, 0), 0.105, 0.016, "stone", None, n=20)
        return
    # Sealed: a wax seal with a raised rim and the meridian, ribbons below, a gold band above.
    m.disc((0, face_y - 0.034, 1.13), (0, -1, 0), 0.135, 0.030, "vermilion", None, n=20)
    centre = Vector((0, face_y - 0.054, 1.13))
    ring = [centre + Vector((math.sin(a) * 0.092, 0, math.cos(a) * 0.092)) for a in [2 * math.pi * i / 20 for i in range(20)]]
    m.strip(ring, (0, -1, 0), 0.012, 0.016, "gold", None, loop=True)
    m.box(centre, (0.014, 0.012, 0.24), "gold", None)
    for sx, length in ((-1, 0.46), (1, 0.36)):
        m.strip([(sx * 0.045, face_y - 0.030, 1.02), (sx * 0.060, face_y - 0.045, 0.86), (sx * 0.070, face_y - 0.040, 1.02 - length)],
                (1, 0, 0), 0.060, 0.010, "vermilion", None)
    m.stack([(1.50, 0.248, 0.248), (1.55, 0.246, 0.246)], "gold", None, n=8, smooth=False)


def post_plain():
    m = _fresh("PostPlain")
    _post(m, False)
    return [m.build()], m


def post_sealed():
    m = _fresh("PostSealed")
    _post(m, True)
    return [m.build()], m


def column():
    """A column of the yard, ten metres: plinth, base, a shaft with a slight
    swell, a necking band, a flared capital and a square abacus."""
    m = _fresh("Column")
    m.box((0, 0, 0.20), (2.00, 2.00, 0.40), "stone_dark", None)
    m.stack([(0.40, 0.92, 0.92), (0.50, 0.96, 0.96), (0.60, 0.90, 0.90), (0.68, 0.78, 0.78), (0.76, 0.80, 0.80), (0.84, 0.74, 0.74)],
            "stone", None, n=28)
    shaft = []
    for i in range(9):
        t = i / 8.0
        r = 0.72 - 0.10 * t + 0.035 * math.sin(math.pi * t)       # entasis: it swells a little, then narrows
        shaft.append((0.84 + 8.20 * t, r, r))
    m.stack(shaft, "stone", None, n=28, cap_start=False, cap_end=False)
    m.stack([(9.04, 0.66, 0.66), (9.12, 0.68, 0.68), (9.20, 0.63, 0.63)], "stone_dark", None, n=28)
    m.stack([(9.20, 0.63, 0.63), (9.40, 0.74, 0.74), (9.56, 0.94, 0.94), (9.62, 0.96, 0.96)], "stone", None, n=28)
    m.box((0, 0, 9.81), (2.10, 2.10, 0.38), "stone_dark", None)
    return [m.build()], m


# ------------------------------------------------------------ Instruments
# The three bound weapons of the slice, dormant and awakened (docs/06).

def _blade(m, mat):
    rings = []
    for i in range(9):
        t = i / 8.0
        z = 0.085 + 0.90 * t
        w = 0.066 * (1.0 - 0.25 * t) if t < 0.86 else 0.066 * 0.785 * (1.0 - (t - 0.86) / 0.14) + 0.002
        back = -0.030 - 0.034 * t * t
        thick = 0.016 * (1.0 - 0.6 * t)
        rings.append([Vector((back, -thick / 2, z)), Vector((back + w, 0, z)), Vector((back, thick / 2, z)),
                      Vector((back - 0.003, 0, z))])
    m.loft(rings, mat, None, smooth=False)


def counterpart_reflection():
    """The Counterpart's second blade, seen once Unveiled: the same blade,
    reversed, with nothing of the first one's warmth. Held in the left hand."""
    m = _fresh("CounterpartReflection")
    _blade(m, "mirror")
    m.box((0.004, 0, 0.074), (0.115, 0.030, 0.020), "mirror", None)
    m.tube([Vector((0, 0, -0.105)), Vector((0, 0, 0.066))], [(0.015, 0.018), (0.016, 0.019)], "steel", None, n=8, up=(0, 1, 0))
    m.ball((0, 0, -0.122), (0.022, 0.022, 0.024), "mirror", None, n=8, m=6)
    obj = m.build()
    obj.scale = (-1, 1, 1)          # reversed left for right
    return [obj], m


def _stave(m, low, high):
    """A surveyor's stave: dark wood ruled in brass, a spike for planting."""
    m.tube([Vector((0, 0, low)), Vector((0, 0, high))], [(0.021, 0.021), (0.019, 0.019)], "ink", None, n=10, up=(0, 1, 0))
    z = low + 0.18
    while z < high - 0.05:
        m.stack([(z, 0.0235, 0.0235), (z + 0.012, 0.0235, 0.0235)], "gold", None, n=10)
        z += 0.15
    m.tube([Vector((0, 0, low)), Vector((0, 0, low - 0.10))], [(0.016, 0.016), (0.002, 0.002)], "steel", None, n=8, up=(0, 1, 0))


def lintel():
    """The Lintel, dormant: a stave as tall as its bearer, its crossbar
    folded down against the head. Half a doorframe, carried."""
    m = _fresh("Lintel")
    _stave(m, -0.78, 1.14)
    m.stack([(1.10, 0.034, 0.034), (1.18, 0.034, 0.034)], "gold", None, n=10)          # the hinge
    m.box((0.050, 0, 0.90), (0.050, 0.042, 0.52), "ink", None)                           # the bar, folded
    m.box((0.050, 0, 0.652), (0.056, 0.048, 0.030), "gold", None)
    return [m.build()], m


def lintel_awakened():
    """The Lintel, awakened: the crossbar stands open. It is a lintel now,
    and where it is planted there is a door."""
    m = _fresh("LintelAwakened")
    _stave(m, -0.78, 1.14)
    m.stack([(1.10, 0.034, 0.034), (1.18, 0.034, 0.034)], "gold", None, n=10)
    m.box((0.285, 0, 1.155), (0.57, 0.046, 0.054), "ink", None)                          # the bar, open
    m.box((0.560, 0, 1.155), (0.030, 0.052, 0.062), "gold", None)
    m.slab([(0.022, 0, 1.12), (0.20, 0, 1.12), (0.022, 0, 0.94)], 0.020, "gold", None)   # the brace
    return [m.build()], m


def lintel_short():
    """What the Witness fights with while the Lintel is planted: the short
    half, unscrewed at the grip."""
    m = _fresh("LintelShort")
    m.tube([Vector((0, 0, -0.16)), Vector((0, 0, 0.62))], [(0.021, 0.021), (0.019, 0.019)], "ink", None, n=10, up=(0, 1, 0))
    for z in (0.10, 0.25, 0.40, 0.55):
        m.stack([(z, 0.0235, 0.0235), (z + 0.012, 0.0235, 0.0235)], "gold", None, n=10)
    m.stack([(0.60, 0.028, 0.028), (0.66, 0.030, 0.030)], "gold", None, n=10)
    m.ball((0, 0, -0.175), (0.026, 0.026, 0.026), "gold", None, n=8, m=6)
    return [m.build()], m


def _gauntlet(m):
    # Built for the LEFT hand slot: fingers toward -X, elbow toward +X, the
    # back of the hand toward -Y (which is the slot's +Z in the game).
    back = -0.05
    m.ball((-0.035, back + 0.012, 0.0), (0.078, 0.062, 0.070), "bronze", None, n=12, m=8)      # the fist
    m.tube([Vector((0.035, back + 0.01, 0)), Vector((0.14, back - 0.005, 0)), Vector((0.27, back - 0.01, 0))],
           [(0.062, 0.056), (0.066, 0.060), (0.074, 0.066)], "bronze", None, n=12, up=(0, 1, 0))
    for x in (-0.075, -0.045, -0.015):                                                         # knuckles
        m.box((x, back - 0.040, 0.0), (0.022, 0.022, 0.118), "lead", None)
    m.disc((0.150, back - 0.066, 0.0), (0, -1, 0), 0.040, 0.016, "gold", None, n=16)           # the reliquary window
    m.disc((0.150, back - 0.076, 0.0), (0, -1, 0), 0.026, 0.008, "vellum", None, n=16)
    # The counting cord, wound up the cuff.
    for i, x in enumerate((0.065, 0.105, 0.205, 0.245)):
        r = 0.068 + 0.004 * i
        ring = [Vector((x, back - 0.002 + math.cos(a) * r * 0.90, math.sin(a) * r)) for a in
                [2 * math.pi * k / 14 for k in range(14)]]
        m.strip(ring, (1, 0, 0), 0.014, 0.012, "cord", None, loop=True)


def tally():
    """The Tally, dormant: a heavy reliquary gauntlet for the off hand, its
    counting-cord wound tight. Harm caught on it is recorded at full value."""
    m = _fresh("Tally")
    _gauntlet(m)
    for k in range(5):                                                                          # beads, locked
        m.ball((0.085 + 0.034 * k, -0.118, 0.045), (0.015, 0.015, 0.015), "cord", None, n=6, m=4)
    return [m.build()], m


def tally_awakened():
    """The Tally, awakened: the cord unwinds and trails, its beads lit. It
    can be cast to reach a debtor."""
    m = _fresh("TallyAwakened")
    _gauntlet(m)
    path = [Vector((0.24, -0.11, 0.0)), Vector((0.22, -0.13, -0.16)), Vector((0.17, -0.12, -0.34)),
            Vector((0.10, -0.10, -0.50)), Vector((0.02, -0.09, -0.62))]
    m.tube(path, [(0.007, 0.007)] * 5, "cord", None, n=6, up=(0, 1, 0))
    for i in range(7):
        t = i / 6.0
        seg = min(3, int(t * 4))
        f = t * 4 - seg
        p = path[seg].lerp(path[seg + 1], min(1.0, f))
        m.ball(p, (0.019, 0.019, 0.019), "gold", None, n=8, m=5)
    return [m.build()], m


# ---------------------------------------------------------- Aurel Voss's

def imprimatur():
    """The Imprimatur: a seal-press on a staff taller than a door. Where its
    head comes down, a Writ is stamped into the floor. A Singular: it is no
    one else's Instrument and no one else could carry it."""
    m = _fresh("Imprimatur")
    _stave(m, -0.86, 1.06)
    m.stack([(1.02, 0.036, 0.036), (1.07, 0.050, 0.050)], "gold", None, n=12)
    m.stack([(1.07, 0.080, 0.080), (1.11, 0.094, 0.094), (1.28, 0.098, 0.098), (1.31, 0.086, 0.086)], "lead", None, n=10, smooth=False)
    m.stack([(1.31, 0.112, 0.112), (1.335, 0.112, 0.112)], "gold", None, n=20)                # the matrix
    m.stack([(1.335, 0.090, 0.090), (1.345, 0.090, 0.090)], "vermilion", None, n=20)          # wax, still on it
    for a in range(4):                                                                         # the press's four screws
        ang = math.pi / 4 + a * math.pi / 2
        m.tube([Vector((math.cos(ang) * 0.086, math.sin(ang) * 0.086, 1.09)), Vector((math.cos(ang) * 0.086, math.sin(ang) * 0.086, 1.30))],
               [(0.010, 0.010), (0.010, 0.010)], "gold", None, n=6, up=(0, 1, 0))
    return [m.build()], m


def seal_mark():
    """What the Imprimatur leaves on the floor: a seal a stride and a half
    across, the meridian raised on it. It is a thing in the fight, and can
    be struck, and bound."""
    m = _fresh("SealMark")
    m.stack([(0.000, 0.86, 0.86), (0.030, 0.86, 0.86), (0.034, 0.82, 0.82)], "vermilion", None, n=36)
    rim = [Vector((math.cos(a) * 0.80, math.sin(a) * 0.80, 0.040)) for a in [2 * math.pi * i / 36 for i in range(36)]]
    m.strip(rim, (0, 0, 1), 0.016, 0.050, "vermilion", None, loop=True)
    ring = [Vector((math.cos(a) * 0.34, math.sin(a) * 0.34, 0.044)) for a in [2 * math.pi * i / 28 for i in range(28)]]
    m.strip(ring, (0, 0, 1), 0.020, 0.050, "gold", None, loop=True)
    m.box((0, 0, 0.044), (0.050, 1.20, 0.020), "gold", None)
    return [m.build()], m
