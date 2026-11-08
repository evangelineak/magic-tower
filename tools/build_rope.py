"""Original rope anchor intact/spent map markers. No baked route direction or external art."""
import argparse
import math
import os
import sys
import bpy
from mathutils import Vector, Matrix

ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'assets','rope')
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


for state in ['rope_ready','rope_spent']:
 start(state)
 box('Heavy anchor base',(0,0,.15),(1.7,1.15,.25),'dark',.07)
 box('Brass foot',(0,0,.32),(.91,.78,.16),'brass',.04)
 box('Anchor post',(0,.05,.89),(.35,.36,1.14),'steel',.06)
 box('Cross peg',(0,.05,1.36),(1.25,.38,.18),'gold',.04)
 for x in [-.56,.56]:box('Peg cap',(x,.05,1.36),(.17,.49,.29),'brass',.03)
 # Frontal loop reads as a rope fixture, not an east/west travel arrow.
 if state=='rope_ready':
  cable('Continuous hanging rope',[(-.37,-.24,1.38),(-.55,-.28,1.06),(-.54,-.28,.61),(-.30,-.28,.42),(.23,-.28,.42),(.51,-.28,.67),(.51,-.28,1.13),(.32,-.24,1.38)],.085,'gold')
  box('Ready teal wrap',(0,-.22,1.02),(.47,.10,.38),'teal',.03)
 else:
  cable('Broken left strand',[(-.37,-.24,1.38),(-.55,-.28,1.06),(-.49,-.28,.85)],.075,'leather')
  cable('Broken right strand',[(.32,-.24,1.38),(.51,-.28,1.13),(.45,-.28,.78)],.075,'leather')
  for x in [-.49,.45]:
   for dx in [-.06,0,.06]:cable('Frayed end',[(x,-.28,.85),(x+dx,-.29,.67)],.018,'gold')
  cable('Fallen severed rope',[(-.51,-.30,.30),(-.25,-.44,.32),(.15,-.42,.30),(.39,-.25,.31)],.065,'leather')
  box('Spent dark wrap',(0,-.22,1.02),(.47,.10,.38),'dark',.03)
props=[bpy.data.collections[n] for n in ['rope_ready','rope_spent']]
start('Rope rig');scene=bpy.context.scene;scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
bpy.ops.object.camera_add(location=(2.1,-8,3.4));cam=finish(bpy.context.object,'Rope marker camera');cam.data.type='ORTHO';cam.data.ortho_scale=2.15;scene.camera=cam
cam.rotation_euler=(Vector((0,0,.8))-cam.location).to_track_quat('-Z','Y').to_euler()
for name,loc,power,size in [('Key',(-3,-4,6),550,4),('Rim',(3,2,5),650,3),('Fill',(1,-5,2),160,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=finish(bpy.context.object,name);o.data.energy=power;o.data.size=size;o.rotation_euler=(Vector((0,0,.8))-o.location).to_track_quat('-Z','Y').to_euler()
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=64;scene.cycles.use_denoising=False
scene.render.resolution_x=128;scene.render.resolution_y=128;scene.render.resolution_percentage=100
scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.view_settings.view_transform='AgX'
p=argparse.ArgumentParser();p.add_argument('--only',nargs='+',choices=['rope_ready','rope_spent']);args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []);requested=set(args.only or ['rope_ready','rope_spent'])
for c in props:c.hide_render=True
for c in props:
 if c.name not in requested:continue
 c.hide_render=False;scene.render.filepath=os.path.join(OUT,c.name+'.png');bpy.ops.render.render(write_still=True);c.hide_render=True
props[0].hide_render=False
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'rope.blend'),compress=True)
print('ROPE COMPLETE',sorted(requested))
