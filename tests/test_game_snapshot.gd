extends "res://tests/test_case.gd"


func _step_full_sim(
	snap: GameSnapshot,
	state: GameState,
	boat_sim: BoatSimulator,
	crew_sim: CrewSimulator,
	station_sim: StationSimulator,
	item_sim: ItemSimulator,
	rod_sim: RodSimulator,
	fish_sim: FishSimulator
) -> Array[Dictionary]:
	var triggered := snap.step(state, rod_sim, fish_sim, GameSnapshot.FIXED_DELTA)
	var inputs: Dictionary = {1: PlayerInput.new()}
	var was_at_station: Dictionary = {1: state.is_player_at_station(1)}
	station_sim.step(state, inputs, CrewSimulator.FIXED_DELTA)
	item_sim.step(state, inputs, CrewSimulator.FIXED_DELTA, was_at_station)
	station_sim.apply_helm_input_to_boat(state, inputs, BoatSimulator.FIXED_DELTA, boat_sim.config.max_steering_angle)
	boat_sim.step(state.boat, station_sim.get_active_boat_input(state, boat_sim.config.max_steering_angle), BoatSimulator.FIXED_DELTA)
	crew_sim.step(state, inputs, CrewSimulator.FIXED_DELTA)
	rod_sim.step(state, inputs, RodSimulator.FIXED_DELTA)
	fish_sim.step(state, inputs, rod_sim, FishSimulator.FIXED_DELTA)
	state.tick += 1
	return triggered


func test_whale_strike_2s_loads_steady_trolling_and_strikes_at_two_seconds() -> void:
	var snap := GameSnapshot.load_from_file("whale_strike_2s")
	assert_true(snap != null, "whale_strike_2s snapshot loads from config/snapshots/")
	if snap == null:
		return

	var state := GameState.new()
	var boat_sim := BoatSimulator.new()
	var crew_sim := CrewSimulator.new()
	var station_sim := StationSimulator.new()
	var item_sim := ItemSimulator.new(state.item_config)
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	var orig_bite_rate := fish_sim.config.base_bite_rate_per_rod

	assert_true(snap.apply_to(state, fish_sim, true), "Snapshot applies cleanly to GameState")
	assert_eq(state.get_deployed_rod_count(), 6, "All 6 trolling rods start deployed")
	assert_almost_eq(state.boat.forward_speed, 3.0, 0.01, "Boat starts cruising at 3.0 m/s")
	assert_true(state.fishes.is_empty(), "No fish is hooked before the 2-second mark")
	assert_almost_eq(fish_sim.config.base_bite_rate_per_rod, 0.0, 0.0001, "Automatic random bites are suppressed while strike event is pending")

	for _tick in range(119):
		var early_events := _step_full_sim(snap, state, boat_sim, crew_sim, station_sim, item_sim, rod_sim, fish_sim)
		assert_true(early_events.is_empty(), "Scheduled strike does not fire early")

	assert_true(state.fishes.is_empty(), "Still zero hooked fish at 119 ticks (1.983 s)")
	assert_true(state.boat.forward_speed >= 2.95 and state.boat.forward_speed <= 3.05, "Boat maintains steady ~3.0 m/s cruise without helm occupant")
	for rid in state.rods:
		var rod := state.get_rod_state(str(rid))
		assert_true(rod != null and rod.planer.state != PlanerBoard.STATE_TANGLED and rod.planer.state != PlanerBoard.STATE_SNAGGED, "Rod %s stays tangle-free before strike" % str(rid))

	var strike_events := _step_full_sim(snap, state, boat_sim, crew_sim, station_sim, item_sim, rod_sim, fish_sim)
	assert_eq(strike_events.size(), 1, "Whale strike event fires at exactly 2.0 seconds (120 ticks)")
	if strike_events.size() == 1:
		assert_eq(str(strike_events[0].get("type", "")), "force_bite", "Event type is force_bite")
		assert_eq(str(strike_events[0].get("rod_id", "")), "rod_4", "Strike targets rod_4")
		assert_eq(str(strike_events[0].get("species", "")), FishState.SPECIES_BLUE_WHALE, "Strike spawns blue_whale")
		assert_true(bool(strike_events[0].get("success", false)), "Strike succeeds")

	var fish := state.get_fish_state("rod_4")
	var rod_4 := state.get_rod_state("rod_4")
	assert_true(fish != null, "FishState created on rod_4")
	if fish != null and rod_4 != null:
		assert_eq(fish.species, FishState.SPECIES_BLUE_WHALE, "Hooked species is blue_whale")
		assert_eq(fish.size_class, FishState.SIZE_MONSTER, "Whale size_class is MONSTER")
		assert_almost_eq(fish.weight_kg, 115000.0, 0.1, "Whale weight matches snapshot spec")
		assert_true(fish.is_jumping(), "Whale begins breach jump on strike")
		assert_eq(rod_4.planer.state, PlanerBoard.STATE_TRIPPED, "Starboard planer trips on whale strike")
		assert_true(rod_4.is_drag_slipping, "Reel drag slips under whale pull")
		assert_true(fish.drag_rate > 0.5, "Drag slip / raikka rate activates immediately")
		assert_true(rod_4.line_tension >= 59.0, "Line tension rises to drag setting")
	assert_almost_eq(fish_sim.config.base_bite_rate_per_rod, orig_bite_rate, 0.0001, "Automatic bite rate restores immediately after event fires")


