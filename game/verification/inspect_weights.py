import bpy,json
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
for o in bpy.data.objects:
 if o.type!='MESH':continue
 print('MESH',o.name, 'MODIFIERS',[(m.name,m.type,m.show_viewport,m.show_render) for m in o.modifiers])
 print('GROUPS',[(g.index,g.name) for g in o.vertex_groups][:10])
 print('WEIGHTS',[(v.index,[(g.group,g.weight) for g in v.groups]) for v in list(o.data.vertices)[:3]])
 print('PARENT',o.parent,'matrix',o.matrix_world)
 for m in o.modifiers:
  if m.type=='ARMATURE':print('ARM',m.object,m.use_vertex_groups,m.use_bone_envelopes,m.use_deform_preserve_volume)
rig.data.pose_position='POSE'
print('DEFORM',[(b.name,b.use_deform) for b in rig.data.bones][:10])
