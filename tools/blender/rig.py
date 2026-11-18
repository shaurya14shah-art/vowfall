"""The VOWFALL body: a tall rig that keeps a CC0 pack's motion.

The only thing reused from the KayKit pack (CC0, Kay Lousberg) is MOTION: its
skeleton's bone names and its 76 animation clips. No mesh, texture or
proportion of that pack survives. The skeleton is re-proportioned here from a
1.5 m toy figure to a 1.86 m one, and every model is built from scratch on
top of it (see kit.py and the build_*.py scripts).

Why it works: a clip stores each bone's rotation relative to its rest pose.
Lengthening a bone without turning it leaves every rotation valid. Legs are
scaled uniformly (front-back and up-down by the same factor), and so is the
hips' travel, so the triangles hip-knee-ankle stay similar and feet meet the
floor exactly where they did.
"""
import math
import os
import bpy
from mathutils import Vector, Matrix

SOURCE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "source", "motion_source.glb")

LEG = 1.82        # legs, and the hips' travel, grow by this
LEG_X = 0.62      # hips are narrower than the toy's

LEG_BONES = ["upperleg", "lowerleg", "foot", "toes", "kneeIK", "control-toe-roll",
             "control-heel-roll", "control-foot-roll", "heelIK", "IK-foot", "IK-toe"]
# location curves on these bones travel with the legs
LEG_SCALED_LOCATION = ["hips", "root", "upperleg.l", "upperleg.r"]

# Upper body, in metres. Arms are in a T pose along X.
HIPS_TOP = 1.06
CHEST_BASE = 1.30
NECK = 1.56
HEAD_BASE = 1.585
HEAD_LEN = 0.27
SHOULDER = Vector((0.185, 0.0, 1.475))
UPPER_ARM = 0.30
FOREARM = 0.265
WRIST = 0.05
HAND = 0.10
ARM_DROP = math.radians(27)   # how far each arm is turned down from the T pose


def fcurves(action):
    try:
        return list(action.fcurves)
    except Exception:
        out = []
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    out += list(bag.fcurves)
        return out


def load():
    """Import the motion source, delete its meshes, return the armature."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SOURCE)
    arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
    for o in list(bpy.data.objects):
        if o is not arm:
            bpy.data.objects.remove(o, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.textures):
        for item in list(block):
            if item.users == 0:
                block.remove(item)
    arm.name = "Rig"
    reproportion(arm)
    return arm


def reproportion(arm):
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.data.edit_bones
    old = {b.name: (b.head.copy(), b.tail.copy()) for b in eb}

    def place(name, head, length=None):
        d = old[name][1] - old[name][0]
        keep = d.length
        d.normalize()
        eb[name].head = head
        eb[name].tail = head + d * (length if length is not None else keep)
        return eb[name].tail.copy()

    def leg(p):
        return Vector((p.x * LEG_X, p.y * LEG, p.z * LEG))

    for base in LEG_BONES:
        for side in (".l", ".r"):
            name = base + side
            eb[name].head = leg(old[name][0])
            eb[name].tail = leg(old[name][1])

    hips_head = Vector((0, 0, old["hips"][0].z * LEG))
    place("hips", hips_head, HIPS_TOP - hips_head.z)
    place("spine", Vector((0, 0, HIPS_TOP)), CHEST_BASE - HIPS_TOP)
    place("chest", Vector((0, 0, CHEST_BASE)), NECK - CHEST_BASE)
    place("head", Vector((0, 0, HEAD_BASE)), HEAD_LEN)
    for side, sx in ((".l", 1.0), (".r", -1.0)):
        shoulder = Vector((SHOULDER.x * sx, SHOULDER.y, SHOULDER.z))
        elbow = place("upperarm" + side, shoulder, UPPER_ARM)
        wrist = place("lowerarm" + side, elbow, FOREARM)
        hand = place("wrist" + side, wrist, WRIST)
        place("hand" + side, hand, HAND)
        offset = old["handslot" + side][0] - old["hand" + side][0]
        place("handslot" + side, hand + offset)
        # The toy held its arms well out from a barrel body. Turn each whole
        # arm down about its shoulder: the rest pose becomes an A-pose and
        # every clip inherits the correction.
        turn = (Matrix.Translation(shoulder) @ Matrix.Rotation(ARM_DROP * sx, 4, 'Y')
                @ Matrix.Translation(-shoulder))
        # Set each bone's whole matrix, so its roll turns with it. (EditBone
        # .transform re-derives roll and left the hand slots twisted against
        # the hands: held things sat 37 degrees off.)
        for part in ("upperarm", "lowerarm", "wrist", "hand", "handslot"):
            bone = eb[part + side]
            length = bone.length
            bone.matrix = turn @ bone.matrix
            bone.length = length
    bpy.ops.object.mode_set(mode='OBJECT')

    for action in bpy.data.actions:
        for fc in fcurves(action):
            if not fc.data_path.endswith("location"):
                continue
            bone = fc.data_path.split('"')[1]
            if bone in LEG_SCALED_LOCATION:
                for kp in fc.keyframe_points:
                    kp.co[1] *= LEG
                    kp.handle_left[1] *= LEG
                    kp.handle_right[1] *= LEG
                fc.update()


def rest(arm):
    """Bone name -> (head, tail) in rest pose, object space."""
    return {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in arm.data.bones}


def pose(arm, clip, frame):
    """Put the armature in a frame of a clip (for review renders)."""
    ad = arm.animation_data
    for track in ad.nla_tracks:
        track.mute = True
    action = bpy.data.actions[clip]
    ad.action = action
    try:
        ad.action_slot = action.slots[0]
    except Exception:
        pass
    bpy.context.scene.frame_set(int(frame))


def unpose(arm):
    ad = arm.animation_data
    ad.action = None
    for track in ad.nla_tracks:
        track.mute = False
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.context.scene.frame_set(0)


def export(arm, objects, path, animations=True):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:
        o.select_set(True)
    if arm is not None:
        arm.select_set(True)
        bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(
        filepath=path, export_format='GLB', use_selection=True,
        export_animations=animations, export_animation_mode='NLA_TRACKS',
        export_skins=True, export_yup=True, export_apply=False,
        export_materials='EXPORT', export_image_format='NONE',
    )
