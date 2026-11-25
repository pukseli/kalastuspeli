extends "res://tests/test_case.gd"


func test_given_taut_trolling_and_safe_drag_when_fish_surges_then_drag_slips_blocks_reel_and_never_snaps() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	fish_sim.set_seed(1101)

	state.boat.forward_speed = 3.0
	state.boat.velocity = Vector2(0.0, -3.0)
	var p1 := state.ensure_player(1)
	p1.local_position = Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, 0.8)

	var item := state.get_holder_item("rod_-3")
	var rod := state.get_rod_state(item.id)
	rod.planer.attached = true
	rod.planer.line_out = 25.0
	rod.planer.lateral_offset = -12.0
	rod.planer.state = PlanerBoard.STATE_TROLLING
	rod.trail_factor = 1.0
	rod.drag_setting = 60.0

	# 60 seconds of taut trolling never snaps the line or wears it down
	for _i in range(3600):
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)

	assert_true(rod.line_tension > 15.0 and rod.line_tension < 60.0, "Taut trolling creates steady safe tension (%.1f N)" % rod.line_tension)
	assert_true(not rod.is_drag_slipping, "Safe trolling does not slip 60 N drag")
	assert_almost_eq(rod.line_integrity, 1.0, 0.001, "Safe taut trolling does not abrade line")
	assert_eq(rod.planer.state, PlanerBoard.STATE_TROLLING, "Line remains in TROLLING after 60s taut pull")

	# Pick up rod and hook a surging 6 kg pike; Space cannot pull line in while drag is slipping
	item.carrier_peer_id = 1
	item.holder_id = ""
	var fish := fish_sim.force_bite(state, rod_sim, item.id, FishState.SPECIES_PIKE, 6.0)
	fish.stamina = 1.0
	fish.surge_timer = 5.0
	fish.hooked_time = 0.0

	var reel_in := PlayerInput.new()
	reel_in.line_input = -1.0
	var line_before := rod.planer.line_out
	var spool_before := rod.line_remaining_on_spool

	for _i in range(60):
		rod_sim.step(state, {1: reel_in}, RodSimulator.FIXED_DELTA)
		fish_sim.step(state, {1: reel_in}, rod_sim, FishSimulator.FIXED_DELTA)

	assert_true(state.has_fish_on_rod(item.id), "60 N drag saves line from snapping during pike surge")
	assert_true(rod.is_drag_slipping, "Drag slips during strong pike surge")
	assert_true(rod.line_tension <= 60.05, "Slipping drag caps line_tension near drag_setting (%.1f N)" % rod.line_tension)
	assert_true(rod.planer.line_out > line_before, "Fish pulls line out despite holding Space during drag slip")
	assert_true(rod.line_remaining_on_spool < spool_before, "Slipping drag reduces line_remaining_on_spool")
	assert_true(fish.drag_rate > 0.0, "Derived FishState.drag_rate activates during drag slip")

	# Once fish calms/tires below drag_setting, holding Space reels line in and refills spool
	fish.stamina = 0.0
	fish.surge_timer = 0.0
	var line_after_surge := rod.planer.line_out
	var spool_after_surge := rod.line_remaining_on_spool
	for _i in range(60):
		rod_sim.step(state, {1: reel_in}, RodSimulator.FIXED_DELTA)
		fish_sim.step(state, {1: reel_in}, rod_sim, FishSimulator.FIXED_DELTA)

	assert_true(not rod.is_drag_slipping, "Tired calm fish stops slipping 60 N drag")
	assert_true(rod.planer.line_out < line_after_surge, "Holding Space reels line in once load drops below drag_setting")
	assert_true(rod.line_remaining_on_spool > spool_after_surge, "Reeling in restores line_remaining_on_spool")


