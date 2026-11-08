import bpy
import numpy as np
from pathlib import Path
root = Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(root / '美术资产/长廊3D小样_v1/酒客_举杯与趴桌.blend'))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
mesh = next(o for o in bpy.data.objects if o.type == 'MESH' and o.find_armature() == rig)
print('BONES', [b.name for b in rig.pose.bones], flush=True)
rig.animation_data.use_nla = False
for clip in ['tavern_drink', 'tavern_sleep']:
    act = bpy.data.actions[clip]
    rig.animation_data.action = act
    rig.animation_data.action_slot = act.slots[0]
    for frame in [1, 61]:
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        ev = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
        coords = np.array([v.co[:] for v in ev.vertices])*1.7947244
        radial = np.linalg.norm(coords[:,:2]-np.array([1.14, 0]), axis=1)
        bad = (radial < .775) & (coords[:,2] > .752) & (coords[:,2] < .838)
        from collections import Counter
        labels = Counter()
        for v in mesh.data.vertices:
            if bad[v.index]:
                g = max(v.groups, key=lambda t:t.weight)
                labels[mesh.vertex_groups[g.group].name] += 1
        print('BAD', clip, frame, coords[bad].min(0) if bad.any() else [], coords[bad].max(0) if bad.any() else [], labels, flush=True)
        for v in mesh.data.vertices:
            if bad[v.index]:
                print('BAD_SOURCE', v.index, tuple(v.co), [(mesh.vertex_groups[g.group].name,round(g.weight,3)) for g in v.groups], flush=True)
        for name in ['Head','R_Hand','L_Hand','L_Forearm','R_Forearm','Pelvis','L_Foot','R_Foot']:
            group = mesh.vertex_groups[name].index
            indices = [v.index for v in mesh.data.vertices if any(g.group == group and g.weight > .5 for g in v.groups)]
            subset=coords[indices]
            print(clip,frame,name,'MIN',subset.min(0).round(4),'MAX',subset.max(0).round(4), flush=True)
        mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh_clear()
