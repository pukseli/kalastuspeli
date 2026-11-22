class_name RodSimulator
extends RefCounted
## Pure simulation step for trolling lines, straight-line angular lag, planer boards, tangles, and obstacle snags.

const FIXED_DELTA: float = 1.0 / 60.0
const HELD_TIP_ANCHOR_POS := Vector3(0.30, 0.78, 0.12)
const HELD_TIP_ANCHOR_ROT_DEG := Vector3(-42.0, 0.0, -10.0)
const HELD_TIP_LOCAL_OFFSET := Vector3(0.0, 1.225, 0.0)
const RESTING_TIP_LOCAL_OFFSET := Vector3(0.0, 1.69, 0.0)

class Config extends RefCounted:
	var line_adjust_speed: float = 8.0
	var max_line_out: float = 35.0
	var leader_length: float = 6.0
	var max_lateral_offset: float = 22.0
	var max_spread_angle_deg: float = 55.0
	var min_pull_speed: float = 0.8
	var optimal_pull_speed: float = 3.0
	var spread_rate: float = 3.0
	var collapse_rate: float = 1.6
	var stall_collapse_gain: float = 1.2
	var tripped_pull_factor: float = 0.15
	var board_tangle_distance: float = 1.5
	var hull_tangle_margin: float = 1.2
	var sharp_turn_omega: float = 0.45
	var board_collision_radius: float = 0.45
	var lure_collision_radius: float = 0.25
	var detach_distance: float = 2.0
	var quiet_water_offset: float = 4.0
	var quiet_water_bite_bonus: float = 1.2
	var min_stopped_trail_factor: float = 0.35
	var full_straighten_speed: float = 2.0
	var trail_factor_rate: float = 1.5
	var straight_align_gain: float = 2.4
	var min_eff_length_for_lag: float = 4.0
	var reel_pull_factor: float = 0.45
	var reel_inward_rate: float = 4.0

var config: Config = Config.new()


func _init(custom_config: Config = null) -> void:
	if custom_config != null:
		config = custom_config


func _get_player_input(inputs: Dictionary, pid: int) -> Variant:
	if inputs.has(pid):
		return inputs[pid]
	var str_pid := str(pid)
	if inputs.has(str_pid):
		return inputs[str_pid]
	return null


func _get_line_input(raw_input: Variant) -> float:
	if raw_input is PlayerInput:
		return clampf((raw_input as PlayerInput).line_input, -1.0, 1.0)
	if raw_input is Dictionary:
		return clampf(float((raw_input as Dictionary).get("line_input", 0.0)), -1.0, 1.0)
	return 0.0


func _get_rod_holder_cfg(state: GameState, item: HeldItem) -> Dictionary:
	if state == null or state.item_config == null or item == null:
		return {}
	var hid := item.holder_id if not item.holder_id.is_empty() else item.last_holder_id
	if hid.is_empty():
		return {}
	return state.item_config.get_holder(hid)


func step(state: GameState, inputs: Dictionary, delta: float = FIXED_DELTA, obstacles: Array = []) -> void:
	if state == null:
		return
	state.sync_rods_with_items()
	var reeling_rods := _process_line_inputs(state, inputs, delta)

	var prev_board_pos: Dictionary = {}
	var prev_abs_lat: Dictionary = {}
	var rod_ids: Array[String] = []
	for rid in state.rods.keys():
		rod_ids.append(str(rid))
	rod_ids.sort()

	for rid in rod_ids:
		var item := state.items.get(rid, null) as HeldItem
		var rod := state.get_rod_state(rid)
		if item == null or rod == null:
			continue
		if rod.planer.attached and rod.planer.is_active_trolling():
			prev_board_pos[rid] = get_board_world_pos_2d(state, item, rod)
			prev_abs_lat[rid] = absf(rod.planer.lateral_offset)

	for rid in rod_ids:
		var item := state.items.get(rid, null) as HeldItem
		var rod := state.get_rod_state(rid)
		if item == null or rod == null:
			continue
		_step_single_rod(state, item, rod, delta, reeling_rods.has(rid))

	_check_planer_tangles(state, rod_ids, prev_board_pos, prev_abs_lat, reeling_rods)
	if not obstacles.is_empty():
		_check_obstacles(state, rod_ids, obstacles)


