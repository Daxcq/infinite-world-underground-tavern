"""Pack the Blender-rendered limb-animation frames into the game atlas."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
folder = ROOT / 'game/assets/characters/motion'
atlas = Image.new('RGBA', (13*256, 4*256))
for row, direction in enumerate(('down', 'up', 'left', 'right')):
    for frame in range(13):
        with Image.open(folder/f'{direction}_{frame:02d}.png') as image:
            atlas.paste(image, (frame*256, row*256))
atlas.save(folder/'player_walk.png')
print('PACKED player_walk.png: four directions, one idle + twelve walk frames each')
