class_name ItemConfig
extends RefCounted
## Configurable item holder layout and initial rod count per boat configuration.

const ITEM_TYPE_ROD: String = "rod"
const ITEM_TYPE_NET: String = "net"
const DEFAULT_ROD_COUNT: int = 6
const DEFAULT_NET_COUNT: int = 1
const DEFAULT_NET_DECK_POS: Vector3 = Vector3(0.0, 0.25, 0.6)
const DEFAULT_HOLDER_RADIUS: float = 0.85
const HOLDER_MOUNT_Y: float = 0.65
const DEFAULT_SIDE_X: float = 1.55
const DEFAULT_STERN_X: float = 0.95
const DEFAULT_STERN_Z: float = 3.45

var rod_count: int = DEFAULT_ROD_COUNT
var net_count: int = DEFAULT_NET_COUNT
var holders: Array[Dictionary] = []


func _init(custom_holders: Array = [], custom_rod_count: int = DEFAULT_ROD_COUNT, custom_net_count: int = -1) -> void:
	var source_holders: Array = create_default_rod_holders() if custom_holders.is_empty() else custom_holders
	holders.clear()
	for raw_entry in source_holders:
		if not (raw_entry is Dictionary):
			continue
		var normalized := _normalize_holder(raw_entry as Dictionary)
		if not str(normalized.get("id", "")).is_empty():
			holders.append(normalized)

	var compatible_count := get_compatible_holders(ITEM_TYPE_ROD).size()
	rod_count = clampi(custom_rod_count, 0, compatible_count)
	if custom_net_count >= 0:
		net_count = custom_net_count
	else:
		net_count = DEFAULT_NET_COUNT if custom_holders.is_empty() else 0


static func create_default_rod_holders() -> Array[Dictionary]:
	var specs: Array[Dictionary] = [
		{"slot": -3, "id": "rod_-3", "label": "-3", "side": -1, "pos": Vector3(-DEFAULT_SIDE_X, HOLDER_MOUNT_Y, 0.8), "tilt": Vector3(14.0, 0.0, 38.0), "spread": -55.0, "planer": true},
		{"slot": -2, "id": "rod_-2", "label": "-2", "side": -1, "pos": Vector3(-DEFAULT_SIDE_X, HOLDER_MOUNT_Y, 2.1), "tilt": Vector3(14.0, 0.0, 38.0), "spread": -38.0, "planer": true},
		{"slot": -1, "id": "rod_-1", "label": "-1", "side": -1, "pos": Vector3(-DEFAULT_STERN_X, HOLDER_MOUNT_Y, DEFAULT_STERN_Z), "tilt": Vector3(38.0, 0.0, 12.0), "spread": -8.0, "planer": false},
		{"slot": 1, "id": "rod_+1", "label": "+1", "side": 1, "pos": Vector3(DEFAULT_STERN_X, HOLDER_MOUNT_Y, DEFAULT_STERN_Z), "tilt": Vector3(38.0, 0.0, -12.0), "spread": 8.0, "planer": false},
		{"slot": 2, "id": "rod_+2", "label": "+2", "side": 1, "pos": Vector3(DEFAULT_SIDE_X, HOLDER_MOUNT_Y, 2.1), "tilt": Vector3(14.0, 0.0, -38.0), "spread": 38.0, "planer": true},
		{"slot": 3, "id": "rod_+3", "label": "+3", "side": 1, "pos": Vector3(DEFAULT_SIDE_X, HOLDER_MOUNT_Y, 0.8), "tilt": Vector3(14.0, 0.0, -38.0), "spread": 55.0, "planer": true},
	]
	var result: Array[Dictionary] = []
	for spec in specs:
		result.append({
			"id": str(spec["id"]),
			"slot": int(spec["slot"]),
			"label": str(spec["label"]),
			"side": int(spec["side"]),
			"local_position": spec["pos"],
			"tilt_degrees": spec["tilt"],
			"radius": DEFAULT_HOLDER_RADIUS,
			"allowed_types": [ITEM_TYPE_ROD],
			"spread_angle_deg": float(spec["spread"]),
			"default_planer_attached": bool(spec["planer"]),
		})
	return result


static func create_default_config(custom_rod_count: int = DEFAULT_ROD_COUNT, custom_net_count: int = 0) -> ItemConfig:
	return ItemConfig.new(create_default_rod_holders(), custom_rod_count, custom_net_count)


func get_holder(holder_id: String) -> Dictionary:
	for h in holders:
		if str(h.get("id", "")) == holder_id:
			return h
	return {}


func has_holder(holder_id: String) -> bool:
	return not get_holder(holder_id).is_empty()


func get_holder_ids() -> Array[String]:
	var ids: Array[String] = []
	for h in holders:
		ids.append(str(h.get("id", "")))
	return ids


func get_compatible_holders(item_type: String) -> Array[Dictionary]:
	var compatible: Array[Dictionary] = []
	for h in holders:
		var allowed: Variant = h.get("allowed_types", [])
		if allowed is Array and (allowed as Array).has(item_type):
			compatible.append(h)
	return compatible


