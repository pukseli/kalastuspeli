extends "res://tests/test_case.gd"


func test_forward_motion_spreads_right_positive_and_left_negative() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	state.boat.forward_speed = 3.0
	state.boat.velocity = Vector2(0.0, -3.0)
	state.boat.angular_velocity = 0.0

	var left_item := state.get_holder_item("rod_-3")
	var right_item := state.get_holder_item("rod_+3")
	var left_rod := state.get_rod_state(left_item.id)
	var right_rod := state.get_rod_state(right_item.id)

	left_rod.planer.attached = true
	left_rod.planer.line_out = 20.0
	left_rod.planer.state = PlanerBoard.STATE_DEPLOYING
	right_rod.planer.attached = true
	right_rod.planer.line_out = 20.0
	right_rod.planer.state = PlanerBoard.STATE_DEPLOYING

	for _i in range(360):
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)

	assert_true(right_rod.planer.lateral_offset > 10.0, "Right planer spreads to positive lateral_offset")
	assert_true(left_rod.planer.lateral_offset < -10.0, "Left planer spreads to negative lateral_offset")
	assert_eq(right_rod.planer.state, PlanerBoard.STATE_TROLLING, "Right planer enters TROLLING state")
	assert_eq(left_rod.planer.state, PlanerBoard.STATE_TROLLING, "Left planer enters TROLLING state")


func test_stopping_boat_reduces_planer_lateral_offset() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	state.boat.forward_speed = 3.0
	state.boat.velocity = Vector2(0.0, -3.0)

	var left_rod := state.get_rod_state(state.get_holder_item("rod_-3").id)
	var right_rod := state.get_rod_state(state.get_holder_item("rod_+3").id)
	left_rod.planer.line_out = 20.0
	left_rod.planer.lateral_offset = -12.0
	left_rod.planer.state = PlanerBoard.STATE_TROLLING
	right_rod.planer.line_out = 20.0
	right_rod.planer.lateral_offset = 12.0
	right_rod.planer.state = PlanerBoard.STATE_TROLLING

	state.boat.forward_speed = 0.0
	state.boat.velocity = Vector2.ZERO
	var prev_left_abs := absf(left_rod.planer.lateral_offset)
	var prev_right_abs := absf(right_rod.planer.lateral_offset)

	for _i in range(90):
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)

	assert_true(absf(left_rod.planer.lateral_offset) < prev_left_abs, "Left planer lateral_offset magnitude decreases when stopped")
	assert_true(absf(right_rod.planer.lateral_offset) < prev_right_abs, "Right planer lateral_offset magnitude decreases when stopped")
	assert_true(absf(left_rod.planer.lateral_offset) < 9.5, "Left planer collapses substantially after 1.5s stopped")
	assert_true(absf(right_rod.planer.lateral_offset) < 9.5, "Right planer collapses substantially after 1.5s stopped")


func test_sharp_turn_inner_planers_approach_and_tangle() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	state.boat.forward_speed = 3.0
	state.boat.velocity = Vector2(0.0, -3.0)
	state.boat.angular_velocity = 0.0

	var outer_item := state.get_holder_item("rod_-3")
	var inner_item := state.get_holder_item("rod_-2")
	var outer_rod := state.get_rod_state(outer_item.id)
	var inner_rod := state.get_rod_state(inner_item.id)

	outer_rod.planer.line_out = 20.0
	outer_rod.planer.state = PlanerBoard.STATE_DEPLOYING
	inner_rod.planer.line_out = 12.0
	inner_rod.planer.state = PlanerBoard.STATE_DEPLOYING

	for _i in range(360):
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)

	assert_eq(outer_rod.planer.state, PlanerBoard.STATE_TROLLING, "Outer left planer reaches TROLLING before turn")
	assert_eq(inner_rod.planer.state, PlanerBoard.STATE_TROLLING, "Inner left planer reaches TROLLING before turn")
	var pos_outer_before := rod_sim.get_board_world_pos_2d(state, outer_item, outer_rod)
	var pos_inner_before := rod_sim.get_board_world_pos_2d(state, inner_item, inner_rod)
	var initial_dist := pos_outer_before.distance_to(pos_inner_before)
	assert_true(initial_dist > rod_sim.config.board_tangle_distance * 2.0, "Left planers start well separated")

	# Sharp left turn (angular_velocity > 0 slows/stalls left inner-turn planers)
	state.boat.forward_speed = 2.5
	state.boat.angular_velocity = 0.65
	var min_dist := initial_dist
	for _i in range(180):
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)
		var p_out := rod_sim.get_board_world_pos_2d(state, outer_item, outer_rod)
		var p_in := rod_sim.get_board_world_pos_2d(state, inner_item, inner_rod)
		min_dist = minf(min_dist, p_out.distance_to(p_in))
		if outer_rod.planer.state == PlanerBoard.STATE_TANGLED and inner_rod.planer.state == PlanerBoard.STATE_TANGLED:
			break

	assert_true(min_dist < initial_dist, "Inner-turn planers move closer together during sharp turn")
	assert_true(
		outer_rod.planer.state == PlanerBoard.STATE_TANGLED or inner_rod.planer.state == PlanerBoard.STATE_TANGLED,
		"Sharp turn triggers TANGLED state on inner-turn planer"
	)


