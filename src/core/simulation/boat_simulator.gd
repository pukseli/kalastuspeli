class_name BoatSimulator
extends RefCounted

const FIXED_DELTA: float = 1.0 / 60.0
const BOAT_ACCEL: float = 6.0
const BOAT_MAX_SPEED: float = 8.0
const BOAT_MAX_REVERSE_SPEED: float = -3.0
const BOAT_WATER_DRAG: float = 2.5
const BOAT_TURN_SPEED: float = 1.2


func step(boat: BoatState, input: PlayerInput, delta: float = FIXED_DELTA) -> void:
	var throttle := clampf(input.throttle, -1.0, 1.0)
	var steering := clampf(input.steering, -1.0, 1.0)

	if absf(throttle) > 0.001:
		boat.forward_speed += throttle * BOAT_ACCEL * delta
	else:
		boat.forward_speed = move_toward(boat.forward_speed, 0.0, BOAT_WATER_DRAG * delta)

	boat.forward_speed = clampf(boat.forward_speed, BOAT_MAX_REVERSE_SPEED, BOAT_MAX_SPEED)
	boat.heading += steering * BOAT_TURN_SPEED * delta

	var forward_dir := Vector3(-sin(boat.heading), 0.0, -cos(boat.heading))
	boat.world_position += forward_dir * boat.forward_speed * delta
