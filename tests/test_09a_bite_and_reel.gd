extends "res://tests/test_case.gd"


func test_bite_generation_quiet_water_bonus_species_and_planer_trip_tiers() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var cfg := FishSimulator.Config.new()
	cfg.base_bite_rate_per_rod = 2.0
	var fish_sim := FishSimulator.new(cfg)
	fish_sim.set_seed(12345)

	var item_l3 := state.get_holder_item("rod_-3")
	var item_l2 := state.get_holder_item("rod_-2")
	var item_r2 := state.get_holder_item("rod_+2")
	var item_l1 := state.get_holder_item("rod_-1")
	var rod_l3 := state.get_rod_state(item_l3.id)
	var rod_l2 := state.get_rod_state(item_l2.id)
	var rod_r2 := state.get_rod_state(item_r2.id)
	var rod_l1 := state.get_rod_state(item_l1.id)

	# Quiet-water trolling planer (-3) vs straight stern (-1); short (-2) and tangled (+2) ineligible
	rod_l3.planer.attached = true
	rod_l3.planer.line_out = 20.0
	rod_l3.planer.lateral_offset = -10.0
	rod_l3.planer.state = PlanerBoard.STATE_TROLLING

	rod_l2.planer.attached = true
	rod_l2.planer.line_out = 3.0
	rod_l2.planer.state = PlanerBoard.STATE_DEPLOYING

	rod_r2.planer.attached = true
	rod_r2.planer.line_out = 20.0
	rod_r2.planer.state = PlanerBoard.STATE_TANGLED

	rod_l1.planer.attached = false
	rod_l1.planer.line_out = 18.0
	rod_l1.planer.state = PlanerBoard.STATE_TROLLING

	assert_true(
		rod_sim.get_bite_probability_multiplier(rod_l3) > rod_sim.get_bite_probability_multiplier(rod_l1),
		"Quiet-water trolling planer has higher bite multiplier than straight stern rod"
	)

	# Stopped boat never spawns natural bites
	state.boat.forward_speed = 0.0
	for _i in range(60):
		fish_sim.step(state, {}, rod_sim, FishSimulator.FIXED_DELTA)
	assert_eq(state.get_hooked_fish_count(), 0, "Stopped boat generates zero automatic bites")

	# Moving boat spawns bites only on eligible rods and allows simultaneous bites
	state.boat.forward_speed = 3.0
	for _i in range(180):
		fish_sim.step(state, {}, rod_sim, FishSimulator.FIXED_DELTA)
	assert_eq(state.get_hooked_fish_count(), 2, "Both eligible rods receive simultaneous bites")
	assert_true(state.has_fish_on_rod(item_l3.id), "Eligible planer rod -3 receives a bite")
	assert_true(state.has_fish_on_rod(item_l1.id), "Eligible stern rod -1 receives a bite")
	assert_true(not state.has_fish_on_rod(item_l2.id), "Short line < 5m does not receive automatic bite")
	assert_true(not state.has_fish_on_rod(item_r2.id), "Tangled rod does not receive automatic bite")

	# Species tier verification: vendace/perch keep planer untripped, zander+ trip planer
	var tier_state := GameState.new()
	var tier_sim := FishSimulator.new()
	tier_sim.set_seed(77)
	var holder_species := [
		["rod_-3", FishState.SPECIES_VENDACE, false],
		["rod_-2", FishState.SPECIES_PERCH, false],
		["rod_+2", FishState.SPECIES_ZANDER, true],
		["rod_+3", FishState.SPECIES_PIKE, true],
		["rod_-1", FishState.SPECIES_ORCA, true],
		["rod_+1", FishState.SPECIES_BLUE_WHALE, true],
	]
	for entry in holder_species:
		var hid := str(entry[0])
		var sp := str(entry[1])
		var expect_trip := bool(entry[2])
		var item := tier_state.get_holder_item(hid)
		var rod := tier_state.get_rod_state(item.id)
		rod.planer.line_out = 18.0
		rod.planer.state = PlanerBoard.STATE_TROLLING
		var f := tier_sim.force_bite(tier_state, rod_sim, item.id, sp)
		assert_true(f != null and f.species == sp, "Forced bite spawns species %s" % sp)
		assert_true(f.weight_kg > 0.0, "Spawned %s has positive weight" % sp)
		if rod.planer.attached:
			if expect_trip:
				assert_eq(rod.planer.state, PlanerBoard.STATE_TRIPPED, "%s trips planer board" % sp)
			else:
				assert_eq(rod.planer.state, PlanerBoard.STATE_TROLLING, "%s does NOT trip planer board" % sp)


