"""Build the masked dealer rig in the supplied pose. Run in Blender 5.2.

Input: game/verification/dealer_rig/prepared.blend, made by the preparation
script. Originals remain untouched. Outputs are isolated from game scenes.
"""
import bpy
import math
import json
import numpy as np
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'美术资产/荷官绑骨样例_v1'
PREVIEW = ROOT/'game/verification/dealer_rig'
bpy.ops.wm.open_mainfile(filepath=str(PREVIEW/'prepared.blend'))
body = bpy.data.objects['Dealer_Body']
offset = Vector((.17,.02,0))
body.data.transform(Matrix.Translation(offset))
data = bpy.data.armatures.new('Dealer_Skeleton')
rig = bpy.data.objects.new('Dealer_Rig',data)
bpy.context.collection.objects.link(rig)
for obj in bpy.context.selected_objects:
    obj.select_set(False)
rig.select_set(True)
bpy.context.view_layer.objects.active=rig
rig.show_in_front=True
data.display_type='OCTAHEDRAL'
bpy.ops.object.mode_set(mode='EDIT')
specs=[]

def bone(name, head, tail, parent=None, deform=True):
    item=data.edit_bones.new(name)
    item.head, item.tail = head,tail
    item.use_deform=deform
    if parent:
        item.parent=data.edit_bones[parent]
    specs.append((name,list(head),list(tail),parent,deform))

bone('Root',(0,0,0),(0,0,.18),deform=False)
bone('Pelvis',(0,0,.84),(0,0,.99),'Root')
bone('Spine',(0,0,.99),(.02,0,1.20),'Pelvis')
bone('Chest',(.02,0,1.20),(.04,0,1.43),'Spine')
bone('Neck',(.04,0,1.43),(.07,0,1.53),'Chest')
bone('Head',(.07,0,1.53),(.10,0,1.79),'Neck')
for side,sign in [('L',1),('R',-1)]:
    shoulder=(.03,.02+sign*.24,1.37)
    elbow=(.09,.30,1.11) if side=='L' else (.04,-.29,1.08)
    wrist=(.36,.24,1.08) if side=='L' else (.22,-.10,1.16)
    palm=(.50,.25,1.035) if side=='L' else (.27,-.015,1.205)
    bone(side+'_Clavicle',(.03,sign*.06,1.37),shoulder,'Chest')
    bone(side+'_Upperarm',shoulder,elbow,side+'_Clavicle')
    bone(side+'_Forearm',elbow,wrist,side+'_Upperarm')
    bone(side+'_Hand',wrist,palm,side+'_Forearm')
    bone(side+'_Thigh',(0,sign*.115,.84),(-.025,sign*.12,.44),'Pelvis')
    bone(side+'_Calf',(-.025,sign*.12,.44),(-.05,sign*.14,.105),side+'_Thigh')
    bone(side+'_Foot',(-.05,sign*.14,.105),(.10,sign*.14,.045),side+'_Calf')
    bone(side+'_Toe',(.10,sign*.14,.045),(.15,sign*.14,.035),side+'_Foot')
    bone('Coat_'+side,(0,sign*.19,.90),(-.01,sign*.23,.55),'Pelvis')
    bone('Coat_'+side+'_End',(-.01,sign*.23,.55),(-.02,sign*.27,.29),'Coat_'+side)
bone('Coat_Back',(-.12,0,.90),(-.14,0,.55),'Pelvis')
bone('Coat_Back_End',(-.14,0,.55),(-.15,0,.29),'Coat_Back')
bpy.ops.object.mode_set(mode='OBJECT')

