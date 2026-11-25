extends "res://tests/test_case.gd"


func test_net_spawns_on_deck_pickup_free_drop_and_disconnect_drop() -> void:
	var state := GameState.new()
	var item_sim := ItemSimulator.new(state.item_config)
	var p1 := state.ensure_player(1)

	var net := state.items.get("net_1", null) as HeldItem
	assert_true(net != null, "Default GameState spawns net_1 on the boat")
	assert_eq(net.item_type, ItemConfig.ITEM_TYPE_NET, "net_1 has item_type == 'net'")
	assert_true(net.is_on_deck(), "net_1 starts lying on the deck")
	assert_almost_eq(net.deck_position.x, ItemConfig.DEFAULT_NET_DECK_POS.x, 0.01, "net_1 starts at center X")
	assert_almost_eq(net.deck_position.z, ItemConfig.DEFAULT_NET_DECK_POS.z, 0.01, "net_1 starts at mid-deck Z")
	assert_true(not state.rods.has("net_1"), "Landing net must not create a RodState")

	var interact_in := PlayerInput.new()
	interact_in.interact = true

	# Too far from net (and any rod holder) -> cannot pick up
	p1.local_position = Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, -1.6)
	item_sim.step(state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	assert_true(state.get_player_held_item(1) == null, "Cannot pick up net when outside deck_pickup_radius")

	# Move next to net and pick up with E
	p1.local_position = Vector3(net.deck_position.x + 0.3, CrewSimulator.DECK_SURFACE_Y, net.deck_position.z)
	item_sim.step(state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	assert_true(state.get_player_held_item(1) == net, "Player picks up net from deck with E")
	assert_true(net.is_carried() and not net.is_on_deck(), "Picked-up net is carried, not on deck")

	# Walk near a rod holder and press E -> drops net on deck without touching rod holder
	var rod_l3 := state.get_holder_item("rod_-3")
	p1.local_position = Vector3(-1.1, CrewSimulator.DECK_SURFACE_Y, 0.8)
	item_sim.step(state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	assert_true(state.get_player_held_item(1) == null, "Pressing E while holding net drops it onto the deck")
	assert_true(net.is_on_deck(), "Dropped net is_on_deck()")
	assert_almost_eq(net.deck_position.x, -1.1, 0.05, "Dropped net keeps player X position")
	assert_almost_eq(net.deck_position.z, 0.8, 0.05, "Dropped net keeps player Z position")
	assert_true(state.get_holder_item("rod_-3") == rod_l3, "Dropping net near rod_-3 does not disturb rod holder")

	# Pick up again and disconnect -> net drops at player's last local_position
	item_sim.step(state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	assert_true(state.get_player_held_item(1) == net, "Player re-picks dropped net from new deck spot")
	p1.local_position = Vector3(0.75, CrewSimulator.DECK_SURFACE_Y, 1.9)
	state.remove_player(1)
	assert_true(net.is_on_deck(), "Disconnecting while holding net drops it on deck")
	assert_almost_eq(net.deck_position.x, 0.75, 0.05, "Disconnect-dropped net keeps player X")
	assert_almost_eq(net.deck_position.z, 1.9, 0.05, "Disconnect-dropped net keeps player Z")


func test_tired_fish_scoop_succeeds_solo_and_coop_and_records_catch() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	fish_sim.set_seed(601)

	var p1 := state.ensure_player(1)
	var p2 := state.ensure_player(2)
	var net := state.items["net_1"] as HeldItem
	net.carrier_peer_id = 1
	net.holder_id = ""

	# 1) Solo scoop: READY_TO_LAND tired fish in holder rod_-3
	var item_l3 := state.get_holder_item("rod_-3")
	var rod_l3 := state.get_rod_state(item_l3.id)
	rod_l3.planer.attached = false
	rod_l3.planer.line_out = fish_sim.config.ready_to_land_distance
	rod_l3.planer.state = PlanerBoard.STATE_TROLLING
	var f_solo := fish_sim.force_bite(state, rod_sim, item_l3.id, FishState.SPECIES_PIKE, 5.2)
	f_solo.state = FishState.STATE_READY_TO_LAND
	f_solo.stamina = 0.0
	f_solo.surfaced = true

	p1.local_position = Vector3(-1.2, CrewSimulator.DECK_SURFACE_Y, 0.8)
	var scoop_in := PlayerInput.new()
	scoop_in.line_input = -1.0

	# Hold halfway -> scoop_progress rises, then release -> decays
	for _i in range(12):
		fish_sim.step(state, {1: scoop_in}, rod_sim, FishSimulator.FIXED_DELTA)
	assert_true(f_solo.scoop_progress > 0.35 and f_solo.scoop_progress < 0.75, "Holding Space fills scoop_progress partway")
	var mid := f_solo.scoop_progress
	var idle_in := PlayerInput.new()
	for _i in range(8):
		fish_sim.step(state, {1: idle_in}, rod_sim, FishSimulator.FIXED_DELTA)
	assert_true(f_solo.scoop_progress < mid - 0.1, "Releasing Space decays scoop_progress")

	# Complete solo scoop
	for _i in range(40):
		fish_sim.step(state, {1: scoop_in}, rod_sim, FishSimulator.FIXED_DELTA)
		if not state.has_fish_on_rod(item_l3.id):
			break
	assert_true(not state.has_fish_on_rod(item_l3.id), "Tired fish is scooped 100% from holder (solo)")
	assert_eq(rod_l3.planer.state, PlanerBoard.STATE_STOWED, "Scooped rod resets to STOWED")
	assert_true(state.get_player_held_item(1) == net, "Net remains empty and ready in player hand after scoop")
	assert_eq(state.get_catch_count(), 1, "Catch count increments to 1 after solo scoop")
	assert_almost_eq(state.get_biggest_catch_weight(), 5.2, 0.01, "Biggest catch weight records 5.2 kg pike")

	# 2) Co-op scoop: Player 2 holds rod_+3 with tired fish, Player 1 scoops with net
	var item_r3 := state.get_holder_item("rod_+3")
	var rod_r3 := state.get_rod_state(item_r3.id)
	item_r3.carrier_peer_id = 2
	item_r3.holder_id = ""
	rod_r3.planer.attached = false
	rod_r3.planer.line_out = fish_sim.config.ready_to_land_distance
	rod_r3.planer.state = PlanerBoard.STATE_TROLLING
	var f_coop := fish_sim.force_bite(state, rod_sim, item_r3.id, FishState.SPECIES_ZANDER, 3.1)
	f_coop.state = FishState.STATE_READY_TO_LAND
	f_coop.stamina = 0.05
	f_coop.surfaced = true

	p2.local_position = Vector3(1.1, CrewSimulator.DECK_SURFACE_Y, 0.9)
	p1.local_position = Vector3(0.3, CrewSimulator.DECK_SURFACE_Y, 0.9)
	for _i in range(40):
		fish_sim.step(state, {1: scoop_in, 2: idle_in}, rod_sim, FishSimulator.FIXED_DELTA)
		if not state.has_fish_on_rod(item_r3.id):
			break
	assert_true(not state.has_fish_on_rod(item_r3.id), "Tired fish is scooped 100% from teammate hand (co-op)")
	assert_eq(state.get_catch_count(), 2, "Catch count increments to 2 after co-op scoop")
	assert_almost_eq(state.get_biggest_catch_weight(), 5.2, 0.01, "Biggest catch weight stays 5.2 kg")
	assert_eq(state.catches.size(), 2, "Catch log preserves every individual catch entry")


func test_fresh_fish_scoop_can_fail_and_bolt_back_to_hooked() -> void:
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	fish_sim.set_seed(602)

	var bolts := 0
	var catches := 0
	for trial in range(25):
		var state := GameState.new()
		var p1 := state.ensure_player(1)
		var net := state.items["net_1"] as HeldItem
		net.carrier_peer_id = 1
		net.holder_id = ""

		var item_l3 := state.get_holder_item("rod_-3")
		var rod_l3 := state.get_rod_state(item_l3.id)
		rod_l3.planer.attached = false
		rod_l3.planer.line_out = fish_sim.config.ready_to_land_distance
		rod_l3.planer.state = PlanerBoard.STATE_TROLLING
		var fish := fish_sim.force_bite(state, rod_sim, item_l3.id, FishState.SPECIES_PIKE, 7.5)
		fish.state = FishState.STATE_READY_TO_LAND
		fish.stamina = 1.0
		fish.surfaced = true

		p1.local_position = Vector3(-1.2, CrewSimulator.DECK_SURFACE_Y, 0.8)
		var scoop_in := PlayerInput.new()
		scoop_in.line_input = -1.0
		for _i in range(40):
			fish_sim.step(state, {1: scoop_in}, rod_sim, FishSimulator.FIXED_DELTA)
			if not state.has_fish_on_rod(item_l3.id) or fish.state == FishState.STATE_HOOKED:
				break

		if not state.has_fish_on_rod(item_l3.id):
			catches += 1
		elif fish.state == FishState.STATE_HOOKED:
			bolts += 1
			assert_true(rod_l3.planer.line_out >= fish_sim.config.ready_to_land_distance + 3.0, "Bolted fish runs out extra line")
			assert_true(fish.surge_timer > 0.0, "Bolted fish triggers active surge")
			assert_almost_eq(fish.scoop_progress, 0.0, 0.001, "Bolted fish resets scoop_progress")

	assert_true(bolts > 10, "Fresh stamina=1.0 fish bolts frequently on scoop attempt (got %d/25)" % bolts)
	assert_eq(bolts + catches, 25, "Every fresh scoop either bolts back to HOOKED or catches (never destroys fish silently)")


func test_catch_log_records_netless_lift_and_network_syncs_net_and_catches() -> void:
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
	fish_sim.set_seed(603)

	# 1) Netless hand lift of vendace records into host_state.catches
	var p1 := host_state.ensure_player(1)
	p1.local_position = Vector3(-0.95, CrewSimulator.DECK_SURFACE_Y, 2.8)
	var item_l1 := host_state.get_holder_item("rod_-1")
	var rod_l1 := host_state.get_rod_state(item_l1.id)
	item_l1.carrier_peer_id = 1
	item_l1.holder_id = ""
	rod_l1.planer.attached = false
	rod_l1.planer.line_out = fish_sim.config.ready_to_land_distance
	rod_l1.planer.state = PlanerBoard.STATE_TROLLING

	var lift_in := PlayerInput.new()
	lift_in.line_input = -1.0
	var hand_lifted := false
	for _attempt in range(10):
		var fv := fish_sim.force_bite(host_state, rod_sim, item_l1.id, FishState.SPECIES_VENDACE, 0.06)
		fv.state = FishState.STATE_READY_TO_LAND
		fv.stamina = 0.0
		fv.surfaced = true
		rod_l1.planer.line_out = fish_sim.config.ready_to_land_distance
		rod_l1.planer.state = PlanerBoard.STATE_TROLLING
		for _i in range(90):
			host_net.step_game_tick(host_state, lift_in, boat_sim, crew_sim, station_sim, item_sim, rod_sim, fish_sim)
			if not host_state.has_fish_on_rod(item_l1.id):
				break
		if host_state.get_catch_count() >= 1:
			hand_lifted = true
			break
	assert_true(hand_lifted, "Successful S9a netless lift records catch into GameState.catches")
	assert_eq(str(host_state.catches[0].get("method", "")), "hand_lift", "Netless lift records method='hand_lift'")

	# 2) Move net on deck + record a heavier net catch and sync snapshot to client
	var host_net_item := host_state.items["net_1"] as HeldItem
	host_net_item.carrier_peer_id = 0
	host_net_item.holder_id = ""
	host_net_item.deck_position = Vector3(0.65, CrewSimulator.DECK_SURFACE_Y, 1.45)
	host_state.record_catch(FishState.SPECIES_PIKE, 6.4, FishState.SIZE_LARGE, "net")
	var snap := host_net.step_game_tick(host_state, PlayerInput.new(), boat_sim, crew_sim, station_sim, item_sim, rod_sim, fish_sim)
	client_net.apply_game_snapshot(client_state, snap)

	var client_net_item := client_state.items.get("net_1", null) as HeldItem
	assert_true(client_net_item != null and client_net_item.is_on_deck(), "Client replicates net_1 on deck")
	assert_almost_eq(client_net_item.deck_position.x, 0.65, 0.01, "Client replicates net_1 deck_position.x")
	assert_almost_eq(client_net_item.deck_position.z, 1.45, 0.01, "Client replicates net_1 deck_position.z")
	assert_eq(client_state.get_catch_count(), 2, "Client replicates full catches array")
	assert_almost_eq(client_state.get_biggest_catch_weight(), 6.4, 0.01, "Client computes biggest catch weight from catches")

	# 3) SnapshotInterpolator interpolates scoop_progress and preserves catches
	var sa := GameState.new()
	sa.tick = 6
	var r_id := sa.get_holder_item("rod_-3").id
	var fa := fish_sim.force_bite(sa, rod_sim, r_id, FishState.SPECIES_PIKE, 4.0)
	fa.state = FishState.STATE_READY_TO_LAND
	fa.scoop_progress = 0.2

	var sb := GameState.new()
	sb.tick = 12
	var fb := fish_sim.force_bite(sb, rod_sim, r_id, FishState.SPECIES_PIKE, 4.0)
	fb.state = FishState.STATE_READY_TO_LAND
	fb.scoop_progress = 0.8
	sb.record_catch(FishState.SPECIES_PIKE, 4.0, FishState.SIZE_LARGE, "net")

	var interp := SnapshotInterpolator.new()
	interp.push_snapshot(sa.to_dict())
	interp.push_snapshot(sb.to_dict())
	var out := GameState.new()
	assert_true(interp.sample_at(out, 0.15, true), "SnapshotInterpolator samples S10 state")
	assert_almost_eq(out.get_fish_state(r_id).scoop_progress, 0.5, 0.01, "scoop_progress interpolates smoothly to 0.5")
	assert_eq(out.get_catch_count(), 1, "SnapshotInterpolator uses latest catches log")

	host_net.free()
	client_net.free()


func test_world_view_renders_deck_and_held_net_lightweight_hud_and_stamina_thrash() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	var world := WorldView.new()

	var p1 := state.ensure_player(1)
	p1.local_position = Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, 0.6)
	var net := state.items["net_1"] as HeldItem

	# 1) Net lying on deck renders in BoatView and prompts [E] Poimi haavi
	world.apply_game_state(state, "", 1, true)
	assert_true(world.boat_view.get_visible_deck_item_count() >= 1, "BoatView renders net lying on deck")
	assert_true(world.prompt_label.text.contains("Poimi haavi"), "Near deck net prompts [E] Poimi haavi")
	assert_true(world.catch_hud_label != null and world.catch_hud_label.text.contains("0 kpl"), "Lightweight catch HUD shows 0 kpl initially")

	# 2) Pick up net -> deck net disappears, PlayerView shows held net, prompt shows Pudota haavi
	net.carrier_peer_id = 1
	net.holder_id = ""
	state.record_catch(FishState.SPECIES_PERCH, 0.85, FishState.SIZE_SMALL, "net")
	state.record_catch(FishState.SPECIES_PIKE, 7.25, FishState.SIZE_LARGE, "net")
	world.apply_game_state(state, "", 1, true)
	assert_eq(world.boat_view.get_visible_deck_item_count(), 0, "Deck net hides when carried")
	assert_true(world.boat_view.get_player_view(1).has_visible_held_item(), "PlayerView displays carried net")
	assert_true(world.prompt_label.text.contains("Pudota haavi"), "Holding net shows [E] Pudota haavi")
	assert_true(world.catch_hud_label.text.contains("2 kpl") and world.catch_hud_label.text.contains("7.25 kg"), "Catch HUD shows count and biggest weight")
	assert_true(not world.catch_hud_label.text.contains("Hauki") and not world.catch_hud_label.text.contains("Ahven"), "Catch HUD stays lightweight without species list")

	# 3) READY_TO_LAND scoop prompt has NO stamina text hint, and fresh fish thrashes faster than tired fish
	var item_l3 := state.get_holder_item("rod_-3")
	var rod_l3 := state.get_rod_state(item_l3.id)
	rod_l3.planer.attached = false
	rod_l3.planer.line_out = fish_sim.config.ready_to_land_distance
	rod_l3.planer.state = PlanerBoard.STATE_TROLLING
	var f_test := fish_sim.force_bite(state, rod_sim, item_l3.id, FishState.SPECIES_PIKE, 5.0)
	f_test.state = FishState.STATE_READY_TO_LAND
	f_test.surfaced = true
	f_test.scoop_progress = 0.5
	p1.local_position = Vector3(-1.2, CrewSimulator.DECK_SURFACE_Y, 0.8)

	f_test.stamina = 1.0
	world.apply_game_state(state, "", 1, true)
	assert_true(world.line_prompt_label.text.contains("Kauhaise") and world.line_prompt_label.text.contains("50%"), "Scoop prompt shows Kauhaise and 50%")
	assert_true(not world.line_prompt_label.text.contains("Virkeä") and not world.line_prompt_label.text.contains("Väsynyt"), "Scoop prompt has no stamina text hint")

	# Compare phase advancement speed between fresh (stamina=1.0) and tired (stamina=0.0) in READY_TO_LAND
	f_test.fight_phase = 0.0
	f_test.stamina = 1.0
	fish_sim.step(state, {}, rod_sim, 0.1)
	var fresh_phase_delta := f_test.fight_phase

	f_test.fight_phase = 0.0
	f_test.stamina = 0.0
	fish_sim.step(state, {}, rod_sim, 0.1)
	var tired_phase_delta := f_test.fight_phase
	assert_true(fresh_phase_delta > tired_phase_delta * 2.0, "Fresh READY_TO_LAND fish thrashes significantly faster than tired fish")

	free_node(world)
