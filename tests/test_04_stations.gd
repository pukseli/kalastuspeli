extends "res://tests/test_case.gd"


func test_interact_within_radius_occupies_helm() -> void:
	var state := GameState.new()
	var p1 := state.ensure_player(1)
	var p2 := state.ensure_player(2)
	var station_sim := StationSimulator.new()
	var crew_sim := CrewSimulator.new()

	var interact_input := PlayerInput.new()
	interact_input.interact = true

	# Out of radius interact must not occupy helm
	p1.local_position = StationConfig.HELM_LOCAL_POS + Vector3(2.0, 0.0, 0.0)
	station_sim.step(state, {1: interact_input}, BoatSimulator.FIXED_DELTA)
	assert_eq(state.stations.get("helm", 0), 0, "Out-of-radius interact must not occupy helm")

	# Within radius occupies helm and locks position
	p1.local_position = StationConfig.HELM_LOCAL_POS + Vector3(0.2, 0.0, 0.1)
	station_sim.step(state, {1: interact_input}, BoatSimulator.FIXED_DELTA)
	assert_eq(state.stations.get("helm", 0), 1, "Player 1 should occupy helm")
	assert_almost_eq(p1.local_position.x, StationConfig.HELM_LOCAL_POS.x, 0.001, "Player locked to helm X")
	assert_almost_eq(p1.local_position.z, StationConfig.HELM_LOCAL_POS.z, 0.001, "Player locked to helm Z")

	# Another player within radius cannot steal occupied helm
	p2.local_position = StationConfig.HELM_LOCAL_POS + Vector3(-0.2, 0.0, 0.0)
	station_sim.step(state, {2: interact_input}, BoatSimulator.FIXED_DELTA)
	assert_eq(state.stations.get("helm", 0), 1, "Player 2 must not steal occupied helm")

	# While at helm, walk inputs must not move player
	var walk_input := PlayerInput.new()
	walk_input.move_x = 1.0
	walk_input.move_z = 1.0
	crew_sim.step(state, {1: walk_input}, CrewSimulator.FIXED_DELTA)
	assert_almost_eq(p1.local_position.x, StationConfig.HELM_LOCAL_POS.x, 0.001, "Player remains locked to helm despite walk input")

	# Vacant station id (0) must never match as occupied by peer_id 0
	assert_true(not state.is_player_at_station(0), "peer_id 0 must not be reported at station")
	assert_eq(state.get_player_station(0), "", "peer_id 0 must have empty station id")


func test_interact_again_releases_helm() -> void:
	var default_stations := StationConfig.create_default_stations()
	assert_eq(default_stations.get("helm", -1), 0, "Default stations include vacant helm")

	var state := GameState.new()
	var p1 := state.ensure_player(1)
	p1.local_position = StationConfig.HELM_LOCAL_POS
	state.stations["helm"] = 1

	var station_sim := StationSimulator.new()
	var crew_sim := CrewSimulator.new()

	var world := WorldView.new()
	world.apply_game_state(state, "", 1, true)
	assert_eq(world.prompt_label.text, "[E] Irrota ote", "WorldView displays helm leave prompt")
	assert_almost_eq(world.camera.rotation_degrees.x, StationConfig.HELM_CAM_PITCH_DEG, 0.05, "WorldView snaps to helm camera pitch")
	assert_almost_eq(world.camera.position.z, StationConfig.HELM_CAM_OFFSET.z, 0.01, "WorldView snaps to helm camera Z offset")

	var p2 := state.ensure_player(2)
	p2.local_position = StationConfig.HELM_LOCAL_POS + Vector3(0.3, 0.0, 0.0)
	world.apply_game_state(state, "", 2, true)
	assert_eq(world.prompt_label.text, "[Ruori varattu]", "WorldView displays occupied prompt for other players near helm")
	state.remove_player(2)

	var release_input := PlayerInput.new()
	release_input.interact = true
	station_sim.step(state, {1: release_input}, BoatSimulator.FIXED_DELTA)

	assert_eq(state.stations.get("helm", 0), 0, "Helm should be vacant after second interact")
	world.apply_game_state(state, "", 1, true)
	assert_eq(world.prompt_label.text, "[E] Tartu ruoriin", "WorldView displays helm enter prompt when vacant")
	assert_almost_eq(world.camera.rotation_degrees.x, WorldView.CAMERA_PITCH_DEG, 0.05, "WorldView returns to deck camera pitch")

	# Now player can walk freely again
	var walk_input := PlayerInput.new()
	walk_input.move_x = 1.0
	crew_sim.step(state, {1: walk_input}, CrewSimulator.FIXED_DELTA)
	assert_true(p1.local_position.x > StationConfig.HELM_LOCAL_POS.x + 0.01, "Player walks freely after leaving helm")

	# CrewSimulator locks non-helm station occupants to their station position, not HELM_LOCAL_POS
	var p3 := state.ensure_player(3)
	p3.local_position = Vector3(-1.0, CrewSimulator.DECK_SURFACE_Y, 1.0)
	state.stations["custom_rod"] = 3
	crew_sim.step(state, {}, CrewSimulator.FIXED_DELTA)
	var custom_pos := StationConfig.get_station_position("custom_rod")
	assert_almost_eq(p3.local_position.z, custom_pos.z, 0.001, "Non-helm station occupant locks to station position, not helm")

	free_node(world)


