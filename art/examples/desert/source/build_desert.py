"""Generate the painted desert raft in Godot world coordinates (+Y up, +Z toward camera).
Run with Blender --background --python examples/desert/source/build_desert.py.
"""
import json
import math
import random
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
OUT = ROOT.parent
V = Vector
UP = V((0,1,0))
rng = random.Random(41706)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

palette_material = bpy.data.materials.new("Camp palette · face colours")
palette_material.use_nodes = True
nodes = palette_material.node_tree.nodes
shader = nodes.get("Principled BSDF")
shader.inputs['Roughness'].default_value = .97
shader.inputs['Specular IOR Level'].default_value = .12
attribute = nodes.new('ShaderNodeVertexColor')
attribute.layer_name = 'Paint'
palette_material.node_tree.links.new(attribute.outputs['Color'], shader.inputs['Base Color'])
parts = {}

class Part:
    def __init__(self, name):
        self.name = name
        self.vertices, self.polygons, self.paint = [], [], []
        parts[name] = self
    def face(self, points, color, inside=None):
        points = [V(p) for p in points]
        if inside is not None:
            normal = (points[1]-points[0]).cross(points[2]-points[0])
            if normal.dot(points[0]-V(inside)) < 0:
                points.reverse()
        i = len(self.vertices)
        self.vertices.extend((p.x,-p.z,p.y) for p in points)
        self.polygons.append(list(range(i,i+len(points))))
        self.paint.append(color)
    def finish(self):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata(self.vertices, [], self.polygons)
        mesh.update()
        obj = bpy.data.objects.new(self.name,mesh)
        bpy.context.collection.objects.link(obj)
        mesh.materials.append(palette_material)
        colors = mesh.color_attributes.new(name='Paint',type='BYTE_COLOR',domain='CORNER')
        values = {}
        for poly, code in zip(mesh.polygons,self.paint):
            if code not in values:
                values[code] = tuple(int(code[j:j+2],16)/255 for j in (0,2,4)) + (1.0,)
            for loop in poly.loop_indices:
                colors.data[loop].color_srgb = values[code]
        return sum(len(f)-2 for f in self.polygons)

def yaw(p,a):
    x,y,z = p
    return V((x*math.cos(a)+z*math.sin(a), y, -x*math.sin(a)+z*math.cos(a)))

