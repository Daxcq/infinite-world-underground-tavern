import bpy
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
print('POSE_MODE',rig.data.pose_position,'ACTION',rig.animation_data.action,'SLOT',rig.animation_data.action_slot,'USE_NLA',rig.animation_data.use_nla)
print('LTHIGH',tuple(rig.pose.bones['L_Thigh'].head),tuple(rig.pose.bones['L_Calf'].head))
for tr in rig.animation_data.nla_tracks:print('TRACK',tr.name,tr.mute)
rig.data.pose_position='POSE'
rig.animation_data.use_nla=False
act=bpy.data.actions['seated']
rig.animation_data.action=act
rig.animation_data.action_slot=act.slots[0]
bpy.context.scene.frame_set(2)
print('AFTER',tuple(rig.pose.bones['L_Thigh'].head),tuple(rig.pose.bones['L_Calf'].head))
bpy.context.scene.render.filepath=r'D:\无限世界地下酒馆和赌局\game\verification\seated_check.png'
bpy.ops.render.render(write_still=True)
