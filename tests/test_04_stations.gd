extends "res://tests/test_case.gd"


func test_interact_within_radius_occupies_helm() -> void:
	var state := GameState.new()
	var p1 := state.ensure_player(1)
	p1.local_position = StationConfig.HELM_LOCAL_POS + Vector3(0.2, 0.0, 0.1)
	var station_sim := StationSimulator.new()
	var crew_sim := CrewSimulator.new()

	var input := PlayerInput.new()
	input.interact = true
	station_sim.step(state, {1: input}, BoatSimulator.FIXED_DELTA)

	assert_eq(state.stations.get("helm", 0), 1, "Player 1 should occupy helm")
	assert_almost_eq(p1.local_position.x, StationConfig.HELM_LOCAL_POS.x, 0.001, "Player locked to helm X")
	assert_almost_eq(p1.local_position.z, StationConfig.HELM_LOCAL_POS.z, 0.001, "Player locked to helm Z")

	# While at helm, walk inputs must not move player
	var walk_input := PlayerInput.new()
	walk_input.move_x = 1.0
	walk_input.move_z = 1.0
	crew_sim.step(state, {1: walk_input}, CrewSimulator.FIXED_DELTA)
	assert_almost_eq(p1.local_position.x, StationConfig.HELM_LOCAL_POS.x, 0.001, "Player remains locked to helm despite walk input")


func test_interact_again_releases_helm() -> void:
	var state := GameState.new()
	var p1 := state.ensure_player(1)
	p1.local_position = StationConfig.HELM_LOCAL_POS
	state.stations["helm"] = 1

	var station_sim := StationSimulator.new()
	var crew_sim := CrewSimulator.new()

	var release_input := PlayerInput.new()
	release_input.interact = true
	station_sim.step(state, {1: release_input}, BoatSimulator.FIXED_DELTA)

	assert_eq(state.stations.get("helm", 0), 0, "Helm should be vacant after second interact")

	# Now player can walk freely again
	var walk_input := PlayerInput.new()
	walk_input.move_x = 1.0
	crew_sim.step(state, {1: walk_input}, CrewSimulator.FIXED_DELTA)
	assert_true(p1.local_position.x > StationConfig.HELM_LOCAL_POS.x + 0.01, "Player walks freely after leaving helm")


func test_only_helm_occupant_steers_boat() -> void:
	var state := GameState.new()
	var _p1 := state.ensure_player(1)
	var _p2 := state.ensure_player(2)
	state.stations["helm"] = 1

	var station_sim := StationSimulator.new()
	var boat_sim := BoatSimulator.new()

	var helm_input := PlayerInput.new()
	helm_input.throttle = 1.0
	helm_input.steering = -1.0

	var rogue_input := PlayerInput.new()
	rogue_input.throttle = -1.0
	rogue_input.steering = 1.0

	var inputs: Dictionary = {1: helm_input, 2: rogue_input}
	for _i in range(30):
		station_sim.apply_helm_input_to_boat(state, inputs, BoatSimulator.FIXED_DELTA)
		boat_sim.step(state.boat, station_sim.get_active_boat_input(state), BoatSimulator.FIXED_DELTA)

	assert_true(state.boat.throttle > 0.0, "Boat throttle must increase from helm occupant")
	assert_true(state.boat.steering_angle < 0.0, "Boat steering angle must steer in helm occupant direction")


func test_boat_retains_throttle_and_steering_when_helm_vacated() -> void:
	var state := GameState.new()
	var p1 := state.ensure_player(1)
	p1.local_position = StationConfig.HELM_LOCAL_POS
	state.stations["helm"] = 1

	var station_sim := StationSimulator.new()
	var boat_sim := BoatSimulator.new()

	var helm_input := PlayerInput.new()
	helm_input.throttle = 1.0
	for _i in range(30):
		station_sim.apply_helm_input_to_boat(state, {1: helm_input}, BoatSimulator.FIXED_DELTA)
		boat_sim.step(state.boat, station_sim.get_active_boat_input(state), BoatSimulator.FIXED_DELTA)

	assert_true(state.boat.throttle > 0.0, "Boat has throttle > 0")
	var initial_throttle := state.boat.throttle

	# Vacate helm
	var vacate_input := PlayerInput.new()
	vacate_input.interact = true
	station_sim.step(state, {1: vacate_input}, BoatSimulator.FIXED_DELTA)
	assert_eq(state.stations.get("helm", 0), 0, "Helm is vacated")

	# Run 20 ticks with nobody at helm
	for _i in range(20):
		station_sim.apply_helm_input_to_boat(state, {}, BoatSimulator.FIXED_DELTA)
		boat_sim.step(state.boat, station_sim.get_active_boat_input(state), BoatSimulator.FIXED_DELTA)

	assert_almost_eq(state.boat.throttle, initial_throttle, 0.001, "Boat retains throttle when helm is empty")
	assert_true(state.boat.forward_speed > 0.5, "Boat continues moving forward while helm is vacant")


func test_disconnect_frees_occupied_station() -> void:
	var state := GameState.new()
	state.ensure_player(2)
	state.stations["helm"] = 2

	state.remove_player(2)
	assert_eq(state.stations.get("helm", 0), 0, "Disconnecting player 2 must vacate helm station")
