extends "res://tests/test_case.gd"


func test_given_50_catches_when_recorded_then_count_50_log_capped_and_biggest_tracked() -> void:
	var state := GameState.new()
	state.record_catch(FishState.SPECIES_PIKE, 11.5, FishState.SIZE_MONSTER, "net")
	for i in range(49):
		state.record_catch(FishState.SPECIES_PERCH, 0.4 + float(i) * 0.01, FishState.SIZE_SMALL, "net")

	assert_eq(state.get_catch_count(), 50, "Total catch count tracks all 50 catches")
	assert_eq(state.catches.size(), GameState.CATCH_LOG_MAX, "Catch log array is capped at CATCH_LOG_MAX (20)")
	assert_almost_eq(state.get_biggest_catch_weight(), 11.5, 0.001, "Biggest catch weight survives even after first catch drops from log")


func test_given_summary_when_to_dict_from_dict_then_count_and_biggest_survive() -> void:
	var src := GameState.new()
	src.record_catch(FishState.SPECIES_ORCA, 4200.0, FishState.SIZE_MONSTER, "net")
	for _i in range(30):
		src.record_catch(FishState.SPECIES_VENDACE, 0.05, FishState.SIZE_SMALL, "hand_lift")

	var snap := src.to_dict()
	var dst := GameState.new()
	dst.from_dict(snap)

	assert_eq(dst.get_catch_count(), 31, "from_dict restores total catch_count across log cap")
	assert_eq(dst.catches.size(), GameState.CATCH_LOG_MAX, "from_dict preserves capped catches array")
	assert_almost_eq(dst.get_biggest_catch_weight(), 4200.0, 0.01, "from_dict restores biggest_catch_kg even when oldest catch is evicted")


func test_given_legacy_snapshot_without_catch_count_when_from_dict_then_falls_back_to_log() -> void:
	var snap := GameState.new().to_dict()
	snap.erase("catch_count")
	snap.erase("biggest_catch_kg")
	snap["catches"] = [
		{"species": FishState.SPECIES_PERCH, "weight_kg": 0.6, "size_class": FishState.SIZE_SMALL, "method": "net"},
		{"species": FishState.SPECIES_ZANDER, "weight_kg": 3.4, "size_class": FishState.SIZE_MEDIUM, "method": "net"},
	]

	var dst := GameState.new()
	dst.from_dict(snap)

	assert_eq(dst.get_catch_count(), 2, "Legacy snapshot without catch_count falls back to catches.size()")
	assert_almost_eq(dst.get_biggest_catch_weight(), 3.4, 0.001, "Legacy snapshot without biggest_catch_kg computes max weight from log")


func test_given_500_catches_when_serialized_then_snapshot_size_bounded() -> void:
	var empty_state := GameState.new()
	var empty_bytes := var_to_bytes(empty_state.to_dict()).size()

	var full_state := GameState.new()
	for i in range(500):
		full_state.record_catch(FishState.SPECIES_PERCH, 0.5, FishState.SIZE_SMALL, "net")
	var full_bytes := var_to_bytes(full_state.to_dict()).size()

	assert_true(full_bytes <= empty_bytes + 3500, "Snapshot with 500 catches remains bounded by CATCH_LOG_MAX (got %d vs empty %d)" % [full_bytes, empty_bytes])


func test_given_interpolator_without_new_catches_when_step_twice_then_catches_array_not_reallocated() -> void:
	var sa := GameState.new()
	sa.tick = 6
	sa.record_catch(FishState.SPECIES_PIKE, 5.2, FishState.SIZE_LARGE, "net")

	var sb := GameState.new()
	sb.tick = 12
	sb.record_catch(FishState.SPECIES_PIKE, 5.2, FishState.SIZE_LARGE, "net")

	var interp := SnapshotInterpolator.new()
	assert_true(interp.push_snapshot(sa.to_dict()), "Push first snapshot")
	assert_true(interp.push_snapshot(sb.to_dict()), "Push second snapshot")

	var render_state := GameState.new()
	assert_true(interp.step(render_state, SnapshotInterpolator.FIXED_DELTA), "First interpolator step")
	var first_catches_ref := render_state.catches
	assert_eq(render_state.get_catch_count(), 1, "Interpolated state has catch_count == 1")
	assert_almost_eq(render_state.get_biggest_catch_weight(), 5.2, 0.001, "Interpolated state has biggest_catch_kg == 5.2")

	assert_true(interp.step(render_state, SnapshotInterpolator.FIXED_DELTA), "Second interpolator step")
	assert_true(is_same(render_state.catches, first_catches_ref), "Interpolator does not reallocate catches array when catch count is unchanged")