# The mesh has close-contact posed arms. Keep weights in anatomical regions
# instead of letting the nearest torso bone capture the glove and forearm.
vertices=np.empty(len(body.data.vertices)*3,dtype=np.float32)
body.data.vertices.foreach_get('co',vertices)
vertices=vertices.reshape(-1,3)
x,y,z=vertices.T
coat_region=(z>.25)&(z<.96)&(x<.18)&((np.abs(y)>.185)|(x<-.105)|((x>.045)&(np.abs(y)>.13)))
deform=[b for b in data.bones if b.use_deform]
scores=[]
for item in deform:
    h,t=np.array(item.head_local),np.array(item.tail_local)
    segment=t-h
    projection=np.clip((vertices-h)@segment/max(float(segment@segment),1e-8),0,1)
    distance=np.sum((vertices-h-projection[:,None]*segment)**2,axis=1)
    score=1/(distance+.001)**3
    name=item.name
    if name.startswith('Coat_'):
        score*=coat_region*np.clip((.98-z)/.18,0,1)*4
        if name.startswith('Coat_L'):score[y<0]*=.001
        if name.startswith('Coat_R'):score[y>0]*=.001
        if name.startswith('Coat_Back'):score[x>-.06]*=.02
    else:
        score[coat_region]*=.025
        if name.endswith('_Toe'):score[z>.14]=0
        elif name.endswith('_Foot'):score[z>.23]=0
        elif name.endswith('_Calf'):score[z>.58]=0
        elif name.endswith('_Thigh'):score[z>.97]=0
        elif name=='Head':score[z<1.48]=0
        elif name=='Neck':score[z<1.34]=0
        elif name in {'Pelvis','Spine','Chest'}:
            score[(z<.7)&~coat_region]*=.01
            score[(x>.14)&(z>.95)&(z<1.38)]*=.05
        if any(tag in name for tag in ('Upperarm','Forearm','Hand','Clavicle')):
            score[(z<.85)|(z>1.46)]=0
            if name.startswith('L_'):score[y<.06]*=.002
            if name.startswith('R_'):score[y>.09]*=.002
    scores.append(score)
weights=np.stack(scores,axis=1)
nearest=np.argsort(weights,axis=1)[:,-4:]
kept=np.zeros_like(weights)
np.put_along_axis(kept,nearest,np.take_along_axis(weights,nearest,axis=1),axis=1)
kept/=kept.sum(axis=1,keepdims=True)
groups=[body.vertex_groups.new(name=b.name) for b in deform]
for index,row in enumerate(kept):
    for group in nearest[index]:
        groups[group].add([index],float(row[group]),'REPLACE')
modifier=body.modifiers.new('Dealer_Skin','ARMATURE')
modifier.object=rig
modifier.use_deform_preserve_volume=True
body.parent=rig
bones=rig.pose.bones

def update():
    bpy.context.view_layer.update()

def reset():
    for b in bones:
        b.rotation_mode='QUATERNION'
        b.matrix_basis=Matrix.Identity(4)
    update()

def rotate(name,axis,angle):
    b=bones[name]
    h=b.head.copy()
    b.matrix=Matrix.Translation(h)@Matrix.Rotation(angle,4,axis)@Matrix.Translation(-h)@b.matrix
    update()

def point(name,direction):
    b=bones[name]
    rotation=(b.tail-b.head).normalized().rotation_difference(Vector(direction).normalized()).to_matrix().to_4x4()
    h=b.head.copy()
    b.matrix=Matrix.Translation(h)@rotation@Matrix.Translation(-h)@b.matrix
    update()

