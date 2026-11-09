"""Original chunky map-only models. blender -b -t 4 -P tools/build_map_icons.py
Sixteen map-specific icons; no combat asset overwritten. -- --only NAME supported.
"""
import bpy, math, os, sys, argparse
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'assets','map_icons'); os.makedirs(OUT,exist_ok=True)
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
M['navy']=material('Cartographer midnight blue',(.035,.075,.16))
M['paper']=material('Warm map parchment',(.78,.65,.40))
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


# Exaggerated head and equipment geometry for 56px gameplay display.
def body(mat):
 cone('Broad torso',(0,0,.70),.55,.43,.95,mat)
 for x in [-.25,.25]: box('Short boot',(x,-.03,.17),(.40,.51,.30),'dark')
def head(mat='skin'):
 orb('Large head',(0,0,1.43),(.47,.38,.43),mat,2)

def disk(name,x,z,r,mat):
 o=cone(name,(x,-.43,z),r,r,.14,mat,8);o.rotation_euler[0]=math.pi/2;return o

new('warden');body('teal');head('steel')
box('Dark visor',(0,-.35,1.46),(.61,.12,.19),'dark');eyes(1.46,.17,-.43,'jade')
disk('Oversize shield rim',-.48,.79,.52,'silver');disk('Shield face',-.48,.79,.43,'teal')
box('Shield stripe',(-.48,-.55,.79),(.12,.05,.61),'gold')
rod('Upright sword',(.55,-.1,.35),(.55,-.1,1.83),.09,'silver',4)
box('Crossguard',(.55,-.1,.81),(.44,.18,.12),'gold')

new('ranger');body('green');head()
cone('Large hood',(0,.04,1.48),.55,.18,.94,'green',6)
box('Visible face',(0,-.37,1.43),(.48,.1,.39),'skin')
eyes(1.48,.13,-.44,'dark')
curve('Oversize longbow',[(-.78,-.42,1.78),(-1,-.42,1.18),(-.87,-.42,.51)],.09,'gold')
rod('Bright bowstring',(-.78,-.42,1.78),(-.87,-.42,.51),.025,'silver')
rod('Horizontal arrow',(-.85,-.52,1.09),(.68,-.52,1.09),.055,'silver')
cone('Arrow point',(.71,-.52,1.09),.14,0,.33,'silver',4).rotation_euler[1]=math.pi/2

new('scholar');body('purple');head();eyes(1.46,.14,-.37,'dark')
cone('Broad hat brim',(0,0,1.74),.76,.76,.13,'purple')
cone('Tall pointed hat',(-.08,0,2.00),.41,0,.58,'purple')
rod('Staff',(.68,-.08,.14),(.68,-.08,1.9),.085,'gold')
orb('Great spell crystal',(.68,-.08,1.97),(.24,.21,.26),'lilac')
box('Open tome',(-.43,-.42,.86),(.6,.18,.43),'paper')

new('mossling')
orb('Wide round moss body',(0,0,.77),(.87,.54,.70),'moss',2)
for x in [-.56,.56]:
 cone('Large leaf horn',(x,0,1.38),.26,0,.67,'leaf',4)
 orb('Root foot',(x,-.14,.19),(.30,.35,.18),'leather')
box('Face mask',(0,-.47,.87),(.72,.08,.35),'dark');eyes(.9,.22,-.54,'amber')

new('stalker');body('purple')
cone('Triangular hood',(0,0,1.45),.63,0,1.15,'purple',4)
box('Black face',(0,-.36,1.41),(.54,.11,.34),'dark');eyes(1.44,.17,-.44,'lilac')
for x in [-.68,.68]:
 o=cone('Huge hooked dagger',(x,-.12,.97),.21,0,1.10,'silver',3);o.rotation_euler[1]=-.30 if x<0 else .30

new('ferryman');body('steel');head('silver')
box('Horizontal visor',(0,-.35,1.46),(.64,.11,.14),'dark')
# A giant one-sided rectangular slab is deliberately unlike the hood ambusher.
box('One-sided tower shield',(-.58,-.44,1.02),(.75,.20,1.65),'silver',.10)
box('Shield blue inset',(-.58,-.56,1.02),(.56,.05,1.41),'teal',.06)
box('Shield horizontal stripe',(-.58,-.60,1.05),(.58,.04,.16),'gold')
rod('Short pike',(.59,-.02,.15),(.59,-.02,1.95),.065,'gold')
cone('Pike tip',(.59,-.02,2.02),.15,0,.34,'silver',4)

