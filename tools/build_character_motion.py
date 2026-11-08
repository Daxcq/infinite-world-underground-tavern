"""Run with Blender 5.2 --background --python tools/build_character_motion.py.

Derive a walk cycle and seated pose from the supplied rig, then render the
four-direction sprite sheet used by the 2D player. Source GLBs stay intact.
"""
import bpy
import math
import numpy as np
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'game/assets/characters/motion'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / 'game/assets/models/adventurer 3d model (1).glb'))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
mesh = next(o for o in bpy.data.objects if o.type == 'MESH' and o.find_armature() == rig)
for obj in list(bpy.data.objects):
    if obj not in (rig, mesh):
        bpy.data.objects.remove(obj, do_unlink=True)

# A working derivative makes animation and sprite generation affordable.
bpy.context.view_layer.objects.active = mesh
mesh.select_set(True)
decimate = mesh.modifiers.new('AnimationWorkingMesh', 'DECIMATE')
decimate.ratio = 0.10
while mesh.modifiers.find(decimate.name) > 0:
    bpy.ops.object.modifier_move_up(modifier=decimate.name)
bpy.ops.object.modifier_apply(modifier=decimate.name)
print('WORKING_TRIANGLES', len(mesh.data.polygons), flush=True)

# The supplied GLB declares float weights but almost all sums are denormal
# values near zero. Rebind the working copy before authoring visible motions.
deform_names = {'Pelvis', 'Waist', 'Spine01', 'Spine02', 'Head'}
deform_names.update(side+'_'+part for side in ('L', 'R') for part in ('Thigh', 'Calf', 'Foot', 'Upperarm', 'Forearm', 'Hand'))
for bone in rig.data.bones:
    bone.use_deform = bone.name in deform_names
mesh.vertex_groups.clear()
for modifier in list(mesh.modifiers):
    if modifier.type == 'ARMATURE':
        mesh.modifiers.remove(modifier)
# Bone-heat binding fails on this generated mesh. Bind to nearby anatomical
# bone segments instead, blending four influences across joints.
vertices = np.empty(len(mesh.data.vertices)*3, dtype=np.float32)
mesh.data.vertices.foreach_get('co', vertices)
vertices = vertices.reshape(-1, 3)
deform_bones = [b for b in rig.data.bones if b.use_deform]
scores = []
for bone in deform_bones:
    head, tail = np.array(bone.head_local), np.array(bone.tail_local)
    segment = tail-head
    t = np.clip((vertices-head)@segment / max(float(segment@segment), 1e-8), 0, 1)
    distance = np.sum((vertices-head-t[:,None]*segment)**2, axis=1)
    score = 1.0/(distance+.0005)**3
    z, y = vertices[:,2], vertices[:,1]
    if bone.name.endswith('Foot'): score[z>.18] = 0
    elif bone.name.endswith('Calf'): score[z>.42] = 0
    elif bone.name.endswith('Thigh'): score[(z>.62)|(np.abs(y)>.18)] = 0
    elif bone.name == 'Head': score[z<.78] = 0
    elif bone.name in {'Waist','Spine01','Spine02'}: score[z<.40] = 0
    if bone.name.startswith('L_'): score[y<-.015] *= .001
    if bone.name.startswith('R_'): score[y>.015] *= .001
    scores.append(score)
weights = np.stack(scores, axis=1)
nearest = np.argsort(weights, axis=1)[:,-4:]
kept = np.zeros_like(weights)
np.put_along_axis(kept, nearest, np.take_along_axis(weights, nearest, axis=1), axis=1)
kept /= kept.sum(axis=1, keepdims=True)
groups = [mesh.vertex_groups.new(name=b.name) for b in deform_bones]
for vertex_index, row in enumerate(kept):
    for bone_index in nearest[vertex_index]:
        groups[bone_index].add([vertex_index], float(row[bone_index]), 'REPLACE')
modifier = mesh.modifiers.new('RepairedSkin', 'ARMATURE')
modifier.object = rig
modifier.use_deform_preserve_volume = True
unbound = sum(sum(g.weight for g in v.groups) < .01 for v in mesh.data.vertices)
print('REBIND_UNBOUND_VERTICES', unbound, 'OF', len(mesh.data.vertices), flush=True)
if unbound:
    raise RuntimeError('Automatic binding left unbound vertices')

scene = bpy.context.scene
scene.render.fps = 30
bones = rig.pose.bones


def update():
    bpy.context.view_layer.update()


def reset():
    for bone in bones:
        bone.matrix_basis.identity()
        bone.rotation_mode = 'QUATERNION'
    update()


def point(name, child, direction):
    bone = bones[name]
    current = (bones[child].head - bone.head).normalized()
    rotation = current.rotation_difference(Vector(direction).normalized()).to_matrix().to_4x4()
    head = bone.head.copy()
    bone.matrix = Matrix.Translation(head) @ rotation @ Matrix.Translation(-head) @ bone.matrix
    update()


def root_drop(amount):
    bone = bones['BoneRoot']
    matrix = bone.matrix.copy()
    matrix.translation.z += amount
    bone.matrix = matrix
    update()