def pose(kind,phase):
    reset()
    if kind=='seated':
        matrix=bones['Root'].matrix.copy()
        matrix.translation.z-=.29
        bones['Root'].matrix=matrix
        update()
        for side,sign in [('L',1),('R',-1)]:
            point(side+'_Thigh',(1,sign*.05,-.04))
            point(side+'_Calf',(0,0,-1))
            point(side+'_Foot',(1,0,-.40))
            point('Coat_'+side,(1,sign*.10,-.08))
            point('Coat_'+side+'_End',(.05,sign*.04,-1))
        point('Coat_Back',(-.65,0,-.76))
        point('Coat_Back_End',(0,0,-1))
        bones['Coat_Back_End'].scale.y=.90
        update()
        lowest=min(bones[s+'_Foot'].head.z for s in ('L','R'))
        matrix=bones['Root'].matrix.copy()
        matrix.translation.z+=.105-lowest
        bones['Root'].matrix=matrix
        update()
        point('L_Upperarm',(.25,.10,-1))
        point('L_Forearm',(.85,0,.50))
        point('L_Hand',(1,0,-.10))
    elif kind=='gesture':
        rotate('Head','Z',math.radians(8)*math.sin(phase))
        rotate('L_Upperarm','Y',math.radians(-12)*math.sin(phase))
        rotate('L_Forearm','Y',math.radians(-18)*math.sin(phase))
        rotate('L_Hand','X',math.radians(8)*math.sin(phase))
        rotate('R_Hand','Y',math.radians(5)*math.sin(phase))
    elif kind=='bend_test':
        for side in ('L','R'):
            rotate(side+'_Upperarm','Y',math.radians(-25)*math.sin(phase))
            rotate(side+'_Forearm','Z',math.radians(12)*math.sin(phase))
            rotate(side+'_Calf','Y',math.radians(25)*math.sin(phase))

scene=bpy.context.scene
scene.render.fps=30
rig.animation_data_create()
for kind in ('idle','gesture','seated','bend_test'):
    action=bpy.data.actions.new(kind)
    rig.animation_data.action=action
    for frame in range(1,32):
        pose(kind,(frame-1)*math.tau/30)
        for b in bones:
            b.keyframe_insert(data_path='location',frame=frame)
            b.keyframe_insert(data_path='rotation_quaternion',frame=frame)
    track=rig.animation_data.nla_tracks.new()
    track.name=kind
    strip=track.strips.new(kind,1,action)
    strip.action_frame_start,strip.action_frame_end=1,31
    track.mute=True
    print('AUTHORED',kind,flush=True)
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks:
    track.mute=False
reset()
scene.frame_start,scene.frame_end=1,31
for obj in bpy.context.selected_objects:obj.select_set(False)
rig.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'masked_dealer_rigged.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_frame_range=True,export_force_sampling=True)
for track in rig.animation_data.nla_tracks:track.mute=True
rig.animation_data.use_nla=False
camera=scene.camera
scene.render.resolution_x=600
scene.render.resolution_y=760
camera.data.ortho_scale=2.20
camera.location=(3.8,-2.2,1.7)
camera.rotation_euler=(Vector((.05,0,.86))-camera.location).to_track_quat('-Z','Y').to_euler()
for name,frame in [('idle',1),('gesture',9),('seated',1),('bend_test',9)]:
    action=bpy.data.actions[name]
    rig.animation_data.action=action
    rig.animation_data.action_slot=action.slots[0]
    scene.frame_set(frame)
    scene.render.filepath=str(PREVIEW/f'rig_{name}.png')
    bpy.ops.render.render(write_still=True)
    print('RENDERED',name,flush=True)

rig.animation_data.action=bpy.data.actions['gesture']
rig.animation_data.action_slot=rig.animation_data.action.slots[0]
scene.frame_set(9)
rig.select_set(True)
body.select_set(False)
bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='POSE')
data.bones.active=data.bones['L_Forearm']
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_location=(0,0,.9)
            area.spaces.active.region_3d.view_distance=3.4
            area.spaces.active.region_3d.view_rotation=(Vector((0,0,.9))-Vector((3.5,-3.0,2.2))).to_track_quat('-Z','Y')
            area.spaces.active.clip_end=100
            area.spaces.active.shading.type='MATERIAL'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'荷官_绑骨与动作样例.blend'))
report={'bones':len(bones),'deform_bones':len(deform),'vertices':len(vertices),'triangles':len(body.data.polygons),'weight_sum_min':float(kept.sum(axis=1).min()),'weight_sum_max':float(kept.sum(axis=1).max()),'clips':['idle','gesture','seated','bend_test'],'finger_controls':False,'rig_rest_pose':'original posed mesh','joint_definitions':specs}
(OUT/'rig_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('DEALER_RIG_COMPLETE',json.dumps({k:v for k,v in report.items() if k!='joint_definitions'}),flush=True)
