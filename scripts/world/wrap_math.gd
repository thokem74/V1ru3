## Shared toroidal coordinate operations. World positions use meters; map indices use cells.
class_name WrapMath
extends RefCounted
const SIZE := 1024.0

## Return the shortest displacement from a to b on the 1024 m torus.
## Only X/Z wrap; vertical distance stays ordinary world-space distance.
static func delta(a: Vector3, b: Vector3) -> Vector3:
	return Vector3(wrapf(b.x - a.x, -SIZE / 2, SIZE / 2), b.y - a.y, wrapf(b.z - a.z, -SIZE / 2, SIZE / 2))

## Map X/Z into [0, SIZE), preserving altitude. Use for logical map storage.
static func canonical(p: Vector3) -> Vector3:
	return Vector3(fposmod(p.x, SIZE), p.y, fposmod(p.z, SIZE))

## Return the periodic copy of p nearest reference, for seamless rendering and collision.
static func near(p: Vector3, reference: Vector3) -> Vector3:
	return reference + delta(reference, p)

## Wrap integer tile coordinates and return the row-major index z * 128 + x.
static func index(x: int, z: int) -> int:
	return posmod(z, 128) * 128 + posmod(x, 128)
