import bpy, json
from pathlib import Path

rig=bpy.data.objects['Dealer_Rig']
body=bpy.data.objects['Dealer_Body']
sums=[sum(g.weight for g in vertex.groups) for vertex in body.data.vertices]
assert len(rig.data.bones)==28
assert min(sums)>.999 and max(sums)<1.001
assert all(name in bpy.data.actions for name in ['idle','gesture','seated','bend_test'])
images=[image for image in bpy.data.images if image.type=='IMAGE']
assert images and all(image.packed_file for image in images)
rig.animation_data.action=bpy.data.actions['gesture']
rig.animation_data.action_slot=rig.animation_data.action.slots[0]
bpy.context.scene.frame_set(9)
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
print('REOPENED_SOURCE_OK',json.dumps({'bones':len(rig.data.bones),'vertices':len(sums),'weight_min':min(sums),'weight_max':max(sums),'packed_images':len(images),'actions':[a.name for a in bpy.data.actions],'default_action':rig.animation_data.action.name}),flush=True)
