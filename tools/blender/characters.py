"""VOWFALL's figures, modelled from scratch. Run through build.py.

Each function returns (armature, [mesh objects]). The look follows
docs/08_art_direction.md: long verticals, cut cloth, no plate armour, rank
shown by seals; gold only on what carries law.
"""
import math
from mathutils import Vector
import rig
import kit
import figure


def _arc(cx, cy, z, rx, ry, a0, a1, n):
    """Points on an ellipse round the body; angle 0 is the front, in degrees."""
    out = []
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        out.append(Vector((cx + math.sin(a) * rx, cy - math.cos(a) * ry, z)))
    return out


def _outward(points, cx, cy, lift=1.0, flare=0.3):
    """For a standing collar: up, leaning away from the neck."""
    out = []
    for p in points:
        o = Vector((p.x - cx, p.y - cy, 0))
        o = o.normalized() if o.length > 1e-6 else Vector((0, -1, 0))
        out.append((Vector((0, 0, lift)) + o * flare).normalized())
    return out


def witness():
    """The Witness. A long ink coat with an uneven hem, a high open collar,
    one arm in a full sleeve and the Instrument arm bound in cord."""
    arm = rig.load()
    R = rig.rest(arm)
    m = kit.Model("Witness", R)
    figure.legs(m, R, "ink_soft", "leather", from_knee=True)
    figure.torso(m, R, "vellum")
    figure.neck(m, "skin_a")
    figure.head(m, "skin_a", hair="swept")

    body = ["hips", "spine", "chest"]
    skirt = ["hips", "upperleg.l", "upperleg.r", "lowerleg.l", "lowerleg.r"]
    m.stack([(0.96, 0.186, 0.142), (1.10, 0.150, 0.112), (1.26, 0.160, 0.118), (1.40, 0.182, 0.126),
             (1.48, 0.186, 0.116), (1.535, 0.125, 0.092)], "ink", body, n=20, cap_start=False)

    def hem(ang, li):
        t = (li / 4.0) ** 1.5
        return -(0.17 * max(0.0, math.sin(ang)) + 0.11 * (1 - math.cos(ang)) / 2) * t

    m.stack([(0.96, 0.186, 0.142), (0.84, 0.212, 0.166), (0.70, 0.240, 0.194), (0.56, 0.268, 0.222),
             (0.45, 0.292, 0.246)], "ink", figure.skirt_skin(0.96), n=20, zfun=hem, cap_start=False)
    m.stack([(1.078, 0.155, 0.117), (1.128, 0.155, 0.117)], "leather", ["spine", "hips"], n=20)
    # The coat closes on a diagonal: a pale edge from the right shoulder to the left hip.
    m.strip([(-0.055, -0.108, 1.50), (0.01, -0.130, 1.39), (0.06, -0.121, 1.25), (0.095, -0.117, 1.11),
             (0.125, -0.148, 0.96), (0.150, -0.196, 0.72), (0.170, -0.236, 0.50)],
            (1, 0, 0), 0.028, 0.014, "vellum", ["chest", "spine", "hips", "upperleg.l"])
    # A short mantle hides the shoulders, so sleeves can turn under it.
    m.stack([(1.555, 0.078, 0.072), (1.522, 0.150, 0.110), (1.462, 0.236, 0.146), (1.405, 0.256, 0.156)],
            "ink_soft", "chest", n=20)
    ring = _arc(0, 0.012, 1.615, 0.090, 0.094, 38, 322, 18)
    m.strip(ring, _outward(ring, 0, 0.012, 1.0, 0.36), 0.165, 0.014, "ink", "chest")
    m.disc((0, -0.118, 1.492), (0, -1, 0), 0.030, 0.014, "lead", "chest")
    m.strip(_arc(0, 0.008, 1.545, 0.098, 0.100, 0, 360, 20)[:-1], (0, 0, 1), 0.016, 0.014, "cord", "chest", loop=True)

    # Left arm: a full sleeve, widening to the cuff. Right arm: bound.
    figure.arm(m, R, ".l", [(0.070, 0.070), (0.070, 0.072), (0.072, 0.076), (0.086, 0.092), (0.104, 0.112)], "ink")
    figure.hand(m, R, ".l", "skin_a")
    figure.arm(m, R, ".r", [(0.060, 0.060), (0.054, 0.054), (0.048, 0.048), (0.043, 0.043), (0.037, 0.037)], "ink_soft")
    el, wr = R["lowerarm.r"]
    for i in range(7):
        p = el.lerp(wr, 0.12 + 0.125 * i)
        d = (wr - el).normalized()
        r = 0.052 - 0.0018 * i
        m.tube([p - d * 0.011, p + d * 0.011], [(r, r), (r, r)], "cord", "lowerarm.r", n=10, up=(0, 1, 0))
    figure.hand(m, R, ".r", "leather")

    # What a Witness has witnessed hangs at the right hip: sealed strips of vellum.
    for i, (dx, length) in enumerate(((-0.150, 0.34), (-0.122, 0.27), (-0.176, 0.22))):
        y0 = -0.085 + 0.045 * i
        m.strip([(dx, y0 - 0.035, 1.090), (dx - 0.012, y0 - 0.060, 0.98), (dx - 0.020, y0 - 0.085, 1.09 - length)],
                (0, 1, 0), 0.034, 0.008, "vellum", ["hips", "upperleg.r"])
        m.disc((dx - 0.022, y0 - 0.087, 1.105 - length), (1, 0, 0), 0.015, 0.010, "vermilion", ["hips", "upperleg.r"])
    # At the left hip: a scabbard, and the hilt of a blade that is not there.
    m.tube([Vector((0.175, -0.035, 1.03)), Vector((0.215, 0.20, 0.60))], [(0.024, 0.030), (0.014, 0.018)], "leather", "hips", n=8)
    m.tube([Vector((0.168, -0.085, 1.115)), Vector((0.175, -0.035, 1.03))], [(0.015, 0.015), (0.016, 0.016)], "cord", "hips", n=8)
    m.box((0.176, -0.036, 1.033), (0.070, 0.022, 0.016), "gold", "hips", rot=(math.radians(28), 'X'))
    m.ball((0.166, -0.094, 1.130), (0.020, 0.020, 0.020), "gold", "hips", n=8, m=6)
    return arm, [m.build(arm)], m


