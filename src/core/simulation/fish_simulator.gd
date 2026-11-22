class_name FishSimulator
extends RefCounted
## Pure simulation step for trolling bites, species behavior, reel drag, jumps, and netless lifting.

const FIXED_DELTA: float = 1.0 / 60.0

const SPECIES_SPECS: Dictionary = {
	FishState.SPECIES_VENDACE: {
		"display_name": "Muikku",
		"weight_min": 0.03,
		"weight_max": 0.08,
		"spawn_weight": 24.0,
		"trips_planer": false,
		"can_jump": false,
		"jump_height": 0.0,
		"initial_stamina": 0.0,
		"stamina_drain_scale": 1.0,
		"base_pull": 0.12,
		"surge_pull": 0.25,
		"reel_speed": 6.2,
		"lift_escape_min": 0.05,
		"lift_escape_max": 0.12,
		"visual_length": 0.34,
		"visual_radius": 0.06,
		"is_whale": false,
	},
	FishState.SPECIES_PERCH: {
		"display_name": "Ahven",
		"weight_min": 0.30,
		"weight_max": 1.20,
		"spawn_weight": 30.0,
		"trips_planer": false,
		"can_jump": false,
		"jump_height": 0.0,
		"initial_stamina": 0.0,
		"stamina_drain_scale": 1.0,
		"base_pull": 0.35,
		"surge_pull": 0.55,
		"reel_speed": 5.4,
		"lift_escape_min": 0.15,
		"lift_escape_max": 0.32,
		"visual_length": 0.52,
		"visual_radius": 0.11,
		"is_whale": false,
	},
	FishState.SPECIES_ZANDER: {
		"display_name": "Kuha",
		"weight_min": 1.20,
		"weight_max": 4.50,
		"spawn_weight": 22.0,
		"trips_planer": true,
		"can_jump": false,
		"jump_height": 0.0,
		"initial_stamina": 0.75,
		"stamina_drain_scale": 1.1,
		"base_pull": 0.68,
		"surge_pull": 1.55,
		"reel_speed": 4.2,
		"lift_escape_min": 0.48,
		"lift_escape_max": 0.70,
		"visual_length": 0.85,
		"visual_radius": 0.16,
		"is_whale": false,
	},
	FishState.SPECIES_PIKE: {
		"display_name": "Hauki",
		"weight_min": 2.50,
		"weight_max": 12.0,
		"spawn_weight": 20.0,
		"trips_planer": true,
		"can_jump": true,
		"jump_height": 1.2,
		"initial_stamina": 1.0,
		"stamina_drain_scale": 1.0,
		"base_pull": 1.15,
		"surge_pull": 2.15,
		"reel_speed": 3.6,
		"lift_escape_min": 0.75,
		"lift_escape_max": 0.92,
		"visual_length": 1.25,
		"visual_radius": 0.20,
		"is_whale": false,
	},
	FishState.SPECIES_ORCA: {
		"display_name": "Miekkavalas",
		"weight_min": 3000.0,
		"weight_max": 5500.0,
		"spawn_weight": 3.0,
		"trips_planer": true,
		"can_jump": true,
		"jump_height": 2.6,
		"initial_stamina": 1.0,
		"stamina_drain_scale": 0.65,
		"base_pull": 1.65,
		"surge_pull": 2.80,
		"reel_speed": 2.8,
		"lift_escape_min": 0.96,
		"lift_escape_max": 0.985,
		"visual_length": 4.2,
		"visual_radius": 0.78,
		"is_whale": true,
	},
	FishState.SPECIES_BLUE_WHALE: {
		"display_name": "Sinivalas",
		"weight_min": 80000.0,
		"weight_max": 150000.0,
		"spawn_weight": 1.0,
		"trips_planer": true,
		"can_jump": true,
		"jump_height": 3.4,
		"initial_stamina": 1.0,
		"stamina_drain_scale": 0.50,
		"base_pull": 1.95,
		"surge_pull": 3.30,
		"reel_speed": 2.4,
		"lift_escape_min": 0.985,
		"lift_escape_max": 0.995,
		"visual_length": 8.4,
		"visual_radius": 1.45,
		"is_whale": true,
	},
}