func _process_line_inputs(state: GameState, inputs: Dictionary, delta: float) -> Dictionary:
	var active_cfg: ItemConfig = state.item_config
	var pids: Array[int] = []
	for pid_raw in inputs.keys():
		var pid := int(pid_raw)
		if pid != 0 and not pids.has(pid):
			pids.append(pid)
	pids.sort()

	var touched_rods: Dictionary = {}
	var reeling_rods: Dictionary = {}

	for pid in pids:
		if not state.players.has(pid):
			continue
		var player: PlayerState = state.players[pid]
		if player.is_bot or state.is_player_at_station(pid):
			continue

		var line_in := _get_line_input(_get_player_input(inputs, pid))
		if absf(line_in) < 0.001:
			continue

		var target_item: HeldItem = null
		var held := state.get_player_held_item(pid)
		if held != null:
			if held.item_type == ItemConfig.ITEM_TYPE_ROD:
				target_item = held
		elif active_cfg != null:
			var best_dist := INF
			for holder in active_cfg.holders:
				var hid := str(holder.get("id", ""))
				if hid.is_empty():
					continue
				var existing := state.get_holder_item(hid)
				if existing == null or existing.item_type != ItemConfig.ITEM_TYPE_ROD:
					continue
				var pos: Vector3 = holder.get("local_position", Vector3.ZERO)
				var radius := float(holder.get("radius", ItemConfig.DEFAULT_HOLDER_RADIUS))
				var dx := player.local_position.x - pos.x
				var dz := player.local_position.z - pos.z
				var dist := sqrt(dx * dx + dz * dz)
				if dist <= radius and dist < best_dist:
					best_dist = dist
					target_item = existing

		if target_item == null or touched_rods.has(target_item.id):
			continue
		var rod := state.get_rod_state(target_item.id)
		if rod == null:
			continue
		touched_rods[target_item.id] = true

		if rod.planer.state == PlanerBoard.STATE_TANGLED or rod.planer.state == PlanerBoard.STATE_SNAGGED:
			if line_in > 0.0:
				continue

		var prev_line := rod.planer.line_out
		var next_line := clampf(prev_line + line_in * config.line_adjust_speed * delta, 0.0, config.max_line_out)
		rod.planer.line_out = next_line
		if next_line > 0.001 and next_line < prev_line and prev_line > 0.001:
			rod.planer.lateral_offset *= (next_line / prev_line)
			reeling_rods[target_item.id] = true

		if next_line <= 0.001:
			rod.planer.line_out = 0.0
			rod.planer.lateral_offset = 0.0
			rod.planer.state = PlanerBoard.STATE_STOWED
			rod.planer.snag_world_position = Vector2.ZERO
			rod.trail_factor = 0.0
			rod.trail_angle = 0.0
		elif prev_line <= 0.001:
			rod.trail_factor = maxf(rod.trail_factor, config.min_stopped_trail_factor)
			if rod.planer.state == PlanerBoard.STATE_STOWED:
				rod.planer.state = PlanerBoard.STATE_DEPLOYING

	return reeling_rods


