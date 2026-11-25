class_name RenderInterpolator
extends RefCounted

var _prev_boat_pos: Vector3 = Vector3.ZERO
var _curr_boat_pos: Vector3 = Vector3.ZERO
var _prev_boat_heading: float = 0.0
var _curr_boat_heading: float = 0.0
var _prev_players: Dictionary = {}
var _curr_players: Dictionary = {}
var _has_prev: bool = false


func capture(state: GameState) -> void:
	if state == null:
		return
	if _has_prev:
		_prev_boat_pos = _curr_boat_pos
		_prev_boat_heading = _curr_boat_heading
		_prev_players = _curr_players.duplicate()
	_curr_boat_pos = state.boat.world_position
	_curr_boat_heading = state.boat.heading
	_curr_players.clear()
	for pid_key in state.players:
		var p: PlayerState = state.players[pid_key]
		if p != null:
			_curr_players[int(pid_key)] = p.local_position
	if not _has_prev:
		_prev_boat_pos = _curr_boat_pos
		_prev_boat_heading = _curr_boat_heading
		_prev_players = _curr_players.duplicate()
		_has_prev = true


func blend(alpha: float) -> Dictionary:
	var t := clampf(alpha, 0.0, 1.0)
	var b_pos := _prev_boat_pos.lerp(_curr_boat_pos, t)
	var b_head := wrapf(lerp_angle(_prev_boat_heading, _curr_boat_heading, t), -PI, PI)
	var out_players: Dictionary = {}
	for pid in _curr_players:
		var curr_p: Vector3 = _curr_players[pid]
		if _prev_players.has(pid):
			out_players[pid] = (_prev_players[pid] as Vector3).lerp(curr_p, t)
		else:
			out_players[pid] = curr_p
	return {"boat_pos": b_pos, "boat_heading": b_head, "players": out_players}
