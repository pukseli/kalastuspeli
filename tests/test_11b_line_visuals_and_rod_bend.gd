extends "res://tests/test_case.gd"


func test_given_slack_vs_taut_rod_when_applied_to_world_view_then_slack_sags_more_and_uses_single_surface() -> void:
	var state := GameState.new()
	var item_slack := state.get_holder_item("rod_-3")
	var rod_slack := state.get_rod_state(item_slack.id)
	rod_slack.planer.attached = false
	rod_slack.planer.line_out = 20.0
	rod_slack.planer.state = PlanerBoard.STATE_TROLLING
	rod_slack.trail_factor = 1.0
	rod_slack.line_tension = 0.0

	var item_taut := state.get_holder_item("rod_+3")
	var rod_taut := state.get_rod_state(item_taut.id)
	rod_taut.planer.attached = false
	rod_taut.planer.line_out = 20.0
	rod_taut.planer.state = PlanerBoard.STATE_TROLLING
	rod_taut.trail_factor = 1.0
	rod_taut.line_tension = 65.0

	var world := WorldView.new()
	world.apply_game_state(state, "", 1, true)

	assert_eq(world.get_trolling_line_surface_count(), 1, "All trolling lines draw in a single ImmediateMesh surface")
	assert_true(world._line_mat.vertex_color_use_as_albedo, "Line material uses per-vertex colors")

	var slack_pts := world.get_line_points_world(item_slack.id)
	var taut_pts := world.get_line_points_world(item_taut.id)
	assert_true(slack_pts.size() >= 5, "Slack line stores at least 5 curve points (%d)" % slack_pts.size())
	assert_true(taut_pts.size() >= 5, "Taut line stores at least 5 curve points (%d)" % taut_pts.size())

	var slack_mid := slack_pts[slack_pts.size() / 2]
	var slack_chord_mid := slack_pts[0].lerp(slack_pts[slack_pts.size() - 1], 0.5)
	var slack_drop := slack_chord_mid.y - slack_mid.y

	var taut_mid := taut_pts[taut_pts.size() / 2]
	var taut_chord_mid := taut_pts[0].lerp(taut_pts[taut_pts.size() - 1], 0.5)
	var taut_drop := taut_chord_mid.y - taut_mid.y

	assert_true(slack_drop >= taut_drop + 0.35, "Slack line sags at least 0.35m more than taut line (slack=%.3f, taut=%.3f)" % [slack_drop, taut_drop])
	assert_true(taut_drop < 0.12, "Taut line runs nearly straight (drop=%.3f)" % taut_drop)

	var slack_col := world.get_line_color(item_slack.id)
	var taut_col := world.get_line_color(item_taut.id)
	assert_true(slack_col.r < 0.70, "Slack line renders with muted cool color (r=%.2f)" % slack_col.r)
	assert_true(taut_col.r > 0.85, "Taut normal/high line renders bright (r=%.2f)" % taut_col.r)

	free_node(world)


