class_name GameState
extends RefCounted

var tick: int = 0
var boat: BoatState = BoatState.new()
var players: Dictionary = {}
var stations: Dictionary = StationConfig.create_default_stations()
var item_config: ItemConfig = ItemConfig.new()
var items: Dictionary = item_config.create_initial_items()
var rods: Dictionary = {}
var fishes: Dictionary = {}
var catches: Array = []
var fish_notice_seq: int = 0
var fish_notice_text: String = ""
var fish_notice_timer: float = 0.0

var helm_steer_detent_timer: float = 0.0
var helm_steer_detent_sign: int = 0
var helm_throttle_detent_timer: float = 0.0
var helm_throttle_detent_sign: int = 0
var helm_last_occupant: int = 0


func _init() -> void:
	sync_rods_with_items()


func reset_helm_detents() -> void:
	helm_steer_detent_timer = 0.0
	helm_steer_detent_sign = 0
	helm_throttle_detent_timer = 0.0
	helm_throttle_detent_sign = 0


func is_player_at_station(peer_id: int) -> bool:
	if peer_id == 0:
		return false
	for sid in stations:
		if int(stations[sid]) == peer_id:
			return true
	return false


func get_player_station(peer_id: int) -> String:
	if peer_id == 0:
		return ""
	for sid in stations:
		if int(stations[sid]) == peer_id:
			return str(sid)
	return ""


func ensure_player(peer_id: int, is_bot: bool = false) -> PlayerState:
	if not players.has(peer_id):
		var p := PlayerState.new()
		p.peer_id = peer_id
		p.is_bot = is_bot
		p.color_index = absi(peer_id) % 4 if is_bot else posmod(peer_id - 1, 4)
		players[peer_id] = p
	return players[peer_id]


func remove_player(peer_id: int) -> void:
	var drop_pos := Vector3(
		ItemConfig.DEFAULT_NET_DECK_POS.x,
		CrewSimulator.DECK_SURFACE_Y,
		ItemConfig.DEFAULT_NET_DECK_POS.z
	)
	if players.has(peer_id):
		var disconnecting := players[peer_id] as PlayerState
		if disconnecting != null:
			drop_pos = Vector3(
				clampf(disconnecting.local_position.x, CrewSimulator.DECK_MIN_X, CrewSimulator.DECK_MAX_X),
				CrewSimulator.DECK_SURFACE_Y,
				clampf(disconnecting.local_position.z, CrewSimulator.DECK_MIN_Z, CrewSimulator.DECK_MAX_Z)
			)
	players.erase(peer_id)
	if peer_id == 0:
		return
	for sid in stations.keys():
		if int(stations[sid]) == peer_id:
			stations[sid] = 0
			if str(sid) == StationConfig.HELM_STATION_ID:
				reset_helm_detents()
				helm_last_occupant = 0
	var carried_ids: Array[String] = []
	for iid in items:
		var item: HeldItem = items[iid]
		if item != null and item.carrier_peer_id == peer_id:
			carried_ids.append(str(iid))
	carried_ids.sort()
	for iid in carried_ids:
		var item := items[iid] as HeldItem
		if item == null:
			continue
		if item.item_type == ItemConfig.ITEM_TYPE_NET or not return_item_to_holder(item):
			item.carrier_peer_id = 0
			item.holder_id = ""
			item.deck_position = drop_pos


func configure_items(cfg: ItemConfig) -> void:
	item_config = cfg if cfg != null else ItemConfig.new()
	items = item_config.create_initial_items()
	rods.clear()
	fishes.clear()
	catches.clear()
	fish_notice_seq = 0
	fish_notice_text = ""
	fish_notice_timer = 0.0
	sync_rods_with_items()


func sync_rods_with_items() -> void:
	for existing_rid in rods.keys():
		if not items.has(existing_rid):
			rods.erase(existing_rid)
		else:
			var existing_item: HeldItem = items[existing_rid]
			if existing_item == null or existing_item.item_type != ItemConfig.ITEM_TYPE_ROD:
				rods.erase(existing_rid)

	for existing_fid in fishes.keys():
		if not rods.has(existing_fid) and not items.has(existing_fid):
			fishes.erase(existing_fid)

	for iid in items:
		var item: HeldItem = items[iid]
		if item == null or item.item_type != ItemConfig.ITEM_TYPE_ROD:
			continue
		var rid := str(iid)
		if rods.has(rid) and rods[rid] is RodState:
			var existing_rod := rods[rid] as RodState
			existing_rod.rod_id = rid
			if existing_rod.planer == null:
				existing_rod.planer = PlanerBoard.new()
			continue

		var rod := RodState.new()
		rod.rod_id = rid
		var hid := item.holder_id if not item.holder_id.is_empty() else item.last_holder_id
		if item_config != null and not hid.is_empty() and item_config.has_holder(hid):
			var holder := item_config.get_holder(hid)
			rod.planer.side = PlanerBoard.SIDE_LEFT if int(holder.get("side", 1)) < 0 else PlanerBoard.SIDE_RIGHT
			rod.planer.attached = bool(holder.get("default_planer_attached", false))
		else:
			rod.planer.side = PlanerBoard.SIDE_RIGHT
			rod.planer.attached = false
		rods[rid] = rod


