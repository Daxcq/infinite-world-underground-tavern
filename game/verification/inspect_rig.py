import bpy, json
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r'D:\无限世界地下酒馆和赌局\game\assets\models\adventurer 3d model (1).glb')
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
print('RIG_WORLD',list(map(list,rig.matrix_world)))
for b in rig.pose.bones:
    if any(s in b.name for s in ('Thigh','Calf','Foot','ToeBase','Arm','Hand','Pelvis','Hip','Spine','Clavicle','BoneRoot')) and not any(s in b.name for s in ('Twist','Finger')):
        print('BONE',json.dumps({'name':b.name,'parent':b.parent.name if b.parent else None,'head':list(rig.matrix_world@b.head),'tail':list(rig.matrix_world@b.tail)},ensure_ascii=False))
for o in bpy.data.objects:
    if o.type=='MESH': print('MESH',o.name,len(o.data.vertices),len(o.data.polygons),list(o.dimensions))
