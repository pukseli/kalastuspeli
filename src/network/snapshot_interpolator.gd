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

var item_config: ItemConfig = null
var render_time: float = 0.0
var current_delay: float = MIN_INTERP_DELAY
var measured_interval: float = 3.0 * FIXED_DELTA
var latest_stations: Dictionary = StationConfig.create_default_stations()
var latest_items: Dictionary = {}
var latest_rods: Dictionary = {}
var latest_fishes: Dictionary = {}
var latest_catches: Array = []
var latest_catch_count: int = 0
var latest_biggest_catch_kg: float = 0.0
var latest_fish_notice_seq: int = 0
var latest_fish_notice_text: String = ""
var latest_fish_notice_timer: float = 0.0

var _buffer: Array[Dictionary] = []
var _has_snapshot: bool = false
var _last_tick: int = -1
var _has_latest_items: bool = false
var _has_latest_rods: bool = false
var _has_latest_fishes: bool = false


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
	latest_rods.clear()
	_has_latest_rods = false
	latest_fishes.clear()
	_has_latest_fishes = false
	latest_catches.clear()
	latest_catch_count = 0
	latest_biggest_catch_kg = 0.0
	latest_fish_notice_seq = 0
	latest_fish_notice_text = ""
	latest_fish_notice_timer = 0.0


## Returns the number of snapshots currently buffered.
func get_buffer_size() -> int:
	return _buffer.size()


## Returns the tick of the newest accepted snapshot, or -1 if empty.
func get_latest_tick() -> int:
	return _last_tick


