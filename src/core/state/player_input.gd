class_name PlayerInput
extends RefCounted

var throttle: float = 0.0
var steering: float = 0.0


func to_dict() -> Dictionary:
	return {
		"throttle": throttle,
		"steering": steering,
	}


func from_dict(data: Dictionary) -> void:
	throttle = float(data.get("throttle", 0.0))
	steering = float(data.get("steering", 0.0))