class Config extends RefCounted:
	var base_bite_rate_per_rod: float = 0.018
	var min_bite_line_out: float = 5.0
	var min_bite_boat_speed: float = 0.8
	var drag_resistance: float = 1.0
	var drag_slip_scale: float = 1.0
	var max_drag_slip_speed: float = 2.0
	var grace_period_sec: float = 7.0
	var unattended_risk_delay_sec: float = 20.0
	var surge_duration_min: float = 1.2
	var surge_duration_max: float = 2.4
	var surge_cooldown_min: float = 2.0
	var surge_cooldown_max: float = 3.8
	var stamina_drain_reeling: float = 0.11
	var stamina_drain_passive: float = 0.015
	var shakeoff_chance_per_sec: float = 0.025
	var shakeoff_unattended_bonus: float = 0.04
	var jump_chance_on_surge: float = 0.75
	var jump_duration_sec: float = 1.1
	var auto_detach_distance: float = 2.0
	var surface_reveal_distance: float = 8.0
	var ready_to_land_distance: float = 1.5
	var lift_hold_duration: float = 1.2
	var lift_decay_rate: float = 1.5
	var ready_unattended_timeout_sec: float = 25.0


var config: Config = Config.new()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(custom_config: Config = null) -> void:
	if custom_config != null:
		config = custom_config
	_rng.seed = 42069


func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value


static func get_species_spec(species_id: String) -> Dictionary:
	if SPECIES_SPECS.has(species_id):
		return SPECIES_SPECS[species_id]
	return SPECIES_SPECS[FishState.SPECIES_PERCH]


static func get_species_display_name(species_id: String) -> String:
	return str(get_species_spec(species_id).get("display_name", "Kala"))


static func species_trips_planer(species_id: String) -> bool:
	return bool(get_species_spec(species_id).get("trips_planer", false))


static func format_weight(weight_kg: float) -> String:
	if weight_kg >= 100.0:
		return "%.0f kg" % weight_kg
	return "%.2f kg" % weight_kg


static func get_lift_escape_chance(fish: FishState) -> float:
	if fish == null:
		return 0.5
	var spec := get_species_spec(fish.species)
	var w_min := float(spec.get("weight_min", 0.3))
	var w_max := maxf(w_min + 0.001, float(spec.get("weight_max", 1.2)))
	var frac := clampf((fish.weight_kg - w_min) / (w_max - w_min), 0.0, 1.0)
	return clampf(lerpf(float(spec.get("lift_escape_min", 0.2)), float(spec.get("lift_escape_max", 0.5)), frac), 0.0, 1.0)


static func get_fish_jump_height_offset(fish: FishState) -> float:
	if fish == null or not fish.is_jumping():
		return 0.0
	var spec := get_species_spec(fish.species)
	if not bool(spec.get("can_jump", false)):
		return 0.0
	var max_h := float(spec.get("jump_height", 1.0))
	return sin(fish.jump_progress * PI) * max_h


func get_fish_distance(rod: RodState, rod_sim: RodSimulator = null) -> float:
	if rod == null or rod.planer == null:
		return 0.0
	var leader_len := rod_sim.config.leader_length if rod_sim != null else 6.0
	if rod.planer.attached:
		return rod.planer.line_out + leader_len
	return rod.planer.line_out


func get_fish_world_pos_2d(
	state: GameState,
	item: HeldItem,
	rod: RodState,
	_fish: FishState,
	rod_sim: RodSimulator = null
) -> Vector2:
	var helper := rod_sim if rod_sim != null else RodSimulator.new()
	return helper.get_lure_world_pos_2d(state, item, rod)


func force_bite(
	state: GameState,
	rod_sim: RodSimulator = null,
	preferred_rod_id: String = "",
	forced_species: String = ""
) -> FishState:
	if state == null:
		return null
	state.sync_rods_with_items()
	var target_rod_id := ""
	if not preferred_rod_id.is_empty():
		if state.rods.has(preferred_rod_id) and not state.has_fish_on_rod(preferred_rod_id):
			target_rod_id = preferred_rod_id
	else:
		var rod_ids: Array[String] = []
		for rid in state.rods.keys():
			rod_ids.append(str(rid))
		rod_ids.sort()
		var fallback_rid := ""
		for rid in rod_ids:
			if state.has_fish_on_rod(rid):
				continue
			var rod := state.get_rod_state(rid)
			if rod == null or not rod.is_deployed():
				continue
			if rod.planer.state == PlanerBoard.STATE_TANGLED or rod.planer.state == PlanerBoard.STATE_SNAGGED:
				continue
			if rod.planer.line_out >= config.min_bite_line_out:
				target_rod_id = rid
				break
			if fallback_rid.is_empty():
				fallback_rid = rid
		if target_rod_id.is_empty():
			target_rod_id = fallback_rid

	if target_rod_id.is_empty():
		return null
	return _spawn_fish_on_rod(state, target_rod_id, forced_species, rod_sim)


