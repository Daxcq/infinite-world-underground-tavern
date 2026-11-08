import bpy,numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector
body=bpy.data.objects['Dealer_Body'];p=np.empty(len(body.data.vertices)*3);body.data.vertices.foreach_get('co',p);p=p.reshape(-1,3)
print('EXTENTS',p.min(axis=0),p.max(axis=0))
cam=bpy.context.scene.camera
print('CAMERA',list(cam.location),'ortho',cam.data.ortho_scale)
for z in [0,.2,.4,.6,.8,1.,1.2,1.4,1.6,1.8]:
 q=p[abs(p[:,2]-z)<.03];print('SLICE',z,'q10median90',np.quantile(q,[.1,.5,.9],axis=0).round(3).tolist() if len(q) else [])
for point in [(0,0,0),(0,0,1.8),(0,.2,1.4),(.2,0,1.2)]:
 q=world_to_camera_view(bpy.context.scene,cam,Vector(point));print('PIX',point,(q.x*400,(1-q.y)*640))