func test_only_helm_occupant_steers_boat() -> void:
	var state := GameState.new()
	var _p1 := state.ensure_player(1)
	var _p2 := state.ensure_player(2)

	var station_sim := StationSimulator.new()
	var boat_sim := BoatSimulator.new()

	var helm_input := PlayerInput.new()
	helm_input.throttle = 1.0
	helm_input.steering = -1.0

	# Vacant helm must ignore throttle and steering inputs
	station_sim.apply_helm_input_to_boat(state, {1: helm_input}, BoatSimulator.FIXED_DELTA, boat_sim.config.max_steering_angle)
	assert_almost_eq(state.boat.throttle, 0.0, 0.0001, "Vacant helm ignores throttle input")
	assert_almost_eq(state.boat.steering_angle, 0.0, 0.0001, "Vacant helm ignores steering input")

	state.stations["helm"] = 1
	var rogue_input := PlayerInput.new()
	rogue_input.throttle = -1.0
	rogue_input.steering = 1.0

	var inputs: Dictionary = {1: helm_input, 2: rogue_input}
	for _i in range(30):
		station_sim.apply_helm_input_to_boat(state, inputs, BoatSimulator.FIXED_DELTA, boat_sim.config.max_steering_angle)
		boat_sim.step(state.boat, station_sim.get_active_boat_input(state, boat_sim.config.max_steering_angle), BoatSimulator.FIXED_DELTA)

	assert_true(state.boat.throttle > 0.0, "Boat throttle must increase from helm occupant")
	assert_true(state.boat.steering_angle < 0.0, "Boat steering angle must steer in helm occupant direction")

	# Custom max_steering_angle must not drift when helm input is idle
	boat_sim.config.max_steering_angle = deg_to_rad(45.0)
	var locked_angle := state.boat.steering_angle
	for _i in range(20):
		station_sim.apply_helm_input_to_boat(state, {}, BoatSimulator.FIXED_DELTA, boat_sim.config.max_steering_angle)
		boat_sim.step(state.boat, station_sim.get_active_boat_input(state, boat_sim.config.max_steering_angle), BoatSimulator.FIXED_DELTA)
	assert_almost_eq(state.boat.steering_angle, locked_angle, 0.0001, "Steering angle must not drift with custom max_steering_angle")

	# Center detent on steering: catches at 0.0, holds briefly, breaks out on direction reversal
	state.boat.steering_angle = 0.01
	var steer_right := PlayerInput.new()
	steer_right.steering = -1.0
	station_sim.apply_helm_input_to_boat(state, {1: steer_right}, BoatSimulator.FIXED_DELTA, boat_sim.config.max_steering_angle)
	assert_almost_eq(state.boat.steering_angle, 0.0, 0.0001, "Steering catches at 0.0 center detent on zero crossing")
	assert_true(state.helm_steer_detent_timer > 0.0, "Steering detent timer activates on zero crossing")
	for _i in range(3):
		station_sim.apply_helm_input_to_boat(state, {1: steer_right}, BoatSimulator.FIXED_DELTA, boat_sim.config.max_steering_angle)
	assert_almost_eq(state.boat.steering_angle, 0.0, 0.0001, "Steering holds at 0.0 during detent")

	var steer_left := PlayerInput.new()
	steer_left.steering = 1.0
	station_sim.apply_helm_input_to_boat(state, {1: steer_left}, BoatSimulator.FIXED_DELTA, boat_sim.config.max_steering_angle)
	assert_true(state.boat.steering_angle > 0.0, "Reversing direction breaks out of steering detent immediately")

	# Center detent on throttle: catches at 0.0 and holds briefly
	state.boat.throttle = 0.01
	var rev_input := PlayerInput.new()
	rev_input.throttle = -1.0
	station_sim.apply_helm_input_to_boat(state, {1: rev_input}, BoatSimulator.FIXED_DELTA, boat_sim.config.max_steering_angle)
	assert_almost_eq(state.boat.throttle, 0.0, 0.0001, "Throttle catches at 0.0 center detent on zero crossing")
	for _i in range(3):
		station_sim.apply_helm_input_to_boat(state, {1: rev_input}, BoatSimulator.FIXED_DELTA, boat_sim.config.max_steering_angle)
	assert_almost_eq(state.boat.throttle, 0.0, 0.0001, "Throttle holds at 0.0 during detent")

	# Vacating helm resets active detent timers
	state.boat.steering_angle = 0.01
	station_sim.apply_helm_input_to_boat(state, {1: steer_right}, BoatSimulator.FIXED_DELTA, boat_sim.config.max_steering_angle)
	assert_true(state.helm_steer_detent_timer > 0.0, "Detent active before vacate")
	var vacate_input := PlayerInput.new()
	vacate_input.interact = true
	station_sim.step(state, {1: vacate_input}, BoatSimulator.FIXED_DELTA)
	assert_almost_eq(state.helm_steer_detent_timer, 0.0, 0.0001, "Vacating helm resets steering detent timer")


