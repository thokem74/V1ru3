class_name WrapMath
extends RefCounted
const SIZE := 1024.0
static func delta(a: Vector3, b: Vector3) -> Vector3:
 return Vector3(wrapf(b.x-a.x, -SIZE/2, SIZE/2), b.y-a.y, wrapf(b.z-a.z, -SIZE/2, SIZE/2))
static func canonical(p: Vector3) -> Vector3:
 return Vector3(fposmod(p.x, SIZE), p.y, fposmod(p.z, SIZE))
static func near(p: Vector3, reference: Vector3) -> Vector3:
 return reference + delta(reference, p)
static func index(x: int, z: int) -> int:
 return posmod(z,128)*128 + posmod(x,128)
