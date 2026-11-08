"""Original procedural tower. Run: blender -b -P tools/build_assets.py"""
import bpy, math, os, random
from mathutils import Vector
bpy.context.preferences.filepaths.save_version=0
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'assets'); os.makedirs(OUT,exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def mat(name,color,metal=0,glow=0):
 m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
 b=m.node_tree.nodes.get('Principled BSDF'); b.inputs['Base Color'].default_value=(*color,1); b.inputs['Metallic'].default_value=metal; b.inputs['Roughness'].default_value=.3
 if glow: b.inputs['Emission Color'].default_value=(*color,1); b.inputs['Emission Strength'].default_value=glow
 return m
stone=mat('Midnight obsidian',(.025,.065,.105),.45)
rim=mat('Blue slate',(.07,.15,.22),.5)
gold=mat('Antique gold',(.8,.49,.13),.7)
light=mat('Arcane jade',(.1,.9,.66),.2,4)
def cyl(name,loc,r,depth,material,verts=8,r2=None):
 bpy.ops.mesh.primitive_cone_add(vertices=verts,radius1=r,radius2=r if r2 is None else r2,depth=depth,location=loc)
 o=bpy.context.object;o.name=name;o.data.materials.append(material);return o
def cube(name,loc,scale,material):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(material);return o
cyl('Floating foundation',(0,0,.1),2.1,.5,stone,6,r2=1.8)
cyl('Foundation inlay',(0,0,.38),1.83,.1,gold,6)
for i in range(3):
 z=.65+i*1.35;r=1.25-i*.17
 cyl('Tower chamber %s'%i,(0,0,z+.5),r,1.05,stone)
 cyl('Cornice %s'%i,(0,0,z),r+.13,.16,rim)
 cyl('Golden ledge %s'%i,(0,0,z+1.03),r+.17,.1,gold)
 for a in range(8):
  angle=a*math.tau/8+math.pi/8
  o=cube('Jade slit',((r*.94)*math.cos(angle),(r*.94)*math.sin(angle),z+.55),(.075,.25,.5),light);o.rotation_euler[2]=angle
cyl('Spire',(0,0,4.5),1.05,1.3,rim,8,r2=.06)
cyl('Beacon crystal',(0,0,5.4),.3,.75,light,6,r2=0)
for z,r in [(1.7,1.8),(3.7,1.5),(5.35,.65)]:
 bpy.ops.mesh.primitive_torus_add(major_segments=48,minor_segments=6,location=(0,0,z),major_radius=r,minor_radius=.035)
 o=bpy.context.object;o.name='Celestial orbit';o.rotation_euler=(.12,.2,0);o.data.materials.append(gold)
random.seed(16)
for i in range(20):
 a=random.random()*math.tau;r=random.uniform(1.8,2.5);z=random.uniform(.5,5.8)
 cyl('Floating mote',(math.cos(a)*r,math.sin(a)*r,z),.025,.07,light,4,r2=0)
scene=bpy.context.scene;scene.world.color=(.006,.012,.03)
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.008,.018,.042,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.4
bpy.ops.object.camera_add(location=(8,-12,8));cam=bpy.context.object;cam.name='Presentation camera';cam.rotation_euler=(Vector((0,0,2.65))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=8;scene.camera=cam
for name,loc,color,power,size in [('Cool key',(4,-5,8),(.4,.75,1),1500,6),('Warm rim',(-4,2,6),(1,.6,.2),1900,5),('Front fill',(0,-5,3),(.2,1,.8),700,4)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name=name;o.data.energy=power;o.data.color=color;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,2.5))-o.location).to_track_quat('-Z','Y').to_euler()
scene.render.engine='CYCLES';scene.cycles.samples=256;scene.cycles.use_denoising=False
scene.render.resolution_x=512;scene.render.resolution_y=768;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=os.path.join(OUT,'tower.png')
scene.use_nodes=True;nodes=scene.node_tree.nodes;nodes.clear();rl=nodes.new('CompositorNodeRLayers');gl=nodes.new('CompositorNodeGlare');gl.glare_type='FOG_GLOW';gl.quality='HIGH';gl.threshold=1.2;comp=nodes.new('CompositorNodeComposite');scene.node_tree.links.new(rl.outputs['Image'],gl.inputs['Image']);scene.node_tree.links.new(gl.outputs['Image'],comp.inputs['Image'])
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'tower.blend'))
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'tower.glb'),export_format='GLB',export_cameras=False,export_lights=False)
bpy.ops.render.render(write_still=True)
print('ASSETS COMPLETE')
