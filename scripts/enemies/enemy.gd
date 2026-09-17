## Four enemy roles sharing geometry ownership, wrapped movement, damage, and destruction signals.
class_name EnemyCraft
extends Node3D
signal enemy_destroyed(enemy: EnemyCraft)
var game: Node3D
var kind := 0
var hp := 2
var velocity := Vector3.ZERO
var target := Vector3.ZERO
var timer := 0.0
var fire_timer := 3.5
var age := 0.0
var alive := true
var model: Node3D
var shadow: MeshInstance3D
var warning: MeshInstance3D
var rng := RandomNumberGenerator.new()

## Initialize role, health, deterministic timers, geometry, warning light, and shadow.
## Role IDs are 0 seeder, 1 fighter, 2 pest, and 3 bomber.
func setup(controller: Node3D, role: int, start: Vector3, seed_value: int) -> void:
	game = controller
	kind = role
	position = start
	rng.seed = seed_value
	hp = [2, 3, 1, 5][kind]
	model = Models.craft(kind)
	add_child(model)
	shadow = Models.shadow(game)
	warning = Models.cone(self, 0.55, 0, 1, Color("ffeed0"), Vector3(0, 2, 0))
	warning.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	target = position
	timer = rng.randf_range(0.5, 2)
	fire_timer = rng.randf_range(3, 5)

## Try up to 32 nearby wrapped positions for a seeder destination above land.
## Set the target 10 m above the surface; the bounded search cannot stall the simulation.
func choose_land() -> void:
	for attempt in range(32):
		target = WrapMath.canonical(position + Vector3(
			rng.randf_range(-100, 100),
			0,
			rng.randf_range(-100, 100)
		))
		if game.terrain.surface(target) > 1:
			break
	target.y = game.terrain.ground(target) + 10

## Advance role-specific movement and attacks, then update orientation, shadow, and ramming.
## Use wrapped displacements so pursuing or attacking across a map seam works normally.
func step(dt: float) -> void:
	if not alive:
		return
	age += dt
	timer -= dt
	fire_timer -= dt
	position = WrapMath.near(position, game.player.position)
	var to_player := WrapMath.delta(position, game.player.position)
	warning.visible = kind == 1 and fire_timer < 0.65 and to_player.length() < 230
	match kind:
		0:
			# Seeder: slow toward a land target and deposit droplets while lingering nearby.
			if timer <= 0:
				choose_land()
				timer = 9
			var d := WrapMath.delta(position, target)
			velocity = velocity.lerp(d.normalized() * minf(15, d.length()), dt * 1.6)
			if fire_timer <= 0 and d.length() < 22:
				game.projectiles.spawn(3, position - Vector3.UP * 2, Vector3.DOWN * 7)
				fire_timer = 1.25 / maxf(1, game.waves.landscape * 0.8)
		1:
			# Fighter: lead the player and add tangential motion instead of hovering in place.
			var aim: Vector3 = to_player + game.player.velocity * 0.6
			var tangent := Vector3(-to_player.z, 0, to_player.x).normalized()
			var desired: Vector3 = (aim.normalized() * 24 + tangent * 24)
			desired.y = clampf(aim.y, -12, 12)
			velocity = velocity.lerp(desired, dt * 1.2)
			if fire_timer <= 0 and game.player.alive:
				if to_player.length() < 230:
					game.projectiles.spawn(1, position, aim.normalized() * 80)
				fire_timer = 3.8 / maxf(1, game.waves.landscape * 0.7)
		2:
			# Pest: pursue with a fast oscillating component that makes ramming harder to evade.
			var aim: Vector3 = to_player.normalized() * 37 + Vector3(
				sin(age * 4) * 9,
				cos(age * 3) * 5,
				cos(age * 4) * 9
			)
			velocity = velocity.lerp(aim, dt * 2.2)
		3:
			# Bomber: cruise at high altitude along crossing routes and drop broad packets.
			velocity = Vector3(50, 0, 20 * sin(age * 0.15))
			velocity.y = clampf((105 - position.y) * 2, -15, 15)
			if fire_timer <= 0:
				game.projectiles.spawn(4, position, Vector3(velocity.x * 0.4, -8, velocity.z * 0.4))
				fire_timer = 1.0
	position += velocity * dt
	position.y = maxf(position.y, game.terrain.ground(position) + 4)
	if velocity.length() > 0.5:
		look_at(position + velocity, Vector3.UP)
	shadow.position = Vector3(position.x, game.terrain.ground(position) + 0.18, position.z)
	shadow.scale = Vector3.ONE * (2 + maxf(0, position.y - shadow.position.y) * 0.014)
	if game.player.alive and WrapMath.delta(position, game.player.position).length() < 3.2:
		game.player.die()

## Apply damage, emit hit debris, and report destruction exactly once when health is gone.
## The controller awards score and removes this enemy from the active wave.
func damage(amount: int) -> void:
	if not alive:
		return
	hp -= amount
	game.effects.burst(position, Color("fff1b7"), 6, 5, 0.35)
	if hp <= 0:
		alive = false
		game.effects.burst(position, Color("e97b67"), 35, 17, 1.2)
		game.effects.sound("explosion")
		enemy_destroyed.emit(self)
		shadow.queue_free()
		queue_free()

## Remove an enemy and its root-owned shadow without score or destruction signals.
func dispose() -> void:
	shadow.queue_free()
	queue_free()
