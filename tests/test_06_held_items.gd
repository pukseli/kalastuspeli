extends "res://tests/test_case.gd"


func test_pickup_walk_place_and_no_deck_drop() -> void:
	var cfg := ItemConfig.create_default_config(4)
	var state := GameState.new()
	state.configure_items(cfg)
	var p1 := state.ensure_player(1)
	var item_sim := ItemSimulator.new(cfg)
	var crew_sim := CrewSimulator.new()

	assert_eq(state.items.size(), 4, "4 rods should spawn when rod_count is 4")
	var h_stern_l := cfg.get_holder("rod_-1")
	var h_stern_r := cfg.get_holder("rod_+1")
	var h_side_l2 := cfg.get_holder("rod_-2")
	var h_side_l3 := cfg.get_holder("rod_-3")
	var h_side_r2 := cfg.get_holder("rod_+2")
	var h_side_r3 := cfg.get_holder("rod_+3")
	assert_true((h_stern_l["local_position"] as Vector3).z > 3.0 and absf((h_stern_l["local_position"] as Vector3).x) < 1.2, "rod_-1 sits on left stern transom")
	assert_true((h_stern_r["local_position"] as Vector3).z > 3.0 and absf((h_stern_r["local_position"] as Vector3).x) < 1.2, "rod_+1 sits on right stern transom")
	assert_true(absf((h_side_l2["local_position"] as Vector3).x) > 1.4 and absf((h_side_l3["local_position"] as Vector3).x) > 1.4, "rod_-2 and rod_-3 sit on left gunwale")
	assert_true(absf((h_side_r2["local_position"] as Vector3).x) > 1.4 and absf((h_side_r3["local_position"] as Vector3).x) > 1.4, "rod_+2 and rod_+3 sit on right gunwale")
	assert_true(state.get_holder_item("rod_-1") != null, "rod_-1 should be populated first")
	assert_true(state.get_holder_item("rod_+1") != null, "rod_+1 should be populated")
	assert_true(state.get_holder_item("rod_-2") != null, "rod_-2 should be populated")
	assert_true(state.get_holder_item("rod_+2") != null, "rod_+2 should be populated")
	assert_true(state.get_holder_item("rod_-3") == null, "rod_-3 should start empty with 4 rods")
	assert_true(state.get_holder_item("rod_+3") == null, "rod_+3 should start empty with 4 rods")

	var interact_in := PlayerInput.new()
	interact_in.interact = true

	p1.local_position = Vector3(-0.95, CrewSimulator.DECK_SURFACE_Y, 3.0)
	item_sim.step(state, {1: interact_in}, ItemSimulator.FIXED_DELTA)

	var rod := state.get_player_held_item(1)
	assert_true(rod != null, "Player 1 should hold picked-up rod")
	assert_eq(rod.carrier_peer_id, 1, "Rod carrier_peer_id should be 1")
	assert_eq(rod.holder_id, "", "Carried rod holder_id must be empty")
	assert_true(state.get_holder_item("rod_-1") == null, "rod_-1 must be empty after pickup")

	# Walk to center deck and press interact -> must NOT drop rod on deck
	var walk_in := PlayerInput.new()
	walk_in.move_x = 1.0
	walk_in.move_z = -1.0
	for _i in range(30):
		crew_sim.step(state, {1: walk_in}, CrewSimulator.FIXED_DELTA)
	item_sim.step(state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	assert_true(state.get_player_held_item(1) == rod, "Pressing interact away from holders must not drop rod on deck")
	assert_eq(rod.carrier_peer_id, 1, "Rod remains carried after center-deck interact")
	assert_eq(rod.holder_id, "", "Rod holder_id stays empty when no holder is nearby")

	# Move near empty rod_-3 and place rod
	p1.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 0.8)
	item_sim.step(state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	assert_true(state.get_player_held_item(1) == null, "Player 1 hands should be empty after placing rod")
	assert_eq(rod.carrier_peer_id, 0, "Placed rod carrier_peer_id must be 0")
	assert_eq(rod.holder_id, "rod_-3", "Placed rod holder_id must be rod_-3")
	assert_eq(rod.last_holder_id, "rod_-3", "Placed rod last_holder_id must be rod_-3")
	assert_true(state.get_holder_item("rod_-3") == rod, "rod_-3 must contain the placed rod")


func test_swap_occupied_holder_and_same_tick_exclusivity() -> void:
	var state := GameState.new()
	var item_sim := ItemSimulator.new(state.item_config)
	var p1 := state.ensure_player(1)
	var p2 := state.ensure_player(2)

	p1.local_position = Vector3(-0.95, CrewSimulator.DECK_SURFACE_Y, 3.0)
	p2.local_position = Vector3(-0.9, CrewSimulator.DECK_SURFACE_Y, 2.95)
	var interact_in := PlayerInput.new()
	interact_in.interact = true

	var rod_a := state.get_holder_item("rod_-1")
	var rod_b := state.get_holder_item("rod_-3")
	assert_true(rod_a != null and rod_b != null, "Default 6-rod setup populates rod_-1 and rod_-3")

	# Same-tick pickup contention: only lowest peer_id (1) gets rod_a
	item_sim.step(state, {1: interact_in, 2: interact_in}, ItemSimulator.FIXED_DELTA)
	assert_true(state.get_player_held_item(1) == rod_a, "Player 1 should win same-tick pickup at rod_-1")
	assert_true(state.get_player_held_item(2) == null, "Player 2 must stay empty-handed on same-tick contention")
	assert_true(state.get_holder_item("rod_-1") == null, "rod_-1 must be vacant after pickup")

	# Player 1 swaps rod_a with rod_b at occupied rod_-3
	p1.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 0.8)
	item_sim.step(state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	assert_eq(rod_a.holder_id, "rod_-3", "Held rod_a should be placed into rod_-3 on swap")
	assert_eq(rod_a.carrier_peer_id, 0, "Swapped-in rod_a carrier_peer_id must be 0")
	assert_eq(rod_b.carrier_peer_id, 1, "Previously held rod_b must now be carried by Player 1")
	assert_eq(rod_b.holder_id, "", "Carried rod_b holder_id must be empty")

	# Player 1 places rod_b into now-empty rod_-1
	p1.local_position = Vector3(-0.95, CrewSimulator.DECK_SURFACE_Y, 3.0)
	item_sim.step(state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	assert_true(state.get_holder_item("rod_-3") == rod_a, "rod_-3 holds rod_a")
	assert_true(state.get_holder_item("rod_-1") == rod_b, "rod_-1 holds rod_b")

	var occupied_holders: Dictionary = {}
	for item_id in state.items:
		var item: HeldItem = state.items[item_id]
		if item.item_type != ItemConfig.ITEM_TYPE_ROD:
			continue
		assert_true(not item.is_carried(), "Zero rods carried after placing rod_b")
		assert_true(not item.holder_id.is_empty(), "Every rod has a holder_id")
		assert_true(not occupied_holders.has(item.holder_id), "All 6 rods occupy distinct holders")
		occupied_holders[item.holder_id] = true
	assert_eq(occupied_holders.size(), 6, "All 6 holders occupied distinctly")


func test_helm_blocked_while_holding_item_and_disconnect_returns_item() -> void:
	var state := GameState.new()
	var station_sim := StationSimulator.new()
	var item_sim := ItemSimulator.new(state.item_config)
	var world := WorldView.new()

	var p1 := state.ensure_player(1)
	p1.local_position = Vector3(-0.95, CrewSimulator.DECK_SURFACE_Y, 3.0)
	var interact_in := PlayerInput.new()
	interact_in.interact = true
	item_sim.step(state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	var rod_a := state.get_player_held_item(1)
	assert_true(rod_a != null, "Player 1 picked up rod_a")

	# Attempt to occupy helm while holding rod -> blocked
	p1.local_position = StationConfig.HELM_LOCAL_POS
	station_sim.step(state, {1: interact_in}, BoatSimulator.FIXED_DELTA)
	assert_eq(state.stations.get("helm", 0), 0, "Helm must remain vacant when player holds an item")
	assert_true(state.get_player_held_item(1) == rod_a, "Player 1 keeps rod when helm entry is blocked")
	world.apply_game_state(state, "", 1, true)
	assert_eq(world.prompt_label.text, "[Laske vapa ensin]", "WorldView prompts to put down rod at helm")

	# Disconnect returns rod_a to original holder rod_-1 when free
	state.remove_player(1)
	assert_eq(rod_a.carrier_peer_id, 0, "Disconnected carrier_peer_id resets to 0")
	assert_eq(rod_a.holder_id, "rod_-1", "Rod returns to last_holder_id rod_-1 when empty")

	# Fallback when last_holder_id is occupied by another player
	var p2 := state.ensure_player(2)
	var p3 := state.ensure_player(3)
	p2.local_position = Vector3(0.95, CrewSimulator.DECK_SURFACE_Y, 3.0)
	item_sim.step(state, {2: interact_in}, ItemSimulator.FIXED_DELTA)
	var rod_b := state.get_player_held_item(2)
	assert_true(rod_b != null, "Player 2 picked up rod_b from rod_+1")

	p3.local_position = Vector3(1.3, CrewSimulator.DECK_SURFACE_Y, 2.1)
	item_sim.step(state, {3: interact_in}, ItemSimulator.FIXED_DELTA)
	var rod_c := state.get_player_held_item(3)
	assert_true(rod_c != null, "Player 3 picked up rod_c from rod_+2")
	p3.local_position = Vector3(0.95, CrewSimulator.DECK_SURFACE_Y, 3.0)
	item_sim.step(state, {3: interact_in}, ItemSimulator.FIXED_DELTA)
	assert_true(state.get_holder_item("rod_+1") == rod_c, "rod_+1 is now occupied by rod_c")
	assert_true(state.get_holder_item("rod_+2") == null, "rod_+2 is now empty")

	state.remove_player(2)
	assert_eq(rod_b.carrier_peer_id, 0, "Disconnected Player 2 rod_b carrier_peer_id resets to 0")
	assert_eq(rod_b.holder_id, "rod_+2", "rod_b falls back to first empty compatible holder rod_+2")

	# Leaving helm must not pick up a rod at helm position on the same tick
	var custom_holders: Array = [
		{
			"id": "helm_holder",
			"label": "H",
			"side": -1,
			"local_position": StationConfig.HELM_LOCAL_POS,
			"radius": 0.85,
			"allowed_types": ["rod"],
		}
	]
	var custom_cfg := ItemConfig.new(custom_holders, 1)
	var helm_state := GameState.new()
	helm_state.configure_items(custom_cfg)
	var hp1 := helm_state.ensure_player(1)
	hp1.local_position = StationConfig.HELM_LOCAL_POS
	helm_state.stations["helm"] = 1

	var net := NetworkManager.new()
	var boat_sim := BoatSimulator.new()
	var crew_sim := CrewSimulator.new()
	var custom_item_sim := ItemSimulator.new(custom_cfg)
	net.step_game_tick(helm_state, interact_in, boat_sim, crew_sim, station_sim, custom_item_sim)
	assert_eq(helm_state.stations.get("helm", 0), 0, "Helm vacated on interact")
	assert_true(helm_state.get_player_held_item(1) == null, "Leaving helm must not pick up a rod on the same tick")

	net.free()
	free_node(world)


func test_configurable_rod_count_and_custom_boat_holder_layout() -> void:
	var default_cli := NetworkManager.parse_cli_args(PackedStringArray([]))
	assert_eq(default_cli.get("rods"), 6, "Default CLI --rods must be 6")
	var custom_cli := NetworkManager.parse_cli_args(PackedStringArray(["--rods", "4"]))
	assert_eq(custom_cli.get("rods"), 4, "--rods 4 must parse rod count 4")

	var custom_holders: Array = [
		{
			"id": "custom_a",
			"label": "A",
			"side": -1,
			"local_position": Vector3(-2.0, 0.65, 0.0),
			"radius": 0.85,
			"allowed_types": ["rod"],
		},
		{
			"id": "custom_b",
			"label": "B",
			"side": 1,
			"local_position": Vector3(2.0, 0.65, 0.0),
			"radius": 0.85,
			"allowed_types": ["rod"],
		},
		{
			"id": "custom_c",
			"label": "C",
			"side": 1,
			"local_position": Vector3(0.0, 0.65, 2.5),
			"radius": 0.85,
			"allowed_types": ["rod"],
		},
	]
	var custom_cfg := ItemConfig.new(custom_holders, 2)
	var state := GameState.new()
	state.configure_items(custom_cfg)
	var item_sim := ItemSimulator.new(custom_cfg)
	var world := WorldView.new()
	world.configure_holders(custom_cfg)
	world.apply_game_state(state)

	assert_eq(state.items.size(), 2, "Custom ItemConfig spawns exact rod_count=2")
	assert_true(state.get_holder_item("custom_a") != null, "custom_a populated")
	assert_true(state.get_holder_item("custom_b") != null, "custom_b populated")
	assert_true(state.get_holder_item("custom_c") == null, "custom_c starts empty")

	assert_eq(world.boat_view.holders_container.get_child_count(), 3, "BoatView spawns 3 custom holder nodes")
	var h_a := world.boat_view.holders_container.get_child(0) as Node3D
	var h_c := world.boat_view.holders_container.get_child(2) as Node3D
	assert_almost_eq(h_a.position.x, -2.0, 0.001, "Custom holder A X matches config")
	assert_almost_eq(h_c.position.z, 2.5, 0.001, "Custom holder C Z matches config")

	var p1 := state.ensure_player(1)
	var interact_in := PlayerInput.new()
	interact_in.interact = true
	p1.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 0.0)
	item_sim.step(state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	assert_true(state.get_player_held_item(1) != null, "Player picks up rod from custom_a")

	p1.local_position = Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, 2.2)
	item_sim.step(state, {1: interact_in}, ItemSimulator.FIXED_DELTA)
	assert_true(state.get_player_held_item(1) == null, "Player places rod into custom_c")
	assert_true(state.get_holder_item("custom_a") == null, "custom_a is empty after move")
	assert_true(state.get_holder_item("custom_c") != null, "custom_c holds moved rod")

	free_node(world)


func test_items_replicate_over_network_interpolate_discretely_and_render_in_view() -> void:
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
	var host_input := PlayerInput.new()

	var p2 := host_state.ensure_player(2)
	p2.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 2.1)
	host_net.receive_client_input(2, {"throttle": 0.0, "steering": 0.0, "move_x": 0.0, "move_z": 0.0, "interact": true})
	var snap := host_net.step_game_tick(host_state, host_input, boat_sim, crew_sim, station_sim, item_sim)

	assert_true(snap.has("items"), "Host snapshot includes serialized items dictionary")
	client_net.apply_game_snapshot(client_state, snap)
	assert_true(client_state.get_player_held_item(2) != null, "Client replicates peer 2 holding rod")

	# Interpolation: smooth position lerp + discrete item state from latest snapshot
	var snap_state_a := GameState.new()
	snap_state_a.tick = 6
	var sa_p2 := snap_state_a.ensure_player(2)
	sa_p2.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 1.5)

	var snap_state_b := GameState.new()
	snap_state_b.tick = 12
	var sb_p2 := snap_state_b.ensure_player(2)
	sb_p2.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 2.1)
	var b_rod := snap_state_b.get_holder_item("rod_-2")
	b_rod.carrier_peer_id = 2
	b_rod.holder_id = ""
	b_rod.last_holder_id = "rod_-2"

	var interp := SnapshotInterpolator.new()
	interp.push_snapshot(snap_state_a.to_dict())
	interp.push_snapshot(snap_state_b.to_dict())

	var out := GameState.new()
	assert_true(interp.sample_at(out, 0.15, true), "Interpolator sample_at succeeds at midpoint")
	assert_almost_eq(out.players[2].local_position.z, 1.8, 0.001, "Player 2 Z interpolates smoothly to midpoint 1.8")
	assert_true(out.get_player_held_item(2) != null, "Interpolated state reads carried rod discretely from latest snapshot")

	var world := WorldView.new()
	world.apply_game_state(out, "", 2, true)
	var p2_view := world.boat_view.players_container.get_node_or_null("Player_2") as PlayerView
	assert_true(p2_view != null, "BoatView has Player_2 view")
	assert_true(p2_view.has_visible_held_item(), "PlayerView shows held item when carrying rod")
	assert_eq(world.boat_view.get_visible_resting_rod_count(), 5, "BoatView renders 5 resting rods when 1 is carried")

	out.players[2].local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 2.1)
	world.apply_game_state(out, "", 2, true)
	assert_eq(world.prompt_label.text, "[E] Aseta vapa (-2)", "Prompt shows place action near empty holder -2")

	out.players[2].local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 0.8)
	world.apply_game_state(out, "", 2, true)
	assert_eq(world.prompt_label.text, "[E] Vaihda vapa (-3)", "Prompt shows swap action near occupied holder -3")

	free_node(world)
	host_net.free()
	client_net.free()
