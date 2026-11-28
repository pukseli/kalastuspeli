extends "res://tests/test_case.gd"


func test_given_hooked_fish_when_fighting_with_high_safe_drag_vs_low_drag_then_tension_scales_fatigue_and_slack_recovers_stamina() -> void:
	var rod_sim := RodSimulator.new()
	var results: Dictionary = {}

	for drag_val in [80.0, 30.0]:
		var st := GameState.new()
		var sim := FishSimulator.new()
		sim.set_seed(1101)
		st.boat.forward_speed = 0.0
		var p1 := st.ensure_player(1)
		p1.local_position = Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, 0.5)

		var item := st.get_holder_item("rod_-3")
		item.carrier_peer_id = 1
		item.holder_id = ""
		var rod := st.get_rod_state(item.id)
		rod.planer.attached = false
		rod.planer.line_out = 20.0
		rod.planer.state = PlanerBoard.STATE_TROLLING
		rod.drag_setting = drag_val

		var fish := sim.force_bite(st, rod_sim, item.id, FishState.SPECIES_PIKE, 7.0)
		fish.stamina = 1.0
		fish.surge_timer = 5.0
		fish.hooked_time = 0.0
		fish.jump_progress = 0.0

		for _i in range(180):
			sim.step(st, {}, rod_sim, FishSimulator.FIXED_DELTA)

		assert_true(st.has_fish_on_rod(item.id), "Fish remains hooked under %.0f N drag" % drag_val)
		results[drag_val] = fish.stamina

	assert_true(
		float(results[80.0]) < float(results[30.0]) - 0.25,
		"Higher safe drag (80 N -> %.2f) drains stamina much faster than low drag (30 N -> %.2f)" % [float(results[80.0]), float(results[30.0])]
	)

	# Active fish recovers stamina on slack tension (< 15 N), whereas exhausted fish never recovers
	var st_slack := GameState.new()
	var sim_slack := FishSimulator.new()
	sim_slack.set_seed(1102)
	st_slack.ensure_player(1)
	var it_slack := st_slack.get_holder_item("rod_-3")
	it_slack.carrier_peer_id = 1
	it_slack.holder_id = ""
	var rd_slack := st_slack.get_rod_state(it_slack.id)
	rd_slack.planer.attached = false
	rd_slack.planer.line_out = 20.0
	rd_slack.planer.state = PlanerBoard.STATE_TROLLING
	rd_slack.drag_setting = 5.0

	var f_slack := sim_slack.force_bite(st_slack, rod_sim, it_slack.id, FishState.SPECIES_PIKE, 7.0)
	f_slack.stamina = 0.50
	f_slack.surge_timer = 0.0
	f_slack.surge_cooldown = 99.0
	f_slack.hooked_time = 0.0
	f_slack.jump_progress = 0.0

	for _i in range(180):
		sim_slack.step(st_slack, {}, rod_sim, FishSimulator.FIXED_DELTA)

	assert_true(f_slack.stamina > 0.58, "Slack tension (< 15 N) recovers active fish stamina (%.2f)" % f_slack.stamina)

	var st_exh := GameState.new()
	var sim_exh := FishSimulator.new()
	sim_exh.set_seed(1103)
	var it_exh := st_exh.get_holder_item("rod_+3")
	var rd_exh := st_exh.get_rod_state(it_exh.id)
	rd_exh.planer.attached = false
	rd_exh.planer.line_out = 18.0
	rd_exh.planer.state = PlanerBoard.STATE_TROLLING
	rd_exh.drag_setting = 0.0

	var f_exh := sim_exh.force_bite(st_exh, rod_sim, it_exh.id, FishState.SPECIES_PIKE, 7.0)
	f_exh.stamina = 0.0
	f_exh.surge_timer = 0.0
	f_exh.surge_cooldown = 99.0
	f_exh.hooked_time = 10.0
	f_exh.jump_progress = 0.0

	for _i in range(180):
		sim_exh.step(st_exh, {}, rod_sim, FishSimulator.FIXED_DELTA)

	assert_true(f_exh.stamina <= 0.001, "Exhausted fish never recovers stamina on 0 N slack line (%.3f)" % f_exh.stamina)
	assert_true(st_exh.has_fish_on_rod(it_exh.id), "Exhausted fish never escapes from 0 N slack line")