def bailiff():
    """A Court Bailiff: tall, broad and faceless. A pale surcoat to the
    ankle, an ink stole with lead seals, a closed helm with one slit."""
    arm = rig.load()
    R = rig.rest(arm)
    m = kit.Model("Bailiff", R)
    figure.legs(m, R, "ink_soft", "leather", from_knee=True)
    figure.torso(m, R, "wool")
    body = ["hips", "spine", "chest"]
    skirt = ["hips", "upperleg.l", "upperleg.r", "lowerleg.l", "lowerleg.r"]
    m.stack([(0.98, 0.216, 0.166), (1.12, 0.190, 0.140), (1.30, 0.200, 0.146), (1.42, 0.214, 0.150),
             (1.50, 0.214, 0.130), (1.545, 0.130, 0.100)], "vellum", body, n=20, cap_start=False)
    m.stack([(0.98, 0.216, 0.166), (0.76, 0.250, 0.200), (0.52, 0.284, 0.234), (0.28, 0.308, 0.258),
             (0.10, 0.322, 0.272)], "vellum", figure.skirt_skin(0.98), n=20, cap_start=False)
    m.stack([(0.125, 0.325, 0.275), (0.095, 0.325, 0.275)], "ink", figure.skirt_skin(0.98), n=20, cap_start=False, cap_end=False)
    robe = figure.skirt_skin(0.98)

    def hang(p):
        # A stole lies on the robe: on the body above the waist, with the skirt below.
        if p.z >= 1.0:
            return m._weights_for(p, ["chest", "spine", "hips"])
        return robe(p)

    m.strip([(0, -0.142, 1.50), (0, -0.160, 1.41), (0, -0.152, 1.12), (0, -0.178, 0.98), (0, -0.214, 0.76),
             (0, -0.250, 0.52), (0, -0.272, 0.34)], (1, 0, 0), 0.170, 0.020, "ink", hang)
    m.strip([(0, 0.142, 1.50), (0, 0.160, 1.41), (0, 0.152, 1.12), (0, 0.178, 0.98), (0, 0.214, 0.76),
             (0, 0.250, 0.52), (0, 0.268, 0.40)], (1, 0, 0), 0.170, 0.020, "ink", hang)
    for sx in (-1, 1):
        m.disc((sx * 0.048, -0.290, 0.385), (0, -1, 0), 0.030, 0.016, "lead", robe)
    # The meridian: a line through a circle, in gold, on the chest.
    centre = Vector((0, -0.176, 1.285))
    circle = [centre + Vector((math.sin(a) * 0.052, 0, math.cos(a) * 0.052)) for a in
              [2 * math.pi * i / 18 for i in range(18)]]
    m.strip(circle, (0, -1, 0), 0.012, 0.012, "gold", "spine", loop=True)
    m.box(centre, (0.011, 0.012, 0.170), "gold", "spine")
    # A yoke and squared shoulders: the silhouette is a block.
    m.stack([(1.560, 0.082, 0.076), (1.530, 0.160, 0.120), (1.475, 0.246, 0.152), (1.440, 0.252, 0.156)], "ink", "chest", n=20)
    for sx in (-1, 1):
        m.box((sx * 0.245, 0.0, 1.492), (0.170, 0.210, 0.072), "ink", "chest", rot=(math.radians(-9 * sx), 'Y'))
    for s in (".l", ".r"):
        figure.arm(m, R, s, [(0.078, 0.078), (0.078, 0.080), (0.080, 0.084), (0.088, 0.094), (0.096, 0.104)], "vellum", to_wrist=0.62)
        el, wr = R["lowerarm" + s]
        m.tube([el.lerp(wr, 0.46), el.lerp(wr, 0.56), wr], [(0.074, 0.078), (0.066, 0.070), (0.050, 0.054)], "lead", "lowerarm" + s, n=10, up=(0, 1, 0))
        figure.hand(m, R, s, "lead")
    # The helm: closed, with one vertical slit and a fin from brow to nape.
    m.tube([Vector((0, 0.012, 1.52)), Vector((0, 0.004, 1.62))], [(0.062, 0.064), (0.070, 0.074)], "ink", ["chest", "head"], n=12, up=(0, 1, 0))
    m.stack([(1.595, 0.086, 0.094), (1.660, 0.106, 0.114), (1.800, 0.108, 0.116), (1.895, 0.098, 0.106),
             (1.955, 0.066, 0.072), (1.982, 0.018, 0.020)], "lead", "head", n=20)
    m.box((0, -0.115, 1.775), (0.013, 0.012, 0.215), "eye", "head")
    m.stack([(1.842, 0.110, 0.118), (1.872, 0.108, 0.116)], "gold", "head", n=20)
    m.slab([(0, -0.098, 1.920), (0, -0.030, 2.075), (0, 0.090, 2.030), (0, 0.118, 1.900), (0, 0.060, 1.930)],
           0.014, "ink", "head", normal=(1, 0, 0))
    return arm, [m.build(arm)], m


