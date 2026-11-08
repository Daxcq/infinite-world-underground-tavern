"""Stage a compact project without altering the source assets.

Next run compact_models.py with Blender, import with Godot, then package.
"""
from pathlib import Path
import json
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'game'
STAGE = ROOT / 'build/compact/project'
STAGE.mkdir(parents=True, exist_ok=True)

# Include the JSON roster and dynamically loaded resources in scripts.
pending = [Path('project.godot')]
pending += [p.relative_to(SOURCE) for folder in ('scenes', 'scripts', 'data')
            for p in (SOURCE / folder).rglob('*') if p.is_file()
            and p.suffix in ('.gd', '.tscn', '.json')]
copied = set()
models = []
while pending:
    relative = pending.pop()
    if relative in copied:
        continue
    source = SOURCE / relative
    target = STAGE / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    # Repeating staging preserves already simplified models.
    if source.suffix != '.glb' or not target.exists():
        shutil.copy2(source, target)
    copied.add(relative)
    for suffix in ('.uid', '.import'):
        sidecar = Path(str(source) + suffix)
        if sidecar.exists():
            shutil.copy2(sidecar, str(target) + suffix)
    if source.suffix in ('.gd', '.tscn', '.json', '.godot', '.gdshader'):
        text = source.read_text(encoding='utf-8-sig')
        for match in re.findall(r'res://([^"\n]+)', text):
            if (SOURCE / match).is_file():
                pending.append(Path(match))
    if source.suffix == '.glb':
        models.append(relative.as_posix())

# Embedded source textures avoid a duplicate image beside every GLB.
# Mode 3 preserves the original texture pixels after the source resize.
for metadata in STAGE.rglob('*.glb.import'):
    text = metadata.read_text(encoding='utf-8')
    text = text.replace('gltf/embedded_image_handling=1', 'gltf/embedded_image_handling=3')
    metadata.write_text(text, encoding='utf-8')

verification = STAGE / 'verification'
verification.mkdir(exist_ok=True)
(verification / '.gdignore').touch()
# Verify using existing tests; these are excluded from the deliverable.
shutil.copytree(SOURCE / 'tests', STAGE / 'tests', dirs_exist_ok=True)
manifest = {'models': sorted(models), 'files': len(copied),
            'source_bytes': sum((SOURCE / p).stat().st_size for p in copied)}
(STAGE.parent / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(json.dumps(manifest, indent=2))
