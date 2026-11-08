import bpy
print('PACKED_IMAGES',[(i.name,bool(i.packed_file)) for i in bpy.data.images if i.type=='IMAGE'])
print('ACTIONS',[(a.name,len(a.slots)) for a in bpy.data.actions])
