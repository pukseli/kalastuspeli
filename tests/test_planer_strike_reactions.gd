extends "res://tests/test_case.gd"


func test_small_strike_stays_on_surface_and_pulls_back_less_than_medium() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	fish_sim.set_seed(111)

	state.boat.forward_speed = 3.0
	state.boat.velocity = Vector2(0.0, -3.0)

	var item_small := state.get_holder_item("rod_-3")
	var item_med := state.get_holder_item("rod_+3")
	var rod_small := state.get_rod_state(item_small.id)
	var rod_med := state.get_rod_state(item_med.id)

	rod_small.planer.line_out = 20.0
	rod_small.planer.state = PlanerBoard.STATE_DEPLOYING
	rod_med.planer.line_out = 20.0
	rod_med.planer.state = PlanerBoard.STATE_DEPLOYING
	for _i in range(420):
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)

	var z_before_small := rod_sim.get_board_local_pos_2d(state, item_small, rod_small).y

	var f_small := fish_sim.force_bite(state, rod_sim, item_small.id, FishState.SPECIES_PERCH, 0.55)
	var f_med := fish_sim.force_bite(state, rod_sim, item_med.id, FishState.SPECIES_ZANDER, 2.50)

	assert_eq(f_small.size_class, FishState.SIZE_SMALL, "0.55 kg perch is classified as SMALL")
	assert_eq(f_med.size_class, FishState.SIZE_MEDIUM, "2.50 kg zander is classified as MEDIUM")

	for _i in range(120):
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)
		fish_sim.step(state, {}, rod_sim, FishSimulator.FIXED_DELTA)
		assert_almost_eq(rod_small.planer.submersion, 0.0, 0.001, "SMALL strike never submerges planer")

	assert_eq(rod_small.planer.state, PlanerBoard.STATE_TROLLING, "SMALL strike does not fully trip planer")
	assert_true(rod_small.planer.flag_angle < -5.0 and rod_small.planer.flag_angle > -40.0, "SMALL strike keeps flag bobbing partially")
	assert_eq(rod_med.planer.state, PlanerBoard.STATE_TRIPPED, "MEDIUM strike clearly trips planer")
	assert_true(rod_med.planer.flag_angle <= -55.0, "MEDIUM strike drops flag back")
	assert_true(rod_small.planer.pull_back_offset > 0.1, "SMALL strike creates subtle aft pull_back_offset")
	assert_true(
		rod_small.planer.pull_back_offset < rod_med.planer.pull_back_offset - 0.5,
		"SMALL pull_back_offset is smaller than MEDIUM pull_back_offset"
	)
	var z_after_small := rod_sim.get_board_local_pos_2d(state, item_small, rod_small).y
	assert_true(z_after_small > z_before_small + 0.2, "pull_back_offset physically shifts board aft in 2D")


func test_monster_strike_submerges_board_and_drives_strong_inward_drift() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	fish_sim.set_seed(222)

	state.boat.forward_speed = 3.0
	state.boat.velocity = Vector2(0.0, -3.0)

	var item := state.get_holder_item("rod_-3")
	var rod := state.get_rod_state(item.id)
	rod.planer.line_out = 20.0
	rod.planer.state = PlanerBoard.STATE_DEPLOYING
	for _i in range(300):
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)

	var abs_lat_before := absf(rod.planer.lateral_offset)
	var f_monster := fish_sim.force_bite(state, rod_sim, item.id, FishState.SPECIES_PIKE, 11.5)
	assert_eq(f_monster.size_class, FishState.SIZE_MONSTER, "11.5 kg pike is classified as MONSTER")
	assert_eq(rod.planer.state, PlanerBoard.STATE_TRIPPED, "MONSTER strike trips planer")

	for _i in range(60):
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)
		fish_sim.step(state, {}, rod_sim, FishSimulator.FIXED_DELTA)

	assert_true(rod.planer.submersion > 0.8, "MONSTER strike submerges planer deep underwater (%.2f)" % rod.planer.submersion)
	assert_true(rod.planer.inward_drift_force >= 2.0, "MONSTER strike produces strong inward_drift_force (%.2f)" % rod.planer.inward_drift_force)
	assert_true(absf(rod.planer.lateral_offset) < abs_lat_before - 1.0, "MONSTER inward drift pulls planer sharply toward centerline")