def ward():
    """A Ward of the Court: slight, hooded, a knife and nothing else."""
    arm = rig.load()
    R = rig.rest(arm)
    m = kit.Model("Ward", R)
    figure.legs(m, R, "ink_soft", "leather", thigh=0.84)
    figure.torso(m, R, "undyed")
    figure.neck(m, "skin_c")
    figure.head(m, "skin_c", hair=None, ears=False)
    body = ["hips", "spine", "chest"]
    m.stack([(0.94, 0.176, 0.132), (1.10, 0.142, 0.104), (1.30, 0.150, 0.108), (1.44, 0.170, 0.113),
             (1.52, 0.120, 0.090)], "undyed", body, n=18, cap_start=False)
    m.stack([(0.94, 0.176, 0.132), (0.86, 0.212, 0.160), (0.76, 0.232, 0.180), (0.64, 0.246, 0.194)], "undyed",
            figure.skirt_skin(0.94, soft=0.12, follow=0.85), n=18, cap_start=False)
    m.strip(_arc(0, 0, 1.090, 0.146, 0.108, 0, 360, 20)[:-1], (0, 0, 1), 0.030, 0.014, "cord", ["spine", "hips"], loop=True)
    def point(ang, li):
        return -0.16 * max(0.0, math.cos(ang)) ** 6 * (li / 3.0)     # the cowl comes to a point at the breast

    m.stack([(1.560, 0.086, 0.080), (1.520, 0.160, 0.120), (1.455, 0.226, 0.146), (1.400, 0.236, 0.154)], "verdigris", "chest", n=18, zfun=point)
    C = figure.HEAD_C

    def hood(d):
        if d.y < -0.42 and -0.80 < d.z < 0.52:
            return 0.76                     # the opening: tucked inside, so the face shows
        if d.y > 0.3 and d.z > 0.2:
            return 1.10                     # a peak at the back
        return 1.0

    m.ball(C + Vector((0, 0.016, 0.006)), (0.102, 0.122, 0.140), "verdigris", "head", n=20, m=14, shape=hood)
    # The hood's long tail, down the back.
    m.tube([C + Vector((0, 0.118, 0.090)), C + Vector((0, 0.170, 0.020)), Vector((0.02, 0.150, 1.50)), Vector((0.035, 0.160, 1.26))],
           [(0.050, 0.050), (0.034, 0.034), (0.022, 0.022), (0.010, 0.010)], "verdigris", ["head", "chest", "spine"], n=8, up=(1, 0, 0))
    for s in (".l", ".r"):
        figure.arm(m, R, s, [(0.058, 0.058), (0.052, 0.052), (0.047, 0.047), (0.042, 0.042), (0.037, 0.037)], "undyed")
        figure.hand(m, R, s, "skin_c")
    return arm, [m.build(arm)], m


