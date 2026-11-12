"""Build the editable forest clearing as a glTF 2.0 binary. Run with Python 3 + NumPy."""
import json
import math
import random
import struct
from pathlib import Path

import numpy as np

OUT = Path(__file__).resolve().parent
SEED = 150516
rng = random.Random(SEED)
TAU = math.tau
HOUSE_YAW = math.radians(13.4)
V = lambda *v: np.array(v, dtype=float)
UP = V(0, 1, 0)


def rgb(code):
    return np.array(list(bytes.fromhex(code.removeprefix("#"))), dtype=float) / 255


def mix(a, b, t):
    return a*(1-t) + b*t


def unit(vec):
    return vec / max(float(np.linalg.norm(vec)), 0.000001)


def circle(a):
    return V(math.cos(a), 0, math.sin(a))


def color_linear(value):
    x = np.clip(value[:3], 0, 1)
    return np.where(x <= 0.04045, x/12.92, ((x+0.055)/1.055)**2.4)


class Geo:
    def __init__(self):
        self.pos, self.norm, self.col, self.ids = [], [], [], []

    def poly(self, points, colors, normal=None):
        coords = np.array(points)
        n = unit(np.cross(coords[1]-coords[0], coords[2]-coords[0])) if normal is None else normal
        first = len(self.pos)
        self.pos.extend(coords)
        self.norm.extend([n]*len(coords))
        self.col.extend([colors]*len(coords) if np.ndim(colors) == 1 else colors)
        for i in range(1, len(coords)-1):
            self.ids.extend([first, first+i, first+i+1])


