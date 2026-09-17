extends SceneTree
var game: Node3D
var sample_usec: Array[int] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 game.persist_record=false
 await process_frame
 game.set_physics_process(false)
 game.start()
 # Last landscape, maximum roster, repeated seam crossings and constant cannon.
 for e in game.enemies: e.dispose()
 game.enemies.clear()
 game.waves.landscape=3; game.waves.wave=4
 game.build_landscape(); game.spawn_wave()
 var initial_health: float=game.terrain.healthy()
 Input.action_press("fire")
 for frame in range(3600):
  game.player.grace=2
  game.player.landed=false
  game.player.position=Vector3(1000+frame*0.2,65,512+sin(frame*0.003)*200)
  game.player.velocity=Vector3.ZERO
  game.player.fuel=100
  var start_time := Time.get_ticks_usec()
  game._physics_process(1.0/60)
  sample_usec.append(Time.get_ticks_usec()-start_time)
  if frame%60==0: await process_frame
 Input.action_release("fire")
 sample_usec.sort()
 print("ENDURANCE: 3600 simulation frames; median %.2fms, p95 %.2fms, worst %.2fms"%[sample_usec[1800]/1000.0,sample_usec[3420]/1000.0,sample_usec[-1]/1000.0])
 print("Enemies: %d; shots: %d; particles: %d; infected: %.2f%%"%[game.enemies.size(),game.projectiles.shots.size(),game.effects.particles.size(),(1-game.terrain.healthy())*100])
 var ok: bool=game.mode=="playing" and game.terrain.healthy()<initial_health and game.enemies.size()<=24 and game.effects.particles.size()<=Effects.LIMIT
 game.queue_free()
 await create_timer(0.15).timeout
 quit(0 if ok else 1)
