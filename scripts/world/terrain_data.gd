## Logical landscape state and exact triangle-height queries, independent of rendering nodes.
class_name TerrainData
extends RefCounted
signal tile_infected(index: int)
const GRID := 128
const CELL := 8.0
const PAD_HALF_SIZE := 15.0
# Arrays share a row-major tile/corner index: z * GRID + x.
# heights stores corner elevation in meters; land stores 0/1; infection stores 0..1.
var heights := PackedFloat32Array()
var infection := PackedFloat32Array()
var land := PackedByteArray()
# Set of Vector2i chunk coordinates needing color rebuilds; values are unused flags.
var dirty: Dictionary = {}
# Each Vector4 contains integer X/Z frequencies, phase in radians, and amplitude in meters.
var waves: Array[Vector4] = []
var bias := 9.0
var land_count := 0
# Running sum lets healthy() avoid scanning all 16,384 cells every tick.
var infection_sum := 0.0
var home := Vector3(512, 14, 512)

## Reset the landscape from a deterministic seed and landscape number (starting at 1).
## Build corner heights first, then classify tile centers so water is excluded from infection.
func generate(seed_value: int, landscape: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	waves.clear()
	for i in range(9):
		waves.append(Vector4(
			rng.randi_range(1, 4),
			rng.randi_range(-4, 4),
			rng.randf_range(0, TAU),
			18.0 / (1.0 + i * 0.65)
		))
	bias = 10.0 - (landscape - 1) * 5.5
	heights.resize(GRID * GRID)
	infection.resize(GRID * GRID)
	infection.fill(0)
	land.resize(GRID * GRID)
	land_count = 0
	infection_sum = 0
	dirty.clear()
	for z in range(GRID):
		for x in range(GRID):
			heights[WrapMath.index(x, z)] = generated_height(x * CELL, z * CELL)
	for z in range(GRID):
		for x in range(GRID):
			var i := WrapMath.index(x, z)
			land[i] = int(surface(Vector3(x * CELL + 4, 0, z * CELL + 4)) > 0.2)
			land_count += land[i]

## Evaluate the periodic sine-wave landscape at world X/Z coordinates, in meters.
## Integer frequencies ensure seamless edges; a smooth blend flattens the home approach.
func generated_height(x: float, z: float) -> float:
	var height := bias
	for wave in waves:
		height += sin(TAU * (wave.x * x + wave.y * z) / WrapMath.SIZE + wave.z) * wave.w
	var home_distance := Vector2(wrapf(x - 512, -512, 512), wrapf(z - 512, -512, 512)).length()
	return lerpf(14.0, height, smoothstep(25.0, 65.0, home_distance))

# Same two triangles as the renderer: analytical collision is exact, including seams.

## Interpolate the height of the same two triangles used by the terrain mesh.
## With clamp_water, clamp each corner before interpolation to match the visible shoreline.
func surface(p: Vector3, clamp_water: bool = false) -> float:
	var x := int(floor(p.x / CELL))
	var z := int(floor(p.z / CELL))
	# Fractional coordinates within the cell select/interpolate one of its two triangles.
	var u := fposmod(p.x, CELL) / CELL
	var v := fposmod(p.z, CELL) / CELL
	# Corners: a=(0,0), b=(1,0), c=(0,1), d=(1,1), with the b-c diagonal.
	var a := heights[WrapMath.index(x, z)]
	var b := heights[WrapMath.index(x + 1, z)]
	var c := heights[WrapMath.index(x, z + 1)]
	var d := heights[WrapMath.index(x + 1, z + 1)]
	if clamp_water:
		a = maxf(0, a)
		b = maxf(0, b)
		c = maxf(0, c)
		d = maxf(0, d)
	if u + v <= 1:
		return a + (b - a) * u + (c - a) * v
	return d + (c - d) * (1 - u) + (b - d) * (1 - v)

## Return the rendered collision surface height, including water at sea level.
func ground(p: Vector3) -> float:
	return surface(p, true)

## Convert a world position to its wrapped logical tile index; altitude is ignored.
func tile(p: Vector3) -> int:
	return WrapMath.index(int(floor(p.x / CELL)), int(floor(p.z / CELL)))

## Add infection to a land tile, clamp it to [0, 1], and maintain the running total.
## Mark only its mesh chunk dirty and emit tile_infected; water is unchanged.
func infect(i: int, amount: float) -> void:
	if land[i] == 0:
		return
	var before := infection[i]
	infection[i] = clampf(before + amount, 0, 1)
	infection_sum += infection[i] - before
	dirty[Vector2i((i % 128) / 16, (i / 128) / 16)] = true
	tile_infected.emit(i)

## Infect a circular neighborhood around a world-space impact, wrapping at map edges.
## Radius is in tiles; strength falls off with distance from the central tile.
func deposit(p: Vector3, radius: int = 3, strength: float = 0.5) -> void:
	var x := int(floor(p.x / CELL))
	var z := int(floor(p.z / CELL))
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var distance := Vector2(dx, dz).length()
			if distance <= radius:
				infect(WrapMath.index(x + dx, z + dz), strength * (1.0 - distance / (radius + 1)))

## Return the uninfected fraction of land, from 0 to 1; water never enters the denominator.
func healthy() -> float:
	return 1.0 - infection_sum / maxi(1, land_count)

## Return a tile color based on water depth, terrain height, and infection amount.
## Land transitions from varied greens through rust to red without any texture assets.
func color_at(i: int) -> Color:
	if land[i] == 0:
		return Color("24495f") if heights[i] < -3 else Color("36748a")
	var green := Color("447b44").lerp(Color("84a65a"), clampf(heights[i] / 45, 0, 1))
	green = green.lightened(float((i * 17) % 7) * 0.016)
	if infection[i] < 0.5:
		return green.lerp(Color("98583c"), infection[i] * 2)
	return Color("98583c").lerp(Color("b12538"), (infection[i] - 0.5) * 2)
