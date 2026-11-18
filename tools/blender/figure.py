"""Shared anatomy for VOWFALL's figures: legs, torso, arms, hands, heads.

Sculptural rather than anatomical: long limbs, small heads, faces reduced to
a brow, a nose and two dark slits, like carved stage figures. Costume is
layered on top of this in characters.py.
"""
import math
from mathutils import Vector

HEAD_C = Vector((0.0, -0.004, 1.735))


def skirt_skin(top, soft=0.20, knee=0.53, follow=0.5):
    """How a robe's skirt follows the body. At its top it belongs to the
    hips; below that each side goes part of the way with its own thigh, and
    below the knee with its own shin. follow=1 is cloth glued to the leg (it
    flaps up like a board on a high step); follow=0.5 lets the hem hang."""
    def step(x, a, b):
        t = max(0.0, min(1.0, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)

    def skin(p):
        down = step(top - p.z, 0.0, soft)
        left = step(p.x, -0.07, 0.07)
        shin = step(knee - p.z, -0.06, 0.16)
        w = {"hips": 1.0 - down * follow}
        for side, share in ((".l", left), (".r", 1.0 - left)):
            w["upperleg" + side] = down * follow * share * (1.0 - shin * 0.6)
            w["lowerleg" + side] = down * follow * share * shin * 0.6
        return {k: v for k, v in w.items() if v > 0.01}
    return skin


def legs(m, R, trousers="ink_soft", boots="leather", from_knee=False, thigh=1.0):
    """from_knee: under a long robe the thighs are never seen, so they are
    not made: nothing to poke through the cloth."""
    for s in (".l", ".r"):
        hip, knee = R["upperleg" + s]
        ankle = R["lowerleg" + s][1]
        if from_knee:
            m.tube([knee + Vector((0, 0, 0.05)), knee, (knee + ankle) / 2, ankle],
                   [(0.058, 0.062), (0.060, 0.064), (0.058, 0.064), (0.048, 0.050)],
                   trousers, "lowerleg" + s, n=10, up=(0, 1, 0))
        else:
            m.tube([hip + Vector((0, 0, 0.04)), (hip + knee) / 2, knee, (knee + ankle) / 2, ankle],
                   [(0.094 * thigh, 0.098 * thigh), (0.080 * thigh, 0.084 * thigh), (0.062, 0.066), (0.060, 0.066), (0.048, 0.050)],
                   trousers, ["upperleg" + s, "lowerleg" + s], n=10, up=(0, 1, 0))
        # A tall boot: shaft on the shin, the rest moving with the foot.
        shin = knee.lerp(ankle, 0.45)
        m.tube([shin, ankle + Vector((0, 0, 0.02))], [(0.064, 0.070), (0.052, 0.056)], boots, "lowerleg" + s, n=10, up=(0, 1, 0))
        m.tube([ankle + Vector((0, 0, 0.03)), Vector((ankle.x, ankle.y + 0.005, 0.070))],
               [(0.050, 0.056), (0.044, 0.056)], boots, "foot" + s, n=10, up=(0, 1, 0))
        m.tube([Vector((ankle.x, ankle.y + 0.062, 0.046)), Vector((ankle.x, ankle.y - 0.04, 0.050)),
                Vector((ankle.x, ankle.y - 0.15, 0.038)), Vector((ankle.x, ankle.y - 0.225, 0.022))],
               [(0.038, 0.045), (0.044, 0.048), (0.040, 0.036), (0.020, 0.018)], boots, "foot" + s, n=10)


def torso(m, R, mat="vellum"):
    m.stack([(0.90, 0.150, 0.105), (0.98, 0.158, 0.112), (1.10, 0.128, 0.092), (1.24, 0.140, 0.100),
             (1.38, 0.166, 0.110), (1.47, 0.176, 0.106), (1.53, 0.118, 0.084), (1.565, 0.060, 0.058)],
            mat, ["hips", "spine", "chest"], n=16)


def arm(m, R, s, radii, mat, n=10, to_wrist=1.0):
    """A sleeve from shoulder toward the wrist. radii: five (r, r) pairs."""
    sh, el = R["upperarm" + s]
    wr = R["lowerarm" + s][1]
    end = el.lerp(wr, to_wrist)
    m.tube([sh, (sh + el) / 2, el, (el + end) / 2, end], radii, mat,
           ["upperarm" + s, "lowerarm" + s], n=n, up=(0, 1, 0))


def hand(m, R, s, mat):
    wr = R["lowerarm" + s][1]
    h0, h1 = R["hand" + s]
    d = (h1 - h0).normalized()
    m.tube([wr - d * 0.02, h0, h1, h1 + d * 0.058, h1 + d * 0.076],
           [(0.026, 0.030), (0.022, 0.040), (0.021, 0.045), (0.017, 0.040), (0.010, 0.026)], mat, "hand" + s, n=8, up=(0, 1, 0))
    t0 = h0 + Vector((0, -0.034, 0)) + d * 0.02
    m.tube([t0, t0 + d * 0.05 + Vector((0, -0.022, 0))], [(0.013, 0.013), (0.009, 0.009)], mat, "hand" + s, n=6, up=(0, 1, 0))


def neck(m, mat):
    m.tube([Vector((0, 0.012, 1.52)), Vector((0, 0.004, 1.65))], [(0.050, 0.052), (0.046, 0.050)], mat, ["chest", "head"], n=10, up=(0, 1, 0))


def head(m, mat, nose=1.0, jaw=1.0, hair=None, hair_mat="hair_dark", ears=True, mouth=True):
    """A carved head: jaw, brow, nose, two slits. Rigid on the head bone."""
    C = HEAD_C

    def skull(d):
        k = 1.0
        if d.z < 0:
            k -= 0.30 * jaw * (-d.z) ** 1.3 * (1.0 if d.y < 0.2 else 0.55)
            if d.y < -0.3:
                k += 0.11 * (-d.z) * (-d.y)        # the chin comes forward
        if d.y > 0.2:
            k += 0.07 * d.y                        # fuller at the back
        if d.y < -0.6 and abs(d.z) < 0.5:
            k -= 0.035                             # a flatter face plane
        return k

    m.ball(C, (0.078, 0.096, 0.118), mat, "head", n=20, m=14, shape=skull)
    face_y = C.y - 0.090
    # The nose: a narrow wedge, widest at the base, running into the brow.
    top = Vector((0, face_y - 0.004, C.z + 0.030))
    tip = Vector((0, face_y - 0.030, C.z - 0.034 * nose))
    base = C.z - 0.044 * nose
    m.loft([[top + Vector((-0.006, 0, 0)), top + Vector((0.006, 0, 0)), top + Vector((0, 0.012, 0))],
            [Vector((-0.014, face_y + 0.004, base)), Vector((0.014, face_y + 0.004, base)), tip]],
           mat, "head", smooth=False)
    # One brow, following the face, casting the shadow the eyes sit in.
    brow = []
    for i in range(9):
        a = math.radians(-58 + 14.5 * i)
        dip = 0.006 * (1 - abs(i - 4) / 4.0)
        brow.append(Vector((math.sin(a) * 0.080, C.y - math.cos(a) * 0.097, C.z + 0.036 - dip)))
    m.strip(brow, (0, 0, 1), 0.014, 0.012, mat, "head")
    for sx in (-1, 1):
        m.box((sx * 0.032, face_y + 0.0005, C.z + 0.019), (0.032, 0.012, 0.006), "eye", "head",
              rot=(math.radians(-12 * sx), 'Z'))
        if ears:
            m.ball((sx * 0.079, C.y + 0.012, C.z - 0.004), (0.011, 0.020, 0.028), mat, "head", n=8, m=6)
    if mouth:
        m.box((0, face_y + 0.004, C.z - 0.062), (0.036, 0.010, 0.004), "eye", "head")
    if hair == "swept":
        def cap(d):
            if d.y < -0.25 and d.z < 0.50:
                return 0.80                        # tucked inside the face: hidden
            if d.y > 0.3 and d.z < -0.2:
                return 1.10                        # length at the nape
            return 1.0
        m.ball(C + Vector((0, 0.010, 0.012)), (0.086, 0.106, 0.126), hair_mat, "head", n=18, m=12, shape=cap)
        m.ball(C + Vector((0, 0.118, -0.045)), (0.030, 0.034, 0.040), hair_mat, "head", n=8, m=6)
    elif hair == "skullcap":
        def cap(d):
            return 1.0 if d.z > 0.22 else 0.82
        m.ball(C + Vector((0, 0.006, 0.010)), (0.084, 0.103, 0.124), hair_mat, "head", n=18, m=12, shape=cap)
