class_name Models
extends RefCounted
static func material(color: Color, glow: bool = false) -> StandardMaterial3D:
 var m := StandardMaterial3D.new()
 m.albedo_color=color
 m.roughness=1
 if glow: m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 return m
static func part(parent: Node3D, mesh: Mesh, color: Color, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
 var n := MeshInstance3D.new()
 n.mesh=mesh
 n.material_override=material(color)
 n.position=at
 parent.add_child(n)
 return n
static func box(parent: Node3D, size: Vector3, color: Color, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
 var m := BoxMesh.new(); m.size=size
 return part(parent,m,color,at)
static func cone(parent: Node3D, bottom: float, top: float, height: float, color: Color, at: Vector3 = Vector3.ZERO, sides: int = 5) -> MeshInstance3D:
 var m := CylinderMesh.new()
 m.bottom_radius=bottom; m.top_radius=top; m.height=height; m.radial_segments=sides
 return part(parent,m,color,at)
static func craft(kind: int) -> Node3D:
 var n := Node3D.new()
 if kind == -1:
  cone(n,1.3,0.5,1.0,Color("e4d9ad"))
  cone(n,0.6,0.35,0.7,Color("3c8390"),Vector3(0,0.7,0))
  box(n,Vector3(0.3,0.28,1.7),Color("e8a85d"),Vector3(0,0.15,-1.2))
  cone(n,0.45,0.7,0.55,Color("303d4a"),Vector3(0,-0.65,0))
  for x in [-1,1]:
   box(n,Vector3(0.2,0.8,1.1),Color("56616b"),Vector3(x*1.1,-0.5,0.2))
 elif kind == 0:
  cone(n,2.8,1.3,1.4,Color("c85767"),Vector3.ZERO,6)
  cone(n,1.4,0.3,1.8,Color("773c64"),Vector3(0,1.2,0),6)
  cone(n,0.6,0.9,1.3,Color("ee8770"),Vector3(0,-1,0))
 elif kind == 1:
  box(n,Vector3(5.4,0.35,1.5),Color("e4a94f"))
  var nose := cone(n,1,0,3.8,Color("c9653f")); nose.rotation.x=PI/2
  box(n,Vector3(0.35,1.5,1.2),Color("fde2a0"),Vector3(0,0.6,0.6))
 elif kind == 2:
  var spike := cone(n,1.25,0,3,Color("9e70d1"),Vector3.ZERO,4); spike.rotation.x=-PI/2
  box(n,Vector3(2.4,0.3,0.4),Color("eb93d5"))
 else:
  box(n,Vector3(8,0.6,2.7),Color("557e99"))
  box(n,Vector3(2.1,1.3,6),Color("adbed0"))
  for x in [-3,3]: cone(n,0.8,0.4,2,Color("e07167"),Vector3(x,-0.9,0))
 return n
static func shadow(parent: Node3D) -> MeshInstance3D:
 var mesh := CylinderMesh.new()
 mesh.top_radius=1; mesh.bottom_radius=1; mesh.height=0.025; mesh.radial_segments=12
 var n := part(parent,mesh,Color(0.02,0.05,0.08,0.3))
 n.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 n.material_override.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 return n
