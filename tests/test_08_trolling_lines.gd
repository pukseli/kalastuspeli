extends "res://tests/test_case.gd"


func test_deploy_reel_at_holder_and_in_hand_and_carry_preserves_line() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var item_sim := ItemSimulator.new(state.item_config)
	var crew_sim := CrewSimulator.new()
	var p1 := state.ensure_player(1)
	var p2 := state.ensure_player(2)

	assert_eq(state.rods.size(), 6, "All 6 initial rods should have RodState entries")
	assert_eq(state.get_deployed_rod_count(), 0, "All rods start stowed at 0.0 m")
	for item_id in state.items:
		var item: HeldItem = state.items[item_id]
		if item == null or item.item_type != ItemConfig.ITEM_TYPE_ROD:
			continue
		var r := state.get_rod_state(str(item_id))
		assert_true(r != null, "RodState exists for %s" % str(item_id))
		assert_almost_eq(r.planer.line_out, 0.0, 0.001, "Initial line_out is 0.0")
		assert_eq(r.planer.state, PlanerBoard.STATE_STOWED, "Initial planer state is STOWED")

	# Empty-handed players at rod_-2: peer 1 wins same-tick line_input contention
	var rod_left_2 := state.get_holder_item("rod_-2")
	assert_true(rod_left_2 != null, "rod_-2 exists")
	p1.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 2.1)
	p2.local_position = Vector3(-1.25, CrewSimulator.DECK_SURFACE_Y, 2.1)

	var out_in := PlayerInput.new()
	out_in.line_input = 1.0
	for _i in range(60):
		rod_sim.step(state, {1: out_in, 2: out_in}, RodSimulator.FIXED_DELTA)

	var r2 := state.get_rod_state(rod_left_2.id)
	assert_almost_eq(r2.planer.line_out, 8.0, 0.05, "Only one actor adjusts rod per tick: 1s at 8 m/s yields 8.0 m")
	assert_true(r2.planer.attached, "Side holder rod_-2 starts with planer attached")
	assert_eq(r2.planer.side, PlanerBoard.SIDE_LEFT, "rod_-2 planer side is LEFT (-1)")

	# Pick up deployed rod, walk on deck, adjust in hand -> line_out stays deployed and adjustable
	var interact_in := PlayerInput.new()
	interact_in.interact = true
	item_sim.step(state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	assert_true(state.get_player_held_item(1) == rod_left_2, "Player 1 picked up deployed rod_-2")

	var walk_in := PlayerInput.new()
	walk_in.move_x = 1.0
	walk_in.move_z = -0.5
	for _i in range(20):
		crew_sim.step(state, {1: walk_in}, CrewSimulator.FIXED_DELTA)
	assert_almost_eq(r2.planer.line_out, 8.0, 0.05, "Carrying rod across deck preserves deployed line_out")

	var reel_in := PlayerInput.new()
	reel_in.line_input = -1.0
	for _i in range(15):
		rod_sim.step(state, {1: reel_in}, RodSimulator.FIXED_DELTA)
	assert_almost_eq(r2.planer.line_out, 6.0, 0.05, "Reeling in hand reduces line_out to 6.0 m")

	for _i in range(30):
		rod_sim.step(state, {1: out_in}, RodSimulator.FIXED_DELTA)
	assert_almost_eq(r2.planer.line_out, 10.0, 0.05, "Deploying in hand increases line_out to 10.0 m")

	# Swap with rod_-3 preserves both rods' line lengths, and disconnect returns rod without resetting line
	var rod_left_3 := state.get_holder_item("rod_-3")
	p1.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 0.8)
	item_sim.step(state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	assert_eq(rod_left_2.holder_id, "rod_-3", "Swapped rod_-2 is now placed in rod_-3")
	assert_true(state.get_player_held_item(1) == rod_left_3, "Player 1 now holds previously resting rod_-3")
	assert_almost_eq(r2.planer.line_out, 10.0, 0.05, "Swapping into holder preserves line_out")

	state.remove_player(1)
	assert_eq(rod_left_3.carrier_peer_id, 0, "Disconnect returns carried rod_-3 to holder")
	assert_almost_eq(r2.planer.line_out, 10.0, 0.05, "Disconnect does not reset deployed line_out")

	# Reel rod_left_2 all the way to 0.0 -> returns to STOWED
	p2.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 0.8)
	for _i in range(90):
		rod_sim.step(state, {2: reel_in}, RodSimulator.FIXED_DELTA)
	assert_almost_eq(r2.planer.line_out, 0.0, 0.001, "Full reel-in reaches 0.0 m")
	assert_eq(r2.planer.state, PlanerBoard.STATE_STOWED, "Reeling to 0.0 returns state to STOWED")
	assert_almost_eq(r2.planer.lateral_offset, 0.0, 0.001, "STOWED planer lateral_offset is 0.0")