func get_rod_state(rod_id: String) -> RodState:
	if rods.has(rod_id) and rods[rod_id] is RodState:
		return rods[rod_id] as RodState
	return null


func get_deployed_rod_count() -> int:
	var count := 0
	for rid in rods:
		var rod: RodState = rods[rid]
		if rod != null and rod.is_deployed():
			count += 1
	return count


func get_fish_state(rod_id: String) -> FishState:
	if fishes.has(rod_id) and fishes[rod_id] is FishState:
		return fishes[rod_id] as FishState
	return null


func has_fish_on_rod(rod_id: String) -> bool:
	return get_fish_state(rod_id) != null


func get_hooked_fish_count() -> int:
	var count := 0
	for fid in fishes:
		if fishes[fid] is FishState:
			count += 1
	return count


func set_fish_notice(text: String, duration: float = 4.5) -> void:
	fish_notice_seq += 1
	fish_notice_text = text
	fish_notice_timer = maxf(0.0, duration)


func record_catch(species: String, weight_kg: float, size_class: String, method: String = "net") -> void:
	catches.append({
		"species": species,
		"weight_kg": maxf(0.01, weight_kg),
		"size_class": size_class,
		"method": method,
	})


func get_catch_count() -> int:
	return catches.size()


func get_biggest_catch_weight() -> float:
	var max_w := 0.0
	for entry in catches:
		if entry is Dictionary:
			max_w = maxf(max_w, float((entry as Dictionary).get("weight_kg", 0.0)))
	return max_w


func get_player_held_item(peer_id: int) -> HeldItem:
	if peer_id == 0:
		return null
	for iid in items:
		var item: HeldItem = items[iid]
		if item != null and item.carrier_peer_id == peer_id:
			return item
	return null


func is_player_holding_item(peer_id: int) -> bool:
	return get_player_held_item(peer_id) != null


func get_holder_item(holder_id: String) -> HeldItem:
	if holder_id.is_empty():
		return null
	for iid in items:
		var item: HeldItem = items[iid]
		if item != null and not item.is_carried() and item.holder_id == holder_id:
			return item
	return null


func return_item_to_holder(item: HeldItem) -> bool:
	if item == null:
		return false
	var target_id := ""
	if not item.last_holder_id.is_empty() and item_config.is_type_allowed(item.last_holder_id, item.item_type) and get_holder_item(item.last_holder_id) == null:
		target_id = item.last_holder_id
	else:
		for holder in item_config.get_compatible_holders(item.item_type):
			var hid := str(holder.get("id", ""))
			if not hid.is_empty() and get_holder_item(hid) == null:
				target_id = hid
				break
	if target_id.is_empty():
		return false
	item.carrier_peer_id = 0
	item.holder_id = target_id
	item.last_holder_id = target_id
	return true


func to_dict() -> Dictionary:
	var players_dict := {}
	for pid in players:
		var p: PlayerState = players[pid]
		players_dict[str(pid)] = p.to_dict()
	var items_dict := {}
	for iid in items:
		var item: HeldItem = items[iid]
		items_dict[str(iid)] = item.to_dict()
	var rods_dict := {}
	for rid in rods:
		var rod: RodState = rods[rid]
		if rod != null:
			rods_dict[str(rid)] = rod.to_dict()
	var fishes_dict := {}
	for fid in fishes:
		var fish: FishState = fishes[fid]
		if fish != null:
			fishes_dict[str(fid)] = fish.to_dict()
	var catches_arr: Array = []
	for entry in catches:
		if entry is Dictionary:
			var ed := entry as Dictionary
			catches_arr.append({
				"species": str(ed.get("species", FishState.SPECIES_PERCH)),
				"weight_kg": maxf(0.01, float(ed.get("weight_kg", 0.5))),
				"size_class": str(ed.get("size_class", FishState.SIZE_SMALL)),
				"method": str(ed.get("method", "net")),
			})
	return {
		"tick": tick,
		"boat": boat.to_dict(),
		"players": players_dict,
		"stations": stations.duplicate(),
		"items": items_dict,
		"rods": rods_dict,
		"fishes": fishes_dict,
		"catches": catches_arr,
		"fish_notice_seq": fish_notice_seq,
		"fish_notice_text": fish_notice_text,
		"fish_notice_timer": fish_notice_timer,
	}