func test_given_critical_tension_over_80_percent_when_stepped_then_line_turns_warning_red_and_vibrates_with_pinned_endpoints() -> void:
	var state := GameState.new()
	var item_fresh := state.get_holder_item("rod_-3")
	var rod_fresh := state.get_rod_state(item_fresh.id)
	rod_fresh.planer.attached = false
	rod_fresh.planer.line_out = 18.0
	rod_fresh.planer.state = PlanerBoard.STATE_TROLLING
	rod_fresh.trail_factor = 1.0
	rod_fresh.line_tension = 88.0
	rod_fresh.line_integrity = 1.0

	var item_abraded := state.get_holder_item("rod_+3")
	var rod_abraded := state.get_rod_state(item_abraded.id)
	rod_abraded.planer.attached = false
	rod_abraded.planer.line_out = 18.0
	rod_abraded.planer.state = PlanerBoard.STATE_TROLLING
	rod_abraded.trail_factor = 1.0
	rod_abraded.line_integrity = 0.50
	rod_abraded.line_tension = 45.0

	var item_calm := state.get_holder_item("rod_-2")
	var rod_calm := state.get_rod_state(item_calm.id)
	rod_calm.planer.attached = false
	rod_calm.planer.line_out = 18.0
	rod_calm.planer.state = PlanerBoard.STATE_TROLLING
	rod_calm.trail_factor = 1.0
	rod_calm.line_tension = 30.0
	rod_calm.line_integrity = 1.0

	var world := WorldView.new()
	state.tick = 1
	world.apply_game_state(state, "", 1, true)

	var col_fresh := world.get_line_color(item_fresh.id)
	var col_abraded := world.get_line_color(item_abraded.id)
	assert_true(col_fresh.r >= 0.90 and col_fresh.g <= 0.35 and col_fresh.b <= 0.25, "Fresh critical >=80%% tension turns warning red")
	assert_true(col_abraded.r >= 0.90 and col_abraded.g <= 0.35 and col_abraded.b <= 0.25, "Abraded critical >=80%% effective strength turns warning red")
	assert_eq(world.get_trolling_line_surface_count(), 1, "Single ImmediateMesh surface preserved with warning colors")

	var pts1_fresh := world.get_line_points_world(item_fresh.id)
	var pts1_abraded := world.get_line_points_world(item_abraded.id)
	var pts1_calm := world.get_line_points_world(item_calm.id)
	var max_fresh_delta := 0.0
	var max_abraded_delta := 0.0
	var max_calm_delta := 0.0

	for tick_val in [2, 3, 4]:
		state.tick = tick_val
		world.apply_game_state(state, "", 1, false, true)
		var pf := world.get_line_points_world(item_fresh.id)
		var pa := world.get_line_points_world(item_abraded.id)
		var pc := world.get_line_points_world(item_calm.id)

		assert_almost_eq(pf[0].distance_to(world.get_line_start_world(item_fresh.id)), 0.0, 0.001, "Critical fresh start stays pinned to rod tip")
		assert_almost_eq(pf[pf.size() - 1].distance_to(pts1_fresh[pts1_fresh.size() - 1]), 0.0, 0.001, "Critical fresh end stays pinned to lure")
		assert_almost_eq(pa[0].distance_to(world.get_line_start_world(item_abraded.id)), 0.0, 0.001, "Critical abraded start stays pinned to rod tip")
		assert_almost_eq(pa[pa.size() - 1].distance_to(pts1_abraded[pts1_abraded.size() - 1]), 0.0, 0.001, "Critical abraded end stays pinned to lure")

		for idx in range(1, pf.size() - 1):
			max_fresh_delta = maxf(max_fresh_delta, pf[idx].distance_to(pts1_fresh[idx]))
		for idx in range(1, pa.size() - 1):
			max_abraded_delta = maxf(max_abraded_delta, pa[idx].distance_to(pts1_abraded[idx]))
		for idx in range(1, pc.size() - 1):
			max_calm_delta = maxf(max_calm_delta, pc[idx].distance_to(pts1_calm[idx]))

	assert_true(max_fresh_delta > 0.015, "Fresh critical line vibrates interior vertices (delta=%.4f)" % max_fresh_delta)
	assert_true(max_abraded_delta > 0.015, "Abraded critical line vibrates interior vertices (delta=%.4f)" % max_abraded_delta)
	assert_true(max_calm_delta < 0.0005, "Calm 30%% line stays steady without vibration (delta=%.5f)" % max_calm_delta)

	free_node(world)


func test_given_increasing_line_tension_when_applied_to_resting_and_held_rods_then_bend_increases_and_line_stays_attached() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var p1 := state.ensure_player(1)
	p1.local_position = Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, 0.4)

	var rest_item := state.get_holder_item("rod_-3")
	var rest_rod := state.get_rod_state(rest_item.id)
	rest_rod.planer.attached = false
	rest_rod.planer.line_out = 18.0
	rest_rod.planer.state = PlanerBoard.STATE_TROLLING
	rest_rod.trail_factor = 1.0

	var held_item := state.get_holder_item("rod_+3")
	held_item.carrier_peer_id = 1
	held_item.holder_id = ""
	var held_rod := state.get_rod_state(held_item.id)
	held_rod.planer.attached = false
	held_rod.planer.line_out = 18.0
	held_rod.planer.state = PlanerBoard.STATE_TROLLING
	held_rod.trail_factor = 1.0

	var world := WorldView.new()
	var rest_bends: Array[float] = []
	var held_bends: Array[float] = []

	for tension_n in [0.0, 40.0, 90.0]:
		rest_rod.line_tension = tension_n
		held_rod.line_tension = tension_n
		world.apply_game_state(state, "", 1, true)
		rest_bends.append(world.boat_view.get_resting_rod_bend_degrees(rest_item.id))
		var pv := world.boat_view.get_player_view(1)
		assert_true(pv != null, "PlayerView exists for carrier")
		held_bends.append(pv.get_held_rod_bend_degrees())

	assert_almost_eq(rest_bends[0], 0.0, 0.001, "Resting rod bend is 0 deg at 0 N tension")
	assert_true(rest_bends[0] < rest_bends[1] and rest_bends[1] < rest_bends[2], "Resting rod bend increases monotonically with tension")
	assert_true(rest_bends[2] > 20.0, "Resting rod bends noticeably (>20 deg) at 90 N (%.1f)" % rest_bends[2])

	assert_almost_eq(held_bends[0], 0.0, 0.001, "Held rod bend is 0 deg at 0 N tension")
	assert_true(held_bends[0] < held_bends[1] and held_bends[1] < held_bends[2], "Held rod bend increases monotonically with tension")
	assert_true(held_bends[2] > 20.0, "Held rod bends noticeably (>20 deg) at 90 N (%.1f)" % held_bends[2])

	for item in [rest_item, held_item]:
		var line_start := world.get_line_start_world(item.id)
		var visual_tip := world.boat_view.get_visual_rod_tip_world(item, state)
		var unbent_tip := rod_sim.get_rod_tip_world(state, item)
		assert_almost_eq(line_start.distance_to(visual_tip), 0.0, 0.001, "Line start stays attached to bent TipPivot tip (%s)" % item.id)
		assert_true(line_start.distance_to(unbent_tip) > 0.15, "Bent TipPivot moves rod tip >0.15m from unbent position (%s)" % item.id)

	free_node(world)


