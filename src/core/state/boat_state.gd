class_name BoatState
extends RefCounted

var world_position: Vector3 = Vector3.ZERO
var heading: float = 0.0
var forward_speed: float = 0.0


func to_dict() -> Dictionary:
	return {
		"x": world_position.x,
		"y": world_position.y,
		"z": world_position.z,
		"heading": heading,
		"forward_speed": forward_speed,
	}


func from_dict(data: Dictionary) -> void:
	world_position = Vector3(
		float(data.get("x", 0.0)),
		float(data.get("y", 0.0)),
		float(data.get("z", 0.0))
	)
	heading = float(data.get("heading", 0.0))
	forward_speed = float(data.get("forward_speed", 0.0))