func _step_single_rod(state: GameState, item: HeldItem, rod: RodState, delta: float, is_reeling: bool = false) -> void:
	var holder_cfg := _get_rod_holder_cfg(state, item)
	if not item.is_carried() and not holder_cfg.is_empty():
		rod.planer.side = PlanerBoard.SIDE_LEFT if int(holder_cfg.get("side", 1)) < 0 else PlanerBoard.SIDE_RIGHT

	var spread_deg := float(holder_cfg.get("spread_angle_deg", float(rod.planer.side) * 20.0))

	if rod.planer.line_out <= 0.001:
		rod.planer.line_out = 0.0
		rod.planer.lateral_offset = 0.0
		rod.planer.state = PlanerBoard.STATE_STOWED
		rod.trail_factor = 0.0
		rod.trail_angle = 0.0
		if not item.is_carried() and not holder_cfg.is_empty():
			rod.planer.attached = bool(holder_cfg.get("default_planer_attached", false))
		return

	if rod.trail_factor <= 0.001:
		rod.trail_factor = config.min_stopped_trail_factor
	var speed_ratio := clampf(maxf(0.0, state.boat.forward_speed) / maxf(0.01, config.full_straighten_speed), 0.0, 1.0)
	var target_factor := lerpf(config.min_stopped_trail_factor, 1.0, speed_ratio)
	rod.trail_factor = move_toward(rod.trail_factor, target_factor, config.trail_factor_rate * delta)

	if rod.planer.attached:
		if rod.planer.state == PlanerBoard.STATE_TANGLED or rod.planer.state == PlanerBoard.STATE_SNAGGED:
			return
		var l_max_hard := minf(config.max_lateral_offset, rod.planer.line_out * sin(deg_to_rad(config.max_spread_angle_deg)))
		rod.planer.lateral_offset = clampf(rod.planer.lateral_offset, -l_max_hard, l_max_hard)
		var tip_local := get_rod_tip_local(state, item)
		var board_x := tip_local.x + rod.planer.lateral_offset
		var v_board := state.boat.forward_speed + state.boat.angular_velocity * board_x
		if v_board >= config.min_pull_speed:
			var p_base := clampf(
				(v_board - config.min_pull_speed) / maxf(0.01, config.optimal_pull_speed - config.min_pull_speed),
				0.0,
				1.0
			)
			var pull := p_base * config.tripped_pull_factor if rod.planer.state == PlanerBoard.STATE_TRIPPED else p_base
			if is_reeling:
				pull *= config.reel_pull_factor
			var rod_max_angle_deg := minf(config.max_spread_angle_deg, absf(spread_deg))
			var l_max := minf(config.max_lateral_offset, rod.planer.line_out * sin(deg_to_rad(rod_max_angle_deg)))
			var x_target := float(rod.planer.side) * pull * l_max
			var max_sin := maxf(0.01, sin(deg_to_rad(config.max_spread_angle_deg)))
			var angle_ratio := clampf(sin(deg_to_rad(rod_max_angle_deg)) / max_sin, 0.45, 1.0)
			var step_rate := config.spread_rate * maxf(pull, 0.25) * angle_ratio
			if is_reeling and absf(x_target) < absf(rod.planer.lateral_offset):
				step_rate = maxf(step_rate, config.reel_inward_rate)
			rod.planer.lateral_offset = move_toward(rod.planer.lateral_offset, x_target, step_rate * delta)
			if rod.planer.state != PlanerBoard.STATE_TRIPPED:
				if not is_reeling and absf(rod.planer.lateral_offset - x_target) < 0.25 and pull > 0.0:
					rod.planer.state = PlanerBoard.STATE_TROLLING
				else:
					rod.planer.state = PlanerBoard.STATE_DEPLOYING
		else:
			var collapse_v := config.collapse_rate + (config.min_pull_speed - v_board) * config.stall_collapse_gain
			if is_reeling:
				collapse_v = maxf(collapse_v, config.reel_inward_rate)
			rod.planer.lateral_offset = move_toward(rod.planer.lateral_offset, 0.0, collapse_v * delta)
			if rod.planer.state != PlanerBoard.STATE_TRIPPED:
				rod.planer.state = PlanerBoard.STATE_DEPLOYING
		rod.planer.lateral_offset = clampf(rod.planer.lateral_offset, -l_max_hard, l_max_hard)
		var leader_eff_len := maxf(config.min_eff_length_for_lag, config.leader_length * maxf(rod.trail_factor, config.min_stopped_trail_factor))
		var leader_align_rate := (maxf(0.0, v_board) * config.straight_align_gain) / leader_eff_len
		rod.trail_angle = wrapf(rod.trail_angle - state.boat.angular_velocity * delta, -PI, PI)
		rod.trail_angle = wrapf(lerp_angle(rod.trail_angle, 0.0, clampf(leader_align_rate * delta, 0.0, 1.0)), -PI, PI)
	else:
		if rod.planer.state == PlanerBoard.STATE_TANGLED or rod.planer.state == PlanerBoard.STATE_SNAGGED:
			return
		var target_angle := deg_to_rad(spread_deg)
		var eff_len := maxf(config.min_eff_length_for_lag, rod.planer.line_out * maxf(rod.trail_factor, config.min_stopped_trail_factor))
		var align_rate := (maxf(0.0, state.boat.forward_speed) * config.straight_align_gain) / eff_len
		rod.trail_angle = wrapf(rod.trail_angle - state.boat.angular_velocity * delta, -PI, PI)
		rod.trail_angle = wrapf(lerp_angle(rod.trail_angle, target_angle, clampf(align_rate * delta, 0.0, 1.0)), -PI, PI)
		rod.planer.lateral_offset = 0.0
		rod.planer.state = PlanerBoard.STATE_TROLLING if state.boat.forward_speed >= config.min_pull_speed else PlanerBoard.STATE_DEPLOYING


