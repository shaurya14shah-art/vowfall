"""A small modelling kit: everything in VOWFALL's models is made from these.

Shapes are built as plain lists (vertices, faces) with a material and bone
weights per vertex, then turned into one skinned mesh. No sculpting, no
imported geometry. Units are metres; Z is up; the figure faces -Y (which
becomes +Z in the game).
"""
import math
import bpy
from mathutils import Vector, Matrix


def srgb(r, g, b):
    """Palette values are written as seen on screen; Blender wants linear."""
    return (r ** 2.2, g ** 2.2, b ** 2.2, 1.0)


# docs/08_art_direction.md. Gold only on what carries law; vermilion only for an act.
PALETTE = {
    "ink":        (srgb(0.080, 0.090, 0.135), 0.85, 0.0),
    "ink_soft":   (srgb(0.150, 0.165, 0.220), 0.9, 0.0),
    "vellum":     (srgb(0.84, 0.80, 0.71), 0.9, 0.0),
    "wool":       (srgb(0.70, 0.66, 0.57), 0.95, 0.0),
    "undyed":     (srgb(0.52, 0.47, 0.39), 0.95, 0.0),
    "leather":    (srgb(0.20, 0.14, 0.11), 0.7, 0.0),
    "cord":       (srgb(0.62, 0.50, 0.30), 0.9, 0.0),
    "skin_a":     (srgb(0.74, 0.58, 0.47), 0.75, 0.0),
    "skin_b":     (srgb(0.52, 0.37, 0.28), 0.75, 0.0),
    "skin_c":     (srgb(0.86, 0.72, 0.62), 0.75, 0.0),
    "hair_dark":  (srgb(0.07, 0.06, 0.07), 0.6, 0.0),
    "hair_grey":  (srgb(0.55, 0.54, 0.52), 0.6, 0.0),
    "gold":       (srgb(0.83, 0.66, 0.28), 0.35, 1.0),
    "lead":       (srgb(0.42, 0.43, 0.46), 0.55, 0.8),
    "steel":      (srgb(0.62, 0.65, 0.70), 0.42, 0.85),
    "bronze":     (srgb(0.55, 0.38, 0.20), 0.45, 1.0),
    "mirror":     (srgb(0.78, 0.88, 1.00), 0.25, 0.6, 0.55),
    "vermilion":  (srgb(0.78, 0.20, 0.12), 0.6, 0.0),
    "verdigris":  (srgb(0.30, 0.47, 0.43), 0.85, 0.0),
    "stone":      (srgb(0.70, 0.67, 0.60), 0.95, 0.0),
    "stone_dark": (srgb(0.30, 0.31, 0.37), 0.95, 0.0),
    "eye":        (srgb(0.03, 0.03, 0.04), 0.3, 0.0),
    "white":      (srgb(0.92, 0.90, 0.85), 0.8, 0.0),
    "struck":     (srgb(0.03, 0.03, 0.04), 1.0, 0.0),            # never glossy, never glowing
    "lamp":       (srgb(1.00, 0.90, 0.66), 0.4, 0.0, 2.4),
}


def material(name):
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    entry = PALETTE[name]
    colour, rough, metal = entry[0], entry[1], entry[2]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = colour
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if len(entry) > 3:                      # a little light of its own
        bsdf.inputs["Emission Color"].default_value = colour
        bsdf.inputs["Emission Strength"].default_value = entry[3]
    return mat