func test_given_overtight_drag_or_empty_spool_when_fish_pulls_then_line_snaps_to_tangled_and_recovers_on_stowed() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	fish_sim.set_seed(1102)

	state.boat.forward_speed = 3.0
	state.boat.velocity = Vector2(0.0, -3.0)
	var p1 := state.ensure_player(1)
	p1.local_position = Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, 0.8)

	# Part A: Over-tightened drag (> 100 N) snaps on pike surge
	var item_l3 := state.get_holder_item("rod_-3")
	var rod_l3 := state.get_rod_state(item_l3.id)
	rod_l3.planer.attached = true
	rod_l3.planer.line_out = 20.0
	rod_l3.planer.lateral_offset = -10.0
	rod_l3.planer.state = PlanerBoard.STATE_TROLLING
	rod_l3.drag_setting = 120.0
	var f_pike := fish_sim.force_bite(state, rod_sim, item_l3.id, FishState.SPECIES_PIKE, 7.0)
	f_pike.stamina = 1.0
	f_pike.surge_timer = 2.0

	for _i in range(10):
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)
		fish_sim.step(state, {}, rod_sim, FishSimulator.FIXED_DELTA)
		if not state.has_fish_on_rod(item_l3.id):
			break

	assert_true(not state.has_fish_on_rod(item_l3.id), "Over-tightened 120 N drag causes fish loss on snap")
	assert_eq(rod_l3.planer.state, PlanerBoard.STATE_TANGLED, "Snapped rod enters TANGLED state")
	assert_true(not rod_l3.planer.attached, "Snapped rod loses attached planer visually")
	assert_true(rod_l3.planer.line_out >= 2.0 and rod_l3.planer.line_out <= 6.05, "Snapped rod leaves short tangled stub (%.1f m)" % rod_l3.planer.line_out)
	assert_true(state.fish_notice_text.to_lower().contains("katkesi"), "Snap updates HUD notice with reason")

	# Part B: Safe drag (60 N) protects line until spool empties, then line snaps
	var item_r3 := state.get_holder_item("rod_+3")
	var rod_r3 := state.get_rod_state(item_r3.id)
	rod_r3.planer.attached = true
	rod_r3.planer.line_out = 20.0
	rod_r3.planer.lateral_offset = 10.0
	rod_r3.planer.state = PlanerBoard.STATE_TROLLING
	rod_r3.drag_setting = 60.0
	rod_r3.line_remaining_on_spool = 0.8
	var f_whale := fish_sim.force_bite(state, rod_sim, item_r3.id, FishState.SPECIES_BLUE_WHALE)
	f_whale.stamina = 1.0
	f_whale.surge_timer = 5.0

	var saw_slip_before_empty := false
	for _i in range(90):
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)
		fish_sim.step(state, {}, rod_sim, FishSimulator.FIXED_DELTA)
		if state.has_fish_on_rod(item_r3.id) and rod_r3.is_drag_slipping:
			saw_slip_before_empty = true
		if not state.has_fish_on_rod(item_r3.id):
			break

	assert_true(saw_slip_before_empty, "Drag slips normally until spool empties")
	assert_true(not state.has_fish_on_rod(item_r3.id), "Emptied spool loses fish on snap")
	assert_eq(rod_r3.planer.state, PlanerBoard.STATE_TANGLED, "Emptied spool transitions rod to TANGLED")
	assert_true(not rod_r3.planer.attached, "Emptied spool snap detaches planer")
	assert_true(rod_r3.line_remaining_on_spool <= 0.001, "Spool reached empty before snapping")

	# Part C: Reeling snapped stub to 0 m -> STOWED restores clean spool, integrity, and default planer
	item_l3.carrier_peer_id = 1
	item_l3.holder_id = ""
	var reel_in := PlayerInput.new()
	reel_in.line_input = -1.0
	for _i in range(120):
		rod_sim.step(state, {1: reel_in}, RodSimulator.FIXED_DELTA)
		if rod_l3.planer.state == PlanerBoard.STATE_STOWED:
			break

	assert_eq(rod_l3.planer.state, PlanerBoard.STATE_STOWED, "Reeling snapped stub reaches STOWED")
	assert_almost_eq(rod_l3.line_integrity, 1.0, 0.001, "STOWED restores line_integrity to 1.0")
	assert_almost_eq(rod_l3.line_remaining_on_spool, 150.0, 0.01, "STOWED refills line_remaining_on_spool to 150 m")
	assert_almost_eq(rod_l3.line_tension, 0.0, 0.001, "STOWED resets line_tension to 0.0")
	assert_true(rod_l3.planer.attached, "STOWED restores side rod default planer attachment")


