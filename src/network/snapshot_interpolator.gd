class_name SnapshotInterpolator
extends RefCounted
## Pure snapshot buffer and time-based GameState interpolator (zero Node/Input/network dependencies).

const FIXED_DELTA: float = 1.0 / 60.0
const MIN_INTERP_DELAY: float = 0.1
const MAX_INTERP_DELAY: float = 0.6
const BUFFER_INTERVAL_MULTIPLIER: float = 2.0
const MAX_BUFFER_SIZE: int = 32
const CLOCK_SNAP_THRESHOLD: float = 0.5
const CLOCK_DRIFT_DEADBAND: float = 0.05
const CLOCK_DRIFT_CORRECTION_RATE: float = 0.25

var render_time: float = 0.0
var current_delay: float = MIN_INTERP_DELAY
var measured_interval: float = 3.0 * FIXED_DELTA
var latest_stations: Dictionary = StationConfig.create_default_stations()
var latest_items: Dictionary = {}

var _buffer: Array[Dictionary] = []
var _has_snapshot: bool = false
var _last_tick: int = -1
var _has_latest_items: bool = false


## Clears buffered snapshots and resets clock/delay tracking to defaults.
func clear() -> void:
	_buffer.clear()
	_has_snapshot = false
	_last_tick = -1
	render_time = 0.0
	current_delay = MIN_INTERP_DELAY
	measured_interval = 3.0 * FIXED_DELTA
	latest_stations = StationConfig.create_default_stations()
	latest_items.clear()
	_has_latest_items = false


## Returns the number of snapshots currently buffered.
func get_buffer_size() -> int:
	return _buffer.size()


## Returns the tick of the newest accepted snapshot, or -1 if empty.
func get_latest_tick() -> int:
	return _last_tick


## Returns a copy of the discrete station occupancy from the latest snapshot.
func get_latest_stations() -> Dictionary:
	return latest_stations.duplicate()


