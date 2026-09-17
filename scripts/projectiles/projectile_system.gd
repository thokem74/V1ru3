class_name ProjectileSystem
extends Node3D
var game: Node3D
var shots: Array[Dictionary] = []
var cooldown := 0.0
func spawn(kind: int, p: Vector3, v: Vector3, target: EnemyCraft = null) -> void:
 if shots.size()>=220: return
 var color: Color=[Color("fff5c0"),Color("ff7364"),Color("b2ffec"),Color("e73158"),Color("ff5271")][kind]
 var mesh := SphereMesh.new()
 mesh.radius=0.22 if kind<2 else 0.5
 mesh.height=mesh.radius*2; mesh.radial_segments=6; mesh.rings=3
 var node := Models.part(self,mesh,color,p)
 node.material_override.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 shots.append({"kind":kind,"node":node,"v":v,"life":3.0 if kind<2 else 8.0,"target":target,"trail":0.0})
func weapons(dt: float) -> void:
 cooldown=maxf(0,cooldown-dt)
 var player: LanderController=game.player
 if not player.alive: return
 if Input.is_action_pressed("fire") and cooldown<=0:
  fire_cannon(); cooldown=0.1
 if Input.is_action_just_pressed("missile"): fire_missile()
 if Input.is_action_just_pressed("bomb"): smart_bomb()
func fire_cannon() -> void:
 var p: LanderController=game.player
 game.score.cannon()
 spawn(0,p.position-p.basis.z*2,-p.basis.z*230+p.velocity)
 game.effects.burst(p.position-p.basis.z*2,Color("fff2af"),3,1,0.08)
 game.effects.sound("cannon")
func fire_missile() -> void:
 if game.score.missiles<=0: game.message("NO MISSILES"); return
 var best: EnemyCraft=null
 var distance := 340.0
 for enemy in game.enemies:
  var d := WrapMath.delta(game.player.position,enemy.position)
  if enemy.alive and d.length()<distance and d.normalized().dot(-game.player.basis.z)>0.55:
   best=enemy; distance=d.length()
 if best==null: game.message("NO LOCK • FACE A TARGET"); return
 game.score.missiles-=1
 spawn(2,game.player.position-game.player.basis.z*3,-game.player.basis.z*85,best)
 game.effects.sound("missile"); game.message("MISSILE AWAY")
func smart_bomb() -> void:
 if game.score.bombs<=0: game.message("NO SMART BOMBS"); return
 game.score.bombs-=1
 for enemy in game.enemies.duplicate():
  if WrapMath.delta(game.player.position,enemy.position).length()<145: enemy.damage(10)
 game.effects.shockwave(game.player.position)
 game.effects.sound("bomb"); game.message("SMART BOMB • 145m")
func step(dt: float) -> void:
 for i in range(shots.size()-1,-1,-1):
  var s := shots[i]
  s.life-=dt
  var a: Vector3=WrapMath.near(s.node.position,game.player.position)
  if s.kind==2:
   if is_instance_valid(s.target) and s.target.alive:
    var desired := WrapMath.delta(a,s.target.position).normalized()*100
    s.v=s.v.move_toward(desired,90*dt).normalized()*100
   s.trail-=dt
   if s.trail<=0:
    game.effects.burst(a,Color("b9ccc4"),1,1,0.6); s.trail=0.045
  if s.kind>=3: s.v.y-=14*dt
  var b: Vector3=a+s.v*dt
  var hit := false
  if s.kind==0 or s.kind==2:
   for enemy in game.enemies.duplicate():
    var center := WrapMath.near(enemy.position,a)
    if enemy.alive and Geometry3D.get_closest_point_to_segment(center,a,b).distance_to(center)<(3.7 if enemy.kind!=2 else 2.0):
     enemy.damage(6 if s.kind==2 else 1); hit=true; break
   if not hit:
    var prop: Dictionary=game.scenery.hit(a,b)
    if not prop.is_empty():
     game.score.add(-ScoreManager.FRIENDLY_PENALTY)
     game.effects.burst(b,Color("c7ac70"),12); hit=true
  elif s.kind==1 and game.player.alive:
   if Geometry3D.get_closest_point_to_segment(game.player.position,a,b).distance_to(game.player.position)<1.5:
    game.player.die(); hit=true
  # Swept sampling prevents fast rounds passing through a ridge between frames.
  if not hit:
   for step_index in range(1,5):
    var point := a.lerp(b,step_index/4.0)
    if point.y<=game.terrain.ground(point):
     hit=true
     if s.kind>=3:
      game.pending_infection.append({"p":point,"radius":6 if s.kind==4 else 3})
      game.effects.burst(point,Color("ed4162"),15)
      game.effects.sound("infection")
     else:
      var water: bool=game.terrain.surface(point)<0
      game.effects.burst(point,Color("8dc9dd") if water else Color("c4aa75"),10)
     break
  s.node.position=b
  if hit or s.life<=0:
   s.node.queue_free(); shots.remove_at(i)
func clear() -> void:
 for s in shots: s.node.queue_free()
 shots.clear()
