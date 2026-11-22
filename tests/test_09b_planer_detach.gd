extends "res://tests/test_case.gd"


func test_reel_stops_at_detach_lock_and_straight_rod_unaffected() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	fish_sim.set_seed(501)

	state.boat.forward_speed = 3.0
	var p1 := state.ensure_player(1)
	p1.local_position = Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, 1.2)

	var item_planer := state.get_holder_item("rod_-3")
	var rod_planer := state.get_rod_state(item_planer.id)
	item_planer.carrier_peer_id = 1
	item_planer.holder_id = ""
	rod_planer.planer.attached = true
	rod_planer.planer.line_out = 10.0
	rod_planer.planer.lateral_offset = -5.0
	rod_planer.planer.state = PlanerBoard.STATE_TROLLING
	var f_planer := fish_sim.force_bite(state, rod_sim, item_planer.id, FishState.SPECIES_PIKE, 5.0)
	f_planer.stamina = 0.0
	f_planer.surge_timer = 0.0

	var reel_and_hold := PlayerInput.new()
	reel_and_hold.line_input = -1.0
	reel_and_hold.interact_held = true
	for _i in range(240):
		rod_sim.step(state, {1: reel_and_hold}, RodSimulator.FIXED_DELTA)
		fish_sim.step(state, {1: reel_and_hold}, rod_sim, FishSimulator.FIXED_DELTA)

	assert_true(rod_planer.planer.attached, "Planer remains attached at detach lock")
	assert_almost_eq(rod_planer.planer.line_out, fish_sim.config.detach_distance, 0.05, "In-hand reel stops at 2.0 m detach lock")
	assert_eq(f_planer.state, FishState.STATE_HOOKED, "Fish stays HOOKED until planer is detached")
	assert_almost_eq(f_planer.detach_progress, 0.0, 0.001, "Carrier cannot self-detach planer while holding rod")

	# Switch to straight stern rod (attached == false): reels directly past 2.0 m into READY_TO_LAND (1.5 m)
	item_planer.carrier_peer_id = 0
	item_planer.holder_id = "rod_-3"
	var item_straight := state.get_holder_item("rod_-1")
	var rod_straight := state.get_rod_state(item_straight.id)
	item_straight.carrier_peer_id = 1
	item_straight.holder_id = ""
	rod_straight.planer.attached = false
	rod_straight.planer.line_out = 10.0
	rod_straight.planer.state = PlanerBoard.STATE_TROLLING
	var f_straight := fish_sim.force_bite(state, rod_sim, item_straight.id, FishState.SPECIES_PERCH, 0.6)

	var reel_in := PlayerInput.new()
	reel_in.line_input = -1.0
	for _i in range(240):
		rod_sim.step(state, {1: reel_in}, RodSimulator.FIXED_DELTA)
		fish_sim.step(state, {1: reel_in}, rod_sim, FishSimulator.FIXED_DELTA)
		if f_straight.is_ready_to_land():
			break

	assert_eq(f_straight.state, FishState.STATE_READY_TO_LAND, "Straight-line rod bypasses detach lock to READY_TO_LAND")
	assert_almost_eq(rod_straight.planer.line_out, fish_sim.config.ready_to_land_distance, 0.05, "Straight-line rod stops at 1.5 m")