func step(state: GameState, inputs: Dictionary, rod_sim: RodSimulator = null, delta: float = FIXED_DELTA) -> void:
	if state == null:
		return
	var helper_rod_sim := rod_sim if rod_sim != null else RodSimulator.new()

	if state.fish_notice_timer > 0.0:
		state.fish_notice_timer = maxf(0.0, state.fish_notice_timer - delta)
		if state.fish_notice_timer <= 0.0:
			state.fish_notice_text = ""

	var fish_ids: Array[String] = []
	for fid in state.fishes.keys():
		fish_ids.append(str(fid))
	fish_ids.sort()

	for fid in fish_ids:
		var fish := state.get_fish_state(fid)
		var rod := state.get_rod_state(fid)
		var item := state.items.get(fid, null) as HeldItem
		if fish == null or rod == null or item == null or not rod.is_deployed():
			state.fishes.erase(fid)
			continue
		if fish.state == FishState.STATE_READY_TO_LAND:
			_step_ready_to_land(state, inputs, item, rod, fish, helper_rod_sim, delta)
		else:
			_step_hooked_fish(state, inputs, item, rod, fish, helper_rod_sim, delta)

	if state.boat.forward_speed >= config.min_bite_boat_speed:
		_roll_automatic_bites(state, helper_rod_sim, delta)


func _spawn_fish_on_rod(
	state: GameState,
	rod_id: String,
	forced_species: String,
	rod_sim: RodSimulator
) -> FishState:
	var rod := state.get_rod_state(rod_id)
	if rod == null:
		return null
	var sp := forced_species if FishState.VALID_SPECIES.has(forced_species) else _pick_random_species()
	var spec := get_species_spec(sp)

	var fish := FishState.new()
	fish.rod_id = rod_id
	fish.species = sp
	fish.weight_kg = _rng.randf_range(float(spec["weight_min"]), float(spec["weight_max"]))
	fish.state = FishState.STATE_HOOKED
	fish.stamina = float(spec["initial_stamina"])
	fish.fight_phase = _rng.randf_range(0.0, TAU)

	var trips := bool(spec["trips_planer"])
	if fish.stamina > 0.05:
		if trips and sp != FishState.SPECIES_ZANDER:
			fish.surge_timer = _rng.randf_range(0.9, 1.4)
			fish.surge_cooldown = _rng.randf_range(config.surge_cooldown_min, config.surge_cooldown_max)
			if bool(spec["can_jump"]) and _rng.randf() <= config.jump_chance_on_surge:
				fish.jump_progress = 0.002
		else:
			fish.surge_timer = 0.0
			fish.surge_cooldown = _rng.randf_range(0.8, 1.8)

	if rod.planer.attached and trips:
		rod.planer.state = PlanerBoard.STATE_TRIPPED

	fish.surfaced = get_fish_distance(rod, rod_sim) <= config.surface_reveal_distance
	state.fishes[rod_id] = fish
	return fish


func _pick_random_species() -> String:
	var total := 0.0
	for sp in FishState.VALID_SPECIES:
		total += float(get_species_spec(sp).get("spawn_weight", 1.0))
	var roll := _rng.randf_range(0.0, total)
	var accum := 0.0
	for sp in FishState.VALID_SPECIES:
		accum += float(get_species_spec(sp).get("spawn_weight", 1.0))
		if roll <= accum:
			return sp
	return FishState.SPECIES_PERCH


func _roll_automatic_bites(state: GameState, rod_sim: RodSimulator, delta: float) -> void:
	var rod_ids: Array[String] = []
	for rid in state.rods.keys():
		rod_ids.append(str(rid))
	rod_ids.sort()

	for rid in rod_ids:
		if state.has_fish_on_rod(rid):
			continue
		var rod := state.get_rod_state(rid)
		if rod == null or rod.planer.line_out < config.min_bite_line_out:
			continue
		if rod.planer.state == PlanerBoard.STATE_TANGLED or rod.planer.state == PlanerBoard.STATE_SNAGGED:
			continue
		var mult := rod_sim.get_bite_probability_multiplier(rod)
		var prob := 1.0 - exp(-config.base_bite_rate_per_rod * mult * delta)
		if _rng.randf() < prob:
			_spawn_fish_on_rod(state, rid, "", rod_sim)