def box(part,p,size,color,angle=0):
    p=V(p)
    corners=[p+yaw((x*size[0]/2,y*size[1]/2,z*size[2]/2),angle)
             for x,y,z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    for face in [[0,1,2,3],[4,5,6,7],[0,3,7,4],[1,2,6,5],[0,4,5,1],[3,2,6,7]]:
        part.face([corners[i] for i in face],color,p)

def taper(part,a,b,ra,rb,color,n=7):
    a,b=V(a),V(b);axis=(b-a).normalized()
    u=axis.cross(UP if abs(axis.y)<.96 else V((1,0,0))).normalized()
    v=axis.cross(u)
    rings=[[p+(math.cos(i*math.tau/n)*u + math.sin(i*math.tau/n)*v)*r for i in range(n)] for p,r in [(a,ra),(b,rb)]]
    inside=(a+b)*.5
    for i in range(n):
        j=(i+1)%n
        part.face([rings[0][i],rings[0][j],rings[1][j],rings[1][i]],color,inside)
    part.face(rings[0],color,inside)
    part.face(rings[1],color,inside)

def polyrock(part,base,dims,col,n=7):
    """Broken bedding planes, irregular roof and bevelled foot."""
    base=V(base); w,h,d=dims
    offset=rng.uniform(0,math.tau)
    radii=[rng.uniform(.82,1.13) for i in range(n)]
    bend=rng.uniform(-.1,.1)
    rings=[]
    for y,s in [(-.04,.84),(.19,1.0),(.80,.90),(1,.70)]:
        ring=[]
        for i in range(n):
            a=i*math.tau/n+offset
            ring.append(base+V(((math.cos(a)*radii[i]*s*.5+bend*y)*w,
                                (y+rng.uniform(-.06,.06))*h,math.sin(a)*radii[i]*d*s*.5)))
        rings.append(ring)
    inside=base+UP*h*.4
    for low,high in zip(rings,rings[1:]):
        for i in range(n):
            j=(i+1)%n
            part.face([low[i],low[j],high[j]],col,inside)
            part.face([low[i],high[j],high[i]],col,inside)
    peak=base+V((w*.02,h*1.025,d*.05))
    for i in range(n):
        part.face([rings[-1][i],rings[-1][(i+1)%n],peak],col,inside)

def ellipsoid(part,p,scale,col,rings=4,n=9):
    p=V(p);sx,sy,sz=scale
    sections=[]
    for j in range(1,rings):
        lat=-math.pi/2+j*math.pi/rings
        sections.append([p+V((sx*math.cos(lat)*math.cos(i*math.tau/n),
                              sy*math.sin(lat),sz*math.cos(lat)*math.sin(i*math.tau/n))) for i in range(n)])
    for i in range(n):
        j=(i+1)%n
        part.face([p-UP*sy,sections[0][i],sections[0][j]],col,p)
        part.face([p+UP*sy,sections[-1][i],sections[-1][j]],col,p)
    for low,high in zip(sections,sections[1:]):
        for i in range(n):
            j=(i+1)%n;part.face([low[i],low[j],high[j],high[i]],col,p)

def height(x,z):
    return .045*math.sin(x*.54+z*.12) + .045*math.cos(z*.74-x*.21)

ground=Part("01 | Sand and valley floor")
for zi in range(-18,11):
    for xi in range(-16,17):
        x,z=xi*1.8,zi*1.8
        corners=[(a,height(a,b),b) for a,b in [(x,z),(x+1.8,z),(x+1.8,z+1.8),(x,z+1.8)]]
        for face in [[0,1,2],[0,2,3]]:
            ground.face([corners[i] for i in face],"cbb08f",(x,-10,z))

cliff=Part("02 | Painted sandstone and distant mesas")
def ridge(trace,depth,colors,thickness):
    data=[]
    for x,y in trace:
        front=depth+rng.uniform(-1.0,1.0)
        data.append((V((x,-.2,front+2)),V((x+.5,y*.60,front+.6)),V((x,y,front)),V((x-.7,y*.86,front-thickness))))
    for i in range(len(data)-1):
        for j in range(3):
            a,b,c,d=data[i][j],data[i+1][j],data[i+1][j+1],data[i][j+1]
            for triangle in [[a,b,c],[a,c,d]]:
                cliff.face(triangle,colors[(i+j)%len(colors)],(a.x,-10,depth-7))
ridge([(-24,11),(-15,11),(-10,8.5),(-6.6,6.2),(-2,3.15),(1.2,2.5),(3.8,.42),(8,.4),(18,1.25)],-12,
      ["a99e87","958c7c","b9aa90","ab9f87"],5)
for pos,dims,col in [
    ((-9.0,0,-5.8),(6,8.7,4.4),"917266"),
    ((-5.9,0,-4.1),(3.25,2.70,3),"db9a53"),
    ((-4.1,0,-4.7),(2.8,2.20,2.5),"b68e76"),
    ((-2.9,0,-5.3),(1.95,3.10,2.3),"ddb273"),
    ((-6.9,0,-4.0),(2.10,1.61,2.1),"edbb67"),
    ((-3.4,0,-3.7),(1.46,1.02,1.2),"d4ab70"),
    ((7.2,0,-4.35),(2.25,2.8,2.4),"b0b2b3"),
    ((8.7,0,-4.65),(3.0,3.38,3.1),"a8aaae"),
    ((5.8,0,-3.9),(1.21,1.40,1.65),"c4c5c1"),
    ((4.95,0,-5.9),(1.1,.77,1.50),"d2bd98")]:
    polyrock(cliff,pos,dims,col)
stones=Part("03 | Loose stones and pebbles")
for i in range(65):
    x,z=rng.uniform(-7,8),rng.uniform(-6,4)
    if (-1.3<x<1.4 and -1.5<z<1.6) or (-2.1<x<1.8 and z>1.9): continue
    w=rng.uniform(.08,.44)
    polyrock(stones,(x,height(x,z)-.035,z),(w*1.2,w*.58,w),rng.choice(["b8a28f","b3a8a0","dec39b","ab9a93"]),5)
polyrock(stones,(-.91,height(-.91,4.95)-.18,4.95),(.73,.50,.64),"9c9295",7)
polyrock(stones,(2.40,height(2.4,4.05)-.1,4.05),(.91,.42,.85),"c3b6a7",7)

RAFT_ANGLE=math.radians(-32)
def raft(p):
    pt=yaw(p,RAFT_ANGLE)
    return V((pt.x*.81-.055,.26+(pt.y-.26)*.89,pt.z-.10))
def board(part,p,size,col,turn=0):
    local = [V(p)+yaw((dx*size[0]*.5,dy*size[1]*.5,dz*size[2]*.5),turn)
             for dx,dy,dz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    for face in [[0,1,2,3],[4,5,6,7],[0,3,7,4],[1,2,6,5],[0,4,5,1],[3,2,6,7]]:
        part.face([raft(local[i]) for i in face],col,raft(p))
def post(part,a,b,r,s,col,n=7): taper(part,raft(a),raft(b),r,s,col,n)

deck=Part("04 | Lashed timber raft")
for i in range(7):
    x=-.98+i*.33; length=3.64+rng.uniform(-.15,.15); y=.17+rng.uniform(0,.04)
    board(deck,(x,y,0),(.307,.24,length),["d8873d","ecac52","c87937","e09945","edb75c","d99441","ce7f35"][i])
    for nail_z in [-1.30,1.25]:
        post(deck,(x,y+.115,nail_z),(x,y+.13,nail_z),.023,.020,"8b5d43",6)
for z in [-1.31,1.22]:
    board(deck,(0,.11,z),(2.22,.15,.16),"996331")
    for side in [-1,1]:
        for r in range(3):
            post(deck,(side*1.06,.055,z-.052+.042*r),(side*1.06,.305,z-.052+.042*r),.022,.023,"bd9763",5)
hut=Part("05 | Painted cabin and upturned eaves")
# Back weatherboards, with a narrow slit of daylight between the uneven boards.
for i,col in enumerate(["9a9824","165d4f","ca902c","a49928","6c5a2e","aa7a24"]):
    board(hut,(-.72+i*.28,1.18,-.94),(.274,1.76+rng.uniform(-.09,.07),.085),col)
for side in [-1,1]:
    for i,col in enumerate(["f9b82c","e18c26","c94035","ac2260","d74339"]):
        board(hut,(side*.82,1.18,-.86+i*.22),(.09,1.75,.215),col if side>0 else ["4e7856","a3a341","87852d","7d9731","b3a62f"][i])
for x,col in [(-.78,"157cad"),(.78,"1383b3")]:
    post(hut,(x,.28,.29),(x+.026,2.13,.27),.085,.079,col,4)
board(hut,(0,.86,-.46),(1.25,.085,.37),"207e78")
board(hut,(-.46,.54,-.46),(.095,.62,.13),"205e53")
board(hut,(.46,.54,-.46),(.095,.62,.13),"205e53")
# Roof boards have subtly different lengths; the front board curls upward at both ends.
for i,col in enumerate(["e56831","ff4c2d","eb323b","f74731","ee3e47","ec3170"]):
    board(hut,(.03,2.12+.014*i,-1.05+.25*i),(2.18+rng.uniform(-.08,.09),.10,.258),col)
for z in [.33,-1.17]:
    coords=[(-1.14,2.34),(-.93,2.22),(-.47,2.16),(.38,2.17),(.87,2.20),(1.12,2.38),
            (1.12,2.12),(.95,2.03),(-.92,2.02),(-1.14,2.07)]
    # Side fascia is dark indigo with a warm strip under the high lip.
    hut.face([raft((x,y,z)) for x,y in coords],"183e63")
    for i in range(len(coords)):
        j=(i+1)%len(coords)
        hut.face([raft((coords[k][0],coords[k][1],zf)) for k,zf in [(i,z),(j,z),(j,z-.08),(i,z-.08)]],"20608a")
# Side blossoms painted on the sunlit planks.
for y,z,rad in [(1.04,-.44,.171),(1.55,.05,.112)]:
    for i in range(5):
        a=math.tau*i/5
        ellipsoid(hut,raft((.877,y+math.cos(a)*rad,z+math.sin(a)*rad)),(.043,rad*.60,rad*.62),"ff9d32",3,7)
    ellipsoid(hut,raft((.895,y,z)),(.037,rad*.47,rad*.44),"efce46",3,7)
    post(hut,(.88,y-rad*.5,z),(.88,y-.33,z+.11),.016,.014,"6b9635",4)
    hut.face([raft((.884,y-.23,z+.07)),raft((.884,y-.19,z+.23)),raft((.884,y-.06,z+.26))],"63a244")

living=Part("06 | Bucket, mast and oar")
for a,b,w,ww in [((-1.69,0,.58),(-1.52,1.09,.48),.145,.095),
                 ((-1.52,1.09,.48),(-1.17,1.51,.43),.098,.076),
                 ((-1.17,1.51,.43),(-.98,1.43,.39),.076,.053)]:
    taper(living,a,b,w,ww,"ba8a54",6)
bucket=V((-.74,.95,.42))
taper(living,bucket-UP*.25,bucket+UP*.17,.218,.277,"362e2c",9)
taper(living,bucket+UP*.175,bucket+UP*.195,.29,.29,"231f20",10)
taper(living,bucket+UP*.196,bucket+UP*.198,.247,.247,"1b1618",10)
prev=None
for i in range(10):
    a=math.pi*i/9
    point=bucket+V((math.cos(a)*.24,.16+math.sin(a)*.365,0))
    if prev is not None:taper(living,prev,point,.019,.019,"4d3e32",5)
    prev=point
taper(living,(-1.09,1.44,.39),(-.74,1.49,.42),.035,.03,"84613d")
taper(living,(-1.88,.06,.30),(-2.24,2.48,-.10),.032,.021,"a27547")
taper(living,(1.21,.19,-.63),(1.64,4.43,-.75),.047,.037,"bf7e36")
taper(living,(.61,.98,-.39),(2.88,.17,.85),.047,.058,"d59343",6)
paddle=[(2.69,.24,.75),(2.89,.25,.74),(3.16,.14,1.00),(3.08,.095,1.13),(2.82,.137,.94)]
living.face(paddle,"eb5331")
living.face([V(p)-UP*.034 for p in reversed(paddle)],"c84732")
# Hand-shaped flag: longitudinal folds converge at a ragged fly with three cutouts.
fabric=Part("07 | Torn sail and clothesline")
xs=[0,.29,.65,1.0,1.31,1.61]
top=[4.30,4.34,4.20,4.37,4.46,4.60]
bottom=[2.78,2.84,2.72,2.98,3.04,3.38]
front=[-.72,-.51,-.77,-.93,-.67,-.61]
for i in range(len(xs)-1):
    wave=lambda j,y: V((1.54+xs[j],y,front[j]))
    if i == 4:
        # Pointed tails split by a deep notch in the worn cloth.
        for corners in [[wave(i,bottom[i]),wave(i+1,bottom[i+1]),wave(i+1,3.49),wave(i,3.30)],
                         [wave(i,3.62),wave(i+1,3.88),wave(i+1,top[i+1]),wave(i,top[i])]]:
            fabric.face(corners,"fff6de")
    else:
        fabric.face([wave(i,bottom[i]),wave(i+1,bottom[i+1]),wave(i+1,top[i+1]),wave(i,top[i])],
                    ["fff3d7","fffaf0","f5e9cf","fff7e8"][i])
taper(living,(3.28,0,.04),(3.66,1.95,-.39),.039,.035,"a0723f")
def on_line(t):
    return V((1.40+2.24*t,1.99-.04*t-.68*4*t*(1-t),-.7+.32*t))
for i in range(18):
    taper(fabric,on_line(i/18),on_line((i+1)/18),.012,.012,"7d614f",5)
def shirt(t,col,fold):
    p=on_line(t)
    silhouette=[(-.10,0),(-.18,-.052),(-.22,-.22),(-.15,-.24),(-.11,-.16),(-.10,-.56),(.11,-.57),(.15,-.18),(.20,-.24),(.24,-.18),(.17,-.041),(.09,-.012),(.045,-.061),(-.029,-.062)]
    mid=p+V((0,-.21,.04))
    for i,(x,y) in enumerate(silhouette):
        x2,y2=silhouette[(i+1)%len(silhouette)]
        fabric.face([mid,p+V((x,y,abs(x)*.3)),p+V((x2,y2,abs(x2)*.3))],fold if i in [2,4,8,10] else col)
    for x in [-.10,.10]:
        taper(fabric,p+V((x,-.01,.032)),p+V((x+.02,.056,.038)),.011,.011,"deb54e",4)
shirt(.16,"f52e30","d53837")
shirt(.43,"287da9","286f91")
shirt(.69,"fff3d0","eadabb")

gull=Part("08 | Roof gull")
# White bird, dark folded wing, ochre beak, red feet and tapered black tail.
g=V((.46,2.21,-.11))
ellipsoid(gull,g+V((.02,.10,0)),(.245,.105,.115),"ece7d7",4,8)
ellipsoid(gull,g+V((-.15,.20,.015)),(.102,.192,.093),"fff6e6",4,8)
ellipsoid(gull,g+V((-.165,.34,.014)),(.115,.095,.098),"fff7e4",4,8)
taper(gull,g+V((-.10,.34,.043)),g+V((-.025,.333,.043)),.040,.005,"e5994e",6)
ellipsoid(gull,g+V((-.125,.360,.108)),(.016,.016,.011),"322b33",3,6)
gull.face([g+V(o) for o in [(-.125,.18,.119),(.02,.185,.134),(.235,.047,.091),(.055,.008,.128)]],"292a34")
gull.face([g+V(o) for o in [(.16,.122,.05),(.40,.056,.016),(.38,.012,-.032),(.14,.052,-.06)]],"302e38")
for xx in [-.05,.045]:
    taper(gull,g+V((xx,.025,0)),g+V((xx+.009,-.145,.012)),.013,.015,"ec654a",5)
    taper(gull,g+V((xx+.009,-.145,.012)),g+V((xx-.064,-.151,.075)),.012,.005,"e86f50",5)

plants=Part("09 | Cacti and brittle desert shrubs")
def cactus(x,z,h,col):
    base=V((x,height(x,z),z))
    taper(plants,base,base+UP*h,.10*h,.065*h,col,7)
    taper(plants,base+UP*h,base+UP*(h*1.07),.065*h,.010*h,col,7)
    for side,level in [(-1,.53),(1,.27)]:
        off=V((side*.16*h,level*h+.11*h,.014))
        taper(plants,base+UP*level*h,base+off,.055*h,.047*h,col,6)
        taper(plants,base+off,base+off+UP*.23*h,.05*h,.034*h,col,6)
        taper(plants,base+off+UP*.23*h,base+off+UP*.255*h,.034*h,.01*h,col,6)
for a in [(-4.17,-2.3,.8,"919332"),(3.13,-.87,1.58,"859238"),(6.69,-1.25,2.12,"9d9b33"),(4.37,-4.54,.81,"9b9d38"),(-6.0,-5.5,.65,"a49b44")]: cactus(*a)
def dry_plant(x,z,scale,col):
    base=V((x,height(x,z),z))
    for j in range(9):
        a=j*math.tau/9+rng.uniform(-.2,.2)
        dx=V((math.cos(a),0,math.sin(a))); width=V((-math.sin(a),0,math.cos(a)))
        h=scale*rng.uniform(.45,1.0); mid=base+dx*.25*h+UP*.48*h
        end=base+dx*.62*h+UP*.85*h
        plants.face([base,mid-width*.075*h,end,mid],col)
        plants.face([base,mid,end,mid+width*.075*h],rng.choice(["ac793e","c38a47","9b7638"]))
for x,z,h in [(-3.8,1.1,.63),(-2.45,3.1,.67),(-1.83,1.98,.39),(-1.47,3.18,.29),(3.29,2.48,.70),(4.3,.52,.58)]:
    dry_plant(x,z,h,"bb833b")

grass=Part("10 | Golden meadow")
shades=["deaa3d","e7b940","f6c94b","cd9f32","f9d265","d6a939","ecc55b"]
def tuft(x,z,h):
    base=V((x,height(x,z)-.015,z))
    for j in range(rng.randrange(4,7)):
        a=rng.uniform(0,math.tau)
        side=V((math.cos(a),0,math.sin(a)))
        forward=V((-math.sin(a),0,math.cos(a)))
        start=base+side*rng.uniform(-.08,.08)+forward*rng.uniform(-.05,.05)
        tall=h*rng.uniform(.63,1.18)
        tip=start+UP*tall+forward*rng.uniform(.045,.17)
        width=rng.uniform(.031,.064)
        ridge=start+forward*.016+UP*tall*.035
        grass.face([start-side*width,ridge,tip],rng.choice(shades))
        grass.face([ridge,start+side*width,tip],rng.choice(shades))
# Patch ellipses leave a sandy winding opening left of the raft and below the camera.
for cx,cz,rx,rz,count in [(2.4,1.30,3.5,1.50,2100),(-.93,.59,1.88,.70,630),
                            (.42,1.91,1.15,.83,480),(1.5,-2.4,6.2,.93,930),
                            (-5.3,-1.75,2.45,.71,630),(4.4,-5.3,3.5,.60,420)]:
    for i in range(count):
        a=rng.random()*math.tau;r=math.sqrt(rng.random())
        x=cx+rx*r*math.cos(a);z=cz+rz*r*math.sin(a)
        if abs(x)<.6 and -.8<z<.8: continue
        tuft(x,z,rng.uniform(.14,.35))

stump=Part("11 | Foreground driftwood")
taper(stump,(-1.43,-.10,4.85),(-1.62,.42,5.03),.17,.095,"a96c36")
taper(stump,(-1.62,.42,5.03),(-1.97,1.06,5.17),.096,.042,"965c32")
taper(stump,(-1.55,.29,4.98),(-1.26,.43,4.92),.068,.026,"c58548")
# A taller branch just outside the capture frame throws a diagonal shadow across the sand.
taper(stump,(-2.27,-.10,4.68),(-2.32,1.62,4.71),.15,.09,"956d45")
taper(stump,(-2.32,1.62,4.71),(-2.12,2.35,4.72),.09,.046,"ac8052")
taper(stump,(-2.22,2.14,4.72),(-1.99,2.21,4.84),.053,.027,"ab7950")

counts={name:part.finish() for name,part in parts.items()}
bpy.context.scene.unit_settings.system='METRIC'
bpy.context.scene.unit_settings.scale_length=1
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'desert_camp.blend'),compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'desert_camp.glb'),export_format='GLB',export_yup=True,
                          export_materials='EXPORT',export_apply=True)
(ROOT/'mesh_counts.json').write_text(json.dumps(counts,indent=2)+'\n')
print("Desert source faces after triangulation:",sum(counts.values()))