## Returns the most recently parsed GameState in the buffer, or null if empty.
func get_latest_state() -> GameState:
	if _buffer.is_empty():
		return null
	return _buffer[_buffer.size() - 1]["state"] as GameState


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

	var parsed := GameState.new(false)
	if item_config != null:
		parsed.item_config = item_config
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
	var has_rods := snapshot.has("rods") and snapshot["rods"] is Dictionary
	if has_rods:
		latest_rods = _clone_rods_dict(parsed.rods)
		_has_latest_rods = true
	var has_fishes := snapshot.has("fishes") and snapshot["fishes"] is Dictionary
	if has_fishes:
		latest_fishes = _clone_fishes_dict(parsed.fishes)
		_has_latest_fishes = true
	if snapshot.has("catches") and snapshot["catches"] is Array:
		latest_catches = _clone_catches_array(parsed.catches)
	latest_catch_count = parsed.catch_count
	latest_biggest_catch_kg = parsed.biggest_catch_kg
	latest_fish_notice_seq = parsed.fish_notice_seq
	latest_fish_notice_text = parsed.fish_notice_text
	latest_fish_notice_timer = parsed.fish_notice_timer
	_buffer.append({
		"tick": tick,
		"time": sim_time,
		"state": parsed,
		"has_items": has_items,
		"has_rods": has_rods,
		"has_fishes": has_fishes,
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
		_copy_state_into(
			target_state,
			_buffer[0]["state"],
			use_latest_stations,
			bool(_buffer[0].get("has_items", false)),
			bool(_buffer[0].get("has_rods", false)),
			bool(_buffer[0].get("has_fishes", false))
		)
		return true

	if sample_time >= float(_buffer[last_idx]["time"]):
		_copy_state_into(
			target_state,
			_buffer[last_idx]["state"],
			use_latest_stations,
			bool(_buffer[last_idx].get("has_items", false)),
			bool(_buffer[last_idx].get("has_rods", false)),
			bool(_buffer[last_idx].get("has_fishes", false))
		)
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
	_interpolate_states(
		target_state,
		state_a,
		state_b,
		t,
		use_latest_stations,
		bool(entry_b.get("has_items", false)),
		bool(entry_b.get("has_rods", false)),
		bool(entry_b.get("has_fishes", false))
	)
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


func _copy_state_into(target_state: GameState, src: GameState, use_latest_stations: bool, src_has_items: bool = false, src_has_rods: bool = false, src_has_fishes: bool = false) -> void:
	target_state.tick = src.tick
	_copy_boat_state(target_state.boat, src.boat)
	_sync_players_from_single(target_state, src)
	target_state.stations = latest_stations.duplicate() if use_latest_stations else src.stations.duplicate()
	if use_latest_stations and _has_latest_items:
		_sync_items_into(target_state, latest_items)
	elif not use_latest_stations and src_has_items:
		_sync_items_into(target_state, src.items)
	if use_latest_stations and _has_latest_rods:
		_sync_rods_into(target_state, latest_rods)
	elif not use_latest_stations and src_has_rods:
		_sync_rods_into(target_state, src.rods)
	if use_latest_stations and _has_latest_fishes:
		_sync_fishes_into(target_state, latest_fishes)
	elif not use_latest_stations and src_has_fishes:
		_sync_fishes_into(target_state, src.fishes)
	var src_catches: Array = latest_catches if use_latest_stations else src.catches
	var src_count: int = latest_catch_count if use_latest_stations else src.catch_count
	var src_biggest: float = latest_biggest_catch_kg if use_latest_stations else src.biggest_catch_kg
	_sync_catches_into(target_state, src_catches, src_count, src_biggest)
	target_state.fish_notice_seq = latest_fish_notice_seq if use_latest_stations else src.fish_notice_seq
	target_state.fish_notice_text = latest_fish_notice_text if use_latest_stations else src.fish_notice_text
	target_state.fish_notice_timer = latest_fish_notice_timer if use_latest_stations else src.fish_notice_timer


func _interpolate_states(target_state: GameState, state_a: GameState, state_b: GameState, t: float, use_latest_stations: bool, b_has_items: bool = false, b_has_rods: bool = false, b_has_fishes: bool = false) -> void:
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

	if (use_latest_stations and _has_latest_rods) or b_has_rods:
		var disc_source: Dictionary = latest_rods if (use_latest_stations and _has_latest_rods) else state_b.rods
		_interpolate_rods_into(target_state, state_a.rods, state_b.rods, disc_source, t)

	if (use_latest_stations and _has_latest_fishes) or b_has_fishes:
		var disc_fishes: Dictionary = latest_fishes if (use_latest_stations and _has_latest_fishes) else state_b.fishes
		_interpolate_fishes_into(target_state, state_a.fishes, state_b.fishes, disc_fishes, t)
	var src_catches: Array = latest_catches if use_latest_stations else state_b.catches
	var src_count: int = latest_catch_count if use_latest_stations else state_b.catch_count
	var src_biggest: float = latest_biggest_catch_kg if use_latest_stations else state_b.biggest_catch_kg
	_sync_catches_into(target_state, src_catches, src_count, src_biggest)
	target_state.fish_notice_seq = latest_fish_notice_seq if use_latest_stations else state_b.fish_notice_seq
	target_state.fish_notice_text = latest_fish_notice_text if use_latest_stations else state_b.fish_notice_text
	target_state.fish_notice_timer = latest_fish_notice_timer if use_latest_stations else state_b.fish_notice_timer


func _clone_rods_dict(source_rods: Dictionary) -> Dictionary:
	var cloned: Dictionary = {}
	for rid in source_rods:
		var rod: RodState = source_rods[rid]
		if rod != null:
			cloned[str(rid)] = rod.clone()
	return cloned


func _sync_rods_into(target_state: GameState, source_rods: Dictionary) -> void:
	for existing_rid in target_state.rods.keys():
		if not source_rods.has(existing_rid):
			target_state.rods.erase(existing_rid)
	for rid in source_rods:
		var src_rod: RodState = source_rods[rid]
		if src_rod == null:
			continue
		if target_state.rods.has(rid) and target_state.rods[rid] is RodState:
			var dst: RodState = target_state.rods[rid]
			dst.rod_id = src_rod.rod_id
			dst.trail_angle = src_rod.trail_angle
			dst.trail_factor = src_rod.trail_factor
			if dst.planer == null:
				dst.planer = PlanerBoard.new()
			if src_rod.planer != null:
				dst.planer.copy_from(src_rod.planer)
		else:
			target_state.rods[str(rid)] = src_rod.clone()


func _interpolate_rods_into(
	target_state: GameState,
	rods_a: Dictionary,
	rods_b: Dictionary,
	discrete_source: Dictionary,
	t: float
) -> void:
	for existing_rid in target_state.rods.keys():
		if not rods_b.has(existing_rid) and not discrete_source.has(existing_rid):
			target_state.rods.erase(existing_rid)

	var keys_to_sync: Dictionary = {}
	for rid in rods_b:
		keys_to_sync[str(rid)] = true
	for rid in discrete_source:
		keys_to_sync[str(rid)] = true

	for rid in keys_to_sync:
		var rb := rods_b.get(rid, null) as RodState
		var ra := rods_a.get(rid, null) as RodState
		var rdisc := discrete_source.get(rid, rb) as RodState
		if rb == null and rdisc == null:
			continue
		var dst: RodState
		if target_state.rods.has(rid) and target_state.rods[rid] is RodState:
			dst = target_state.rods[rid] as RodState
		else:
			dst = RodState.new()
			target_state.rods[rid] = dst
		if dst.planer == null:
			dst.planer = PlanerBoard.new()
		dst.rod_id = rid

		if rb != null and ra != null:
			dst.trail_angle = wrapf(lerp_angle(ra.trail_angle, rb.trail_angle, t), -PI, PI)
			dst.trail_factor = lerpf(ra.trail_factor, rb.trail_factor, t)
			dst.planer.line_out = lerpf(ra.planer.line_out, rb.planer.line_out, t)
			dst.planer.lateral_offset = lerpf(ra.planer.lateral_offset, rb.planer.lateral_offset, t)
			dst.planer.pull_back_offset = lerpf(ra.planer.pull_back_offset, rb.planer.pull_back_offset, t)
			dst.planer.submersion = lerpf(ra.planer.submersion, rb.planer.submersion, t)
			dst.planer.flag_angle = lerpf(ra.planer.flag_angle, rb.planer.flag_angle, t)
			dst.planer.shake_intensity = lerpf(ra.planer.shake_intensity, rb.planer.shake_intensity, t)
			dst.planer.inward_drift_force = lerpf(ra.planer.inward_drift_force, rb.planer.inward_drift_force, t)
		elif rb != null:
			dst.trail_angle = rb.trail_angle
			dst.trail_factor = rb.trail_factor
			dst.planer.line_out = rb.planer.line_out
			dst.planer.lateral_offset = rb.planer.lateral_offset
			dst.planer.pull_back_offset = rb.planer.pull_back_offset
			dst.planer.submersion = rb.planer.submersion
			dst.planer.flag_angle = rb.planer.flag_angle
			dst.planer.shake_intensity = rb.planer.shake_intensity
			dst.planer.inward_drift_force = rb.planer.inward_drift_force
		elif rdisc != null:
			dst.trail_angle = rdisc.trail_angle
			dst.trail_factor = rdisc.trail_factor
			dst.planer.line_out = rdisc.planer.line_out
			dst.planer.lateral_offset = rdisc.planer.lateral_offset
			dst.planer.pull_back_offset = rdisc.planer.pull_back_offset
			dst.planer.submersion = rdisc.planer.submersion
			dst.planer.flag_angle = rdisc.planer.flag_angle
			dst.planer.shake_intensity = rdisc.planer.shake_intensity
			dst.planer.inward_drift_force = rdisc.planer.inward_drift_force

		var disc_src := rdisc if rdisc != null else rb
		if disc_src != null and disc_src.planer != null:
			dst.planer.side = disc_src.planer.side
			dst.planer.attached = disc_src.planer.attached
			dst.planer.state = disc_src.planer.state
			dst.planer.snag_world_position = disc_src.planer.snag_world_position


func _clone_fishes_dict(source_fishes: Dictionary) -> Dictionary:
	var cloned: Dictionary = {}
	for fid in source_fishes:
		var fish: FishState = source_fishes[fid]
		if fish != null:
			cloned[str(fid)] = fish.clone()
	return cloned


func _sync_fishes_into(target_state: GameState, source_fishes: Dictionary) -> void:
	for existing_fid in target_state.fishes.keys():
		if not source_fishes.has(existing_fid):
			target_state.fishes.erase(existing_fid)
	for fid in source_fishes:
		var src_fish: FishState = source_fishes[fid]
		if src_fish == null:
			continue
		if target_state.fishes.has(fid) and target_state.fishes[fid] is FishState:
			var dst: FishState = target_state.fishes[fid]
			dst.copy_from(src_fish)
			dst.rod_id = str(fid)
		else:
			var copy := src_fish.clone()
			copy.rod_id = str(fid)
			target_state.fishes[str(fid)] = copy


func _interpolate_fishes_into(
	target_state: GameState,
	fishes_a: Dictionary,
	fishes_b: Dictionary,
	discrete_source: Dictionary,
	t: float
) -> void:
	for existing_fid in target_state.fishes.keys():
		if not discrete_source.has(existing_fid):
			target_state.fishes.erase(existing_fid)

	for raw_fid in discrete_source:
		var fid := str(raw_fid)
		var fdisc := discrete_source.get(fid, null) as FishState
		if fdisc == null:
			continue
		var fa := fishes_a.get(fid, null) as FishState
		var fb := fishes_b.get(fid, null) as FishState

		var dst: FishState
		if target_state.fishes.has(fid) and target_state.fishes[fid] is FishState:
			dst = target_state.fishes[fid] as FishState
		else:
			dst = FishState.new()
			target_state.fishes[fid] = dst

		dst.copy_from(fdisc)
		dst.rod_id = fid

		if fa != null and fb != null:
			dst.stamina = lerpf(fa.stamina, fb.stamina, t)
			dst.drag_rate = lerpf(fa.drag_rate, fb.drag_rate, t)
			dst.lift_progress = lerpf(fa.lift_progress, fb.lift_progress, t)
			dst.scoop_progress = lerpf(fa.scoop_progress, fb.scoop_progress, t)
			dst.detach_progress = lerpf(fa.detach_progress, fb.detach_progress, t)
			dst.fight_phase = wrapf(lerp_angle(fa.fight_phase, fb.fight_phase, t), 0.0, TAU)
			if fb.jump_progress >= fa.jump_progress:
				dst.jump_progress = lerpf(fa.jump_progress, fb.jump_progress, t)
			else:
				dst.jump_progress = fb.jump_progress
		elif fb != null:
			dst.stamina = fb.stamina
			dst.drag_rate = fb.drag_rate
			dst.lift_progress = fb.lift_progress
			dst.scoop_progress = fb.scoop_progress
			dst.detach_progress = fb.detach_progress
			dst.fight_phase = fb.fight_phase
			dst.jump_progress = fb.jump_progress


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
			dst.copy_from(src_item)
		else:
			target_state.items[str(iid)] = src_item.clone()


func _sync_catches_into(target_state: GameState, src_catches: Array, src_count: int, src_biggest: float) -> void:
	if target_state.catch_count != src_count or target_state.catches.size() != src_catches.size() or (src_count == 0 and not target_state.catches.is_empty()):
		target_state.catches = _clone_catches_array(src_catches)
	target_state.catch_count = src_count
	target_state.biggest_catch_kg = src_biggest


func _clone_catches_array(source_catches: Array) -> Array:
	var cloned: Array = []
	for entry in source_catches:
		if entry is Dictionary:
			cloned.append((entry as Dictionary).duplicate())
	return cloned


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