func _step_hooked_fish(
	state: GameState,
	inputs: Dictionary,
	item: HeldItem,
	rod: RodState,
	fish: FishState,
	rod_sim: RodSimulator,
	delta: float
) -> void:
	var spec := get_species_spec(fish.species)
	var is_reeling := _is_player_reeling_rod(state, inputs, item)
	fish.hooked_time += delta
	fish.unattended_time = 0.0 if is_reeling else (fish.unattended_time + delta)

	var phase_speed := 10.0 if fish.surge_timer > 0.0 else (6.5 if fish.stamina > 0.05 else 3.5)
	fish.fight_phase = wrapf(fish.fight_phase + delta * phase_speed, 0.0, TAU)

	# Drain stamina faster while actively reeling; small species start exhausted (0.0)
	var drain_scale := float(spec.get("stamina_drain_scale", 1.0))
	var drain := (config.stamina_drain_reeling if is_reeling else config.stamina_drain_passive) * drain_scale
	fish.stamina = maxf(0.0, fish.stamina - drain * delta)

	# Update surges and breach jumps while fish still has stamina
	if fish.stamina > 0.05 and float(spec["initial_stamina"]) > 0.0:
		if fish.surge_timer > 0.0:
			fish.surge_timer = maxf(0.0, fish.surge_timer - delta)
		else:
			fish.surge_cooldown -= delta
			if fish.surge_cooldown <= 0.0:
				fish.surge_timer = _rng.randf_range(config.surge_duration_min, config.surge_duration_max)
				fish.surge_cooldown = _rng.randf_range(config.surge_cooldown_min, config.surge_cooldown_max)
				if bool(spec["can_jump"]) and fish.jump_progress <= 0.001 and _rng.randf() <= config.jump_chance_on_surge:
					fish.jump_progress = 0.002
	else:
		fish.surge_timer = 0.0

	if fish.jump_progress > 0.001:
		fish.jump_progress += delta / maxf(0.1, config.jump_duration_sec)
		if fish.jump_progress >= 1.0:
			fish.jump_progress = 0.0

	# Shake-off roll: never during grace period, never when exhausted (stamina <= 0.05)
	if fish.hooked_time >= config.grace_period_sec and fish.stamina > 0.05 and fish.surge_timer > 0.0:
		var hazard := config.shakeoff_chance_per_sec
		if fish.unattended_time >= config.unattended_risk_delay_sec:
			hazard += config.shakeoff_unattended_bonus
		var escape_prob := 1.0 - exp(-hazard * delta)
		if _rng.randf() < escape_prob:
			var label := "Kala" if not fish.surfaced else get_species_display_name(fish.species)
			state.set_fish_notice("%s irtosi koukusta kesken väsytyksen!" % label, 4.0)
			state.fishes.erase(fish.rod_id)
			if rod.planer.attached and rod.planer.state == PlanerBoard.STATE_TRIPPED:
				rod.planer.state = PlanerBoard.STATE_TROLLING if state.boat.forward_speed >= rod_sim.config.min_pull_speed else PlanerBoard.STATE_DEPLOYING
			return

	# Drag / räikkä calculation
	var stamina_factor := 0.35 + 0.65 * fish.stamina
	var raw_pull := lerpf(float(spec["base_pull"]), float(spec["surge_pull"]), 1.0 if fish.surge_timer > 0.0 else 0.0) * stamina_factor
	fish.drag_rate = clampf((raw_pull - config.drag_resistance) * config.drag_slip_scale, 0.0, config.max_drag_slip_speed)

	# Line adjustment: reeling in hand vs drag slip when not reeling
	var prev_line := rod.planer.line_out
	if is_reeling:
		var reel_speed := maxf(0.35, float(spec["reel_speed"]) - fish.drag_rate * 0.65)
		var next_line := maxf(0.0, prev_line - reel_speed * delta)
		rod.planer.line_out = next_line
		if prev_line > 0.001 and next_line > 0.001:
			rod.planer.lateral_offset *= (next_line / prev_line)
	elif fish.drag_rate > 0.001:
		rod.planer.line_out = minf(rod_sim.config.max_line_out, prev_line + fish.drag_rate * delta)

	# S9a automatic planer bypass at auto_detach_distance
	if rod.planer.attached and rod.planer.line_out <= config.auto_detach_distance:
		var dx := rod.planer.lateral_offset
		var dz := sqrt(maxf(0.01, rod.planer.line_out * rod.planer.line_out - dx * dx))
		rod.trail_angle = wrapf(atan2(dx, dz), -PI, PI)
		rod.planer.attached = false
		rod.planer.lateral_offset = 0.0
		rod.planer.line_out = rod.planer.line_out + rod_sim.config.leader_length
		rod.planer.state = PlanerBoard.STATE_TROLLING if state.boat.forward_speed >= rod_sim.config.min_pull_speed else PlanerBoard.STATE_DEPLOYING

	var dist := get_fish_distance(rod, rod_sim)
	if dist <= config.surface_reveal_distance:
		fish.surfaced = true

	if not rod.planer.attached and rod.planer.line_out <= config.ready_to_land_distance:
		rod.planer.line_out = config.ready_to_land_distance
		fish.state = FishState.STATE_READY_TO_LAND
		fish.surfaced = true
		fish.drag_rate = 0.0
		fish.surge_timer = 0.0
		fish.jump_progress = 0.0
		fish.lift_progress = 0.0