func from_dict(data: Dictionary) -> void:
	tick = int(data.get("tick", 0))
	var boat_data: Variant = data.get("boat", {})
	if boat_data is Dictionary:
		boat.from_dict(boat_data)

	var raw_players: Variant = data.get("players", {})
	var incoming_ids: Dictionary = {}
	if raw_players is Dictionary:
		for raw_id in raw_players:
			var pid := int(raw_id)
			var p_data: Variant = raw_players[raw_id]
			if p_data is Dictionary:
				incoming_ids[pid] = true
				var player := ensure_player(pid, bool(p_data.get("is_bot", false)))
				player.from_dict(p_data)
				player.peer_id = pid

	for existing_key in players.keys():
		if not incoming_ids.has(existing_key):
			players.erase(existing_key)

	var raw_stations: Variant = data.get("stations", null)
	if raw_stations is Dictionary:
		var next_stations: Dictionary = {}
		for sid in raw_stations:
			next_stations[str(sid)] = int(raw_stations[sid])
		stations = next_stations

	var raw_items: Variant = data.get("items", null)
	if raw_items is Dictionary:
		var incoming_item_ids: Dictionary = {}
		for raw_iid in raw_items:
			var iid := str(raw_iid)
			var i_data: Variant = raw_items[raw_iid]
			if i_data is Dictionary:
				incoming_item_ids[iid] = true
				var item: HeldItem
				if items.has(iid) and items[iid] is HeldItem:
					item = items[iid] as HeldItem
				else:
					item = HeldItem.new()
					items[iid] = item
				item.from_dict(i_data)
				item.id = iid
		for existing_iid in items.keys():
			if not incoming_item_ids.has(existing_iid):
				items.erase(existing_iid)

	var raw_rods: Variant = data.get("rods", null)
	if raw_rods is Dictionary:
		var incoming_rod_ids: Dictionary = {}
		for raw_rid in raw_rods:
			var rid := str(raw_rid)
			var r_data: Variant = raw_rods[raw_rid]
			if r_data is Dictionary:
				incoming_rod_ids[rid] = true
				var rod: RodState
				if rods.has(rid) and rods[rid] is RodState:
					rod = rods[rid] as RodState
				else:
					rod = RodState.new()
					rods[rid] = rod
				rod.from_dict(r_data)
				rod.rod_id = rid
		for existing_rid in rods.keys():
			if not incoming_rod_ids.has(existing_rid):
				rods.erase(existing_rid)

	var raw_fishes: Variant = data.get("fishes", null)
	if raw_fishes is Dictionary:
		var incoming_fish_ids: Dictionary = {}
		for raw_fid in raw_fishes:
			var fid := str(raw_fid)
			var f_data: Variant = raw_fishes[raw_fid]
			if f_data is Dictionary:
				incoming_fish_ids[fid] = true
				var fish: FishState
				if fishes.has(fid) and fishes[fid] is FishState:
					fish = fishes[fid] as FishState
				else:
					fish = FishState.new()
					fishes[fid] = fish
				fish.from_dict(f_data)
				fish.rod_id = fid
		for existing_fid in fishes.keys():
			if not incoming_fish_ids.has(existing_fid):
				fishes.erase(existing_fid)

	var raw_catches: Variant = data.get("catches", null)
	if raw_catches is Array:
		var next_catches: Array = []
		for raw_entry in (raw_catches as Array):
			if raw_entry is Dictionary:
				var ed := raw_entry as Dictionary
				next_catches.append({
					"species": str(ed.get("species", FishState.SPECIES_PERCH)),
					"weight_kg": maxf(0.01, float(ed.get("weight_kg", 0.5))),
					"size_class": str(ed.get("size_class", FishState.SIZE_SMALL)),
					"method": str(ed.get("method", "net")),
				})
		catches = next_catches

	fish_notice_seq = int(data.get("fish_notice_seq", fish_notice_seq))
	fish_notice_text = str(data.get("fish_notice_text", ""))
	fish_notice_timer = maxf(0.0, float(data.get("fish_notice_timer", 0.0)))

	sync_rods_with_items()