func _check_planer_tangles(
	state: GameState,
	rod_ids: Array[String],
	prev_board_pos: Dictionary,
	prev_abs_lat: Dictionary,
	reeling_rods: Dictionary = {}
) -> void:
	var active_entries: Array[Dictionary] = []
	var omega := state.boat.angular_velocity
	var sharp_turn := absf(omega) >= config.sharp_turn_omega

	for rid in rod_ids:
		var item := state.items.get(rid, null) as HeldItem
		var rod := state.get_rod_state(rid)
		if item == null or rod == null:
			continue
		if not rod.planer.attached or not rod.planer.is_active_trolling():
			continue
		if rod.planer.line_out <= config.detach_distance:
			continue

		var tip_local := get_rod_tip_local(state, item)
		var board_x := tip_local.x + rod.planer.lateral_offset
		var v_board := state.boat.forward_speed + omega * board_x
		var had_spread := float(prev_abs_lat.get(rid, 0.0)) >= config.hull_tangle_margin
		if sharp_turn and v_board < config.min_pull_speed and absf(rod.planer.lateral_offset) < config.hull_tangle_margin and had_spread and not reeling_rods.has(rid):
			rod.planer.state = PlanerBoard.STATE_TANGLED
			continue

		var tip_3d := get_rod_tip_world(state, item)
		active_entries.append({
			"rid": rid,
			"rod": rod,
			"tip": Vector2(tip_3d.x, tip_3d.z),
			"pos": get_board_world_pos_2d(state, item, rod),
			"prev_abs_lat": float(prev_abs_lat.get(rid, absf(rod.planer.lateral_offset))),
		})

	for i in range(active_entries.size()):
		for j in range(i + 1, active_entries.size()):
			var a := active_entries[i]
			var b := active_entries[j]
			var rod_a := a["rod"] as RodState
			var rod_b := b["rod"] as RodState
			var pos_a := a["pos"] as Vector2
			var pos_b := b["pos"] as Vector2
			var tip_a := a["tip"] as Vector2
			var tip_b := b["tip"] as Vector2

			var crosses := false
			if sharp_turn and absf(rod_a.planer.lateral_offset) >= 1.5 and absf(rod_b.planer.lateral_offset) >= 1.5:
				crosses = Geometry2D.segment_intersects_segment(tip_a, pos_a, tip_b, pos_b) != null

			var dist := pos_a.distance_to(pos_b)
			var rid_a := str(a["rid"])
			var rid_b := str(b["rid"])
			var approaching := false
			if prev_board_pos.has(rid_a) and prev_board_pos.has(rid_b):
				var prev_dist := (prev_board_pos[rid_a] as Vector2).distance_to(prev_board_pos[rid_b] as Vector2)
				approaching = dist < prev_dist - 0.0001

			var both_trolling := (
				rod_a.planer.state == PlanerBoard.STATE_TROLLING
				and rod_b.planer.state == PlanerBoard.STATE_TROLLING
			)
			var either_spread := (
				absf(rod_a.planer.lateral_offset) >= config.hull_tangle_margin
				or absf(rod_b.planer.lateral_offset) >= config.hull_tangle_margin
				or float(a["prev_abs_lat"]) >= config.hull_tangle_margin
				or float(b["prev_abs_lat"]) >= config.hull_tangle_margin
			)
			var hit_by_turn := sharp_turn and either_spread and (dist <= config.board_tangle_distance or crosses)
			var hit_by_approach := both_trolling and dist <= config.board_tangle_distance and approaching
			if hit_by_turn or hit_by_approach:
				rod_a.planer.state = PlanerBoard.STATE_TANGLED
				rod_b.planer.state = PlanerBoard.STATE_TANGLED


