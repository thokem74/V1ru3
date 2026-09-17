class_name SceneryManager
extends Node3D
signal radar_tower_destroyed
var data: TerrainData
var props: Array[Dictionary] = []
var towers: Array[Dictionary] = []
var trees: MultiMeshInstance3D
var tree_props: Array[int] = []
var home_node: Node3D
var covered := PackedByteArray()
var buckets: Dictionary = {}
func setup(terrain: TerrainData) -> void:
 data=terrain
 var rng := RandomNumberGenerator.new(); rng.seed=7301
 var cone := CylinderMesh.new()
 cone.bottom_radius=2.0; cone.top_radius=0; cone.height=6; cone.radial_segments=5
 trees=MultiMeshInstance3D.new()
 trees.multimesh=MultiMesh.new()
 trees.multimesh.transform_format=MultiMesh.TRANSFORM_3D
 trees.multimesh.use_colors=true
 trees.multimesh.mesh=cone
 trees.material_override=Models.material(Color.WHITE)
 trees.material_override.vertex_color_use_as_albedo=true
 add_child(trees)
 for i in range(1100):
  var p := Vector3(rng.randf()*1024,0,rng.randf()*1024)
  p.y=data.ground(p)
  if p.y<1 or WrapMath.delta(p,data.home).length()<35: continue
  tree_props.append(props.size())
  props.append({"p":p,"kind":0,"alive":true,"scale":rng.randf_range(0.7,1.5),"tree":tree_props.size()-1})
 trees.multimesh.instance_count=tree_props.size()
 for i in range(42):
  var p := Vector3(rng.randf()*1024,0,rng.randf()*1024)
  p.y=data.ground(p)
  if p.y<1 or WrapMath.delta(p,data.home).length()<40: continue
  var node := Node3D.new(); add_child(node)
  Models.box(node,Vector3(5,4,6),Color("98a39b"),Vector3(0,2,0))
  Models.cone(node,4.1,0,2,Color("536a73"),Vector3(0,5,0),4).rotation.y=PI/4
  Models.box(node,Vector3(1.4,1.5,0.1),Color("e0bd75"),Vector3(0,2,-3.1))
  props.append({"p":p,"kind":1,"alive":true,"node":node})
 for z in range(4):
  for x in range(4):
   var p := Vector3(x*256+128,0,z*256+128); p.y=data.ground(p)
   var node := Node3D.new(); add_child(node)
   Models.cone(node,3,1,10,Color("6d8794"),Vector3(0,5,0),4)
   Models.box(node,Vector3(7,0.7,1.5),Color("8de1d3"),Vector3(0,10.5,0))
   Models.cone(node,0.6,0,3,Color("e2c980"),Vector3(0,12,0))
   var item := {"p":p,"kind":2,"alive":true,"node":node}
   towers.append(item); props.append(item)
 home_node=Node3D.new(); add_child(home_node)
 Models.box(home_node,Vector3((TerrainData.PAD_HALF_SIZE+1)*2,0.35,(TerrainData.PAD_HALF_SIZE+1)*2),Color("3c515c"),Vector3(0,0.15,0))
 for x in [-TerrainData.PAD_HALF_SIZE,TerrainData.PAD_HALF_SIZE]: Models.box(home_node,Vector3(0.6,0.1,30),Color("8fe2cf"),Vector3(x,0.4,0))
 for z in [-TerrainData.PAD_HALF_SIZE,TerrainData.PAD_HALF_SIZE]: Models.box(home_node,Vector3(30,0.1,0.6),Color("8fe2cf"),Vector3(0,0.4,z))
 for x in [-2,2]: Models.box(home_node,Vector3(0.6,0.1,6),Color("f0de9e"),Vector3(x,0.4,0))
 Models.box(home_node,Vector3(4,0.1,0.6),Color("f0de9e"),Vector3(0,0.4,0))
 Models.cone(home_node,0.5,0.3,16,Color("b6c8c4"),Vector3(19,8,0))
 Models.cone(home_node,1.2,0,2,Color("80ffee"),Vector3(19,17,0))
 for item in props:
  var key := bucket(item.p)
  if not buckets.has(key): buckets[key]=[]
  buckets[key].append(item)
 rebuild_coverage()
func bucket(p: Vector3) -> Vector2i:
 return Vector2i(posmod(int(floor(p.x/32)),32),posmod(int(floor(p.z/32)),32))
func rebuild_coverage() -> void:
 covered.resize(16384); covered.fill(0)
 for z in range(128):
  for x in range(128):
   var p := Vector3(x*8,0,z*8)
   for tower in towers:
    var d := WrapMath.delta(p,tower.p); d.y=0
    if tower.alive and d.length()<190:
     covered[z*128+x]=1; break
func update_view(reference: Vector3) -> void:
 home_node.position=WrapMath.near(data.home,reference)
 for item in props:
  if not item.alive: continue
  var p := WrapMath.near(item.p,reference)
  if item.kind==0:
   var infection := data.infection[data.tile(item.p)]
   var shape: Vector3 = Vector3(1.0+infection*0.5,1.0-infection*0.3,1.0+infection*0.5)*item.scale
   trees.multimesh.set_instance_transform(item.tree,Transform3D(Basis.IDENTITY.scaled(shape),p+Vector3(0,3*shape.y,0)))
   trees.multimesh.set_instance_color(item.tree,Color("387150").lerp(Color("bc434b"),infection))
  else: item.node.position=p
func hit(a: Vector3, b: Vector3) -> Dictionary:
 var candidates: Array = []
 var seen: Dictionary = {}
 # Broadphase uses toroidal 32m bins; include neighboring bins for prop radii.
 var steps := maxi(1,int(ceil(a.distance_to(b)/16)))
 for sample in range(steps+1):
  var cell := bucket(a.lerp(b,float(sample)/steps))
  for dz in range(-1,2):
   for dx in range(-1,2):
    var key := Vector2i(posmod(cell.x+dx,32),posmod(cell.y+dz,32))
    if not seen.has(key):
     seen[key]=true
     candidates.append_array(buckets.get(key,[]))
 for item in candidates:
  if not item.alive: continue
  var center: Vector3 = WrapMath.near(item.p,a)+Vector3.UP*(5 if item.kind==2 else 3)
  var closest := Geometry3D.get_closest_point_to_segment(center,a,b)
  if closest.distance_to(center)<(3.5 if item.kind==2 else 2.6):
   item.alive=false
   if item.kind==0: trees.multimesh.set_instance_transform(item.tree,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))
   else: item.node.hide()
   if item.kind==2:
    rebuild_coverage(); radar_tower_destroyed.emit()
   return item
 return {}
