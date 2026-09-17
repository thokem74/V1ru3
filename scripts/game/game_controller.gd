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
var pending_infection: Array[Dictionary] = []
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
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 var env := WorldEnvironment.new()
 env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color("bbcfd0")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color("bec9c2")
 env.environment.ambient_light_energy=0.5
 env.environment.fog_enabled=true
 env.environment.fog_light_color=Color("bbcfd0")
 env.environment.fog_density=0.0018
 add_child(env)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees=Vector3(-45,-25,0)
 sun.light_color=Color("fff1ca"); sun.light_energy=1.0
 add_child(sun)
 camera=Camera3D.new(); camera.fov=70; camera.far=420; camera.near=0.15
 add_child(camera); camera.current=true
 effects=Effects.new(); add_child(effects)
 projectiles=ProjectileSystem.new(); projectiles.game=self; add_child(projectiles)
 var layer := CanvasLayer.new(); add_child(layer)
 hud=GameHUD.new(); hud.game=self; layer.add_child(hud)
 var save := ConfigFile.new()
 if save.load("user://record.cfg")==OK: best_score=int(save.get_value("record","score",0))
 reset_campaign()
 mode="title"
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func reset_campaign() -> void:
 score=ScoreManager.new(); waves=WaveController.new()
 score.extra_life.connect(func(): message("EXTRA LIFE • WEAPONS REPLENISHED"); effects.sound("warning"))
 elapsed=0; respawn_timer=0
 build_landscape()
func build_landscape() -> void:
 for enemy in enemies: enemy.dispose()
 enemies.clear(); projectiles.clear(); effects.clear(); pending_infection.clear()
 if is_instance_valid(player): player.dispose()
 if is_instance_valid(renderer): renderer.free()
 if is_instance_valid(scenery): scenery.free()
 terrain=TerrainData.new(); terrain.generate(1987,waves.landscape)
 renderer=TerrainRenderer.new(); add_child(renderer); renderer.setup(terrain)
 scenery=SceneryManager.new(); add_child(scenery); scenery.setup(terrain)
 scenery.radar_tower_destroyed.connect(func(): message("RADAR TOWER DESTROYED"))
 player=LanderController.new(); player.name="Lander"; add_child(player); player.setup(self)
 player.player_died.connect(on_player_died)
 camera_yaw=0
 camera.position=player.position+Vector3(0,7,15)
 camera.look_at(player.position+Vector3(0,2,-8))
 renderer.update_view(player.position); scenery.update_view(player.position)
 hud.refresh_radar()
func start() -> void:
 if mode=="pause":
  mode="playing"
 elif mode=="results":
  var next := waves.advance()
  if next=="victory": finish(true); return
  if next=="landscape": build_landscape()
  else:
   projectiles.clear(); player.respawn()
  spawn_wave(); mode="playing"
 elif mode in ["title","gameover","victory"]:
  if mode!="title": reset_campaign()
  spawn_wave(); mode="playing"
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func spawn_wave() -> void:
 var rng := RandomNumberGenerator.new(); rng.seed=1987+waves.wave*127+waves.landscape*891
 var roster := waves.roster()
 for i in range(roster.size()):
  var angle := -PI/2+float(i)*TAU/roster.size()*0.7
  var distance := rng.randf_range(110,230)
  var p := terrain.home+Vector3(cos(angle)*distance,0,sin(angle)*distance)
  if roster[i]==0:
   for attempt in range(50):
    if terrain.surface(p)>1: break
    p=terrain.home+Vector3(rng.randf_range(-220,220),0,rng.randf_range(-220,220))
  p.y=terrain.ground(p)+(100 if roster[i]==3 else 18)
  var enemy := EnemyCraft.new(); add_child(enemy)
  enemy.setup(self,roster[i],p,1987+i*97+waves.wave)
  enemy.enemy_destroyed.connect(on_enemy_destroyed)
  enemies.append(enemy)
 message("LANDSCAPE %d  /  WAVE %d"%[waves.landscape,waves.wave])
 wave_started.emit()
