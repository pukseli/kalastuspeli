extends "res://tests/test_case.gd"


func _make_snapshot(
	tick: int,
	boat_pos: Vector3,
	heading: float = 0.0,
	forward_speed: float = 0.0,
	velocity: Vector2 = Vector2.ZERO,
	angular_velocity: float = 0.0,
	throttle: float = 0.0,
	steering_angle: float = 0.0,
	players_data: Dictionary = {},
	stations_data: Dictionary = {"helm": 0}
) -> Dictionary:
	return {
		"tick": tick,
		"boat": {
			"x": boat_pos.x,
			"y": boat_pos.y,
			"z": boat_pos.z,
			"heading": heading,
			"forward_speed": forward_speed,
			"vx": velocity.x,
			"vz": velocity.y,
			"angular_velocity": angular_velocity,
			"throttle": throttle,
			"steering_angle": steering_angle,
		},
		"players": players_data,
		"stations": stations_data.duplicate(),
	}


func _make_player_dict(peer_id: int, pos: Vector3, color_index: int = 0, is_bot: bool = false) -> Dictionary:
	return {
		"peer_id": peer_id,
		"x": pos.x,
		"y": pos.y,
		"z": pos.z,
		"color_index": color_index,
		"is_bot": is_bot,
	}


func test_boat_position_and_wrapped_heading_interpolate_smoothly() -> void:
	var interp := SnapshotInterpolator.new()
	var snap_a := _make_snapshot(
		6,
		Vector3(0.0, 0.0, 0.0),
		PI - 0.1,
		2.0,
		Vector2(0.0, -2.0),
		0.4,
		0.2,
		-0.1
	)
	var snap_b := _make_snapshot(
		12,
		Vector3(10.0, 0.0, -20.0),
		-PI + 0.1,
		6.0,
		Vector2(4.0, -6.0),
		0.8,
		0.8,
		0.3
	)
	assert_true(interp.push_snapshot(snap_a), "First snapshot should be accepted")
	assert_true(interp.push_snapshot(snap_b), "Second snapshot should be accepted")

	var out := GameState.new()
	assert_true(interp.sample_at(out, 0.15), "sample_at should succeed at midpoint t=0.5")
	assert_almost_eq(out.boat.world_position.x, 5.0, 0.001, "Boat X interpolates to midpoint")
	assert_almost_eq(out.boat.world_position.z, -10.0, 0.001, "Boat Z interpolates to midpoint")
	assert_almost_eq(absf(angle_difference(out.boat.heading, PI)), 0.0, 0.001, "Heading interpolates via shortest arc across -PI/+PI")
	assert_almost_eq(out.boat.forward_speed, 4.0, 0.001, "forward_speed interpolates to midpoint")
	assert_almost_eq(out.boat.velocity.x, 2.0, 0.001, "velocity.x interpolates to midpoint")
	assert_almost_eq(out.boat.velocity.y, -4.0, 0.001, "velocity.y interpolates to midpoint")
	assert_almost_eq(out.boat.angular_velocity, 0.6, 0.001, "angular_velocity interpolates to midpoint")
	assert_almost_eq(out.boat.throttle, 0.5, 0.001, "throttle interpolates to midpoint")
	assert_almost_eq(out.boat.steering_angle, 0.1, 0.001, "steering_angle interpolates to midpoint")


func test_players_interpolate_in_local_space_while_stations_use_latest() -> void:
	var interp := SnapshotInterpolator.new()
	var snap1 := _make_snapshot(
		6,
		Vector3.ZERO,
		0.0,
		0.0,
		Vector2.ZERO,
		0.0,
		0.0,
		0.0,
		{
			"1": _make_player_dict(1, Vector3(0.0, 0.25, 0.0), 0),
			"2": _make_player_dict(2, Vector3(-1.0, 0.25, 1.0), 1),
		},
		{"helm": 0}
	)
	var snap2 := _make_snapshot(
		12,
		Vector3.ZERO,
		0.0,
		0.0,
		Vector2.ZERO,
		0.0,
		0.0,
		0.0,
		{
			"1": _make_player_dict(1, Vector3(1.0, 0.25, -1.0), 0),
			"3": _make_player_dict(3, Vector3(0.5, 0.25, 0.5), 2),
		},
		{"helm": 0}
	)
	var snap3 := _make_snapshot(
		18,
		Vector3.ZERO,
		0.0,
		0.0,
		Vector2.ZERO,
		0.0,
		0.0,
		0.0,
		{
			"1": _make_player_dict(1, Vector3(1.0, 0.25, -1.0), 0),
			"3": _make_player_dict(3, Vector3(0.5, 0.25, 0.5), 2),
		},
		{"helm": 1}
	)
	interp.push_snapshot(snap1)
	interp.push_snapshot(snap2)
	interp.push_snapshot(snap3)

	var out := GameState.new()
	assert_true(interp.sample_at(out, 0.15, true), "sample_at should interpolate between snap1 and snap2")
	assert_true(out.players.has(1), "Player 1 should exist in interpolated state")
	assert_almost_eq(out.players[1].local_position.x, 0.5, 0.001, "Player 1 local X interpolates")
	assert_almost_eq(out.players[1].local_position.z, -0.5, 0.001, "Player 1 local Z interpolates")
	assert_true(not out.players.has(2), "Removed player 2 should not remain in target snapshot B")
	assert_true(out.players.has(3), "Newly joined player 3 should appear from snapshot B")
	assert_almost_eq(out.players[3].local_position.x, 0.5, 0.001, "Player 3 spawns at B local X")
	assert_eq(out.players[3].color_index, 2, "Player 3 preserves discrete color_index")
	assert_eq(out.stations.get("helm", 0), 1, "Stations reflect latest received snapshot immediately")


