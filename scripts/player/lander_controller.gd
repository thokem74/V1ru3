## Player flight, fuel, landing assistance, and survival. Campaign bookkeeping lives in the controller.
class_name LanderController
extends Node3D
signal player_died
@export_group("Classic flight")
## Tilt-input units accumulated per vertical mouse pixel.
@export var mouse_sensitivity := 0.28
## Requested heading change in degrees per horizontal mouse pixel.
@export var mouse_heading_sensitivity := 0.10
## Heading spring strength: larger values approach the requested heading faster.
@export var heading_response := 24.0
## Angular-velocity damping for heading; reduces overshoot and oscillation.
@export var heading_damping := 12.0
## Maximum tilt-input radius; not a world-space distance.
@export var virtual_mouse_radius := 240.0
## Maximum tilt away from upright in degrees; values above 90 allow inversion.
@export var max_declination := 172.0
## Fraction of the input radius that requests zero tilt.
@export_range(0.0, 0.2) var mouse_deadzone := 0.04
## Power curve exponent; above 1 makes small tilt inputs less sensitive.
@export_range(1.0, 3.0) var tilt_curve := 1.5
## Tilt spring strength; used separately from heading response.
@export var orientation_response := 22.0
## Tilt angular-velocity damping.
@export var orientation_damping := 10.0
## Maximum heading speed, in degrees per second.
@export var max_heading_rate := 45.0
## Maximum declination speed, in degrees per second.
@export var max_tilt_rate := 100.0
## Downward acceleration, in meters per second squared.
@export var gravity := 10.0
## Acceleration along the craft local up axis, in meters per second squared.
@export var thrust_acceleration := 24.0
## Exponential velocity decay rate per second, independent of frame duration.
@export var linear_drag := 0.12
## Velocity magnitude cap, in meters per second.
@export var max_practical_speed := 95.0
## World-space altitude in meters above which the main engine adds no acceleration.
@export var flight_ceiling := 180.0
@export_group("Landing assistance")
## Maximum horizontal distance from home for assistance, in meters.
@export var landing_assist_radius := 22.0
## Maximum underside clearance above the home pad for assistance, in meters.
@export var landing_assist_height := 18.0
## Maximum absolute vertical touchdown speed, in meters per second.
@export var landing_vertical_limit := 8.0
## Maximum horizontal touchdown speed, in meters per second.
@export var landing_horizontal_limit := 7.0
## Maximum safe touchdown tilt from upright, in degrees.
@export var landing_tilt_limit := 22.0
# Live simulation state. Angles/angular velocities below use radians, not export degrees.
var landing_assist := false
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

## Attach the controller, construct the lander model and world-space shadow, then respawn.
## The shadow belongs to the game root so it never inherits the craft tilt.
func setup(controller: Node3D) -> void:
	game = controller
	model = Models.craft(-1)
	add_child(model)
	shadow = Models.shadow(game)
	respawn()

## Restore a living, upright craft at home with full fuel and brief enemy-hit protection.
## Campaign score, enemies, and terrain infection are owned elsewhere and remain intact.
func respawn() -> void:
	position = game.terrain.home + Vector3.UP * 1.35
	velocity = Vector3.ZERO
	virtual_mouse_offset = Vector2.ZERO
	yaw = 0
	requested_heading = 0
	tilt = 0
	yaw_velocity = 0
	tilt_velocity = 0
	basis = Basis.IDENTITY
	fuel = 100
	alive = true
	landed = true
	grace = 1.5
	landing_assist = false
	show()
	shadow.show()

## Accumulate relative mouse pixels into a heading request and tilt-input radius.
## Horizontal movement changes heading only; upward movement increases declination.
func mouse_motion(relative: Vector2) -> void:
	# Relative steering avoids the polar singularity: a tiny sideways movement
	# near upright must not ask for a 90-degree compass turn.
	requested_heading = wrapf(requested_heading - deg_to_rad(relative.x * mouse_heading_sensitivity), -PI, PI)
	var radius := clampf(
		virtual_mouse_offset.length() - relative.y * mouse_sensitivity,
		0,
		virtual_mouse_radius
	)
	set_attitude_input(radius)

