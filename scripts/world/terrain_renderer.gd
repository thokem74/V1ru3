class_name TerrainRenderer
extends Node3D
var data: TerrainData
var chunks: Dictionary = {}
var material: StandardMaterial3D
func setup(terrain: TerrainData) -> void:
 data = terrain
 material = StandardMaterial3D.new()
 material.vertex_color_use_as_albedo = true
 material.roughness = 1
 for z in range(8):
  for x in range(8):
   var key := Vector2i(x,z)
   var instance := MeshInstance3D.new()
   instance.material_override = material
   add_child(instance)
   chunks[key] = instance
   rebuild(key)
func rebuild(key: Vector2i) -> void:
 var vertices := PackedVector3Array()
 var colors := PackedColorArray()
 var normals := PackedVector3Array()
 for z in range(16):
  for x in range(16):
   var gx := key.x*16+x
   var gz := key.y*16+z
   var a := Vector3(x*8,data.heights[WrapMath.index(gx,gz)],z*8)
   var b := Vector3((x+1)*8,data.heights[WrapMath.index(gx+1,gz)],z*8)
   var c := Vector3(x*8,data.heights[WrapMath.index(gx,gz+1)],(z+1)*8)
   var d := Vector3((x+1)*8,data.heights[WrapMath.index(gx+1,gz+1)],(z+1)*8)
   a.y=maxf(a.y,0); b.y=maxf(b.y,0); c.y=maxf(c.y,0); d.y=maxf(d.y,0)
   var col := data.color_at(WrapMath.index(gx,gz))
   for tri in [[a,b,c],[b,d,c]]:
    var normal: Vector3 = (tri[2]-tri[0]).cross(tri[1]-tri[0]).normalized()
    for point in tri:
     vertices.append(point); normals.append(normal); colors.append(col)
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices
 arrays[Mesh.ARRAY_NORMAL]=normals
 arrays[Mesh.ARRAY_COLOR]=colors
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 chunks[key].mesh=mesh
func update_view(reference: Vector3) -> void:
 # One nearest periodic image of each 128m chunk; far plane < half a world.
 for key in chunks:
  var center := Vector3(key.x*128+64,0,key.y*128+64)
  chunks[key].position = WrapMath.near(center,reference)-Vector3(64,0,64)
 var budget := 2
 for key in data.dirty.keys():
  rebuild(key)
  data.dirty.erase(key)
  budget-=1
  if budget==0: break