func test_out_of_order_ticks_ignored_and_underrun_clamps_without_overshoot() -> void:
	var interp := SnapshotInterpolator.new()
	assert_true(interp.push_snapshot(_make_snapshot(6, Vector3(0.0, 0.0, -2.0), 0.0, 6.0, Vector2(0.0, -6.0))), "Accept tick 6")
	assert_true(interp.push_snapshot(_make_snapshot(9, Vector3(0.0, 0.0, -5.0), 0.0, 6.0, Vector2(0.0, -6.0))), "Accept tick 9")
	assert_true(not interp.push_snapshot(_make_snapshot(9, Vector3(0.0, 0.0, -99.0))), "Reject duplicate tick 9")
	assert_true(not interp.push_snapshot(_make_snapshot(7, Vector3(0.0, 0.0, -88.0))), "Reject out-of-order tick 7")
	assert_eq(interp.get_buffer_size(), 2, "Buffer keeps only valid increasing ticks")
	assert_eq(interp.get_latest_tick(), 9, "Latest tick remains 9")

	var out := GameState.new()
	var prev_z := -2.0
	for _i in range(30):
		assert_true(interp.step(out, SnapshotInterpolator.FIXED_DELTA), "step succeeds during and after underrun")
		assert_true(out.boat.world_position.z <= prev_z + 0.0001, "Boat Z must not rewind during underrun")
		assert_true(out.boat.world_position.z >= -5.0001, "Boat Z must not overshoot/extrapolate past latest snapshot")
		prev_z = out.boat.world_position.z

	assert_almost_eq(out.boat.world_position.z, -5.0, 0.001, "Underrun clamps cleanly to latest snapshot Z")


func test_adaptive_delay_scales_with_tick_interval_and_smooths_jitter() -> void:
	var interp_rate := SnapshotInterpolator.new()
	interp_rate.push_snapshot(_make_snapshot(3, Vector3.ZERO))
	interp_rate.push_snapshot(_make_snapshot(6, Vector3(0.0, 0.0, -0.3)))
	interp_rate.push_snapshot(_make_snapshot(9, Vector3(0.0, 0.0, -0.6)))
	assert_almost_eq(interp_rate.current_delay, 0.1, 0.001, "20 Hz (50ms interval) yields 100ms delay")

	interp_rate.push_snapshot(_make_snapshot(21, Vector3(0.0, 0.0, -1.8)))
	interp_rate.push_snapshot(_make_snapshot(33, Vector3(0.0, 0.0, -3.0)))
	assert_almost_eq(interp_rate.current_delay, 0.4, 0.001, "5 Hz (200ms interval) scales delay to 400ms")

	interp_rate.push_snapshot(_make_snapshot(39, Vector3(0.0, 0.0, -3.6)))
	assert_almost_eq(interp_rate.current_delay, 0.2, 0.001, "10 Hz (100ms interval) scales delay to 200ms")

	# Jittered / bursty arrivals at 20 Hz should still yield smooth monotonic per-tick motion
	var interp_jitter := SnapshotInterpolator.new()
	var jitter_pattern: Array[int] = [0, 1, -1, 2, -1, 0, 1, -1, 2, -1, 0, 1, -1, 2, -1, 0]
	var schedule: Dictionary = {}
	for idx in range(jitter_pattern.size()):
		var snap_tick := (idx + 1) * 3
		var arrive_frame := snap_tick + jitter_pattern[idx]
		var snap_z := -6.0 * float(snap_tick) * SnapshotInterpolator.FIXED_DELTA
		var snap := _make_snapshot(snap_tick, Vector3(0.0, 0.0, snap_z), 0.0, 6.0, Vector2(0.0, -6.0))
		if not schedule.has(arrive_frame):
			schedule[arrive_frame] = []
		schedule[arrive_frame].append(snap)

	var out := GameState.new()
	var prev_z := 0.0
	var measured_steps := 0
	for frame in range(1, 43):
		if schedule.has(frame):
			for snap in schedule[frame]:
				interp_jitter.push_snapshot(snap)
		if interp_jitter.get_buffer_size() > 0:
			interp_jitter.step(out, SnapshotInterpolator.FIXED_DELTA)
			if frame == 14:
				prev_z = out.boat.world_position.z
			elif frame >= 15 and frame <= 38:
				var step_dz := prev_z - out.boat.world_position.z
				assert_true(step_dz > 0.04, "Jittered stream must not stall at frame %d (dz=%.4f)" % [frame, step_dz])
				assert_true(step_dz < 0.18, "Jittered stream must not jump/teleport at frame %d (dz=%.4f)" % [frame, step_dz])
				prev_z = out.boat.world_position.z
				measured_steps += 1

	assert_eq(measured_steps, 24, "Measured all 24 steady-state jittered frames")


