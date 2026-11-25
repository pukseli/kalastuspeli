extends "res://tests/test_case.gd"


func test_given_bare_game_state_when_created_then_items_and_rods_empty() -> void:
	var default_state := GameState.new()
	assert_true(not default_state.items.is_empty(), "Default GameState.new() populates initial items")
	assert_true(not default_state.rods.is_empty(), "Default GameState.new() populates initial rods")

	var bare_state := GameState.new(false)
	assert_true(bare_state.items.is_empty(), "GameState.new(false) skips initial item allocation")
	assert_true(bare_state.rods.is_empty(), "GameState.new(false) skips initial rod allocation")


func test_given_states_when_copy_from_then_all_fields_equal_without_dict_roundtrip() -> void:
	var src_fish := FishState.new()
	src_fish.rod_id = "rod_2"
	src_fish.species = FishState.SPECIES_PIKE
	src_fish.weight_kg = 7.25
	src_fish.size_class = FishState.SIZE_LARGE
	src_fish.state = FishState.STATE_READY_TO_LAND
	src_fish.stamina = 0.33
	src_fish.drag_rate = 1.15
	src_fish.surge_timer = 0.45
	src_fish.surge_cooldown = 1.85
	src_fish.jump_progress = 0.6
	src_fish.lift_progress = 0.4
	src_fish.scoop_progress = 0.75
	src_fish.detach_progress = 0.9
	src_fish.hooked_time = 14.0
	src_fish.unattended_time = 2.5
	src_fish.surfaced = true
	src_fish.fight_phase = 2.1

	var dst_fish := FishState.new()
	dst_fish.copy_from(src_fish)
	assert_eq(dst_fish.to_dict(), src_fish.to_dict(), "FishState.copy_from copies all 17 fields accurately")

	var src_board := PlanerBoard.new()
	src_board.side = PlanerBoard.SIDE_LEFT
	src_board.attached = false
	src_board.lateral_offset = -8.4
	src_board.line_out = 19.5
	src_board.state = PlanerBoard.STATE_TRIPPED
	src_board.snag_world_position = Vector2(12.0, -34.0)
	src_board.pull_back_offset = 2.4
	src_board.submersion = 0.55
	src_board.flag_angle = -68.0
	src_board.shake_intensity = 0.7
	src_board.inward_drift_force = 1.9

	var dst_board := PlanerBoard.new()
	dst_board.copy_from(src_board)
	assert_eq(dst_board.to_dict(), src_board.to_dict(), "PlanerBoard.copy_from copies all 11 fields accurately")

	var src_item := HeldItem.new()
	src_item.id = "net_1"
	src_item.item_type = ItemConfig.ITEM_TYPE_NET
	src_item.color_index = 2
	src_item.carrier_peer_id = 3
	src_item.holder_id = ""
	src_item.last_holder_id = "rod_-1"
	src_item.deck_position = Vector3(0.4, 0.25, 1.1)

	var dst_item := HeldItem.new()
	dst_item.copy_from(src_item)
	assert_eq(dst_item.to_dict(), src_item.to_dict(), "HeldItem.copy_from copies all 7 fields accurately")


func test_given_pushed_snapshot_when_get_latest_state_then_parsed_state_uses_configured_item_config() -> void:
	var cfg := ItemConfig.create_default_config(4, 1)
	var host_state := GameState.new()
	host_state.configure_items(cfg)
	host_state.tick = 18
	host_state.boat.world_position = Vector3(4.0, 0.0, -9.0)

	var interp := SnapshotInterpolator.new()
	interp.item_config = cfg
	assert_true(interp.get_latest_state() == null, "Empty interpolator returns null latest state")
	assert_true(interp.push_snapshot(host_state.to_dict()), "Push snapshot succeeds")

	var latest := interp.get_latest_state()
	assert_true(latest != null, "get_latest_state returns parsed GameState")
	assert_eq(latest.tick, 18, "Latest state has snapshot tick")
	assert_true(is_same(latest.item_config, cfg), "Parsed state shares configured ItemConfig reference")


func test_given_out_of_order_snapshot_or_latency_drop_when_applied_then_older_tick_rejected() -> void:
	var client_net := NetworkManager.new()
	client_net.configure_from_args(PackedStringArray(["--join", "127.0.0.1", "--latency", "200"]))
	var client_state := GameState.new()

	var received_ticks: Array[int] = []
	client_net.game_snapshot_received.connect(func(snap: Dictionary) -> void:
		received_ticks.append(int(snap.get("tick", 0)))
		client_net.apply_game_snapshot(client_state, snap)
	)

	var s10 := GameState.new()
	s10.tick = 10
	s10.boat.world_position = Vector3(0.0, 0.0, -10.0)
	var s20 := GameState.new()
	s20.tick = 20
	s20.boat.world_position = Vector3(0.0, 0.0, -20.0)

	# Queue tick 10 under 200ms latency, then drop latency to 0ms and receive tick 20
	client_net.receive_incoming_game_snapshot(s10.to_dict())
	client_net.set_sim_latency(0, 0)
	client_net.receive_incoming_game_snapshot(s20.to_dict())

	# Step client clock past 200ms so any queued snapshots drain
	for _i in range(15):
		client_net.step_game_tick(client_state, PlayerInput.new(), BoatSimulator.new(), CrewSimulator.new())

	assert_eq(client_state.tick, 20, "Client GameState remains at newest tick 20 and never steps backward to tick 10")
	assert_almost_eq(client_state.boat.world_position.z, -20.0, 0.001, "Older snapshot never overwrites newer boat position")
	client_net.free()


func test_given_offline_vs_host_mode_when_snapshot_tick_then_offline_skips_and_host_emits() -> void:
	var boat_sim := BoatSimulator.new()
	var crew_sim := CrewSimulator.new()
	var station_sim := StationSimulator.new()
	var inp := PlayerInput.new()

	var offline_net := NetworkManager.new()
	offline_net.configure_from_args(PackedStringArray(["--sync-hz", "60"]))
	var offline_state := GameState.new()
	var offline_snap := offline_net.step_game_tick(offline_state, inp, boat_sim, crew_sim, station_sim)
	assert_true(offline_snap.is_empty(), "Offline mode skips to_dict() serialization on snapshot tick")

	var host_net := NetworkManager.new()
	host_net.configure_from_args(PackedStringArray(["--host", "--sync-hz", "60"]))
	var host_state := GameState.new()
	var host_snap := host_net.step_game_tick(host_state, inp, boat_sim, crew_sim, station_sim)
	assert_true(not host_snap.is_empty(), "Host mode still returns serialized snapshot dict on snapshot tick")

	offline_net.free()
	host_net.free()
