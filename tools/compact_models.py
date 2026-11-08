"""Blender --background --python tools/compact_models.py -- [relative GLB].

Simplify staged copies while retaining UVs, materials, bones and animation.
The originals under game/ are never written.
"""
from pathlib import Path
import json
import struct
import sys
import time
import bpy

ROOT = Path(__file__).resolve().parents[1]
STAGE = ROOT / 'build/compact/project'
manifest = json.loads((STAGE.parent / 'manifest.json').read_text(encoding='utf-8'))
requested = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
report_path = STAGE.parent / 'models.json'
report = json.loads(report_path.read_text(encoding='utf-8')) if report_path.exists() else {}

for relative in requested or manifest['models']:
    if relative in report and not requested:
        continue
    source = ROOT / 'game' / relative
    target = STAGE / relative
    started = time.monotonic()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    animated = bool(bpy.data.actions)
    character = '/npcs/' in relative or 'adventurer' in relative
    budget = 10000 if character else 3500
    if 'round table' in relative:
        budget = 12000
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    before = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
    for obj in meshes:
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        triangles = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        if triangles > budget:
            modifier = obj.modifiers.new('CompactDistribution', 'DECIMATE')
            modifier.ratio = budget / triangles
            bpy.ops.object.modifier_move_to_index(modifier=modifier.name, index=0)
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        if not animated:
            # Static source characters sometimes contain invalid unused skins.
            for modifier in list(obj.modifiers):
                if modifier.type == 'ARMATURE':
                    obj.modifiers.remove(modifier)
    for image in bpy.data.images:
        if image.size[0] == 0:
            continue
        limit = 1024 if character or 'round table' in relative else 512
        scale = min(1.0, limit / max(image.size))
        if scale < 1.0:
            image.scale(max(1, round(image.size[0] * scale)),
                        max(1, round(image.size[1] * scale)))
    bpy.ops.export_scene.gltf(
        filepath=str(target), export_format='GLB', export_image_format='JPEG',
        export_jpeg_quality=78, export_animations=animated,
        export_animation_mode='NLA_TRACKS', export_frame_range=False,
        export_force_sampling=True, export_yup=True)
    after = sum(sum(len(p.vertices) - 2 for p in obj.data.polygons) for obj in meshes)
    data = target.read_bytes()
    length = struct.unpack_from('<I', data, 12)[0]
    gltf = json.loads(data[20:20 + length])
    entry = {'triangles_before': before, 'triangles_after': after,
             'bytes_before': source.stat().st_size, 'bytes_after': len(data),
             'animations': [a.get('name') for a in gltf.get('animations', [])],
             'skins': len(gltf.get('skins', [])),
             'seconds': round(time.monotonic() - started, 1)}
    report[relative] = entry
    report_path.write_text(json.dumps(report, indent=2), encoding='utf-8')
    print('COMPACT', relative, json.dumps(entry), flush=True)

print('COMPACT_MODELS_FINISHED', flush=True)
