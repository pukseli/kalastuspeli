class_name GameState
extends RefCounted

var tick: int = 0
var boat: BoatState = BoatState.new()
var players: Dictionary = {}
var stations: Dictionary = {
	"helm": 0,
}


func is_player_at_station(peer_id: int) -> bool:
	for sid in stations:
		if int(stations[sid]) == peer_id:
			return true
	return false


func get_player_station(peer_id: int) -> String:
	for sid in stations:
		if int(stations[sid]) == peer_id:
			return str(sid)
	return ""


func ensure_player(peer_id: int, is_bot: bool = false) -> PlayerState:
	if not players.has(peer_id):
		var p := PlayerState.new()
		p.peer_id = peer_id
		p.is_bot = is_bot
		p.color_index = absi(peer_id) % 4
		players[peer_id] = p
	return players[peer_id]


func remove_player(peer_id: int) -> void:
	players.erase(peer_id)
	for sid in stations.keys():
		if int(stations[sid]) == peer_id:
			stations[sid] = 0


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
	if data.has("boat") and data["boat"] is Dictionary:
		boat.from_dict(data["boat"])

	var raw_players: Dictionary = data.get("players", {})
	var current_pids: Array = players.keys()
	for pid in current_pids:
		if not raw_players.has(str(pid)) and not raw_players.has(pid):
			players.erase(pid)

	for raw_id in raw_players:
		var pid := int(raw_id)
		var p_dict: Dictionary = raw_players[raw_id]
		var player := ensure_player(pid, bool(p_dict.get("is_bot", false)))
		player.from_dict(p_dict)

	if data.has("stations") and data["stations"] is Dictionary:
		var raw_stations: Dictionary = data["stations"]
		for sid in raw_stations:
			stations[str(sid)] = int(raw_stations[sid])
