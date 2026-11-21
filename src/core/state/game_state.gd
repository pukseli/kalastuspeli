class_name GameState
extends RefCounted

var tick: int = 0
var boat: BoatState = BoatState.new()
var players: Dictionary = {}
var stations: Dictionary = StationConfig.create_default_stations()

var helm_steer_detent_timer: float = 0.0
var helm_steer_detent_sign: int = 0
var helm_throttle_detent_timer: float = 0.0
var helm_throttle_detent_sign: int = 0
var helm_last_occupant: int = 0


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
	players.erase(peer_id)
	if peer_id == 0:
		return
	for sid in stations.keys():
		if int(stations[sid]) == peer_id:
			stations[sid] = 0
			if str(sid) == StationConfig.HELM_STATION_ID:
				reset_helm_detents()
				helm_last_occupant = 0


func to_dict() -> Dictionary:
	var players_dict := {}
	for pid in players:
		var p: PlayerState = players[pid]
		players_dict[str(pid)] = p.to_dict()
	return {
		"tick": tick,
		"boat": boat.to_dict(),
		"players": players_dict,
		"stations": stations.duplicate(),
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
