"""Original low-poly models for the lava garden. Run from any directory with Python + NumPy."""
from pathlib import Path
import json, math, random, struct
import numpy as np

BASE = Path(__file__).resolve().parents[1]
ASSETS = BASE/'assets'
ASSETS.mkdir(exist_ok=True)
R=random.Random(3429)
FOV=56
TAN=math.tan(math.radians(FOV/2))
ASPECT=1704/960
TILT=math.radians(2.4)
CAM=np.array([0.,2.7,8.])
RIGHT=np.array([1.,0,0])
UP=np.array([0.,math.cos(TILT),-math.sin(TILT)])
BACK=np.cross(RIGHT,UP)
MATERIALS=['stone','warm_wood','petal','lumen']

def point(u,v,depth):
    return CAM+depth*((2*u-1)*TAN*ASPECT*RIGHT+(1-2*v)*TAN*UP-BACK)

def on_ground(u,v,y=.0):
    ray=point(u,v,1.)-CAM
    return CAM+ray*((y-CAM[1])/ray[1])

def srgb(h):
    rgb=np.array(list(bytes.fromhex(h.lstrip('#'))))/255
    return np.where(rgb<.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)

class Sculpt:
    def __init__(self):
        self.groups={}
    def tri(self,pts,color,tag='stone',factor=1.0):
        pts=np.asarray(pts,dtype=float)
        n=np.cross(pts[1]-pts[0],pts[2]-pts[0]); n=n/max(1.e-10,np.linalg.norm(n))
        g=self.groups.setdefault(tag,[[],[],[]])
        g[0].extend(pts);g[1].extend([n]*3);g[2].extend([np.clip(srgb(color)*factor,0,1)]*3)
    def quad(self,a,b,c,d,color,tag='stone',factor=1.):
        self.tri([a,b,c],color,tag,factor);self.tri([a,c,d],color,tag,factor)
    def save(self,name):
        buf=bytearray(); views=[]; access=[]; prims=[]
        def attr(values):
            a=np.array(values,dtype='<f4');offset=len(buf);raw=a.tobytes();buf.extend(raw)
            views.append(dict(buffer=0,byteOffset=offset,byteLength=len(raw),target=34962))
            access.append(dict(bufferView=len(views)-1,componentType=5126,type='VEC3',count=len(a),min=a.min(axis=0).tolist(),max=a.max(axis=0).tolist()))
            return len(access)-1
        for tag,(verts,norms,colors) in self.groups.items():
            prims.append(dict(attributes=dict(POSITION=attr(verts),NORMAL=attr(norms),COLOR_0=attr(colors)),material=MATERIALS.index(tag)))
        mats=[]
        for tag in MATERIALS:
            mat=dict(name=tag,doubleSided=True,pbrMetallicRoughness=dict(metallicFactor=0,roughnessFactor=.96))
            if tag=='lumen':
                mat['emissiveFactor']=[.42,.29,.001]
            mats.append(mat)
        gl=dict(asset=dict(version='2.0',generator='Lava Garden painted mineral palette'),scene=0,scenes=[dict(nodes=[0])],nodes=[dict(name=name,mesh=0)],meshes=[dict(name=name,primitives=prims)],buffers=[dict(byteLength=len(buf))],bufferViews=views,accessors=access,materials=mats)
        txt=json.dumps(gl,separators=(',',':')).encode();txt+=b' '*((-len(txt))%4)
        data=struct.pack('<4sII',b'glTF',2,28+len(txt)+len(buf))+struct.pack('<I4s',len(txt),b'JSON')+txt+struct.pack('<I4s',len(buf),b'BIN\0')+buf
        (ASSETS/(name+'.glb')).write_bytes(data)
        return sum(len(g[0])//3 for g in self.groups.values())

def ring_form(model, centers, radii, colors, sides=7, tag='stone',jitter=.09, phase=0., jagged=0.):
    rings=[];angles=[2*math.pi*i/sides+phase+R.uniform(-.065,.065) for i in range(sides)]
    for c,(rx,rz) in zip(centers,radii):
        ring=[]
        for a in angles:
            r=1+R.uniform(-jitter,jitter)
            ring.append(np.asarray(c)+[rx*math.cos(a)*r,R.uniform(-jagged,jagged),rz*math.sin(a)*r])
        rings.append(ring)
    for j,(bot,top) in enumerate(zip(rings,rings[1:])):
        for i in range(sides):
            k=(i+1)%sides;c=colors[min(j,len(colors)-1)]
            model.quad(bot[i],top[i],top[k],bot[k],c,tag,R.uniform(.90,1.08))
    for i in range(1,sides-1):
        model.tri([rings[-1][0],rings[-1][i+1],rings[-1][i]],colors[-1],tag)
        model.tri([rings[0][0],rings[0][i],rings[0][i+1]],colors[0],tag)

def boulder(model,center,size,palette):
    x,y,z=center; w,h,d=size
    levels=[(0.,.71),(.23,1.),(.70,.93),(1.,.56)]
    cs=[(x+R.uniform(-.10,.10)*w,y+t*h,z+R.uniform(-.09,.09)*d) for t,s in levels]
    start=len(model.groups.get('stone',[[]])[0])
    ring_form(model,cs,[(w*s,d*s) for _,s in levels],palette,R.randint(5,8),jitter=.14,phase=R.random(),jagged=.09*h)
    verts,norms,colors=model.groups['stone']
    for i in range(start,len(verts)):
        nx=(verts[i]-np.array([x,y+.45*h,z]))/np.array([w*w,h*h,d*d])
        nx/=max(.001,np.linalg.norm(nx))
        sn=norms[i]*.62+nx*.38;norms[i]=sn/np.linalg.norm(sn)
        t=np.clip((verts[i][1]-y)/h,.0,1.)
        colors[i]=colors[i]*(.77+.26*t)

def stem(model,path,radii,colors,tag='warm_wood'):
    pts=np.array(path)
    rings=[]
    for i,p in enumerate(pts):
        tangent=pts[min(i+1,len(pts)-1)]-pts[max(i-1,0)];tangent/=np.linalg.norm(tangent)
        a=np.cross(tangent,[0,0,1.]);a/=np.linalg.norm(a);b=np.cross(tangent,a)
        rings.append([p+radii[i]*(a*math.cos(2*math.pi*k/7)+b*math.sin(2*math.pi*k/7)) for k in range(7)])
    for i in range(len(rings)-1):
        for k in range(7):
            j=(k+1)%7; c=colors[min(i,len(colors)-1)]
            model.quad(rings[i][k],rings[i][j],rings[i+1][j],rings[i+1][k],c,tag,1.10 if k==2 else 1.0)

def drip(model,c,w,h):
    x,y,z=c
    ring_form(model,[(x,y-.50*h,z),(x,y-.37*h,z),(x,y+.04*h,z),(x,y+.43*h,z),(x,y+.5*h,z)],[(.22*w,.20*w),(.70*w,.59*w),(w,.87*w),(.85*w,.74*w),(.28*w,.26*w)],['fff517']*4,9,'lumen',.05)

def make_plants():
    m=Sculpt()
    root=on_ground(.122,.85,.10)
    depth=np.dot(CAM-root,BACK)
    coords=[(.122,.85),(.117,.758),(.093,.679),(.052,.592),(.043,.504),(.060,.444),(.090,.393),(.124,.327),(.139,.251),(.149,.216),(.164,.209),(.17,.233)]
    pts=[point(u,v,depth)-root for u,v in coords]
    stem(m,pts,[.54,.46,.35,.27,.22,.17,.135,.100,.076,.056,.040,.035],['805253','825156','884f50','9a534a','aa634a','bc6d49','c07947','cf8549','e49241'])
    a=pts[-1]; x,y,z=a
    cs=[(x,y-.73,z),(x-.01,y-.66,z),(x,y-.53,z),(x+.02,y-.53,z),(x+.04,y-.16,z),(x,y+.005,z)]
    ring_form(m,cs,[(.17,.16),(.19,.17),(.27,.24),(.23,.21),(.28,.24),(.18,.17)],['8f5773','94566e','96506b','a15770','ba626b'],8,'petal',.04)
    drip(m,(x,y-.80,z),.168,.32)
    return m,root,depth

def ribbon():
    m=Sculpt()
    path=[[0,.02,0],[-.34,.15,-.02],[-.61,.36,-.04],[-.65,.62,-.10],[-.45,.93,-.12],[-.23,1.04,-.10],[-.05,.98,-.10],[.03,.81,-.08]]
    stem(m,path,[.27,.21,.14,.12,.095,.065,.045,.035],['a63b5a','b33164','c42b62','cb2760','d82b61','e6385f'],'petal')
    drip(m,(.03,.76,-.08),.048,.12)
    return m

def spear():
    m=Sculpt()
    path=[[0,.0,0],[-.08,.40,.08],[-.22,.81,.05],[-.14,1.28,.04],[.04,1.62,0],[.12,1.88,.04],[.19,1.98,.04],[.24,1.88,.04]]
    stem(m,path,[.28,.23,.16,.12,.08,.048,.028,.025],['8f5e58','996955','b16a52','c17c56','dd8953'])
    ring_form(m,[(.24,1.58,.04),(.24,1.66,.04),(.24,1.79,.04),(.24,1.88,.04)],[(.09,.08),(.13,.12),(.11,.1),(.06,.06)],['c16675','d06c83','ca7485'],7,'petal',.06)
    drip(m,(.24,1.38,.04),.081,.46)
    return m

def shore():
    m=Sculpt()
    vv=[1.25,1.08,.98,.93,.88,.83,.78,.75,.72,.70,.682,.66,.645,.625,.603,.587,.563,.53]
    left=[-.35,-.05,.18,.30,.36,.39,.34,.27,.16,.29,.39,.46,.47,.51,.53,.505,.49,.54]
    right=[.64,.58,.555,.55,.53,.512,.493,.48,.49,.50,.53,.55,.565,.575,.56,.548,.526,.552]
    for sign,us in [(-1,left),(1,right)]:
        rows=[]
        for j,(v,u) in enumerate(zip(vv,us)):
            edge=on_ground(u,v)
            row=[]
            for k,offset in enumerate([0,.3,1.1,2.8,5.5,9.0,14.,22.]):
                h=[-.055,.12,.35,.47,.8,1.1,1.28,1.1][k]+R.uniform(-.13,.13)*min(offset,1)
                row.append(edge+np.array([offset*sign,h,R.uniform(-.15,.15)*min(offset,1)]))
            rows.append(row)
        pal=['9d869e','a28ba1','a18aa4','a88fa4','a1879f','a78da1']
        for j in range(len(rows)-1):
            for k in range(len(rows[j])-1):
                a,b,c,d=rows[j][k],rows[j+1][k],rows[j+1][k+1],rows[j][k+1]
                for tri in [(a,b,c),(a,c,d)]:
                    if np.cross(tri[1]-tri[0],tri[2]-tri[0])[1]<0: tri=tri[::-1]
                    m.tri(tri,R.choice(pal))
    return m

def walls():
    m=Sculpt()
    # Broad oblique rock faces establish the skyline before the smaller talus clusters.
    def slab(skyline,depth,face,shadow):
        top=[point(u,v,depth) for u,v in skyline]
        bottom=[np.array([t[0],-2.,t[2]+2.2]) for t in top]
        far=[t+np.array([.4,.1,-4.2]) for t in top]
        for i in range(len(top)-1):
            m.tri([bottom[i],bottom[i+1],top[i]],face,factor=.8+.05*(i%4))
            m.tri([bottom[i+1],top[i+1],top[i]],shadow,factor=.94+.03*(i%2))
            m.quad(top[i],top[i+1],far[i+1],far[i],face)
    slab([(-.3,.41),(-.03,.31),(.04,.29),(.14,.24),(.195,.26),(.31,.15),(.315,.31),(.44,.347),(.573,.413),(.61,.45)],32.,'af828a','aa7c85')
    slab([(.764,.55),(.805,.31),(.94,.306),(1.17,.27),(1.35,.44)],32.,'c2918e','a67986')
    # Layered stacks behind the basin. Their width and height are set against the target camera.
    rocks=[
       (-.05,.69,.365,.14,15),(.035,.56,.298,.10,17),(.094,.48,.247,.056,18),
       (.136,.56,.272,.075,16),(.185,.59,.34,.061,16),(.240,.57,.342,.052,15),
       (.292,.54,.276,.031,16),(.313,.56,.36,.073,17),(.354,.528,.333,.032,17),
       (.363,.538,.31,.019,17),(.379,.51,.389,.037,18),(.408,.545,.42,.038,18),
       (.436,.567,.457,.03,18),(.452,.588,.48,.035,18),(.477,.581,.51,.036,19),
       (.52,.591,.518,.03,20),(.555,.592,.509,.035,21),(.59,.589,.525,.034,21),
       (.641,.592,.427,.065,19),(.675,.61,.40,.056,18),(.688,.63,.432,.036,15),
       (.730,.638,.49,.04,15),(.772,.683,.537,.055,13),(.80,.681,.524,.045,14),
       (.823,.669,.552,.06,15),(.878,.676,.568,.094,13),(.962,.709,.547,.085,14),
       (1.045,.68,.469,.12,14)]
    muted=[['634d65','815f71','af7f82'],['755769','a86b60','c58a71'],['67546c','886778','b38687']]
    warm=[['89676e','bd785f','dd9a6d'],['94676a','c57f62','e4a779']]
    for i,(u,v,t,w,d) in enumerate(rocks):
        peak=point(u,t,d);foot=point(u,v,d);width=2*w*TAN*ASPECT*d
        pal=warm if i in {5,6,8,9,20,23,24} else muted
        boulder(m,foot,[width,max(.8,peak[1]-foot[1]),width*.77],R.choice(pal))
    # A broad amber mound supports the middle band of small lamps.
    mound=on_ground(.285,.642)
    boulder(m,mound+[0,-.30,0],[3.45,1.30,1.55],['876171','b9755b','d99756'])
    # A leaning pair makes a natural arch at the far stream entrance.
    for u,v,t,w in [(.57,.646,.52,.043),(.595,.587,.49,.036),(.618,.547,.439,.044),(.654,.513,.396,.050)]:
        foot=point(u,v,16.);peak=point(u,t,16.)
        boulder(m,foot,[w*31.,peak[1]-foot[1],w*17.],['645770','8c6e7b','d39178'])
    for i in range(44):
        u=R.uniform(-.09,1.10)
        if .475<u<.65: continue
        v=R.uniform(.585,.68);at=on_ground(u,v)
        w=R.uniform(.28,.83)
        boulder(m,at+[0,-.17,0],[w,R.uniform(.45,1.50),w*.9],R.choice(muted+warm))
    return m

def pool():
    m=Sculpt()
    for x,z,w,h in [(0,0,1.05,.17),(-.66,-.18,.54,.38),(.48,-.22,.72,.27),(.1,-.49,.39,.45),(.88,-.42,.22,.12)]:
        drip(m,(x,h*.45,z),w,h)
    return m

def tvec(v):
    return 'Vector3('+', '.join(f'{a:.6f}' for a in v)+')'

def main():
    m,root,depth=make_plants()
    shapes=dict(angler=m,spindle=spear(),ribbon=ribbon(),yellow_pool=pool(),banks=shore(),canyon=walls())
    counts={name:shape.save(name) for name,shape in shapes.items()}
    # Intersect the screen ray with actual cliff/shore triangles to plant small assets on the rock.
    geom=np.vstack([np.array(shapes[name].groups['stone'][0]).reshape(-1,3,3) for name in ['banks','canyon']])
    a=geom[:,0]; e1=geom[:,1]-a;e2=geom[:,2]-a;svec=CAM-a
    qvec=np.cross(svec,e1)
    def surface(u,v):
        ray=point(u,v,1.)-CAM
        pv=np.cross(ray,e2)
        det=np.einsum('ij,ij->i',e1,pv)
        inv=1/np.where(abs(det)>1.e-7,det,np.inf)
        bary=np.einsum('ij,ij->i',svec,pv)*inv
        b2=(qvec@ray)*inv
        d=np.einsum('ij,ij->i',e2,qvec)*inv
        hits=d[(bary>=0)&(b2>=0)&(bary+b2<=1)&(d>0)]
        return CAM+ray*hits.min() if len(hits) else on_ground(u,v,.10)
    objects=[]
    def add(name,at,scale=1,yaw=0):
        objects.append((name,np.array(at),scale,yaw))
    add('banks',[0,0,0]);add('canyon',[0,0,0]);add('angler',root)
    add('yellow_pool',surface(.204,.922)+[0,.025,0],1.11)
    add('yellow_pool',on_ground(.295,.906,.14),.44)
    # Match height by projecting artists' normalized reference landmarks onto level ground.
    specs=[('angler',.519,.709,.235,3.28),('spindle',.694,.792,.22,3.15),('spindle',.387,.681,.176,.35),('ribbon',.574,.742,.118,-.2),('ribbon',.206,.704,.044,-.2),('ribbon',.293,.645,.046,.12),('spindle',.297,.558,.105,.1),('spindle',.319,.549,.083,.22),('angler',.239,.564,.052,.1),('angler',.252,.56,.063,-.35),('spindle',.465,.627,.06,.0)]
    for tag,u,v,height,yaw in specs:
        at=surface(u,v)-[0,.03,0]
        d=np.dot(CAM-at,BACK)
        unit_height={'angler':depth*(.85-.21)*2*TAN,'spindle':1.98,'ribbon':1.04}[tag]
        scale=d*height*2*TAN/unit_height
        add(tag,at,scale,yaw)
        if tag!='ribbon': add('yellow_pool',at+[0,.005,.025],max(.1,scale*.55),yaw)
    for i in range(28):
        u=R.uniform(.04,.91);v=R.uniform(.55,.67)
        if .46<u<.61: continue
        at=surface(u,v)-[0,.03,0]
        add(R.choice(['spindle','ribbon']),at,R.uniform(.3,1.03),R.uniform(-1.4,1.4))
        if i%2==0:add('yellow_pool',at+[.25,0,.15],R.uniform(.2,.56))
    for u,v,scale in [(.156,.811,.40),(.372,.684,.32),(.485,.698,.16),(.647,.97,.32),(.70,.80,.18),(.66,.78,.18),(.56,.637,.16),(.629,.733,.17)]:
        add('yellow_pool',surface(u,v)+[0,.01,0],scale)
    for i in range(33):
        u,v=R.choice([(.32,.665),(.16,.59),(.49,.67),(.575,.735),(.664,.78)])
        u+=R.uniform(-.065,.065);v+=R.uniform(-.022,.022)
        at=surface(u,v)
        if at[1]>.025:
            add('yellow_pool',at,R.uniform(.05,.17),R.uniform(-3.,3.))
    hdr='[gd_scene format=3]\n\n'+''.join(f'[ext_resource type="PackedScene" path="res://examples/lava/assets/{n}.glb" id="{n}"]\n' for n in shapes)
    txt=hdr+'\n[node name="VolcanicGarden" type="Node3D"]\n'
    for i,(n,at,s,y) in enumerate(objects):
        txt+=f'\n[node name="{n.title()}{i:02d}" parent="." instance=ExtResource("{n}")]\nposition = {tvec(at)}\nscale = {tvec([s]*3)}\nrotation = Vector3(0,{y:.6f},0)\n'
    (BASE/'garden.tscn').write_text(txt)
    (BASE/'source'/'geometry.json').write_text(json.dumps(dict(asset_triangles=counts,instances=len(objects),seed=3429,camera_fov=FOV),indent=2)+'\n')
    print(counts,len(objects))
if __name__=='__main__':main()
