extends "res://tests/test_case.gd"


func test_given_default_config_when_get_holder_then_indexed_result_and_cached_tip_match_exact_math() -> void:
	var state := GameState.new()
	var cfg := state.item_config
	var rod_sim := RodSimulator.new()

	assert_true(cfg.get_holder("nonexistent").is_empty(), "Unknown holder id returns empty Dictionary")
	for h in cfg.holders:
		var hid := str(h["id"])
		var looked_up := cfg.get_holder(hid)
		assert_eq(str(looked_up.get("id", "")), hid, "Indexed get_holder finds %s" % hid)
		assert_true(looked_up.has("tip_local_position"), "Holder %s caches precomputed tip_local_position" % hid)
		var h_pos: Vector3 = looked_up["local_position"]
		var tilt: Vector3 = looked_up["tilt_degrees"]
		var tilt_rad := Vector3(deg_to_rad(tilt.x), deg_to_rad(tilt.y), deg_to_rad(tilt.z))
		var expected_tip := h_pos + Basis.from_euler(tilt_rad) * RodSimulator.RESTING_TIP_LOCAL_OFFSET
		var item := state.get_holder_item(hid)
		var actual_tip := rod_sim.get_rod_tip_local(state, item)
		assert_almost_eq(actual_tip.distance_to(expected_tip), 0.0, 0.00001, "Cached rod tip local position matches Euler math for %s" % hid)


func _run_deterministic_sim_600(seed_value: int) -> String:
	var gs := GameState.new()
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	fish_sim.set_seed(seed_value)
	var boat_sim := BoatSimulator.new()
	var crew_sim := CrewSimulator.new()
	var st_sim := StationSimulator.new()
	gs.configure_items(ItemConfig.create_default_config(6, 1))
	gs.ensure_player(1, false)
	gs.boat.forward_speed = 2.0
	var rids: Array[String] = []
	for rid in gs.rods.keys():
		rids.append(str(rid))
	rids.sort()
	for rid in rids:
		var rod: RodState = gs.rods[rid]
		rod.planer.line_out = 25.0
		rod.planer.state = PlanerBoard.STATE_TROLLING
		rod.trail_factor = 1.0
		rod.planer.lateral_offset = 5.0 * float(rod.planer.side)
		fish_sim.force_bite(gs, rod_sim, rid, FishState.SPECIES_PIKE, 5.0)
	var item_sim := ItemSimulator.new(gs.item_config)
	var nm := NetworkManager.new()
	var inp := PlayerInput.new()
	inp.throttle = 0.4
	for _i in range(600):
		nm.step_game_tick(gs, inp, boat_sim, crew_sim, st_sim, item_sim, rod_sim, fish_sim)
	nm.free()

	var full := gs.to_dict()
	var core_snapshot := {
		"tick": gs.tick,
		"boat": gs.boat.to_dict(),
		"players": full["players"],
		"rods": full["rods"],
		"fishes": full["fishes"],
	}
	return var_to_str(core_snapshot).sha256_text()


func test_given_seed_42069_and_600_ticks_when_simulated_twice_then_state_hashes_match() -> void:
	var hash_a := _run_deterministic_sim_600(42069)
	var hash_b := _run_deterministic_sim_600(42069)
	var hash_other := _run_deterministic_sim_600(99999)
	assert_eq(hash_a.length(), 64, "Simulation digest is a valid 64-char SHA-256 hex string")
	assert_eq(hash_a, hash_b, "Two identical 600-tick simulations produce bit-identical deterministic hash")
	assert_true(hash_a != hash_other, "Different seed changes deterministic simulation hash")


func test_given_holders_array_replaced_when_get_holder_then_index_rebuilt() -> void:
	var cfg := ItemConfig.new()
	assert_true(cfg.has_holder("rod_-3"), "Initial config has rod_-3")

	cfg.holders.append({
		"id": "rod_custom",
		"label": "C",
		"side": 1,
		"local_position": Vector3(1.0, 0.65, 1.0),
		"tilt_degrees": Vector3(10.0, 0.0, -20.0),
		"radius": 0.85,
		"allowed_types": [ItemConfig.ITEM_TYPE_ROD],
	})
	assert_true(cfg.has_holder("rod_custom"), "Index rebuilds automatically when holders array size changes")


func test_given_net_or_coop_detach_closer_than_helm_when_player_presses_interact_then_helm_does_not_hijack() -> void:
	var state := GameState.new()
	var boat_sim := BoatSimulator.new()
	var crew_sim := CrewSimulator.new()
	var station_sim := StationSimulator.new()
	var item_sim := ItemSimulator.new(state.item_config)
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	var nm := NetworkManager.new()

	# Player 1 is at Z = 0.05 (0.65m from helm at Z = -0.6, inside helm's 1.0m radius)
	# Landing net is on deck at Z = 0.30 (0.25m from player 1, closer than helm!)
	var p1 := state.ensure_player(1)
	p1.local_position = Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, 0.05)
	var net_item := state.items["net_1"] as HeldItem
	net_item.deck_position = Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, 0.30)

	var interact_in := PlayerInput.new()
	interact_in.interact = true
	nm.step_game_tick(state, interact_in, boat_sim, crew_sim, station_sim, item_sim, rod_sim, fish_sim)

	assert_eq(state.get_player_station(1), "", "Helm does not hijack E press when deck net is closer than helm")
	assert_true(state.get_player_held_item(1) == net_item, "Player picks up closer deck net instead of entering helm")
	nm.free()


func test_given_escaped_fish_after_planer_detach_when_reeled_to_zero_in_hand_then_default_planer_restored() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var p1 := state.ensure_player(1)
	p1.local_position = Vector3(-1.2, CrewSimulator.DECK_SURFACE_Y, 0.8)

	var item := state.get_holder_item("rod_-3")
	var rod := state.get_rod_state(item.id)
	# Carry rod_-3 in hand, simulate detached planer and escaped fish at 1.5m line_out
	item.carrier_peer_id = 1
	item.holder_id = ""
	item.last_holder_id = "rod_-3"
	rod.planer.attached = false
	rod.planer.line_out = 1.5
	rod.planer.state = PlanerBoard.STATE_TROLLING

	var reel_in := PlayerInput.new()
	reel_in.line_input = -1.0
	for _i in range(20):
		rod_sim.step(state, {1: reel_in}, RodSimulator.FIXED_DELTA)

	assert_almost_eq(rod.planer.line_out, 0.0, 0.001, "Line is reeled all the way to 0.0 m in hand")
	assert_true(rod.planer.attached, "Reeling side rod to 0.0 m in hand restores its default planer board attachment")