func _check_obstacles(state: GameState, rod_ids: Array[String], obstacles: Array) -> void:
	for rid in rod_ids:
		var item := state.items.get(rid, null) as HeldItem
		var rod := state.get_rod_state(rid)
		if item == null or rod == null or not rod.is_deployed():
			continue
		if rod.planer.state == PlanerBoard.STATE_SNAGGED:
			continue

		var board_pos := get_board_world_pos_2d(state, item, rod)
		var lure_pos := get_lure_world_pos_2d(state, item, rod)

		for raw_obs in obstacles:
			if not (raw_obs is Dictionary):
				continue
			var obs := raw_obs as Dictionary
			var raw_pos: Variant = obs.get("position", Vector2.ZERO)
			var obs_pos := Vector2.ZERO
			if raw_pos is Vector2:
				obs_pos = raw_pos as Vector2
			elif raw_pos is Vector3:
				var p3 := raw_pos as Vector3
				obs_pos = Vector2(p3.x, p3.z)
			else:
				continue
			var obs_radius := maxf(0.0, float(obs.get("radius", 0.0)))

			var hit_board := rod.planer.attached and board_pos.distance_to(obs_pos) <= obs_radius + config.board_collision_radius
			var hit_lure := lure_pos.distance_to(obs_pos) <= obs_radius + config.lure_collision_radius
			if hit_board or hit_lure:
				rod.planer.state = PlanerBoard.STATE_SNAGGED
				rod.planer.snag_world_position = board_pos if rod.planer.attached else lure_pos
				break


func get_rod_tip_local(state: GameState, item: HeldItem) -> Vector3:
	if item == null:
		return Vector3(0.0, 1.8, 3.0)
	if item.is_carried() and state != null and state.players.has(item.carrier_peer_id):
		var player: PlayerState = state.players[item.carrier_peer_id]
		var rot_rad := Vector3(
			deg_to_rad(HELD_TIP_ANCHOR_ROT_DEG.x),
			deg_to_rad(HELD_TIP_ANCHOR_ROT_DEG.y),
			deg_to_rad(HELD_TIP_ANCHOR_ROT_DEG.z)
		)
		var anchor_basis := Basis.from_euler(rot_rad)
		return player.local_position + HELD_TIP_ANCHOR_POS + anchor_basis * HELD_TIP_LOCAL_OFFSET

	var holder_cfg := _get_rod_holder_cfg(state, item)
	if not holder_cfg.is_empty():
		var h_pos: Vector3 = holder_cfg.get("local_position", Vector3.ZERO)
		var tilt: Vector3 = holder_cfg.get("tilt_degrees", Vector3.ZERO)
		var tilt_rad := Vector3(deg_to_rad(tilt.x), deg_to_rad(tilt.y), deg_to_rad(tilt.z))
		var holder_basis := Basis.from_euler(tilt_rad)
		return h_pos + holder_basis * RESTING_TIP_LOCAL_OFFSET
	return Vector3(0.0, 1.8, 3.0)