class Document:
    def __init__(self):
        self.binary = bytearray()
        self.data = dict(asset={"version":"2.0","generator":"Forest Clearing authored geometry"},
                         extensionsUsed=["KHR_materials_unlit"], buffers=[], bufferViews=[], accessors=[],
                         meshes=[], nodes=[], scenes=[{"nodes":[]}], scene=0, materials=[])
        for name, unlit, alpha in [("MattePaint",False,False),("LeafPigments",True,False),("SmokeWash",True,True)]:
            mat = {"name":name,"doubleSided":True,"pbrMetallicRoughness":{"metallicFactor":0,"roughnessFactor":1}}
            if unlit: mat["extensions"] = {"KHR_materials_unlit":{}}
            if alpha: mat["alphaMode"] = "BLEND"
            self.data["materials"].append(mat)

    def accessor(self, array, component, arity, kind, bounds=False):
        while len(self.binary)%4:
            self.binary.append(0)
        start = len(self.binary)
        self.binary.extend(array.tobytes())
        view = {"buffer":0,"byteOffset":start,"byteLength":array.nbytes,"target":34963 if kind=="SCALAR" else 34962}
        self.data["bufferViews"].append(view)
        acc = {"bufferView":len(self.data["bufferViews"])-1,"componentType":component,"type":kind,"count":array.size//arity}
        if component==5121: acc["normalized"] = True
        if bounds:
            acc.update(min=array.min(axis=0).tolist(),max=array.max(axis=0).tolist())
        self.data["accessors"].append(acc)
        return len(self.data["accessors"])-1

    def mesh(self, g, name, mat=0):
        verts = np.array(g.pos,dtype="<f4")
        rgb_as = np.asarray(g.col)
        colors = np.clip(rgb_as[:,:3],0,1)
        colors = np.where(colors<=.04045, colors/12.92, ((colors+.055)/1.055)**2.4)
        if rgb_as.shape[1] == 4:
            colors = np.c_[colors, rgb_as[:,3]]
        color_bytes = np.rint(np.clip(colors,0,1)*255).astype("u1")
        attrs = {"POSITION":self.accessor(verts,5126,3,"VEC3",True),
                 "NORMAL":self.accessor(np.array(g.norm,dtype="<f4"),5126,3,"VEC3"),
                 "COLOR_0":self.accessor(color_bytes,5121,colors.shape[1],f"VEC{colors.shape[1]}")}
        primitive={"indices":self.accessor(np.array(g.ids,dtype="<u4"),5125,1,"SCALAR"),"attributes":attrs,"material":mat}
        self.data["meshes"].append({"name":name,"primitives":[primitive]})
        return len(self.data["meshes"])-1

    def place(self, mesh, name, translation=(0,0,0), yaw=0, scale=(1,1,1)):
        self.data["scenes"][0]["nodes"].append(len(self.data["nodes"]))
        self.data["nodes"].append(dict(name=name,mesh=mesh,translation=list(translation),
                                       rotation=[0,math.sin(yaw/2),0,math.cos(yaw/2)],scale=list(scale)))

    def finish(self, path):
        while len(self.binary)%4: self.binary.append(0)
        self.data["buffers"]=[{"byteLength":len(self.binary)}]
        metadata=json.dumps(self.data,separators=(",",":")).encode()
        metadata+=b" " * ((-len(metadata))%4)
        path.write_bytes(struct.pack("<4sII",b"glTF",2,28+len(metadata)+len(self.binary))+
                         struct.pack("<I4s",len(metadata),b"JSON")+metadata+
                         struct.pack("<I4s",len(self.binary),b"BIN\x00")+self.binary)


def box(g, center, dims, color):
    x,y,z=center
    w,h,d=np.array(dims)/2
    faces=[[(x-w,y-h,z+d),(x+w,y-h,z+d),(x+w,y+h,z+d),(x-w,y+h,z+d)],
           [(x+w,y-h,z-d),(x-w,y-h,z-d),(x-w,y+h,z-d),(x+w,y+h,z-d)],
           [(x+w,y-h,z+d),(x+w,y-h,z-d),(x+w,y+h,z-d),(x+w,y+h,z+d)],
           [(x-w,y-h,z-d),(x-w,y-h,z+d),(x-w,y+h,z+d),(x-w,y+h,z-d)],
           [(x-w,y+h,z+d),(x+w,y+h,z+d),(x+w,y+h,z-d),(x-w,y+h,z-d)],
           [(x-w,y-h,z-d),(x+w,y-h,z-d),(x+w,y-h,z+d),(x-w,y-h,z+d)]]
    for face in faces: g.poly(face,color)


def beam(g, p0, p1, width0, width1, clr, sides=6):
    a,b=np.array(p0),np.array(p1)
    axis=unit(b-a)
    x=unit(np.cross(axis, V(.03,.06,1)))
    z=unit(np.cross(axis,x))
    rim=[x*math.cos(TAU*i/sides)+z*math.sin(TAU*i/sides) for i in range(sides)]
    for i in range(sides):
        v,w=rim[i-1],rim[i]
        g.poly([a+v*width0,a+w*width0,b+w*width1,b+v*width1],clr*(.96+.04*i/sides))
    g.poly([b+v*width1 for v in rim],clr)


def ellipsoid(g, center, rad, clr, segments=9, rings=5, rough=.04, shades=0):
    center,rad=np.array(center),np.array(rad)
    norms=[]; coords=[]
    for j in range(rings+1):
        line=[];points=[]
        elev=(j/rings-.5)*math.pi
        for i in range(segments):
            theta=(i + 0.3*(j%2))*TAU/segments
            n=V(math.cos(elev)*math.cos(theta),math.sin(elev),math.cos(elev)*math.sin(theta))
            line.append(n)
            points.append(center+rad*n*(1+rng.uniform(-rough,rough)))
        coords.append(points);norms.append(line)
    for j in range(rings):
        for i in range(segments):
            k=(i+1)%segments
            idx=[(j,i),(j+1,i),(j+1,k),(j,k)]
            if j==0:idx=idx[:3]
            if j==rings-1:idx=[idx[0],idx[2],idx[3]]
            n=unit(np.mean([norms[y][x] for y,x in idx],axis=0))
            fac=.82+.28*n.dot(V(-.45,.82,.34))
            col=clr*(1-shades+fac*shades)
            g.poly([coords[y][x] for y,x in idx],col,n)


def house():
    class RoofSurface(Geo):
        def poly(self, points, colors, normal=None):
            if normal is not None:
                vertices=np.asarray(points)
                if np.cross(vertices[1]-vertices[0],vertices[2]-vertices[0]).dot(normal)<0:
                    points=vertices[::-1]
                    if np.ndim(colors)>1:colors=colors[::-1]
            super().poly(points,colors,normal)

    wall, roof, detail=Geo(),RoofSurface(),Geo()
    masonry, balcony, dormers, stoop = Geo(), Geo(), RoofSurface(), Geo()
    hand = random.Random(5293)
    timber=rgb("646169"); plaster=rgb("c0848b"); stone=rgb("817c74")
    def chip_stone(g, x, y, z, width, thick, depth, hue, spin=0.):
        top, bottom = [], []
        for side in range(9):
            a=spin+TAU*side/9
            dx=math.copysign(abs(math.cos(a))**.65,math.cos(a))*width*.5
            dz=math.copysign(abs(math.sin(a))**.66,math.sin(a))*depth*.5
            rim=V(x+dx,y+hand.uniform(-.014,.014),z+dz)
            top.append(rim)
            bottom.append(rim-V(0,thick,0))
        g.poly(top[::-1],hue,UP)
        for i in range(9):
            g.poly([bottom[i-1],bottom[i],top[i],top[i-1]],hue*hand.uniform(.83,.92))

    def facade_pigment(u,v):
        # Preserve the dusty pink even in shade. Sparse cool runs mark old
        # lime and algae where the posts meet the splash zone.
        fleck=.5+.5*math.sin(u*9.1+v*3.2)*math.cos(v*12.3-u*4.6)
        weather=.5+.5*math.cos(u*3.17-v*.82+.38*math.sin(v*3.1))
        waterline=.34+.18*math.sin(u*2.4+.9)
        damp=.53*math.exp(-((v-waterline)/.33)**2)
        joint=min(abs(u-x) for x in (-2.46,-1.44,-.31,1.32,2.43))
        drip=.20*math.exp(-(joint/.20)**2)*(.61+.39*math.sin(v*5.2+u*.9))
        wash=mix(rgb("b47e7a"),rgb("cd918d"),.21+.66*weather)
        wash=mix(wash,rgb("c3a797"),.12*fleck)
        return mix(wash,rgb("738080"),min(.55,damp+drip+.045*fleck))
    box(wall,(0,.22,0),(5.1,.45,4.15),stone)
    box(wall,(0,1.50,0),(4.97,2.48,4.1),plaster)
    for x in [-2.48,2.48]:
        wall.poly([(x,2.73,-2.05),(x,2.73,2.05),(x,5.42,-.12)],plaster)
    # A continuous limewash interpolates across the warm front panels.
    for j in range(9):
        for i in range(23):
            x0=-2.481+i*4.962/23; x1=x0+4.962/23
            y0=.265+j*2.47/9; y1=y0+2.47/9
            v=[(x0,y0,2.054),(x1,y0,2.054),(x1,y1,2.054),(x0,y1,2.054)]
            wall.poly(v,[facade_pigment(x,y) for x,y,_ in v],V(0,0,1))
    for x in [-2.46,-1.44,-.31,1.32,2.43]:
        box(detail,(x,1.56,2.077),(.113,2.53,.120),timber)
    for y in [.39,2.65]:
        box(detail,(0,y,2.077),(5.05,.12,.13),timber)
    for x in [-2.52,2.52]:
        for z in [-1.92,-.15,1.92]:
            box(detail,(x,1.48,z),(.12,2.49,.12),timber)
        for y in [.40,2.55]:
            box(detail,(x,y,0),(.12,.12,4.25),timber)
        beam(detail,(x,.47,-1.66),(x,2.43,-.5),.078,.072,timber,4)
    for x,dx,y0,y1 in [(-2.36,.91,1.02,.42),(-.81,.50,.45,1.96),(1.19,-.45,.48,1.82)]:
        beam(detail,(x,y0,2.13),(x+dx,y1,2.13),.086,.074,timber,4)
    # Recessed front door has planks, a top light and a little wrought-iron handle.
    box(detail,(.54,1.35,2.107),(1.06,2.05,.104),rgb("444d50"))
    for i in range(7):
        box(detail,(.112+i*.143,1.30,2.167),(.138,1.82,.038),
            rgb(["49585b","4c595c","505e60","4a575b","505c60","4c595d","4e595a"][i]))
    box(detail,(.84,1.26,2.208),(.088,.037,.031),rgb("88806a"))
    box(detail,(.52,2.31,2.144),(1.09,.104,.13),rgb("525755"))
    # The little white upper window and dark left shutter sit tight under the eaves.
    for x,y,w,h in [(-1.87,2.35,.50,.45),(2.00,2.42,.74,.51)]:
        box(detail,(x,y,2.108),(w+.10,h+.095,.080),timber)
        light=rgb("a3a5a1") if x>0 else rgb("636e73")
        box(detail,(x,y,2.158),(w,h,.025),light)
        for offset in [-w*.20,w*.21]:
            box(detail,(x+offset,y,2.181),(.027,h,.027),rgb("727575"))
        box(detail,(x,y-h*.50-.033,2.160),(w+.15,.042,.14),rgb("777776"))
    # Individual overlapping slate courses preserve the dark roof silhouette.
    for sign in [-1,1]:
        ridge=V(0,5.53,-.12)
        eave=V(0,2.63,sign*2.45)
        slope=eave-ridge
        upward=unit(V(0,abs(slope[2]),-slope[1]*sign))
        roof.poly([ridge+V(-2.85,0,0),ridge+V(2.85,0,0),eave+V(2.85,0,0),
                  eave+V(-2.85,0,0)],rgb("45515d"),upward)
        for row in range(15):
            cells=22
            offset=(-.5 if row%2 else 0)
            for col in range(cells+1):
                x0=max(-2.83,-2.83+(col+offset)*5.66/cells)
                x1=min(2.83,-2.83+(col+offset+1)*5.66/cells-.013)
                if x1<=x0:continue
                t0=max(0,row/15-.006);t1=min(1,(row+1)/15+rng.uniform(-.002,.003))
                lift=.017+hand.uniform(.001,.012)
                def tile(x,t,dh):
                    return ridge+V(x,dh,0)+slope*t
                xmid=(x0+x1)*.5
                chipped=hand.uniform(.009,.025)
                nose=[tile(x1-chipped,t1,lift),tile(xmid,t1+.003,lift+.002),
                      tile(x0+chipped,t1,lift)]
                points=[tile(x0,t0,lift-.009),tile(x1,t0,lift-.009),*nose]
                slate=mix(rgb("435869"),rgb("667783"),.16+rng.random()*.31)
                blotch=.5+.5*math.sin(xmid*1.1+row*.31)*math.cos(xmid*.87-row*.19)
                weather=.035+.12*blotch+.10*max(0.,(row-10)/5)
                color=mix(slate,rgb("8593a1"),weather*hand.uniform(.72,1.10))
                roof.poly(points,[color*.95,color*.96,color,color*1.012,color],upward)
                for k in range(2):
                    pa,pb=nose[k:k+2]
                    roof.poly([pa,pb,pb-V(0,.014,0),pa-V(0,.014,0)],color*.83,V(0,0,sign))
        beam(roof,eave+V(-2.87,0,0),eave+V(2.87,0,0),.070,.070,rgb("4e5157"),5)
    for i in range(20):
        x=-2.90+i*.290
        beam(roof,(x,5.56,-.12),(x+.306,5.56,-.12),.089,.077,rgb("72808a")*hand.uniform(.91,1.04),7)
    # A front opening, two slate cheeks and flashed sill give each roof feature depth.
    def dormer(x,z,w,back,wall_top,bottom,peak,hip):
        zf=z+back
        box(dormers,(x,(wall_top+bottom)/2,z+back*.52),(w*.88,wall_top-bottom,back*.80),rgb("596264"))
        box(dormers,(x,(wall_top+bottom)/2,zf-.01),(w*.69,wall_top-bottom-.07,.06),rgb("93947a"))
        for n in range(4):
            box(dormers,(x+(n-1.5)*w*.152,(wall_top+bottom)/2,zf+.026),
                (w*.13,wall_top-bottom-.16,.029),rgb(["717c72","7d8775","7b8373","68766d"][n]))
        for dy in [bottom+.10,wall_top-.08]:
            box(dormers,(x,dy,zf+.048),(w*.72,.032,.049),rgb("999982"))
        box(dormers,(x,bottom+.015,zf+.025),(w*.86,.075,.15),rgb("6b746e"))
        ridge0=V(x,peak,z-.13);ridge1=V(x,peak,zf-hip)
        for side in [-1,1]:
            e0=V(x+side*w*.57,wall_top,z-.08)
            e1=V(x+side*w*.57,wall_top,zf+.10)
            normal=unit(V((peak-wall_top)*side,w*.57,0))
            for j in range(4):
                v0=j/4;v1=(j+1)/4
                for k in range(6):
                    u0=k/6;u1=(k+1)/6
                    def slopepoint(u,v):
                        return mix(mix(ridge0,ridge1,u),mix(e0,e1,u),v)
                    shade=rgb("889391")*hand.uniform(.88,1.07)
                    dormers.poly([slopepoint(u0,v0),slopepoint(u1,v0),slopepoint(u1,v1),slopepoint(u0,v1)],shade,normal)
            beam(dormers,e0,e1,.037,.041,rgb("717a79"),5)
        dormers.poly([ridge1,V(x-w*.57,wall_top,zf+.10),V(x+w*.57,wall_top,zf+.10)],
                     rgb("838b87"),unit(V(0,hip+.10,peak-wall_top)))
    dormer(-.74,.34,.91,1.04,4.59,3.63,5.24,.16)
    # Low shed light: a single pitched cap and narrow glazing tucked tightly
    # against the roof, with staggered overlaps and two flashing cheeks.
    wx,back_z,front_z=1.40,1.055,1.99
    def cap_height(t):
        return 4.29-.50*t
    front_height=cap_height(1.)
    box(dormers,(wx,front_height-.18,front_z-.10),(.85,.34,.25),rgb("50616c"))
    box(dormers,(wx,front_height-.17,front_z+.033),(.66,.19,.035),rgb("647278"))
    for x in [wx-.29,wx+.28]:
        box(dormers,(x,front_height-.17,front_z+.052),(.044,.19,.026),rgb("727c7a"))
    for side in [-1,1]:
        x=wx+side*.46
        dormers.poly([(x,4.21,back_z),(x,3.26,front_z),(x,front_height,front_z),
                      (x,cap_height(0.),back_z)],rgb("566772"),V(side,0,0))
    for row in range(3):
        t0,t1=row/3,(row+1)/3
        z0,z1=back_z+(front_z-back_z)*t0,back_z+(front_z-back_z)*t1
        for col in range(7):
            x0=wx-.545+col*.155;x1=x0+.154
            paint=mix(rgb("75858a"),rgb("9eaaa8"),hand.uniform(.14,.76))
            dormers.poly([(x0,cap_height(t0),z0),(x0,cap_height(t1),z1),
                          (x1,cap_height(t1),z1),(x1,cap_height(t0),z0)],
                         paint,unit(V(0,front_z-back_z,.50)))
    box(dormers,(wx,front_height-.024,front_z), (1.095,.048,.048),rgb("637077"))

    # Match the thin-walled flue opening in the original. It is set into the
    # near pitch, with flashing where the stone meets the slates.
    cx,cz=1.504,.46
    cap_y=7.48
    base_y=4.28
    shaft_w,shaft_d=.735,.665
    shaft_top=cap_y-.19
    box(masonry,(cx,(shaft_top+base_y)*.5,cz),(shaft_w,shaft_top-base_y,shaft_d),rgb("746c61"))
    for zz in [cz-.297,cz+.297]:
        box(masonry,(cx,cap_y-.11,zz),(shaft_w,.20,.070),rgb("796f61"))
    for xx in [cx-.333,cx+.333]:
        box(masonry,(xx,cap_y-.11,cz),(.068,.20,.53),rgb("71685d"))
    for row in range(10):
        count=2+row%2
        for col in range(count):
            old_draw=rng.choice(["897966","918471","756957","a1967e"])
            brick_y=4.43+row*.307
            width=shaft_w/count
            xx=cx-shaft_w*.5+(col+.5)*width
            brick=mix(rgb(old_draw),rgb("80796f"),.50)*hand.uniform(.88,.99)
            box(masonry,(xx,brick_y,cz+shaft_d*.49),(width-.013,.285,.036),brick)
        for side in [-1,1]:
            for col in range(2):
                zz=cz+(-.5+col)*shaft_d*.5
                box(masonry,(cx+side*shaft_w*.49,4.43+row*.307,zz),
                    (.036,.28,shaft_d*.48),rgb("80766a")*hand.uniform(.85,1.00))
    for zz in [cz-.32,cz+.32]:
        box(masonry,(cx,cap_y,zz),(.83,.115,.105),rgb("938a7c"))
    for xx in [cx-.36,cx+.36]:
        box(masonry,(xx,cap_y,cz),(.11,.115,.57),rgb("8c8375"))
    box(masonry,(cx,cap_y-.155,cz),(.645,.016,.54),rgb("444340"))
    # Four small sooty marks, no directional shadow baked into the roof.
    for j in range(4):
        x=cx-.29+j*.19
        box(masonry,(x,cap_y-.13,cz+.336),(.075,.09,.017),rgb("665e59"))
    for xx in [cx-.405,cx+.405]:
        points=[]
        for zz,xoff in [(cz-.43,-.05),(cz-.43,.05),(cz+.46,.05),(cz+.46,-.05)]:
            y=5.53-(zz+.12)*2.90/2.57+.064
            points.append((xx+xoff,y,zz))
        masonry.poly(points,rgb("686e70"),unit(V(0,2.57,2.90)))
    # Raised open deck with a pale grey working surface. Its front bracing
    # is visible through the space below the deck as well as from the side.
    for i in range(13):
        board_tint=rng.uniform(.90,1.08)
        box(balcony,(-3.44,.91,-1.45+i*.26),(2.02,.115,.248),
            rgb("8a8885")*board_tint)
    deck_timber=rgb("5b6263")
    for x in [-4.44,-2.55]:
        for z in [-1.61,1.84]:
            box(balcony,(x,.90,z),(.135,1.94,.14),deck_timber)
        box(balcony,(x,1.78,.105),(.11,.085,3.58),rgb("717a7c"))
        for j in range(10):
            box(balcony,(x,1.38,-1.48+j*.35),(.050,.71,.052),deck_timber)
    box(balcony,(-3.47,1.78,1.84),(2.07,.09,.11),rgb("707b7c"))
    box(balcony,(-3.47,1.06,1.84),(2.06,.07,.095),rgb("586263"))
    for j in range(9):
        box(balcony,(-4.40+j*.233,1.40,1.84),(.045,.66,.046),deck_timber)
    for x0,x1 in [(-4.37,-3.53),(-3.50,-2.64)]:
        beam(balcony,(x0,.21,1.73),(x1,.83,1.73),.065,.068,deck_timber,4)
    for x in [-4.33,-2.60]:
        box(balcony,(x,.40,1.73),(.16,.80,.18),deck_timber)
    # Partly embedded irregular stone stoop and worn footstones turn toward the pond.
    # Individual stones step out from the sill, then disappear into the
    # approach. A split joint and asymmetric edges keep the landing rounded.
    for x,z,width,depth,rise in [(.48,2.19,.94,.45,.29),(-.16,2.26,.42,.39,.22),
              (.98,2.33,.47,.40,.19),(.32,2.51,.64,.41,.18),(.78,2.56,.40,.33,.12),
              (-.07,2.64,.45,.35,.095),(.42,2.81,.53,.36,.082),(1.06,2.83,.39,.31,.055),
              (.81,3.04,.43,.28,.047),(1.35,3.17,.26,.26,.031)]:
        a=HOUSE_YAW
        ground=ground_height(.13+x*math.cos(a)+z*math.sin(a),z*math.cos(a)-x*math.sin(a)-.04)
        hue=mix(rgb("766e67"),rgb("aaa39b"),hand.uniform(.35,.74))
        chip_stone(stoop,x,ground+rise,z,width,max(.12,rise+.028),depth,hue,hand.uniform(-.45,.45))
    for i in range(40):
        x=hand.uniform(-2.55,2.55)
        if -.14<x<1.36: continue
        z=hand.uniform(2.07,2.38);y=hand.uniform(.028,.09)
        for n in range(3):
            dx=hand.uniform(-.09,.09);dz=hand.uniform(-.07,.08);height=hand.uniform(.12,.32)
            stoop.poly([(x+dx-.033,y,z+dz),(x+dx+.035,y+.012,z+dz),
                        (x+dx+hand.uniform(-.07,.07),y+height,z+dz+.052)],
                       rgb(hand.choice(["6c7950","7c8557","768052"])),V(0,.8,.5))
    for g,name in [(wall,"TimberHouse"),(roof,"SlateCourses"),(detail,"WindowDeckAndChimney"),
                   (masonry,"MasonryFlue"),(dormers,"DormerWindows"),(balcony,"WestDeck"),(stoop,"Doorstone")]:
        doc.place(doc.mesh(g,name),name,(.13,0,-.04),HOUSE_YAW)


def soil_color(x,z):
    # The warm break in the canopy falls between the visitors and the camera.
    open_light = math.exp(-((x+1.25)/6.5)**2-((z-6.7)/4.5)**2)
    pool_light = .75*math.exp(-((x-8.1)/3.05)**2-((z-.32)/2.2)**2)
    large = math.sin(x*.70+math.sin(z*.93)) * math.cos(z*.72-x*.23)
    small = math.sin(x*2.6-z*1.3+.6*math.sin(z*2.5))
    mottling = large*.11 + small*.046
    aperture = np.clip(max(open_light,pool_light)+mottling,0,1)
    lawn = mix(rgb("526b4b"),rgb("9fd34e"),aperture)
    # Cool moss under the front wall meets the warm, trampled earth path.
    eave = math.exp(-((x-.12)/3.5)**4-((z-2.64)/1.18)**2)
    lawn = mix(lawn,rgb("475937"),.56*eave)
    t = (x-1.06)/3.36
    if -.11 < t < 1.12:
        path_z = 2.40+1.13*t+.15*math.sin(math.pi*t)
        wear = math.exp(-((z-path_z)/(.43+.087*math.cos(8*t)))**2)
        taper = min(1.,max(0.,(t+.11)*7),max(0.,(1.12-t)*6))
        lawn = mix(lawn,mix(rgb("897864"),rgb("958469"),.5+.49*small),.76*wear*taper)
    return lawn*(.976+.027*small)*(1.0-.067*open_light)


def ground_height(x,z):
    old = -.1+.052*math.sin(x*.62+z*.39)+.08*math.sin(z*.43-x*.27)
    # A shallow lip joins the turf to a real depressed basin.
    u=(x-7.11)/2.54
    v=(z-1.53+.39*u)/1.72
    distance=math.hypot(u,v)
    if distance<1.65:
        old += .19*math.exp(-((distance-1.07)/.21)**2) - .19*max(0.,1-distance)
    return old


def in_pond(x,z,scale=1):
    return ((x-7.20)/2.68)**2 + ((z-1.55)/1.85)**2 < scale**2


def landscape():
    g=Geo()
    xs=np.r_[np.linspace(-32,-10,22,endpoint=False),np.linspace(-10,12,76,endpoint=False),np.linspace(12,32,22)]
    zs=np.r_[np.linspace(-36,-6,31,endpoint=False),np.linspace(-6,12,62,endpoint=False),np.linspace(12,24,14)]
    doc.floor_axes=(xs,zs)
    for iz,z in enumerate(zs[:-1]):
        for ix,x in enumerate(xs[:-1]):
            x2,z2=xs[ix+1],zs[iz+1]
            coords=[(x,z),(x,z2),(x2,z2),(x2,z)]
            pts=[(px,ground_height(px,pz),pz) for px,pz in coords]
            g.poly(pts,[soil_color(px,pz) for px,pz in coords],UP)
    doc.place(doc.mesh(g,"SunlitForestFloor"),"SunlitForestFloor")
    path=Geo();grass=Geo();flowers=Geo()
    for i in range(24):
        z=2.06+i*.24
        x=.60+(z-2.06)*.82+rng.uniform(-.36,.40)
        if not in_pond(x,z):
            t=i/23
            offset=x-(.60+(z-2.06)*.82)
            # Break the short worn trail into a handful of gray-brown slabs,
            # with smaller, half-buried chips between them.
            px=1.06+3.36*t+.18*offset
            pz=2.40+1.13*t+.15*math.sin(math.pi*t)+offset*.62
            w=.29+.15*rng.random()
            prominent=i in (1,5,9,10,16,22)
            size=w if prominent else w*(.18+.16*abs(math.sin(i)))
            col=rgb(rng.choice(["9e8b72","a1927c","877e6d","aa997a"]))
            ellipsoid(path,(px,ground_height(px,pz)+.018,pz),
                      (size,.050 if prominent else .022,size*(.48+.19*t)),
                      col,7,3,rough=.15,shades=.20)
    for i in range(7650):
        x=rng.uniform(-18,18);z=rng.uniform(-17,15)
        if in_pond(x,z,1.05) or (abs(x)<2.9 and abs(z)<2.4):continue
        y=ground_height(x,z)+.013
        base=soil_color(x,z)
        tone=mix(base,rgb(rng.choice(["bad773","cfe194","718e53","a9bd68"])),rng.uniform(.22,.65))
        count=rng.randint(2,4)
        for k in range(count):
            a=rng.uniform(0,TAU);s=circle(a);w=rng.uniform(.015,.052)
            center=V(x+rng.uniform(-.1,.1),y,z+rng.uniform(-.1,.1))
            tip=center+UP*rng.uniform(.10,.28)+circle(a+1.57)*rng.uniform(.03,.12)
            # Patchy low brushwork on the sunlit lawn; taller blades rim the grove.
            field = math.exp(-((x+.9)/5.0)**2-((z-5.7)/4.5)**2)
            tip[1] = center[1] + (tip[1]-center[1])*(.59-.36*field)
            tip += circle(a+1.57)*(.035+.054*field)
            w *= 1.05+.55*field
            shade=mix(base,tone,.58)
            v=[center-w*s,center+w*s,tip]
            paint=[shade*.94,shade,mix(shade,rgb("cbdc80"),.19)]
            if np.cross(v[1]-v[0],v[2]-v[0])[1]<0:
                v.reverse();paint.reverse()
            grass.poly(v,paint,UP)
    # Short-stem wildflowers are planted in patches, concentrated around the figures.
    for i in range(100):
        x=rng.uniform(-13,13);z=rng.uniform(-4,12)
        if abs(x)<3 and z<2.8 or in_pond(x,z,1.1):continue
        c=rgb(rng.choice(["ffe398","b4a3f1","95a6ef","faf2bb","e9a5bb","c2d8f9"]))
        for j in range(rng.randint(4,12)):
            px=x+rng.uniform(-.52,.52);pz=z+rng.uniform(-.46,.46)
            center=V(px,ground_height(px,pz)+rng.uniform(.12,.27),pz)
            for k in range(4):
                a=TAU*k/4; w=rng.uniform(.027,.055)
                petal=center+circle(a)*w
                flowers.poly([center,petal+circle(a+1.57)*w*.65,petal+circle(a)*w,petal-circle(a+1.57)*w*.65],c,UP)
            flowers.poly([center+UP*.005+circle(k*TAU/3)*.022 for k in range(3)],rgb("f7d172"),UP)
    # Small groups of yellow and violet blossoms sit beside the two figures.
    # Preserve the spacing of the empty grass between groups.
    floor_rng=random.Random(SEED+179)
    for cx,cz,color,size,count in [
        (-3.04,4.98,"f8d263",.141,6),(-3.90,4.26,"777db8",.080,8),
        (-4.08,6.18,"c5dbaf",.068,12),(-1.86,7.23,"edca60",.132,6),
        (.70,6.95,"f4d477",.138,6),(.93,4.55,"7379bb",.072,15),
        (-.21,5.23,"757fb6",.066,8),(2.08,3.85,"e9d787",.085,6)]:
        blue=color in ("777db8","7379bb","757fb6")
        for j in range(count):
            angle=floor_rng.uniform(0,TAU);rad=floor_rng.random()**.68
            px=cx+.48*rad*math.cos(angle);pz=cz+.39*rad*math.sin(angle)
            rise=floor_rng.uniform(.15,.31) if blue else floor_rng.uniform(.065,.17)
            foot=V(px,ground_height(px,pz),pz)
            c=foot+V(.035*math.sin(angle),rise,0)
            h=size*floor_rng.uniform(.72,1.17)
            clr=rgb(color)*floor_rng.uniform(.90,1.03)
            if blue:
                beam(flowers,foot,c,.009,.0065,rgb("637957"),3)
                # A blue bell has a darker outer silhouette at the lip.
                for row in range(3):
                    level=c-UP*(row*.043)
                    lateral=circle(angle+row*2.01)*h*.47
                    flowers.poly([level+lateral-UP*h*.51,level+lateral+circle(angle+1.57)*h*.50,
                                  level+lateral+UP*h*.34,level+lateral-circle(angle+1.57)*h*.54],
                                 clr*(.87+.064*row),UP)
            else:
                for blade in range(5):
                    a=angle+TAU*blade/5;along=circle(a)*h;side=circle(a+math.pi/2)*h*.36
                    flowers.poly([c,c+along*.66+side,c+along+UP*h*.16,c+along*.66-side],
                                 [clr*.88,clr,clr*1.04,clr],UP)
                flowers.poly([c+UP*.008+circle(k*TAU/5)*h*.24 for k in range(5)],rgb("d9a548"),UP)
    # Dark seed stones provide scale beside the walking pair.
    for cx,cz,amount in [(-.68,5.40,11),(.12,5.20,7),(-3.15,7.5,6)]:
        for j in range(amount):
            a=floor_rng.uniform(0,TAU);r=floor_rng.random()**.6
            px,pz=cx+.55*r*math.cos(a),cz+.36*r*math.sin(a)
            level=ground_height(px,pz)+.013
            w=floor_rng.uniform(.036,.102)
            summit=V(px+.17*w,level+w*floor_rng.uniform(.41,.72),pz-.11*w)
            base=[V(px+math.cos(v*TAU/5+a)*w,level,pz+math.sin(v*TAU/5+a)*w*.67) for v in range(5)]
            rock=rgb(floor_rng.choice(["565a42","6c6950","454e3e","65624d"]))
            for k in range(5):
                path.poly([base[k-1],summit,base[k]],rock*(.85+.038*k),UP)
    doc.place(doc.mesh(path,"DoorstepTrail"),"DoorstepTrail")
    doc.place(doc.mesh(grass,"GrassBrushstrokes"),"GrassBrushstrokes")
    doc.place(doc.mesh(flowers,"ScatteredWildflowers",1),"ScatteredWildflowers")


def pond_point(angle, radius=1.0):
    # Oblique waterline rises toward screen right across a slightly pinched inlet.
    u,v=math.cos(angle),math.sin(angle)
    outline=1+.054*math.sin(3*angle+.23)+.031*math.cos(7*angle-.31)
    return V(7.11+2.54*radius*u*outline,.046,1.53+radius*(1.72*v-.39*u)*outline)


def pond_color(x,z):
    # The reflected canopy forms a branching, dark diagonal against sky-green water.
    wave=.073*math.sin(15*z+1.7*x)+.047*math.sin(21*x-11*z)
    lobes=[(5.34,2.02,.63,.33),(5.93,1.78,.64,.56),(6.46,1.55,.77,.57),
           (7.06,1.29,.66,.49),(7.60,1.17,.49,.35),(7.82,.74,.38,.26),
           (7.12,.72,.49,.21),(6.79,1.99,.32,.26),(6.36,2.38,.14,.33)]
    field=min(((x-cx)/rx)**2+((z-cz-wave)/rz)**2 for cx,cz,rx,rz in lobes)
    # Short separations between boughs admit reflected skylight.
    edge=field+.22*math.sin(x*13.1+z*6.8)+.22*math.cos(z*14.3-x*4.1)
    shadow=min(1.,max(0.,(1.20-edge)/.31))
    holes=[(5.60,1.83,.20,.085),(6.31,1.14,.23,.10),(7.30,1.06,.19,.105),
           (7.63,1.07,.24,.12),(6.88,1.78,.23,.087)]
    gap=min(((x-hx)/rx)**2+((z-hz-.02*math.sin(13*x))/rz)**2 for hx,hz,rx,rz in holes)
    shadow*=min(1.,max(0.,(gap-.59)/.68))
    # A thin hooked limb continues below the broad reflected canopy.
    limb=1.-min(1.,abs(z-(1.60+.37*math.sin((x-6.88)*5.0)))/.085)
    if 6.72<x<7.44 and z>1.52:
        shadow=max(shadow,limb*.86)
    facing=min(1.,max(0.,.57+.15*(x-7.1)-.10*(z-1.5)+.18*math.sin(1.6*x+1.1*z)))
    open_color=mix(rgb("729581"),rgb("d4e5a6"),facing)
    # Separate sky-blue openings in a continuous field of reeds and reflected green leaves.
    blue_centers=[(5.19,1.97,.39,.23),(5.70,1.74,.31,.19),
                  (7.97,.03,.42,.22),(8.40,-.01,.22,.16),(7.28,.41,.25,.12)]
    blue=min(((x-cx)/rx)**2+((z-cz-wave*.56)/rz)**2 for cx,cz,rx,rz in blue_centers)
    sky=max(0.,min(1.,(1.20-blue)/.82))
    dark=mix(rgb("1c3844"),rgb("35575b"),.48+.34*math.cos(6*x-3*z))
    reflection=mix(open_color,dark,shadow)
    return mix(reflection,rgb("6699a4"),sky*.91)



def pond():
    water,stones,pads,margin=Geo(),Geo(),Geo(),Geo()
    center=pond_point(0,0)
    # Assign a colour at every vertex, so no concentric bands follow the mesh rings.
    last=[center]*120
    for i in range(1,29):
        ring=[pond_point(j*TAU/120,i/28) for j in range(120)]
        for j,p in enumerate(ring):
            k=(j+1)%120
            pts=([center,ring[k],p] if i==1 else [last[j],last[k],ring[k],p])
            water.poly(pts,[pond_color(v[0],v[2]) for v in pts],UP)
        last=ring
    # Turf, silt and submerged stones soften the exposed earth boundary.
    count=63
    for j in range(count):
        a,b=TAU*j/count,TAU*(j+1)/count
        widths=[1.005,1.045,1.109,1.18]
        heights=[.042,.077,.098,None]
        rings=[]
        for r,y in zip(widths,heights):
            pair=[]
            for theta in [a,b]:
                q=pond_point(theta,r+.012*math.sin(8*theta))
                q[1]=ground_height(q[0],q[2])+.006 if y is None else y+.018*math.sin(6*theta)
                pair.append(q)
            rings.append(pair)
        for i,(inner,outer) in enumerate(zip(rings,rings[1:])):
            pts=[inner[0],inner[1],outer[1],outer[0]]
            soil=[soil_color(v[0],v[2]) for v in pts]
            moss=rgb(["707e59","82945e","849857"][i])
            margin.poly(pts,[mix(col,moss,.60 if i<2 else .22) for col in soil],UP)
    for i in range(21):
        a=i*TAU/21 +rng.uniform(-.06,.06)
        if math.sin(a)>.34 and i%2:continue
        p=pond_point(a,1.045)
        r=rng.uniform(.22,.56) if math.sin(a)<.25 else rng.uniform(.14,.34)
        if math.sin(a)<-.35:
            r *= .74 + .17*abs(math.sin(9*a))
        elif math.sin(a)>.50:
            r *= .52
        else:
            r *= .75
        p[1]=.055 if math.sin(a)<0 else .018
        colors=["797b67","8a826f","81846b","717c71","9e917b"]
        ellipsoid(stones,p,(r*1.31,r*(.54+.17*abs(math.cos(a))),r*.78),
                  rgb(rng.choice(colors)),8,4,.19,.36)
    for j in range(55):
        angle=rng.uniform(0,TAU);dist=rng.uniform(.20,.95)
        p=pond_point(angle,dist)
        p[1]+=.017
        if j%5==0:
            r=rng.uniform(.11,.23)*.76
            pts=[p]+[p+V(math.cos(a)*r,0,math.sin(a)*r*.76) for a in np.linspace(.25,TAU-.17,9)]
            pads.poly(pts,rgb(rng.choice(["94ac69","aaca77","90ac6d"])),UP)
        else:
            w=rng.uniform(.06,.23)*(1.05 if j%4==0 else .48)
            pads.poly([p+V(-w,0,0),p+V(-w*.73,0,.015),p+V(w,0,.009),p+V(w*.65,0,-.007)],
                      mix(pond_color(p[0],p[2]),rgb("d3deb7"),.18 if j%4 else .40),UP)
    reed_rng=random.Random(SEED+941)
    for j in range(65):
        angle=reed_rng.uniform(0,TAU)
        for k in range(reed_rng.randint(4,9)):
            c=pond_point(angle+reed_rng.gauss(0,.034),reed_rng.uniform(.95,1.10))
            c[1]=.058
            a=reed_rng.uniform(0,TAU)
            h=reed_rng.uniform(.047,.17);w=reed_rng.uniform(.015,.034)
            side=circle(a)*w;tip=c+UP*h+circle(a+1.57)*h*.62
            clr=rgb(reed_rng.choice(["7d9660","899c5c","75885a","b1b26a"]))
            margin.poly([c-side,c+side,tip],[clr*.92,clr,clr*1.06],UP)
    # A pair of sun-bleached stems rises at the far corner of the pool.
    for x,z,h,slant in [(9.32,.42,.73,.09),(9.45,.41,.54,-.05)]:
        b=V(x,.058,z);joint=b+V(slant*.35,h*.59,.045);end=b+V(slant,h,-.035)
        beam(margin,b,joint,.033,.025,rgb("bba078"),5)
        beam(margin,joint,end,.025,.010,rgb("d4b681"),5)
        beam(margin,joint,joint+V(-.085,.15,0),.015,.005,rgb("b99a70"),4)
    # Spikes at the near-left bank overlap the water silhouette in the capture.
    for az,count in [(2.53,11),(2.15,8),(1.47,7),(3.13,5)]:
        for _ in range(count):
            a=az+reed_rng.uniform(-.10,.10)
            c=pond_point(a,reed_rng.uniform(.87,1.035));c[1]=.058
            lean=circle(a+reed_rng.uniform(-1.1,1.1))*reed_rng.uniform(.035,.16)
            top=c+UP*reed_rng.uniform(.14,.38)+lean
            beam(margin,c,top,.010,.006,rgb("657c50"),4)
            if reed_rng.random()<.56:
                for tier in range(3):
                    f=top-V(0,tier*.044,0)+circle(a+tier*2.46)*.022
                    w=reed_rng.uniform(.022,.047)
                    pads.poly([f-UP*w*.9,f+V(-w*.83,0,0),f+UP*w,f+V(w*.83,0,0)],
                              rgb(reed_rng.choice(["7788a3","8588a1","8898b0"])),UP)
    # Floating leaves, small sky glints and fine blue streaks cut across the reflected boughs.
    for cx,cz in [(5.74,1.87),(6.34,1.56),(7.24,1.42),(7.78,.96),(8.00,.12)]:
        for j in range(3):
            px=cx+reed_rng.uniform(-.16,.16);pz=cz+reed_rng.uniform(-.09,.09)
            w=reed_rng.uniform(.047,.117);spin=reed_rng.uniform(0,TAU)
            v=V(px,.075+(.002*j),pz)
            points=[v]+[v+V(math.cos(a+spin)*w,0,math.sin(a+spin)*w*.57)
                         for a in np.linspace(.22,TAU-.22,8)]
            pads.poly(points,rgb(reed_rng.choice(["b7cd9d","97b934","bed3ae","99b7ac"])),UP)
    for j in range(32):
        a=reed_rng.uniform(0,TAU);q=pond_point(a,reed_rng.uniform(.18,.92))
        q[1]=.067
        w=reed_rng.uniform(.027,.115);glint=rgb(reed_rng.choice(["bfd9c6","98b9b6","cbdcc3"]))
        pads.poly([q+V(-w,0,0),q+V(0,0,.009),q+V(w,0,.008)],glint,UP)
    doc.place(doc.mesh(water,"GreenPond",1),"GreenPond")
    doc.place(doc.mesh(stones,"ShoreBoulders"),"ShoreBoulders")
    doc.place(doc.mesh(pads,"WaterLilyPads",1),"WaterLilyPads")
    doc.place(doc.mesh(margin,"PondMargin"),"PondMargin")


FOREST_PALETTES = {
    "far": [("344b45","536f56","91a86a"),("384a3c","60784e","a3b660"),("546d69","728e89","92aba6")],
    "mid": [("3a513e","667f4c","a0ba67"),("344d43","5c7758","84a26e"),
            ("4c5f3e","849b4e","bbcc68"),("424e35","6a8446","9fb458")],
    "near": [("45633c","82a046","b0c75d"),("739138","b7c847","d6db50"),
             ("294631","527f3f","84a950")],
}
SUN = unit(V(-.40,.84,.36))


def leaf_pigment(n, y, total, colors, offset):
    lit = np.clip(0.19 + .34*(y/total) + .33*n.dot(SUN) + offset, 0, 1)
    if lit < .58:
        return mix(colors[0], colors[1], lit/.58)
    return mix(colors[1], colors[2], min(1,(lit-.58)/.40))


def leafy_cloud(g, center, radius, colors, tree_height):
    # A branch carries overlapping maple-shaped paint masses, with a few leaf
    # tips at the silhouette. Each fan has one broad upper light and underside.
    outward = unit(V(center[0]+.02,0,center[2]+.03))
    side = V(-outward[2],0,outward[0])
    r = float(radius[0])
    upper_fraction = np.clip(center[1]/tree_height,0,1)
    floor_tone = mix(colors[0],colors[1],.14+.32*upper_fraction)
    ellipsoid(g,center-outward*r*.15-UP*r*.12,(.53*r,.19*r,.50*r),floor_tone,9,4,.14,.12)

    # Three staggered planes along the limb give a dark lower shelf, mid
    # green foliage, and a smaller canopy catching sun on the upper plane.
    fan_outline = [
        (-.12,-.67),(-.54,-.49),(-.48,-.29),(-.83,-.26),(-.57,.01),
        (-.86,.35),(-.40,.29),(-.46,.70),(-.18,.49),(.02,.99),
        (.17,.57),(.44,.74),(.39,.30),(.84,.39),(.62,.06),
        (.78,-.16),(.49,-.26),(.61,-.43),(.18,-.44),
    ]
    for shelf,count in enumerate((5,7,5)):
        height=(shelf-1)*.23*r
        for i in range(count):
            a=TAU*(i+.34*shelf)/count + rng.uniform(-.19,.19)
            d = unit(outward*(.56+math.cos(a)) + side*math.sin(a))
            dist=r*(.51+.23*math.sin(TAU*i/count+.7*shelf))
            inner_reach = .68 if shelf == 2 else 1.0
            root=center+d*(dist*inner_reach)+outward*.13*r+UP*(height+rng.uniform(-.14,.14)*r)
            # Tilt fans en masse. Their blades then form a lateral cove
            # instead of the tiny upright points of a conifer at thumbnail scale.
            spine=unit(d+UP*rng.uniform(-.65,.82))
            edge=unit(np.cross(UP,spine))
            normal=unit(np.cross(spine,edge))
            magnitude=r*rng.uniform(.39,.59)*(1-.10*abs(shelf-1))
            direction_light=.13*outward.dot(SUN) + .17*d.dot(SUN)
            light=np.clip(.19+.20*upper_fraction+direction_light+.18*shelf+rng.uniform(-.07,.035),0,1)
            if light < .54:
                base=mix(colors[0],colors[1],light/.54)
            else:
                base=mix(colors[1],colors[2],(light-.54)/.46)
            if shelf==0:
                base=mix(base,colors[0],.33)
            # A slight crease in the middle splits a single brushstroke into
            # related values and keeps the colored mass larger than a pixel.
            ridge=root+normal*magnitude*.070+spine*magnitude*.09
            points=[root+edge*(w+rng.uniform(-.059,.059))*magnitude+
                    spine*h*magnitude+normal*magnitude*(.035*math.sin(w*4)-.10*abs(w))
                    for w,h in fan_outline]
            ink=base*(.96+.06*light)
            tints=[ink*(.95+.06*(h+1)/2+.026*w) for w,h in fan_outline]
            g.poly([ridge,*points,points[0]],[ink*1.013,*tints,tints[0]],normal)
            # Two smaller leaflets overlap the broad wash and feather its ends.
            for handedness in (-1,1):
                shoot=root+edge*handedness*magnitude*.36+spine*magnitude*.28
                lead=unit(spine*.65+edge*handedness*.70-UP*.12)
                cross=unit(np.cross(UP,lead))
                leaflet=[shoot+lead*h*magnitude*.52+cross*w*magnitude*.40
                         for w,h in fan_outline]
                shade=ink*(.93 if handedness<0 else 1.025)
                g.poly([shoot+normal*.018,*leaflet,leaflet[0]],shade,normal)
            if i%3==0:
                tip=root+spine*.61*magnitude+edge*.43*magnitude
                direction=unit(spine+edge*.72+UP*.15)
                width=magnitude*.12
                length=magnitude*.55
                g.poly([tip,tip+edge*width+direction*length*.30,tip+direction*length,
                        tip-edge*width*.86+direction*length*.38],
                       [ink*.97,ink,ink*1.035,ink],normal)


def tree_templates():
    library={}
    for tier,options in FOREST_PALETTES.items():
        library[tier]=[]
        for idx,palette in enumerate(options):
            trunk,canopy=Geo(),Geo()
            colors=[rgb(c) for c in palette]
            top=rng.uniform(6.7,8.3)
            wood=rgb(rng.choice(["776d57","857b65","746d57","797662"]))
            bend=V(rng.uniform(-.38,.38),top*.44,rng.uniform(-.25,.25))
            beam(trunk,V(0,-.28,0),bend,.30,.21,wood,8)
            for k in range(4):
                d=circle(TAU*k/4+rng.uniform(-.35,.35))
                beam(trunk,d*rng.uniform(.32,.49)-UP*.15,UP*.52,.08,.13,wood,6)
            fork=bend+V(rng.uniform(-.23,.23),top*.28,rng.uniform(-.32,.28))
            beam(trunk,bend,fork,.20,.13,wood,7)
            lobes=[]
            phase=rng.random()*TAU
            for k in range(8):
                a=phase+k*2.40+rng.uniform(-.17,.17)
                lift=k/8
                length=(2.55-.92*lift)*rng.uniform(.82,1.22)
                attach=mix(bend,fork,lift)
                end=circle(a)*length + UP*(top*(.57+.34*lift))
                elbow=mix(attach,end,.56)+UP*.34
                beam(trunk,attach,elbow,.139-.044*lift,.09,wood,6)
                beam(trunk,elbow,end,.09,.035,wood,5)
                branch_side=circle(a+TAU*.25)
                second=mix(elbow,end,.64)+branch_side*rng.uniform(.49,.85)+UP*.34
                beam(trunk,elbow,second,.068,.022,wood,5)
                lobes.extend([(end,rng.uniform(.83,1.29)),(second,rng.uniform(.59,.88))])
            lobes.extend([(fork+V(.30,top*.22,.22),1.22),(fork+V(-.59,top*.17,-.16),1.12)])
            for point,r in lobes:
                leafy_cloud(canopy,point,V(r*1.12,r*.70,r),colors,top)
            name=f"{tier.title()}{idx}"
            library[tier].append((doc.mesh(trunk,name+"Boughs"),doc.mesh(canopy,name+"Leaves",1)))
    return library


def pine_template():
    trunk, pine=Geo(),Geo()
    pine_color=rgb("566b4c")
    wood=rgb("685c49")
    beam(trunk,(0,-.2,0),(.03,8.6,.02),.26,.048,wood,7)
    for layer in range(12):
        level=1.77+layer*.55
        radius=2.5*(1-layer/13)**.8
        for k in range(11):
            a=k*TAU/11+layer*.48+rng.uniform(-.16,.16)
            d,side=circle(a),circle(a+math.pi/2)
            size=radius*rng.uniform(.72,1.12)
            start=UP*level
            tip=start+size*d-UP*size*.32
            beam(trunk,start,tip,.056,.018,wood,5)
            shade=pine_color*rng.uniform(.66,1.09)*(1+.10*layer/12)
            for i in range(6):
                t=.12+i*.15
                root=mix(start,tip,t)
                outer=(1-t)*.49+.07
                for sign in (-1,1):
                    v=root+side*outer*sign+UP*.08
                    pine.poly([root-UP*.06,v,d*size*.27+v-UP*.12,root+d*size*.34-UP*.11],
                              [shade*.74,shade,shade*1.16,shade*.88],UP)
    return doc.mesh(trunk,"SpruceTrunk"),doc.mesh(pine,"SpruceNeedles",1)


def plant_forest():
    # Keep the forest rebuild independent of revisions to the house or clearing.
    state = rng.getstate()
    rng.seed(819431)
    library=tree_templates()
    library["spruce"]=[pine_template()]
    rng.seed(40711)
    tree_num=0

    def plant(x,z,tier,scale,variation=None,vertical=1.0):
        nonlocal tree_num
        trunk,leaves=library[tier][variation] if variation is not None else rng.choice(library[tier])
        yaw=rng.uniform(-1.2,1.2)
        size=(scale,scale*vertical,scale)
        p=(x,ground_height(x,z),z)
        for mesh,label in [(trunk,"Trunk"),(leaves,"Canopy")]:
            doc.place(mesh,f"{tier.title()}{tree_num:02}{label}",p,yaw,size)
        tree_num+=1

    # The distant mixed stand closes the horizon. Pine tops rise above the
    # foliage at uneven intervals near the upper edge of the reference.
    for row,z in enumerate([-27,-20.8,-15.5,-11.4]):
        for col in range(-5,6):
            x=col*4.6+rng.uniform(-1.5,1.5)
            pz=z+rng.uniform(-1.65,1.55)
            tier="far" if row<2 else "mid"
            if (col+row*2)%4==0:
                tier="spruce"
            # Allow two small blue-grey glimpses of the distant stand through
            # taller deciduous crowns. They are volumes with lit leaves.
            if row>=2 and -6.3<x<-3.1:
                x -= 1.9
            if row>=2 and 9.8<x<12.2:
                x += 1.3
            variation = rng.randrange(2) if tier=="far" else None
            plant(x,pz,tier,rng.uniform(.82,1.18),variation,vertical=rng.uniform(.96,1.12))
    plant(-4.45,-14.3,"far",.43,2)
    plant(11.48,-12.0,"far",.41,2)
    for x,z,s in [(-6.8,-8.7,1.21),(1.15,-8.8,1.27),(9.3,-9.8,1.22),(16.1,-9.2,1.19)]:
        plant(x,z,"spruce",s)

    # Staggered woodland edge: taller trunks are visible on either side of
    # the roof, with lower shrubs occupying isolated gaps in the farther stand.
    for x,z,s,idx in [(-16.3,-4,.97,0),(-11.4,-4.7,1.04,2),(-7.55,-7.4,.90,1),
                      (-3.51,-3.56,.96,0),(1.0,-6.9,1.02,2),(4.63,-6.1,1.06,1),
                      (7.45,-3.2,1.02,1),(10.97,-3.75,.96,0),(15.22,-4.15,1.03,2),
                      (18.9,-4.6,1.06,3)]:
        plant(x,z,"mid",s,idx,vertical=1.04)
    for x,z,s,idx in [(-14,-6.1,.53,1),(-8.2,-6.9,.58,3),(-5.8,-6.7,.54,1),(-.8,-7.0,.61,0),
                      (3.7,-6.1,.59,1),(5.4,-5.4,.43,3),(9.1,-5.6,.46,1),(11.3,-7.0,.58,3),(17.9,-6.4,.62,1)]:
        plant(x,z,"mid",s,idx)
    for x,z,s,idx in [(-15.5,1.7,1.05,1),(-14.8,5.1,.88,0),(-16.7,7.2,1.06,0),
                      (15.8,1.4,1.06,2),(18.1,5.0,.87,0),(17.2,7.4,1.02,1)]:
        plant(x,z,"mid",s,idx)

    # Independently placed trees create a diagonal bright leaf curtain. The
    # outer, middle and nearest tiers overlap without closing the lawn center.
    for x,z,s,idx,h in [
        (-17.3,11.7,.98,2,1.00),(-12.9,13.2,.99,1,1.00),
        (-11.0,15.4,1.03,0,1.02),(-8.55,17.05,.98,2,.98),
        (-6.3,17.25,.82,2,.88),(-15.0,18.2,1.21,0,1.0),
        (17.2,9.0,1.08,0,1.08),(15.04,12.6,1.11,0,1.03),
        (12.55,14.1,1.10,1,.96),(8.85,14.8,1.02,1,1.07),
        (5.6,17.3,1.03,0,.97),(2.72,19.0,.88,1,.99),(15.0,18.2,1.2,1,1.0),
    ]:
        plant(x,z,"near",s,idx,h)

    # A fork from the nearest sunny tree reaches across the lower-right lip
    # of the pond. Leave the left half of the water and its dark reflection clear.
    limb,leaf_edge=Geo(),Geo()
    bark=rgb("80805e")
    stem=V(9.92,3.35,15.65)
    joint=V(9.05,6.26,14.32)
    beam(limb,stem,joint,.19,.135,bark,7)
    palette=[rgb(c) for c in FOREST_PALETTES["near"][1]]
    for end,r in [(V(7.74,7.56,13.45),1.02),(V(8.54,7.42,13.31),.94),
                  (V(9.75,7.45,13.12),1.10),(V(10.71,7.15,13.45),.89),
                  (V(7.31,7.12,13.80),.74)]:
        elbow=mix(joint,end,.54)-UP*.17
        beam(limb,joint,elbow,.10,.065,bark,6)
        beam(limb,elbow,end,.065,.025,bark,5)
        # Build in local coordinates so the individual branch remains editable.
        leafy_cloud(leaf_edge,end-stem,V(r,r*.72,r),palette,4.4)
    doc.place(doc.mesh(limb,"PoolEdgeBough"),"PoolEdgeBough")
    doc.place(doc.mesh(leaf_edge,"PoolEdgeFoliage",1),"PoolEdgeFoliage",stem)
    # The taller eastern maple reaches into the opening above the stump.
    east_wood,east_leaves=Geo(),Geo()
    origin=V(15.8,2.9,1.4)
    fork=V(.3,2.83,-.45)
    beam(east_wood,(0,0,0),fork,.15,.085,bark,7)
    east_palette=[rgb(c) for c in ("647d43","a3b94f","cbce62")]
    for tip,radius in [(V(-2.15,4.23,-.87),.98),(V(-1.45,4.65,-.95),1.02),
                       (V(-.65,4.52,-1.1),1.02),(V(.29,5.19,-.78),1.24),
                       (V(1.26,5.50,-.93),1.10)]:
        bend=mix(fork,tip,.45)-UP*.17
        beam(east_wood,fork,bend,.08,.042,bark,5)
        beam(east_wood,bend,tip,.045,.018,bark,5)
        leafy_cloud(east_leaves,tip,V(radius,radius*.7,radius),east_palette,5.7)
    doc.place(doc.mesh(east_wood,"EasternMapleLimb"),"EasternMapleLimb",origin)
    doc.place(doc.mesh(east_leaves,"EasternMapleCanopy",1),"EasternMapleCanopy",origin)
    # A light spray above a recessed green crown breaks the diagonal left frame.
    west_wood,west_leaves=Geo(),Geo()
    west_origin=V(-11.0,3.1,15.4)
    west_fork=V(.84,2.80,.14)
    beam(west_wood,(0,0,0),west_fork,.13,.075,bark,6)
    west_palette=[rgb(c) for c in ("547339","96ac43","c6cc58")]
    for tip,radius in [(V(1.65,4.80,.02),1.07),(V(2.33,4.72,-.21),.91),
                       (V(3.12,4.56,-.12),1.03),(V(3.94,4.22,.16),.78)]:
        bend=mix(west_fork,tip,.51)-UP*.18
        beam(west_wood,west_fork,bend,.07,.036,bark,5)
        beam(west_wood,bend,tip,.037,.018,bark,5)
        leafy_cloud(west_leaves,tip,V(radius,radius*.68,radius),west_palette,5.1)
    doc.place(doc.mesh(west_wood,"WesternMapleLimb"),"WesternMapleLimb",west_origin)
    doc.place(doc.mesh(west_leaves,"NearWestSprayCanopy",1),"NearWestSprayCanopy",west_origin)
    for x,z,h,variant in [(-9.2,-.9,.47,1),(-7.1,-2.6,.40,0)]:
        plant(x,z,"mid",h,variant)
    # A splintered stump in the opening at screen right.
    stump=Geo()
    bark=rgb("6f6654")
    beam(stump,(0,-.12,0),(.09,.56,-.04),.50,.29,bark,8)
    for i in range(6):
        d=circle(i*TAU/6)
        beam(stump,d*.30+UP*.29,d*.21+UP*rng.uniform(.54,.94),.13,.032,bark,5)
        beam(stump,d*.68-UP*.12,d*.21+UP*.23,.10,.13,bark,5)
    doc.place(doc.mesh(stump,"WoodlandStump"),"WoodlandStump",(14.9,ground_height(14.9,-3.7),-3.7),.34)
    rng.setstate(state)


def visitor(pos, size, yaw, coat, hair):
    # Short relaxed stride and bent elbows keep the figures legible at
    # 30 pixels, even when a darker tree patch lies behind the clothing.
    g=Geo()
    wanderer=pos[0]<-1.5
    skin=rgb("bd9880") if wanderer else rgb("b69b87")
    garment=mix(coat,rgb("603d3b") if wanderer else rgb("3c434c"),.35)
    for k in [-1,1]:
        advance=.075*k if wanderer else -.050*k
        hip=V(k*.091,.64,0);knee=V(k*.101,.36,advance*.32)
        foot=V(k*.118,.085,advance)
        beam(g,hip,knee,.079,.065,rgb("4c494c"),7)
        beam(g,knee,foot,.064,.047,rgb("484748"),7)
        ellipsoid(g,foot+V(0,-.024,.035),(.075,.064,.114),rgb("383838"),8,4)
        shoulder=V(k*.135,1.12,-.01);elbow=V(k*.178,.89,advance*.3+.035)
        hand=V(k*.137,.78,.13) if k<0 else V(k*.185,.73,.052)
        beam(g,shoulder,elbow,.068,.056,garment*.94,7)
        beam(g,elbow,hand,.056,.044,garment*.89,7)
        ellipsoid(g,hand,(.044,.055,.041),skin,7,4)
    beam(g,(0,.65,0),(0,1.07,0),.145,.164,garment,9)
    ellipsoid(g,(0,1.08,-.008),(.170,.134,.117),garment,9,4)
    beam(g,(0,.74,0),(0,.775,0),.146,.146,rgb("55453c"),9)
    beam(g,(0,1.15,-.005),(0,1.25,0),.057,.065,skin,7)
    ellipsoid(g,(0,1.34,0),(.115,.149,.112),skin,10,6)
    ellipsoid(g,(0,1.421,-.024),(.122,.099,.123),hair*.86,11,5)
    ellipsoid(g,(0,1.33,.102),(.027,.027,.031),skin,7,3)
    if wanderer:
        beam(g,(-.13,1.11,.102),(.093,.77,.133),.015,.018,rgb("7d6453"),4)
        box(g,(.133,.73,.066),(.12,.135,.075),rgb("69513d"))
    else:
        ellipsoid(g,(0,1.35,-.121),(.073,.069,.062),hair*.82,8,4)
        beam(g,(0,1.139,0),(0,1.18,0),.106,.089,rgb("6c7070"),8)
    name="Wanderer" if wanderer else "Herbalist"
    # Use the same two triangles per cell as SunlitForestFloor. The two
    # slightly staggered boots should each touch even where the ground tilts.
    def floor_y_at(x,z):
        xs,zs=doc.floor_axes
        ix=int(np.clip(np.searchsorted(xs,x)-1,0,len(xs)-2))
        iz=int(np.clip(np.searchsorted(zs,z)-1,0,len(zs)-2))
        x0,x1=xs[ix:ix+2];z0,z1=zs[iz:iz+2]
        u,v=(x-x0)/(x1-x0),(z-z0)/(z1-z0)
        if u<v:
            return (1-v)*ground_height(x0,z0)+(v-u)*ground_height(x0,z1)+u*ground_height(x1,z1)
        return (1-u)*ground_height(x0,z0)+(u-v)*ground_height(x1,z0)+v*ground_height(x1,z1)
    contacts=[]
    for side in [-1,1]:
        gaps=[]
        for x,y,z in g.pos:
            if y>.095 or x*side<=0:continue
            wx=pos[0]+size*(x*math.cos(yaw)+z*math.sin(yaw))
            wz=pos[2]+size*(-x*math.sin(yaw)+z*math.cos(yaw))
            gaps.append(size*y+pos[1]-floor_y_at(wx,wz))
        contacts.append(min(gaps))
    lift=-sum(contacts)*.5-.004
    for i,(x,y,z) in enumerate(g.pos):
        if y<.55:
            side=0 if x<0 else 1
            influence=1.-float(np.clip((y-.095)/.455,0.,1.))
            correction=(-contacts[side]-.004-lift)/size
            g.pos[i]=V(x,y+influence*correction,z)
    doc.place(doc.mesh(g,name),name,(pos[0],pos[1]+lift,pos[2]),yaw,(size,)*3)


if __name__=="__main__":
    doc=Document()
    house()
    landscape()
    pond()
    plant_forest()
    visitor((-1.83,0,5.48),1.02,1.18,rgb("94594f"),rgb("4d423a"))
    visitor((-1.01,0,5.22),1.00,-1.05,rgb("4e5362"),rgb("b6a893"))
    target=OUT/"forest_clearing.glb"
    doc.finish(target)
    triangles=[doc.data["accessors"][p["indices"]]["count"]//3 for m in doc.data["meshes"] for p in m["primitives"]]
    print(f"{target}: {len(doc.data['nodes'])} instances, {len(triangles)} meshes, {sum(triangles)} unique triangles, {target.stat().st_size} bytes")
