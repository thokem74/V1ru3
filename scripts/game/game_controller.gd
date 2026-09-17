## Scene composition and campaign state machine. Owns the order in which gameplay systems update.
extends Node3D
signal wave_started
signal wave_completed
signal landscape_completed
var terrain: TerrainData
var renderer: TerrainRenderer
var scenery: SceneryManager
var player: LanderController
var projectiles: ProjectileSystem
var effects: Effects
var hud: GameHUD
var camera: Camera3D
var score: ScoreManager
var waves: WaveController
var enemies: Array[EnemyCraft] = []
# Deferred impact records: p=world impact, radius=spread radius in terrain cells.
var pending_infection: Array[Dictionary] = []
# State machine: title -> playing <-> pause; playing -> results/gameover; results -> victory.
var mode := "title"
var notice := ""
var notice_time := 0.0
var respawn_timer := 0.0
var infection_tick := 0.0
var scenery_tick := 0.0
var elapsed := 0.0
var camera_yaw := 0.0
var result_bonus := 0
var loss_reason := ""
var best_score := 0
var persist_record := true

## Construct lighting, camera, effects, projectile system, and HUD, then show the title world.
## Read the optional local high score; all gameplay systems work without that save file.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var world_environment := WorldEnvironment.new()
	world_environment.environment = Environment.new()
	world_environment.environment.background_mode = Environment.BG_COLOR
	world_environment.environment.background_color = Color("bbcfd0")
	world_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.environment.ambient_light_color = Color("bec9c2")
	world_environment.environment.ambient_light_energy = 0.5
	world_environment.environment.fog_enabled = true
	world_environment.environment.fog_light_color = Color("bbcfd0")
	world_environment.environment.fog_density = 0.0018
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -25, 0)
	sun.light_color = Color("fff1ca")
	sun.light_energy = 1.0
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 70
	camera.far = 420
	camera.near = 0.15
	add_child(camera)
	camera.current = true
	effects = Effects.new()
	add_child(effects)
	projectiles = ProjectileSystem.new()
	projectiles.game = self
	add_child(projectiles)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = GameHUD.new()
	hud.game = self
	layer.add_child(hud)
	var save := ConfigFile.new()
	if save.load("user://record.cfg") == OK:
		best_score = int(save.get_value("record", "score", 0))
	reset_campaign()
	mode = "title"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## Create fresh score/progression state and generate landscape one for a new run.
func reset_campaign() -> void:
	score = ScoreManager.new()
	waves = WaveController.new()
	score.extra_life.connect(on_extra_life)
	elapsed = 0
	respawn_timer = 0
	build_landscape()

## Replace world data, geometry, scenery, enemies, projectiles, and the player.
## Keep the campaign score/progression objects so landscape transitions preserve rewards.
func build_landscape() -> void:
	for enemy in enemies:
		enemy.dispose()
	enemies.clear()
	projectiles.clear()
	effects.clear()
	pending_infection.clear()
	if is_instance_valid(player):
		player.dispose()
	if is_instance_valid(renderer):
		renderer.free()
	if is_instance_valid(scenery):
		scenery.free()
	terrain = TerrainData.new()
	terrain.generate(1987, waves.landscape)
	renderer = TerrainRenderer.new()
	add_child(renderer)
	renderer.setup(terrain)
	scenery = SceneryManager.new()
	add_child(scenery)
	scenery.setup(terrain)
	scenery.radar_tower_destroyed.connect(on_radar_tower_destroyed)
	player = LanderController.new()
	player.name = "Lander"
	add_child(player)
	player.setup(self)
	player.player_died.connect(on_player_died)
	camera_yaw = 0
	camera.position = player.position + Vector3(0, 7, 15)
	camera.look_at(player.position + Vector3(0, 2, -8))
	renderer.update_view(player.position)
	scenery.update_view(player.position)
	hud.refresh_radar()

## Handle the start/continue action according to the current menu state.
## Resume, advance results, or restart a finished campaign, then capture the pointer for play.
func start() -> void:
	if mode == "pause":
		mode = "playing"
	elif mode == "results":
		var next := waves.advance()
		if next == "victory":
			finish(true)
			return
		if next == "landscape":
			build_landscape()
		else:
			projectiles.clear()
			player.respawn()
		spawn_wave()
		mode = "playing"
	elif mode in ["title", "gameover", "victory"]:
		if mode != "title":
			reset_campaign()
		spawn_wave()
		mode = "playing"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Create the current wave roster at deterministic positions a safe distance from home.
## Give seeders land destinations and connect destruction signals for score and progression.
func spawn_wave() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1987 + waves.wave * 127 + waves.landscape * 891
	var roster := waves.roster()
	for i in range(roster.size()):
		var angle := -PI / 2 + float(i) * TAU / roster.size() * 0.7
		var distance := rng.randf_range(110, 230)
		var spawn_position := terrain.home + Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		if roster[i] == 0:
			for attempt in range(50):
				if terrain.surface(spawn_position) > 1:
					break
				spawn_position = terrain.home + Vector3(
					rng.randf_range(-220, 220),
					0,
					rng.randf_range(-220, 220)
				)
		spawn_position.y = terrain.ground(spawn_position) + (100 if roster[i] == 3 else 18)
		var enemy := EnemyCraft.new()
		add_child(enemy)
		enemy.setup(self, roster[i], spawn_position, 1987 + i * 97 + waves.wave)
		enemy.enemy_destroyed.connect(on_enemy_destroyed)
		enemies.append(enemy)
	message("LANDSCAPE %d  /  WAVE %d" % [waves.landscape, waves.wave])
	wave_started.emit()