def clerk():
    """A Court Clerk: narrow, robed to the ankle, white bands at the throat."""
    arm = rig.load()
    R = rig.rest(arm)
    m = kit.Model("Clerk", R)
    figure.legs(m, R, "ink_soft", "leather", from_knee=True)
    figure.torso(m, R, "ink")
    figure.neck(m, "skin_c")
    figure.head(m, "skin_c", nose=1.45, jaw=1.2, hair="skullcap", hair_mat="ink")
    body = ["hips", "spine", "chest"]
    skirt = ["hips", "upperleg.l", "upperleg.r", "lowerleg.l", "lowerleg.r"]
    m.stack([(0.98, 0.172, 0.136), (1.12, 0.146, 0.110), (1.30, 0.150, 0.110), (1.42, 0.166, 0.113),
             (1.50, 0.166, 0.102), (1.545, 0.110, 0.086)], "ink", body, n=18, cap_start=False)
    m.stack([(0.98, 0.172, 0.136), (0.70, 0.192, 0.160), (0.40, 0.208, 0.180), (0.12, 0.222, 0.196)],
            "ink", figure.skirt_skin(0.98), n=18, cap_start=False)
    m.stack([(1.540, 0.070, 0.068), (1.580, 0.068, 0.066)], "white", "chest", n=14)
    for sx in (-1, 1):
        m.box((sx * 0.023, -0.116, 1.462), (0.038, 0.010, 0.120), "white", "chest", rot=(math.radians(4 * sx), 'Y'))
    for s in (".l", ".r"):
        figure.arm(m, R, s, [(0.064, 0.064), (0.064, 0.066), (0.068, 0.072), (0.082, 0.090), (0.098, 0.108)], "ink")
        figure.hand(m, R, s, "skin_c")
    return arm, [m.build(arm)], m


