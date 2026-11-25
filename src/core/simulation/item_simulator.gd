class_name ItemSimulator
extends RefCounted
## Pure simulation step for picking up, placing, and swapping carryable items at configured holders.

const FIXED_DELTA: float = 1.0 / 60.0
const DEFAULT_DECK_PICKUP_RADIUS: float = 0.95

var config: ItemConfig


func _init(custom_config: ItemConfig = null) -> void:
	config = custom_config if custom_config != null else ItemConfig.new()


static func find_nearest_deck_item(
	state: GameState,
	pos: Vector3,
	max_radius: float = DEFAULT_DECK_PICKUP_RADIUS
) -> Dictionary:
	if state == null:
		return {}
	var item_ids: Array[String] = []
	for iid in state.items.keys():
		item_ids.append(str(iid))
	item_ids.sort()

	var best_item: HeldItem = null
	var best_dist := INF
	for iid in item_ids:
		var item := state.items[iid] as HeldItem
		if item == null or not item.is_on_deck():
			continue
		var dx := pos.x - item.deck_position.x
		var dz := pos.z - item.deck_position.z
		var dist := sqrt(dx * dx + dz * dz)
		if dist <= max_radius and dist < best_dist:
			best_dist = dist
			best_item = item
	if best_item == null:
		return {}
	return {"item": best_item, "distance": best_dist}


func _get_player_input(inputs: Dictionary, pid: int) -> Variant:
	if inputs.has(pid):
		return inputs[pid]
	var str_pid := str(pid)
	if inputs.has(str_pid):
		return inputs[str_pid]
	return null


func _is_interact_pressed(raw_input: Variant) -> bool:
	if raw_input is PlayerInput:
		return (raw_input as PlayerInput).interact
	if raw_input is Dictionary:
		return bool((raw_input as Dictionary).get("interact", false))
	return false


func step(state: GameState, inputs: Dictionary, _delta: float = FIXED_DELTA, blocked_peers: Dictionary = {}) -> void:
	var active_cfg: ItemConfig = config if config != null else state.item_config
	if active_cfg == null:
		return

	var pids: Array[int] = []
	for pid_raw in inputs.keys():
		var pid := int(pid_raw)
		if pid != 0 and not pids.has(pid):
			pids.append(pid)
	pids.sort()

	var touched_holders: Dictionary = {}

	for pid in pids:
		if not state.players.has(pid):
			continue
		var player: PlayerState = state.players[pid]
		if player.is_bot:
			continue
		if bool(blocked_peers.get(pid, false)):
			continue
		if state.is_player_at_station(pid):
			continue

		var raw_input: Variant = _get_player_input(inputs, pid)
		if not _is_interact_pressed(raw_input):
			continue

		var held := state.get_player_held_item(pid)
		if held == null and not FishSimulator.find_detach_target_for_player(state, pid).is_empty():
			continue

		if held != null and held.item_type == ItemConfig.ITEM_TYPE_NET:
			held.carrier_peer_id = 0
			held.holder_id = ""
			held.deck_position = Vector3(
				clampf(player.local_position.x, CrewSimulator.DECK_MIN_X, CrewSimulator.DECK_MAX_X),
				CrewSimulator.DECK_SURFACE_Y,
				clampf(player.local_position.z, CrewSimulator.DECK_MIN_Z, CrewSimulator.DECK_MAX_Z)
			)
			continue

		var best_hid := ""
		var best_dist := INF

		for holder in active_cfg.holders:
			var hid := str(holder.get("id", ""))
			if hid.is_empty() or touched_holders.has(hid):
				continue
			var pos: Vector3 = holder.get("local_position", Vector3.ZERO)
			var radius := float(holder.get("radius", ItemConfig.DEFAULT_HOLDER_RADIUS))
			var dx := player.local_position.x - pos.x
			var dz := player.local_position.z - pos.z
			var dist := sqrt(dx * dx + dz * dz)
			if dist > radius:
				continue

			var existing := state.get_holder_item(hid)
			if held != null:
				if not active_cfg.is_type_allowed(hid, held.item_type):
					continue
				if existing == held:
					continue
			elif existing == null:
				continue

			if dist < best_dist:
				best_dist = dist
				best_hid = hid

		var deck_candidate: Dictionary = {}
		if held == null:
			deck_candidate = find_nearest_deck_item(state, player.local_position, DEFAULT_DECK_PICKUP_RADIUS)

		if not deck_candidate.is_empty() and (best_hid.is_empty() or float(deck_candidate["distance"]) < best_dist):
			var deck_item := deck_candidate["item"] as HeldItem
			deck_item.carrier_peer_id = pid
			deck_item.holder_id = ""
			continue

		if best_hid.is_empty():
			continue

		var existing_item := state.get_holder_item(best_hid)
		if held == null and existing_item != null:
			existing_item.carrier_peer_id = pid
			existing_item.holder_id = ""
			existing_item.last_holder_id = best_hid
			touched_holders[best_hid] = true
		elif held != null and existing_item == null:
			held.carrier_peer_id = 0
			held.holder_id = best_hid
			held.last_holder_id = best_hid
			touched_holders[best_hid] = true
		elif held != null and existing_item != null:
			held.carrier_peer_id = 0
			held.holder_id = best_hid
			held.last_holder_id = best_hid
			existing_item.carrier_peer_id = pid
			existing_item.holder_id = ""
			existing_item.last_holder_id = best_hid
			touched_holders[best_hid] = true