def pose(kind, phase=0):
    reset()
    if kind == 'seated':
        root_drop(-0.224)
    for side, sign, offset in [('L', 1, 0), ('R', -1, math.pi)]:
        t = phase + offset
        swing = math.radians(25)*math.sin(t) if kind == 'walk' else 0
        knee = math.radians(42)*max(0, -math.sin(t)) if kind == 'walk' else 0
        if kind == 'seated':
            thigh, calf = (1, sign*.12, -.045), (.02, sign*.02, -1)
            upper, forearm = (.20, sign*.09, -1), (1, -sign*.05, .40)
        else:
            thigh = (math.sin(swing), sign*.025, -math.cos(swing))
            calf = (math.sin(swing-knee), sign*.02, -math.cos(swing-knee))
            arm = -.65*swing
            upper = (math.sin(arm), sign*.12, -math.cos(arm))
            forearm = (math.sin(arm+.22), sign*.03, -math.cos(arm+.22))
        point(side+'_Thigh', side+'_Calf', thigh)
        point(side+'_Calf', side+'_Foot', calf)
        # Keep the original heel-to-toe slope while bending the knees.
        point(side+'_Foot', side+'_ToeBase', (.069, sign*.011, -.057))
        point(side+'_Upperarm', side+'_Forearm', upper)
        point(side+'_Forearm', side+'_Hand', forearm)
    if kind in ('walk', 'seated'):
        lowest = min(bones[s+'_Foot'].head.z for s in ('L', 'R'))
        root_drop(.0822-lowest)


for kind, length in [('idle', 24), ('walk', 24), ('seated', 24)]:
    rig.animation_data_create()
    action = bpy.data.actions.new(kind)
    rig.animation_data.action = action
    for frame in range(1, length+2):
        pose(kind, (frame-1)*math.tau/length)
        for bone in bones:
            bone.keyframe_insert(data_path='location', frame=frame)
            bone.keyframe_insert(data_path='rotation_quaternion', frame=frame)
    track = rig.animation_data.nla_tracks.new()
    track.name = kind
    strip = track.strips.new(kind, 1, action)
    strip.action_frame_start = 1
    strip.action_frame_end = length+1
    track.mute = True
    print('AUTHORED', kind, flush=True)

# NLA export keeps one named clip per action. Enable tracks only for export.
rig.animation_data.action = None
for track in rig.animation_data.nla_tracks:
    track.mute = False
reset()
scene.frame_start, scene.frame_end = 1, 25
for obj in bpy.context.selected_objects:
    obj.select_set(False)
rig.select_set(True)
mesh.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'adventurer_motion.glb'), export_format='GLB', use_selection=True, export_animations=True, export_animation_mode='NLA_TRACKS', export_frame_range=True, export_force_sampling=True)
for track in rig.animation_data.nla_tracks:
    track.mute = True

# Orthographic 3D renders become actual limb-animation frames in the 2D world.
scene.render.engine = 'CYCLES'
scene.cycles.samples = 12
scene.cycles.use_denoising = True
scene.render.resolution_x = scene.render.resolution_y = 256
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.world = bpy.data.worlds.new('CharacterWorld')
scene.world.color = (.35, .35, .35)
camera_data = bpy.data.cameras.new('SpriteCamera')
camera = bpy.data.objects.new('SpriteCamera', camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.type = 'ORTHO'
camera_data.ortho_scale = 1.20

for name, at, power, size in [('Key', (2,-3,4), 350, 4), ('Fill', (-2,2,3), 200, 4)]:
    data = bpy.data.lights.new(name, 'AREA')
    data.energy, data.shape, data.size = power, 'DISK', size
    light = bpy.data.objects.new(name, data)
    scene.collection.objects.link(light)
    light.location = at
    light.rotation_euler = (Vector((0,0,.5))-light.location).to_track_quat('-Z','Y').to_euler()

verification = ROOT / 'game/verification'
rig.animation_data.action = bpy.data.actions['seated']
scene.frame_set(1)
camera.location = (2,-3,1.6)
camera.rotation_euler = (Vector((.1,0,.45))-camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath = str(verification/'seated_character.png')
bpy.ops.render.render(write_still=True)

# A stable floor point projects to pixel (128, 215) for every direction.
# This keeps collision and depth ordering fixed while feet alternate.
directions = {'down':(3,0,2.1), 'up':(-3,0,2.1), 'left':(0,3,2.1), 'right':(0,-3,2.1)}
camera_data.ortho_scale = 1.22
scene.cycles.samples = 8
for direction, at in directions.items():
    camera.location = at
    target = Vector((0,0,.47))
    camera.rotation_euler = (target-camera.location).to_track_quat('-Z','Y').to_euler()
    for index in range(13):
        rig.animation_data.action = bpy.data.actions['idle' if index == 0 else 'walk']
        scene.frame_set(1 if index == 0 else 1+(index-1)*2)
        scene.render.filepath = str(OUT/f'{direction}_{index:02d}.png')
        bpy.ops.render.render(write_still=True)
    print('RENDERED_DIRECTION', direction, flush=True)

rig.animation_data.action = bpy.data.actions['seated']
scene.frame_set(1)
source_dir = ROOT / '美术资产/角色动作_v1'
source_dir.mkdir(parents=True, exist_ok=True)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(source_dir/'冒险者_行走与坐姿.blend'))
print('CHARACTER_MOTION_COMPLETE', flush=True)