func test_latency_simulator_delays_client_traffic_and_is_disabled_in_prod() -> void:
	var parsed := NetworkManager.parse_cli_args(PackedStringArray(["--join", "127.0.0.1", "--latency", "100", "--jitter", "15"]))
	assert_eq(parsed.get("latency_ms", -1), 100, "parse_cli_args parses --latency")
	assert_eq(parsed.get("jitter_ms", -1), 15, "parse_cli_args parses --jitter")

	var test_cfg := EnvConfig.load_from_sources(PackedStringArray(["--env", "test"]))
	var client_net := NetworkManager.new()
	client_net.configure_from_args(PackedStringArray(["--join", "127.0.0.1", "--latency", "100", "--jitter", "0"]), test_cfg)
	assert_eq(client_net.sim_latency_ms, 100, "Test profile accepts --latency 100")
	assert_eq(client_net.sim_jitter_ms, 0, "Test profile accepts --jitter 0")

	var flushed_outgoing: Array = []
	var delivered_snapshots: Array = []
	client_net.client_outgoing_flushed.connect(func(pkt: Dictionary) -> void:
		flushed_outgoing.append(pkt)
	)
	client_net.game_snapshot_received.connect(func(snap: Dictionary) -> void:
		delivered_snapshots.append(snap)
	)

	var client_state := GameState.new()
	var client_input := PlayerInput.new()
	var boat_sim := BoatSimulator.new()
	var crew_sim := CrewSimulator.new()
	var station_sim := StationSimulator.new()

	# Enqueue 1 incoming snapshot + tick 0 outgoing interact & move input (50ms = 3 ticks each way)
	client_net.receive_incoming_game_snapshot(_make_snapshot(6, Vector3(0.0, 0.0, -3.0)))
	client_input.move_z = -1.0
	client_input.interact = true
	client_net.step_game_tick(client_state, client_input, boat_sim, crew_sim, station_sim)
	assert_eq(flushed_outgoing.size(), 0, "Outgoing packets delayed on tick 0")
	assert_eq(delivered_snapshots.size(), 0, "Incoming snapshot delayed on tick 0")

	client_input.interact = false
	client_input.move_z = 0.0
	# Ticks 1 and 2: elapsed 16.7ms and 33.3ms (< 50ms)
	client_net.step_game_tick(client_state, client_input, boat_sim, crew_sim, station_sim)
	client_net.step_game_tick(client_state, client_input, boat_sim, crew_sim, station_sim)
	assert_eq(flushed_outgoing.size(), 0, "Outgoing packets still delayed at 33.3ms")
	assert_eq(delivered_snapshots.size(), 0, "Incoming snapshot still delayed at 33.3ms")

	# Tick 3: elapsed 50.0ms -> tick 0 interact + input + incoming snapshot delivered
	client_net.step_game_tick(client_state, client_input, boat_sim, crew_sim, station_sim)
	assert_eq(delivered_snapshots.size(), 1, "Incoming snapshot delivered after 50ms (RTT/2)")
	assert_eq(int(delivered_snapshots[0].get("tick", 0)), 6, "Delivered snapshot preserves tick")

	var saw_interact := false
	var saw_move_input := false
	for pkt in flushed_outgoing:
		if str(pkt.get("kind", "")) == "interact":
			saw_interact = true
		elif str(pkt.get("kind", "")) == "input":
			var payload: Dictionary = pkt.get("payload", {})
			if is_equal_approx(float(payload.get("move_z", 0.0)), -1.0):
				saw_move_input = true
	assert_true(saw_interact, "Reliable interact event delayed and not lost")
	assert_true(saw_move_input, "Delayed movement input delivered after 50ms (RTT/2)")

	assert_true(not client_net.toggle_interpolation(), "Test mode allows toggling interpolation OFF")
	assert_true(client_net.toggle_interpolation(), "Test mode allows toggling interpolation back ON")

	# Prod profile must force latency/jitter to 0 and keep interpolation ON
	var prod_cfg := EnvConfig.load_from_sources(PackedStringArray(["--env", "prod"]))
	var prod_net := NetworkManager.new()
	prod_net.configure_from_args(PackedStringArray(["--join", "10.0.0.1", "--latency", "200", "--jitter", "30"]), prod_cfg)
	assert_eq(prod_net.sim_latency_ms, 0, "Prod profile forces sim_latency_ms to 0")
	assert_eq(prod_net.sim_jitter_ms, 0, "Prod profile forces sim_jitter_ms to 0")
	assert_true(prod_net.interpolation_enabled, "Prod profile keeps interpolation enabled")
	assert_eq(prod_net.cycle_latency_preset(), [0, 0], "Prod profile blocks latency preset cycling")
	assert_true(prod_net.toggle_interpolation(), "Prod profile blocks disabling interpolation")

	client_net.free()
	prod_net.free()