func get_rod_tip_world(state: GameState, item: HeldItem) -> Vector3:
	var tip_local := get_rod_tip_local(state, item)
	if state == null:
		return tip_local
	return state.boat.world_position + tip_local.rotated(Vector3.UP, state.boat.heading)


func get_board_local_pos_2d(state: GameState, item: HeldItem, rod: RodState) -> Vector2:
	if rod == null:
		return Vector2.ZERO
	var tip_local := get_rod_tip_local(state, item)
	var eff_factor := maxf(rod.trail_factor, config.min_stopped_trail_factor) if rod.is_deployed() else 0.0
	var eff_out := rod.planer.line_out * eff_factor
	var max_dx := eff_out * sin(deg_to_rad(config.max_spread_angle_deg))
	var dx := clampf(rod.planer.lateral_offset * eff_factor, -max_dx, max_dx)
	var trail_z := sqrt(maxf(0.0, eff_out * eff_out - dx * dx))
	var bx := tip_local.x + dx
	var bz := tip_local.z + trail_z
	if item != null and item.is_carried() and rod.is_deployed() and absf(bx) < 1.9 and bz < 3.8:
		bx = float(rod.planer.side) * 2.0
	return Vector2(bx, bz)


func get_board_world_pos_2d(state: GameState, item: HeldItem, rod: RodState) -> Vector2:
	if rod != null and rod.planer.state == PlanerBoard.STATE_SNAGGED:
		return rod.planer.snag_world_position
	var local_2d := get_board_local_pos_2d(state, item, rod)
	if state == null:
		return local_2d
	var rotated := Vector3(local_2d.x, 0.0, local_2d.y).rotated(Vector3.UP, state.boat.heading)
	return Vector2(state.boat.world_position.x + rotated.x, state.boat.world_position.z + rotated.z)


func get_lure_world_pos_2d(state: GameState, item: HeldItem, rod: RodState) -> Vector2:
	if rod == null or state == null:
		return Vector2.ZERO
	if rod.planer.attached:
		var board_world := get_board_world_pos_2d(state, item, rod)
		var eff_factor := maxf(rod.trail_factor, config.min_stopped_trail_factor) if rod.is_deployed() else 0.0
		var leader_eff := config.leader_length * eff_factor
		var leader_local := Vector3(sin(rod.trail_angle) * leader_eff, 0.0, cos(rod.trail_angle) * leader_eff)
		var leader_world := leader_local.rotated(Vector3.UP, state.boat.heading)
		return board_world + Vector2(leader_world.x, leader_world.z)
	var tip_local := get_rod_tip_local(state, item)
	var dist := rod.planer.line_out * rod.trail_factor
	var lure_local := Vector3(
		tip_local.x + sin(rod.trail_angle) * dist,
		0.0,
		tip_local.z + cos(rod.trail_angle) * dist
	)
	var lure_world := state.boat.world_position + lure_local.rotated(Vector3.UP, state.boat.heading)
	return Vector2(lure_world.x, lure_world.z)


func get_bite_probability_multiplier(rod: RodState) -> float:
	if rod == null or rod.planer == null:
		return 1.0
	if not rod.planer.attached or rod.planer.state != PlanerBoard.STATE_TROLLING:
		return 1.0
	if absf(rod.planer.lateral_offset) >= config.quiet_water_offset:
		return config.quiet_water_bite_bonus
	return 1.0
