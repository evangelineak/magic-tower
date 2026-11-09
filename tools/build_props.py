"""Original low-poly tower props, no external assets.
Rebuild: blender -b -P tools/build_props.py
Incremental: blender -b -P tools/build_props.py -- --only winch
The single editable .blend contains both prop collections and the portrait rig.
"""
import argparse
import math
import os
import sys
import bpy
from mathutils import Vector, Matrix

ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'assets','props')
os.makedirs(OUT,exist_ok=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name,rgb,metal=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*rgb,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*rgb,1)
 p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=.37
 return m
M={'brass':material('Weathered prop brass',(.57,.32,.085),.70),
   'gold':material('Prop gold edging',(.87,.56,.20),.65),
   'steel':material('Cool forged faces',(.29,.43,.50),.65),
   'dark':material('Charcoal frame',(.025,.055,.075),.35),
   'teal':material('Teal enamel',(.025,.32,.31),.20),
   'leather':material('Grip leather',(.20,.075,.025))}
active=None

def start(name):
 global active
 active=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(active)
 return active

def finish(obj,name,key=None):
 obj.name=name
 if key:obj.data.materials.append(M[key])
 for c in list(obj.users_collection):c.objects.unlink(obj)
 active.objects.link(obj)
 return obj

def box(name,loc,size,key,bevel=.04):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
 o=finish(bpy.context.object,name,key);o.scale=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('Forged edges','BEVEL');mod.width=bevel;mod.segments=1
  o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 return o

def cylinder(name,a,b,radius,key,vertices=12):
 a,b=Vector(a),Vector(b)
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=(b-a).length,location=(a+b)/2)
 o=finish(bpy.context.object,name,key);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
 return o

def torus(name,loc,radius,width,key,rotation=(0,0,0)):
 bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=6,major_radius=radius,minor_radius=width,location=loc,rotation=rotation)
 return finish(bpy.context.object,name,key)

def cable(name,points,width,key):
 data=bpy.data.curves.new(name,'CURVE');data.dimensions='3D';data.bevel_depth=width;data.bevel_resolution=0
 line=data.splines.new('POLY');line.points.add(len(points)-1)
 for p,co in zip(line.points,points):p.co=(*co,1)
 o=bpy.data.objects.new(name,data);active.objects.link(o);data.materials.append(M[key]);return o

start('winch')
# Broad base and two upright cheeks read as a stationary mechanical device.
box('Winch plinth',(0,0,.16),(1.91,1.05,.25),'dark',.08)
box('Plinth rim',(0,0,.30),(1.81,.99,.10),'brass',.025)
for side in [-1,1]:
 box('Winch cheek',(side*.70,0,.82),(.20,.68,1.03),'teal',.065)
 cylinder('Axle boss',(side*.70,0,1.04),(side*.87,0,1.04),.20,'brass')
 for y in [-.29,.29]:
  cylinder('Base bolt',(side*.68,y,.33),(side*.68,y,.41),.055,'gold',6)
cylinder('Drum axle',(-.89,0,1.04),(.91,0,1.04),.105,'steel')
cylinder('Cable drum',(-.54,0,1.04),(.54,0,1.04),.34,'dark')
for x in [-.56,.56]:cylinder('Drum flange',(x-.045,0,1.04),(x+.045,0,1.04),.47,'gold',12)
# Distinct thick windings, not tiny texture-only lines.
for i in range(9):torus('Cable winding',(-.45+i*.1125,0,1.04),.345,.042,'teal',(0,math.pi/2,0))
cable('Paying-out cable',[(.04,-.34,1.04),(.04,-.63,.89),(.04,-.70,.48)],.037,'teal')
# Open hook remains visibly separate from the plinth at map-icon scale.
cable('Load hook',[(.04,-.70,.48),(.04,-.70,.26),(.16,-.70,.18),(.30,-.70,.25),(.30,-.70,.37)],.045,'gold')
# Right-hand crank with a broad grip.
cylinder('Crank spindle',(.90,0,1.04),(1.01,0,1.04),.075,'brass')
cylinder('Crank arm',(1.01,0,1.04),(1.01,-.37,1.31),.06,'gold',8)
cylinder('Crank grip',(.98,-.37,1.31),(1.24,-.37,1.31),.10,'leather',10)

start('maul')
# Large horizontal striking block and long slender handle: immediately distinct
# from a sword, and legible without a text label at fifty pixels.
cylinder('Maul handle',(0,0,.17),(0,0,2.16),.105,'leather',10)
for z in [.28,.47,.66,.85,1.04]:
 torus('Grip band',(0,0,z),.108,.018,'teal')
cylinder('Pommel',(0,0,.10),(0,0,.25),.155,'gold',10)
cylinder('Head collar',(0,0,1.86),(0,0,2.08),.18,'brass',10)
box('Maul striking block',(0,0,2.18),(1.55,.61,.56),'brass',.085)
box('Head enamel band',(0,-.32,2.18),(.48,.07,.43),'teal',.025)
for sign in [-1,1]:
 box('Maul steel face',(sign*.78,0,2.18),(.13,.73,.67),'steel',.04)
 box('Face inset',(sign*.855,0,2.18),(.025,.47,.40),'gold',.012)
 for z in [2.01,2.35]:
  cylinder('Maul rivet',(sign*.43,-.31,z),(sign*.43,-.37,z),.035,'gold',6)
# Slight lean avoids a generic UI plus-sign silhouette.
for o in list(active.objects):
 o.matrix_world=Matrix.Rotation(-.16,4,'Y') @ o.matrix_world

props=[bpy.data.collections[n] for n in ['winch','maul']]
start('Prop portrait rig')
scene=bpy.context.scene;scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.21,.30,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.35
bpy.ops.object.camera_add(location=(4,-9,5));cam=finish(bpy.context.object,'Prop camera')
cam.data.type='ORTHO';scene.camera=cam
for name,loc,color,power,size in [('Soft key',(-3,-4,7),(.76,.88,1),550,5),('Gold rim',(3,3,5),(1,.68,.30),700,3),('Front fill',(2,-5,2),(.40,1,.85),160,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=finish(bpy.context.object,name)
 o.data.energy=power;o.data.color=color;o.data.shape='DISK';o.data.size=size
 o.rotation_euler=(Vector((0,0,1.1))-o.location).to_track_quat('-Z','Y').to_euler()
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=96;scene.cycles.use_denoising=False
scene.render.resolution_x=256;scene.render.resolution_y=256;scene.render.resolution_percentage=100
scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.image_settings.color_depth='8'
scene.view_settings.view_transform='AgX'
parser=argparse.ArgumentParser();parser.add_argument('--only',nargs='+',choices=['winch','maul'])
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
requested=set(args.only or ['winch','maul'])
for coll in props:coll.hide_render=True
for coll in props:
 if coll.name not in requested:continue
 coll.hide_render=False
 target=(0,0,.79) if coll.name=='winch' else (-.12,0,1.24)
 cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
 cam.data.ortho_scale=2.65 if coll.name=='winch' else 2.90
 scene.render.filepath=os.path.join(OUT,coll.name+'.png')
 bpy.ops.render.render(write_still=True)
 coll.hide_render=True
props[0].hide_render=False
cam.rotation_euler=(Vector((0,0,.79))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=2.65
scene.render.filepath=os.path.join(OUT,'winch.png')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'props.blend'),compress=True)
print('PROPS COMPLETE: '+', '.join(sorted(requested)))