func test_snapshot_reload_preserves_monotonic_tick_and_restores_bite_rate() -> void:
	var snap := GameSnapshot.load_from_file("whale_strike_2s")
	assert_true(snap != null, "whale_strike_2s snapshot loads")
	if snap == null:
		return

	var state := GameState.new()
	var boat_sim := BoatSimulator.new()
	var crew_sim := CrewSimulator.new()
	var station_sim := StationSimulator.new()
	var item_sim := ItemSimulator.new(state.item_config)
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	var orig_bite_rate := fish_sim.config.base_bite_rate_per_rod

	snap.apply_to(state, fish_sim, true)
	for _i in range(30):
		_step_full_sim(snap, state, boat_sim, crew_sim, station_sim, item_sim, rod_sim, fish_sim)

	var tick_mid := state.tick
	assert_almost_eq(fish_sim.config.base_bite_rate_per_rod, 0.0, 0.0001, "Bite rate suppressed mid-countdown")
	assert_true(snap.apply_to(state, fish_sim, true), "Reloading mid-countdown succeeds")
	assert_true(state.tick > tick_mid, "Reload keeps GameState.tick monotonically increasing (%d > %d)" % [state.tick, tick_mid])
	assert_true(state.fishes.is_empty(), "Reload clears fishes")
	assert_true(snap.has_pending_events(), "Reload re-arms pending scheduled events")

	for _i in range(120):
		_step_full_sim(snap, state, boat_sim, crew_sim, station_sim, item_sim, rod_sim, fish_sim)

	assert_true(state.has_fish_on_rod("rod_4"), "Whale strikes 2s after reload")
	assert_almost_eq(fish_sim.config.base_bite_rate_per_rod, orig_bite_rate, 0.0001, "Original bite rate restored even after mid-countdown reload")

	for _i in range(30):
		_step_full_sim(snap, state, boat_sim, crew_sim, station_sim, item_sim, rod_sim, fish_sim)

	var tick_high := state.tick
	snap.apply_to(state, fish_sim, true)
	assert_true(state.tick > tick_high, "Second reload above snapshot tick still increments monotonically")
	assert_true(state.fishes.is_empty(), "Second reload resets fishes")