func _step_ready_to_land(
	state: GameState,
	inputs: Dictionary,
	item: HeldItem,
	rod: RodState,
	fish: FishState,
	rod_sim: RodSimulator,
	delta: float
) -> void:
	fish.surfaced = true
	fish.drag_rate = 0.0
	fish.surge_timer = 0.0
	fish.jump_progress = 0.0
	fish.fight_phase = wrapf(fish.fight_phase + delta * 5.0, 0.0, TAU)
	rod.planer.line_out = config.ready_to_land_distance

	var is_reeling := _is_player_reeling_rod(state, inputs, item)
	if is_reeling:
		fish.unattended_time = 0.0
		fish.lift_progress = minf(1.0, fish.lift_progress + delta / maxf(0.1, config.lift_hold_duration))
		if fish.lift_progress >= 1.0:
			var escape_chance := get_lift_escape_chance(fish)
			var sp_name := get_species_display_name(fish.species)
			var w_str := format_weight(fish.weight_kg)
			if _rng.randf() < escape_chance:
				state.set_fish_notice("%s (%s) karkasi nostossa ilman haavia!" % [sp_name, w_str], 5.0)
			else:
				state.set_fish_notice("Saalis! %s (%s) nostettu veneeseen!" % [sp_name, w_str], 5.0)
			_clear_fish_and_reset_rod(state, item, rod, rod_sim)
	else:
		fish.lift_progress = maxf(0.0, fish.lift_progress - config.lift_decay_rate * delta)
		if item == null or not item.is_carried():
			fish.unattended_time += delta
			if fish.unattended_time >= config.ready_unattended_timeout_sec:
				state.set_fish_notice("%s (%s) lipui tiehensä laidalta!" % [get_species_display_name(fish.species), format_weight(fish.weight_kg)], 4.5)
				state.fishes.erase(fish.rod_id)


func _clear_fish_and_reset_rod(state: GameState, item: HeldItem, rod: RodState, rod_sim: RodSimulator) -> void:
	state.fishes.erase(rod.rod_id)
	rod.planer.line_out = 0.0
	rod.planer.lateral_offset = 0.0
	rod.planer.state = PlanerBoard.STATE_STOWED
	rod.planer.snag_world_position = Vector2.ZERO
	rod.trail_factor = 0.0
	rod.trail_angle = 0.0
	if state.item_config != null and item != null:
		var hid := item.holder_id if not item.holder_id.is_empty() else item.last_holder_id
		if not hid.is_empty():
			var holder_cfg := state.item_config.get_holder(hid)
			if not holder_cfg.is_empty():
				rod.planer.attached = bool(holder_cfg.get("default_planer_attached", false))
	if rod_sim != null:
		state.sync_rods_with_items()


func _is_player_reeling_rod(state: GameState, inputs: Dictionary, item: HeldItem) -> bool:
	if item == null or not item.is_carried() or item.carrier_peer_id <= 0:
		return false
	var pid := item.carrier_peer_id
	if not state.players.has(pid):
		return false
	var player: PlayerState = state.players[pid]
	if player.is_bot or state.is_player_at_station(pid):
		return false
	var raw_input: Variant = _get_player_input(inputs, pid)
	return _get_line_input(raw_input) < -0.1


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
