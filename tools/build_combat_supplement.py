"""Render three original editable models at combat resolution, not scaled PNGs.
blender -b -t 4 -P tools/build_combat_supplement.py [-- --only jailer]
Source collections: assets/map_icons/map_icons.blend. No original file rewritten.
"""
import bpy, os, sys, argparse
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'assets','combat')
NAMES=['gate_brute','ferryman','jailer']
p=argparse.ArgumentParser();p.add_argument('--only',nargs='+',choices=NAMES)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
requested=set(a.only or NAMES)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
with bpy.data.libraries.load(os.path.join(ROOT,'assets','map_icons','map_icons.blend'),link=False) as (source,target):
 target.collections=NAMES
for c in target.collections:bpy.context.scene.collection.children.link(c)
cast=target.collections
scene=bpy.context.scene;scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.21,.30,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.45
bpy.ops.object.camera_add(location=(3.3,-9,3.6));cam=bpy.context.object;cam.name='Combat three-quarter camera';cam.data.type='ORTHO';scene.camera=cam
for name,loc,color,power,size in [('Cool key',(-3,-4,6),(.76,.88,1),500,4),('Golden rim',(3,3,4),(1,.68,.30),650,3),('Face fill',(1,-5,2),(.5,1,.85),120,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name=name;o.data.energy=power;o.data.color=color;o.data.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=128;scene.cycles.use_denoising=False
scene.render.resolution_x=384;scene.render.resolution_y=384;scene.render.resolution_percentage=100
scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.image_settings.color_depth='8'
scene.view_settings.view_transform='AgX'
for c in cast:c.hide_render=True
for c in cast:
 if c.name not in requested:continue
 c.hide_render=False
 cam.location=(3.3,-9,3.6);cam.rotation_euler=(Vector((0,0,1.05))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=3
 bpy.context.view_layer.update()
 points=[world_to_camera_view(scene,cam,o.matrix_world@Vector(v)) for o in c.objects if o.type in {'MESH','CURVE'} for v in o.bound_box]
 xmin,xmax=min(v.x for v in points),max(v.x for v in points);ymin,ymax=min(v.y for v in points),max(v.y for v in points)
 cam.location+=cam.rotation_euler.to_quaternion()@Vector((((xmin+xmax)/2-.5)*cam.data.ortho_scale,((ymin+ymax)/2-.5)*cam.data.ortho_scale,0))
 cam.data.ortho_scale*=max(xmax-xmin,ymax-ymin)/.88
 bpy.context.view_layer.update();scene.render.filepath=os.path.join(OUT,c.name+'.png');bpy.ops.render.render(write_still=True);c.hide_render=True
cast[0].hide_render=False
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'combat_supplement.blend'),compress=True)
print('COMBAT SUPPLEMENT COMPLETE',sorted(requested))
