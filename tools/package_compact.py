"""Create and verify a sub-12,000,000-byte Godot project ZIP (no engine)."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
STAGE = ROOT / 'build/compact/project'
OUTPUT = ROOT / 'build/地下酒馆_12MB精简版.zip'
LIMIT = 12_000_000
report = json.loads((STAGE.parent / 'models.json').read_text(encoding='utf-8'))
manifest = json.loads((STAGE.parent / 'manifest.json').read_text(encoding='utf-8'))
assert set(report) == set(manifest['models']), 'Model processing is incomplete'

instructions = '''# 地下酒馆 · 精简版

本包不含 Godot 引擎。请先解压到普通文件夹，再用 Godot 4.7.2
导入本目录 project.godot，等首次资源导入完成后按 F5 游玩。
沿用原工程的 GDScript 与 Compatibility 渲染器，不需要 .NET。

已有当前电脑的 Godot 安装时，也可双击“开始试玩.cmd”。
直接进入地下赌局：双击“进入地下赌局.cmd”。

操作：WASD / 方向键移动，Shift 快步，E 交互，Enter 确认，
Esc 暂停，F11 全屏；赌桌内按住鼠标左键拖动环顾。

本版保留原有玩法、七位可选 NPC、酒保及已有动画。
3D 模型降低面数，角色/圆桌贴图缩至 1024，其他道具贴图缩至 512。
原二维背景、人物图集与对白数据保持原样。近看精细纹饰会有所减少。
不包含原始高模、编辑缓存、测试截图、历史美术素材或引擎。
首次打开后 Godot 会生成 .godot 缓存，解压/导入后体积大于压缩包属正常。
'''

def launcher(extra):
    return ('@echo off\r\n'
            'set "GODOT_EXE=D:\\Godot_v4.7.2-stable_mono_win64\\Godot_v4.7.2-stable_mono_win64.exe"\r\n'
            'if not exist "%GODOT_EXE%" (\r\n'
            '  echo Please import project.godot with Godot 4.7.2 and press F5.\r\n'
            '  pause\r\n  exit /b 1\r\n)\r\n'
            '"%GODOT_EXE%" --headless --path "%~dp0." --import\r\n'
            'if errorlevel 1 exit /b 1\r\n'
            f'start "" "%GODOT_EXE%" --path "%~dp0."{extra}\r\n')

files = sorted(p for p in STAGE.rglob('*') if p.is_file()
               and p.relative_to(STAGE).parts[0] in ('assets', 'scenes', 'scripts', 'data')
               and p.suffix in ('.glb', '.png', '.jpg', '.gdshader', '.gd', '.tscn', '.json', '.import', '.uid'))
files.append(STAGE / 'project.godot')
with zipfile.ZipFile(OUTPUT, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for path in files:
        archive.write(path, '地下酒馆_精简版/' + path.relative_to(STAGE).as_posix())
    archive.writestr('地下酒馆_精简版/说明.md', instructions)
    archive.writestr('地下酒馆_精简版/开始试玩.cmd', launcher(''))
    archive.writestr('地下酒馆_精简版/进入地下赌局.cmd', launcher(' -- --underground'))
with zipfile.ZipFile(OUTPUT) as archive:
    assert archive.testzip() is None, 'ZIP integrity failure'
size = OUTPUT.stat().st_size
summary = {'archive': str(OUTPUT), 'bytes': size, 'decimal_MB': round(size / 1e6, 3),
           'MiB': round(size / 2**20, 3), 'limit_bytes': LIMIT, 'under_limit': size < LIMIT,
           'sha256': hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
           'models': len(report), 'project_files': len(files),
           'triangles_before': sum(r['triangles_before'] for r in report.values()),
           'triangles_after': sum(r['triangles_after'] for r in report.values()),
           'source_bytes': manifest['source_bytes'],
           'uncompressed_project_bytes': sum(p.stat().st_size for p in files)}
(STAGE.parent / 'package-report.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
print(json.dumps(summary, ensure_ascii=False, indent=2))
assert size < LIMIT, f'Archive exceeds 12 MB: {size} bytes'
