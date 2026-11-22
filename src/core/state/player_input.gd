class_name PlayerInput
extends RefCounted

var throttle: float = 0.0
var steering: float = 0.0
var move_x: float = 0.0
var move_z: float = 0.0
var interact: bool = false
var interact_held: bool = false
var line_input: float = 0.0


func to_dict() -> Dictionary:
	return {
		"throttle": throttle,
		"steering": steering,
		"move_x": move_x,
		"move_z": move_z,
		"interact": interact,
		"interact_held": interact_held,
		"line_input": line_input,
	}


func from_dict(data: Dictionary) -> void:
	throttle = float(data.get("throttle", 0.0))
	steering = float(data.get("steering", 0.0))
	move_x = float(data.get("move_x", 0.0))
	move_z = float(data.get("move_z", 0.0))
	interact = bool(data.get("interact", false))
	interact_held = bool(data.get("interact_held", false))
	line_input = clampf(float(data.get("line_input", 0.0)), -1.0, 1.0)