func test_obstacle_collision_triggers_snagged_state() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	state.boat.world_position = Vector3.ZERO
	state.boat.heading = 0.0
	state.boat.forward_speed = 3.0
	state.boat.velocity = Vector2(0.0, -3.0)

	var item := state.get_holder_item("rod_+3")
	var rod := state.get_rod_state(item.id)
	rod.planer.line_out = 16.0
	rod.planer.lateral_offset = 10.0
	rod.planer.state = PlanerBoard.STATE_TROLLING
	rod.trail_factor = 1.0

	var board_start := rod_sim.get_board_world_pos_2d(state, item, rod)
	var obstacle_pos := board_start + Vector2(0.0, -1.5)
	var obstacles: Array = [{"position": obstacle_pos, "radius": 1.0}]

	for _i in range(60):
		state.boat.world_position.z -= state.boat.forward_speed * RodSimulator.FIXED_DELTA
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA, obstacles)
		if rod.planer.state == PlanerBoard.STATE_SNAGGED:
			break

	assert_eq(rod.planer.state, PlanerBoard.STATE_SNAGGED, "Planer hitting obstacle transitions to SNAGGED")
	var locked_pos := rod.planer.snag_world_position
	assert_true(locked_pos.distance_to(obstacle_pos) <= 1.6, "snag_world_position locks at obstacle collision area")

	# Advance boat further: SNAGGED planer world position remains anchored at snag_world_position
	for _i in range(15):
		state.boat.world_position.z -= state.boat.forward_speed * RodSimulator.FIXED_DELTA
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA, obstacles)
	assert_almost_eq(rod_sim.get_board_world_pos_2d(state, item, rod).distance_to(locked_pos), 0.0, 0.001, "SNAGGED planer remains anchored in world space")