new('jailer');body('rose')
box('Square cage helm',(0,0,1.47),(1.00,.72,.84),'gold',.04)
box('Cage darkness',(0,-.39,1.47),(.83,.08,.61),'dark',.01)
for x in [-.30,0,.30]:box('Thick cage bar',(x,-.46,1.47),(.10,.1,.63),'silver',.01)
for x in [-.23,.23]:orb('Cell eyes',(x,-.44,1.46),(.065,.04,.065),'amber')
curve('Heavy chain',[(-.57,0,1.05),(-.81,-.1,.74),(-.75,-.2,.40)],.095,'silver')
disk('Key bow',.69,1.05,.25,'gold');disk('Key hole',.69,1.05,.12,'dark')
rod('Key shaft',(.69,-.43,.86),(.69,-.43,.30),.09,'gold')
box('Key teeth',(.83,-.43,.34),(.36,.17,.17),'gold')


# Remaining enemies use silhouette-coded geometry rather than recoloured portraits.
new('sentinel');body('stone')
box('Square stone head',(0,0,1.53),(.88,.65,.69),'stone')
box('Single cyan eye',(0,-.36,1.55),(.52,.08,.15),'jade')
for x in [-.68,.68]:box('Block arm',(x,0,.91),(.37,.48,.80),'silver')
disk('Exposed circular core',0,.79,.22,'jade')

new('briar');body('leather');head('leather');eyes(1.46,.18,-.38,'amber')
for x in [-.63,.63]:
 for z in [.56,1.02,1.48]:
  o=cone('Large lateral thorn',(x,0,z),.19,0,.59,'leaf',4);o.rotation_euler[1]=(-1 if x<0 else 1)*math.pi/2
cone('Central branch crown',(0,0,1.91),.17,0,.56,'leaf',4)

new('juggernaut');body('gold');head('brass')
box('Heavy face slit',(0,-.36,1.46),(.62,.10,.17),'dark')
for z in [.57,.82,1.07]:box('Countable charge block',(0,-.49,z),(.28,.12,.15),'amber')
rod('Great hammer haft',(.7,-.05,.15),(.7,-.05,1.58),.10,'leather')
box('Broad hammer head',(.67,-.05,1.75),(.76,.57,.48),'silver')
box('Square pauldron',(-.62,0,1.20),(.47,.64,.51),'gold')

new('colossus')
box('Huge vault body',(0,0,.92),(1.32,.68,1.15),'steel',.15)
box('Recessed vault face',(0,-.39,1.29),(.78,.10,.38),'dark')
eyes(1.30,.23,-.46,'amber')
for x in [-.86,.86]:box('Massive pillar fist',(x,-.02,.72),(.47,.62,.93),'gold',.1)
for x in [-.4,.4]:box('Foundation boot',(x,-.05,.18),(.58,.59,.34),'steel')
disk('Vault dial',0,.70,.30,'gold');disk('Dial center',0,.70,.13,'dark')

new('regent');body('rose');head();eyes(1.46,.14,-.38,'dark')
cone('Wide crown band',(0,0,1.80),.48,.48,.19,'gold')
for x in [-.39,0,.39]:cone('Crown point',(x,0,2.03),.15,0,.45,'gold',4)
rod('Sceptre',(.63,0,.22),(.63,0,1.75),.07,'gold');orb('Royal red orb',(.63,0,1.89),(.23,.21,.23),'rose')
for x in [-.49,.49]:orb('White ermine collar',(x,-.15,1.10),(.27,.23,.22),'silver')

new('archivist')
cone('Sealed armored column',(0,0,.92),.53,.42,1.43,'teal')
cone('Faceless angular helm',(0,0,1.75),.39,0,.56,'silver',4)
for z,r in [(.42,.73),(.99,.77),(1.56,.66)]:
 bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=6,major_radius=r,minor_radius=.075,location=(0,0,z))
 finish(bpy.context.object,'Broad floating orbit','gold')
box('Bright sealed core',(0,-.45,.98),(.23,.10,.62),'jade')