func test_given_surging_big_fish_when_angler_yields_and_reels_in_rhythm_vs_panic_reeling_then_rhythm_builds_and_tires_fish_much_faster() -> void:
	var rod_sim := RodSimulator.new()
	var cfg := FishSimulator.Config.new()
	cfg.grace_period_sec = 30.0
	var reel_in := PlayerInput.new()
	reel_in.line_input = -1.0

	# Part A: Pure slipping surge (1.5 s) -> yielding builds fight_rhythm, panic-reeling crushes it and wastes drain
	var st_yield := GameState.new()
	var sim_yield := FishSimulator.new(cfg)
	sim_yield.set_seed(1119)
	st_yield.boat.forward_speed = 2.0
	st_yield.ensure_player(1)
	var it_yield := st_yield.get_holder_item("rod_-3")
	it_yield.carrier_peer_id = 1
	it_yield.holder_id = ""
	var rd_yield := st_yield.get_rod_state(it_yield.id)
	rd_yield.planer.attached = false
	rd_yield.planer.line_out = 35.0
	rd_yield.planer.state = PlanerBoard.STATE_TROLLING
	rd_yield.drag_setting = 70.0
	var f_yield := sim_yield.force_bite(st_yield, rod_sim, it_yield.id, FishState.SPECIES_PIKE, 7.0)
	f_yield.stamina = 1.0
	f_yield.fight_rhythm = 0.5
	f_yield.surge_timer = 3.0
	f_yield.surge_cooldown = 5.0
	f_yield.jump_progress = 0.0

	var st_panic := GameState.new()
	var sim_panic := FishSimulator.new(cfg)
	sim_panic.set_seed(1119)
	st_panic.boat.forward_speed = 2.0
	st_panic.ensure_player(1)
	var it_panic := st_panic.get_holder_item("rod_-3")
	it_panic.carrier_peer_id = 1
	it_panic.holder_id = ""
	var rd_panic := st_panic.get_rod_state(it_panic.id)
	rd_panic.planer.attached = false
	rd_panic.planer.line_out = 35.0
	rd_panic.planer.state = PlanerBoard.STATE_TROLLING
	rd_panic.drag_setting = 70.0
	var f_panic := sim_panic.force_bite(st_panic, rod_sim, it_panic.id, FishState.SPECIES_PIKE, 7.0)
	f_panic.stamina = 1.0
	f_panic.fight_rhythm = 0.5
	f_panic.surge_timer = 3.0
	f_panic.surge_cooldown = 5.0
	f_panic.jump_progress = 0.0

	for _i in range(90):
		sim_yield.step(st_yield, {}, rod_sim, FishSimulator.FIXED_DELTA)
		sim_panic.step(st_panic, {1: reel_in}, rod_sim, FishSimulator.FIXED_DELTA)

	assert_true(f_yield.fight_rhythm > 0.90, "Yielding cleanly during drag slip builds fight_rhythm (%.2f)" % f_yield.fight_rhythm)
	assert_true(f_panic.fight_rhythm < 0.05, "Panic-reeling into slipping drag crushes fight_rhythm (%.2f)" % f_panic.fight_rhythm)
	assert_true(
		f_panic.stamina > f_yield.stamina + 0.12,
		"Yielding during drag slip tires fish faster than panic-reeling (yield=%.2f, panic=%.2f)" % [f_yield.stamina, f_panic.stamina]
	)

	# Part B: Full 7-second alternating fight (rhythm angler vs continuous panic vs unattended holder)
	var states := {}
	var sims := {}
	var fishes := {}
	var rods := {}
	for mode in ["rhythm", "bad", "holder"]:
		var st := GameState.new()
		st.boat.forward_speed = 2.0
		st.ensure_player(1)
		var it := st.get_holder_item("rod_-3")
		if mode != "holder":
			it.carrier_peer_id = 1
			it.holder_id = ""
		var rd := st.get_rod_state(it.id)
		rd.planer.attached = false
		rd.planer.line_out = 35.0
		rd.planer.state = PlanerBoard.STATE_TROLLING
		rd.drag_setting = 70.0
		var sim := FishSimulator.new(cfg)
		sim.set_seed(1120)
		var fi := sim.force_bite(st, rod_sim, it.id, FishState.SPECIES_PIKE, 7.0)
		fi.stamina = 1.0
		fi.fight_rhythm = 0.0
		fi.surge_timer = 1.6
		fi.surge_cooldown = 1.5
		fi.jump_progress = 0.0
		sim.set_seed(1120)
		states[mode] = st
		sims[mode] = sim
		fishes[mode] = fi
		rods[mode] = rd

	var rhythm_in := PlayerInput.new()
	for _i in range(420):
		rhythm_in.line_input = 0.0 if (rods["rhythm"] as RodState).is_drag_slipping else -1.0
		(sims["rhythm"] as FishSimulator).step(states["rhythm"], {1: rhythm_in}, rod_sim, FishSimulator.FIXED_DELTA)
		(sims["bad"] as FishSimulator).step(states["bad"], {1: reel_in}, rod_sim, FishSimulator.FIXED_DELTA)
		(sims["holder"] as FishSimulator).step(states["holder"], {}, rod_sim, FishSimulator.FIXED_DELTA)

	var st_r: FishState = fishes["rhythm"]
	var st_b: FishState = fishes["bad"]
	var st_h: FishState = fishes["holder"]
	assert_true(
		st_r.stamina < st_b.stamina - 0.18,
		"Rhythm angler tires fish faster over 7s than panic angler (rhythm=%.2f, panic=%.2f)" % [st_r.stamina, st_b.stamina]
	)
	assert_true(
		st_r.stamina < st_h.stamina - 0.35,
		"Rhythm angler tires fish vastly faster than unattended holder (rhythm=%.2f, holder=%.2f)" % [st_r.stamina, st_h.stamina]
	)


