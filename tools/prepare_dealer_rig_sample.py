import bpy, json
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'美术资产/荷官绑骨样例_v1'
OUT.mkdir(parents=True, exist_ok=True)
PREVIEW = ROOT/'game/verification/dealer_rig'
PREVIEW.mkdir(exist_ok=True)
source = Path(r'D:/电脑管家迁移文件/xwechat_files/wxid_vehdh1cvzy4k22_7f3c/msg/file/2026-11/mysterious masked man 3d model.glb')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
body = next(o for o in bpy.data.objects if o.type=='MESH')
for o in list(bpy.data.objects):
    if o != body:
        bpy.data.objects.remove(o, do_unlink=True)
corners = [body.matrix_world@Vector(c) for c in body.bound_box]
low = Vector([min(v[i] for v in corners) for i in range(3)])
high = Vector([max(v[i] for v in corners) for i in range(3)])
body.data.transform(Matrix.Scale(1.8/(high.z-low.z),4) @ Matrix.Translation(Vector((-(high.x+low.x)/2,-(high.y+low.y)/2,-low.z))) @ body.matrix_world)
body.matrix_world = Matrix.Identity(4)
body.name = 'Dealer_Body'
bpy.context.view_layer.objects.active = body
body.select_set(True)
modifier = body.modifiers.new('WorkingMesh','DECIMATE')
modifier.ratio = .14
bpy.ops.object.modifier_apply(modifier=modifier.name)
print('BODY',len(body.data.vertices),len(body.data.polygons),flush=True)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 12
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 400,640
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.film_transparent = True
scene.world = bpy.data.worlds.new('World')
scene.world.color = (.4,.4,.4)
data = bpy.data.cameras.new('ReviewCamera')
camera = bpy.data.objects.new('ReviewCamera',data)
scene.collection.objects.link(camera)
data.type='ORTHO'
data.ortho_scale=2.05
scene.camera=camera
for name,at,power in [('Key',(3,-4,5),500),('Fill',(-2,3,4),400)]:
    data=bpy.data.lights.new(name,'AREA')
    data.energy, data.shape, data.size = power,'DISK',4
    light=bpy.data.objects.new(name,data)
    scene.collection.objects.link(light)
    light.location=at
    light.rotation_euler=(Vector((0,0,.9))-light.location).to_track_quat('-Z','Y').to_euler()
for name,at in [('front',(4,0,.9)),('side',(0,-4,.9)),('back',(-4,0,.9))]:
    camera.location=at
    camera.rotation_euler=(Vector((0,0,.9))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(PREVIEW/f'landmarks_{name}.png')
    bpy.ops.render.render(write_still=True)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(PREVIEW/'prepared.blend'))
print('PREPARED_DEALER',flush=True)