func test_boat_speed_spreads_planer_fan_and_stop_collapses_offset() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	state.boat.forward_speed = 3.0
	state.boat.velocity = Vector2(0.0, -3.0)
	state.boat.angular_velocity = 0.0

	var deployed_holders: Array[String] = ["rod_-3", "rod_-2", "rod_-1", "rod_+2", "rod_+3"]
	for hid in deployed_holders:
		var item := state.get_holder_item(hid)
		var rod := state.get_rod_state(item.id)
		rod.planer.line_out = 20.0
		rod.planer.state = PlanerBoard.STATE_DEPLOYING
		rod.trail_factor = rod_sim.config.min_stopped_trail_factor

	for _i in range(360):
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)

	var r_l3 := state.get_rod_state(state.get_holder_item("rod_-3").id)
	var r_l2 := state.get_rod_state(state.get_holder_item("rod_-2").id)
	var r_l1 := state.get_rod_state(state.get_holder_item("rod_-1").id)
	var r_r2 := state.get_rod_state(state.get_holder_item("rod_+2").id)
	var r_r3 := state.get_rod_state(state.get_holder_item("rod_+3").id)

	assert_true(r_l3.planer.lateral_offset < -10.0, "Left outer planer (-3) spreads far negative")
	assert_true(r_l2.planer.lateral_offset < -6.0, "Left inner planer (-2) spreads negative")
	assert_true(absf(r_l3.planer.lateral_offset) > absf(r_l2.planer.lateral_offset) + 1.0, "Outer slot -3 spreads wider than -2")
	assert_true(r_r2.planer.lateral_offset > 6.0, "Right inner planer (+2) spreads positive")
	assert_true(r_r3.planer.lateral_offset > 10.0, "Right outer planer (+3) spreads far positive")
	assert_eq(r_l3.planer.state, PlanerBoard.STATE_TROLLING, "-3 reaches steady TROLLING state")
	assert_eq(r_l2.planer.state, PlanerBoard.STATE_TROLLING, "-2 reaches steady TROLLING state without false tangle")
	assert_eq(r_r3.planer.state, PlanerBoard.STATE_TROLLING, "+3 reaches steady TROLLING state")
	assert_true(not r_l1.planer.attached, "Stern slot -1 has no planer attached")
	assert_almost_eq(r_l1.trail_factor, 1.0, 0.02, "Straight stern line extends trail_factor to 1.0 at cruise speed")

	var prev_l3_abs := absf(r_l3.planer.lateral_offset)
	var prev_r3_abs := absf(r_r3.planer.lateral_offset)
	state.boat.forward_speed = 0.0
	state.boat.velocity = Vector2.ZERO
	for _i in range(120):
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)

	assert_true(absf(r_l3.planer.lateral_offset) < prev_l3_abs - 1.5, "Stopping boat collapses left planer lateral_offset toward boat")
	assert_true(absf(r_r3.planer.lateral_offset) < prev_r3_abs - 1.5, "Stopping boat collapses right planer lateral_offset toward boat")
	assert_true(r_l1.trail_factor < 0.6, "Stopping boat shrinks straight-line horizontal projection trail_factor")