func is_type_allowed(holder_id: String, item_type: String) -> bool:
	var h := get_holder(holder_id)
	if h.is_empty():
		return false
	var allowed: Variant = h.get("allowed_types", [])
	return allowed is Array and (allowed as Array).has(item_type)


func get_layout_signature() -> String:
	var parts: Array[String] = []
	for h in holders:
		var pos: Vector3 = h.get("local_position", Vector3.ZERO)
		var tilt: Vector3 = h.get("tilt_degrees", Vector3.ZERO)
		parts.append("%s:%d:%.3f,%.3f,%.3f:%.2f,%.2f,%.2f:%.3f" % [
			str(h.get("id", "")),
			int(h.get("side", 0)),
			pos.x,
			pos.y,
			pos.z,
			tilt.x,
			tilt.y,
			tilt.z,
			float(h.get("radius", DEFAULT_HOLDER_RADIUS)),
		])
	return "|".join(parts)


func create_initial_items() -> Dictionary:
	var compatible := get_compatible_holders(ITEM_TYPE_ROD)
	var ordered: Array[Dictionary] = []
	for h in compatible:
		ordered.append(h)

	var all_have_slots := not ordered.is_empty()
	for h in ordered:
		if not h.has("slot"):
			all_have_slots = false
			break

	if all_have_slots:
		ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var sa := int(a["slot"])
			var sb := int(b["slot"])
			var abs_a := absi(sa)
			var abs_b := absi(sb)
			if abs_a != abs_b:
				return abs_a < abs_b
			return sa < sb
		)

	var count := mini(rod_count, ordered.size())
	var result: Dictionary = {}
	for i in range(count):
		var target_holder_id := str(ordered[i]["id"])
		var item := HeldItem.new()
		item.id = "rod_%d" % (i + 1)
		item.item_type = ITEM_TYPE_ROD
		item.color_index = i
		item.carrier_peer_id = 0
		item.holder_id = target_holder_id
		item.last_holder_id = target_holder_id
		result[item.id] = item
	for i in range(net_count):
		var net_item := HeldItem.new()
		net_item.id = "net_%d" % (i + 1)
		net_item.item_type = ITEM_TYPE_NET
		net_item.color_index = i
		net_item.carrier_peer_id = 0
		net_item.holder_id = ""
		net_item.last_holder_id = ""
		net_item.deck_position = Vector3(
			DEFAULT_NET_DECK_POS.x + float(i) * 0.35,
			DEFAULT_NET_DECK_POS.y,
			DEFAULT_NET_DECK_POS.z
		)
		result[net_item.id] = net_item
	return result


func _normalize_holder(raw: Dictionary) -> Dictionary:
	var hid := str(raw.get("id", "")).strip_edges()
	var raw_pos: Variant = raw.get("local_position", Vector3(0.0, HOLDER_MOUNT_Y, 0.0))
	var pos := Vector3(0.0, HOLDER_MOUNT_Y, 0.0)
	if raw_pos is Vector3:
		pos = raw_pos as Vector3
	elif raw_pos is Dictionary:
		var pd := raw_pos as Dictionary
		pos = Vector3(float(pd.get("x", 0.0)), float(pd.get("y", HOLDER_MOUNT_Y)), float(pd.get("z", 0.0)))

	var default_side := -1 if pos.x < 0.0 else 1
	var side := int(raw.get("side", default_side))
	var tilt := Vector3(14.0, 0.0, -float(side) * 38.0)
	var raw_tilt: Variant = raw.get("tilt_degrees", null)
	if raw_tilt is Vector3:
		tilt = raw_tilt as Vector3
	elif raw_tilt is Dictionary:
		var td := raw_tilt as Dictionary
		tilt = Vector3(float(td.get("x", tilt.x)), float(td.get("y", tilt.y)), float(td.get("z", tilt.z)))
	var radius := maxf(0.05, float(raw.get("radius", DEFAULT_HOLDER_RADIUS)))
	var label := str(raw.get("label", hid))
	var spread_angle_deg := float(raw.get("spread_angle_deg", float(side) * 20.0))
	var default_planer_attached := bool(raw.get("default_planer_attached", false))

	var allowed_types: Array[String] = []
	var raw_allowed: Variant = raw.get("allowed_types", [ITEM_TYPE_ROD])
	if raw_allowed is Array:
		for t in (raw_allowed as Array):
			var ts := str(t).strip_edges()
			if not ts.is_empty() and not allowed_types.has(ts):
				allowed_types.append(ts)
	if allowed_types.is_empty():
		allowed_types.append(ITEM_TYPE_ROD)

	var out := {
		"id": hid,
		"label": label,
		"side": side,
		"local_position": pos,
		"tilt_degrees": tilt,
		"radius": radius,
		"allowed_types": allowed_types,
		"spread_angle_deg": spread_angle_deg,
		"default_planer_attached": default_planer_attached,
	}
	if raw.has("slot"):
		out["slot"] = int(raw["slot"])
	return out