func test_drag_raikka_stamina_jumps_and_resisting_shakeoff() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	fish_sim.set_seed(2026)

	var item_vendace := state.get_holder_item("rod_-3")
	var item_perch := state.get_holder_item("rod_-2")
	var item_zander := state.get_holder_item("rod_+2")
	var item_whale := state.get_holder_item("rod_+3")

	for item in [item_vendace, item_perch, item_zander, item_whale]:
		var r := state.get_rod_state(item.id)
		r.planer.line_out = 16.0
		r.planer.state = PlanerBoard.STATE_TROLLING

	var f_vendace := fish_sim.force_bite(state, rod_sim, item_vendace.id, FishState.SPECIES_VENDACE)
	var f_perch := fish_sim.force_bite(state, rod_sim, item_perch.id, FishState.SPECIES_PERCH)
	var f_zander := fish_sim.force_bite(state, rod_sim, item_zander.id, FishState.SPECIES_ZANDER)
	var f_whale := fish_sim.force_bite(state, rod_sim, item_whale.id, FishState.SPECIES_BLUE_WHALE)

	assert_true(f_vendace.stamina <= 0.01, "Vendace tires out immediately")
	assert_true(f_perch.stamina <= 0.01, "Perch tires out immediately")

	# Zander calm outside surge, gentle drag during surge
	f_zander.surge_timer = 0.0
	f_zander.surge_cooldown = 10.0
	fish_sim.step(state, {}, rod_sim, FishSimulator.FIXED_DELTA)
	assert_almost_eq(f_zander.drag_rate, 0.0, 0.001, "Calm zander does not slip reel drag")
	f_zander.surge_timer = 1.5
	fish_sim.step(state, {}, rod_sim, FishSimulator.FIXED_DELTA)
	assert_true(f_zander.drag_rate > 0.0 and f_zander.drag_rate < 1.0, "Surging zander gently slips drag")

	# Blue whale pulls drag within cap, slips line when unreeled, and jumps
	var whale_line_before := state.get_rod_state(item_whale.id).planer.line_out
	var saw_jump := false
	for _i in range(420):
		fish_sim.step(state, {}, rod_sim, FishSimulator.FIXED_DELTA)
		if state.has_fish_on_rod(item_whale.id) and f_whale.is_jumping():
			saw_jump = true
			assert_true(FishSimulator.get_fish_jump_height_offset(f_whale) > 0.1, "Jumping whale rises above water")
	assert_true(saw_jump, "Large resisting fish/whale performs breach jumps")
	assert_true(state.get_rod_state(item_whale.id).planer.line_out > whale_line_before, "Unreeled whale pulls line out over drag")
	assert_true(f_whale.drag_rate <= fish_sim.config.max_drag_slip_speed + 0.001, "Drag slip speed respects configured cap")

	# Vendace and perch never pull line or shake off over 25 seconds
	for _i in range(1100):
		fish_sim.step(state, {}, rod_sim, FishSimulator.FIXED_DELTA)
	assert_true(state.has_fish_on_rod(item_vendace.id), "Tired vendace does not shake off")
	assert_true(state.has_fish_on_rod(item_perch.id), "Tired perch does not shake off")
	assert_almost_eq(state.get_rod_state(item_vendace.id).planer.line_out, 16.0, 0.001, "Vendace never pulls line")

	# Grace period vs random resisting shake-off
	var risk_cfg := FishSimulator.Config.new()
	risk_cfg.grace_period_sec = 7.0
	risk_cfg.shakeoff_chance_per_sec = 4.0
	var risk_sim := FishSimulator.new(risk_cfg)
	risk_sim.set_seed(99)
	var risk_state := GameState.new()
	var p_item := risk_state.get_holder_item("rod_-3")
	risk_state.get_rod_state(p_item.id).planer.line_out = 18.0
	var f_pike := risk_sim.force_bite(risk_state, rod_sim, p_item.id, FishState.SPECIES_PIKE)
	f_pike.surge_timer = 20.0

	for _i in range(360):
		risk_sim.step(risk_state, {}, rod_sim, FishSimulator.FIXED_DELTA)
	assert_true(risk_state.has_fish_on_rod(p_item.id), "Grace period prevents early shake-off before 7s")

	for _i in range(360):
		risk_sim.step(risk_state, {}, rod_sim, FishSimulator.FIXED_DELTA)
		if not risk_state.has_fish_on_rod(p_item.id):
			break
	assert_true(not risk_state.has_fish_on_rod(p_item.id), "Resisting fish can shake off after grace period")
	assert_true(not risk_state.fish_notice_text.is_empty(), "Shake-off updates fish_notice_text")

	# Exhausted pike never shakes off even after grace period
	var tired_item := risk_state.get_holder_item("rod_+3")
	risk_state.get_rod_state(tired_item.id).planer.line_out = 18.0
	var f_tired := risk_sim.force_bite(risk_state, rod_sim, tired_item.id, FishState.SPECIES_PIKE)
	f_tired.stamina = 0.0
	f_tired.hooked_time = 10.0
	for _i in range(300):
		risk_sim.step(risk_state, {}, rod_sim, FishSimulator.FIXED_DELTA)
	assert_true(risk_state.has_fish_on_rod(tired_item.id), "Exhausted pike with stamina=0 never shakes off")


