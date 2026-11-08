"""One-off assembly. Edit the resulting TSCN normally in Godot."""
import json, math, pathlib, struct
ROOT = pathlib.Path(__file__).resolve().parents[1]
resources, nodes, ids, bounds = [], [], {}, {}
ext = ['[ext_resource type="Script" path="res://scripts/table_view.gd" id="controller"]']
for index, path in enumerate(sorted((ROOT/'assets/models').glob('*.glb'))):
    key = str(index+1)
    ids[path.name] = key
    ext.append(f'[ext_resource type="PackedScene" path="res://assets/models/{path.name}" id="{key}"]')
    with path.open('rb') as f:
        f.seek(12)
        size, _ = struct.unpack('<II', f.read(8))
        d = json.loads(f.read(size))
    a = d['accessors'][d['meshes'][0]['primitives'][0]['attributes']['POSITION']]
    bounds[path.name] = (a['min'], a['max'])

def vec(v):
    return 'Vector3('+', '.join(f'{x:.7f}' for x in v)+')'

def res(kind, **props):
    key = f'{kind}_{len(resources)}'
    resources.append(f'[sub_resource type="{kind}" id="{key}"]\n'+'\n'.join(f'{k} = {v}' for k,v in props.items()))
    return f'SubResource("{key}")'

def node(name, kind=None, parent='.', **props):
    instance = props.pop('instance', None)
    header = f'[node name="{name}"'
    if kind: header += f' type="{kind}"'
    if parent is not None: header += f' parent="{parent}"'
    if instance: header += f' instance={instance}'
    nodes.append(header+']\n'+'\n'.join(f'{k} = {v}' for k,v in props.items()))

def mat(hexcolor, metal=0, rough=.8, emission=None):
    rgba = [int(hexcolor[i:i+2],16)/255 for i in (0,2,4)]+[1]
    props = dict(albedo_color='Color('+', '.join(str(v) for v in rgba)+')', metallic=metal, roughness=rough)
    if emission: props.update(emission_enabled='true', emission=emission, emission_energy_multiplier=1.8)
    return res('StandardMaterial3D', **props)

def box(name, size, at, material):
    node(name, 'MeshInstance3D', 'Room', position=vec(at), mesh=res('BoxMesh', size=vec(size), material=material))

def cylinder(name, radius, height, at, material, top=None):
    node(name, 'MeshInstance3D', 'Room', position=vec(at), mesh=res('CylinderMesh', top_radius=radius if top is None else top, bottom_radius=radius, height=height, radial_segments=48, material=material))

def model(name, filename, parent, at, scale, yaw=0, roll=0):
    low, high = bounds[filename]
    c = [(low[i]+high[i])/2 for i in range(3)]
    cx = (c[0]*math.cos(roll)-c[1]*math.sin(roll))*scale[0]
    cz = c[2]*scale[2]
    bottom = min((x*math.sin(roll)+y*math.cos(roll))*scale[1] for x in (low[0],high[0]) for y in (low[1],high[1]))
    node(name, 'Node3D', parent, position=vec(at), rotation=vec((0,yaw,0)))
    node('Model', parent=f'{parent}/{name}', instance=f'ExtResource("{ids[filename]}")', position=vec((-cx,-bottom,-cz)), rotation=vec((0,0,roll)), scale=vec(scale))

node('TableView', 'Node3D', None, process_mode=1, script='ExtResource("controller")')
sky_mat = res('ProceduralSkyMaterial', sky_top_color='Color(0.045,0.065,0.09,1)', sky_horizon_color='Color(0.38,0.33,0.24,1)', ground_bottom_color='Color(0.025,0.02,0.015,1)', ground_horizon_color='Color(0.28,0.24,0.17,1)')
sky = res('Sky', sky_material=sky_mat)
environment = res('Environment', background_mode=1, background_color='Color(0.035,0.045,0.04,1)', sky=sky, ambient_light_source=3, ambient_light_color='Color(0.70,0.76,0.82,1)', ambient_light_energy=.42, reflected_light_source=2, tonemap_mode=2)
node('WorldEnvironment', 'WorldEnvironment', environment=environment)
node('Room', 'Node3D')
wood, brass, wall, floor, glass = mat('30241a',0.05,0.72), mat('a78246',0.7,0.34), mat('1d2926',0,0.93), mat('211c17',0,0.93), mat('354958',0.25,0.3)
lamp = mat('e8c78a',0,0.72,'Color(0.9,0.55,0.23,1)')
box('Floor',(10,0.12,10),(0,-.07,0),floor)
for i in range(-8,9): box(f'FloorSeam{i+8}',(0.012,0.003,9),(i*.45,-.008,0),wood)
box('BackWall',(8,3.8,0.18),(0,1.8,-3.5),wall)
box('LeftWall',(0.18,3.8,8),(-4,1.8,0),wall)
box('RightWall',(0.18,3.8,8),(4,1.8,0),wall)
for i in range(-5,6): box(f'Wainscot{i+5}',(0.06,1.04,0.08),(i*.7,0.52,-3.35),wood)
box('WallRail',(8,0.06,0.09),(0,1.08,-3.3),brass)
for i,x in enumerate((-2.2,2.2)):
    box(f'WindowFrame{i}',(1.1,1.45,0.08),(x,2,-3.32),wood)
    box(f'WindowGlass{i}',(0.95,1.30,0.08),(x,2,-3.25),glass)
    box(f'WindowVertical{i}',(0.035,1.3,0.09),(x,2,-3.19),brass)
    box(f'WindowHorizontal{i}',(0.95,0.035,0.09),(x,2,-3.19),brass)