## Store a tilt-input radius along the requested heading for the attitude instrument.
## The vector length controls tilt; its direction visualizes the requested compass heading.
func set_attitude_input(radius: float) -> void:
	virtual_mouse_offset = Vector2(-sin(requested_heading), -cos(requested_heading)) * radius

## Return requested declination in radians after the dead zone and progressive curve.
## Small inputs give precise low-angle control; full radius still reaches max_declination.
func requested_tilt() -> float:
	# A soft center gives precision for hovering/landing without losing full inversion.
	var radius := virtual_mouse_offset.length() / virtual_mouse_radius
	var travel := clampf((radius - mouse_deadzone) / (1.0 - mouse_deadzone), 0, 1)
	return deg_to_rad(max_declination) * pow(travel, tilt_curve)

## Return whether a descending craft is eligible for the home-pad landing assist.
## Require a nearby, low, moderate-speed, mostly upright approach with thrust released.
func can_assist_landing() -> bool:
	var home_offset := WrapMath.delta(position, game.terrain.home)
	var approach_height: float = position.y - game.terrain.home.y - 1.15
	var horizontal_distance := Vector2(home_offset.x, home_offset.z).length()
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	return (
		not landed
		and not Input.is_action_pressed("thrust")
		and approach_height >= 0
		and approach_height <= landing_assist_height
		and horizontal_distance <= landing_assist_radius
		and velocity.y <= 1.0
		and velocity.y >= -16.0
		and horizontal_speed <= 14.0
		and absf(tilt) <= deg_to_rad(40)
	)

## Gently steer horizontal velocity toward home and vertical velocity toward -2.5 m/s.
## Called after gravity/drag; acceleration limits avoid teleporting or instantly stopping the craft.
func assist_descent(dt: float) -> void:
	# The home pad guides a controlled approach; fast/inverted crashes remain lethal.
	var home_offset := WrapMath.delta(position, game.terrain.home)
	var desired_horizontal_velocity := (Vector2(home_offset.x, home_offset.z) * 0.6).limit_length(4.0)
	var horizontal_velocity := Vector2(velocity.x, velocity.z).move_toward(
		desired_horizontal_velocity,
		10.0 * dt
	)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.y
	velocity.y = move_toward(velocity.y, -2.5, 24.0 * dt)

## Complete a safe touchdown: stop motion, clear tilt input, and stabilize orientation.
## Preserve horizontal position and heading; normal landed updates handle refueling.
func settle_on_pad() -> void:
	landed = true
	landing_assist = false
	position.y = game.terrain.home.y + 1.35
	velocity = Vector3.ZERO
	virtual_mouse_offset = Vector2.ZERO
	tilt = 0
	tilt_velocity = 0
	yaw_velocity = 0
	requested_heading = yaw
	basis = Basis(Vector3.UP, yaw)

## Advance one living craft by dt seconds: input, attitude, forces, contact, then effects.
## The game controller calls this at 60 Hz only during active gameplay.
func step(dt: float) -> void:
	if not alive:
		return
	grace = maxf(0, grace - dt)
	update_attitude(dt)
	var powered := update_motion(dt)
	update_flight_effects(dt, powered)

## Read keyboard attitude input, apply landing leveling, and integrate damped angular motion.
## Heading and declination are separate angles; the craft has no persistent roll.
func update_attitude(dt: float) -> void:
	if Input.is_action_just_pressed("center"):
		virtual_mouse_offset = Vector2.ZERO
		requested_heading = yaw
	var turn := Input.get_axis("left", "right")
	var pitch := Input.get_axis("raise", "dip")
	if turn != 0 or pitch != 0:
		requested_heading = wrapf(requested_heading - turn * dt * 1.6, -PI, PI)
		var radius := clampf(virtual_mouse_offset.length() + pitch * dt * 65, 0, virtual_mouse_radius)
		set_attitude_input(radius)
	landing_assist = can_assist_landing()
	if landing_assist:
		virtual_mouse_offset = virtual_mouse_offset.move_toward(Vector2.ZERO, 120.0 * dt)
	var target_tilt := 0.0 if landing_assist else requested_tilt()
	# Damped springs accelerate toward the target before integrating the actual angles.
	yaw_velocity += (angle_difference(yaw, requested_heading) * heading_response - yaw_velocity * heading_damping) * dt
	tilt_velocity += ((target_tilt - tilt) * orientation_response - tilt_velocity * orientation_damping) * dt
	yaw_velocity = clampf(yaw_velocity, -deg_to_rad(max_heading_rate), deg_to_rad(max_heading_rate))
	tilt_velocity = clampf(tilt_velocity, -deg_to_rad(max_tilt_rate), deg_to_rad(max_tilt_rate))
	yaw += yaw_velocity * dt
	tilt += tilt_velocity * dt
	# Godot uses -Z as forward. Yaw first, then pitch about local X; no roll is added.
	basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -tilt)