func test_given_tangled_or_snagged_rod_when_abraded_then_integrity_drops_and_lower_load_snaps_line() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	state.boat.forward_speed = 3.0
	state.boat.velocity = Vector2(0.0, -3.0)

	# Part A: SNAGGED and TANGLED rods lose line_integrity over time
	var item_snag := state.get_holder_item("rod_-3")
	var rod_snag := state.get_rod_state(item_snag.id)
	rod_snag.planer.attached = true
	rod_snag.planer.line_out = 18.0
	rod_snag.planer.lateral_offset = -8.0
	rod_snag.planer.state = PlanerBoard.STATE_SNAGGED
	var tip_2d := rod_sim.get_rod_tip_world(state, item_snag)
	rod_snag.planer.snag_world_position = Vector2(tip_2d.x - 8.0, tip_2d.z + 15.0)

	var item_tangle := state.get_holder_item("rod_+3")
	var rod_tangle := state.get_rod_state(item_tangle.id)
	rod_tangle.planer.attached = true
	rod_tangle.planer.line_out = 18.0
	rod_tangle.planer.lateral_offset = 6.0
	rod_tangle.planer.state = PlanerBoard.STATE_TANGLED

	for _i in range(180):
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)

	assert_true(rod_snag.line_integrity < 0.90, "SNAGGED abrasion reduces line_integrity (%.2f)" % rod_snag.line_integrity)
	assert_true(rod_tangle.line_integrity < 0.90, "TANGLED abrasion reduces line_integrity (%.2f)" % rod_tangle.line_integrity)
	assert_true(rod_snag.get_effective_max_strength() < 90.0, "Effective max strength drops with abrasion")

	# Part B: Worn line (integrity = 0.4 -> 40 N effective) snaps even at safe 60 N drag
	var worn_state := GameState.new()
	var fish_sim := FishSimulator.new()
	fish_sim.set_seed(1103)
	worn_state.boat.forward_speed = 3.0
	var item_worn := worn_state.get_holder_item("rod_-3")
	var rod_worn := worn_state.get_rod_state(item_worn.id)
	rod_worn.planer.attached = true
	rod_worn.planer.line_out = 18.0
	rod_worn.planer.state = PlanerBoard.STATE_TROLLING
	rod_worn.drag_setting = 60.0
	rod_worn.line_integrity = 0.40
	var f_pike := fish_sim.force_bite(worn_state, rod_sim, item_worn.id, FishState.SPECIES_PIKE, 5.0)
	f_pike.stamina = 1.0
	f_pike.surge_timer = 1.0

	for _i in range(10):
		rod_sim.step(worn_state, {}, RodSimulator.FIXED_DELTA)
		fish_sim.step(worn_state, {}, rod_sim, FishSimulator.FIXED_DELTA)
		if not worn_state.has_fish_on_rod(item_worn.id):
			break

	assert_true(not worn_state.has_fish_on_rod(item_worn.id), "Abraded 40% integrity line snaps under 60 N drag")
	assert_eq(rod_worn.planer.state, PlanerBoard.STATE_TANGLED, "Abraded snap enters TANGLED state")

	# Part C: Broken TANGLED stub does not repeatedly re-snap in a loop
	worn_state.fish_notice_text = ""
	for _i in range(60):
		rod_sim.step(worn_state, {}, RodSimulator.FIXED_DELTA)
		fish_sim.step(worn_state, {}, rod_sim, FishSimulator.FIXED_DELTA)
	assert_eq(worn_state.fish_notice_text, "", "Already-tangled broken stub does not re-trigger snap notice")
	assert_true(rod_worn.line_integrity >= 0.149, "Abrasion stays clamped above minimum floor (0.15)")


