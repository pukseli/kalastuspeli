class_name PlayerState
extends RefCounted

var peer_id: int = 1
var local_position: Vector3 = Vector3(0.0, 0.25, 0.0)
var color_index: int = 0
var is_bot: bool = false


func to_dict() -> Dictionary:
	return {
		"peer_id": peer_id,
		"x": local_position.x,
		"y": local_position.y,
		"z": local_position.z,
		"color_index": color_index,
		"is_bot": is_bot,
	}


func from_dict(data: Dictionary) -> void:
	peer_id = int(data.get("peer_id", 1))
	local_position = Vector3(
		float(data.get("x", 0.0)),
		float(data.get("y", 0.25)),
		float(data.get("z", 0.0))
	)
	color_index = int(data.get("color_index", 0))
	is_bot = bool(data.get("is_bot", false))
