class_name LanderController
extends Node3D
signal player_died
@export_group("Classic flight")
@export var mouse_sensitivity := 0.28
@export var mouse_heading_sensitivity := 0.10
@export var heading_response := 24.0
@export var heading_damping := 12.0
@export var virtual_mouse_radius := 240.0
@export var max_declination := 172.0
@export_range(0.0, 0.2) var mouse_deadzone := 0.04
@export_range(1.0, 3.0) var tilt_curve := 1.5
@export var orientation_response := 22.0
@export var orientation_damping := 10.0
@export var max_heading_rate := 45.0
@export var max_tilt_rate := 100.0
@export var gravity := 10.0
@export var thrust_acceleration := 24.0
@export var linear_drag := 0.12
@export var max_practical_speed := 95.0
@export var flight_ceiling := 180.0
var virtual_mouse_offset := Vector2.ZERO
var velocity := Vector3.ZERO
var yaw := 0.0
var requested_heading := 0.0
var tilt := 0.0
var yaw_velocity := 0.0
var tilt_velocity := 0.0
var fuel := 100.0
var alive := true
var landed := true
var grace := 1.5
var thrusting := false
var model: Node3D
var shadow: MeshInstance3D
var game: Node3D
var exhaust_timer := 0.0
func setup(controller: Node3D) -> void:
 game=controller
 model=Models.craft(-1); add_child(model)
 shadow=Models.shadow(game)
 respawn()
func respawn() -> void:
 position=game.terrain.home+Vector3.UP*1.35
 velocity=Vector3.ZERO; virtual_mouse_offset=Vector2.ZERO
 yaw=0; requested_heading=0; tilt=0; yaw_velocity=0; tilt_velocity=0
 basis=Basis.IDENTITY
 fuel=100; alive=true; landed=true; grace=1.5
 show(); shadow.show()
func mouse_motion(relative: Vector2) -> void:
 # Relative steering avoids the polar singularity: a tiny sideways movement
 # near upright must not ask for a 90-degree compass turn.
 requested_heading=wrapf(requested_heading-deg_to_rad(relative.x*mouse_heading_sensitivity),-PI,PI)
 var radius := clampf(virtual_mouse_offset.length()-relative.y*mouse_sensitivity,0,virtual_mouse_radius)
 set_attitude_input(radius)
func set_attitude_input(radius: float) -> void:
 virtual_mouse_offset=Vector2(-sin(requested_heading),-cos(requested_heading))*radius
func requested_tilt() -> float:
 # A soft center gives precision for hovering/landing without losing full inversion.
 var radius := virtual_mouse_offset.length()/virtual_mouse_radius
 var travel := clampf((radius-mouse_deadzone)/(1.0-mouse_deadzone),0,1)
 return deg_to_rad(max_declination)*pow(travel,tilt_curve)
func step(dt: float) -> void:
 if not alive: return
 grace=maxf(0,grace-dt)
 if Input.is_action_just_pressed("center"):
  virtual_mouse_offset=Vector2.ZERO
  requested_heading=yaw
 var turn := Input.get_axis("left","right")
 var pitch := Input.get_axis("raise","dip")
 if turn!=0 or pitch!=0:
  requested_heading=wrapf(requested_heading-turn*dt*1.6,-PI,PI)
  var radius := clampf(virtual_mouse_offset.length()+pitch*dt*65,0,virtual_mouse_radius)
  set_attitude_input(radius)
 var target_tilt := requested_tilt()
 yaw_velocity+=(angle_difference(yaw,requested_heading)*heading_response-yaw_velocity*heading_damping)*dt
 tilt_velocity+=((target_tilt-tilt)*orientation_response-tilt_velocity*orientation_damping)*dt
 yaw_velocity=clampf(yaw_velocity,-deg_to_rad(max_heading_rate),deg_to_rad(max_heading_rate))
 tilt_velocity=clampf(tilt_velocity,-deg_to_rad(max_tilt_rate),deg_to_rad(max_tilt_rate))
 yaw+=yaw_velocity*dt; tilt+=tilt_velocity*dt
 basis=Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,-tilt)
 thrusting=Input.is_action_pressed("thrust") and fuel>0
 var powered := thrusting and position.y<flight_ceiling
 if thrusting: fuel=maxf(0,fuel-4*dt)
 if landed and powered and basis.y.y>0.4: landed=false
 if landed:
  fuel=minf(100,fuel+20*dt)
  velocity=Vector3.ZERO
 else:
  velocity.y-=gravity*dt
  if powered: velocity+=basis.y*thrust_acceleration*dt
  velocity*=exp(-linear_drag*dt)
  velocity=velocity.limit_length(max_practical_speed)
  position+=velocity*dt
  var ground: float=game.terrain.ground(position)
  if position.y<=ground+1.15:
   var home_delta := WrapMath.delta(game.terrain.home,position)
   var safe := absf(home_delta.x)<9 and absf(home_delta.z)<9 and absf(velocity.y)<4 and Vector2(velocity.x,velocity.z).length()<3.5 and absf(tilt)<deg_to_rad(8) and basis.y.y>0
   if safe:
    landed=true; position.y=game.terrain.home.y+1.35; velocity=Vector3.ZERO
    virtual_mouse_offset=Vector2.ZERO
   else: die(true)
 exhaust_timer-=dt
 if powered and exhaust_timer<=0:
  exhaust_timer=0.035
  game.effects.burst(position-basis.y,Color("ffd98d"),2,2,0.35,-basis.y*13+velocity*0.3)
 if position.y>90 and exhaust_timer<=0:
  exhaust_timer=0.08
  game.effects.burst(position+Vector3(randf_range(-12,12),randf_range(-5,5),-15),Color("d3e4df"),1,0,0.8,-velocity*0.6)
 shadow.position=Vector3(position.x,game.terrain.ground(position)+0.14,position.z)
 shadow.scale=Vector3.ONE*(1.5+minf(altitude(),100)*0.018)
 model.visible=grace<=0 or fmod(grace,0.2)<0.13
func altitude() -> float: return maxf(0,position.y-game.terrain.ground(position)-1.15)
func die(terrain_collision: bool = false) -> void:
 if not alive or (grace>0 and not terrain_collision): return
 alive=false; thrusting=false
 hide(); shadow.hide()
 game.effects.burst(position,Color("ffb16d"),60,18,1.5)
 game.effects.sound("explosion")
 player_died.emit()
func dispose() -> void:
 shadow.queue_free(); queue_free()
