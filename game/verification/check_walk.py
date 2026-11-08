import bpy
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');scene=bpy.context.scene
rig.animation_data.action=bpy.data.actions['walk'];rig.animation_data.action_slot=bpy.data.actions['walk'].slots[0];rig.animation_data.use_nla=False
for frame in [1,7,13,19]:
 scene.frame_set(frame)
 print('SAMPLE',frame,tuple(rig.pose.bones['L_Thigh'].rotation_quaternion),tuple(rig.pose.bones['L_Calf'].head))
 scene.render.filepath=fr'D:\无限世界地下酒馆和赌局\game\verification\walk_check_{frame}.png'
 bpy.ops.render.render(write_still=True)