func test_boat_retains_throttle_and_steering_when_helm_vacated() -> void:
	var state := GameState.new()
	var p1 := state.ensure_player(1)
	p1.local_position = StationConfig.HELM_LOCAL_POS
	state.stations["helm"] = 1

	var station_sim := StationSimulator.new()
	var boat_sim := BoatSimulator.new()

	var helm_input := PlayerInput.new()
	helm_input.throttle = 1.0
	helm_input.steering = -1.0
	for _i in range(30):
		station_sim.apply_helm_input_to_boat(state, {1: helm_input}, BoatSimulator.FIXED_DELTA, boat_sim.config.max_steering_angle)
		boat_sim.step(state.boat, station_sim.get_active_boat_input(state, boat_sim.config.max_steering_angle), BoatSimulator.FIXED_DELTA)

	assert_true(state.boat.throttle > 0.0, "Boat has throttle > 0")
	assert_true(state.boat.steering_angle < 0.0, "Boat has steering_angle < 0")
	var initial_throttle := state.boat.throttle
	var initial_steering := state.boat.steering_angle

	# Vacate helm
	var vacate_input := PlayerInput.new()
	vacate_input.interact = true
	station_sim.step(state, {1: vacate_input}, BoatSimulator.FIXED_DELTA)
	assert_eq(state.stations.get("helm", 0), 0, "Helm is vacated")
	var heading_at_vacate := state.boat.heading

	# Run 20 ticks with nobody at helm
	for _i in range(20):
		station_sim.apply_helm_input_to_boat(state, {}, BoatSimulator.FIXED_DELTA, boat_sim.config.max_steering_angle)
		boat_sim.step(state.boat, station_sim.get_active_boat_input(state, boat_sim.config.max_steering_angle), BoatSimulator.FIXED_DELTA)

	assert_almost_eq(state.boat.throttle, initial_throttle, 0.001, "Boat retains throttle when helm is empty")
	assert_almost_eq(state.boat.steering_angle, initial_steering, 0.001, "Boat retains steering_angle when helm is empty")
	assert_true(state.boat.forward_speed > 0.5, "Boat continues moving forward while helm is vacant")
	assert_true(absf(state.boat.heading - heading_at_vacate) > 0.05, "Boat continues turning while helm is vacant")


func test_disconnect_frees_occupied_station() -> void:
	var state := GameState.new()
	var host_player := state.ensure_player(1, false)
	var bot_player := state.ensure_player(-1, true)
	assert_eq(host_player.color_index, 0, "Host peer 1 has color_index 0")
	assert_eq(bot_player.color_index, 1, "Bot -1 has color_index 1 (distinct from host)")

	state.ensure_player(2)
	state.stations["helm"] = 2
	state.helm_steer_detent_timer = 0.2

	state.remove_player(2)
	assert_eq(state.stations.get("helm", 0), 0, "Disconnecting player 2 must vacate helm station")
	assert_almost_eq(state.helm_steer_detent_timer, 0.0, 0.0001, "Disconnecting helm occupant resets detent timer")

	# NetworkManager latches interact across updates, replicates stations, and does not recurse on snapshot apply
	var host_net := NetworkManager.new()
	host_net.configure_from_args(PackedStringArray(["--host", "--sync-hz", "60"]))
	var client_net := NetworkManager.new()
	client_net.configure_from_args(PackedStringArray(["--join", "127.0.0.1"]))

	var host_state := GameState.new()
	var client_state := GameState.new()
	var boat_sim := BoatSimulator.new()
	var crew_sim := CrewSimulator.new()
	var station_sim := StationSimulator.new()
	var host_input := PlayerInput.new()

	var p2 := host_state.ensure_player(2)
	p2.local_position = StationConfig.HELM_LOCAL_POS
	host_net.receive_client_input(2, {"interact": true, "throttle": 0.0, "steering": 0.0, "move_x": 0.0, "move_z": 0.0})
	host_net.receive_client_input(2, {"interact": false, "throttle": 0.0, "steering": 0.0, "move_x": 0.0, "move_z": 0.0})

	var snap := host_net.step_game_tick(host_state, host_input, boat_sim, crew_sim, station_sim)
	assert_eq(host_state.stations.get("helm", 0), 2, "Latched interact survives follow-up input before host tick")
	assert_true(not snap.is_empty(), "Host emits GameState snapshot at 60 Hz")

	var apply_calls := [0]
	client_net.game_snapshot_received.connect(func(received_snap: Dictionary) -> void:
		apply_calls[0] += 1
		client_net.apply_game_snapshot(client_state, received_snap)
	)
	client_net.game_snapshot_received.emit(snap)
	assert_eq(apply_calls[0], 1, "apply_game_snapshot must not re-emit game_snapshot_received")
	assert_eq(client_state.stations.get("helm", 0), 2, "Client GameState replicates occupied stations")

	host_net.free()
	client_net.free()