func test_solo_holder_detach_blocks_pickup_fills_meter_and_unlocks_reel() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var item_sim := ItemSimulator.new(state.item_config)
	var fish_sim := FishSimulator.new()
	fish_sim.set_seed(502)

	state.boat.forward_speed = 3.0
	var p1 := state.ensure_player(1)
	p1.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 0.8)

	var item := state.get_holder_item("rod_-3")
	var rod := state.get_rod_state(item.id)
	rod.planer.attached = true
	rod.planer.line_out = fish_sim.config.detach_distance
	rod.planer.lateral_offset = -1.2
	rod.planer.state = PlanerBoard.STATE_TROLLING
	var fish := fish_sim.force_bite(state, rod_sim, item.id, FishState.SPECIES_PIKE, 5.5)
	fish.stamina = 0.0
	fish.surge_timer = 0.0

	var hold_in := PlayerInput.new()
	hold_in.interact = true
	hold_in.interact_held = true

	for i in range(24):
		item_sim.step(state, {1: hold_in}, ItemSimulator.FIXED_DELTA)
		rod_sim.step(state, {1: hold_in}, RodSimulator.FIXED_DELTA)
		fish_sim.step(state, {1: hold_in}, rod_sim, FishSimulator.FIXED_DELTA)
		if i == 0:
			assert_true(not item.is_carried(), "ItemSimulator blocks rod pickup while rod is detach-ready in holder")

	assert_true(fish.detach_progress > 0.35 and fish.detach_progress < 0.75, "Holding E for 0.4s fills detach_progress partway (%.2f)" % fish.detach_progress)
	var mid_progress := fish.detach_progress

	var release_in := PlayerInput.new()
	for _i in range(15):
		fish_sim.step(state, {1: release_in}, rod_sim, FishSimulator.FIXED_DELTA)
	assert_true(fish.detach_progress < mid_progress - 0.15, "Releasing E decays detach_progress")

	for _i in range(55):
		item_sim.step(state, {1: hold_in}, ItemSimulator.FIXED_DELTA)
		rod_sim.step(state, {1: hold_in}, RodSimulator.FIXED_DELTA)
		fish_sim.step(state, {1: hold_in}, rod_sim, FishSimulator.FIXED_DELTA)
		if not rod.planer.attached:
			break

	assert_true(not rod.planer.attached, "Holding E completes planer detach in holder")
	assert_almost_eq(rod.planer.line_out, 8.0, 0.2, "Planer detach adds 6.0 m leader length")
	assert_almost_eq(fish.detach_progress, 0.0, 0.001, "Completed detach resets detach_progress")
	assert_almost_eq(rod.planer.pull_back_offset, 0.0, 0.001, "Completed detach resets pull_back_offset")
	assert_almost_eq(rod.planer.submersion, 0.0, 0.001, "Completed detach resets submersion")
	assert_almost_eq(rod.planer.flag_angle, 0.0, 0.001, "Completed detach resets flag_angle")
	assert_almost_eq(rod.planer.shake_intensity, 0.0, 0.001, "Completed detach resets shake_intensity")
	assert_almost_eq(rod.planer.inward_drift_force, 0.0, 0.001, "Completed detach resets inward_drift_force")
	assert_true(fish.surfaced, "Fish surfaces once planer is detached")
	assert_true(state.fish_notice_text.contains("Plaanari irrotettu"), "Completed detach sets HUD notice")

	var pickup_in := PlayerInput.new()
	pickup_in.interact = true
	item_sim.step(state, {1: pickup_in}, ItemSimulator.FIXED_DELTA)
	assert_true(state.get_player_held_item(1) == item, "After detach, player can pick up the rod again")

	var reel_in := PlayerInput.new()
	reel_in.line_input = -1.0
	for _i in range(240):
		rod_sim.step(state, {1: reel_in}, RodSimulator.FIXED_DELTA)
		fish_sim.step(state, {1: reel_in}, rod_sim, FishSimulator.FIXED_DELTA)
		if fish.is_ready_to_land():
			break
	assert_eq(fish.state, FishState.STATE_READY_TO_LAND, "Detached rod reels remaining leader to READY_TO_LAND")
	assert_almost_eq(rod.planer.line_out, fish_sim.config.ready_to_land_distance, 0.05, "Line stops at 1.5 m ready_to_land_distance")