def voss():
    """Aurel Voss, the Last Arbiter. Tall, narrow, old. An ink robe to the
    floor, the pale stole of his office over it with lead seals at the hem,
    a chain with the meridian, a tall cap. No armour: he does not expect to
    need any."""
    arm = rig.load()
    R = rig.rest(arm)
    m = kit.Model("Voss", R)
    figure.legs(m, R, "ink_soft", "leather", from_knee=True)
    figure.torso(m, R, "ink")
    figure.neck(m, "skin_c")
    figure.head(m, "skin_c", nose=1.30, jaw=1.30, hair="swept", hair_mat="hair_grey")
    body = ["hips", "spine", "chest"]
    robe = figure.skirt_skin(0.98, follow=0.45)
    m.stack([(0.98, 0.170, 0.134), (1.12, 0.142, 0.108), (1.30, 0.150, 0.110), (1.42, 0.168, 0.114),
             (1.50, 0.168, 0.104), (1.545, 0.112, 0.088)], "ink", body, n=20, cap_start=False)
    m.stack([(0.98, 0.170, 0.134), (0.70, 0.202, 0.168), (0.40, 0.228, 0.194), (0.05, 0.254, 0.220)],
            "ink", robe, n=20, cap_start=False)

    def hang(p):
        if p.z >= 1.0:
            return m._weights_for(p, ["chest", "spine", "hips"])
        return robe(p)

    # The stole: broad, pale, to the floor in front and behind.
    m.strip([(0, -0.118, 1.50), (0, -0.126, 1.41), (0, -0.120, 1.12), (0, -0.146, 0.98), (0, -0.180, 0.70),
             (0, -0.206, 0.40), (0, -0.228, 0.10)], (1, 0, 0), 0.150, 0.018, "vellum", hang)
    m.strip([(0, 0.118, 1.50), (0, 0.126, 1.41), (0, 0.120, 1.12), (0, 0.146, 0.98), (0, 0.180, 0.70),
             (0, 0.206, 0.40), (0, 0.224, 0.16)], (1, 0, 0), 0.150, 0.018, "vellum", hang)
    for sx in (-1, 0, 1):
        m.disc((sx * 0.048, -0.244, 0.165), (0, -1, 0), 0.026, 0.016, "lead", robe)
    m.strip([(0, -0.130, 0.30), (0, -0.136, 0.26)], (1, 0, 0), 0.150, 0.006, "gold", robe)
    # A wide flat collar, and over it the chain of his office with the meridian.
    m.stack([(1.560, 0.084, 0.078), (1.515, 0.190, 0.130), (1.455, 0.262, 0.160), (1.430, 0.266, 0.163)], "vellum", "chest", n=20)
    chain = _arc(0, 0.0, 1.405, 0.215, 0.160, 0, 360, 24)[:-1]
    chain = [Vector((p.x, p.y, p.z - 0.10 * max(0.0, -p.y / 0.160))) for p in chain]     # it hangs lower at the breast
    m.strip(chain, (0, 0, 1), 0.016, 0.014, "gold", "chest", loop=True)
    centre = Vector((0, -0.178, 1.265))
    ring = [centre + Vector((math.sin(a) * 0.040, 0, math.cos(a) * 0.040)) for a in [2 * math.pi * i / 16 for i in range(16)]]
    m.strip(ring, (0, -1, 0), 0.010, 0.010, "gold", "chest", loop=True)
    m.box(centre, (0.010, 0.010, 0.120), "gold", "chest")
    for s in (".l", ".r"):
        figure.arm(m, R, s, [(0.070, 0.070), (0.072, 0.074), (0.078, 0.084), (0.100, 0.112), (0.124, 0.140)], "ink")
        el, wr = R["lowerarm" + s]
        d = (wr - el).normalized()
        m.tube([wr - d * 0.035, wr - d * 0.005], [(0.126, 0.142), (0.127, 0.143)], "vellum", "lowerarm" + s, n=10, up=(0, 1, 0))
        figure.hand(m, R, s, "skin_c")
    # The cap: tall, flat-topped, banded in gold.
    C = figure.HEAD_C
    m.stack([(C.z + 0.070, 0.090, 0.106, 0, C.y + 0.012), (C.z + 0.100, 0.094, 0.110, 0, C.y + 0.012),
             (C.z + 0.250, 0.108, 0.122, 0, C.y + 0.012)], "ink", "head", n=16)
    m.stack([(C.z + 0.068, 0.093, 0.109, 0, C.y + 0.012), (C.z + 0.094, 0.096, 0.112, 0, C.y + 0.012)], "gold", "head", n=16)
    return arm, [m.build(arm)], m
