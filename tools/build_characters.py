"""Original low-poly combat cast. Blender 4.3: blender -b -P tools/build_characters.py
Ten transparent sprites and one editable scene; no downloaded assets.
All dimensions/materials are authored here; deterministic and CPU-renderable.
Optional incremental render: blender -b -P tools/build_characters.py -- --only juggernaut
"""
import bpy, math, os, sys, argparse
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'assets','combat'); os.makedirs(OUT,exist_ok=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for collection in list(bpy.data.collections):
 if collection.name!='Collection' and collection.users==0: bpy.data.collections.remove(collection)

def material(name, color, metal=0, glow=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
 p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=.38
 if glow:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=glow
 return m
M={
 'steel':material('Moon steel',(.22,.39,.50),.7),
 'silver':material('Blade edge',(.58,.75,.79),.75),
 'gold':material('Old sun gold',(.88,.53,.16),.7),
 'dark':material('Deep shadow',(.019,.035,.055)),
 'teal':material('Warden cloth',(.025,.32,.36)),
 'green':material('Scout green',(.10,.29,.16)),
 'leather':material('Warm leather',(.26,.105,.04)),
 'skin':material('Warm porcelain',(.72,.43,.25)),
 'purple':material('Scholar violet',(.23,.12,.40)),
 'stone':material('Slate construct',(.17,.22,.29),.35),
 'moss':material('Moss skin',(.28,.48,.13)),
 'leaf':material('Leaf tips',(.47,.72,.20)),
 'rose':material('Regent crimson',(.39,.06,.095)),
 'jade':material('Jade glow',(.12,.88,.68),.2,2),
 'amber':material('Amber glow',(1,.49,.07),.2,2),
 'lilac':material('Spell light',(.54,.28,1),.1,2),
}
M['brass']=material('Weathered brass',(.49,.28,.075),.72)
active=None

def finish(obj,name,mat):
 obj.name=name
 if mat:obj.data.materials.append(M[mat])
 for c in list(obj.users_collection):c.objects.unlink(obj)
 active.objects.link(obj)
 return obj

def orb(name,loc,scale,mat,sub=1):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=loc)
 o=finish(bpy.context.object,name,mat);o.scale=scale;return o

def box(name,loc,scale,mat,bevel=.06):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
 o=finish(bpy.context.object,name,mat);o.scale=scale
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  b=o.modifiers.new('Soft forged edges','BEVEL');b.width=bevel;b.segments=1
  o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
 return o

def cone(name,loc,r1,r2,depth,mat,vertices=8):
 bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r1,radius2=r2,depth=depth,location=loc)
 return finish(bpy.context.object,name,mat)

def rod(name,a,b,r,mat,vertices=8):
 a,b=Vector(a),Vector(b);o=cone(name,(a+b)/2,r,r,(b-a).length,mat,vertices)
 o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o

def curve(name,points,r,mat):
 d=bpy.data.curves.new(name,'CURVE');d.dimensions='3D';d.resolution_u=1;d.bevel_depth=r;d.bevel_resolution=0;d.resolution_u=1
 poly=d.splines.new('POLY');poly.points.add(len(points)-1)
 for p,co in zip(poly.points,points):p.co=(*co,1)
 o=bpy.data.objects.new(name,d);active.objects.link(o);o.data.materials.append(M[mat]);return o

def eyes(z,spacing=.14,y=-.35,color='jade',x=0):
 for s in [-1,1]:box('Eye', (x+s*spacing,y,z),(.105,.04,.07),color,.012)

def boots(mat='leather',size=1):
 for x in [-.26,.26]:
  rod('Leg',(x,0,.30),(x,0,1.05),.16*size,mat)
  box('Boot',(x,-.12,.22),(.34*size,.53,.36),mat)

def arms(mat,hand='leather',wide=.67):
 for sign in [-1,1]:
  orb('Shoulder',(sign*.49,0,1.60),(.28,.29,.31),mat)
  rod('Upper arm',(sign*.50,0,1.52),(sign*wide,-.03,1.18),.16,mat)
  orb('Glove',(sign*wide,-.07,1.04),(.19,.19,.22),hand)

def new(name):
 global active
 active=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(active)
 return active

