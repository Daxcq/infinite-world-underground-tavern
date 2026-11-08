"""A small, fully volumetric RPG body built on the supplied character's rig."""
import bpy
import math
from mathutils import Vector


def build_body(rig):
    vertices, faces, face_materials, bindings = [], [], [], []
    colors = [('coat', '#69432e'), ('trim', '#b18a50'), ('shirt', '#d4c3a0'),
              ('pants', '#292c2d'), ('boots', '#3a2922'), ('skin', '#d6a174'),
              ('hair', '#38251f'), ('eye', '#211b1a'), ('bag', '#885537')]
    materials = []
    for name, hex_color in colors:
        srgb = [int(hex_color[i:i+2], 16)/255 for i in (1,3,5)]
        rgb = tuple(v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in srgb)
        mat = bpy.data.materials.new('Pixel_'+name)
        mat.diffuse_color = (*rgb,1)
        mat.use_nodes = True
        shader = mat.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Base Color'].default_value = (*rgb,1)
        shader.inputs['Roughness'].default_value = .95
        materials.append(mat)

    def add(points, polygons, mat, weights):
        offset = len(vertices)
        vertices.extend([tuple(p) for p in points])
        faces.extend([tuple(offset+i for i in face) for face in polygons])
        face_materials.extend([mat]*len(polygons))
        if isinstance(weights, str):
            weights = [{weights:1} for _ in points]
        bindings.extend(weights)

    def ellipsoid(center, radius, mat, bone, rings=6, segments=10):
        points = []
        for j in range(rings+1):
            phi = math.pi*j/rings
            for i in range(segments):
                theta = math.tau*i/segments
                points.append(Vector(center)+Vector((radius[0]*math.sin(phi)*math.cos(theta), radius[1]*math.sin(phi)*math.sin(theta), radius[2]*math.cos(phi))))
        polygons = []
        for j in range(rings):
            for i in range(segments):
                k = j*segments+i
                n = j*segments+(i+1)%segments
                polygons.append((k,k+segments,n+segments,n))
        add(points,polygons,mat,bone)

    def cuboid(center, size, mat, bone):
        points = [Vector(center)+Vector((x*size[0]/2,y*size[1]/2,z*size[2]/2))
                  for x,y,z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
        add(points,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat,bone)

    def limb(bone_name, child_name, r1, r2, mat):
        bone = rig.data.bones[bone_name]
        a = bone.head_local.copy()
        b = rig.data.bones[child_name].head_local.copy()
        direction = (b-a).normalized()
        u = direction.cross(Vector((1,0,0))).normalized()
        v = direction.cross(u).normalized()
        points = []
        for center,radius in [(a,r1),(b,r2)]:
            points.extend([center+(u*math.cos(i*math.tau/8)+v*math.sin(i*math.tau/8))*radius for i in range(8)])
        polygons = [(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
        polygons.extend([tuple(range(7,-1,-1)),tuple(range(8,16))])
        add(points,polygons,mat,bone_name)

    # The torso has four broad planes and smooth weights between spine rings.
    sections = [(.53,.079,.104,'Pelvis'),(.59,.082,.108,'Waist'),
                (.66,.086,.115,'Spine01'),(.75,.080,.119,'Spine02')]
    points, weights = [], []
    for z,rx,ry,bone in sections:
        for i in range(8):
            angle = math.tau*i/8
            points.append((.018+rx*math.cos(angle),.005+ry*math.sin(angle),z))
            weights.append({bone:1})
    polygons = [(j*8+i,j*8+(i+1)%8,(j+1)*8+(i+1)%8,(j+1)*8+i) for j in range(3) for i in range(8)]
    polygons.extend([tuple(range(7,-1,-1)),tuple(range(24,32))])
    add(points,polygons,0,weights)
    # Shirt front, collar, brass buttons and an actual diagonal leather strap.
    add([(.105,-.045,.745),(.105,.045,.745),(.108,0,.61)],[(0,1,2)],2,'Spine02')
    for side in [-1,1]:
        add([(.110,side*.045,.75),(.112,side*.075,.715),(.115,side*.025,.635)],[(0,1,2)],1,'Spine02')
    for z in [.59,.625,.66]:
        ellipsoid((.109,.004,z),(.006,.006,.006),1,'Spine01',3,6)
    for z,y,bone in [(.73,.08,'Spine02'),(.67,.025,'Spine01'),(.60,-.045,'Waist'),(.545,-.10,'Pelvis')]:
        cuboid((.112,y,z),(.013,.022,.063),8,bone)
    cuboid((.012,-.18,.49),(.13,.065,.12),8,'Pelvis')
    cuboid((.077,-.18,.49),(.009,.07,.035),1,'Pelvis')

    for side, sign in [('L',1),('R',-1)]:
        limb(side+'_Thigh',side+'_Calf',.053,.044,3)
        limb(side+'_Calf',side+'_Foot',.044,.035,3)
        knee = rig.data.bones[side+'_Calf'].head_local
        ellipsoid(knee,(.045,.045,.045),3,side+'_Calf',4,8)
        foot = rig.data.bones[side+'_Foot'].head_local
        ellipsoid(foot+Vector((.040,0,-.037)),(.105,.047,.045),4,side+'_Foot',4,10)
        # Coat tails follow each thigh rather than stretching across the lap.
        a = rig.data.bones[side+'_Thigh'].head_local
        cuboid(a+Vector((.055,sign*.014,-.065)),(.023,.105,.17),0,side+'_Thigh')
        limb(side+'_Upperarm',side+'_Forearm',.047,.043,0)
        limb(side+'_Forearm',side+'_Hand',.043,.029,0)
        elbow = rig.data.bones[side+'_Forearm'].head_local
        ellipsoid(elbow,(.043,.043,.043),0,side+'_Forearm',4,8)
        hand = rig.data.bones[side+'_Hand']
        ellipsoid((hand.head_local+hand.tail_local)*.5,(.025,.028,.028),5,side+'_Hand',4,8)
        for finger in ['Pinky','Ring','Mid','Index','Thumb']:
            for joint in [1,2]:
                name = side+'_'+finger+str(joint)
                limb(name,side+'_'+finger+str(joint+1),.007,.006,5)
            tip = rig.data.bones[side+'_'+finger+'3']
            ellipsoid((tip.head_local+tip.tail_local)*.5,(.007,.007,.009),5,tip.name,3,6)

    neck_points, neck_weights = [], []
    for z,bone in [(.75,'Spine02'),(.82,'Head'),(.88,'Head')]:
        for i in range(8):
            theta = math.tau*i/8
            neck_points.append((.015+.035*math.cos(theta),.005+.035*math.sin(theta),z))
            neck_weights.append({bone:1})
    add(neck_points,[(j*8+i,j*8+(i+1)%8,(j+1)*8+(i+1)%8,(j+1)*8+i) for j in range(2) for i in range(8)],5,neck_weights)
    # Faceted head, a visible nose, two eyes and a shaped hair cap.
    ellipsoid((.037,.005,.892),(.117,.120,.135),5,'Head',7,12)
    cuboid((.154,.005,.889),(.028,.032,.034),5,'Head')
    for sign in [-1,1]:
        cuboid((.145,.005+sign*.048,.922),(.014,.024,.020),7,'Head')
        cuboid((.147,.005+sign*.048,.941),(.015,.034,.009),6,'Head')
        ellipsoid((.025,.005+sign*.122,.894),(.028,.018,.034),5,'Head',4,8)
    cuboid((.147,.005,.855),(.013,.037,.008),7,'Head')
    # Cap rings end above the eyes; back hair stays behind the neck.
    cap_points = []
    for height,rx,ry in [(.932,.117,.123),(.989,.096,.108),(1.025,.05,.055)]:
        for i in range(12):
            theta = math.tau*i/12
            cap_points.append((.026+rx*math.cos(theta),.005+ry*math.sin(theta),height))
    cap_faces = [(j*12+i,j*12+(i+1)%12,(j+1)*12+(i+1)%12,(j+1)*12+i) for j in range(2) for i in range(12)]
    cap_faces.append(tuple(range(24,36)))
    add(cap_points,cap_faces,6,'Head')
    for x,y,z in [(.102,-.055,.976),(.112,.015,.970),(.075,.075,.995),(-.045,.0,.995)]:
        ellipsoid((x,y,z),(.05,.045,.047),6,'Head',3,7)

    data = bpy.data.meshes.new('PixelRPGBody')
    data.from_pydata(vertices,[],faces)
    data.update()
    obj = bpy.data.objects.new('PixelRPGBody',data)
    bpy.context.scene.collection.objects.link(obj)
    for mat in materials:
        data.materials.append(mat)
    for face, mat in zip(data.polygons,face_materials):
        face.material_index = mat
        face.use_smooth = False
    groups = {name:obj.vertex_groups.new(name=name) for name in {key for row in bindings for key in row}}
    for index,row in enumerate(bindings):
        for name,weight in row.items():
            groups[name].add([index],weight,'REPLACE')
            rig.data.bones[name].use_deform = True
    deform = obj.modifiers.new('SkeletonDeform','ARMATURE')
    deform.object = rig
    obj.parent = rig
    return obj