func test_straight_line_angular_lag_and_bite_bonus_api() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var stern_left := state.get_holder_item("rod_-1")
	var stern_right := state.get_holder_item("rod_+1")
	var rod_short := state.get_rod_state(stern_left.id)
	var rod_long := state.get_rod_state(stern_right.id)

	rod_short.planer.attached = false
	rod_short.planer.line_out = 6.0
	rod_short.trail_angle = deg_to_rad(-8.0)
	rod_short.trail_factor = 1.0

	rod_long.planer.attached = false
	rod_long.planer.line_out = 24.0
	rod_long.trail_angle = deg_to_rad(8.0)
	rod_long.trail_factor = 1.0

	# Left turn (angular_velocity > 0) lags lures toward negative angle relative to stern
	state.boat.forward_speed = 3.0
	state.boat.angular_velocity = 0.5
	for _i in range(45):
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)

	assert_true(rod_short.trail_angle < deg_to_rad(-8.0), "Turning left lags short straight line to negative trail_angle")
	assert_true(rod_long.trail_angle < 0.0, "Turning left lags long straight line toward negative trail_angle")

	# Straighten out: short line recovers toward its holder angle faster than long line
	var short_after_turn := rod_short.trail_angle
	var long_after_turn := rod_long.trail_angle
	state.boat.angular_velocity = 0.0
	for _i in range(60):
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)

	var short_err_before := absf(angle_difference(short_after_turn, deg_to_rad(-8.0)))
	var short_err_after := absf(angle_difference(rod_short.trail_angle, deg_to_rad(-8.0)))
	var long_err_before := absf(angle_difference(long_after_turn, deg_to_rad(8.0)))
	var long_err_after := absf(angle_difference(rod_long.trail_angle, deg_to_rad(8.0)))
	assert_true(short_err_after < short_err_before, "Short straight line recovers toward holder fan angle")
	assert_true(long_err_after < long_err_before, "Long straight line recovers toward holder fan angle")
	assert_true((short_err_after / maxf(0.001, short_err_before)) < (long_err_after / maxf(0.001, long_err_before)), "Shorter line aligns faster than longer line")

	# Quiet-water bite bonus API
	var planer_item := state.get_holder_item("rod_-3")
	var planer_rod := state.get_rod_state(planer_item.id)
	assert_almost_eq(rod_sim.get_bite_probability_multiplier(planer_rod), 1.0, 0.001, "Stowed planer gets 1.0x bite multiplier")
	assert_almost_eq(rod_sim.get_bite_probability_multiplier(rod_long), 1.0, 0.001, "Straight stern line gets 1.0x bite multiplier")

	planer_rod.planer.line_out = 20.0
	planer_rod.planer.lateral_offset = -10.0
	planer_rod.planer.state = PlanerBoard.STATE_TROLLING
	assert_almost_eq(rod_sim.get_bite_probability_multiplier(planer_rod), rod_sim.config.quiet_water_bite_bonus, 0.001, "Trolling planer in quiet water gets 1.2x bite multiplier")


func test_rods_replicate_over_network_and_interpolate_smoothly() -> void:
	var host_net := NetworkManager.new()
	host_net.configure_from_args(PackedStringArray(["--host", "--sync-hz", "60"]))
	var client_net := NetworkManager.new()
	client_net.configure_from_args(PackedStringArray(["--join", "127.0.0.1"]))

	var host_state := GameState.new()
	var client_state := GameState.new()
	var boat_sim := BoatSimulator.new()
	var crew_sim := CrewSimulator.new()
	var station_sim := StationSimulator.new()
	var item_sim := ItemSimulator.new(host_state.item_config)
	var rod_sim := RodSimulator.new()
	var host_input := PlayerInput.new()

	var p2 := host_state.ensure_player(2)
	p2.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 0.8)
	host_net.receive_client_input(2, {"throttle": 0.0, "steering": 0.0, "move_x": 0.0, "move_z": 0.0, "interact": false, "line_input": 1.0})

	var snap: Dictionary = {}
	for _i in range(6):
		snap = host_net.step_game_tick(host_state, host_input, boat_sim, crew_sim, station_sim, item_sim, rod_sim)

	assert_true(snap.has("rods"), "Host snapshot includes serialized rods dictionary")
	client_net.apply_game_snapshot(client_state, snap)

	var rod_l3_id := host_state.get_holder_item("rod_-3").id
	var client_rod := client_state.get_rod_state(rod_l3_id)
	assert_true(client_rod != null, "Client replicates RodState for rod_-3")
	assert_true(client_rod.planer.line_out > 0.5, "Client replicates deployed line_out from host")

	# Interpolation: smooth continuous rod/planer fields + discrete state/attached from latest
	var state_a := GameState.new()
	state_a.tick = 6
	var ra := state_a.get_rod_state(rod_l3_id)
	ra.trail_angle = -0.2
	ra.trail_factor = 0.4
	ra.planer.line_out = 10.0
	ra.planer.lateral_offset = -4.0
	ra.planer.state = PlanerBoard.STATE_DEPLOYING
	ra.planer.attached = true

	var state_b := GameState.new()
	state_b.tick = 12
	var rb := state_b.get_rod_state(rod_l3_id)
	rb.trail_angle = 0.2
	rb.trail_factor = 1.0
	rb.planer.line_out = 20.0
	rb.planer.lateral_offset = -12.0
	rb.planer.state = PlanerBoard.STATE_TROLLING
	rb.planer.attached = true

	var interp := SnapshotInterpolator.new()
	interp.push_snapshot(state_a.to_dict())
	interp.push_snapshot(state_b.to_dict())

	var out := GameState.new()
	assert_true(interp.sample_at(out, 0.15, true), "Interpolator sample_at succeeds at midpoint")
	var out_rod := out.get_rod_state(rod_l3_id)
	assert_almost_eq(out_rod.planer.line_out, 15.0, 0.01, "line_out interpolates smoothly to midpoint 15.0")
	assert_almost_eq(out_rod.planer.lateral_offset, -8.0, 0.01, "lateral_offset interpolates smoothly to midpoint -8.0")
	assert_almost_eq(out_rod.trail_factor, 0.7, 0.01, "trail_factor interpolates smoothly to midpoint 0.7")
	assert_almost_eq(out_rod.trail_angle, 0.0, 0.01, "trail_angle interpolates smoothly to midpoint 0.0")
	assert_eq(out_rod.planer.state, PlanerBoard.STATE_TROLLING, "Discrete planer state follows latest snapshot")

	host_net.free()
	client_net.free()