func test_in_hand_reel_auto_planer_bypass_no_false_tangle_and_carry_persistence() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var item_sim := ItemSimulator.new(state.item_config)
	var fish_sim := FishSimulator.new()
	fish_sim.set_seed(303)

	state.boat.forward_speed = 3.0
	state.boat.velocity = Vector2(0.0, -3.0)
	var p1 := state.ensure_player(1)
	p1.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 0.8)

	var item_l3 := state.get_holder_item("rod_-3")
	var item_l2 := state.get_holder_item("rod_-2")
	var rod_l3 := state.get_rod_state(item_l3.id)
	var rod_l2 := state.get_rod_state(item_l2.id)

	rod_l3.planer.line_out = 16.0
	rod_l3.planer.lateral_offset = -9.0
	rod_l3.planer.state = PlanerBoard.STATE_TROLLING
	rod_l3.trail_factor = 1.0
	rod_l2.planer.line_out = 12.0
	rod_l2.planer.lateral_offset = -6.0
	rod_l2.planer.state = PlanerBoard.STATE_TROLLING
	rod_l2.trail_factor = 1.0

	var fish := fish_sim.force_bite(state, rod_sim, item_l3.id, FishState.SPECIES_PIKE)
	fish.stamina = 0.0
	fish.surge_timer = 0.0
	assert_eq(rod_l3.planer.state, PlanerBoard.STATE_TRIPPED, "Pike trips planer on rod_-3")

	# Reeling at holder without picking up rod is ignored
	var reel_in := PlayerInput.new()
	reel_in.line_input = -1.0
	for _i in range(60):
		rod_sim.step(state, {1: reel_in}, RodSimulator.FIXED_DELTA)
		fish_sim.step(state, {1: reel_in}, rod_sim, FishSimulator.FIXED_DELTA)
	assert_almost_eq(rod_l3.planer.line_out, 16.0, 0.05, "Hooked rod cannot be reeled while resting in holder")

	# Sharp turn does not falsely tangle hooked TRIPPED planer rod
	state.boat.angular_velocity = 0.75
	for _i in range(120):
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)
		fish_sim.step(state, {}, rod_sim, FishSimulator.FIXED_DELTA)
	assert_true(rod_l3.planer.state != PlanerBoard.STATE_TANGLED, "Hooked planer rod is protected from false tangles")
	state.boat.angular_velocity = 0.0

	# Pick up rod, walk to center, place down and disconnect -> FishState persists
	var interact_in := PlayerInput.new()
	interact_in.interact = true
	item_sim.step(state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	assert_true(state.get_player_held_item(1) == item_l3, "Player 1 picks up hooked rod_-3")

	p1.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 0.8)
	item_sim.step(state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	assert_true(state.has_fish_on_rod(item_l3.id), "Placing rod back into holder preserves FishState")
	item_sim.step(state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	state.remove_player(1)
	assert_true(state.has_fish_on_rod(item_l3.id), "Player disconnect preserves FishState on returned rod")

	p1 = state.ensure_player(1)
	p1.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 0.8)
	item_sim.step(state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	p1.local_position = Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, 0.0)

	# Reel in hand: auto planer bypass at <= 2.0m, surface at <= 8.0m, stop at READY_TO_LAND
	var saw_bypass := false
	for _i in range(420):
		rod_sim.step(state, {1: reel_in}, RodSimulator.FIXED_DELTA)
		fish_sim.step(state, {1: reel_in}, rod_sim, FishSimulator.FIXED_DELTA)
		if not rod_l3.planer.attached and not saw_bypass:
			saw_bypass = true
			assert_true(rod_l3.planer.line_out > 6.0, "Auto planer bypass adds leader_length cleanly")
			assert_true(fish.surfaced, "Fish surfaces after planer bypass within 8m")
		if fish.is_ready_to_land():
			break

	assert_true(saw_bypass, "Planer auto-bypass occurred during S9a reel-in")
	assert_eq(fish.state, FishState.STATE_READY_TO_LAND, "Reeling stops cleanly at READY_TO_LAND")
	assert_almost_eq(rod_l3.planer.line_out, fish_sim.config.ready_to_land_distance, 0.05, "Line stops at ready_to_land_distance (1.5 m)")

	var world_2d := fish_sim.get_fish_world_pos_2d(state, item_l3, rod_l3, fish, rod_sim)
	var rel_3d := (Vector3(world_2d.x, 0.0, world_2d.y) - state.boat.world_position).rotated(Vector3.UP, -state.boat.heading)
	assert_true(absf(rel_3d.x) >= 1.9 or rel_3d.z >= 3.8, "READY_TO_LAND fish stays clear outside boat hull")


func test_netless_hand_lift_risk_scales_with_size_and_network_sync() -> void:
	var rod_sim := RodSimulator.new()
	var reel_in := PlayerInput.new()
	reel_in.line_input = -1.0

	# Lift progress fills over ~1.2 s holding Space and decays when released
	var meter_state := GameState.new()
	var meter_sim := FishSimulator.new()
	meter_sim.set_seed(55)
	var m_p1 := meter_state.ensure_player(1)
	var m_item := meter_state.get_holder_item("rod_-3")
	var m_rod := meter_state.get_rod_state(m_item.id)
	m_item.carrier_peer_id = 1
	m_item.holder_id = ""
	m_p1.local_position = Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, 0.0)
	m_rod.planer.attached = false
	m_rod.planer.line_out = meter_sim.config.ready_to_land_distance
	var m_fish := meter_sim.force_bite(meter_state, rod_sim, m_item.id, FishState.SPECIES_VENDACE)
	m_fish.state = FishState.STATE_READY_TO_LAND
	m_fish.surfaced = true

	for _i in range(36):
		meter_sim.step(meter_state, {1: reel_in}, rod_sim, FishSimulator.FIXED_DELTA)
	assert_true(m_fish.lift_progress > 0.4 and m_fish.lift_progress < 0.7, "Holding Space 0.6s fills lift_progress partway")
	for _i in range(60):
		meter_sim.step(meter_state, {}, rod_sim, FishSimulator.FIXED_DELTA)
	assert_true(m_fish.lift_progress < 0.2, "Releasing Space decays lift_progress smoothly")

	# Risk scaling across 40 seeded trials: vendace succeeds vastly more than blue whale
	var vendace_landed := 0
	var whale_landed := 0
	for trial in range(40):
		for sp in [FishState.SPECIES_VENDACE, FishState.SPECIES_BLUE_WHALE]:
			var st := GameState.new()
			var sim := FishSimulator.new()
			sim.set_seed(1000 + trial * 17 + (1 if sp == FishState.SPECIES_BLUE_WHALE else 0))
			st.ensure_player(1)
			var it := st.get_holder_item("rod_-3")
			var rd := st.get_rod_state(it.id)
			it.carrier_peer_id = 1
			it.holder_id = ""
			rd.planer.attached = false
			rd.planer.line_out = sim.config.ready_to_land_distance
			var fi := sim.force_bite(st, rod_sim, it.id, sp)
			fi.state = FishState.STATE_READY_TO_LAND
			fi.surfaced = true
			for _i in range(90):
				sim.step(st, {1: reel_in}, rod_sim, FishSimulator.FIXED_DELTA)
				if not st.has_fish_on_rod(it.id):
					break
			assert_true(not st.has_fish_on_rod(it.id), "Completed lift attempt clears FishState")
			assert_almost_eq(rd.planer.line_out, 0.0, 0.001, "Completed lift attempt resets rod to 0.0 m")
			assert_eq(rd.planer.state, PlanerBoard.STATE_STOWED, "Completed lift resets rod to STOWED")
			assert_true(rd.planer.attached, "Side rod restores default planer attachment after lift")
			if st.fish_notice_text.contains("nostettu"):
				if sp == FishState.SPECIES_VENDACE:
					vendace_landed += 1
				else:
					whale_landed += 1

	assert_true(vendace_landed >= 30, "Vendace netless lift succeeds frequently (%d/40)" % vendace_landed)
	assert_true(whale_landed <= 3, "Blue whale netless lift almost always escapes (%d/40)" % whale_landed)

	# Network replication & SnapshotInterpolator for FishState
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
	var net_fish_sim := FishSimulator.new()
	net_fish_sim.set_seed(88)
	var host_input := PlayerInput.new()

	var l3_id := host_state.get_holder_item("rod_-3").id
	host_state.get_rod_state(l3_id).planer.line_out = 18.0
	host_state.get_rod_state(l3_id).planer.state = PlanerBoard.STATE_TROLLING
	net_fish_sim.force_bite(host_state, rod_sim, l3_id, FishState.SPECIES_PIKE)
	host_state.set_fish_notice("Tärppi testissä!", 4.0)

	var snap: Dictionary = {}
	for _i in range(3):
		snap = host_net.step_game_tick(host_state, host_input, boat_sim, crew_sim, station_sim, item_sim, rod_sim, net_fish_sim)
	assert_true(snap.has("fishes"), "Snapshot includes fishes dictionary")
	client_net.apply_game_snapshot(client_state, snap)
	assert_true(client_state.has_fish_on_rod(l3_id), "Client replicates FishState")
	assert_eq(client_state.get_fish_state(l3_id).species, FishState.SPECIES_PIKE, "Client replicates fish species")
	assert_true(client_state.fish_notice_text.contains("Tärppi"), "Client replicates fish_notice_text")

	var sa := GameState.new()
	sa.tick = 6
	var fa := net_fish_sim.force_bite(sa, rod_sim, l3_id, FishState.SPECIES_PIKE)
	fa.stamina = 0.8
	fa.drag_rate = 0.4
	fa.lift_progress = 0.2
	fa.jump_progress = 0.2
	fa.surfaced = false

	var sb := GameState.new()
	sb.tick = 12
	var fb := net_fish_sim.force_bite(sb, rod_sim, l3_id, FishState.SPECIES_PIKE)
	fb.stamina = 0.4
	fb.drag_rate = 1.2
	fb.lift_progress = 0.8
	fb.jump_progress = 0.6
	fb.surfaced = true
	fb.state = FishState.STATE_READY_TO_LAND

	var interp := SnapshotInterpolator.new()
	interp.push_snapshot(sa.to_dict())
	interp.push_snapshot(sb.to_dict())
	var out := GameState.new()
	assert_true(interp.sample_at(out, 0.15, true), "SnapshotInterpolator sample_at succeeds for FishState")
	var out_f := out.get_fish_state(l3_id)
	assert_almost_eq(out_f.stamina, 0.6, 0.01, "stamina interpolates smoothly")
	assert_almost_eq(out_f.drag_rate, 0.8, 0.01, "drag_rate interpolates smoothly")
	assert_almost_eq(out_f.lift_progress, 0.5, 0.01, "lift_progress interpolates smoothly")
	assert_almost_eq(out_f.jump_progress, 0.4, 0.01, "jump_progress interpolates smoothly")
	assert_true(out_f.surfaced, "Discrete surfaced follows latest snapshot")
	assert_eq(out_f.state, FishState.STATE_READY_TO_LAND, "Discrete fish state follows latest snapshot")

	host_net.free()
	client_net.free()