func _unhandled_input(event: InputEvent) -> void:
 if event.is_action_pressed("pause"):
  if mode=="playing":
   mode="pause"; Input.mouse_mode=Input.MOUSE_MODE_VISIBLE; effects.thrust(false)
  elif mode=="pause": start()
  return
 if mode!="playing":
  if event.is_action_pressed("start") or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed): start()
  return
 if event is InputEventMouseMotion: player.mouse_motion(event.relative)
 if event.is_action_pressed("map"): hud.large_map=not hud.large_map
func _physics_process(dt: float) -> void:
 if mode!="playing":
  if mode=="title":
   elapsed+=dt
   camera.position=terrain.home+Vector3(sin(elapsed*0.06)*75,48,cos(elapsed*0.06)*75)
   camera.look_at(terrain.home)
  hud.queue_redraw()
  return
 elapsed+=dt; notice_time=maxf(0,notice_time-dt)
 player.step(dt)
 projectiles.weapons(dt)
 for enemy in enemies.duplicate(): enemy.step(dt)
 projectiles.step(dt)
 infection_tick-=dt
 if infection_tick<=0:
  infection_tick=0.15
  for deposit in pending_infection: terrain.deposit(deposit.p,deposit.radius,0.65)
  pending_infection.clear()
  if terrain.healthy()<0.025: finish(false,"LANDSCAPE LOST")
  hud.refresh_radar()
 effects.tick(dt,player.position)
 effects.thrust(player.alive and player.thrusting and player.position.y<player.flight_ceiling)
 renderer.update_view(player.position)
 scenery_tick-=dt
 if scenery_tick<=0:
  scenery_tick=0.1; scenery.update_view(player.position)
 update_camera(dt)
 if not player.alive and score.lives>0:
  respawn_timer-=dt
  if respawn_timer<=0:
   player.respawn(); message("NEW CRAFT • SYSTEMS READY")
 if enemies.is_empty() and mode=="playing" and player.alive:
  clear_wave()
 hud.queue_redraw()
func update_camera(dt: float) -> void:
 camera_yaw=lerp_angle(camera_yaw,player.yaw,1-exp(-3*dt))
 var heading := Basis(Vector3.UP,camera_yaw)
 var desired := player.position+heading*Vector3(0,6,14)
 desired.y=maxf(desired.y,terrain.ground(desired)+3)
 camera.position=camera.position.lerp(desired,1-exp(-6*dt))
 var look := player.position+heading*Vector3(0,2,-10)
 camera.look_at(look,Vector3.UP)
func on_enemy_destroyed(enemy: EnemyCraft) -> void:
 score.add(ScoreManager.REWARDS[enemy.kind]); enemies.erase(enemy)
func on_player_died() -> void:
 score.lives-=1; respawn_timer=2.2
 effects.thrust(false)
 if score.lives<=0: finish(false,"ALL CRAFT LOST")
 else: message("CRAFT LOST • REPLACEMENT INBOUND")
func clear_wave() -> void:
 result_bonus=int(terrain.healthy()*2000)
 if waves.wave==4:
  result_bonus+=int(terrain.healthy()*3000)
  landscape_completed.emit()
 score.add(result_bonus)
 mode="results"; Input.mouse_mode=Input.MOUSE_MODE_VISIBLE; effects.thrust(false)
 wave_completed.emit()
func finish(won: bool, reason: String = "") -> void:
 mode="victory" if won else "gameover"
 loss_reason=reason
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE; effects.thrust(false)
 best_score=maxi(best_score,score.score)
 if persist_record:
  var save := ConfigFile.new(); save.set_value("record","score",best_score)
  save.save("user://record.cfg")
func message(text: String) -> void:
 notice=text; notice_time=3.0