## Apply fuel use, thrust, gravity, drag, assisted descent, and terrain contact in that order.
## Return whether the engine produced thrust this tick, so exhaust follows the same decision.
func update_motion(dt: float) -> bool:
	thrusting = Input.is_action_pressed("thrust") and fuel > 0
	var powered := thrusting and position.y < flight_ceiling
	if thrusting:
		fuel = maxf(0, fuel - 4 * dt)
	if landed and powered and basis.y.y > 0.4:
		landed = false
	if landed:
		fuel = minf(100, fuel + 20 * dt)
		velocity = Vector3.ZERO
	else:
		velocity.y -= gravity * dt
		if powered:
			velocity += basis.y * thrust_acceleration * dt
		# Exponential damping composes consistently across different time-step sizes.
		velocity *= exp(-linear_drag * dt)
		if landing_assist:
			assist_descent(dt)
		velocity = velocity.limit_length(max_practical_speed)
		position += velocity * dt
		var ground: float = game.terrain.ground(position)
		if position.y <= ground + 1.15:
			var home_delta := WrapMath.delta(game.terrain.home, position)
			var safe := (
				absf(home_delta.x) <= TerrainData.PAD_HALF_SIZE
				and absf(home_delta.z) <= TerrainData.PAD_HALF_SIZE
				and absf(velocity.y) <= landing_vertical_limit
				and Vector2(velocity.x, velocity.z).length() <= landing_horizontal_limit
				and absf(tilt) <= deg_to_rad(landing_tilt_limit)
				and basis.y.y > 0
			)
			if safe:
				settle_on_pad()
			else:
				die(true)
	return powered

## Emit exhaust/speed particles, project the ground shadow, and blink during spawn protection.
## These visual effects do not modify fuel, velocity, or collision outcomes.
func update_flight_effects(dt: float, powered: bool) -> void:
	exhaust_timer -= dt
	if powered and exhaust_timer <= 0:
		exhaust_timer = 0.035
		game.effects.burst(position - basis.y, Color("ffd98d"), 2, 2, 0.35, -basis.y * 13 + velocity * 0.3)
	if position.y > 90 and exhaust_timer <= 0:
		exhaust_timer = 0.08
		game.effects.burst(
			position + Vector3(randf_range(-12, 12), randf_range(-5, 5), -15),
			Color("d3e4df"),
			1,
			0,
			0.8,
			-velocity * 0.6
		)
	shadow.position = Vector3(position.x, game.terrain.ground(position) + 0.14, position.z)
	shadow.scale = Vector3.ONE * (1.5 + minf(altitude(), 100) * 0.018)
	model.visible = grace <= 0 or fmod(grace, 0.2) < 0.13

## Return meters above the local rendered ground/water, measured from the craft underside.
func altitude() -> float:
	return maxf(0, position.y - game.terrain.ground(position) - 1.15)

## Destroy the craft once, hide its model/shadow, and notify the campaign controller.
## Enemy hits respect spawn grace; terrain collisions deliberately bypass that protection.
func die(terrain_collision: bool = false) -> void:
	if not alive or (grace > 0 and not terrain_collision):
		return
	alive = false
	thrusting = false
	hide()
	shadow.hide()
	game.effects.burst(position, Color("ffb16d"), 60, 18, 1.5)
	game.effects.sound("explosion")
	player_died.emit()

## Release the separately parented shadow and craft without reporting a gameplay death.
func dispose() -> void:
	shadow.queue_free()
	queue_free()
