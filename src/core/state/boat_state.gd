class_name BoatState
extends RefCounted

var world_position: Vector3 = Vector3.ZERO
var heading: float = 0.0
var forward_speed: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var angular_velocity: float = 0.0
var throttle: float = 0.0
var steering_angle: float = 0.0


func to_dict() -> Dictionary:
	return {
		"x": world_position.x,
		"y": world_position.y,
		"z": world_position.z,
		"heading": heading,
		"forward_speed": forward_speed,
		"vx": velocity.x,
		"vz": velocity.y,
		"angular_velocity": angular_velocity,
		"throttle": throttle,
		"steering_angle": steering_angle,
	}


func from_dict(data: Dictionary) -> void:
	world_position = Vector3(
		float(data.get("x", 0.0)),
		float(data.get("y", 0.0)),
		float(data.get("z", 0.0))
	)
	heading = float(data.get("heading", 0.0))
	forward_speed = float(data.get("forward_speed", 0.0))
	velocity = Vector2(
		float(data.get("vx", 0.0)),
		float(data.get("vz", 0.0))
	)
	angular_velocity = float(data.get("angular_velocity", 0.0))
	throttle = float(data.get("throttle", 0.0))
	steering_angle = float(data.get("steering_angle", 0.0))
