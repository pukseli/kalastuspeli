class_name GameState
extends RefCounted

var tick: int = 0
var boat: BoatState = BoatState.new()
var players: Dictionary = {}


func ensure_player(peer_id: int, is_bot: bool = false) -> PlayerState:
	if players.has(peer_id):
		return players[peer_id] as PlayerState
	var player := PlayerState.new()
	player.peer_id = peer_id
	player.is_bot = is_bot
	player.color_index = absi(peer_id) % 4 if is_bot else posmod(peer_id - 1, 4)
	players[peer_id] = player
	return player


func remove_player(peer_id: int) -> void:
	players.erase(peer_id)


func to_dict() -> Dictionary:
	var serialized_players: Dictionary = {}
	for peer_id in players:
		var player: PlayerState = players[peer_id]
		serialized_players[int(peer_id)] = player.to_dict()
	return {
		"tick": tick,
		"boat": boat.to_dict(),
		"players": serialized_players,
	}


func from_dict(data: Dictionary) -> void:
	tick = int(data.get("tick", 0))
	var boat_data: Variant = data.get("boat", {})
	if boat_data is Dictionary:
		boat.from_dict(boat_data)

	var raw_players: Variant = data.get("players", {})
	var incoming_ids: Dictionary = {}
	if raw_players is Dictionary:
		for raw_key in raw_players:
			var pid := int(raw_key)
			var p_data: Variant = raw_players[raw_key]
			if p_data is Dictionary:
				incoming_ids[pid] = true
				var player := ensure_player(pid, bool(p_data.get("is_bot", false)))
				player.from_dict(p_data)
				player.peer_id = pid

	for existing_key in players.keys():
		if not incoming_ids.has(existing_key):
			players.erase(existing_key)
