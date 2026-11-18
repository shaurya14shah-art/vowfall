"""What stands in the Assize Quarter (M5). Modelled from scratch, like
everything else: no imported geometry.

A thing's front is Blender's -Y, which is +Z in the game at yaw 0. Each
stands on the ground at the origin, except the banner, which hangs from it.

The rule from docs/08 holds here: gold only on what carries law, vermilion
only for an act, and what was struck is a flat matte black.
"""
import math
import bpy
from mathutils import Vector, Matrix
import kit


def _fresh(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return kit.Model(name)


def _rand(i, k=0):
    """A fixed scatter in 0..1: the same clutter every build."""
    return (math.sin(i * 12.9898 + k * 78.233) * 43758.5453) % 1.0


def _meridian(m, centre, radius, normal=(0, -1, 0), mat="gold", n=24):
    """The Court's mark: a circle with a line through it, raised on a face."""
    c = Vector(centre)
    nrm = Vector(normal).normalized()
    side = Vector((1, 0, 0)) if abs(nrm.x) < 0.9 else Vector((0, 1, 0))
    up = nrm.cross(side).normalized()
    side = up.cross(nrm).normalized()
    ring = [c + side * math.cos(2 * math.pi * i / n) * radius + up * math.sin(2 * math.pi * i / n) * radius for i in range(n)]
    m.strip(ring, nrm, radius * 0.10, radius * 0.12, mat, None, loop=True)
    m.strip([c - up * radius * 1.45, c + up * radius * 1.45], nrm, radius * 0.10, radius * 0.10, mat, None)


def vow_stone():
    """A vow-stone: older than the square around it. A leaning, unworked
    stone with one worked thing in it, a plate for the hand, and round it a
    cord from which kept vows hang as strips of vellum."""
    m = _fresh("VowStone")
    m.stack([(0.00, 0.66, 0.66), (0.10, 0.66, 0.66), (0.15, 0.54, 0.54)], "stone_dark", None, n=10, smooth=False)
    rough = lambda ang, li: 1.0 + 0.10 * math.sin(3 * ang + li * 1.3) + 0.05 * math.sin(5 * ang + li * 2.1)
    m.stack([(0.15, 0.42, 0.35), (0.62, 0.40, 0.33, 0.01, 0.0), (1.20, 0.34, 0.28, 0.03, 0.0),
             (1.64, 0.26, 0.21, 0.05, 0.0), (1.86, 0.11, 0.09, 0.07, 0.0)], "stone", None, n=9, smooth=False,
            cap_start=False, shape=rough)
    m.disc((0.02, -0.300, 1.12), (0, -1, 0.12), 0.165, 0.050, "stone_dark", None, n=20)
    m.disc((0.02, -0.330, 1.12), (0, -1, 0.12), 0.120, 0.020, "gold", None, n=20)
    m.box((0.02, -0.344, 1.12), (0.014, 0.012, 0.30), "gold", None)
    ring = [Vector((0.02 + math.sin(a) * 0.40, -math.cos(a) * 0.335, 0.80 + 0.03 * math.sin(2 * a)))
            for a in [2 * math.pi * i / 16 for i in range(16)]]
    m.strip(ring, (0, 0, 1), 0.035, 0.030, "cord", None, loop=True)
    for i, a in enumerate([-1.1, -0.55, 0.1, 0.5, 1.2, 2.3, 3.4, 4.3]):
        length = 0.26 + 0.24 * _rand(i)
        top = Vector((0.02 + math.sin(a) * 0.42, -math.cos(a) * 0.355, 0.79))
        out = Vector((math.sin(a), -math.cos(a), 0.0))
        m.strip([top, top + out * 0.03 + Vector((0, 0, -length * 0.5)), top + out * 0.01 + Vector((0, 0, -length))],
                out.cross(Vector((0, 0, 1))), 0.075, 0.008, "vellum", None)
    return [m.build()], m


def lectern():
    """A reading stand: something has been left on it to be read."""
    m = _fresh("Lectern")
    m.box((0, 0, 0.05), (0.60, 0.60, 0.10), "stone_dark", None)
    m.box((0, 0, 0.14), (0.44, 0.44, 0.08), "stone", None)
    m.stack([(0.18, 0.115, 0.115), (0.92, 0.085, 0.085), (0.99, 0.15, 0.15)], "stone", None, n=8, smooth=False)
    tilt = 0.46
    rot = Matrix.Rotation(tilt, 4, 'X')
    nrm = rot @ Vector((0, 0, 1))
    c = Vector((0, -0.02, 1.10))
    m.box(c, (0.70, 0.50, 0.05), "ink_soft", None, rot=rot)
    m.box(c + nrm * 0.032, (0.44, 0.34, 0.012), "vellum", None, rot=rot)
    m.box(c + rot @ Vector((0, -0.235, 0.045)), (0.70, 0.03, 0.05), "leather", None, rot=rot)     # the ledge
    for k in range(4):                                                                          # ruled lines
        m.box(c + nrm * 0.040 + rot @ Vector((0, 0.10 - 0.065 * k, 0)), (0.34, 0.008, 0.003), "ink", None, rot=rot)
    hang = c + rot @ Vector((0.27, -0.25, 0.0))
    m.tube([hang, hang + Vector((0.0, -0.01, -0.20))], [(0.006, 0.006), (0.006, 0.006)], "cord", None, n=5)
    m.disc(hang + Vector((0.0, -0.012, -0.24)), (0, -1, 0), 0.045, 0.016, "lead", None, n=12)
    return [m.build()], m


def stall():
    """An oath-broker's booth: a counter, an awning, a ledger. For a fee a
    broker finds you a witness. Nobody is buying today."""
    m = _fresh("Stall")
    m.box((0, -0.30, 0.46), (2.60, 0.70, 0.92), "undyed", None)
    m.box((0, -0.30, 0.95), (2.74, 0.80, 0.06), "leather", None)
    m.box((0, 0.62, 1.30), (2.60, 0.06, 2.20), "undyed", None)
    for sx in (-1.27, 1.27):
        m.box((sx, 0.60, 1.25), (0.10, 0.10, 2.50), "leather", None)
        m.box((sx, -0.62, 1.12), (0.08, 0.08, 2.24), "leather", None)
    rot = Matrix.Rotation(0.20, 4, 'X')
    c = Vector((0, -0.04, 2.40))
    m.box(c, (2.96, 1.66, 0.05), "vellum", None, rot=rot)
    for k in (-1, 0, 1):
        m.box(c + rot @ Vector((k * 0.98, 0.0, 0.03)), (0.20, 1.66, 0.012), "verdigris", None, rot=rot)
    m.box(c + rot @ Vector((0, -0.84, -0.10)), (2.96, 0.03, 0.22), "vellum", None, rot=rot)          # the valance
    m.box((-0.62, -0.34, 1.01), (0.42, 0.30, 0.07), "leather", None, rot=(0.25, 'Z'))                # the ledger
    m.box((-0.62, -0.34, 1.05), (0.36, 0.26, 0.012), "vellum", None, rot=(0.25, 'Z'))
    for i, x in enumerate((0.25, 0.48, 0.74, 0.96)):                                                 # blank seals, unsold
        m.disc((x, -0.36 + 0.10 * _rand(i), 0.995), (0, 0, 1), 0.050, 0.022, "lead", None, n=10)
    m.stack([(0.98, 0.050, 0.050, 0.05, -0.12), (1.08, 0.045, 0.045, 0.05, -0.12), (1.10, 0.025, 0.025, 0.05, -0.12)],
            "ink", None, n=8, smooth=False)                                                           # ink
    m.tube([(-1.27, -0.66, 2.02), (-1.27, -0.86, 2.02)], [(0.012, 0.012), (0.012, 0.012)], "leather", None, n=5, up=(0, 0, 1))
    m.disc((-1.27, -0.86, 1.84), (0, -1, 0), 0.17, 0.03, "undyed", None, n=16)                        # the broker's sign: an open hand's width
    m.box((-1.27, -0.88, 1.84), (0.20, 0.012, 0.03), "ink", None)
    return [m.build()], m


def shelf():
    """A docket shelf: rolled records, sealed in lead. The lower rows have
    been under water."""
    m = _fresh("Shelf")
    m.box((0, 0.38, 1.60), (3.30, 0.04, 3.20), "ink_soft", None)
    for sx in (-1.65, 0, 1.65):
        m.box((sx, 0, 1.60), (0.10, 0.80, 3.20), "leather", None)
    for i in range(5):
        z = 0.22 + i * 0.72
        m.box((0, 0, z), (3.30, 0.80, 0.06), "leather", None)
        if i == 4:
            break
        x = -1.52
        k = 0
        while x < 1.50:
            r = 0.085 + 0.03 * _rand(k, i)
            if x < 0.07 and x + 2 * r > -0.07:                         # the middle upright
                x = 0.08
                continue
            if _rand(k, i + 7) > 0.16:                                  # gaps: some have been taken
                mat = "verdigris" if i == 0 else ("undyed" if (i == 1 and _rand(k, 3) > 0.4) else ("wool" if _rand(k, 5) > 0.5 else "vellum"))
                length = 0.52 + 0.16 * _rand(k, i + 2)
                m.tube([(x + r, -0.36, z + 0.03 + r), (x + r, -0.36 + length, z + 0.03 + r)], [(r, r), (r, r)], mat, None, n=7, up=(0, 0, 1))
                if _rand(k, i + 11) > 0.6:
                    m.disc((x + r, -0.375, z + 0.03 + r), (0, -1, 0), 0.032, 0.014, "lead", None, n=8)
            x += 2 * r + 0.02
            k += 1
    m.box((0, 0, 3.24), (3.42, 0.86, 0.08), "ink_soft", None)
    return [m.build()], m


def _plinth(m):
    m.box((0, 0, 0.20), (1.80, 1.80, 0.40), "stone_dark", None)
    m.box((0, 0, 1.20), (1.40, 1.40, 1.60), "stone", None)
    m.box((0, 0, 2.10), (1.62, 1.62, 0.20), "stone_dark", None)


def statue():
    """An Arbiter in stone, six metres with the plinth: robe, tall cap, the
    seal-press held upright. The Court's mark is on the plinth in gold."""
    m = _fresh("Statue")
    _plinth(m)
    _meridian(m, (0, -0.715, 1.25), 0.26)
    fold = lambda ang, li: 1.0 + 0.045 * math.cos(7 * ang) * (1.0 if li < 3 else 0.3)
    m.stack([(2.20, 0.64, 0.52), (3.20, 0.50, 0.40), (4.30, 0.43, 0.33), (4.86, 0.54, 0.35), (5.02, 0.40, 0.29), (5.10, 0.16, 0.15)],
            "stone", None, n=14, smooth=False, shape=fold)
    m.box((0, -0.37, 3.55), (0.24, 0.07, 2.50), "stone_dark", None, rot=(-0.085, 'X'))          # the stole
    m.ball((0, -0.01, 5.30), (0.19, 0.21, 0.25), "stone", None, n=10, m=7, smooth=False)
    m.stack([(5.46, 0.20, 0.21), (5.52, 0.215, 0.225), (5.98, 0.185, 0.195)], "stone", None, n=8, smooth=False)
    m.box((0, -0.21, 5.30), (0.06, 0.08, 0.16), "stone", None)                                  # a nose, at this height all it needs
    staff = Vector((0.50, -0.42, 0.0))
    m.tube([staff + Vector((0, 0, 2.20)), staff + Vector((0, 0, 5.72))], [(0.055, 0.055), (0.050, 0.050)], "stone", None, n=8)
    m.stack([(5.72, 0.12, 0.12, staff.x, staff.y), (5.78, 0.16, 0.16, staff.x, staff.y), (6.04, 0.165, 0.165, staff.x, staff.y),
             (6.10, 0.20, 0.20, staff.x, staff.y), (6.15, 0.20, 0.20, staff.x, staff.y)], "stone", None, n=10, smooth=False)
    for sx, hand in ((1, Vector((0.50, -0.40, 4.30))), (-1, Vector((0.46, -0.44, 3.86)))):
        sh = Vector((sx * 0.46, -0.02, 4.80))
        el = Vector((sx * 0.58, -0.22, 4.22)) if sx > 0 else Vector((-0.44, -0.34, 4.10))
        m.tube([sh, el, hand], [(0.13, 0.13), (0.11, 0.11), (0.085, 0.085)], "stone", None, n=7)
    return [m.build()], m


def plinth_struck():
    """A plinth with the feet of whoever stood on it. Where the name was
    there is a flat black bar. What was struck is still visible."""
    m = _fresh("PlinthStruck")
    _plinth(m)
    m.box((0, -0.712, 1.25), (0.96, 0.03, 0.26), "struck", None)
    jag = lambda ang, li: 1.0 + (0.22 * math.sin(4 * ang + 1.0) if li == 2 else 0.0)
    cut = lambda ang, li: (0.10 * math.sin(3 * ang) if li == 2 else 0.0)
    for sx in (-0.26, 0.24):
        m.stack([(2.20, 0.22, 0.30, sx, -0.04), (2.34, 0.17, 0.20, sx, 0.02), (2.62 + 0.14 * (sx > 0), 0.14, 0.16, sx, 0.03)],
                "stone", None, n=8, smooth=False, shape=jag, zfun=cut)
    return [m.build()], m


def rubble():
    """Fallen stone: blocks of the Oath Hall and one drum of a column."""
    m = _fresh("Rubble")
    for i in range(9):
        w, d, h = 0.5 + 0.8 * _rand(i, 1), 0.4 + 0.7 * _rand(i, 2), 0.25 + 0.45 * _rand(i, 3)
        x, y = -1.2 + 2.4 * _rand(i, 4), -0.9 + 1.8 * _rand(i, 5)
        rot = Matrix.Rotation(_rand(i, 6) * 6.28, 4, 'Z') @ Matrix.Rotation((_rand(i, 7) - 0.5) * 0.7, 4, 'X')
        m.box((x, y, h * 0.45 + 0.2 * _rand(i, 8) * (i % 3 == 0)), (w, d, h), "stone" if i % 4 else "stone_dark", None, rot=rot)
    m.tube([(-0.9, 0.5, 0.62), (0.5, 0.2, 0.72)], [(0.66, 0.66), (0.62, 0.62)], "stone", None, n=14, up=(0, 0, 1))
    m.tube([(-0.95, 0.51, 0.62), (-0.86, 0.49, 0.63)], [(0.74, 0.74), (0.74, 0.74)], "stone_dark", None, n=14, up=(0, 0, 1))
    return [m.build()], m


def lamp():
    """A standing lamp of old bronze, gone green. Its light is steady:
    in Veyr a lamp is lit under a vow to keep it."""
    m = _fresh("Lamp")
    m.stack([(0.00, 0.26, 0.26), (0.08, 0.26, 0.26), (0.16, 0.14, 0.14), (0.30, 0.07, 0.07)], "stone_dark", None, n=8, smooth=False)
    m.tube([(0, 0, 0.30), (0, 0, 2.70)], [(0.045, 0.045), (0.035, 0.035)], "verdigris", None, n=8)
    m.stack([(1.40, 0.060, 0.060), (1.46, 0.075, 0.075), (1.52, 0.060, 0.060)], "bronze", None, n=8)
    m.stack([(2.70, 0.05, 0.05), (2.76, 0.19, 0.19), (2.80, 0.19, 0.19)], "verdigris", None, n=6, smooth=False)
    for i in range(6):
        a = 2 * math.pi * i / 6
        m.tube([(math.sin(a) * 0.17, math.cos(a) * 0.17, 2.80), (math.sin(a) * 0.17, math.cos(a) * 0.17, 3.16)],
               [(0.012, 0.012), (0.012, 0.012)], "verdigris", None, n=4)
    m.stack([(2.82, 0.13, 0.13), (3.14, 0.13, 0.13)], "lamp", None, n=6, smooth=False)
    m.stack([(3.16, 0.23, 0.23), (3.20, 0.21, 0.21), (3.36, 0.05, 0.05), (3.46, 0.02, 0.02)], "verdigris", None, n=6, smooth=False)
    return [m.build()], m


def banner():
    """A banner of the Meridian Court, hung from its rod: seven metres of
    ink wool, the mark in gold, a pale hem cut to two points."""
    m = _fresh("Banner")
    m.tube([(-0.82, -0.14, -0.05), (0.82, -0.14, -0.05)], [(0.04, 0.04), (0.04, 0.04)], "bronze", None, n=8, up=(0, 0, 1))
    for sx in (-0.82, 0.82):
        m.ball((sx, -0.14, -0.05), (0.07, 0.07, 0.07), "bronze", None, n=8, m=6)
        m.box((sx * 0.9, -0.07, -0.05), (0.05, 0.14, 0.05), "bronze", None)
    y = -0.14
    m.slab([(-0.68, y, -0.05), (0.68, y, -0.05), (0.68, y, -6.2), (-0.68, y, -6.2)], 0.035, "ink", None)
    m.slab([(-0.68, y, -6.2), (0.68, y, -6.2), (0.68, y, -7.0), (0.0, y, -6.45), (-0.68, y, -7.0)], 0.035, "vellum", None)
    m.box((0, y, -6.14), (1.36, 0.045, 0.07), "gold", None)
    _meridian(m, (0, y - 0.03, -1.7), 0.42)
    for k in range(3):                                                  # three ruled lines: a banner is a page
        m.box((0, y - 0.02, -3.2 - 0.34 * k), (0.9 - 0.2 * k, 0.012, 0.035), "vellum", None)
    return [m.build()], m


def gate():
    """One panel of a bronze grille, two metres by five. A way is barred by
    as many as it takes."""
    m = _fresh("Gate")
    for i in range(5):
        x = -0.8 + 0.4 * i
        m.tube([(x, 0, 0.0), (x, 0, 4.62)], [(0.040, 0.040), (0.036, 0.036)], "verdigris", None, n=6)
        m.stack([(4.62, 0.060, 0.060, x, 0), (4.70, 0.075, 0.035, x, 0), (5.00, 0.004, 0.004, x, 0)], "bronze", None, n=4, smooth=False)
    for z in (0.22, 2.40, 4.40):
        m.box((0, 0, z), (2.00, 0.07, 0.10), "bronze", None)
    m.disc((0, -0.05, 2.40), (0, -1, 0), 0.20, 0.05, "lead", None, n=16)
    m.box((0, -0.08, 2.40), (0.024, 0.012, 0.52), "bronze", None)
    return [m.build()], m


def door():
    """The Witness Gate: two leaves of green bronze eight metres high, shut
    and barred. The Court's seal was set across the join after you came in."""
    m = _fresh("Door")
    for sx in (-3.5, 3.5):
        m.box((sx, -0.20, 4.4), (0.80, 0.40, 8.8), "stone_dark", None)
    m.box((0, -0.24, 9.15), (8.40, 0.48, 0.90), "stone_dark", None)
    m.box((0, -0.26, 9.66), (8.90, 0.52, 0.16), "stone", None)
    for sx in (-1, 1):
        m.box((sx * 1.56, -0.10, 4.35), (3.06, 0.16, 8.70), "verdigris", None)
        for row in range(4):
            z = 1.1 + row * 2.2
            m.box((sx * 1.56, -0.19, z), (2.60, 0.03, 1.70), "bronze", None)
            m.box((sx * 1.56, -0.21, z), (2.20, 0.03, 1.30), "verdigris", None)
            for cx in (-1.18, 1.18):
                for cz in (-0.75, 0.75):
                    m.disc((sx * 1.56 + cx, -0.215, z + cz), (0, -1, 0), 0.06, 0.03, "bronze", None, n=8)
    m.box((0, -0.27, 3.3), (5.60, 0.10, 0.26), "lead", None)                                   # the bar
    for sx in (-2.6, 2.6):
        m.box((sx, -0.25, 3.3), (0.30, 0.16, 0.50), "bronze", None)
    m.disc((0, -0.30, 4.6), (0, -1, 0), 0.56, 0.07, "vermilion", None, n=28)                    # sealed: an act, still fresh
    _meridian(m, (0, -0.345, 4.6), 0.36)
    for sx, length in ((-0.16, 1.5), (0.14, 1.1)):
        m.strip([(sx, -0.30, 4.1), (sx * 1.3, -0.33, 3.5), (sx * 1.5, -0.31, 4.1 - length)], (1, 0, 0), 0.20, 0.014, "vermilion", None)
    return [m.build()], m


def desk():
    """A copyist's desk: a sloped board, a sheet half ruled, ink, a stool
    pushed back in a hurry."""
    m = _fresh("Desk")
    for sx in (-0.66, 0.66):
        m.box((sx, 0, 0.50), (0.07, 0.72, 1.00), "leather", None)
    m.box((0, 0.30, 0.56), (1.32, 0.05, 0.86), "undyed", None)
    m.box((0, 0, 0.30), (1.32, 0.60, 0.05), "undyed", None)
    rot = Matrix.Rotation(0.30, 4, 'X')
    nrm = rot @ Vector((0, 0, 1))
    c = Vector((0, -0.02, 1.06))
    m.box(c, (1.50, 0.84, 0.05), "ink_soft", None, rot=rot)
    m.box(c + rot @ Vector((0, -0.42, 0.04)), (1.50, 0.03, 0.05), "leather", None, rot=rot)
    m.box(c + nrm * 0.032 + rot @ Vector((-0.20, 0.0, 0)), (0.62, 0.52, 0.012), "vellum", None, rot=rot)
    for k in range(5):
        m.box(c + nrm * 0.040 + rot @ Vector((-0.20, 0.18 - 0.07 * k, 0)), (0.50 if k < 3 else 0.22, 0.008, 0.003), "ink", None, rot=rot)
    m.box(c + nrm * 0.035 + rot @ Vector((0.44, 0.10, 0)), (0.30, 0.40, 0.02), "vellum", None, rot=rot @ Matrix.Rotation(0.3, 4, 'Z'))
    pot = c + rot @ Vector((0.56, 0.30, 0.03))
    m.stack([(pot.z, 0.05, 0.05, pot.x, pot.y), (pot.z + 0.09, 0.045, 0.045, pot.x, pot.y), (pot.z + 0.10, 0.025, 0.025, pot.x, pot.y)],
            "ink", None, n=8, smooth=False)
    m.stack([(0.00, 0.17, 0.17, 0.22, -0.86), (0.44, 0.15, 0.15, 0.22, -0.86), (0.48, 0.20, 0.20, 0.22, -0.86), (0.52, 0.20, 0.20, 0.22, -0.86)],
            "leather", None, n=8, smooth=False)
    return [m.build()], m


def hanging_courts():
    """The Hanging Courts: the upper city of Veyr, seen from underneath. An
    inverted hill of four terraces, its towers built downward, one great
    keel pointing at the Hall of Standing, the Court's mark in gold on its
    belly, and chains that hang from its rim and hold nothing. The origin
    is the tip of the keel, its lowest point. 124 metres across."""
    m = _fresh("HangingCourts")
    tiers = [(14.0, 20.0, 16.0), (20.0, 27.0, 30.0), (27.0, 35.0, 46.0), (35.0, 44.0, 62.0)]     # z0, z1, radius
    # The keel: a tower built point-down, with two collars.
    m.stack([(0.0, 0.25, 0.25), (5.0, 1.5, 1.5), (5.6, 2.3, 2.3), (6.2, 1.9, 1.9), (10.4, 3.4, 3.4), (11.2, 4.6, 4.6),
             (12.0, 4.0, 4.0), (14.0, 5.6, 5.6)], "stone_dark", None, n=8, smooth=False, cap_end=False)
    inner = 5.6
    k = 0
    for ti, (z0, z1, r) in enumerate(tiers):
        # Each terrace: a chamfered underside, a pale band at its rim, a dark body.
        m.stack([(z0, r - 2.2, r - 2.2), (z0 + 1.2, r, r)], "stone_dark", None, n=16, smooth=False, cap_end=False)
        m.stack([(z0 + 1.2, r + 0.2, r + 0.2), (z0 + 2.1, r + 0.2, r + 0.2)], "stone", None, n=16, smooth=False)
        m.stack([(z0 + 2.1, r - 0.5, r - 0.5), (z1, r - 0.5, r - 0.5)], "stone_dark", None, n=16, smooth=False, cap_start=False,
                cap_end=(ti == len(tiers) - 1))
        # Towers hang from the belly of each terrace, between the one below and its own rim.
        count = [7, 12, 17, 22][ti]
        for i in range(count):
            k += 1
            ang = 2 * math.pi * (i + 0.5 * (ti % 2)) / count + (_rand(k, 1) - 0.5) * 0.3
            rad = inner + 1.8 + (r - 4.6 - inner - 1.8) * (0.25 + 0.75 * _rand(k, 2))
            cx, cy = math.sin(ang) * rad, math.cos(ang) * rad
            w = 0.9 + 1.5 * _rand(k, 3)
            length = (4.0 + 5.0 * ti * 0.55) * (0.55 + 0.9 * _rand(k, 4))
            top = z0 + 0.9
            sides = 4 if _rand(k, 5) > 0.35 else 6
            m.stack([(top - length, 0.05, 0.05, cx, cy), (top - length * 0.80, w * 0.50, w * 0.50, cx, cy),
                     (top - length * 0.76, w * 0.78, w * 0.78, cx, cy), (top - length * 0.72, w * 0.58, w * 0.58, cx, cy),
                     (top - 0.9, w * 0.92, w * 0.92, cx, cy), (top - 0.5, w * 1.25, w * 1.25, cx, cy), (top, w * 1.25, w * 1.25, cx, cy)],
                    "stone" if _rand(k, 6) > 0.42 else "stone_dark", None, n=sides, smooth=False, cap_end=False)
        inner = r
    # The Court's mark on the belly of the first terrace, around the keel: it looks down on the Hall.
    _meridian(m, (0, 0, 13.92), 11.0, normal=(0, 0, -1), n=40)
    # The city on top: all that shows of it from below is a broken skyline.
    for i in range(16):
        ang = 2 * math.pi * i / 16 + 0.2
        rad = 30 + 26 * _rand(i, 9)
        h = 5 + 12 * _rand(i, 10)
        m.box((math.sin(ang) * rad, math.cos(ang) * rad, 44 + h / 2), (4 + 5 * _rand(i, 11), 4 + 5 * _rand(i, 12), h),
              "stone_dark", None, rot=(ang, 'Z'), taper=0.7)
    # Chains from the rims, holding nothing.
    for i, (ti, ang, length) in enumerate([(1, 0.5, 22), (1, 3.9, 16), (2, 1.7, 30), (2, 2.9, 19), (2, 5.2, 26), (3, 0.1, 21), (3, 4.4, 33)]):
        z0, z1, r = tiers[ti]
        cx, cy = math.sin(ang) * (r - 1.4), math.cos(ang) * (r - 1.4)
        n = int(length / 1.55)
        for j in range(n):
            turn = Matrix.Rotation(ang + (math.pi / 2 if j % 2 else 0.0), 4, 'Z')
            last = j == n - 1
            if last:                                                    # the last link hangs open
                turn = turn @ Matrix.Rotation(0.6, 4, 'X')
            m.box((cx, cy + (0.35 if last else 0.0), z0 + 1.0 - 1.55 * j - 0.9), (1.05, 0.30, 2.05), "verdigris", None, rot=turn)
            m.box((cx, cy + (0.35 if last else 0.0), z0 + 1.0 - 1.55 * j - 0.9), (0.52, 0.34, 1.30), "stone_dark", None, rot=turn)
    return [m.build()], m


def oath_hall_ruin():
    """Where the Oath Hall stood, seen from the square: the two ends of its
    front still up and stepped like a torn page, its doorway with the lintel
    down across it, the stumps of its porch and the drums of its columns
    lying where they fell, and across the gap the Court's answer: a flat
    black bar on two sealed posts. Its front runs along X, eighteen metres;
    the square is toward -Y."""
    m = _fresh("OathHallRuin")
    # The standing ends.
    for sx, steps in ((-1, [(9.0, 7.5, 9.6), (7.5, 6.5, 6.9), (6.5, 5.9, 4.3)]), (1, [(9.0, 7.7, 10.6), (7.7, 6.8, 8.1), (6.8, 6.0, 5.2)])):
        for i, (xa, xb, h) in enumerate(steps):
            m.box((sx * (xa + xb) / 2, 0.75, h / 2), (xa - xb, 1.5, h), "stone", None)
            m.box((sx * (xa + xb) / 2, 0.75, h + 0.12), (xa - xb + 0.1, 1.4, 0.3), "stone_dark", None, rot=((_rand(i, sx + 3) - 0.5) * 0.25, 'Y'))
        m.box((sx * 8.25, -0.08, 0.3), (1.5, 0.16, 0.6), "stone_dark", None)                       # what is left of a plinth course
        m.box((sx * 8.25, -0.02, 4.0), (1.5, 0.05, 0.25), "stone_dark", None)                      # and of the string course
    # Low broken wall between the ends and the door.
    k = 0
    for sx in (-1, 1):
        x = 5.9
        while x > 3.3:
            k += 1
            w = 0.6 + 0.7 * _rand(k, 1)
            h = 0.7 + 2.2 * _rand(k, 2) * (0.5 + 0.5 * (x - 3.3) / 2.6)
            m.box((sx * (x - w / 2), 0.75, h / 2), (w, 1.5, h), "stone", None, rot=((_rand(k, 3) - 0.5) * 0.12, 'Z'))
            x -= w
    # The doorway: one jamb whole, one broken, the lintel down across it.
    m.box((-2.9, 0.6, 3.3), (1.1, 1.7, 6.6), "stone_dark", None)
    m.box((2.9, 0.6, 1.9), (1.1, 1.7, 3.8), "stone_dark", None)
    m.box((2.75, 0.5, 4.0), (1.1, 1.6, 0.7), "stone_dark", None, rot=(0.35, 'Y'))
    lintel = Matrix.Rotation(-0.62, 4, 'Y') @ Matrix.Rotation(0.18, 4, 'Z')
    m.box((0.2, -0.5, 3.75), (8.4, 1.3, 1.2), "stone", None, rot=lintel)
    m.box((0.2, -0.5, 3.75), (8.5, 1.36, 0.22), "gold", None, rot=lintel)                         # the band that said whose hall it was
    # The porch: four columns stood three metres out. Stumps, and drums where they fell.
    for i, (x, h) in enumerate(((-6.0, 1.5), (-2.0, 3.4), (2.0, 0.9), (6.0, 2.3))):
        m.box((x, -3.2, 0.2), (1.9, 1.9, 0.4), "stone_dark", None)
        m.stack([(0.4, 0.86, 0.86, x, -3.2), (0.6, 0.74, 0.74, x, -3.2), (h, 0.70, 0.70, x, -3.2)], "stone", None, n=14)
        jag = lambda ang, li, s=i: 1.0 if li == 0 else 0.45 + 0.5 * abs(math.sin(2.3 * ang + s))
        m.stack([(h, 0.70, 0.70, x, -3.2), (h + 0.5, 0.60, 0.60, x, -3.2)], "stone", None, n=14, smooth=False, shape=jag,
                zfun=lambda ang, li, s=i: 0.0 if li == 0 else 0.25 * math.sin(3 * ang + s))
        y = -4.9 - 0.4 * _rand(i, 7)
        for d in range(2 + (i % 2)):
            skew = (_rand(i * 5 + d, 8) - 0.5) * 0.9
            a = Vector((x + skew * 0.6 + d * (0.25 if i % 2 else -0.3), y, 0.70))
            b = a + Vector((math.sin(skew) * 1.5, -math.cos(skew) * 1.5, 0.0))
            m.tube([a, b], [(0.70, 0.70), (0.68, 0.68)], "stone", None, n=14, up=(0, 0, 1))
            y -= 1.9 + 0.5 * _rand(i * 5 + d, 9)
        if i in (1, 3):                                                                           # a capital, on its side
            m.box((x + 0.5, y - 0.4, 0.55), (2.0, 0.42, 2.0), "stone_dark", None, rot=Matrix.Rotation(1.35, 4, 'X') @ Matrix.Rotation(0.3, 4, 'Z'))
    # Smaller stone, thrown outward.
    for i in range(18):
        w, d, h = 0.4 + 0.9 * _rand(i, 21), 0.4 + 0.8 * _rand(i, 22), 0.25 + 0.5 * _rand(i, 23)
        x, y = -7.5 + 15.0 * _rand(i, 24), -0.9 - 5.5 * _rand(i, 25) ** 1.6
        rot = Matrix.Rotation(_rand(i, 26) * 6.28, 4, 'Z') @ Matrix.Rotation((_rand(i, 27) - 0.5) * 0.8, 4, 'X')
        m.box((x, y, h * 0.42), (w, d, h), "stone" if i % 3 else "stone_dark", None, rot=rot)
    # Behind the front: the roof came down in slabs, and the back wall still stands, in the dark.
    for i, (x, tilt, lean) in enumerate(((-4.5, 0.62, 0.15), (0.8, 0.48, -0.2), (5.2, 0.75, 0.1))):
        m.box((x, 5.2, 2.6), (5.4, 8.6, 0.55), "stone_dark", None, rot=Matrix.Rotation(tilt, 4, 'X') @ Matrix.Rotation(lean, 4, 'Y'))
    for i, (xa, xb, h) in enumerate(((-9.0, -5.5, 11.5), (-5.5, -1.5, 8.2), (-1.5, 2.5, 12.6), (2.5, 6.0, 7.0), (6.0, 9.0, 10.2))):
        m.box(((xa + xb) / 2, 11.0, h / 2), (xb - xa, 1.6, h), "ink_soft", None)
    for sx in (-1, 1):
        m.box((sx * 9.6, 5.6, 4.2), (1.3, 11.5, 8.4 + sx * 1.5), "ink_soft", None)
    # The Court's answer: a bar struck across the gap, on two posts, sealed at both ends.
    for sx in (-1, 1):
        m.tube([(sx * 8.9, -0.75, 0.0), (sx * 8.9, -0.75, 7.6)], [(0.11, 0.11), (0.09, 0.09)], "verdigris", None, n=8)
        m.stack([(0.0, 0.34, 0.34, sx * 8.9, -0.75), (0.25, 0.30, 0.30, sx * 8.9, -0.75), (0.34, 0.14, 0.14, sx * 8.9, -0.75)], "stone_dark", None, n=8, smooth=False)
        m.stack([(7.6, 0.16, 0.16, sx * 8.9, -0.75), (7.9, 0.02, 0.02, sx * 8.9, -0.75)], "bronze", None, n=6, smooth=False)
        m.disc((sx * 8.9, -0.93, 6.0), (0, -1, 0), 0.34, 0.07, "vermilion", None, n=20)
        m.strip([(sx * 8.9 - 0.1, -0.95, 5.75), (sx * 8.9 - 0.16, -0.99, 5.2), (sx * 8.9 - 0.2, -0.96, 4.5)], (1, 0, 0), 0.16, 0.012, "vermilion", None)
    m.box((0, -0.80, 6.0), (17.6, 0.10, 1.7), "struck", None)
    return [m.build()], m


ALL = ["vow_stone", "lectern", "stall", "shelf", "statue", "plinth_struck", "rubble", "lamp", "banner", "gate", "door", "desk", "hanging_courts", "oath_hall_ruin"]