func test_snapshot_save_and_load_roundtrip_via_json_file() -> void:
	var src := GameState.new()
	src.tick = 456
	src.boat.world_position = Vector3(12.5, 0.0, -34.25)
	src.boat.forward_speed = 2.75
	src.boat.throttle = 0.25
	src.ensure_player(1)
	var rod_3 := src.get_rod_state("rod_3")
	rod_3.drag_setting = 85.0
	rod_3.planer.line_out = 21.5
	rod_3.planer.state = PlanerBoard.STATE_TROLLING
	src.record_catch(FishState.SPECIES_PIKE, 6.4, FishState.SIZE_LARGE, "net")

	var test_path := "user://snapshots/_test_roundtrip.json"
	var snap := GameSnapshot.capture_from_state(
		src,
		"roundtrip_test",
		"Save load roundtrip test",
		[{"delay_sec": 1.5, "type": "fish_notice", "text": "Ping", "duration": 2.0}],
		98765,
		false
	)
	assert_true(snap.save_to_file(test_path), "save_to_file writes JSON to user://snapshots/")

	var loaded := GameSnapshot.load_from_file(test_path)
	assert_true(loaded != null, "load_from_file reads back saved JSON snapshot")
	if loaded != null:
		assert_eq(loaded.snapshot_name, "roundtrip_test", "Snapshot name roundtrips")
		assert_eq(loaded.rng_seed, 98765, "RNG seed roundtrips")
		assert_eq(loaded.scheduled_events.size(), 1, "Scheduled events roundtrip")

		var dst := GameState.new()
		assert_true(loaded.apply_to(dst, null, false), "Loaded snapshot applies to fresh GameState")
		assert_eq(dst.tick, 456, "Tick roundtrips when monotonic override is disabled")
		assert_almost_eq(dst.boat.world_position.x, 12.5, 0.001, "Boat X roundtrips")
		assert_almost_eq(dst.boat.world_position.z, -34.25, 0.001, "Boat Z roundtrips")
		assert_almost_eq(dst.boat.forward_speed, 2.75, 0.001, "Boat forward_speed roundtrips")
		var dst_rod_3 := dst.get_rod_state("rod_3")
		assert_almost_eq(dst_rod_3.drag_setting, 85.0, 0.001, "Rod drag_setting roundtrips")
		assert_almost_eq(dst_rod_3.planer.line_out, 21.5, 0.001, "Rod line_out roundtrips")
		assert_eq(dst.get_catch_count(), 1, "Catch count roundtrips")
		assert_almost_eq(dst.get_biggest_catch_weight(), 6.4, 0.001, "Biggest catch weight roundtrips")

	var dir := DirAccess.open("user://snapshots")
	if dir != null and dir.file_exists("_test_roundtrip.json"):
		dir.remove("_test_roundtrip.json")


func test_cli_parsing_path_resolution_and_prod_profile_guards() -> void:
	assert_eq(
		GameSnapshot.extract_cli_snapshot(PackedStringArray(["--env", "test", "--snapshot", "whale_strike_2s"])),
		"whale_strike_2s",
		"Parses space-separated --snapshot flag"
	)
	assert_eq(
		GameSnapshot.extract_cli_snapshot(PackedStringArray(["--snapshot=whale_strike_2s"])),
		"whale_strike_2s",
		"Parses --snapshot=value flag"
	)
	assert_eq(
		GameSnapshot.extract_cli_snapshot(PackedStringArray(["--snapshot"])),
		"",
		"Returns empty when --snapshot has no value"
	)
	assert_eq(
		GameSnapshot.extract_cli_snapshot(PackedStringArray(["--snapshot", "--host"])),
		"",
		"Ignores next CLI flag after --snapshot"
	)
	assert_eq(
		GameSnapshot.resolve_path("whale_strike_2s"),
		"res://config/snapshots/whale_strike_2s.json",
		"Resolves bare snapshot name to res://config/snapshots/<name>.json"
	)
	assert_eq(
		GameSnapshot.resolve_path("user://snapshots/quicksave.json"),
		"user://snapshots/quicksave.json",
		"Preserves explicit user:// snapshot paths"
	)

	var prod_cfg := EnvConfig.load_from_sources(PackedStringArray(["--env", "prod", "--snapshot", "whale_strike_2s"]))
	assert_true(prod_cfg.is_prod(), "Prod profile activates even if --snapshot is supplied")
	assert_true(not prod_cfg.debug_hotkeys, "Prod profile keeps debug hotkeys disabled")


func test_force_bite_event_falls_back_when_target_rod_stowed() -> void:
	var snap := GameSnapshot.load_from_file("whale_strike_2s")
	assert_true(snap != null, "whale_strike_2s snapshot loads")
	if snap == null:
		return

	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	snap.apply_to(state, fish_sim, true)

	var rod_4 := state.get_rod_state("rod_4")
	rod_4.planer.line_out = 0.0
	rod_4.planer.state = PlanerBoard.STATE_STOWED

	for _i in range(120):
		snap.step(state, rod_sim, fish_sim, GameSnapshot.FIXED_DELTA)
		rod_sim.step(state, {}, RodSimulator.FIXED_DELTA)
		fish_sim.step(state, {}, rod_sim, FishSimulator.FIXED_DELTA)

	assert_eq(state.get_hooked_fish_count(), 1, "Fallback still hooks exactly one blue whale")
	assert_true(not state.has_fish_on_rod("rod_4"), "Stowed target rod_4 is skipped")
	var hooked_rod := ""
	for fid in state.fishes:
		hooked_rod = str(fid)
	assert_true(not hooked_rod.is_empty() and hooked_rod != "rod_4", "Another deployed rod takes the whale strike")
	var fish := state.get_fish_state(hooked_rod)
	assert_true(fish != null and fish.species == FishState.SPECIES_BLUE_WHALE, "Fallback hooked fish is still a blue_whale")