func test_live_fish_fight_cycle_modulates_reaction_unlike_static_snagged() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	fish_sim.set_seed(333)

	state.boat.forward_speed = 3.0
	state.boat.velocity = Vector2(0.0, -3.0)

	var live_item := state.get_holder_item("rod_-3")
	var snag_item := state.get_holder_item("rod_+3")
	var live_rod := state.get_rod_state(live_item.id)
	var snag_rod := state.get_rod_state(snag_item.id)

	live_rod.planer.line_out = 20.0
	live_rod.planer.lateral_offset = -12.0
	live_rod.planer.state = PlanerBoard.STATE_TROLLING
	live_rod.trail_factor = 1.0

	snag_rod.planer.line_out = 20.0
	snag_rod.planer.lateral_offset = 12.0
	snag_rod.planer.state = PlanerBoard.STATE_SNAGGED
	snag_rod.planer.snag_world_position = Vector2(12.0, 15.0)
	snag_rod.trail_factor = 1.0

	var f_large := fish_sim.force_bite(state, rod_sim, live_item.id, FishState.SPECIES_PIKE, 6.2)
	assert_eq(f_large.size_class, FishState.SIZE_LARGE, "6.2 kg pike is classified as LARGE")

	var min_pull := INF
	var max_pull := -INF
	var min_shake := INF
	var max_shake := -INF

	for _i in range(400):
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)
		fish_sim.step(state, {}, rod_sim, FishSimulator.FIXED_DELTA)

		min_pull = minf(min_pull, live_rod.planer.pull_back_offset)
		max_pull = maxf(max_pull, live_rod.planer.pull_back_offset)
		min_shake = minf(min_shake, live_rod.planer.shake_intensity)
		max_shake = maxf(max_shake, live_rod.planer.shake_intensity)

		assert_almost_eq(snag_rod.planer.pull_back_offset, 0.0, 0.001, "SNAGGED pull_back_offset stays static at 0.0")
		assert_almost_eq(snag_rod.planer.shake_intensity, 0.0, 0.001, "SNAGGED shake_intensity stays static at 0.0")
		assert_almost_eq(snag_rod.planer.submersion, 0.0, 0.001, "SNAGGED submersion stays static at 0.0")
		assert_almost_eq(snag_rod.planer.flag_angle, -30.0, 0.001, "SNAGGED flag_angle stays static at -30.0")

	assert_true(max_pull - min_pull > 0.6, "Live fish pull_back_offset modulates over fight cycle (span %.2f)" % (max_pull - min_pull))
	assert_true(max_shake - min_shake > 0.15, "Live fish shake_intensity modulates over fight cycle (span %.2f)" % (max_shake - min_shake))


func test_unattended_large_or_monster_drift_triggers_tangled_with_inner_planer() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	fish_sim.set_seed(444)

	state.boat.forward_speed = 3.0
	state.boat.velocity = Vector2(0.0, -3.0)

	var outer_item := state.get_holder_item("rod_-3")
	var inner_item := state.get_holder_item("rod_-2")
	var outer_rod := state.get_rod_state(outer_item.id)
	var inner_rod := state.get_rod_state(inner_item.id)

	outer_rod.planer.line_out = 20.0
	outer_rod.planer.state = PlanerBoard.STATE_DEPLOYING
	inner_rod.planer.line_out = 14.0
	inner_rod.planer.state = PlanerBoard.STATE_DEPLOYING
	for _i in range(360):
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)

	assert_eq(outer_rod.planer.state, PlanerBoard.STATE_TROLLING, "Outer planer -3 starts TROLLING")
	assert_eq(inner_rod.planer.state, PlanerBoard.STATE_TROLLING, "Inner planer -2 starts TROLLING")

	fish_sim.force_bite(state, rod_sim, outer_item.id, FishState.SPECIES_PIKE, 6.5)

	var tangled := false
	for _i in range(360):
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)
		fish_sim.step(state, {}, rod_sim, FishSimulator.FIXED_DELTA)
		if outer_rod.planer.state == PlanerBoard.STATE_TANGLED and inner_rod.planer.state == PlanerBoard.STATE_TANGLED:
			tangled = true
			break

	assert_true(tangled, "Unattended LARGE strike inward drift crosses/collides inner planer and triggers TANGLED")
	assert_almost_eq(outer_rod.planer.inward_drift_force, 0.0, 0.001, "Tangled planer clears inward_drift_force")
	assert_almost_eq(outer_rod.planer.submersion, 0.0, 0.001, "Tangled planer clears submersion")