func test_world_view_renders_lines_planers_lures_and_updates_hud() -> void:
	var state := GameState.new()
	var p1 := state.ensure_player(1)
	var world := WorldView.new()

	world.apply_game_state(state, "", 1, true)
	assert_eq(world.get_trolling_line_surface_count(), 0, "ImmediateMesh has 0 surfaces when no lines are deployed")
	assert_eq(world.get_visible_lure_count(), 0, "Zero lures rendered when all rods are stowed")
	assert_eq(world.get_visible_planer_count(), 0, "Zero planers rendered when all rods are stowed")
	assert_true(world.hud_label.text.contains("Vedessä: 0/6"), "HUD shows Vedessä: 0/6 initially")

	# Deploy one planer rod (rod_-3) and one straight stern rod (rod_-1)
	var item_planer := state.get_holder_item("rod_-3")
	var rod_planer := state.get_rod_state(item_planer.id)
	rod_planer.planer.attached = true
	rod_planer.planer.line_out = 18.0
	rod_planer.planer.lateral_offset = -10.0
	rod_planer.planer.state = PlanerBoard.STATE_TROLLING
	rod_planer.trail_factor = 1.0

	var item_straight := state.get_holder_item("rod_-1")
	var rod_straight := state.get_rod_state(item_straight.id)
	rod_straight.planer.attached = false
	rod_straight.planer.line_out = 18.0
	rod_straight.planer.state = PlanerBoard.STATE_TROLLING
	rod_straight.trail_angle = deg_to_rad(-8.0)
	rod_straight.trail_factor = 1.0

	p1.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 0.8)
	world.apply_game_state(state, "", 1, true)

	assert_eq(world.get_trolling_line_surface_count(), 1, "Single ImmediateMesh surface draws all active lines in 1 draw call")
	assert_eq(world.get_visible_lure_count(), 2, "2 lures visible for 2 deployed rods")
	assert_eq(world.get_visible_planer_count(), 1, "1 planer board visible for attached deployed rod")
	assert_true(world.hud_label.text.contains("Vedessä: 2/6"), "HUD updates to Vedessä: 2/6")
	assert_eq(world.prompt_label.text, "[E] Poimi vapa (-3)", "Existing holder prompt_label remains intact")
	assert_true(world.line_prompt_label.text.contains("18.0 m"), "line_prompt_label shows nearby rod line length")
	assert_true(world.line_prompt_label.text.contains("[Q/Shift]") and world.line_prompt_label.text.contains("[Space]"), "line_prompt_label shows deploy and reel hints")

	# Pick up rod and confirm line_prompt_label shows carried rod length away from holders
	item_planer.carrier_peer_id = 1
	item_planer.holder_id = ""
	p1.local_position = Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, 0.0)
	world.apply_game_state(state, "", 1, true)
	assert_true(world.line_prompt_label.text.contains("18.0 m"), "line_prompt_label tracks carried rod length")
	assert_true(world.line_prompt_label.text.contains("[Space]"), "line_prompt_label shows reel key while carrying rod")

	free_node(world)