func test_given_slack_line_when_active_fish_hooked_then_escape_rate_spikes_while_tired_fish_stay_safe() -> void:
	var rod_sim := RodSimulator.new()
	var slack_escapes := 0
	var taut_escapes := 0

	for trial in range(20):
		for mode in ["slack", "taut"]:
			var st := GameState.new()
			var f_sim := FishSimulator.new()
			f_sim.set_seed(7000 + trial * 13)
			st.boat.forward_speed = 0.0
			var it := st.get_holder_item("rod_-3")
			var rd := st.get_rod_state(it.id)
			rd.planer.attached = true
			rd.planer.line_out = 18.0
			rd.planer.state = PlanerBoard.STATE_TRIPPED
			rd.drag_setting = 5.0 if mode == "slack" else 60.0

			var fish := f_sim.force_bite(st, rod_sim, it.id, FishState.SPECIES_PIKE, 5.0)
			fish.stamina = 1.0
			fish.hooked_time = 8.0
			fish.surge_timer = 0.0
			fish.surge_cooldown = 99.0

			for _i in range(600):
				fish.surge_timer = 0.0
				fish.surge_cooldown = 99.0
				f_sim.step(st, {}, rod_sim, FishSimulator.FIXED_DELTA)
				if not st.has_fish_on_rod(it.id):
					break

			if not st.has_fish_on_rod(it.id):
				if mode == "slack":
					slack_escapes += 1
				else:
					taut_escapes += 1

	assert_true(slack_escapes >= 14, "Slack line (< 10 N) causes frequent active fish escapes (%d/20)" % slack_escapes)
	assert_eq(taut_escapes, 0, "Taut non-surging line never triggers slack escapes (%d/20)" % taut_escapes)

	# Exhausted pike and perch stay safely hooked even at 0 N tension
	var safe_state := GameState.new()
	var safe_sim := FishSimulator.new()
	safe_sim.set_seed(1104)
	var it_pike := safe_state.get_holder_item("rod_-3")
	var rd_pike := safe_state.get_rod_state(it_pike.id)
	rd_pike.planer.line_out = 16.0
	rd_pike.drag_setting = 0.0
	var tired_pike := safe_sim.force_bite(safe_state, rod_sim, it_pike.id, FishState.SPECIES_PIKE, 4.5)
	tired_pike.stamina = 0.0
	tired_pike.hooked_time = 10.0

	var it_perch := safe_state.get_holder_item("rod_+3")
	var rd_perch := safe_state.get_rod_state(it_perch.id)
	rd_perch.planer.line_out = 16.0
	rd_perch.drag_setting = 0.0
	var perch := safe_sim.force_bite(safe_state, rod_sim, it_perch.id, FishState.SPECIES_PERCH, 0.5)
	perch.hooked_time = 10.0

	for _i in range(300):
		safe_sim.step(safe_state, {}, rod_sim, FishSimulator.FIXED_DELTA)

	assert_true(safe_state.has_fish_on_rod(it_pike.id), "Exhausted pike stays hooked even with 0 N slack line")
	assert_true(safe_state.has_fish_on_rod(it_perch.id), "Small perch stays hooked even with 0 N slack line")