func test_coop_teammate_detaches_while_carrier_holds_rod_with_range_and_hands_checks() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var item_sim := ItemSimulator.new(state.item_config)
	var fish_sim := FishSimulator.new()
	fish_sim.set_seed(503)

	state.boat.forward_speed = 3.0
	var p1 := state.ensure_player(1)
	var p2 := state.ensure_player(2)
	p1.local_position = Vector3(-0.8, CrewSimulator.DECK_SURFACE_Y, 2.1)

	var item_l3 := state.get_holder_item("rod_-3")
	var rod_l3 := state.get_rod_state(item_l3.id)
	item_l3.carrier_peer_id = 1
	item_l3.holder_id = ""
	rod_l3.planer.attached = true
	rod_l3.planer.line_out = fish_sim.config.detach_distance
	rod_l3.planer.lateral_offset = -1.2
	rod_l3.planer.state = PlanerBoard.STATE_TROLLING
	var f_pike := fish_sim.force_bite(state, rod_sim, item_l3.id, FishState.SPECIES_PIKE, 7.0)
	f_pike.stamina = 1.0
	f_pike.surge_timer = 5.0

	var hold_in := PlayerInput.new()
	hold_in.interact = true
	hold_in.interact_held = true

	# 1) Far away (> 1.6 m): teammate cannot detach
	p2.local_position = Vector3(1.2, CrewSimulator.DECK_SURFACE_Y, 2.1)
	for _i in range(20):
		fish_sim.step(state, {2: hold_in}, rod_sim, FishSimulator.FIXED_DELTA)
	assert_almost_eq(f_pike.detach_progress, 0.0, 0.001, "Teammate out of range (> 1.6 m) cannot detach planer")

	# 2) In range (<= 1.6 m) but holding another rod: teammate cannot detach
	var item_r3 := state.get_holder_item("rod_+3")
	item_r3.carrier_peer_id = 2
	item_r3.holder_id = ""
	p2.local_position = Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, 2.1)
	for _i in range(20):
		fish_sim.step(state, {2: hold_in}, rod_sim, FishSimulator.FIXED_DELTA)
	assert_almost_eq(f_pike.detach_progress, 0.0, 0.001, "Teammate holding another item cannot detach planer")

	# 3) Empty-handed teammate next to carrier (and near occupied holder rod_-2) does NOT steal rod_-2, freezes drag slip, and detaches planer
	item_r3.carrier_peer_id = 0
	item_r3.holder_id = "rod_+3"
	rod_l3.planer.line_out = fish_sim.config.detach_distance
	f_pike.surge_timer = 5.0
	p2.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 2.1)

	for i in range(55):
		item_sim.step(state, {2: hold_in}, ItemSimulator.FIXED_DELTA)
		rod_sim.step(state, {2: hold_in}, RodSimulator.FIXED_DELTA)
		fish_sim.step(state, {2: hold_in}, rod_sim, FishSimulator.FIXED_DELTA)
		if i == 0:
			assert_true(state.get_player_held_item(2) == null, "Co-op helper E does not steal adjacent idle rod_-2")
			assert_true(f_pike.drag_rate > 0.0, "Surging pike has active drag while being detached")
			assert_almost_eq(rod_l3.planer.line_out, fish_sim.config.detach_distance, 0.02, "Active detach pauses drag slip")
		if not rod_l3.planer.attached:
			break

	assert_true(not rod_l3.planer.attached, "Co-op teammate completes planer detach while carrier holds rod")
	assert_true(rod_l3.planer.line_out > 6.0, "Co-op detach adds leader length cleanly")
	assert_true(state.get_player_held_item(1) == item_l3, "Carrier keeps holding rod_-3 throughout co-op detach")


func test_network_replicates_interact_held_and_interpolates_detach_progress() -> void:
	var pi := PlayerInput.new()
	pi.interact_held = true
	var pi_roundtrip := PlayerInput.new()
	pi_roundtrip.from_dict(pi.to_dict())
	assert_true(pi_roundtrip.interact_held, "PlayerInput to_dict/from_dict preserves interact_held=true")
	pi.interact_held = false
	pi_roundtrip.from_dict(pi.to_dict())
	assert_true(not pi_roundtrip.interact_held, "PlayerInput to_dict/from_dict preserves interact_held=false")

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
	var fish_sim := FishSimulator.new()
	fish_sim.set_seed(504)
	var host_input := PlayerInput.new()

	var p2 := host_state.ensure_player(2)
	p2.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 0.8)
	var l3_id := host_state.get_holder_item("rod_-3").id
	var host_rod := host_state.get_rod_state(l3_id)
	host_rod.planer.attached = true
	host_rod.planer.line_out = fish_sim.config.detach_distance
	host_rod.planer.state = PlanerBoard.STATE_TROLLING
	var host_fish := fish_sim.force_bite(host_state, rod_sim, l3_id, FishState.SPECIES_PIKE, 4.5)
	host_fish.stamina = 0.0
	host_fish.surge_timer = 0.0

	host_net.receive_client_input(2, {
		"throttle": 0.0,
		"steering": 0.0,
		"move_x": 0.0,
		"move_z": 0.0,
		"interact": false,
		"interact_held": true,
		"line_input": 0.0,
	})

	var snap: Dictionary = {}
	for _i in range(24):
		snap = host_net.step_game_tick(host_state, host_input, boat_sim, crew_sim, station_sim, item_sim, rod_sim, fish_sim)
	assert_true(host_fish.detach_progress > 0.35 and host_fish.detach_progress < 0.75, "Host preserves interact_held across ticks without clearing it")

	client_net.apply_game_snapshot(client_state, snap)
	assert_almost_eq(client_state.get_fish_state(l3_id).detach_progress, host_fish.detach_progress, 0.001, "Client replicates detach_progress")

	for _i in range(36):
		snap = host_net.step_game_tick(host_state, host_input, boat_sim, crew_sim, station_sim, item_sim, rod_sim, fish_sim)
		if not host_rod.planer.attached:
			break
	assert_true(not host_rod.planer.attached, "Continued held client input finishes detach on host")
	client_net.apply_game_snapshot(client_state, snap)
	assert_true(not client_state.get_rod_state(l3_id).planer.attached, "Client replicates completed detach")
	assert_true(client_state.get_rod_state(l3_id).planer.line_out > 6.0, "Client replicates post-detach leader line length")

	var sa := GameState.new()
	sa.tick = 6
	var fa := fish_sim.force_bite(sa, rod_sim, l3_id, FishState.SPECIES_PIKE, 4.5)
	fa.detach_progress = 0.2

	var sb := GameState.new()
	sb.tick = 12
	var fb := fish_sim.force_bite(sb, rod_sim, l3_id, FishState.SPECIES_PIKE, 4.5)
	fb.detach_progress = 0.8

	var interp := SnapshotInterpolator.new()
	interp.push_snapshot(sa.to_dict())
	interp.push_snapshot(sb.to_dict())
	var out := GameState.new()
	assert_true(interp.sample_at(out, 0.15, true), "SnapshotInterpolator samples FishState detach_progress")
	assert_almost_eq(out.get_fish_state(l3_id).detach_progress, 0.5, 0.01, "detach_progress interpolates smoothly to midpoint 0.5")

	host_net.free()
	client_net.free()