func test_given_active_rod_when_tension_drag_and_integrity_change_then_hud_meter_updates_fill_marker_and_danger_zone() -> void:
	var state := GameState.new()
	var p1 := state.ensure_player(1)
	p1.local_position = Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, -1.0)

	var world := WorldView.new()
	world.apply_game_state(state, "", 1, true)
	assert_true(not world.tension_meter_root.visible, "Tension meter hides when empty-handed away from holders")

	var item := state.get_holder_item("rod_-3")
	var orig_holder := item.holder_id
	item.carrier_peer_id = 1
	item.holder_id = ""
	var rod := state.get_rod_state(item.id)
	rod.planer.line_out = 18.0
	rod.planer.state = PlanerBoard.STATE_TROLLING
	rod.drag_setting = 60.0
	rod.line_tension = 25.0
	rod.line_remaining_on_spool = 150.0
	rod.line_integrity = 1.0

	world.apply_game_state(state, "", 1, true)
	assert_true(world.tension_meter_root.visible, "Tension meter shows when holding a rod")
	var fill_low := world.tension_bar_fill.size.x
	assert_true(fill_low > 0.0, "Tension bar fill width is positive at 25 N")
	var low_col := world.tension_bar_fill.color
	assert_true(low_col.g > low_col.r, "Low 25%% tension bar fill is green-dominant")
	var drag_x_60 := world.drag_marker.position.x
	var danger_w_100 := world.tension_danger_zone.size.x
	var spool_w_150 := world.spool_bar_fill.size.x

	rod.line_tension = 88.0
	rod.drag_setting = 110.0
	rod.is_drag_slipping = true
	rod.line_remaining_on_spool = 75.0
	rod.line_integrity = 0.50

	world.apply_game_state(state, "", 1, true)
	assert_true(world.tension_bar_fill.size.x > fill_low, "Tension bar fill width grows from 25 N to 88 N")
	var high_col := world.tension_bar_fill.color
	assert_true(high_col.r >= 0.90 and high_col.g <= 0.35, "Critical tension bar fill turns warning red")
	assert_true(world.drag_marker.position.x > drag_x_60 + 50.0, "Drag marker moves right when drag increases 60 -> 110 N")
	assert_true(world.tension_danger_zone.size.x > danger_w_100 + 50.0, "Danger zone widens when line integrity drops to 50%%")
	assert_true(world.spool_bar_fill.size.x < spool_w_150 * 0.55, "Spool bar shrinks proportionally at 75/150 m")

	item.carrier_peer_id = 0
	item.holder_id = orig_holder
	state.stations[StationConfig.HELM_STATION_ID] = 1
	p1.local_position = StationConfig.HELM_LOCAL_POS
	world.apply_game_state(state, "", 1, true)
	assert_true(not world.tension_meter_root.visible, "Tension meter hides while operating helm")

	free_node(world)


func test_given_unchanged_view_state_when_reapplied_then_no_material_reassignments_and_single_draw_call_preserved() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	fish_sim.set_seed(1105)

	var configurations := [
		{"hid": "rod_-3", "tension": 5.0, "integrity": 1.0, "slip": false, "state": PlanerBoard.STATE_TROLLING},
		{"hid": "rod_-2", "tension": 42.0, "integrity": 1.0, "slip": false, "state": PlanerBoard.STATE_TROLLING},
		{"hid": "rod_+2", "tension": 60.0, "integrity": 1.0, "slip": true, "state": PlanerBoard.STATE_TRIPPED},
		{"hid": "rod_+3", "tension": 88.0, "integrity": 1.0, "slip": false, "state": PlanerBoard.STATE_TROLLING},
	]
	for cfg in configurations:
		var it := state.get_holder_item(str(cfg["hid"]))
		var rd := state.get_rod_state(it.id)
		rd.planer.attached = true
		rd.planer.line_out = 20.0
		rd.planer.lateral_offset = float(rd.planer.side) * 10.0
		rd.planer.state = str(cfg["state"])
		rd.trail_factor = 1.0
		rd.line_tension = float(cfg["tension"])
		rd.line_integrity = float(cfg["integrity"])
		rd.is_drag_slipping = bool(cfg["slip"])

	var pike_item := state.get_holder_item("rod_+2")
	var pike := fish_sim.force_bite(state, rod_sim, pike_item.id, FishState.SPECIES_PIKE, 5.2)
	pike.surfaced = true

	var world := WorldView.new()
	world.apply_game_state(state, "", 1, true, false)
	var assign_count_after_first := world.material_assign_count
	assert_true(assign_count_after_first > 0, "Initial apply assigns materials to planers and surfaced fish")
	assert_eq(world.get_trolling_line_surface_count(), 1, "All 4 lines render in 1 surface")

	world.apply_game_state(state, "", 1, false, false)
	assert_eq(world.material_assign_count, assign_count_after_first, "Reapplying unchanged view state triggers 0 extra material assignments")
	assert_eq(world.get_trolling_line_surface_count(), 1, "Single ImmediateMesh surface preserved after reapply")

	free_node(world)