node('Table','Node3D')
table_sy = .84/.7493896484375
model('RoundTable','round table 3d model.glb','Table',(0,0,0),(2.24,table_sy,2.24))
surface = (0.3471+.37469482421875)*table_sy
node('Props','Node3D')
model('MetalTray','round metal tray 3d model.glb','Props',(-.10,surface+.002,-.02),(0.66,)*3)
tray_floor = surface+.002+(0.1250457763671875-.0205)*.66
for name,file,x,z,yaw in [('BrassDie','ornate brass die 3d model.glb',-.23,0.02,0.24),('GoldDie','gold die 3d model.glb',-.04,0.09,-.18),('GlassDie','glass dice 3d model.glb',-.09,-.11,0.45)]:
    model(name,file,'Props',(x,tray_floor+.003,z),(0.105,)*3,yaw)
model('TransparentDie','transparent dice 3d model.glb','Props',(0.43,surface+.002,-.12),(0.115,)*3,-.3)
model('HeartDie','heart dice 3d model.glb','Props',(0.47,surface+.002,0.18),(0.12,)*3,0.25)
model('OrnateKey','ornate key 3d model.glb','Props',(0.49,surface+.003,0.48),(0.24,)*3,-.55,math.pi/2)
node('Chips','Node3D')
for pile,(file,x,z,count) in enumerate([('poker chip 3d model.glb',-.47,0.61,4),('poker chip 3d model (1).glb',-.30,0.66,5),('golden poker chip 3d model.glb',-.13,0.70,6)]):
    low,high = bounds[file]
    height = (high[1]-low[1])*.095
    for i in range(count): model(f'Pile{pile+1}Chip{i+1}',file,'Chips',(x,surface+.002+i*(height+.0005),z),(0.095,)*3,i*.28)
model('LooseGoldChip','golden poker chip 3d model.glb','Chips',(0.10,surface+.002,0.69),(0.095,)*3,0.2)
node('Characters','Node3D')
# The source avatar faces +X and has no sitting animation. Keep it standing.
for name,file,at,yaw in [('AdventurerLeft','adventurer 3d model (1).glb',(-.95,0,-1.60),math.atan2(-1.60,0.95)),('AdventurerRight','adventurer 3d model (2).glb',(1.70,0,-.46),math.atan2(-.46,-1.70)),('AdventurerBackLeft','adventurer 3d model.glb',(-2.65,0,-2.35),math.atan2(-2.35,2.65)),('AdventurerBackRight','adventurer 3d model (3).glb',(2.65,0,-2.35),math.atan2(-2.35,-2.65))]:
    low,high = bounds[file]
    model(name,file,'Characters',at,(1.76/(high[1]-low[1]),)*3,yaw)
cylinder('LampBase',0.10,0.018,(-.61,surface+.009,-.42),brass)
cylinder('LampStem',0.035,0.25,(-.61,surface+.13,-.42),brass)
cylinder('LampShade',0.15,0.15,(-.61,surface+.30,-.42),lamp,0.08)
node('SeatCamera','Camera3D',position=vec((0,1.38,1.60)),rotation=vec((-.28,0,0)),fov=68.0,near=.05,current='true')
node('WarmTableLight','OmniLight3D',position=vec((-.6,2.4,0.65)),light_color='Color(1,0.79,0.53,1)',light_energy=2.2,omni_range=6.0,shadow_enabled='true',shadow_bias=.025,shadow_normal_bias=.4)
node('CoolWindowLight','OmniLight3D',position=vec((1.7,2.6,-2.6)),light_color='Color(0.48,0.67,1,1)',light_energy=1.5,omni_range=6.0)
node('SoftFrontLight','OmniLight3D',position=vec((0,2.4,2.8)),light_color='Color(1,0.90,0.75,1)',light_energy=.65,omni_range=6.0)
(ROOT/'scenes/table_view.tscn').write_text(f'[gd_scene load_steps={1+len(ext)+len(resources)} format=3]\n\n'+'\n\n'.join(ext+resources+nodes)+'\n',encoding='utf-8')
print(f'Saved {len(ids)} models, {len(nodes)} nodes. Surface {surface:.4f} m, tray floor {tray_floor:.4f} m.')
