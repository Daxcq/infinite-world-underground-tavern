import bpy
from pathlib import Path
root = Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(root / 'game/assets/characters/motion/adventurer_motion.glb'))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
print('RIG', rig.name, tuple(rig.scale), tuple(rig.location), flush=True)
for b in rig.pose.bones:
    if b.name in ['BoneRoot','Pelvis','Waist','Spine01','Spine02','Head'] or any(t in b.name for t in ['Upperarm','Forearm','Hand','Thigh','Calf','Foot','ToeBase']):
        print(b.name, tuple(round(v,4) for v in b.head), tuple(round(v,4) for v in b.tail), flush=True)
for o in bpy.data.objects:
    if o.type == 'MESH': print('MESH',o.name, len(o.data.vertices), tuple(o.dimensions), tuple(o.scale), tuple(o.location), flush=True)
print('ACTIONS', [a.name for a in bpy.data.actions], flush=True)