new('warden')
boots('steel');cone('Tunic',(0,.03,1.05),.47,.38,.65,'teal')
box('Breastplate',(0,-.01,1.45),(.85,.51,.77),'steel',.10)
box('Belt',(0,-.02,1.08),(.89,.55,.13),'gold',.02)
arms('steel');orb('Helmet',(0,0,2.05),(.40,.34,.40),'steel',2)
box('Face visor',(0,-.31,2.06),(.48,.10,.17),'dark',.02);eyes(2.07,y=-.37)
rod('Helmet crest',(0,0,2.32),(0,.17,2.68),.10,'gold')
# Shield is a broad faceted silhouette, angled slightly forward.
shield=cone('Sun shield',(-.71,-.27,1.22),.53,.46,.14,'gold',6);shield.rotation_euler[0]=math.pi/2
shield=cone('Shield enamel',(-.71,-.37,1.22),.42,.42,.05,'teal',6);shield.rotation_euler[0]=math.pi/2
box('Shield sigil',(-.71,-.42,1.22),(.10,.035,.51),'gold',.015)
rod('Sword grip',(.67,-.08,.85),(.67,-.08,1.25),.075,'leather')
box('Sword guard',(.67,-.08,1.25),(.43,.13,.09),'gold',.025)
blade=cone('Sword blade',(.67,-.08,1.90),.11,.015,1.24,'silver',4)

new('ranger')
boots();cone('Scout coat',(0,.02,1.12),.43,.32,.82,'green')
box('Chest strap',(0,-.25,1.48),(.75,.10,.12),'leather',.02)
arms('green',wide=.62)
orb('Hood',(0,.05,2.02),(.45,.39,.44),'green',2)
orb('Face',(0,-.28,1.99),(.27,.10,.29),'skin',2)
box('Hood brow',(0,-.37,2.17),(.53,.09,.10),'dark',.02)
eyes(2.04,y=-.388,spacing=.105,color='dark')
cone('Hood peak',(0,.10,2.40),.27,0,.38,'green')
# Tall recurved bow, bright string and one visible arrow.
bow=[(.90,-.12,.25),(1.09,-.12,.55),(1.15,-.12,1.25),(1.06,-.12,1.95),(.87,-.12,2.24)]
curve('Recurved bow',bow,.065,'leather');rod('Bow string',bow[0],bow[-1],.013,'gold',6)
rod('Arrow',(.55,-.17,1.15),(1.35,-.17,1.15),.025,'silver',6)
arrow=cone('Arrow point',(1.39,-.17,1.15),.08,0,.18,'gold',4);arrow.rotation_euler[1]=math.pi/2
box('Quiver',(-.31,.28,1.53),(.30,.30,.84),'leather',.04)
for x in [-.40,-.27,-.15]:rod('Spare arrow',(x,.30,1.90),(x,.30,2.44),.025,'gold')

new('scholar')
cone('Long robe',(0,.02,1.02),.58,.29,1.64,'purple',10)
cone('Gold hem',(0,.02,.28),.59,.57,.09,'gold',10)
cone('Gold collar',(0,.02,1.72),.34,.40,.14,'gold',10)
arms('purple',wide=.60)
orb('Face',(0,-.05,2.02),(.29,.27,.32),'skin',2)
eyes(2.07,y=-.31,spacing=.10,color='dark')
cone('Hat brim',(0,.02,2.27),.54,.53,.12,'purple',10)
cone('Scholar hat',(0,.04,2.59),.40,.02,.64,'purple',8)
cone('Hat band',(0,.02,2.35),.36,.34,.10,'gold')
rod('Staff',(.73,0,.10),(.73,0,2.53),.065,'leather')
for dx in [-.12,.12]:rod('Staff prong',(.73,0,2.36),(.73+dx,0,2.65),.045,'gold')
orb('Spell orb',(.73,0,2.77),(.20,.20,.20),'lilac',2)
book=box('Spell book',(-.66,-.12,1.13),(.40,.18,.53),'gold',.025);book.rotation_euler[1]=-.18
box('Book cover',(-.66,-.23,1.13),(.35,.045,.46),'purple',.02)