class Model:
    """Collects shapes; build() makes one mesh object skinned to `arm`."""

    def __init__(self, name, bones=None):
        self.name = name
        self.bones = bones or {}      # rest pose: name -> (head, tail)
        self.verts = []
        self.faces = []
        self.face_mat = []
        self.face_smooth = []
        self.weights = []             # per vertex: {bone: weight}
        self.materials = []

    # ---------------------------------------------------------- weights

    def _weights_for(self, p, spec):
        """spec: a bone name (rigid), a list of bones (blend by distance),
        or a function p -> {bone: weight}."""
        if spec is None:
            return {}
        if callable(spec):
            return spec(p)
        if isinstance(spec, str):
            return {spec: 1.0}
        scored = []
        for b in spec:
            head, tail = self.bones[b]
            d = _dist_to_segment(p, head, tail)
            scored.append((1.0 / (d ** 4 + 1e-6), b))
        scored.sort(reverse=True)
        scored = scored[:3]
        total = sum(s for s, _ in scored)
        return {b: s / total for s, b in scored if s / total > 0.02}

    def _add(self, points, faces, mat, skin, smooth):
        base = len(self.verts)
        if mat not in self.materials:
            self.materials.append(mat)
        mi = self.materials.index(mat)
        for p in points:
            p = Vector(p)
            self.verts.append(p)
            self.weights.append(self._weights_for(p, skin))
        for f in faces:
            self.faces.append([base + i for i in f])
            self.face_mat.append(mi)
            self.face_smooth.append(smooth)

    # ----------------------------------------------------------- shapes

    def loft(self, rings, mat, skin, smooth=True, cap_start=True, cap_end=True, closed=True):
        """Skin a sequence of rings (each a list of n points) with quads."""
        n = len(rings[0])
        pts = [p for ring in rings for p in ring]
        faces = []
        span = n if closed else n - 1
        for r in range(len(rings) - 1):
            for i in range(span):
                a = r * n + i
                b = r * n + (i + 1) % n
                faces.append([a, b, b + n, a + n])
        if closed and cap_start:
            c = len(pts)
            pts.append(sum((Vector(p) for p in rings[0]), Vector()) / n)
            for i in range(n):
                faces.append([c, (i + 1) % n, i])
        if closed and cap_end:
            c = len(pts)
            pts.append(sum((Vector(p) for p in rings[-1]), Vector()) / n)
            off = (len(rings) - 1) * n
            for i in range(n):
                faces.append([c, off + i, off + (i + 1) % n])
        self._add(pts, faces, mat, skin, smooth)

    def stack(self, levels, mat, skin, n=16, smooth=True, cap_start=True, cap_end=True,
              shape=None, zfun=None, arc=None):
        """Horizontal ellipses stacked up Z.
        levels: (z, rx, ry[, cx, cy]). shape(angle, level) scales the radius;
        zfun(angle, level) offsets the height (an uneven hem). arc=(a0, a1)
        makes an open shell instead of a closed ring."""
        rings = []
        closed = arc is None
        for li, lv in enumerate(levels):
            z, rx, ry = lv[0], lv[1], lv[2]
            cx = lv[3] if len(lv) > 3 else 0.0
            cy = lv[4] if len(lv) > 4 else 0.0
            ring = []
            count = n if closed else n + 1
            for i in range(count):
                if closed:
                    ang = 2 * math.pi * i / n
                else:
                    ang = arc[0] + (arc[1] - arc[0]) * i / n
                k = shape(ang, li) if shape else 1.0
                dz = zfun(ang, li) if zfun else 0.0
                # angle 0 is the figure's front (-Y); it runs to the figure's left (+X)
                ring.append(Vector((cx + math.sin(ang) * rx * k, cy - math.cos(ang) * ry * k, z + dz)))
            rings.append(ring)
        self.loft(rings, mat, skin, smooth, cap_start, cap_end, closed)

    def tube(self, path, radii, mat, skin, n=10, smooth=True, cap_start=True, cap_end=True, up=(0, 0, 1)):
        """A tube along a polyline. radii: (ra, rb) per point, across `up` and along it."""
        up = Vector(up).normalized()
        rings = []
        for i, p in enumerate(path):
            p = Vector(p)
            a = Vector(path[max(i - 1, 0)])
            b = Vector(path[min(i + 1, len(path) - 1)])
            t = (b - a).normalized()
            side = t.cross(up)
            if side.length < 1e-4:
                side = t.cross(Vector((0, 1, 0)))
            side.normalize()
            v = side.cross(t).normalized()
            ra, rb = radii[i]
            rings.append([p + side * math.cos(2 * math.pi * k / n) * ra + v * math.sin(2 * math.pi * k / n) * rb
                          for k in range(n)])
        self.loft(rings, mat, skin, smooth, cap_start, cap_end)

    def strip(self, path, across, width, thickness, mat, skin, smooth=False, loop=False):
        """A ribbon with thickness: collars, stoles, belts, hems, rings.
        across: one vector, or one per point, giving the direction of its width."""
        rings = []
        count = len(path)
        for i, p in enumerate(path):
            p = Vector(p)
            if loop:
                a = Vector(path[(i - 1) % count])
                b = Vector(path[(i + 1) % count])
            else:
                a = Vector(path[max(i - 1, 0)])
                b = Vector(path[min(i + 1, count - 1)])
            t = (b - a).normalized()
            w = Vector(across[i] if isinstance(across, list) else across).normalized()
            nrm = t.cross(w).normalized()
            hw = (width[i] if isinstance(width, list) else width) / 2.0
            ht = thickness / 2.0
            rings.append([p - w * hw - nrm * ht, p + w * hw - nrm * ht, p + w * hw + nrm * ht, p - w * hw + nrm * ht])
        if loop:
            rings.append(rings[0])
            self.loft(rings, mat, skin, smooth, False, False)
        else:
            self.loft(rings, mat, skin, smooth, True, True)

    def disc(self, centre, axis, radius, thickness, mat, skin, n=14, smooth=False):
        """A coin: seals, buttons, studs."""
        c = Vector(centre)
        ax = Vector(axis).normalized()
        self.tube([c - ax * thickness / 2, c + ax * thickness / 2], [(radius, radius), (radius, radius)],
                  mat, skin, n=n, smooth=smooth, up=(0, 0, 1) if abs(ax.z) < 0.9 else (0, 1, 0))

    def box(self, centre, size, mat, skin, rot=None, smooth=False, taper=1.0):
        """A box; taper narrows the +Z end in X and Y."""
        cx, cy, cz = centre
        sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
        pts = []
        for z, k in ((-sz, 1.0), (sz, taper)):
            for x, y in ((-sx, -sy), (sx, -sy), (sx, sy), (-sx, sy)):
                pts.append(Vector((x * k, y * k, z)))
        if rot is not None:
            m = rot if isinstance(rot, Matrix) else Matrix.Rotation(rot[0], 4, rot[1])
            pts = [m @ p for p in pts]
        pts = [p + Vector(centre) for p in pts]
        faces = [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
        self._add(pts, faces, mat, skin, smooth)

    def ball(self, centre, radii, mat, skin, n=12, m=8, smooth=True, shape=None):
        """An ellipsoid. shape(direction) -> scale lets it be carved into a head."""
        c = Vector(centre)
        rings = []
        for j in range(1, m):
            lat = math.pi * j / m - math.pi / 2
            ring = []
            for i in range(n):
                lon = 2 * math.pi * i / n
                d = Vector((math.sin(lon) * math.cos(lat), -math.cos(lon) * math.cos(lat), math.sin(lat)))
                k = shape(d) if shape else 1.0
                ring.append(c + Vector((d.x * radii[0], d.y * radii[1], d.z * radii[2])) * k)
            rings.append(ring)
        self.loft(rings, mat, skin, smooth, True, True)

    def slab(self, outline, thickness, mat, skin, normal=(0, -1, 0), smooth=False):
        """A flat plate: a polygon (list of points in space, coplanar) given thickness."""
        nrm = Vector(normal).normalized() * (thickness / 2)
        front = [Vector(p) + nrm for p in outline]
        back = [Vector(p) - nrm for p in outline]
        n = len(outline)
        pts = front + back
        faces = [list(range(n)), list(range(2 * n - 1, n - 1, -1))]
        for i in range(n):
            j = (i + 1) % n
            faces.append([i, i + n, j + n, j])
        self._add(pts, faces, mat, skin, smooth)

    # ------------------------------------------------------------ build

    def build(self, arm=None):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata([tuple(v) for v in self.verts], [], self.faces)
        mesh.validate()
        for m in self.materials:
            mesh.materials.append(material(m))
        for poly, mi, sm in zip(mesh.polygons, self.face_mat, self.face_smooth):
            poly.material_index = mi
            poly.use_smooth = sm
        mesh.update()
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        # Faces were wound by hand; make every normal point outward.
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode='OBJECT')
        obj.select_set(False)
        if arm is not None:
            groups = {}
            for vi, w in enumerate(self.weights):
                for bone, weight in w.items():
                    if bone not in groups:
                        groups[bone] = obj.vertex_groups.new(name=bone)
                    groups[bone].add([vi], weight, 'REPLACE')
            mod = obj.modifiers.new("Armature", 'ARMATURE')
            mod.object = arm
            obj.parent = arm
        return obj

    def triangles(self):
        return sum(max(1, len(f) - 2) for f in self.faces)


