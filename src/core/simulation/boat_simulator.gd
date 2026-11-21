class_name BoatSimulator
extends RefCounted

const FIXED_DELTA: float = 1.0 / 60.0
const DEFAULT_MAX_STEERING_ANGLE: float = deg_to_rad(35.0)
const BOAT_MAX_SPEED: float = 8.0
const BOAT_MAX_REVERSE_SPEED: float = -3.0
const BOAT_WATER_DRAG: float = 2.5
const BOAT_TURN_SPEED: float = 1.2

class Config extends RefCounted:
	var engine_power: float = 12.0
	var turn_power: float = 6.8
	var passive_turn_power: float = 1.0
	var forward_drag: float = 0.4
	var lateral_drag: float = 4.0
	var angular_drag: float = 2.5
	var water_friction: float = 1.0
	var max_steering_angle: float = DEFAULT_MAX_STEERING_ANGLE
	var steering_speed: float = 10.0
	var max_forward_speed: float = 8.0
	var max_reverse_speed: float = -3.0

var config: Config = Config.new()


func step(boat: BoatState, input: PlayerInput, delta: float = FIXED_DELTA) -> void:
	var target_throttle := clampf(input.throttle, -1.0, 1.0)
	var target_steering := clampf(input.steering, -1.0, 1.0)
	var target_angle := target_steering * config.max_steering_angle

	boat.throttle = target_throttle
	boat.steering_angle = move_toward(boat.steering_angle, target_angle, config.steering_speed * delta)

	var fwd_dir := Vector2(-sin(boat.heading), -cos(boat.heading))
	var right_dir := Vector2(cos(boat.heading), -sin(boat.heading))

	if boat.velocity.length_squared() < 0.0001 and absf(boat.forward_speed) > 0.0001:
		boat.velocity = fwd_dir * boat.forward_speed

	var local_fwd := boat.velocity.dot(fwd_dir)
	var local_lat := boat.velocity.dot(right_dir)

	var fwd_damping := maxf(0.0, 1.0 - config.forward_drag * delta)
	var lat_damping := maxf(0.0, 1.0 - config.lateral_drag * delta)
	local_fwd *= fwd_damping
	local_lat *= lat_damping
	local_fwd = move_toward(local_fwd, 0.0, config.water_friction * delta)
	local_lat = move_toward(local_lat, 0.0, config.water_friction * 2.0 * delta)

	var forward_thrust := boat.throttle * cos(boat.steering_angle) * config.engine_power
	local_fwd += forward_thrust * delta
	local_fwd = clampf(local_fwd, config.max_reverse_speed, config.max_forward_speed)

	boat.velocity = fwd_dir * local_fwd + right_dir * local_lat
	boat.forward_speed = local_fwd

	var active_torque := boat.throttle * sin(boat.steering_angle) * config.turn_power
	var passive_torque := sin(boat.steering_angle) * local_fwd * config.passive_turn_power
	var total_torque := active_torque + passive_torque

	var ang_damping := maxf(0.0, 1.0 - config.angular_drag * delta)
	boat.angular_velocity = boat.angular_velocity * ang_damping + total_torque * delta
	boat.angular_velocity = move_toward(boat.angular_velocity, 0.0, 0.1 * delta)

	boat.heading = wrapf(boat.heading + boat.angular_velocity * delta, -PI, PI)

	boat.world_position.x += boat.velocity.x * delta
	boat.world_position.z += boat.velocity.y * delta
