"""Read-only appearance review; outputs previews, never modifies source GLBs."""
import bpy
import math
from pathlib import Path
from mathutils import Vector

folder = Path(r'D:/电脑管家迁移文件/xwechat_files/wxid_vehdh1cvzy4k22_7f3c/msg/file/2026-11')
output = Path(__file__).resolve().parent/'new_characters'
output.mkdir(exist_ok=True)
names = ['mysterious masked man 3d model.glb', 'masked figure 3d model.glb', 'puppet 3d model(1).glb', 'gas mask doctor 3d model.glb', 'vintage gentleman 3d model.glb']
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 12
scene.cycles.use_denoising = True
scene.render.resolution_x = 400
scene.render.resolution_y = 600
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.film_transparent = True
scene.world = bpy.data.worlds.new('ReviewWorld')
scene.world.color = (.35, .35, .35)
camera_data = bpy.data.cameras.new('ReviewCamera')
camera = bpy.data.objects.new('ReviewCamera', camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.type = 'ORTHO'
camera_data.ortho_scale = 1.22
for name, at, power in [('Key', (3,-4,4), 450), ('Fill', (0,3,3), 250)]:
    data = bpy.data.lights.new(name, 'AREA')
    data.energy, data.shape, data.size = power, 'DISK', 4
    light = bpy.data.objects.new(name, data)
    scene.collection.objects.link(light)
    light.location = at
    light.rotation_euler = (Vector((0,0,.5))-light.location).to_track_quat('-Z','Y').to_euler()
fixed = set(bpy.data.objects)
for index, filename in enumerate(names, 1):
    bpy.ops.import_scene.gltf(filepath=str(folder/filename))
    imported = [o for o in bpy.data.objects if o not in fixed]
    meshes = [o for o in imported if o.type == 'MESH']
    corners = [o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
    low = Vector([min(v[i] for v in corners) for i in range(3)])
    high = Vector([max(v[i] for v in corners) for i in range(3)])
    center = (low+high)*.5
    for mesh in meshes:
        bpy.context.view_layer.objects.active = mesh
        mesh.select_set(True)
        modifier = mesh.modifiers.new('PreviewOnly', 'DECIMATE')
        modifier.ratio = .08
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        mesh.select_set(False)
    for view, offset in [('front', Vector((4,-2.2,1.1))), ('back', Vector((-4,2.2,1.1)))]:
        camera.location = center+offset
        camera.rotation_euler = (center-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath = str(output/f'{index:02d}_{view}.png')
        bpy.ops.render.render(write_still=True)
    print('REVIEWED', filename, flush=True)
    for obj in imported:
        bpy.data.objects.remove(obj, do_unlink=True)
print('REVIEW_COMPLETE', flush=True)
