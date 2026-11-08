"""Original sealed medical cargo and empty freight berth. Blender CPU rebuild; no external art."""
import argparse
import math
import os
import sys
import bpy
from mathutils import Vector, Matrix

ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'assets','cargo')
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


start('cargo')
box('Sealed broad crate',(0,0,.78),(1.56,1.08,1.28),'teal',.12)
box('Raised lid',(0,0,1.46),(1.70,1.17,.16),'brass',.05)
for x in [-.58,.58]:
 box('Wide brass strap',(x,-.57,.80),(.18,.09,1.36),'gold',.025)
 box('Lid strap',(x,0,1.56),(.18,1.20,.08),'gold',.015)
box('Dark medicine plaque',(0,-.60,.85),(.69,.09,.70),'dark',.06)
box('Medical mark horizontal',(0,-.67,.85),(.48,.06,.16),'gold',.015)
box('Medical mark vertical',(0,-.67,.85),(.16,.06,.48),'gold',.015)
for x in [-.86,.86]:box('Carrying handle',(x,0,1.14),(.18,.55,.15),'steel',.04)
box('Seal latch',(0,-.64,1.43),(.24,.12,.27),'gold',.03)
start('cargo_empty')
box('Empty loading plate',(0,0,.17),(1.91,1.31,.24),'dark',.06)
for x in [-.84,.84]:
 box('Berth upright',(x,.27,.77),(.15,.18,1.22),'steel',.03)
 box('Floor guide',(x,0,.34),(.15,1.28,.10),'brass',.02)
box('Empty berth crossbar',(0,.27,1.43),(1.83,.18,.16),'steel',.04)
for x in [-.55,0,.55]:box('Empty floor stripe',(x,-.13,.32),(.15,.72,.04),'gold',.008)
props=[bpy.data.collections[n] for n in ['cargo','cargo_empty']]
start('Cargo rig');scene=bpy.context.scene;scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
bpy.ops.object.camera_add(location=(3,-8,4.1));cam=finish(bpy.context.object,'Cargo map camera');cam.data.type='ORTHO';cam.data.ortho_scale=2.30;scene.camera=cam
cam.rotation_euler=(Vector((0,0,.80))-cam.location).to_track_quat('-Z','Y').to_euler()
for name,loc,power,size in [('Key',(-3,-4,6),550,4),('Rim',(3,2,5),650,3),('Fill',(1,-5,2),160,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=finish(bpy.context.object,name);o.data.energy=power;o.data.size=size;o.rotation_euler=(Vector((0,0,.8))-o.location).to_track_quat('-Z','Y').to_euler()
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=64;scene.cycles.use_denoising=False
scene.render.resolution_x=128;scene.render.resolution_y=128;scene.render.resolution_percentage=100
scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='AgX'
parser=argparse.ArgumentParser();parser.add_argument('--only',nargs='+',choices=['cargo','cargo_empty']);args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
requested=set(args.only or ['cargo','cargo_empty'])
for c in props:c.hide_render=True
for c in props:
 if c.name not in requested:continue
 c.hide_render=False;scene.render.filepath=os.path.join(OUT,c.name+'.png');bpy.ops.render.render(write_still=True);c.hide_render=True
props[0].hide_render=False
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'cargo.blend'),compress=True)
print('CARGO COMPLETE',sorted(requested))
