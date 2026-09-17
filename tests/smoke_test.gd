extends SceneTree
var failures := 0
var checks := 0
var game: Node3D
func check(condition: bool, message: String) -> void:
 checks+=1
 if not condition:
  failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 game.persist_record=false
 await process_frame
 game.set_physics_process(false)
 check(game.mode=="title" and game.renderer.chunks.size()==64,"Title and 64 terrain chunks initialize")
 check(game.scenery.towers.size()==16 and game.scenery.tree_props.size()>300,"Scenery and radar towers initialize")
 check(game.hud.radar!=null,"Radar generated")
 game.start()
 check(game.mode=="playing" and game.enemies.size()==3,"Title starts first wave")
 if DisplayServer.get_name()!="headless": check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Starting captures mouse")
 var esc := InputEventAction.new(); esc.action="pause"; esc.pressed=true
 game._unhandled_input(esc)
 check(game.mode=="pause" and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Pause releases mouse")
 game._unhandled_input(esc)
 check(game.mode=="playing","Resume restores gameplay")
 if DisplayServer.get_name()!="headless": check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Resume captures mouse")
 var p: LanderController=game.player
 p.fuel=50
 for i in range(60): p.step(1.0/60)
 check(p.fuel>69 and p.landed,"Safe pad refuels at 20 per second")
 Input.action_press("thrust")
 for i in range(120): p.step(1.0/60)
 Input.action_release("thrust")
 check(p.position.y>30 and not p.landed and p.fuel<70,"Thrust lifts and consumes fuel")
 p.virtual_mouse_offset=Vector2(30,-50)
 Input.action_press("thrust")
 for i in range(90): p.step(1.0/60)
 Input.action_release("thrust")
 check(Vector2(p.velocity.x,p.velocity.z).length()>5,"Tilted thrust accelerates horizontally")
 var velocity_before := p.velocity.length()
 p.virtual_mouse_offset=Vector2.ZERO
 p.step(1.0/60)
 check(p.velocity.length()>velocity_before*0.9,"Recentering preserves inertia")
 p.position=Vector3(512,200,512); p.velocity=Vector3.ZERO
 Input.action_press("thrust"); p.step(0.1); Input.action_release("thrust")
 check(p.velocity.y<0,"Ceiling prevents main thrust acceleration")
 p.position=Vector3(512,90,512); p.velocity=Vector3.ZERO
 p.tilt=deg_to_rad(170); p.virtual_mouse_offset=Vector2(0,-240)
 Input.action_press("thrust"); p.step(0.1); Input.action_release("thrust")
 check(p.velocity.y< -2.5,"Inverted thrust accelerates downwards")
 var lives: int=game.score.lives
 p.position=Vector3(560,game.terrain.ground(Vector3(560,0,512))+1,512)
 p.velocity=Vector3(0,-20,0); p.step(0.02)
 check(not p.alive and game.score.lives==lives-1,"Bad terrain contact kills player")
 game.respawn_timer=0.01; game._physics_process(0.02)
 check(p.alive and p.landed and p.fuel==100,"Death respawns on pad")
 p.grace=0; p.landed=false; p.position=game.terrain.home+Vector3.UP*1.2; p.velocity=Vector3(0,-2,0)
 p.step(0.05)
 check(p.alive and p.landed,"Gentle upright landing succeeds")
 p.landed=false; p.position=Vector3(512,70,512); p.fuel=0; p.velocity=Vector3.ZERO
 Input.action_press("thrust"); p.step(0.1); Input.action_release("thrust")
 check(p.velocity.y<0 and not p.thrusting,"Empty fuel disables the engine")
 p.respawn()
 var motion := InputEventMouseMotion.new(); motion.relative=Vector2(1000,-1000)
 game._unhandled_input(motion)
 check(is_equal_approx(p.virtual_mouse_offset.length(),p.virtual_mouse_radius),"Mouse motion accumulates and clamps its virtual radius")
 p.respawn()
 Input.action_press("dip")
 for i in range(20): p.step(1.0/60)
 Input.action_release("dip")
 check(p.virtual_mouse_offset.y<0,"Keyboard pitch changes attitude input")
 Input.action_press("right")
 for i in range(20): p.step(1.0/60)
 Input.action_release("right")
 check(p.virtual_mouse_offset.x>0,"Keyboard right turns heading to the right")
 p.respawn()
 var seed_enemy: EnemyCraft=game.enemies[0]
 seed_enemy.target=seed_enemy.position; seed_enemy.timer=5; seed_enemy.fire_timer=0
 seed_enemy.step(0.1)
 check(game.projectiles.shots.any(func(s): return s.kind==3),"Seeder emits visible falling droplets")
 game.projectiles.clear()
 var shot_score: int=game.score.score
 game.projectiles.fire_cannon()
 check(game.score.score==shot_score-1 and game.projectiles.shots.size()>0,"Real cannon creates round and charges score")
 game.projectiles.clear()
 # Real swept enemy collision, across the toroidal seam.
 var enemy: EnemyCraft=game.enemies[0]
 enemy.position=Vector3(1022,50,400); enemy.hp=1
 game.projectiles.spawn(0,Vector3(5,50,400),Vector3(-230,0,0))
 game.projectiles.step(0.05)
 check(game.enemies.size()==2,"Cannon collision uses wrapped enemy positions")
 await process_frame
 p.position=Vector3(512,70,512); p.basis=Basis.IDENTITY
 enemy=game.enemies[0]; enemy.position=Vector3(512,70,450)
 var missiles: int=game.score.missiles
 game.projectiles.fire_missile()
 check(game.score.missiles==missiles-1,"Forward cone acquires missile target")
 for i in range(60): game.projectiles.step(1.0/60)
 check(game.enemies.size()==1,"Homing missile reaches and destroys target")
 game.projectiles.clear()
 var healthy: float=game.terrain.healthy()
 game.projectiles.spawn(3,game.terrain.home+Vector3(40,2,0),Vector3.DOWN*30)
 for i in range(60): game.projectiles.step(1.0/60)
 game.infection_tick=0; game._physics_process(0.01)
 check(game.terrain.healthy()<healthy,"Falling virus infects land on impact")
 var coverage_before: int= game.scenery.covered.count(1)
 var tower: Dictionary=game.scenery.towers[0]
 var tower_pos: Vector3=tower.p+Vector3.UP*5
 game.scenery.hit(tower_pos-Vector3(0,0,10),tower_pos+Vector3(0,0,10))
 check(game.scenery.covered.count(1)<coverage_before,"Destroying radar tower removes coverage")
 enemy=game.enemies[0]; enemy.position=p.position+Vector3(0,0,-200)
 game.projectiles.smart_bomb()
 check(game.enemies.size()==1,"Smart bomb has limited radius")
 enemy.position=p.position+Vector3(0,0,-50)
 game.projectiles.smart_bomb()
 game._physics_process(0.01)
 check(game.mode=="results" and game.enemies.is_empty(),"All enemies destroyed yields wave results")
 game.start()
 check(game.waves.wave==2 and game.enemies.size()==6,"Results continue into wave two")
 # Exercise all enemy roles, including projectile telegraph cadence.
 for e in game.enemies.duplicate(): e.damage(100)
 game.waves.wave=4; game.clear_wave(); game.start()
 check(game.waves.landscape==2 and game.waves.wave==1,"Fourth wave advances landscape")
 check(game.enemies.any(func(e): return e.kind==3),"Later landscape spawns bombers")
 game.set_physics_process(false)
 for e in game.enemies:
  if e.kind==3: e.fire_timer=0; e.step(0.05)
 check(game.projectiles.shots.any(func(s): return s.kind==4),"Bomber deposits visible virus packets")
 var fighter := EnemyCraft.new(); game.add_child(fighter)
 fighter.setup(game,1,game.player.position+Vector3(0,30,-80),71)
 fighter.fire_timer=0; fighter.step(0.05)
 check(game.projectiles.shots.any(func(s): return s.kind==1),"Fighter fires lethal projectile")
 fighter.dispose()
 var pest := EnemyCraft.new(); game.add_child(pest)
 pest.setup(game,2,game.player.position+Vector3(0,20,30),72)
 pest.step(0.1)
 check(pest.velocity.dot(WrapMath.delta(pest.position,game.player.position))>0,"Pest pursues player")
 pest.dispose()
 game.player.grace=0
 var lives_before: int=game.score.lives
 game.projectiles.spawn(1,game.player.position+Vector3(0,0,-3),Vector3(0,0,80))
 game.projectiles.step(0.05)
 check(not game.player.alive and game.score.lives==lives_before-1,"One hostile projectile is lethal")
 game.player.respawn()
 var tree_index: int=game.scenery.tree_props[0]
 var tree: Dictionary=game.scenery.props[tree_index]
 var tree_id: int=game.terrain.tile(tree.p)
 game.terrain.infect(tree_id,1)
 game.scenery.update_view(game.player.position)
 var color: Color=game.scenery.trees.multimesh.get_instance_color(tree.tree)
 if DisplayServer.get_name()!="headless": check(color.r>color.g,"Infection visibly recolors tree instances")
 var water_pos := Vector3.ZERO
 for i in range(16384):
  if game.terrain.land[i]==0 and game.terrain.heights[i]< -3:
   water_pos=Vector3((i%128)*8+4,0,(i/128)*8+4); break
 game.player.position=water_pos; game.player.landed=false; game.player.velocity=Vector3.DOWN*10
 game.player.step(0.02)
 check(not game.player.alive,"Water contact destroys craft")
 game.player.respawn()
 game.player.grace=0
 game.score.lives=1; game.player.die()
 check(game.mode=="gameover","Last life triggers game over")
 game.start()
 check(game.mode=="playing" and game.score.lives==3 and game.waves.landscape==1,"Game over restarts without reopening")
 game.waves.landscape=3; game.waves.wave=4; game.mode="results"; game.start()
 check(game.mode=="victory","Final results reach victory")
 game.start()
 check(game.mode=="playing" and game.enemies.size()==3,"Victory can restart")
 game.terrain.infection_sum=game.terrain.land_count
 game.infection_tick=0; game._physics_process(0.02)
 check(game.mode=="gameover" and game.loss_reason=="LANDSCAPE LOST","Nearly complete infection ends the campaign")
 print("INTEGRATION: %d checks, %d failures"%[checks,failures])
 # Accelerated simulation queues real-time audio; let its longest one-shot finish.
 game.effects.thrust(false)
 await create_timer(1.4).timeout
 game.queue_free()
 await create_timer(0.15).timeout
 quit(1 if failures else 0)
