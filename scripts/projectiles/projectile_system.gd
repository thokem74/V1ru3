## Player weapon input and simulation of cannon rounds, hostile fire, missiles, and virus packets.
class_name ProjectileSystem
extends Node3D
var game: Node3D
# Shot record: kind=role ID, node=visual, v=velocity, life=seconds remaining,
# target=optional enemy reference, trail=seconds until the next missile smoke particle.
var shots: Array[Dictionary] = []
var cooldown := 0.0

## Create a bounded-lifetime projectile with world position p and velocity v in m/s.
## Kinds: 0 cannon, 1 hostile round, 2 missile, 3 seeder droplet, 4 bomber packet.
func spawn(kind: int, p: Vector3, v: Vector3, target: EnemyCraft = null) -> void:
	if shots.size() >= 220:
		return
	var color: Color = [Color("fff5c0"), Color("ff7364"), Color("b2ffec"), Color("e73158"), Color("ff5271")][kind]
	var mesh := SphereMesh.new()
	mesh.radius = 0.22 if kind < 2 else 0.5
	mesh.height = mesh.radius * 2
	mesh.radial_segments = 6
	mesh.rings = 3
	var node := Models.part(self, mesh, color, p)
	node.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shots.append({"kind": kind, "node": node, "v": v, "life": 3.0 if kind < 2 else 8.0, "target": target, "trail": 0.0})

## Poll live-player weapon actions and enforce the cannon cooldown in simulation seconds.
## Cannon repeats while held; missiles and bombs trigger on a fresh key press.
func weapons(dt: float) -> void:
	cooldown = maxf(0, cooldown - dt)
	var player: LanderController = game.player
	if not player.alive:
		return
	if Input.is_action_pressed("fire") and cooldown <= 0:
		fire_cannon()
		cooldown = 0.1
	if Input.is_action_just_pressed("missile"):
		fire_missile()
	if Input.is_action_just_pressed("bomb"):
		smart_bomb()

## Charge one score point and fire from the nose along local -Z, adding craft velocity.
## Spawn the muzzle flash and queue its sound even when the round later misses.
func fire_cannon() -> void:
	var player: LanderController = game.player
	game.score.cannon()
	spawn(0, player.position - player.basis.z * 2, -player.basis.z * 230 + player.velocity)
	game.effects.burst(player.position - player.basis.z * 2, Color("fff2af"), 3, 1, 0.08)
	game.effects.sound("cannon")

## Find the closest living enemy within 340 m and the forward lock cone.
## Consume a missile only after acquiring a target; otherwise display the failure reason.
func fire_missile() -> void:
	if game.score.missiles <= 0:
		game.message("NO MISSILES")
		return
	var nearest_enemy: EnemyCraft = null
	var nearest_distance := 340.0
	for enemy in game.enemies:
		var target_offset := WrapMath.delta(game.player.position, enemy.position)
		if (
			enemy.alive
			and target_offset.length() < nearest_distance
			and target_offset.normalized().dot(-game.player.basis.z) > 0.55
		):
			nearest_enemy = enemy
			nearest_distance = target_offset.length()
	if nearest_enemy == null:
		game.message("NO LOCK • FACE A TARGET")
		return
	game.score.missiles -= 1
	spawn(2, game.player.position - game.player.basis.z * 3, -game.player.basis.z * 85, nearest_enemy)
	game.effects.sound("missile")
	game.message("MISSILE AWAY")

## Consume one bomb and damage enemies within 145 m using wrapped distance.
## Iterate a copy because enemy destruction removes entries from the active list.
func smart_bomb() -> void:
	if game.score.bombs <= 0:
		game.message("NO SMART BOMBS")
		return
	game.score.bombs -= 1
	for enemy in game.enemies.duplicate():
		if WrapMath.delta(game.player.position, enemy.position).length() < 145:
			enemy.damage(10)
	game.effects.shockwave(game.player.position)
	game.effects.sound("bomb")
	game.message("SMART BOMB • 145m")

## Move, steer, and collide every active projectile for dt seconds.
## Walk backward so deleting expired or impacted shots never skips the next array entry.
func step(dt: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var shot := shots[i]
		shot.life -= dt
		var segment_start: Vector3 = WrapMath.near(shot.node.position, game.player.position)
		# Missiles turn at a finite acceleration; a destroyed target leaves them flying straight.
		if shot.kind == 2:
			if is_instance_valid(shot.target) and shot.target.alive:
				var desired := WrapMath.delta(segment_start, shot.target.position).normalized() * 100
				shot.v = shot.v.move_toward(desired, 90 * dt).normalized() * 100
			shot.trail -= dt
			if shot.trail <= 0:
				game.effects.burst(segment_start, Color("b9ccc4"), 1, 1, 0.6)
				shot.trail = 0.045
		if shot.kind >= 3:
			shot.v.y -= 14 * dt
		var segment_end: Vector3 = segment_start + shot.v * dt
		var hit := false
		# Compare against the entire traveled segment, not only its end, to avoid tunneling.
		if shot.kind == 0 or shot.kind == 2:
			for enemy in game.enemies.duplicate():
				var center := WrapMath.near(enemy.position, segment_start)
				if (
					enemy.alive
					and Geometry3D.get_closest_point_to_segment(
						center,
						segment_start,
						segment_end
					).distance_to(center) < (3.7 if enemy.kind != 2 else 2.0)
				):
					enemy.damage(6 if shot.kind == 2 else 1)
					hit = true
					break
			if not hit:
				var prop: Dictionary = game.scenery.hit(segment_start, segment_end)
				if not prop.is_empty():
					game.score.add(-ScoreManager.FRIENDLY_PENALTY)
					game.effects.burst(segment_end, Color("c7ac70"), 12)
					hit = true
		elif shot.kind == 1 and game.player.alive:
			if Geometry3D.get_closest_point_to_segment(
				game.player.position,
				segment_start,
				segment_end
			).distance_to(game.player.position) < 1.5:
				game.player.die()
				hit = true
		# Swept sampling prevents fast rounds passing through a ridge between frames.
		if not hit:
			for step_index in range(1, 5):
				var point := segment_start.lerp(segment_end, step_index / 4.0)
				if point.y <= game.terrain.ground(point):
					hit = true
					if shot.kind >= 3:
						# The controller applies deposits on its slower infection tick.
						game.pending_infection.append({"p": point, "radius": 6 if shot.kind == 4 else 3})
						game.effects.burst(point, Color("ed4162"), 15)
						game.effects.sound("infection")
					else:
						var water: bool = game.terrain.surface(point) < 0
						game.effects.burst(point, Color("8dc9dd") if water else Color("c4aa75"), 10)
					break
		shot.node.position = segment_end
		if hit or shot.life <= 0:
			shot.node.queue_free()
			shots.remove_at(i)

## Remove every projectile without impact effects, for campaign or wave transitions.
func clear() -> void:
	for shot in shots:
		shot.node.queue_free()
	shots.clear()
