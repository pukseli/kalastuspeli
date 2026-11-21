extends "res://tests/test_case.gd"


func test_player_moves_in_boat_local_space_and_clamps_to_deck() -> void:
	var state := GameState.new()
	var p1 := state.ensure_player(1)
	p1.local_position = Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, 0.0)
	var sim := CrewSimulator.new()
	var input := PlayerInput.new()
	input.move_z = -1.0

	for _i in range(120):
		sim.step(state, {1: input}, CrewSimulator.FIXED_DELTA)

	assert_almost_eq(p1.local_position.z, CrewSimulator.DECK_MIN_Z, 0.001, "Player should clamp to bow deck bound (-2.1)")
	assert_almost_eq(p1.local_position.y, CrewSimulator.DECK_SURFACE_Y, 0.001, "Player should stay at DECK_SURFACE_Y (0.25)")


func test_player_to_player_collision_separates_overlapping_players() -> void:
	var state := GameState.new()
	var p1 := state.ensure_player(1)
	var p2 := state.ensure_player(2)
	p1.local_position = Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, 0.0)
	p2.local_position = Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, 0.0)
	var sim := CrewSimulator.new()

	sim.step(state, {}, CrewSimulator.FIXED_DELTA)

	var dx := p1.local_position.x - p2.local_position.x
	var dz := p1.local_position.z - p2.local_position.z
	var dist := sqrt(dx * dx + dz * dz)
	assert_true(dist >= (CrewSimulator.PLAYER_RADIUS * 2.0) - 0.001, "Overlapping players must separate to >= 2 * PLAYER_RADIUS")
	assert_true(p1.local_position.x >= CrewSimulator.DECK_MIN_X and p1.local_position.x <= CrewSimulator.DECK_MAX_X, "Player 1 stays inside deck X bounds")
	assert_true(p2.local_position.x >= CrewSimulator.DECK_MIN_X and p2.local_position.x <= CrewSimulator.DECK_MAX_X, "Player 2 stays inside deck X bounds")


func test_bot_count_cli_and_cycle_spawns_and_removes_bots() -> void:
	var cfg := NetworkManager.parse_cli_args(PackedStringArray(["--bots", "2"]))
	assert_eq(cfg.get("bots"), 2, "--bots 2 should parse bot count 2")

	var net := NetworkManager.new()
	net.configure_from_args(PackedStringArray(["--bots", "2"]))
	var state := GameState.new()
	var boat_sim := BoatSimulator.new()
	var crew_sim := CrewSimulator.new()
	var local_input := PlayerInput.new()

	net.step_game_tick(state, local_input, boat_sim, crew_sim)
	assert_true(state.players.has(-1) and state.players.has(-2), "Bots -1 and -2 should be spawned")
	assert_true(not state.players.has(-3), "Bot -3 should not exist when bot_count == 2")
	assert_true((state.players[-1] as PlayerState).is_bot, "Bot -1 must have is_bot == true")

	assert_eq(net.cycle_bot_count(), 3, "Cycle 2 -> 3")
	net.step_game_tick(state, local_input, boat_sim, crew_sim)
	assert_true(state.players.has(-3), "Bot -3 should spawn at bot_count == 3")

	assert_eq(net.cycle_bot_count(), 0, "Cycle 3 -> 0")
	net.step_game_tick(state, local_input, boat_sim, crew_sim)
	assert_true(not state.players.has(-1) and not state.players.has(-2) and not state.players.has(-3), "All bots removed at bot_count == 0")
	net.free()


func test_game_state_network_sync_replicates_boat_and_crew() -> void:
	var host_net := NetworkManager.new()
	host_net.configure_from_args(PackedStringArray(["--host", "--sync-hz", "60"]))
	var client_net := NetworkManager.new()
	client_net.configure_from_args(PackedStringArray(["--join", "127.0.0.1"]))

	var host_state := GameState.new()
	var client_state := GameState.new()
	var boat_sim := BoatSimulator.new()
	var crew_sim := CrewSimulator.new()
	var host_input := PlayerInput.new()
	host_input.throttle = 1.0

	host_net.receive_client_input(2, {"throttle": 0.0, "steering": 0.0, "move_x": 1.0, "move_z": 0.0})
	var snapshot: Dictionary = {}
	for _i in range(15):
		snapshot = host_net.step_game_tick(host_state, host_input, boat_sim, crew_sim)

	assert_true(not snapshot.is_empty(), "Host at 60 Hz should emit GameState snapshot")
	client_net.apply_game_snapshot(client_state, snapshot)

	assert_true(client_state.boat.forward_speed > 0.5, "Client receives replicated boat forward_speed")
	assert_true(client_state.players.has(1) and client_state.players.has(2), "Client receives both host (1) and client (2) players")
	var client_p2: PlayerState = client_state.players[2]
	assert_true(client_p2.local_position.x > 0.2, "Client player 2 local_position.x advanced from move_x input")

	host_net.free()
	client_net.free()


func test_view_parents_player_to_boat_and_rotates_camera_with_heading() -> void:
	var world := WorldView.new()
	var state := GameState.new()
	state.boat.world_position = Vector3(5.0, 0.0, -3.0)
	state.boat.heading = PI / 2.0
	var p1 := state.ensure_player(1)
	p1.local_position = Vector3(0.5, CrewSimulator.DECK_SURFACE_Y, -1.0)

	world.apply_game_state(state)

	var players_container := world.boat_view.get_node_or_null("PlayersContainer")
	assert_true(players_container != null, "BoatView must have a PlayersContainer child node")
	assert_eq(players_container.get_child_count(), 1, "PlayersContainer should contain 1 PlayerView")
	var p_view := players_container.get_child(0) as Node3D
	assert_almost_eq(p_view.position.x, 0.5, 0.001, "PlayerView local x matches PlayerState")
	assert_almost_eq(p_view.position.z, -1.0, 0.001, "PlayerView local z matches PlayerState")
	assert_almost_eq(world.camera.rotation.y, PI / 2.0, 0.001, "Camera rotation.y follows boat heading")
	assert_almost_eq(world.camera.rotation_degrees.x, -28.0, 0.01, "Camera pitch is -28 degrees")
	free_node(world)