func test_world_view_and_interpolator_reflect_submersion_pitch_flag_and_shake() -> void:
	var state := GameState.new()
	state.ensure_player(1)
	var world := WorldView.new()

	var item_m := state.get_holder_item("rod_-3")
	var rod_m := state.get_rod_state(item_m.id)
	rod_m.planer.line_out = 18.0
	rod_m.planer.lateral_offset = -10.0
	rod_m.planer.state = PlanerBoard.STATE_TRIPPED
	rod_m.planer.pull_back_offset = 6.0
	rod_m.planer.submersion = 1.0
	rod_m.planer.flag_angle = -76.0
	rod_m.planer.shake_intensity = 0.9
	rod_m.trail_factor = 1.0

	var item_s := state.get_holder_item("rod_+3")
	var rod_s := state.get_rod_state(item_s.id)
	rod_s.planer.line_out = 18.0
	rod_s.planer.lateral_offset = 10.0
	rod_s.planer.state = PlanerBoard.STATE_TROLLING
	rod_s.planer.pull_back_offset = 0.4
	rod_s.planer.submersion = 0.0
	rod_s.planer.flag_angle = -20.0
	rod_s.planer.shake_intensity = 0.1
	rod_s.trail_factor = 1.0

	world.apply_game_state(state, "", 1, true)

	var node_m := world.planers_container.get_node_or_null("Planer_%s" % item_m.id) as Node3D
	var node_s := world.planers_container.get_node_or_null("Planer_%s" % item_s.id) as Node3D
	assert_true(node_m != null and node_s != null, "WorldView creates planer nodes for both rods")
	assert_true(node_m.position.y < WorldView.WATER_Y - 0.3, "Submerged MONSTER planer sits below WATER_Y")
	assert_true(node_s.position.y > WorldView.WATER_Y, "Surface SMALL planer stays above WATER_Y")
	assert_true(node_m.rotation.x > node_s.rotation.x + 0.2, "Higher pull_back_offset pitches planer further backward")

	var flag_m := node_m.get_node_or_null("FlagPivot") as Node3D
	var flag_s := node_s.get_node_or_null("FlagPivot") as Node3D
	assert_almost_eq(flag_m.rotation_degrees.x, -76.0, 0.1, "MONSTER flag_pivot matches continuous flag_angle")
	assert_almost_eq(flag_s.rotation_degrees.x, -20.0, 0.1, "SMALL bobbing flag_pivot matches continuous flag_angle")

	# Network interpolation of new PlanerBoard reaction fields and FishState.size_class
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	var sa := GameState.new()
	sa.tick = 6
	var ra := sa.get_rod_state(item_m.id)
	ra.planer.line_out = 18.0
	fish_sim.force_bite(sa, rod_sim, item_m.id, FishState.SPECIES_PIKE, 10.0)
	ra.planer.pull_back_offset = 2.0
	ra.planer.submersion = 0.2
	ra.planer.flag_angle = -30.0
	ra.planer.shake_intensity = 0.2
	ra.planer.inward_drift_force = 1.0

	var sb := GameState.new()
	sb.tick = 12
	var rb := sb.get_rod_state(item_m.id)
	rb.planer.line_out = 18.0
	fish_sim.force_bite(sb, rod_sim, item_m.id, FishState.SPECIES_PIKE, 10.0)
	rb.planer.pull_back_offset = 6.0
	rb.planer.submersion = 1.0
	rb.planer.flag_angle = -70.0
	rb.planer.shake_intensity = 0.8
	rb.planer.inward_drift_force = 3.0

	var interp := SnapshotInterpolator.new()
	interp.push_snapshot(sa.to_dict())
	interp.push_snapshot(sb.to_dict())
	var out := GameState.new()
	assert_true(interp.sample_at(out, 0.15, true), "SnapshotInterpolator interpolates planer strike reactions")
	var out_rod := out.get_rod_state(item_m.id)
	assert_almost_eq(out_rod.planer.pull_back_offset, 4.0, 0.01, "pull_back_offset interpolates to midpoint 4.0")
	assert_almost_eq(out_rod.planer.submersion, 0.6, 0.01, "submersion interpolates to midpoint 0.6")
	assert_almost_eq(out_rod.planer.flag_angle, -50.0, 0.01, "flag_angle interpolates to midpoint -50.0")
	assert_almost_eq(out_rod.planer.shake_intensity, 0.5, 0.01, "shake_intensity interpolates to midpoint 0.5")
	assert_almost_eq(out_rod.planer.inward_drift_force, 2.0, 0.01, "inward_drift_force interpolates to midpoint 2.0")
	assert_eq(out.get_fish_state(item_m.id).size_class, FishState.SIZE_MONSTER, "FishState size_class replicates cleanly")

	free_node(world)
