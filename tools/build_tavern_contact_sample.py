"""Author contact-calibrated derivatives; run in Blender, never overwrite the source rig."""
import bpy
import json
import math
import numpy as np
import sys
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'game/assets/tavern3d'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT / '美术资产/角色动作_v1/冒险者_行走与坐姿.blend'))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
mesh = next(o for o in bpy.data.objects if o.type == 'MESH' and o.find_armature() == rig)
rig.animation_data_clear()
bones = rig.pose.bones
S = 1.7947244
scene = bpy.context.scene
scene.render.fps = 30

sys.path.insert(0, str(ROOT / 'tools'))
from pixel_rpg_body import build_body
bpy.data.objects.remove(mesh, do_unlink=True)
mesh = build_body(rig)


def update():
    bpy.context.view_layer.update()


def turn(name, radians):
    b = bones[name]
    head = b.head.copy()
    b.matrix = Matrix.Translation(head) @ Matrix.Rotation(radians, 4, 'Y') @ Matrix.Translation(-head) @ b.matrix
    update()


def point(name, child, direction):
    b = bones[name]
    q = (bones[child].head - b.head).normalized().rotation_difference(Vector(direction).normalized())
    head = b.head.copy()
    b.matrix = Matrix.Translation(head) @ q.to_matrix().to_4x4() @ Matrix.Translation(-head) @ b.matrix
    update()


def reset():
    for b in bones:
        b.matrix_basis.identity()
        b.rotation_mode = 'QUATERNION'
    update()


def drop(z):
    m = bones['BoneRoot'].matrix.copy()
    m.translation.z += z
    bones['BoneRoot'].matrix = m
    update()


def seated():
    reset()
    drop(-.224)
    for side, sign in [('L', 1), ('R', -1)]:
        point(side+'_Thigh', side+'_Calf', (1, sign*.12, -.045))
        point(side+'_Calf', side+'_Foot', (.02, sign*.02, -1))
        point(side+'_Foot', side+'_ToeBase', (.069, sign*.011, -.057))
    drop(.0822 - min(bones[s+'_Foot'].head.z for s in ['L', 'R']))


def arm(side, hand_target, elbow_pole, elbow_height=None):
    """Analytic two-link solve in rig coordinates, with a stable elbow plane."""
    upper, lower, hand = [bones[side+'_'+n] for n in ['Upperarm', 'Forearm', 'Hand']]
    a = upper.head.copy()
    l1 = (lower.head - a).length
    l2 = (hand.head - lower.head).length
    target = Vector(hand_target) / S
    delta = target - a
    distance = min(delta.length, l1+l2-.00001)
    axis = delta.normalized()
    pole = Vector(elbow_pole) - a
    pole = (pole - axis * pole.dot(axis)).normalized()
    along = (l1*l1-l2*l2+distance*distance)/(2*distance)
    radius = math.sqrt(max(0, l1*l1-along*along))
    center = a + axis*along
    if elbow_height is not None:
        up = Vector((0,0,1)) - axis*axis.z
        up.normalize()
        lateral = axis.cross(up).normalized()
        amount = max(-1, min(1, (elbow_height/S-center.z)/max(radius*up.z, 1e-8)))
        choices = [up*amount + lateral*sign*math.sqrt(1-amount*amount) for sign in [-1,1]]
        pole = max(choices, key=lambda v:v.dot(pole))
    elbow = center + pole*radius
    point(side+'_Upperarm', side+'_Forearm', elbow-a)
    point(side+'_Forearm', side+'_Hand', target-lower.head)