new('mossling')
orb('Root body',(0,0,1.0),(.83,.59,.84),'moss',2)
orb('Upper face',(0,-.27,1.24),(.68,.40,.60),'leaf',1)
for sign in [-1,1]:
 rod('Root arm',(sign*.61,0,1.15),(sign*.93,-.12,.73),.13,'leather')
 orb('Root fist',(sign*.95,-.14,.64),(.23,.19,.23),'moss')
 rod('Root foot',(sign*.37,.0,.45),(sign*.49,-.19,.16),.19,'leather')
 for i in range(2):rod('Toe',(sign*.49,-.14,.16),(sign*(.40+i*.17),-.46,.10),.06,'leather')
eyes(1.35,spacing=.22,y=-.65,color='dark')
box('Mouth',(0,-.67,1.05),(.25,.03,.055),'dark',.01)
for x,z,ang in [(-.36,1.94,-.45),(0,2.10,0),(.35,1.93,.45)]:
 leaf=cone('Crown leaf',(x,0,z),.19,0,.68,'leaf',4);leaf.rotation_euler[1]=ang
orb('Seed lantern',(0,-.62,.73),(.13,.09,.13),'jade')

new('sentinel')
for x in [-.34,.34]:
 box('Pillar leg',(x,0,.54),(.34,.40,.90),'stone')
 box('Square foot',(x,-.14,.18),(.48,.64,.25),'steel')
box('Construct torso',(0,0,1.36),(1.0,.62,.84),'stone',.12)
box('Core housing',(0,-.35,1.40),(.43,.14,.48),'gold',.055)
orb('Core',(0,-.46,1.40),(.15,.07,.18),'lilac')
for sign in [-1,1]:
 box('Large shoulder',(sign*.65,0,1.66),(.49,.56,.49),'steel',.09)
 rod('Elbow strut',(sign*.64,0,1.45),(sign*.74,0,.93),.12,'gold')
 box('Forearm',(sign*.74,-.05,.91),(.32,.40,.55),'stone')
box('Head',(0,0,2.08),(.57,.50,.50),'steel',.07)
box('Eye bar',(0,-.27,2.11),(.43,.05,.09),'lilac',.02)
cone('Antenna',(0,0,2.53),.10,0,.42,'gold',4)

new('colossus')
for x in [-.48,.48]:
 box('Massive pillar',(x,0,.58),(.60,.64,1.0),'stone',.09)
 box('Broad foot',(x,-.20,.17),(.78,.94,.26),'steel',.07)
box('Vault body',(0,0,1.62),(1.51,.89,1.23),'stone',.13)
box('Golden vault frame',(0,-.49,1.61),(.90,.13,.91),'gold',.07)
box('Vault door',(0,-.58,1.61),(.72,.09,.74),'steel',.04)
orb('Vault seal',(0,-.65,1.61),(.20,.08,.20),'amber')
for sign in [-1,1]:
 box('Colossal shoulder',(sign*.97,0,1.94),(.61,.76,.66),'gold',.10)
 box('Stone arm',(sign*1.03,0,1.29),(.53,.65,.85),'stone',.10)
 box('Hammer fist',(sign*1.03,-.14,.86),(.64,.76,.47),'steel',.08)
box('Vault head',(0,0,2.54),(.74,.64,.54),'stone',.09)
box('Angry brow',(0,-.35,2.66),(.68,.12,.12),'gold',.025)
eyes(2.53,y=-.345,spacing=.20,color='amber')
for x in [-.34,.34]:cone('Crenellation',(x,0,2.92),.16,.16,.25,'gold',4)

new('regent')
cone('Royal cloak',(0,.10,1.10),.75,.32,1.88,'rose',10)
cone('Cloak hem',(0,.10,.19),.77,.74,.12,'gold',10)
box('Royal breastplate',(0,-.09,1.62),(.69,.49,.65),'dark',.06)
orb('Heart jewel',(0,-.36,1.67),(.14,.08,.18),'amber')
for sign in [-1,1]:
 orb('Royal shoulder',(sign*.48,0,1.81),(.33,.36,.27),'gold')
 rod('Sleeve',(sign*.55,0,1.64),(sign*.69,-.02,1.21),.18,'rose')
 orb('Royal glove',(sign*.70,-.03,1.12),(.17,.18,.20),'gold')
