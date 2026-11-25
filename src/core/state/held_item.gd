class_name HeldItem
extends RefCounted
## Pure state model representing a carryable item (e.g. fishing rod) in a holder or carried by a peer.

var id: String = ""
var item_type: String = "rod"
var color_index: int = 0
var carrier_peer_id: int = 0
var holder_id: String = ""
var last_holder_id: String = ""
var deck_position: Vector3 = Vector3.ZERO


func is_carried() -> bool:
	return carrier_peer_id != 0


func is_on_deck() -> bool:
	return carrier_peer_id == 0 and holder_id.is_empty()


func clone() -> HeldItem:
	var copy := HeldItem.new()
	copy.id = id
	copy.item_type = item_type
	copy.color_index = color_index
	copy.carrier_peer_id = carrier_peer_id
	copy.holder_id = holder_id
	copy.last_holder_id = last_holder_id
	copy.deck_position = deck_position
	return copy


func to_dict() -> Dictionary:
	return {
		"id": id,
		"item_type": item_type,
		"color_index": color_index,
		"carrier_peer_id": carrier_peer_id,
		"holder_id": holder_id,
		"last_holder_id": last_holder_id,
		"deck_position": {
			"x": deck_position.x,
			"y": deck_position.y,
			"z": deck_position.z,
		},
	}


func from_dict(data: Dictionary) -> void:
	id = str(data.get("id", id))
	item_type = str(data.get("item_type", "rod"))
	color_index = int(data.get("color_index", 0))
	carrier_peer_id = int(data.get("carrier_peer_id", 0))
	holder_id = str(data.get("holder_id", ""))
	last_holder_id = str(data.get("last_holder_id", ""))
	var raw_deck_pos: Variant = data.get("deck_position", null)
	if raw_deck_pos is Vector3:
		deck_position = raw_deck_pos as Vector3
	elif raw_deck_pos is Dictionary:
		var dp := raw_deck_pos as Dictionary
		deck_position = Vector3(float(dp.get("x", 0.0)), float(dp.get("y", 0.0)), float(dp.get("z", 0.0)))
	else:
		deck_position = Vector3.ZERO