report = {'source': '美术资产/角色动作_v1/冒险者_行走与坐姿.blend', 'scale': S, 'table_height': .84, 'table_radius': .78, 'clips': {}}
for kind in ['drink', 'sleep']:
    rig.animation_data_create()
    action = bpy.data.actions.new('tavern_'+kind)
    rig.animation_data.action = action
    measures = []
    penetrations = []
    for frame in range(1, 122):
        seated()
        phase = (frame-1)/120
        lift = (1-math.cos(phase*math.tau))/2
        if kind == 'drink':
            arm('L', (.40, .16, .96), (0, .35, .35))
            arm('R', (.37-.15*lift, -.13+.055*lift, .94+.17*lift), (0, -.38, .38))
            # Keep wrist orientation stable; cup is attached to this bone in Godot.
            m = bones['R_Hand'].matrix.copy()
            m.translation = bones['R_Hand'].head
            # Preserve the seated hand's orientation, with a small drinking tilt.
            if frame == 1:
                wrist_rest = m.to_3x3().copy()
            orientation = Matrix.Rotation(-.30*lift, 3, 'Y') @ wrist_rest
            bones['R_Hand'].matrix = Matrix.Translation(m.translation) @ orientation.to_4x4()
            update()
            for finger in ['Pinky','Ring','Mid','Index']:
                for joint, angle in [(1, 30), (2, 55), (3, 35)]:
                    b = bones['R_'+finger+str(joint)]
                    b.rotation_mode = 'QUATERNION'
                    b.rotation_quaternion = Matrix.Rotation(math.radians(angle), 4, 'X').to_quaternion()
            update()
        else:
            turn('Waist', math.radians(20))
            turn('Spine01', math.radians(20))
            turn('Spine02', math.radians(14))
            arm('L', (.53, -.035, .98), (.18, .28, .42), .925)
            arm('R', (.47, .045, .97), (.18, -.28, .42), .935)
            turn('Head', math.radians(5))
            head = bones['Head'].matrix.copy()
            head.translation.z += .15/S
            bones['Head'].matrix = head
            update()
        for b in bones:
            b.keyframe_insert(data_path='location', frame=frame)
            b.keyframe_insert(data_path='rotation_quaternion', frame=frame)
        update()
        measures.append({n: [round(v*S, 5) for v in bones[n].head] for n in ['Pelvis','Head','L_Forearm','R_Forearm','L_Hand','R_Hand','L_Foot','R_Foot']})
        if kind == 'drink' or frame == 1:
            evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
            data = evaluated.to_mesh()
            coords = np.empty(len(data.vertices)*3, dtype=np.float32)
            data.vertices.foreach_get('co', coords)
            coords = coords.reshape(-1,3)*S
            radial = np.linalg.norm(coords[:,:2]-np.array([1.14, 0]), axis=1)
            bad = (radial < .797) & (coords[:,2] > .752) & (coords[:,2] < .838)
            penetrations.append(int(bad.sum()))
            if frame in [1, 31, 61, 91, 121]:
                print('TABLE_PENETRATION', kind, frame, int(bad.sum()), 'MIN',coords[bad].min(0).tolist() if bad.any() else [], flush=True)
            evaluated.to_mesh_clear()
    track = rig.animation_data.nla_tracks.new()
    track.name = kind
    strip = track.strips.new(kind, 1, action)
    strip.action_frame_start, strip.action_frame_end = 1, 121
    track.mute = True
    report['clips'][kind] = {'first': measures[0], 'peak': measures[60], 'last': measures[-1], 'mesh_samples':len(penetrations), 'max_table_penetrating_vertices':max(penetrations)}
    print('AUTHORED_CONTACT', kind, json.dumps(report['clips'][kind]), flush=True)
    if max(penetrations):
        raise RuntimeError(f'{kind}: posed character intersects tabletop; do not export')

rig.animation_data.action = None
for name in ['idle', 'walk', 'seated']:
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    action = bpy.data.actions[name]
    strip = track.strips.new(name, 1, action)
    strip.action_frame_start, strip.action_frame_end = 1, 25
for track in rig.animation_data.nla_tracks:
    track.mute = False
reset()
scene.frame_start, scene.frame_end = 1, 121
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
mesh.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'patron_contact.glb'), export_format='GLB', use_selection=True,
    export_animations=True, export_animation_mode='NLA_TRACKS', export_frame_range=True, export_force_sampling=True)
for track in rig.animation_data.nla_tracks:
    track.mute = True
source = ROOT / '美术资产/像素长廊小样_v1'
source.mkdir(parents=True, exist_ok=True)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(source/'像素角色_接触动作.blend'))
(OUT/'contact_authoring.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print('TAVERN_CONTACT_COMPLETE', flush=True)