orb('Regent mask',(0,-.015,2.20),(.35,.29,.37),'silver',2)
eyes(2.24,y=-.30,spacing=.13,color='amber')
box('Mask mouth',(0,-.31,2.08),(.10,.03,.11),'dark',.015)
cone('Crown band',(0,0,2.51),.39,.39,.16,'gold',10)
for a in range(5):
 angle=math.tau*a/5
 cone('Crown point',(.32*math.sin(angle),.28*math.cos(angle),2.76),.10,0,.43,'gold',4)
rod('Royal scepter',(.75,-.02,.23),(.75,-.02,2.42),.055,'gold')
orb('Scepter star',(.75,-.02,2.60),(.20,.17,.25),'amber')

new('stalker')
boots('dark',.85)
cone('Veil coat',(0,.04,1.13),.42,.27,1.04,'dark',10)
cone('Veil lining',(0,.04,.66),.44,.40,.11,'purple',10)
arms('dark',wide=.68)
orb('Veiled hood',(0,.035,2.04),(.40,.34,.43),'dark',2)
cone('Pointed cowl',(0,.08,2.38),.31,0,.49,'dark',6)
orb('Shadow face',(0,-.27,2.03),(.26,.08,.29),'dark')
eyes(2.09,y=-.35,spacing=.10,color='lilac')
box('Veil band',(0,-.32,1.91),(.43,.09,.16),'purple',.02)
for sign in [-1,1]:
 rod('Dagger grip',(sign*.68,-.08,1.06),(sign*.77,-.14,1.32),.055,'leather')
 dagger=cone('Curved shadow blade',(sign*.87,-.16,1.58),.095,0,.62,'silver',4)
 dagger.rotation_euler[1]=sign*.35
 box('Dagger hilt',(sign*.79,-.15,1.33),(.26,.12,.06),'purple',.018)
# Floating cloth tails maintain a readable spectral silhouette.
for sign in [-1,1]:
 tail=cone('Veil tail',(sign*.39,.17,.72),.12,0,1.03,'purple',4)
 tail.rotation_euler[1]=sign*.30

new('briar')
for sign in [-1,1]:
 rod('Root leg',(sign*.32,0,.25),(sign*.24,0,1.03),.20,'leather')
 orb('Root foot',(sign*.39,-.15,.20),(.31,.38,.17),'leather')
orb('Briar torso',(0,0,1.40),(.64,.47,.72),'moss',2)
box('Bark breastplate',(0,-.35,1.41),(.67,.18,.71),'leather',.08)
orb('Living core',(0,-.47,1.43),(.14,.07,.19),'jade')
for sign in [-1,1]:
 orb('Thorn shoulder',(sign*.58,0,1.73),(.38,.39,.33),'moss')
 rod('Branch arm',(sign*.65,0,1.58),(sign*.83,-.07,.98),.20,'leather')
 orb('Bark gauntlet',(sign*.84,-.10,.88),(.25,.27,.30),'moss')
 for z in [1.02,1.36,1.77]:
  thorn=cone('Outer thorn',(sign*(.98 if z<1.6 else .83),0,z),.13,0,.49,'gold',4)
  thorn.rotation_euler[1]=sign*1.05
orb('Briar head',(0,-.01,2.17),(.35,.32,.38),'leather',1)
eyes(2.23,y=-.31,spacing=.13,color='jade')
for x in [-.27,0,.27]:
 thorn=cone('Branch crown',(x,.04,2.57),.12,0,.59,'moss',4)
 thorn.rotation_euler[1]=x*1.3

new('juggernaut')
# A compact boiler knight: the three illuminated chest cells count its charge.
for sign in [-1,1]:
 box('Brass boot',(sign*.36,-.16,.20),(.57,.72,.35),'brass',.08)
 box('Armored shin',(sign*.36,0,.61),(.43,.50,.63),'gold',.065)
 rod('Knee piston',(sign*.47,-.27,.45),(sign*.47,-.27,.94),.055,'silver')