# Legacy B is a separate horned gate brute, never a duplicate king.
new('gate_brute');body('leather');head('rose')
for x in [-.46,.46]:cone('Tall horn',(x,0,1.98),.21,0,.70,'paper',4)
eyes(1.46,.17,-.39,'amber')
box('Wide toothed jaw',(0,-.34,1.17),(.65,.19,.23),'paper')
rod('Club haft',(.68,0,.25),(.68,0,1.50),.11,'leather')
orb('Spiked club head',(.68,0,1.65),(.32,.30,.38),'stone')

# Friendly NPCs: readable map tools and travel kit, no combat weapons.
new('ilen');body('navy');head();eyes(1.46,.14,-.38,'dark')
cone('Cartographer cap',(0,0,1.77),.49,.34,.21,'navy')
box('Large opened map',(-.15,-.51,.89),(.93,.12,.60),'paper',.025)
for x in [-.61,.31]:rod('Map scroll roller',(x,-.53,.56),(x,-.53,1.22),.07,'gold')
curve('Bold map route',[(-.43,-.59,.75),(-.18,-.59,.98),(.12,-.59,.87)],.025,'teal')
disk('Survey ring',.64,1.10,.28,'gold');disk('Survey ring hole',.64,1.10,.17,'dark')

new('mira');body('leather');head();eyes(1.46,.14,-.38,'dark')
box('Big travel backpack',(-.50,.15,.98),(.60,.52,.86),'gold',.10)
cone('Map tube',(.55,.06,1.14),.16,.16,1.11,'paper')
cone('Tube cap',(.55,.06,1.72),.19,.19,.10,'gold')
box('Bright scarf collar',(0,-.18,1.20),(.92,.37,.22),'teal')
box('Long scarf tail',(.24,-.44,.88),(.24,.10,.67),'teal')
box('Field notebook',(-.43,-.49,.84),(.45,.13,.53),'paper',.03)
box('Notebook spine',(-.62,-.57,.84),(.10,.05,.52),'navy')

names=['warden','ranger','scholar','mossling','stalker','ferryman','jailer','sentinel','briar','juggernaut','colossus','regent','archivist','gate_brute','ilen','mira']
cast=[bpy.data.collections[n] for n in names]
active=new('Map icon rig');scene=bpy.context.scene
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
bpy.ops.object.camera_add(location=(.5,-8,3.6));cam=finish(bpy.context.object,'Map orthographic camera',None)
cam.rotation_euler=(Vector((0,0,1.03))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.65;scene.camera=cam
for name,loc,power,size in [('Broad key',(-3,-4,6),500,4),('Bright rim',(3,2,4),650,3),('Face fill',(0,-4,2),120,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=finish(bpy.context.object,name,None);o.data.energy=power;o.data.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=64;scene.cycles.use_denoising=False
scene.render.resolution_x=128;scene.render.resolution_y=128;scene.render.resolution_percentage=100
scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='AgX'
p=argparse.ArgumentParser();p.add_argument('--only',nargs='+');a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
requested=set(a.only or names);assert requested.issubset(names)
for c in cast:c.hide_render=True
for c in cast:
 if c.name not in requested:continue
 c.hide_render=False
 cam.location=(.5,-8,3.6);cam.rotation_euler=(Vector((0,0,1.03))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=2.65
 # Fit each distinct silhouette to 94% of the icon, not a shared portrait box.
 bpy.context.view_layer.update()
 points=[world_to_camera_view(scene,cam,o.matrix_world@Vector(v)) for o in c.objects if o.type in {'MESH','CURVE'} for v in o.bound_box]
 loX,hiX=min(p.x for p in points),max(p.x for p in points)
 loY,hiY=min(p.y for p in points),max(p.y for p in points)
 cam.location+=cam.rotation_euler.to_quaternion()@Vector((((loX+hiX)/2-.5)*cam.data.ortho_scale,((loY+hiY)/2-.5)*cam.data.ortho_scale,0))
 cam.data.ortho_scale*=max(hiX-loX,hiY-loY)/.94
 bpy.context.view_layer.update()
 scene.render.filepath=os.path.join(OUT,c.name+'.png');bpy.ops.render.render(write_still=True);c.hide_render=True
cast[0].hide_render=False
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'map_icons.blend'),compress=True)
print('MAP ICONS COMPLETE',sorted(requested))