def _dist_to_segment(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


# ------------------------------------------------------------- reviewing

def studio(width=900, height=1100):
    """A plain render set-up: pale ground, warm key, cool fill. Headless."""
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.film_transparent = False
    scene.view_settings.view_transform = 'Standard'
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.62, 0.60, 0.55, 1)
    bg.inputs[1].default_value = 0.55
    scene.world = world
    key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", 'SUN'))
    key.data.energy = 3.2
    key.data.color = (1.0, 0.95, 0.84)
    key.rotation_euler = (math.radians(52), 0, math.radians(-38))
    scene.collection.objects.link(key)
    fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", 'SUN'))
    fill.data.energy = 0.9
    fill.data.color = (0.62, 0.70, 0.90)
    fill.rotation_euler = (math.radians(60), 0, math.radians(140))
    scene.collection.objects.link(fill)
    ground = bpy.data.meshes.new("Ground")
    ground.from_pydata([(-30, -30, 0), (30, -30, 0), (30, 30, 0), (-30, 30, 0)], [], [[0, 1, 2, 3]])
    gobj = bpy.data.objects.new("Ground", ground)
    ground.materials.append(material("stone"))
    scene.collection.objects.link(gobj)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 70
    scene.collection.objects.link(cam)
    scene.camera = cam
    return cam, gobj


def look(cam, target, angle_deg, distance, height):
    """Angle 0 looks at the figure's front."""
    a = math.radians(angle_deg)
    t = Vector(target)
    cam.location = (t.x + math.sin(a) * distance, t.y - math.cos(a) * distance, height)
    direction = t - cam.location
    cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()


def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