func test_world_view_renders_surface_jump_fish_rod_twitch_and_hud() -> void:
	var state := GameState.new()
	var p1 := state.ensure_player(1)
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	fish_sim.set_seed(909)
	var world := WorldView.new()

	var item_l3 := state.get_holder_item("rod_-3")
	var rod_l3 := state.get_rod_state(item_l3.id)
	rod_l3.planer.attached = true
	rod_l3.planer.line_out = 16.0
	rod_l3.planer.lateral_offset = -8.0
	rod_l3.planer.state = PlanerBoard.STATE_TROLLING
	rod_l3.trail_factor = 1.0
	var f_pike := fish_sim.force_bite(state, rod_sim, item_l3.id, FishState.SPECIES_PIKE)
	f_pike.surfaced = false
	f_pike.jump_progress = 0.0
	f_pike.fight_phase = 1.2

	p1.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 0.8)
	world.apply_game_state(state, "", 1, true)

	assert_eq(world.get_visible_fish_count(), 0, "Submerged distant fish is not rendered")
	assert_true(world.hud_label.text.contains("F: Tärppi"), "Debug HUD displays F: Tärppi hotkey")
	assert_eq(world.prompt_label.text, "[E] Poimi vapa (-3)", "Existing holder prompt_label remains intact")
	assert_true(world.line_prompt_label.text.contains("KALA KIINNI"), "line_prompt_label shows tripped bite prompt")
	assert_true(world.fish_alert_label.text.contains("TÄRPPI"), "fish_alert_label shows active tripped bite alert")

	# Jumping fish appears above water surface
	f_pike.jump_progress = 0.5
	world.apply_game_state(state, "", 1, true)
	assert_eq(world.get_visible_fish_count(), 1, "Jumping fish becomes visible")
	var jump_node := world.fishes_container.get_child(0) as Node3D
	assert_true(jump_node.position.y > WorldView.WATER_Y + 0.2, "Jumping fish rises above water Y")

	# Surfaced READY_TO_LAND in player hand shows species + lift progress; whale is much larger than pike
	f_pike.jump_progress = 0.0
	f_pike.surfaced = true
	f_pike.state = FishState.STATE_READY_TO_LAND
	f_pike.lift_progress = 0.5
	rod_l3.planer.attached = false
	rod_l3.planer.line_out = 1.5
	item_l3.carrier_peer_id = 1
	item_l3.holder_id = ""
	p1.local_position = Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, 0.0)

	var item_r3 := state.get_holder_item("rod_+3")
	var rod_r3 := state.get_rod_state(item_r3.id)
	rod_r3.planer.attached = false
	rod_r3.planer.line_out = 1.5
	rod_r3.planer.state = PlanerBoard.STATE_TROLLING
	rod_r3.trail_factor = 1.0
	var f_whale := fish_sim.force_bite(state, rod_sim, item_r3.id, FishState.SPECIES_BLUE_WHALE)
	f_whale.surfaced = true
	f_whale.state = FishState.STATE_READY_TO_LAND

	world.apply_game_state(state, "", 1, true)
	assert_eq(world.get_visible_fish_count(), 2, "Both surfaced fish render")
	assert_true(
		world.line_prompt_label.text.contains("Hauki") and world.line_prompt_label.text.contains("50%"),
		"line_prompt_label displays surfaced species and lift meter percentage"
	)

	var pike_view := world.fishes_container.get_node_or_null("Fish_%s" % item_l3.id) as Node3D
	var whale_view := world.fishes_container.get_node_or_null("Fish_%s" % item_r3.id) as Node3D
	assert_true(pike_view != null and whale_view != null, "Named 3D nodes exist for both fish")
	assert_true(whale_view.scale.z > pike_view.scale.z * 3.0, "Blue whale 3D model is drastically larger than pike")

	state.set_fish_notice("Saalis! Hauki (4.50 kg) nostettu!", 3.0)
	world.apply_game_state(state, "", 1, true)
	assert_true(world.fish_alert_label.text.contains("Hauki"), "fish_alert_label displays timed catch/escape notice")

	free_node(world)