func test_world_view_shows_detach_lock_coop_prompts_progress_and_highlight() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	var world := WorldView.new()

	var p1 := state.ensure_player(1)
	var p2 := state.ensure_player(2)
	p1.local_position = Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, 1.5)
	p2.local_position = Vector3(0.8, CrewSimulator.DECK_SURFACE_Y, 1.5)

	var item_l3 := state.get_holder_item("rod_-3")
	var rod_l3 := state.get_rod_state(item_l3.id)
	item_l3.carrier_peer_id = 1
	item_l3.holder_id = ""
	rod_l3.planer.attached = true
	rod_l3.planer.line_out = fish_sim.config.detach_distance
	rod_l3.planer.lateral_offset = -1.2
	rod_l3.planer.state = PlanerBoard.STATE_TRIPPED
	rod_l3.trail_factor = 1.0
	var f_pike := fish_sim.force_bite(state, rod_sim, item_l3.id, FishState.SPECIES_PIKE, 5.0)

	# 1) Carrier perspective + green highlight
	world.apply_game_state(state, "", 1, true)
	assert_true(world.line_prompt_label.text.contains("PLAANARI LAIDALLA"), "Carrier sees PLAANARI LAIDALLA detach lock guidance")
	var planer_node := world.planers_container.get_node_or_null("Planer_%s" % item_l3.id) as Node3D
	assert_true(planer_node != null, "Detach-ready planer node exists")
	var body_mesh := planer_node.get_node_or_null("Body") as MeshInstance3D
	var body_mat := body_mesh.material_override as StandardMaterial3D if body_mesh != null else null
	assert_true(body_mat != null and body_mat.albedo_color.g > 0.8 and body_mat.albedo_color.r < 0.5, "Detach-ready planer highlights green")

	# 2) Co-op helper perspective with detach_progress = 0.5
	f_pike.detach_progress = 0.5
	world.apply_game_state(state, "", 2, true)
	assert_true(world.prompt_label.text.contains("[Pidä E]") and world.prompt_label.text.contains("50%"), "Co-op helper prompt shows [Pidä E] and 50%")
	assert_true(world.line_prompt_label.text.contains("50%"), "Co-op helper line_prompt shows 50% progress")

	# 3) Solo at holder with detach_progress = 0.25
	item_l3.carrier_peer_id = 0
	item_l3.holder_id = "rod_-3"
	p1.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 0.8)
	f_pike.detach_progress = 0.25
	world.apply_game_state(state, "", 1, true)
	assert_true(world.prompt_label.text.contains("[Pidä E]") and world.prompt_label.text.contains("25%"), "Solo holder prompt shows [Pidä E] and 25%")
	assert_true(not world.prompt_label.text.contains("Poimi vapa"), "Detach-ready holder does not prompt Poimi vapa")
	assert_true(world.line_prompt_label.text.contains("25%"), "Solo holder line_prompt shows 25% progress")

	# 4) After detach completed
	rod_l3.planer.attached = false
	rod_l3.planer.line_out = 8.0
	f_pike.detach_progress = 0.0
	world.apply_game_state(state, "", 1, true)
	assert_eq(world.get_visible_planer_count(), 0, "Detached planer disappears from PlanersContainer")

	free_node(world)