## Route pause, menu confirmation, mouse motion, and map-toggle events.
## Movement and weapon buttons are polled separately during the simulation tick.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if mode == "playing":
			mode = "pause"
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			effects.thrust(false)
		elif mode == "pause":
			start()
		return
	if mode != "playing":
		if (
			event.is_action_pressed("start") or (event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed)
		):
			start()
		return
	if event is InputEventMouseMotion:
		player.mouse_motion(event.relative)
	if event.is_action_pressed("map"):
		hud.large_map = not hud.large_map

## Run the active simulation in dependency order, then refresh camera and HUD.
## Menu modes stop gameplay updates; the title mode alone keeps its orbiting camera moving.
func _physics_process(dt: float) -> void:
	if mode != "playing":
		if mode == "title":
			elapsed += dt
			camera.position = terrain.home + Vector3(sin(elapsed * 0.06) * 75, 48, cos(elapsed * 0.06) * 75)
			camera.look_at(terrain.home)
		hud.queue_redraw()
		return
	elapsed += dt
	notice_time = maxf(0, notice_time - dt)
	# Move craft first so AI, weapons, and effects see this tick's updated player position.
	player.step(dt)
	projectiles.weapons(dt)
	for enemy in enemies.duplicate():
		enemy.step(dt)
	projectiles.step(dt)
	# Infection/radar run about 6.7 Hz; prop mutation/placement runs at 10 Hz below.
	infection_tick -= dt
	if infection_tick <= 0:
		infection_tick = 0.15
		for deposit in pending_infection:
			terrain.deposit(deposit.p, deposit.radius, 0.65)
		pending_infection.clear()
		if terrain.healthy() < 0.025:
			finish(false, "LANDSCAPE LOST")
		hud.refresh_radar()
	effects.tick(dt, player.position)
	effects.thrust(player.alive and player.thrusting and player.position.y < player.flight_ceiling)
	renderer.update_view(player.position)
	scenery_tick -= dt
	if scenery_tick <= 0:
		scenery_tick = 0.1
		scenery.update_view(player.position)
	update_camera(dt)
	if not player.alive and score.lives > 0:
		respawn_timer -= dt
		if respawn_timer <= 0:
			player.respawn()
			message("NEW CRAFT • SYSTEMS READY")
	# Wait for a surviving/respawned player before showing results, even after the last kill.
	if enemies.is_empty() and mode == "playing" and player.alive:
		clear_wave()
	hud.queue_redraw()

## Smoothly chase the craft heading without roll and look ahead of its position.
## Clamp the desired camera height above terrain to reduce ground clipping.
func update_camera(dt: float) -> void:
	camera_yaw = lerp_angle(camera_yaw, player.yaw, 1 - exp(-3 * dt))
	var heading := Basis(Vector3.UP, camera_yaw)
	var desired := player.position + heading * Vector3(0, 6, 14)
	desired.y = maxf(desired.y, terrain.ground(desired) + 3)
	camera.position = camera.position.lerp(desired, 1 - exp(-6 * dt))
	var look := player.position + heading * Vector3(0, 2, -10)
	camera.look_at(look, Vector3.UP)

## Award the destroyed role reward and remove it from the required-enemy list.
func on_enemy_destroyed(enemy: EnemyCraft) -> void:
	score.add(ScoreManager.REWARDS[enemy.kind])
	enemies.erase(enemy)

## Spend a life and schedule a replacement, or end the campaign when no lives remain.
func on_player_died() -> void:
	score.lives -= 1
	respawn_timer = 2.2
	effects.thrust(false)
	if score.lives <= 0:
		finish(false, "ALL CRAFT LOST")
	else:
		message("CRAFT LOST • REPLACEMENT INBOUND")

## Award healthy-land bonuses and enter the results screen without advancing immediately.
## The next confirmation advances progression, allowing the player to read the results.
func clear_wave() -> void:
	result_bonus = int(terrain.healthy() * 2000)
	if waves.wave == 4:
		result_bonus += int(terrain.healthy() * 3000)
		landscape_completed.emit()
	score.add(result_bonus)
	mode = "results"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	effects.thrust(false)
	wave_completed.emit()

## Enter victory/game-over mode, release the mouse, and update the optional local record.
## Tests disable persist_record so validation never changes the player save.
func finish(won: bool, reason: String = "") -> void:
	mode = "victory" if won else "gameover"
	loss_reason = reason
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	effects.thrust(false)
	best_score = maxi(best_score, score.score)
	if persist_record:
		var save := ConfigFile.new()
		save.set_value("record", "score", best_score)
		save.save("user://record.cfg")

## Replace the HUD notice and keep it visible for three simulation seconds.
func message(text: String) -> void:
	notice = text
	notice_time = 3.0

## Announce the score manager life/weapon award and queue its notification sound.
func on_extra_life() -> void:
	message("EXTRA LIFE • WEAPONS REPLENISHED")
	effects.sound("warning")

## Announce a lost scanner; the scenery manager has already rebuilt coverage.
func on_radar_tower_destroyed() -> void:
	message("RADAR TOWER DESTROYED")