box('Boiler waist',(0,0,1.02),(1.02,.65,.28),'dark',.07)
box('Heavy brass cuirass',(0,0,1.59),(1.20,.79,1.03),'brass',.15)
box('Charge panel rim',(0,-.44,1.56),(.66,.14,.78),'gold',.045)
box('Charge panel inset',(0,-.53,1.56),(.50,.07,.65),'dark',.025)
for index,z in enumerate([1.34,1.56,1.78],1):
 box('Charge cell %d'%index,(0,-.577,z),(.35,.035,.12),'amber',.017)
for sign in [-1,1]:
 box('Layered shoulder',(sign*.74,0,1.95),(.54,.74,.43),'gold',.075)
 rod('Upper arm piston',(sign*.77,0,1.74),(sign*.88,-.02,1.32),.12,'silver')
 box('Brass gauntlet',(sign*.88,-.06,1.24),(.43,.50,.48),'brass',.07)
# Deep visor and broad vented helm, deliberately distinct from the vault giant.
box('Boiler helmet',(0,-.005,2.36),(.68,.61,.56),'brass',.09)
box('Visor recess',(0,-.33,2.38),(.51,.08,.20),'dark',.025)
box('Charge visor',(0,-.38,2.40),(.38,.025,.065),'amber',.012)
for x in [-.20,0,.20]:box('Helmet vent',(x,-.33,2.21),(.055,.025,.11),'dark',.008)
cone('Exhaust collar',(-.39,.27,2.26),.14,.14,.38,'dark')
cone('Exhaust rim',(-.39,.27,2.48),.17,.17,.08,'gold')
# Raised great hammer. It stays wholly inside the shared 256px portrait frame.
rod('Hammer haft',(.91,-.05,.56),(.91,-.05,2.73),.073,'leather')
for z in [1.05,1.28,2.38]:cone('Haft grip ring',(.91,-.05,z),.095,.095,.065,'gold')
box('Great hammer head',(.91,-.05,2.70),(.97,.56,.49),'brass',.065)
for x in [.43,1.39]:box('Hammer striking face',(x,-.05,2.70),(.11,.65,.57),'steel',.028)
box('Hammer charge stripe',(.91,-.35,2.70),(.37,.035,.10),'amber',.012)

# Shared transparent portrait rig. Each character collection is render-isolated.
cast=[bpy.data.collections[n] for n in ['warden','ranger','scholar','mossling','sentinel','colossus','regent','stalker','briar','juggernaut']]
active=bpy.data.collections.new('Portrait rig');bpy.context.scene.collection.children.link(active)
scene=bpy.context.scene
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.21,.30,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.35
bpy.ops.object.camera_add(location=(4,-9,5.0));cam=finish(bpy.context.object,'Portrait camera',None)
cam.rotation_euler=(Vector((0,0,1.45))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=3.8;scene.camera=cam
for name,loc,color,power,size in [('Soft key',(-3,-4,7),(.76,.88,1),550,5),('Gold rim',(3,3,5),(1,.68,.30),700,3),('Front fill',(2,-5,2),(.40,1,.85),160,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=finish(bpy.context.object,name,None);o.data.energy=power;o.data.color=color;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,1.4))-o.location).to_track_quat('-Z','Y').to_euler()
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=96;scene.cycles.use_denoising=False
scene.render.resolution_x=256;scene.render.resolution_y=256;scene.render.resolution_percentage=100
scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.image_settings.color_depth='8'
scene.view_settings.view_transform='AgX'
parser=argparse.ArgumentParser(description='Render the original combat cast')
parser.add_argument('--only', nargs='+', help='Render selected sprites; the editable scene still contains every model')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
requested=set(args.only or [c.name for c in cast])
unknown=requested-{c.name for c in cast}
if unknown: raise ValueError('Unknown character: '+', '.join(sorted(unknown)))
for coll in cast:coll.hide_render=True
for coll in cast:
 if coll.name not in requested: continue
 coll.hide_render=False
 scene.render.filepath=os.path.join(OUT,coll.name+'.png')
 bpy.ops.render.render(write_still=True)
 coll.hide_render=True
cast[0].hide_render=False
scene.render.filepath=os.path.join(OUT,'warden.png')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'characters.blend'),compress=True)
print('COMBAT CAST COMPLETE: ten editable characters; rendered '+', '.join(sorted(requested)))
