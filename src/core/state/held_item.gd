class_name HeldItem
extends RefCounted
## Pure state model representing a carryable item (e.g. fishing rod) in a holder or carried by a peer.

var id: String = ""
var item_type: String = "rod"
var color_index: int = 0
var carrier_peer_id: int = 0
var holder_id: String = ""
var last_holder_id: String = ""


func is_carried() -> bool:
	return carrier_peer_id != 0


func clone() -> HeldItem:
	var copy := HeldItem.new()
	copy.id = id
	copy.item_type = item_type
	copy.color_index = color_index
	copy.carrier_peer_id = carrier_peer_id
	copy.holder_id = holder_id
	copy.last_holder_id = last_holder_id
	return copy


func to_dict() -> Dictionary:
	return {
		"id": id,
		"item_type": item_type,
		"color_index": color_index,
		"carrier_peer_id": carrier_peer_id,
		"holder_id": holder_id,
		"last_holder_id": last_holder_id,
	}


func from_dict(data: Dictionary) -> void:
	id = str(data.get("id", id))
	item_type = str(data.get("item_type", "rod"))
	color_index = int(data.get("color_index", 0))
	carrier_peer_id = int(data.get("carrier_peer_id", 0))
	holder_id = str(data.get("holder_id", ""))
	last_holder_id = str(data.get("last_holder_id", ""))