func test_short_deploy_put_down_redeploy_and_stopped_clearance() -> void:
	# Part 1: Stationary boat (v_fwd = 0): deploy 0 -> 4m, reel 4 -> 2m, re-deploy 2 -> 8m
	var stopped_state := GameState.new()
	var rod_sim := RodSimulator.new()
	var item_sim := ItemSimulator.new(stopped_state.item_config)
	var p1 := stopped_state.ensure_player(1)
	p1.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 0.8)

	var rod_item := stopped_state.get_holder_item("rod_-3")
	var rod := stopped_state.get_rod_state(rod_item.id)
	var out_in := PlayerInput.new()
	out_in.line_input = 1.0
	var reel_in := PlayerInput.new()
	reel_in.line_input = -1.0
	var interact_in := PlayerInput.new()
	interact_in.interact = true

	for _i in range(30):
		rod_sim.step(stopped_state, {1: out_in}, RodSimulator.FIXED_DELTA)
	assert_almost_eq(rod.planer.line_out, 4.0, 0.05, "Stopped boat deploys rod_-3 to 4.0 m")
	assert_true(rod.planer.state != PlanerBoard.STATE_TANGLED, "Stopped short deploy must not trigger TANGLED")
	var pos_at_4m := rod_sim.get_board_world_pos_2d(stopped_state, rod_item, rod)
	assert_true(absf(pos_at_4m.x) > 1.8, "Stopped planer spawns clear outside boat hull")

	for _i in range(15):
		rod_sim.step(stopped_state, {1: reel_in}, RodSimulator.FIXED_DELTA)
	assert_almost_eq(rod.planer.line_out, 2.0, 0.05, "Stopped boat reels rod_-3 back to 2.0 m")
	var pos_at_2m := rod_sim.get_board_world_pos_2d(stopped_state, rod_item, rod)
	assert_true(pos_at_2m.y < pos_at_4m.y, "Reeling moves stopped planer forward toward rod tip")

	for _i in range(45):
		rod_sim.step(stopped_state, {1: out_in}, RodSimulator.FIXED_DELTA)
	assert_almost_eq(rod.planer.line_out, 8.0, 0.05, "Stopped boat re-deploys rod_-3 from 2.0 m to 8.0 m without full reel-in")
	assert_true(rod.planer.state != PlanerBoard.STATE_TANGLED, "Re-deploy while stopped never locks in TANGLED")
	var pos_at_8m := rod_sim.get_board_world_pos_2d(stopped_state, rod_item, rod)
	assert_true(pos_at_8m.y > pos_at_4m.y, "Deploying further moves stopped planer farther aft")

	# Part 2: Cruising (3.0 m/s): pick up rod, deploy short (3.0m), put down into holder, re-deploy to 10m
	var cruise_state := GameState.new()
	cruise_state.boat.forward_speed = 3.0
	cruise_state.boat.velocity = Vector2(0.0, -3.0)
	var cp1 := cruise_state.ensure_player(1)
	cp1.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 0.8)

	var c_rod_item := cruise_state.get_holder_item("rod_-3")
	var c_rod := cruise_state.get_rod_state(c_rod_item.id)
	item_sim.step(cruise_state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	assert_true(cruise_state.get_player_held_item(1) == c_rod_item, "Player picks up rod_-3")

	for _i in range(23):
		rod_sim.step(cruise_state, {1: out_in}, RodSimulator.FIXED_DELTA)
	assert_true(c_rod.planer.line_out > 2.5 and c_rod.planer.line_out < 3.5, "Short deploy in hand ~3.0 m")
	assert_true(c_rod.planer.state != PlanerBoard.STATE_TANGLED, "Short deploy in hand stays untangled")
	var held_board_pos := rod_sim.get_board_world_pos_2d(cruise_state, c_rod_item, c_rod)
	assert_true(absf(held_board_pos.x) > 1.8, "Held rod planer stays clear outside boat hull")

	# Put rod back down into rod_-3 and immediately re-deploy further
	item_sim.step(cruise_state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	assert_true(cruise_state.get_player_held_item(1) == null, "Player puts rod_-3 back into holder")
	var line_after_place := c_rod.planer.line_out
	for _i in range(52):
		rod_sim.step(cruise_state, {1: out_in}, RodSimulator.FIXED_DELTA)
	assert_true(c_rod.planer.line_out > line_after_place + 6.0, "Can immediately re-deploy after putting short-deployed rod down")
	assert_true(c_rod.planer.state != PlanerBoard.STATE_TANGLED, "Re-deploying after placing rod stays untangled")

	# Deploy rod_-2 first (10 m), then deploy rod_-3 (0 -> 10 m) straight -> must NOT false tangle
	var rod_l2 := cruise_state.get_rod_state(cruise_state.get_holder_item("rod_-2").id)
	rod_l2.planer.line_out = 10.0
	rod_l2.planer.state = PlanerBoard.STATE_DEPLOYING
	for _i in range(180):
		rod_sim.step(cruise_state, {}, RodSimulator.FIXED_DELTA)
	assert_eq(rod_l2.planer.state, PlanerBoard.STATE_TROLLING, "rod_-2 reaches TROLLING first")

	c_rod.planer.line_out = 0.0
	c_rod.planer.lateral_offset = 0.0
	c_rod.planer.state = PlanerBoard.STATE_STOWED
	cp1.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 0.8)
	for _i in range(75):
		rod_sim.step(cruise_state, {1: out_in}, RodSimulator.FIXED_DELTA)
	for _i in range(180):
		rod_sim.step(cruise_state, {}, RodSimulator.FIXED_DELTA)
	assert_eq(c_rod.planer.state, PlanerBoard.STATE_TROLLING, "Deploying rod_-3 after rod_-2 reaches TROLLING without false tangle")
	assert_eq(rod_l2.planer.state, PlanerBoard.STATE_TROLLING, "rod_-2 remains TROLLING when rod_-3 deploys next to it")


func test_reeling_in_during_inner_turn_and_stopping_keeps_board_aft_of_rod_tip() -> void:
	# Scenario A (right turn, starboard rod_+2 deployed to 20 m and reeled in while player stands near +2)
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	state.boat.heading = 0.0
	state.boat.forward_speed = 5.73
	state.boat.velocity = Vector2(0.0, -5.73)
	state.boat.angular_velocity = -0.25

	var p1 := state.ensure_player(1)
	p1.local_position = Vector3(1.2, CrewSimulator.DECK_SURFACE_Y, 2.1)

	var item := state.get_holder_item("rod_+2")
	var rod := state.get_rod_state(item.id)
	rod.planer.attached = true
	rod.planer.line_out = 20.0
	rod.planer.state = PlanerBoard.STATE_DEPLOYING
	rod.trail_factor = 1.0

	for _i in range(360):
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)
	assert_eq(rod.planer.state, PlanerBoard.STATE_TROLLING, "Starboard rod_+2 reaches TROLLING before reel-in")

	var reel_in := PlayerInput.new()
	reel_in.line_input = -1.0
	var checked_at_3_9 := false
	for tick in range(143):
		rod_sim.step(state, {1: reel_in}, RodSimulator.FIXED_DELTA)
		if rod.planer.line_out > 0.5:
			var tip_local := rod_sim.get_rod_tip_local(state, item)
			var board_local := rod_sim.get_board_local_pos_2d(state, item, rod)
			var eff_factor := maxf(rod.trail_factor, rod_sim.config.min_stopped_trail_factor)
			assert_true(
				board_local.y > tip_local.z + 0.5 * rod.planer.line_out * eff_factor,
				"Reeling inner-turn planer keeps board aft of rod tip (tick=%d, line=%.2f)" % [tick, rod.planer.line_out]
			)
			assert_true(
				absf(rod.planer.lateral_offset) <= rod.planer.line_out * sin(deg_to_rad(rod_sim.config.max_spread_angle_deg)) + 0.02,
				"lateral_offset remains bounded by max spread geometry while reeling"
			)
			assert_true(rod.planer.state != PlanerBoard.STATE_TANGLED, "Actively reeling inner-turn rod does not false-tangle")
		if tick == 120:
			checked_at_3_9 = true
			var board_local_3_9 := rod_sim.get_board_local_pos_2d(state, item, rod)
			assert_almost_eq(rod.planer.line_out, 3.867, 0.1, "121 ticks of reeling reaches ~3.9 m")
			assert_true(board_local_3_9.y > 3.6, "At ~3.9 m line_out, board stays aft of stern z=3.6 (was %.2f)" % board_local_3_9.y)
			assert_true(rod.trail_angle > 0.0, "Right turn builds positive trailing leader angle (%.3f)" % rod.trail_angle)

	assert_true(checked_at_3_9, "Verified snapshot at ~3.9 m during reel-in")

	# Scenario B (boat stopping from 3.0 m/s cruise never snaps board forward to trail_z = 0)
	var stop_state := GameState.new()
	stop_state.boat.forward_speed = 3.0
	stop_state.boat.velocity = Vector2(0.0, -3.0)
	var s_item := stop_state.get_holder_item("rod_+3")
	var s_rod := stop_state.get_rod_state(s_item.id)
	s_rod.planer.attached = true
	s_rod.planer.line_out = 20.0
	s_rod.planer.state = PlanerBoard.STATE_DEPLOYING
	s_rod.trail_factor = 1.0
	for _i in range(360):
		rod_sim.step(stop_state, {}, RodSimulator.FIXED_DELTA)
	assert_eq(s_rod.planer.state, PlanerBoard.STATE_TROLLING, "rod_+3 reaches TROLLING before stop")

	stop_state.boat.forward_speed = 0.0
	stop_state.boat.velocity = Vector2.ZERO
	for tick in range(90):
		rod_sim.step(stop_state, {}, RodSimulator.FIXED_DELTA)
		var s_tip := rod_sim.get_rod_tip_local(stop_state, s_item)
		var s_board := rod_sim.get_board_local_pos_2d(stop_state, s_item, s_rod)
		var s_eff := maxf(s_rod.trail_factor, rod_sim.config.min_stopped_trail_factor)
		assert_true(
			s_board.y > s_tip.z + 0.5 * s_rod.planer.line_out * s_eff,
			"Stopping boat never snaps planer forward to 90 deg abeam (tick=%d)" % tick
		)