func test_given_drag_input_when_synced_over_network_then_drag_adjusts_interpolates_and_renders_hud() -> void:
	# Part A: Local drag adjustment in holder (empty-handed) and in hand (hooked) clamped to [0, 125]
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	var p1 := state.ensure_player(1)
	p1.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 0.8)

	var item := state.get_holder_item("rod_-3")
	var rod := state.get_rod_state(item.id)
	assert_almost_eq(rod.drag_setting, 60.0, 0.01, "Default drag_setting starts at 60 N")

	var tighten_in := PlayerInput.new()
	tighten_in.drag_input = 1.0
	for _i in range(150):
		rod_sim.step(state, {1: tighten_in}, RodSimulator.FIXED_DELTA)
	assert_almost_eq(rod.drag_setting, 125.0, 0.01, "Tightening drag_input clamps at 125 N max")

	# Pick up hooked rod and loosen drag down to 0 N
	item.carrier_peer_id = 1
	item.holder_id = ""
	rod.planer.line_out = 15.0
	fish_sim.force_bite(state, rod_sim, item.id, FishState.SPECIES_PERCH)
	var loosen_in := PlayerInput.new()
	loosen_in.drag_input = -1.0
	for _i in range(250):
		rod_sim.step(state, {1: loosen_in}, RodSimulator.FIXED_DELTA)
	assert_almost_eq(rod.drag_setting, 0.0, 0.01, "Loosening hooked carried rod clamps at 0 N min")

	# Part B: Network drag_input, RodState.copy_from, and SnapshotInterpolator
	var host_net := NetworkManager.new()
	host_net.configure_from_args(PackedStringArray(["--host", "--sync-hz", "60"]))
	var host_state := GameState.new()
	var host_p2 := host_state.ensure_player(2)
	host_p2.local_position = Vector3(1.3, CrewSimulator.DECK_SURFACE_Y, 0.8)
	var item_r3 := host_state.get_holder_item("rod_+3")
	var rod_r3 := host_state.get_rod_state(item_r3.id)
	var drag_before := rod_r3.drag_setting

	host_net.receive_client_input(2, {
		"throttle": 0.0, "steering": 0.0, "move_x": 0.0, "move_z": 0.0,
		"interact": false, "interact_held": false, "line_input": 0.0, "drag_input": 1.0,
	})
	var boat_sim := BoatSimulator.new()
	var crew_sim := CrewSimulator.new()
	var st_sim := StationSimulator.new()
	var it_sim := ItemSimulator.new(host_state.item_config)
	var snap: Dictionary = {}
	for _i in range(3):
		snap = host_net.step_game_tick(host_state, PlayerInput.new(), boat_sim, crew_sim, st_sim, it_sim, rod_sim, fish_sim)
	assert_true(rod_r3.drag_setting > drag_before, "Client drag_input adjusts rod drag_setting on host")

	var copy_target := RodState.new()
	copy_target.copy_from(rod_r3)
	assert_almost_eq(copy_target.drag_setting, rod_r3.drag_setting, 0.001, "RodState.copy_from copies drag_setting")

	var sa := GameState.new()
	sa.tick = 6
	var ra := sa.get_rod_state(item_r3.id)
	ra.line_tension = 20.0
	ra.drag_setting = 50.0
	ra.line_remaining_on_spool = 140.0
	ra.line_integrity = 0.90
	ra.is_drag_slipping = false

	var sb := GameState.new()
	sb.tick = 12
	var rb := sb.get_rod_state(item_r3.id)
	rb.line_tension = 60.0
	rb.drag_setting = 70.0
	rb.line_remaining_on_spool = 120.0
	rb.line_integrity = 0.70
	rb.is_drag_slipping = true

	var interp := SnapshotInterpolator.new()
	interp.push_snapshot(sa.to_dict())
	interp.push_snapshot(sb.to_dict())
	var out := GameState.new()
	assert_true(interp.sample_at(out, 0.15, true), "SnapshotInterpolator samples RodState tension fields")
	var out_r := out.get_rod_state(item_r3.id)
	assert_almost_eq(out_r.line_tension, 40.0, 0.1, "line_tension interpolates smoothly")
	assert_almost_eq(out_r.drag_setting, 60.0, 0.1, "drag_setting interpolates smoothly")
	assert_almost_eq(out_r.line_remaining_on_spool, 130.0, 0.1, "line_remaining_on_spool interpolates smoothly")
	assert_almost_eq(out_r.line_integrity, 0.80, 0.01, "line_integrity interpolates smoothly")
	assert_true(out_r.is_drag_slipping, "Discrete is_drag_slipping follows latest snapshot")
	host_net.free()

	# Part C: WorldView line_prompt displays [Z/X], drag (N), tension (%), spool (m), and [RÄIKKÄ!]
	var view_state := GameState.new()
	var vp1 := view_state.ensure_player(1)
	vp1.local_position = Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, 0.0)
	var v_item := view_state.get_holder_item("rod_-3")
	var v_rod := view_state.get_rod_state(v_item.id)
	v_item.carrier_peer_id = 1
	v_item.holder_id = ""
	v_rod.planer.line_out = 18.0
	v_rod.planer.state = PlanerBoard.STATE_TRIPPED
	v_rod.line_tension = 60.0
	v_rod.line_max_strength = 100.0
	v_rod.drag_setting = 75.0
	v_rod.line_remaining_on_spool = 120.0
	v_rod.is_drag_slipping = true
	fish_sim.force_bite(view_state, rod_sim, v_item.id, FishState.SPECIES_PIKE, 5.0)

	var world := WorldView.new()
	world.apply_game_state(view_state, "", 1, true)
	var prompt_txt := world.line_prompt_label.text
	assert_true(prompt_txt.contains("[Z/X]"), "line_prompt shows [Z/X] drag hint")
	assert_true(prompt_txt.contains("75"), "line_prompt shows drag_setting in N")
	assert_true(prompt_txt.contains("60%"), "line_prompt shows tension percentage")
	assert_true(prompt_txt.contains("120"), "line_prompt shows remaining spool length")
	assert_true(prompt_txt.contains("RÄIKKÄ"), "line_prompt shows RÄIKKÄ warning when slipping")
	free_node(world)