## Parses and buffers an incoming snapshot if its tick is strictly newer than the last accepted tick.
func push_snapshot(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false

	var tick := int(snapshot.get("tick", 0))
	if _has_snapshot and tick <= _last_tick:
		return false

	var parsed := GameState.new()
	parsed.from_dict(snapshot)
	var sim_time := float(tick) * FIXED_DELTA

	if _has_snapshot:
		var tick_diff := tick - _last_tick
		measured_interval = clampf(
			float(tick_diff) * FIXED_DELTA,
			FIXED_DELTA,
			MAX_INTERP_DELAY / BUFFER_INTERVAL_MULTIPLIER
		)
		current_delay = clampf(
			maxf(MIN_INTERP_DELAY, measured_interval * BUFFER_INTERVAL_MULTIPLIER),
			MIN_INTERP_DELAY,
			MAX_INTERP_DELAY
		)
	else:
		_has_snapshot = true
		render_time = sim_time - current_delay

	_last_tick = tick
	latest_stations = parsed.stations.duplicate()
	var has_items := snapshot.has("items") and snapshot["items"] is Dictionary
	if has_items:
		latest_items = _clone_items_dict(parsed.items)
		_has_latest_items = true
	_buffer.append({
		"tick": tick,
		"time": sim_time,
		"state": parsed,
		"has_items": has_items,
	})
	while _buffer.size() > MAX_BUFFER_SIZE:
		_buffer.pop_front()

	return true


## Samples the buffered snapshots into target_state at sample_time without extrapolating.
func sample_at(target_state: GameState, sample_time: float, use_latest_stations: bool = true) -> bool:
	if target_state == null or _buffer.is_empty():
		return false

	var last_idx := _buffer.size() - 1
	if _buffer.size() == 1 or sample_time <= float(_buffer[0]["time"]):
		_copy_state_into(target_state, _buffer[0]["state"], use_latest_stations, bool(_buffer[0].get("has_items", false)))
		return true

	if sample_time >= float(_buffer[last_idx]["time"]):
		_copy_state_into(target_state, _buffer[last_idx]["state"], use_latest_stations, bool(_buffer[last_idx].get("has_items", false)))
		return true

	var entry_a: Dictionary = _buffer[0]
	var entry_b: Dictionary = _buffer[last_idx]
	for i in range(last_idx):
		var t0 := float(_buffer[i]["time"])
		var t1 := float(_buffer[i + 1]["time"])
		if sample_time >= t0 and sample_time <= t1:
			entry_a = _buffer[i]
			entry_b = _buffer[i + 1]
			break

	var time_a := float(entry_a["time"])
	var time_b := float(entry_b["time"])
	var span := time_b - time_a
	var t := clampf((sample_time - time_a) / span, 0.0, 1.0) if span > 0.000001 else 1.0

	var state_a: GameState = entry_a["state"]
	var state_b: GameState = entry_b["state"]
	_interpolate_states(target_state, state_a, state_b, t, use_latest_stations, bool(entry_b.get("has_items", false)))
	return true


## Advances render_time monotonically with drift correction and samples the interpolated state.
func step(target_state: GameState, delta: float = FIXED_DELTA) -> bool:
	if target_state == null or _buffer.is_empty():
		return false

	var latest_time := float(_buffer[_buffer.size() - 1]["time"])
	var target_time := latest_time - current_delay
	var error := target_time - render_time

	if error > CLOCK_SNAP_THRESHOLD:
		render_time = target_time
	elif error > CLOCK_DRIFT_DEADBAND:
		render_time += delta * (1.0 + CLOCK_DRIFT_CORRECTION_RATE)
	elif error < -CLOCK_DRIFT_DEADBAND:
		render_time += delta * (1.0 - CLOCK_DRIFT_CORRECTION_RATE)
	else:
		render_time += delta

	render_time = minf(render_time, latest_time)
	return sample_at(target_state, render_time, true)


func _copy_state_into(target_state: GameState, src: GameState, use_latest_stations: bool, src_has_items: bool = false) -> void:
	target_state.tick = src.tick
	_copy_boat_state(target_state.boat, src.boat)
	_sync_players_from_single(target_state, src)
	target_state.stations = latest_stations.duplicate() if use_latest_stations else src.stations.duplicate()
	if use_latest_stations and _has_latest_items:
		_sync_items_into(target_state, latest_items)
	elif not use_latest_stations and src_has_items:
		_sync_items_into(target_state, src.items)


func _interpolate_states(target_state: GameState, state_a: GameState, state_b: GameState, t: float, use_latest_stations: bool, b_has_items: bool = false) -> void:
	target_state.tick = state_b.tick

	var boat_a := state_a.boat
	var boat_b := state_b.boat
	target_state.boat.world_position = boat_a.world_position.lerp(boat_b.world_position, t)
	target_state.boat.velocity = boat_a.velocity.lerp(boat_b.velocity, t)
	target_state.boat.heading = wrapf(lerp_angle(boat_a.heading, boat_b.heading, t), -PI, PI)
	target_state.boat.forward_speed = lerpf(boat_a.forward_speed, boat_b.forward_speed, t)
	target_state.boat.angular_velocity = lerpf(boat_a.angular_velocity, boat_b.angular_velocity, t)
	target_state.boat.throttle = lerpf(boat_a.throttle, boat_b.throttle, t)
	target_state.boat.steering_angle = lerpf(boat_a.steering_angle, boat_b.steering_angle, t)

	for existing_pid in target_state.players.keys():
		if not state_b.players.has(existing_pid):
			target_state.players.erase(existing_pid)

	for pid_key in state_b.players:
		var pid := int(pid_key)
		var pb: PlayerState = state_b.players[pid_key]
		var out_p := target_state.ensure_player(pid, pb.is_bot)
		out_p.peer_id = pid
		out_p.color_index = pb.color_index
		out_p.is_bot = pb.is_bot
		if state_a.players.has(pid):
			var pa: PlayerState = state_a.players[pid]
			out_p.local_position = pa.local_position.lerp(pb.local_position, t)
		else:
			out_p.local_position = pb.local_position

	target_state.stations = latest_stations.duplicate() if use_latest_stations else state_b.stations.duplicate()
	if use_latest_stations and _has_latest_items:
		_sync_items_into(target_state, latest_items)
	elif not use_latest_stations and b_has_items:
		_sync_items_into(target_state, state_b.items)


func _clone_items_dict(source_items: Dictionary) -> Dictionary:
	var cloned: Dictionary = {}
	for iid in source_items:
		var item: HeldItem = source_items[iid]
		if item != null:
			cloned[str(iid)] = item.clone()
	return cloned


func _sync_items_into(target_state: GameState, source_items: Dictionary) -> void:
	for existing_id in target_state.items.keys():
		if not source_items.has(existing_id):
			target_state.items.erase(existing_id)
	for iid in source_items:
		var src_item: HeldItem = source_items[iid]
		if src_item == null:
			continue
		if target_state.items.has(iid) and target_state.items[iid] is HeldItem:
			var dst: HeldItem = target_state.items[iid]
			dst.id = src_item.id
			dst.item_type = src_item.item_type
			dst.color_index = src_item.color_index
			dst.carrier_peer_id = src_item.carrier_peer_id
			dst.holder_id = src_item.holder_id
			dst.last_holder_id = src_item.last_holder_id
		else:
			target_state.items[str(iid)] = src_item.clone()


func _copy_boat_state(dst: BoatState, src: BoatState) -> void:
	dst.world_position = src.world_position
	dst.heading = src.heading
	dst.forward_speed = src.forward_speed
	dst.velocity = src.velocity
	dst.angular_velocity = src.angular_velocity
	dst.throttle = src.throttle
	dst.steering_angle = src.steering_angle


func _sync_players_from_single(target_state: GameState, src: GameState) -> void:
	for existing_pid in target_state.players.keys():
		if not src.players.has(existing_pid):
			target_state.players.erase(existing_pid)

	for pid_key in src.players:
		var pid := int(pid_key)
		var p_src: PlayerState = src.players[pid_key]
		var out_p := target_state.ensure_player(pid, p_src.is_bot)
		out_p.peer_id = pid
		out_p.local_position = p_src.local_position
		out_p.color_index = p_src.color_index
		out_p.is_bot = p_src.is_bot