func test_given_tiring_fish_when_stamina_drops_then_surges_shorten_rest_windows_lengthen_and_exhausted_fish_scoops_cleanly() -> void:
	var rod_sim := RodSimulator.new()

	# Part A: Surges shorten and cooldowns lengthen as stamina drops
	var st_fresh := GameState.new()
	var sim_fresh := FishSimulator.new()
	var it_fresh := st_fresh.get_holder_item("rod_-3")
	var rd_fresh := st_fresh.get_rod_state(it_fresh.id)
	rd_fresh.planer.attached = false
	rd_fresh.planer.line_out = 20.0
	rd_fresh.planer.state = PlanerBoard.STATE_TROLLING
	var f_fresh := sim_fresh.force_bite(st_fresh, rod_sim, it_fresh.id, FishState.SPECIES_PIKE, 7.0)
	f_fresh.stamina = 1.0
	f_fresh.surge_timer = 0.0
	f_fresh.surge_cooldown = 0.005
	f_fresh.jump_progress = 0.0

	var st_tiring := GameState.new()
	var sim_tiring := FishSimulator.new()
	var it_tiring := st_tiring.get_holder_item("rod_-3")
	var rd_tiring := st_tiring.get_rod_state(it_tiring.id)
	rd_tiring.planer.attached = false
	rd_tiring.planer.line_out = 20.0
	rd_tiring.planer.state = PlanerBoard.STATE_TROLLING
	var f_tiring := sim_tiring.force_bite(st_tiring, rod_sim, it_tiring.id, FishState.SPECIES_PIKE, 7.0)
	f_tiring.stamina = 0.25
	f_tiring.surge_timer = 0.0
	f_tiring.surge_cooldown = 0.005
	f_tiring.jump_progress = 0.0

	sim_fresh.set_seed(1130)
	sim_tiring.set_seed(1130)
	sim_fresh.step(st_fresh, {}, rod_sim, FishSimulator.FIXED_DELTA)
	sim_tiring.step(st_tiring, {}, rod_sim, FishSimulator.FIXED_DELTA)

	assert_true(
		f_fresh.surge_timer > f_tiring.surge_timer * 1.4,
		"Fresh surge lasts longer than tiring surge (fresh=%.2f, tiring=%.2f)" % [f_fresh.surge_timer, f_tiring.surge_timer]
	)
	assert_true(
		f_tiring.surge_cooldown > f_fresh.surge_cooldown * 1.4,
		"Tiring fish rests longer between surges than fresh fish (tiring=%.2f, fresh=%.2f)" % [f_tiring.surge_cooldown, f_fresh.surge_cooldown]
	)

	# Part B: Weight scaling within same species
	assert_true(
		FishSimulator.get_fatigue_drain_scale(FishState.SPECIES_PIKE, 3.0) > FishSimulator.get_fatigue_drain_scale(FishState.SPECIES_PIKE, 11.5),
		"Lighter pike has higher fatigue drain scale than trophy pike"
	)

	var st_light := GameState.new()
	var sim_light := FishSimulator.new()
	sim_light.set_seed(1131)
	st_light.ensure_player(1)
	var it_light := st_light.get_holder_item("rod_-3")
	it_light.carrier_peer_id = 1
	it_light.holder_id = ""
	var rd_light := st_light.get_rod_state(it_light.id)
	rd_light.planer.attached = false
	rd_light.planer.line_out = 20.0
	rd_light.planer.state = PlanerBoard.STATE_TROLLING
	rd_light.drag_setting = 70.0
	var f_light := sim_light.force_bite(st_light, rod_sim, it_light.id, FishState.SPECIES_PIKE, 3.0)
	f_light.stamina = 1.0
	f_light.surge_timer = 5.0
	f_light.jump_progress = 0.0

	var st_trophy := GameState.new()
	var sim_trophy := FishSimulator.new()
	sim_trophy.set_seed(1131)
	st_trophy.ensure_player(1)
	var it_trophy := st_trophy.get_holder_item("rod_-3")
	it_trophy.carrier_peer_id = 1
	it_trophy.holder_id = ""
	var rd_trophy := st_trophy.get_rod_state(it_trophy.id)
	rd_trophy.planer.attached = false
	rd_trophy.planer.line_out = 20.0
	rd_trophy.planer.state = PlanerBoard.STATE_TROLLING
	rd_trophy.drag_setting = 70.0
	var f_trophy := sim_trophy.force_bite(st_trophy, rod_sim, it_trophy.id, FishState.SPECIES_PIKE, 11.5)
	f_trophy.stamina = 1.0
	f_trophy.surge_timer = 5.0
	f_trophy.jump_progress = 0.0

	for _i in range(180):
		sim_light.step(st_light, {}, rod_sim, FishSimulator.FIXED_DELTA)
		sim_trophy.step(st_trophy, {}, rod_sim, FishSimulator.FIXED_DELTA)

	assert_true(
		f_light.stamina < f_trophy.stamina - 0.05,
		"Light 3 kg pike tires faster than 11.5 kg trophy pike (light=%.2f, trophy=%.2f)" % [f_light.stamina, f_trophy.stamina]
	)

	# Part C: Exhausted fish (stamina <= 0.05) never surges, reels cleanly to READY_TO_LAND, and scoops 100%
	var st_exh := GameState.new()
	var sim_exh := FishSimulator.new()
	sim_exh.set_seed(1132)
	var p1 := st_exh.ensure_player(1)
	var it_exh := st_exh.get_holder_item("rod_-3")
	it_exh.carrier_peer_id = 1
	it_exh.holder_id = ""
	var rd_exh := st_exh.get_rod_state(it_exh.id)
	rd_exh.planer.attached = false
	rd_exh.planer.line_out = 4.0
	rd_exh.planer.state = PlanerBoard.STATE_TROLLING
	rd_exh.drag_setting = 70.0
	var f_exh := sim_exh.force_bite(st_exh, rod_sim, it_exh.id, FishState.SPECIES_PIKE, 7.0)
	f_exh.stamina = 0.04
	f_exh.surge_timer = 0.0
	f_exh.surge_cooldown = 0.005
	f_exh.jump_progress = 0.0
	assert_true(f_exh.is_exhausted(), "Fish at stamina 0.04 reports is_exhausted()")

	var reel_in := PlayerInput.new()
	reel_in.line_input = -1.0
	for _i in range(120):
		sim_exh.step(st_exh, {1: reel_in}, rod_sim, FishSimulator.FIXED_DELTA)
		if f_exh.state == FishState.STATE_HOOKED:
			assert_almost_eq(f_exh.surge_timer, 0.0, 0.001, "Exhausted fish never triggers new surges")
		if f_exh.is_ready_to_land():
			break

	assert_eq(f_exh.state, FishState.STATE_READY_TO_LAND, "Exhausted fish reels cleanly to READY_TO_LAND")

	it_exh.carrier_peer_id = 0
	it_exh.holder_id = "rod_-3"
	var net := st_exh.items["net_1"] as HeldItem
	net.carrier_peer_id = 1
	net.holder_id = ""
	p1.local_position = Vector3(-1.2, CrewSimulator.DECK_SURFACE_Y, 0.8)
	for _i in range(40):
		sim_exh.step(st_exh, {1: reel_in}, rod_sim, FishSimulator.FIXED_DELTA)
		if not st_exh.has_fish_on_rod(it_exh.id):
			break

	assert_eq(st_exh.get_catch_count(), 1, "Exhausted fish scoops 100%% cleanly into catch log")
	assert_true(not st_exh.has_fish_on_rod(it_exh.id), "Fish clears rod after clean scoop")


