class_name FishSimulator
extends RefCounted
## Pure simulation step for trolling bites, species behavior, reel drag, jumps, and netless lifting.

const FIXED_DELTA: float = 1.0 / 60.0
const DEFAULT_DETACH_DISTANCE: float = 2.0
const DEFAULT_DETACH_WINDOW_DISTANCE: float = 3.5
const DEFAULT_DETACH_HOLD_DURATION: float = 0.8
const DEFAULT_DETACH_DECAY_RATE: float = 1.5
const DEFAULT_COOP_DETACH_RADIUS: float = 1.6
const DEFAULT_SCOOP_RADIUS: float = 1.6
const DEFAULT_SCOOP_HOLD_DURATION: float = 0.4
const DEFAULT_SCOOP_DECAY_RATE: float = 1.8
const DEFAULT_SCOOP_TIRED_STAMINA: float = 0.1
const DEFAULT_SCOOP_FAIL_BOLT_LINE: float = 5.0
const EXHAUSTED_STAMINA: float = FishState.EXHAUSTED_STAMINA

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
		"weight_min": 0.25,
		"weight_max": 0.95,
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

const STRIKE_REACTION_PROFILES: Dictionary = {
	FishState.SIZE_SMALL: {
		"trips_planer": false,
		"pull_back_rest": 0.35,
		"pull_back_burst": 0.80,
		"submersion_rest": 0.0,
		"submersion_burst": 0.0,
		"flag_angle_rest": -12.0,
		"flag_angle_burst": -30.0,
		"shake_rest": 0.08,
		"shake_burst": 0.22,
		"inward_drift_rest": 0.0,
		"inward_drift_burst": 0.0,
		"can_drift_tangle": false,
	},
	FishState.SIZE_MEDIUM: {
		"trips_planer": true,
		"pull_back_rest": 1.60,
		"pull_back_burst": 2.80,
		"submersion_rest": 0.0,
		"submersion_burst": 0.12,
		"flag_angle_rest": -62.0,
		"flag_angle_burst": -70.0,
		"shake_rest": 0.22,
		"shake_burst": 0.55,
		"inward_drift_rest": 0.35,
		"inward_drift_burst": 0.75,
		"can_drift_tangle": false,
	},
	FishState.SIZE_LARGE: {
		"trips_planer": true,
		"pull_back_rest": 3.20,
		"pull_back_burst": 5.20,
		"submersion_rest": 0.30,
		"submersion_burst": 0.80,
		"flag_angle_rest": -68.0,
		"flag_angle_burst": -75.0,
		"shake_rest": 0.35,
		"shake_burst": 0.80,
		"inward_drift_rest": 1.35,
		"inward_drift_burst": 2.60,
		"can_drift_tangle": true,
	},
	FishState.SIZE_MONSTER: {
		"trips_planer": true,
		"pull_back_rest": 5.00,
		"pull_back_burst": 7.50,
		"submersion_rest": 0.82,
		"submersion_burst": 1.00,
		"flag_angle_rest": -75.0,
		"flag_angle_burst": -78.0,
		"shake_rest": 0.50,
		"shake_burst": 1.00,
		"inward_drift_rest": 2.40,
		"inward_drift_burst": 4.20,
		"can_drift_tangle": true,
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
	var fatigue_min_work_tension: float = 15.0
	var fatigue_tension_ref: float = 75.0
	var stamina_drain_surge_drag: float = 0.13
	var stamina_drain_reeling: float = 0.11
	var stamina_drain_passive: float = 0.015
	var stamina_drain_passive_held: float = 0.025
	var stamina_drain_holder_slip: float = 0.030
	var stamina_recovery_rate: float = 0.06
	var rhythm_gain_yield: float = 0.35
	var rhythm_gain_reel: float = 0.30
	var rhythm_penalty_panic: float = 0.80
	var rhythm_decay_idle: float = 0.25
	var rhythm_decay_holder: float = 0.35
	var rhythm_decay_slack: float = 0.45
	var rhythm_drain_bonus_max: float = 1.65
	var panic_reel_drain_mult: float = 0.50
	var panic_reel_shakeoff_bonus: float = 0.03
	var shakeoff_chance_per_sec: float = 0.025
	var shakeoff_unattended_bonus: float = 0.04
	var jump_chance_on_surge: float = 0.75
	var jump_duration_sec: float = 1.1
	var detach_distance: float = DEFAULT_DETACH_DISTANCE
	var detach_window_distance: float = DEFAULT_DETACH_WINDOW_DISTANCE
	var detach_hold_duration: float = DEFAULT_DETACH_HOLD_DURATION
	var detach_decay_rate: float = DEFAULT_DETACH_DECAY_RATE
	var coop_detach_radius: float = DEFAULT_COOP_DETACH_RADIUS
	var surface_reveal_distance: float = 8.0
	var ready_to_land_distance: float = 1.5
	var lift_hold_duration: float = 1.2
	var lift_decay_rate: float = 1.5
	var scoop_radius: float = DEFAULT_SCOOP_RADIUS
	var scoop_hold_duration: float = DEFAULT_SCOOP_HOLD_DURATION
	var scoop_decay_rate: float = DEFAULT_SCOOP_DECAY_RATE
	var scoop_tired_stamina: float = DEFAULT_SCOOP_TIRED_STAMINA
	var scoop_fail_bolt_line: float = DEFAULT_SCOOP_FAIL_BOLT_LINE
	var ready_unattended_timeout_sec: float = 25.0
	var small_max_kg: float = 1.0
	var medium_max_kg: float = 4.0
	var large_max_kg: float = 8.0
	var reaction_pull_back_rate: float = 12.0
	var reaction_submersion_rate: float = 4.0
	var reaction_flag_rate: float = 240.0
	var reaction_shake_rate: float = 6.0
	var reaction_drift_rate: float = 8.0


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


static func get_strike_reaction_profile(size_class: String) -> Dictionary:
	if STRIKE_REACTION_PROFILES.has(size_class):
		return STRIKE_REACTION_PROFILES[size_class]
	return STRIKE_REACTION_PROFILES[FishState.SIZE_SMALL]


static func get_fatigue_drain_scale(species_id: String, weight_kg: float) -> float:
	var spec := get_species_spec(species_id)
	var base_scale := float(spec.get("stamina_drain_scale", 1.0))
	var w_min := float(spec.get("weight_min", 0.3))
	var w_max := maxf(w_min + 0.001, float(spec.get("weight_max", 1.2)))
	var weight_frac := clampf((weight_kg - w_min) / (w_max - w_min), 0.0, 1.0)
	return base_scale * lerpf(1.15, 0.80, weight_frac)


func compute_size_class(weight_kg: float) -> String:
	return FishState.compute_size_class(weight_kg, config.small_max_kg, config.medium_max_kg, config.large_max_kg)


static func is_rod_ready_for_planer_detach(
	rod: RodState,
	fish: FishState,
	detach_window_distance: float = DEFAULT_DETACH_WINDOW_DISTANCE
) -> bool:
	if rod == null or rod.planer == null or fish == null:
		return false
	return (
		fish.state == FishState.STATE_HOOKED
		and rod.planer.attached
		and rod.planer.state != PlanerBoard.STATE_TANGLED
		and rod.planer.state != PlanerBoard.STATE_SNAGGED
		and rod.planer.line_out <= detach_window_distance + 0.001
	)


static func find_detach_target_for_player(
	state: GameState,
	peer_id: int,
	detach_window_distance: float = DEFAULT_DETACH_WINDOW_DISTANCE,
	coop_radius: float = DEFAULT_COOP_DETACH_RADIUS
) -> Dictionary:
	if state == null or peer_id == 0 or not state.players.has(peer_id):
		return {}
	var player: PlayerState = state.players[peer_id]
	if player.is_bot or state.is_player_at_station(peer_id) or state.is_player_holding_item(peer_id):
		return {}

	var fish_ids: Array[String] = []
	for fid in state.fishes.keys():
		fish_ids.append(str(fid))
	fish_ids.sort()

	var best_rid := ""
	var best_mode := ""
	var best_dist := INF

	for rid in fish_ids:
		var fish := state.get_fish_state(rid)
		var rod := state.get_rod_state(rid)
		var item := state.items.get(rid, null) as HeldItem
		if item == null or not is_rod_ready_for_planer_detach(rod, fish, detach_window_distance):
			continue
		if not item.is_carried() and not item.holder_id.is_empty() and state.item_config != null:
			var holder := state.item_config.get_holder(item.holder_id)
			if holder.is_empty():
				continue
			var pos: Vector3 = holder.get("local_position", Vector3.ZERO)
			var radius := float(holder.get("radius", ItemConfig.DEFAULT_HOLDER_RADIUS))
			var dx := player.local_position.x - pos.x
			var dz := player.local_position.z - pos.z
			var dist := sqrt(dx * dx + dz * dz)
			if dist <= radius and dist < best_dist:
				best_dist = dist
				best_rid = rid
				best_mode = "holder"
		elif item.is_carried() and item.carrier_peer_id != peer_id and state.players.has(item.carrier_peer_id):
			var carrier: PlayerState = state.players[item.carrier_peer_id]
			var dx := player.local_position.x - carrier.local_position.x
			var dz := player.local_position.z - carrier.local_position.z
			var dist := sqrt(dx * dx + dz * dz)
			if dist <= coop_radius and dist < best_dist:
				best_dist = dist
				best_rid = rid
				best_mode = "coop"

	if best_rid.is_empty():
		return {}
	return {"rod_id": best_rid, "mode": best_mode, "distance": best_dist}


static func find_scoop_target_for_player(
	state: GameState,
	peer_id: int,
	scoop_radius: float = DEFAULT_SCOOP_RADIUS
) -> Dictionary:
	if state == null or peer_id == 0 or not state.players.has(peer_id):
		return {}
	var player: PlayerState = state.players[peer_id]
	if player.is_bot or state.is_player_at_station(peer_id):
		return {}
	var held := state.get_player_held_item(peer_id)
	if held == null or held.item_type != ItemConfig.ITEM_TYPE_NET:
		return {}

	var fish_ids: Array[String] = []
	for fid in state.fishes.keys():
		fish_ids.append(str(fid))
	fish_ids.sort()

	var best_rid := ""
	var best_mode := ""
	var best_dist := INF

	for rid in fish_ids:
		var fish := state.get_fish_state(rid)
		var item := state.items.get(rid, null) as HeldItem
		if fish == null or item == null or not fish.is_ready_to_land():
			continue
		if not item.is_carried() and not item.holder_id.is_empty() and state.item_config != null:
			var holder := state.item_config.get_holder(item.holder_id)
			if holder.is_empty():
				continue
			var pos: Vector3 = holder.get("local_position", Vector3.ZERO)
			var dx := player.local_position.x - pos.x
			var dz := player.local_position.z - pos.z
			var dist := sqrt(dx * dx + dz * dz)
			if dist <= scoop_radius and dist < best_dist:
				best_dist = dist
				best_rid = rid
				best_mode = "holder"
		elif item.is_carried() and item.carrier_peer_id != peer_id and state.players.has(item.carrier_peer_id):
			var carrier: PlayerState = state.players[item.carrier_peer_id]
			var dx := player.local_position.x - carrier.local_position.x
			var dz := player.local_position.z - carrier.local_position.z
			var dist := sqrt(dx * dx + dz * dz)
			if dist <= scoop_radius and dist < best_dist:
				best_dist = dist
				best_rid = rid
				best_mode = "coop"

	if best_rid.is_empty():
		return {}
	return {"rod_id": best_rid, "mode": best_mode, "distance": best_dist}


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
	forced_species: String = "",
	forced_weight_kg: float = -1.0
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
	return _spawn_fish_on_rod(state, target_rod_id, forced_species, rod_sim, forced_weight_kg)


func step(state: GameState, inputs: Dictionary, rod_sim: RodSimulator = null, delta: float = FIXED_DELTA) -> void:
	if state == null:
		return
	var helper_rod_sim := rod_sim if rod_sim != null else RodSimulator.new()

	if state.fish_notice_timer > 0.0:
		state.fish_notice_timer = maxf(0.0, state.fish_notice_timer - delta)
		if state.fish_notice_timer <= 0.0:
			state.fish_notice_text = ""

	var scooping_rods := _collect_scooping_rods(state, inputs)
	var detaching_rods := _collect_detaching_rods(state, inputs)

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
			_step_ready_to_land(state, inputs, item, rod, fish, helper_rod_sim, delta, scooping_rods.has(fid))
		else:
			_step_hooked_fish(state, inputs, item, rod, fish, helper_rod_sim, delta, detaching_rods.has(fid))

	if state.boat.forward_speed >= config.min_bite_boat_speed:
		_roll_automatic_bites(state, helper_rod_sim, delta)


func _spawn_fish_on_rod(
	state: GameState,
	rod_id: String,
	forced_species: String,
	rod_sim: RodSimulator,
	forced_weight_kg: float = -1.0
) -> FishState:
	var rod := state.get_rod_state(rod_id)
	if rod == null:
		return null
	var sp := forced_species if FishState.VALID_SPECIES.has(forced_species) else _pick_random_species()
	var spec := get_species_spec(sp)

	var fish := FishState.new()
	fish.rod_id = rod_id
	fish.species = sp
	fish.weight_kg = maxf(0.01, forced_weight_kg) if forced_weight_kg > 0.0 else _rng.randf_range(float(spec["weight_min"]), float(spec["weight_max"]))
	fish.size_class = compute_size_class(fish.weight_kg)
	fish.state = FishState.STATE_HOOKED
	fish.stamina = float(spec["initial_stamina"])
	fish.fight_phase = _rng.randf_range(0.0, TAU)

	var profile := get_strike_reaction_profile(fish.size_class)
	var trips := bool(profile.get("trips_planer", false))
	if not fish.is_exhausted():
		if trips and sp != FishState.SPECIES_ZANDER:
			fish.surge_timer = _rng.randf_range(0.9, 1.4)
			fish.surge_cooldown = _rng.randf_range(config.surge_cooldown_min, config.surge_cooldown_max)
			if bool(spec["can_jump"]) and _rng.randf() <= config.jump_chance_on_surge:
				fish.jump_progress = 0.002
		else:
			fish.surge_timer = 0.0
			fish.surge_cooldown = _rng.randf_range(0.8, 1.8)

	if rod.planer.attached:
		if trips:
			rod.planer.state = PlanerBoard.STATE_TRIPPED
		var init_intensity := 0.90 if (fish.size_class == FishState.SIZE_MONSTER or fish.surge_timer > 0.0) else 0.35
		rod.planer.pull_back_offset = lerpf(float(profile["pull_back_rest"]), float(profile["pull_back_burst"]), init_intensity)
		rod.planer.submersion = lerpf(float(profile["submersion_rest"]), float(profile["submersion_burst"]), init_intensity)
		rod.planer.flag_angle = lerpf(float(profile["flag_angle_rest"]), float(profile["flag_angle_burst"]), init_intensity)
		rod.planer.shake_intensity = lerpf(float(profile["shake_rest"]), float(profile["shake_burst"]), init_intensity)
		rod.planer.inward_drift_force = lerpf(float(profile["inward_drift_rest"]), float(profile["inward_drift_burst"]), init_intensity)
	else:
		rod.planer.reset_strike_reaction()

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
	delta: float,
	has_detacher: bool = false
) -> void:
	var spec := get_species_spec(fish.species)
	var is_reeling := _is_player_reeling_rod(state, inputs, item)
	var ready_for_detach := is_rod_ready_for_planer_detach(rod, fish, config.detach_window_distance)
	var is_detaching := ready_for_detach and has_detacher
	fish.hooked_time += delta
	fish.unattended_time = 0.0 if (is_reeling or is_detaching) else (fish.unattended_time + delta)

	var phase_speed := 10.0 if fish.surge_timer > 0.0 else (6.5 if not fish.is_exhausted() else 3.5)
	fish.fight_phase = wrapf(fish.fight_phase + delta * phase_speed, 0.0, TAU)

	# Update surges and breach jumps while fish still has stamina; surge timing scales with remaining stamina
	if not fish.is_exhausted() and float(spec["initial_stamina"]) > 0.0:
		if fish.surge_timer > 0.0:
			fish.surge_timer = maxf(0.0, fish.surge_timer - delta)
		else:
			fish.surge_cooldown -= delta
			if fish.surge_cooldown <= 0.0:
				var stamina_t := clampf(fish.stamina, 0.0, 1.0)
				var dur_scale := lerpf(0.55, 1.15, stamina_t)
				var cd_scale := lerpf(1.65, 0.85, stamina_t)
				fish.surge_timer = _rng.randf_range(config.surge_duration_min, config.surge_duration_max) * dur_scale
				fish.surge_cooldown = _rng.randf_range(config.surge_cooldown_min, config.surge_cooldown_max) * cd_scale
				if bool(spec["can_jump"]) and fish.jump_progress <= 0.001 and _rng.randf() <= config.jump_chance_on_surge:
					fish.jump_progress = 0.002
	else:
		fish.surge_timer = 0.0

	if fish.jump_progress > 0.001:
		fish.jump_progress += delta / maxf(0.1, config.jump_duration_sec)
		if fish.jump_progress >= 1.0:
			fish.jump_progress = 0.0

	# Update strike reaction and line physics (shared tension, drag slip, abrasion, snap)
	_update_planer_strike_reaction(rod, fish, delta)

	var stamina_factor := 0.35 + 0.65 * fish.stamina
	var raw_pull := lerpf(float(spec["base_pull"]), float(spec["surge_pull"]), 1.0 if fish.surge_timer > 0.0 else 0.0) * stamina_factor
	var fish_pull_n := raw_pull * LinePhysics.FISH_PULL_TO_NEWTONS
	var phys := LinePhysics.step_rod_line(
		state,
		item,
		rod,
		rod_sim,
		delta,
		fish_pull_n,
		is_reeling,
		is_detaching,
		config.max_drag_slip_speed
	)
	if bool(phys["snapped"]):
		return
	fish.drag_rate = float(phys["slip_speed"])
	_step_fish_fatigue(item, rod, fish, spec, is_reeling, is_detaching, delta)

	# Shake-off roll: never during grace period, never when exhausted (stamina <= EXHAUSTED_STAMINA)
	var is_slack := rod.line_tension < LinePhysics.SLACK_TENSION_THRESHOLD and not is_detaching
	if fish.hooked_time >= config.grace_period_sec and not fish.is_exhausted() and (fish.surge_timer > 0.0 or is_slack):
		var hazard := 0.0
		if fish.surge_timer > 0.0:
			hazard += config.shakeoff_chance_per_sec
			if is_reeling and rod.is_drag_slipping:
				hazard += config.panic_reel_shakeoff_bonus
			if fish.unattended_time >= config.unattended_risk_delay_sec:
				hazard += config.shakeoff_unattended_bonus
		if is_slack:
			hazard += LinePhysics.SLACK_ESCAPE_HAZARD
		var escape_prob := 1.0 - exp(-hazard * delta)
		if _rng.randf() < escape_prob:
			var label := "Kala" if not fish.surfaced else get_species_display_name(fish.species)
			if is_slack and fish.surge_timer <= 0.0:
				state.set_fish_notice("%s irtosi löysästä siimasta!" % label, 4.0)
			else:
				state.set_fish_notice("%s irtosi koukusta kesken väsytyksen!" % label, 4.0)
			state.fishes.erase(fish.rod_id)
			rod.planer.reset_strike_reaction()
			rod.is_drag_slipping = false
			if rod.planer.attached and rod.planer.state == PlanerBoard.STATE_TRIPPED:
				rod.planer.state = PlanerBoard.STATE_TROLLING if state.boat.forward_speed >= rod_sim.config.min_pull_speed else PlanerBoard.STATE_DEPLOYING
			return

	# Realistic reel clutch: reeling is blocked while fish+water exceeds drag_setting
	var prev_line := rod.planer.line_out
	if is_reeling and not rod.is_drag_slipping:
		var f_ext := float(phys["external_load"])
		var drag_margin := clampf((rod.drag_setting - f_ext) / maxf(1.0, rod.drag_setting), 0.0, 1.0)
		var reel_speed := float(spec["reel_speed"]) * lerpf(0.60, 1.0, drag_margin)
		var next_line := maxf(0.0, prev_line - reel_speed * delta)
		if rod.planer.attached and next_line < config.detach_distance:
			next_line = minf(prev_line, config.detach_distance)
		var reeled := maxf(0.0, prev_line - next_line)
		rod.planer.line_out = next_line
		rod.line_remaining_on_spool = minf(RodState.DEFAULT_SPOOL_CAPACITY, rod.line_remaining_on_spool + reeled)
		if prev_line > 0.001 and next_line > 0.001:
			rod.planer.lateral_offset *= (next_line / prev_line)

	# S9b manual planer detach lock (hold E in holder or by empty-handed co-op teammate)
	ready_for_detach = is_rod_ready_for_planer_detach(rod, fish, config.detach_window_distance)
	if ready_for_detach and is_detaching:
		fish.detach_progress = minf(1.0, fish.detach_progress + delta / maxf(0.1, config.detach_hold_duration))
		if fish.detach_progress >= 1.0:
			_complete_planer_detach(state, rod, fish, rod_sim)
	else:
		fish.detach_progress = maxf(0.0, fish.detach_progress - config.detach_decay_rate * delta)

	var dist := get_fish_distance(rod, rod_sim)
	if dist <= config.surface_reveal_distance + 0.01:
		fish.surfaced = true

	if not rod.planer.attached and rod.planer.line_out <= config.ready_to_land_distance:
		rod.planer.line_out = config.ready_to_land_distance
		fish.state = FishState.STATE_READY_TO_LAND
		fish.surfaced = true
		fish.drag_rate = 0.0
		fish.surge_timer = 0.0
		fish.jump_progress = 0.0
		fish.lift_progress = 0.0
		fish.fight_rhythm = 0.0


func _step_fish_fatigue(
	item: HeldItem,
	rod: RodState,
	fish: FishState,
	spec: Dictionary,
	is_reeling: bool,
	is_detaching: bool,
	delta: float
) -> void:
	if float(spec.get("initial_stamina", 0.0)) <= 0.0:
		fish.stamina = 0.0
		fish.fight_rhythm = 0.0
		fish.surge_timer = 0.0
		return
	if fish.is_exhausted():
		fish.fight_rhythm = 0.0
		fish.surge_timer = 0.0
		return
	if is_detaching:
		return

	var tension := rod.line_tension
	var min_work := maxf(0.1, config.fatigue_min_work_tension)
	if tension < min_work:
		fish.fight_rhythm = maxf(0.0, fish.fight_rhythm - config.rhythm_decay_slack * delta)
		var slack_frac := clampf((min_work - tension) / min_work, 0.0, 1.0)
		var max_stamina := float(spec.get("initial_stamina", 1.0))
		fish.stamina = minf(max_stamina, fish.stamina + config.stamina_recovery_rate * slack_frac * delta)
		return

	var tension_span := maxf(1.0, config.fatigue_tension_ref - min_work)
	var tension_work := clampf((tension - min_work) / tension_span, 0.0, 1.35)
	var eff_scale := get_fatigue_drain_scale(fish.species, fish.weight_kg)
	var is_carried := item != null and item.is_carried()
	var is_slipping := rod.is_drag_slipping
	var is_surging := fish.surge_timer > 0.0

	var drain := 0.0
	if is_reeling and is_slipping:
		# Panicked reeling against slipping drag breaks fight rhythm and halves fatigue efficiency
		fish.fight_rhythm = maxf(0.0, fish.fight_rhythm - config.rhythm_penalty_panic * delta)
		drain = config.stamina_drain_surge_drag * tension_work * config.panic_reel_drain_mult
	elif is_carried and not is_reeling and (is_slipping or is_surging):
		fish.fight_rhythm = minf(1.0, fish.fight_rhythm + config.rhythm_gain_yield * delta)
		var rhythm_mult := lerpf(1.0, config.rhythm_drain_bonus_max, fish.fight_rhythm)
		drain = config.stamina_drain_surge_drag * tension_work * rhythm_mult
	elif is_reeling and not is_slipping:
		fish.fight_rhythm = minf(1.0, fish.fight_rhythm + config.rhythm_gain_reel * delta)
		var rhythm_mult := lerpf(1.0, config.rhythm_drain_bonus_max, fish.fight_rhythm)
		drain = config.stamina_drain_reeling * maxf(0.35, tension_work) * rhythm_mult
	elif is_carried:
		fish.fight_rhythm = maxf(0.0, fish.fight_rhythm - config.rhythm_decay_idle * delta)
		drain = config.stamina_drain_passive_held * tension_work
	else:
		fish.fight_rhythm = maxf(0.0, fish.fight_rhythm - config.rhythm_decay_holder * delta)
		var holder_rate := config.stamina_drain_holder_slip if is_slipping else config.stamina_drain_passive
		drain = holder_rate * tension_work

	fish.stamina = maxf(0.0, fish.stamina - drain * eff_scale * delta)
	if fish.is_exhausted():
		fish.fight_rhythm = 0.0
		fish.surge_timer = 0.0


func _collect_scooping_rods(state: GameState, inputs: Dictionary) -> Dictionary:
	var scooping: Dictionary = {}
	var pids: Array[int] = []
	for pid_raw in inputs.keys():
		var pid := int(pid_raw)
		if pid != 0 and not pids.has(pid):
			pids.append(pid)
	pids.sort()
	for pid in pids:
		if _get_line_input(_get_player_input(inputs, pid)) >= -0.1:
			continue
		var target := find_scoop_target_for_player(state, pid, config.scoop_radius)
		if not target.is_empty():
			var rid := str(target["rod_id"])
			if not scooping.has(rid):
				scooping[rid] = pid
	return scooping


func _step_ready_to_land(
	state: GameState,
	inputs: Dictionary,
	item: HeldItem,
	rod: RodState,
	fish: FishState,
	rod_sim: RodSimulator,
	delta: float,
	is_scooping: bool = false
) -> void:
	fish.surfaced = true
	fish.drag_rate = 0.0
	fish.surge_timer = 0.0
	fish.jump_progress = 0.0
	fish.detach_progress = 0.0
	fish.fight_rhythm = 0.0
	rod.is_drag_slipping = false
	rod.line_tension = LinePhysics.compute_water_drag(state.boat.forward_speed, rod)
	var thrash_speed := lerpf(2.2, 11.0, clampf(fish.stamina, 0.0, 1.0))
	fish.fight_phase = wrapf(fish.fight_phase + delta * thrash_speed, 0.0, TAU)
	rod.planer.line_out = config.ready_to_land_distance
	rod.planer.reset_strike_reaction()

	if is_scooping:
		fish.unattended_time = 0.0
		fish.scoop_progress = minf(1.0, fish.scoop_progress + delta / maxf(0.05, config.scoop_hold_duration))
		if fish.scoop_progress >= 1.0:
			var fail_chance := 0.0
			if fish.stamina > config.scoop_tired_stamina:
				var fresh_t := clampf(
					(fish.stamina - config.scoop_tired_stamina) / maxf(0.01, 1.0 - config.scoop_tired_stamina),
					0.0,
					1.0
				)
				fail_chance = lerpf(0.15, 0.85, fresh_t)
			if fail_chance > 0.0 and _rng.randf() < fail_chance:
				fish.state = FishState.STATE_HOOKED
				fish.scoop_progress = 0.0
				fish.lift_progress = 0.0
				fish.surge_timer = 1.2
				fish.unattended_time = 0.0
				rod.planer.line_out = minf(rod_sim.config.max_line_out, rod.planer.line_out + config.scoop_fail_bolt_line)
				state.set_fish_notice("%s säikähti haavia ja syöksyi takaisin!" % get_species_display_name(fish.species), 3.5)
				return
			state.record_catch(fish.species, fish.weight_kg, fish.size_class, "net")
			state.set_fish_notice(
				"Saalis! %s (%s) haavittu veneeseen!" % [get_species_display_name(fish.species), format_weight(fish.weight_kg)],
				5.0
			)
			_clear_fish_and_reset_rod(state, item, rod, rod_sim)
			return
	else:
		fish.scoop_progress = maxf(0.0, fish.scoop_progress - config.scoop_decay_rate * delta)

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
				state.record_catch(fish.species, fish.weight_kg, fish.size_class, "hand_lift")
				state.set_fish_notice("Saalis! %s (%s) nostettu veneeseen!" % [sp_name, w_str], 5.0)
			_clear_fish_and_reset_rod(state, item, rod, rod_sim)
	else:
		fish.lift_progress = maxf(0.0, fish.lift_progress - config.lift_decay_rate * delta)
		if not is_scooping and (item == null or not item.is_carried()):
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
	rod.planer.reset_strike_reaction()
	rod.trail_factor = 0.0
	rod.trail_angle = 0.0
	rod.reset_line_condition()
	if state.item_config != null and item != null:
		var hid := item.holder_id if not item.holder_id.is_empty() else item.last_holder_id
		if not hid.is_empty():
			var holder_cfg := state.item_config.get_holder(hid)
			if not holder_cfg.is_empty():
				rod.planer.attached = bool(holder_cfg.get("default_planer_attached", false))
	if rod_sim != null:
		state.sync_rods_with_items()


func _update_planer_strike_reaction(rod: RodState, fish: FishState, delta: float) -> void:
	if rod == null or rod.planer == null or fish == null:
		return
	fish.size_class = compute_size_class(fish.weight_kg)
	if not rod.planer.attached or rod.planer.state == PlanerBoard.STATE_TANGLED or rod.planer.state == PlanerBoard.STATE_SNAGGED:
		rod.planer.pull_back_offset = 0.0
		rod.planer.submersion = 0.0
		rod.planer.shake_intensity = 0.0
		rod.planer.inward_drift_force = 0.0
		if rod.planer.state == PlanerBoard.STATE_TANGLED or rod.planer.state == PlanerBoard.STATE_SNAGGED:
			rod.planer.flag_angle = -30.0
		else:
			rod.planer.flag_angle = 0.0
		return

	var profile := get_strike_reaction_profile(fish.size_class)
	if bool(profile.get("trips_planer", false)) and rod.planer.state != PlanerBoard.STATE_TRIPPED:
		rod.planer.state = PlanerBoard.STATE_TRIPPED

	var wave := 0.5 + 0.5 * sin(fish.fight_phase * 0.5)
	var cycle_intensity := 0.0
	if fish.surge_timer > 0.0:
		cycle_intensity = clampf(0.65 + 0.35 * wave, 0.0, 1.0)
	else:
		cycle_intensity = clampf(0.15 + 0.45 * wave, 0.0, 0.65)
	if fish.size_class == FishState.SIZE_MONSTER and fish.hooked_time < 1.5:
		cycle_intensity = maxf(cycle_intensity, 0.90)

	var t_pull := lerpf(float(profile["pull_back_rest"]), float(profile["pull_back_burst"]), cycle_intensity)
	var t_sub := lerpf(float(profile["submersion_rest"]), float(profile["submersion_burst"]), cycle_intensity)
	var t_flag := lerpf(float(profile["flag_angle_rest"]), float(profile["flag_angle_burst"]), cycle_intensity)
	var t_shake := lerpf(float(profile["shake_rest"]), float(profile["shake_burst"]), cycle_intensity)
	var t_drift := lerpf(float(profile["inward_drift_rest"]), float(profile["inward_drift_burst"]), cycle_intensity)

	if fish.is_exhausted() and fish.size_class != FishState.SIZE_SMALL:
		t_drift = 0.0
		t_sub *= 0.35
		t_shake *= 0.35

	var close_scale := clampf((rod.planer.line_out - config.detach_distance) / 4.0, 0.0, 1.0)
	t_pull *= close_scale
	t_sub *= lerpf(0.15, 1.0, close_scale)

	rod.planer.pull_back_offset = move_toward(rod.planer.pull_back_offset, t_pull, config.reaction_pull_back_rate * delta)
	rod.planer.submersion = move_toward(rod.planer.submersion, t_sub, config.reaction_submersion_rate * delta)
	rod.planer.flag_angle = move_toward(rod.planer.flag_angle, t_flag, config.reaction_flag_rate * delta)
	rod.planer.shake_intensity = move_toward(rod.planer.shake_intensity, t_shake, config.reaction_shake_rate * delta)
	rod.planer.inward_drift_force = move_toward(rod.planer.inward_drift_force, t_drift, config.reaction_drift_rate * delta)


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


func _complete_planer_detach(state: GameState, rod: RodState, fish: FishState, rod_sim: RodSimulator) -> void:
	var dx := rod.planer.lateral_offset
	var dz := sqrt(maxf(0.01, rod.planer.line_out * rod.planer.line_out - dx * dx))
	rod.trail_angle = wrapf(atan2(dx, dz), -PI, PI)
	rod.planer.attached = false
	rod.planer.lateral_offset = 0.0
	rod.planer.reset_strike_reaction()
	rod.planer.line_out = rod.planer.line_out + rod_sim.config.leader_length
	rod.planer.state = PlanerBoard.STATE_TROLLING if state.boat.forward_speed >= rod_sim.config.min_pull_speed else PlanerBoard.STATE_DEPLOYING
	fish.detach_progress = 0.0
	if get_fish_distance(rod, rod_sim) <= config.surface_reveal_distance + 0.05:
		fish.surfaced = true
	state.set_fish_notice("Plaanari irrotettu! Kelaa kala veneen viereen!", 3.0)


func _is_interact_held(raw_input: Variant) -> bool:
	if raw_input is PlayerInput:
		return (raw_input as PlayerInput).interact_held
	if raw_input is Dictionary:
		return bool((raw_input as Dictionary).get("interact_held", false))
	return false


func _collect_detaching_rods(state: GameState, inputs: Dictionary) -> Dictionary:
	var detaching: Dictionary = {}
	var pids: Array[int] = []
	for pid_raw in inputs.keys():
		var pid := int(pid_raw)
		if pid != 0 and not pids.has(pid):
			pids.append(pid)
	pids.sort()
	for pid in pids:
		if not _is_interact_held(_get_player_input(inputs, pid)):
			continue
		var target := find_detach_target_for_player(state, pid, config.detach_window_distance, config.coop_detach_radius)
		var rid := str(target.get("rod_id", ""))
		if not rid.is_empty():
			detaching[rid] = true
	return detaching


func _is_any_player_detaching_rod(state: GameState, inputs: Dictionary, rod_id: String) -> bool:
	var pids: Array[int] = []
	for pid_raw in inputs.keys():
		var pid := int(pid_raw)
		if pid != 0 and not pids.has(pid):
			pids.append(pid)
	pids.sort()
	for pid in pids:
		if not _is_interact_held(_get_player_input(inputs, pid)):
			continue
		var target := find_detach_target_for_player(state, pid, config.detach_window_distance, config.coop_detach_radius)
		if str(target.get("rod_id", "")) == rod_id:
			return true
	return false


func _get_line_input(raw_input: Variant) -> float:
	if raw_input is PlayerInput:
		return clampf((raw_input as PlayerInput).line_input, -1.0, 1.0)
	if raw_input is Dictionary:
		return clampf(float((raw_input as Dictionary).get("line_input", 0.0)), -1.0, 1.0)
	return 0.0