func test_holder_move_preserves_deployed_planer_and_syncs_stowed_default() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var item_sim := ItemSimulator.new(state.item_config)
	state.boat.forward_speed = 3.0
	state.boat.velocity = Vector2(0.0, -3.0)
	state.boat.angular_velocity = 0.0

	var p1 := state.ensure_player(1)
	var interact_in := PlayerInput.new()
	interact_in.interact = true

	var item_r2 := state.get_holder_item("rod_+2")
	var item_r1 := state.get_holder_item("rod_+1")
	var rod_r2 := state.get_rod_state(item_r2.id)
	var rod_r1 := state.get_rod_state(item_r1.id)
	assert_true(rod_r2.planer.attached, "rod_+2 starts with planer attached")
	assert_true(not rod_r1.planer.attached, "rod_+1 starts without planer attached")

	# 1. Deploy rod_+2 to 15.0 m -> reaches TROLLING wide on starboard side
	rod_r2.planer.line_out = 15.0
	rod_r2.planer.state = PlanerBoard.STATE_DEPLOYING
	rod_r2.trail_factor = 1.0
	for _i in range(360):
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)
	assert_eq(rod_r2.planer.state, PlanerBoard.STATE_TROLLING, "rod_+2 reaches TROLLING")
	assert_true(rod_r2.planer.lateral_offset > 6.0, "rod_+2 spreads > 6.0 m before holder move")

	# 2. Pick up deployed rod from +2, swap into +1, and place dry former-+1 rod into +2
	p1.local_position = Vector3(1.3, CrewSimulator.DECK_SURFACE_Y, 2.1)
	item_sim.step(state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	assert_true(state.get_player_held_item(1) == item_r2, "Player picks up deployed rod_+2")

	p1.local_position = Vector3(0.95, CrewSimulator.DECK_SURFACE_Y, 3.0)
	item_sim.step(state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	assert_eq(item_r2.holder_id, "rod_+1", "Deployed rod is placed into stern holder +1")
	assert_true(state.get_player_held_item(1) == item_r1, "Player receives stowed former-+1 rod from swap")

	p1.local_position = Vector3(1.3, CrewSimulator.DECK_SURFACE_Y, 2.1)
	item_sim.step(state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	assert_eq(item_r1.holder_id, "rod_+2", "Stowed rod is placed into side holder +2")

	for _i in range(360):
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)

	assert_true(rod_r2.planer.attached, "Deployed rod moved to +1 keeps planer attached while in water")
	assert_true(
		rod_r2.planer.lateral_offset > 1.5 and rod_r2.planer.lateral_offset < 3.0,
		"Planer in +1 narrows toward 8 deg (~2.09 m), was %.2f" % rod_r2.planer.lateral_offset
	)
	assert_true(rod_r1.planer.attached, "Stowed former-+1 rod moved into +2 automatically attaches planer")

	# 3. Reel deployed rod in +1 all the way to 0.0 m -> syncs to +1 default (no planer)
	p1.local_position = Vector3(0.95, CrewSimulator.DECK_SURFACE_Y, 3.0)
	var reel_in := PlayerInput.new()
	reel_in.line_input = -1.0
	for _i in range(130):
		rod_sim.step(state, {1: reel_in}, RodSimulator.FIXED_DELTA)
	assert_eq(rod_r2.planer.state, PlanerBoard.STATE_STOWED, "Fully reeled rod enters STOWED")
	assert_true(not rod_r2.planer.attached, "Once stowed in +1, planer attachment syncs to +1 default (false)")

	# 4. Move stowed rod back to +2 -> automatically re-attaches planer
	item_sim.step(state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	p1.local_position = Vector3(1.3, CrewSimulator.DECK_SURFACE_Y, 2.1)
	item_sim.step(state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	assert_eq(item_r2.holder_id, "rod_+2", "Stowed rod swapped back to +2")
	rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)
	assert_true(rod_r2.planer.attached, "Stowed rod moved back to +2 automatically restores planer attachment")