func test_given_fish_with_fight_rhythm_when_synced_over_network_then_copy_from_serialization_and_interpolation_preserve_it() -> void:
	var src := FishState.new()
	src.rod_id = "rod_1"
	src.stamina = 0.04
	src.fight_rhythm = 0.72
	assert_true(src.is_exhausted(), "is_exhausted() returns true when stamina <= EXHAUSTED_STAMINA")

	var copy_dst := FishState.new()
	copy_dst.copy_from(src)
	assert_almost_eq(copy_dst.fight_rhythm, 0.72, 0.001, "FishState.copy_from copies fight_rhythm")

	var dict_dst := FishState.new()
	dict_dst.from_dict(src.to_dict())
	assert_almost_eq(dict_dst.fight_rhythm, 0.72, 0.001, "FishState to_dict/from_dict preserves fight_rhythm")
	assert_true(dict_dst.is_exhausted(), "Deserialized FishState preserves is_exhausted()")

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

	var l3_id := host_state.get_holder_item("rod_-3").id
	host_state.get_rod_state(l3_id).planer.line_out = 18.0
	host_state.get_rod_state(l3_id).planer.state = PlanerBoard.STATE_TROLLING
	var host_fish := fish_sim.force_bite(host_state, rod_sim, l3_id, FishState.SPECIES_PIKE, 6.0)
	host_fish.fight_rhythm = 0.65

	var snap := host_net.step_game_tick(host_state, PlayerInput.new(), boat_sim, crew_sim, station_sim, item_sim, rod_sim, fish_sim)
	client_net.apply_game_snapshot(client_state, snap)
	var client_fish := client_state.get_fish_state(l3_id)
	assert_true(client_fish != null, "Client receives FishState snapshot")
	assert_almost_eq(client_fish.fight_rhythm, host_fish.fight_rhythm, 0.001, "Client replicates FishState.fight_rhythm")

	var sa := GameState.new()
	sa.tick = 6
	var fa := fish_sim.force_bite(sa, rod_sim, l3_id, FishState.SPECIES_PIKE, 6.0)
	fa.fight_rhythm = 0.2

	var sb := GameState.new()
	sb.tick = 12
	var fb := fish_sim.force_bite(sb, rod_sim, l3_id, FishState.SPECIES_PIKE, 6.0)
	fb.fight_rhythm = 0.8

	var interp := SnapshotInterpolator.new()
	interp.push_snapshot(sa.to_dict())
	interp.push_snapshot(sb.to_dict())
	var out := GameState.new()
	assert_true(interp.sample_at(out, 0.15, true), "SnapshotInterpolator samples FishState.fight_rhythm")
	assert_almost_eq(out.get_fish_state(l3_id).fight_rhythm, 0.5, 0.01, "fight_rhythm interpolates smoothly to midpoint 0.5")

	host_net.free()
	client_net.free()


