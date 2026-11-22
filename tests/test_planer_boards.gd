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