func test_given_hooked_and_ready_fish_when_applied_to_world_view_then_fatigue_hud_rhythm_prompts_and_exhausted_roll_render_without_scoop_spoilers() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	var world := WorldView.new()

	var p1 := state.ensure_player(1)
	p1.local_position = Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, 0.5)
	var item := state.get_holder_item("rod_-3")
	item.carrier_peer_id = 1
	item.holder_id = ""
	var rod := state.get_rod_state(item.id)
	rod.planer.attached = false
	rod.planer.line_out = 10.0
	rod.planer.state = PlanerBoard.STATE_TROLLING
	rod.trail_factor = 1.0
	rod.is_drag_slipping = true
	rod.line_tension = 65.0

	var fish := fish_sim.force_bite(state, rod_sim, item.id, FishState.SPECIES_PIKE, 7.0)
	fish.surfaced = true
	fish.jump_progress = 0.0
	fish.stamina = 0.80
	fish.fight_rhythm = 0.40

	world.apply_game_state(state, "", 1, true)
	assert_true(world.fatigue_row_root.visible, "Fatigue/rhythm HUD row shows during active HOOKED fight")
	assert_true(world.fish_stamina_bar_fill.size.x > 80.0, "Fish stamina bar reflects 80% stamina")
	assert_true(world.rhythm_bar_fill.size.x > 35.0, "Fight rhythm bar reflects 40% rhythm")
	assert_true(world.line_prompt_label.text.contains("Anna juosta") and world.line_prompt_label.text.contains("RÄIKKÄ"), "Slipping drag guides player to let fish run")

	var fish_node := world.fishes_container.get_node_or_null("Fish_%s" % item.id) as Node3D
	assert_true(fish_node != null, "Surfaced 3D fish node exists")
	assert_true(absf(fish_node.rotation.z) < 0.05, "Fresh surfaced fish stays upright without belly-roll")

	# Calm high-rhythm state
	rod.is_drag_slipping = false
	rod.line_tension = 55.0
	fish.drag_rate = 0.0
	fish.surge_timer = 0.0
	fish.stamina = 0.40
	fish.fight_rhythm = 0.80
	var old_stamina_w := world.fish_stamina_bar_fill.size.x
	var old_rhythm_w := world.rhythm_bar_fill.size.x

	world.apply_game_state(state, "", 1, true)
	assert_true(world.fish_stamina_bar_fill.size.x < old_stamina_w, "Fish stamina bar shrinks when stamina drops 80 -> 40%")
	assert_true(world.rhythm_bar_fill.size.x > old_rhythm_w, "Rhythm bar grows when rhythm climbs 40 -> 80%")
	assert_true(world.line_prompt_label.text.contains("RYTMI") and world.line_prompt_label.text.contains("80%"), "Calm high-rhythm prompt displays RYTMI 80%")

	# Exhausted surfaced fish tilts visibly onto its side
	fish.stamina = 0.0
	fish.jump_progress = 0.0
	world.apply_game_state(state, "", 1, true)
	assert_true(absf(fish_node.rotation.z) > 0.25, "Exhausted surfaced fish tilts onto its side (roll=%.2f)" % fish_node.rotation.z)

	# READY_TO_LAND hides fatigue HUD row and keeps scoop prompt free of stamina text spoilers
	item.carrier_peer_id = 0
	item.holder_id = "rod_-3"
	var net := state.items["net_1"] as HeldItem
	net.carrier_peer_id = 1
	net.holder_id = ""
	p1.local_position = Vector3(-1.2, CrewSimulator.DECK_SURFACE_Y, 0.8)
	rod.planer.line_out = 1.5
	fish.state = FishState.STATE_READY_TO_LAND

	world.apply_game_state(state, "", 1, true)
	assert_true(not world.fatigue_row_root.visible, "Fatigue HUD row hides cleanly during READY_TO_LAND / net scoop")
	assert_true(world.line_prompt_label.text.contains("Kauhaise"), "Scoop prompt renders normally")
	assert_true(not world.line_prompt_label.text.contains("Virkeä") and not world.line_prompt_label.text.contains("Väsynyt"), "Scoop prompt stays free of stamina text spoilers")

	free_node(world)
