extends "res://tests/test_case.gd"


func test_given_two_captures_when_blend_half_then_boat_pos_and_heading_midpoint_with_pi_wrap() -> void:
	var ri := RenderInterpolator.new()
	var s1 := GameState.new(false)
	s1.boat.world_position = Vector3(10.0, 0.0, -20.0)
	s1.boat.heading = 3.05
	ri.capture(s1)

	var b_first := ri.blend(0.5)
	assert_almost_eq((b_first["boat_pos"] as Vector3).x, 10.0, 0.001, "First capture snaps prev and curr X")

	var s2 := GameState.new(false)
	s2.boat.world_position = Vector3(14.0, 0.0, -30.0)
	s2.boat.heading = -3.05
	ri.capture(s2)

	var b_mid := ri.blend(0.5)
	var pos := b_mid["boat_pos"] as Vector3
	var heading := float(b_mid["boat_heading"])
	assert_almost_eq(pos.x, 12.0, 0.001, "Blended boat X is midpoint (12.0)")
	assert_almost_eq(pos.z, -25.0, 0.001, "Blended boat Z is midpoint (-25.0)")
	assert_true(absf(angle_difference(heading, PI)) < 0.01, "Blended heading wraps across +/-PI boundary via shortest arc")


func test_given_players_when_blend_then_local_positions_lerped_and_new_player_snaps() -> void:
	var ri := RenderInterpolator.new()
	var s1 := GameState.new(false)
	var p1_a := s1.ensure_player(1)
	p1_a.local_position = Vector3(-1.0, 0.25, 0.0)
	ri.capture(s1)

	var s2 := GameState.new(false)
	var p1_b := s2.ensure_player(1)
	p1_b.local_position = Vector3(1.0, 0.25, 2.0)
	var p2_b := s2.ensure_player(2)
	p2_b.local_position = Vector3(0.5, 0.25, -1.0)
	ri.capture(s2)

	var blended := ri.blend(0.25)
	var players: Dictionary = blended["players"]
	var pos1 := players[1] as Vector3
	var pos2 := players[2] as Vector3
	assert_almost_eq(pos1.x, -0.5, 0.001, "Existing player X interpolates at alpha=0.25")
	assert_almost_eq(pos1.z, 0.5, 0.001, "Existing player Z interpolates at alpha=0.25")
	assert_almost_eq(pos2.x, 0.5, 0.001, "Newly joined player snaps X to current position")
	assert_almost_eq(pos2.z, -1.0, 0.001, "Newly joined player snaps Z to current position")


func test_given_camera_when_stepped_60hz_vs_144hz_then_same_result_within_eps() -> void:
	var cam_60 := CameraController.new()
	var cam_144 := CameraController.new()

	cam_60.apply_axes(1.0, 0.5, 1.0)
	cam_60.apply_zoom(3.0)
	cam_144.apply_axes(1.0, 0.5, 1.0)
	cam_144.apply_zoom(3.0)

	for _i in range(30):
		cam_60.step(false, 1.0 / 60.0)
	for _i in range(72):
		cam_144.step(false, 1.0 / 144.0)

	assert_almost_eq(cam_60.current_yaw, cam_144.current_yaw, 0.0001, "Camera yaw after 0.5s matches at 60 Hz and 144 Hz")
	assert_almost_eq(cam_60.current_pitch, cam_144.current_pitch, 0.0001, "Camera pitch after 0.5s matches at 60 Hz and 144 Hz")
	assert_almost_eq(cam_60.current_dist, cam_144.current_dist, 0.0001, "Camera dist after 0.5s matches at 60 Hz and 144 Hz")


func test_given_world_view_when_update_frame_then_boat_players_and_lines_container_follow_blend() -> void:
	var world := WorldView.new()
	var ri := RenderInterpolator.new()

	var s1 := GameState.new()
	s1.boat.world_position = Vector3(0.0, 0.0, 0.0)
	s1.boat.heading = 0.0
	var p1 := s1.ensure_player(1)
	p1.local_position = Vector3(0.0, 0.25, 0.0)
	ri.capture(s1)

	var s2 := GameState.new()
	s2.boat.world_position = Vector3(0.0, 0.0, -4.0)
	s2.boat.heading = 0.0
	var p1_next := s2.ensure_player(1)
	p1_next.local_position = Vector3(1.0, 0.25, 2.0)
	ri.capture(s2)

	# Tick state applied at s2, then visual frame rendered at alpha=0.5 (midpoint between s1 and s2)
	world.apply_game_state(s2, "", 1, false, false)
	var blend := ri.blend(0.5)
	world.update_frame(blend, 1.0 / 144.0)

	assert_almost_eq(world.boat_view.position.z, -2.0, 0.001, "BoatView Z follows blended position (-2.0)")
	var pv := world.boat_view.get_player_view(1)
	assert_true(pv != null, "PlayerView 1 exists")
	assert_almost_eq(pv.position.x, 0.5, 0.001, "PlayerView X follows blended local position (0.5)")
	assert_almost_eq(pv.position.z, 1.0, 0.001, "PlayerView Z follows blended local position (1.0)")
	assert_almost_eq(world.trolling_lines_container.position.z, 2.0, 0.001, "TrollingLinesContainer shifts by +2.0 to match blended boat (-2.0 vs tick -4.0)")

	free_node(world)


func test_given_raikka_when_frame_delta_varies_then_cooldown_scales_with_delta() -> void:
	var world := WorldView.new()
	var state := GameState.new()
	var fish := FishState.new()
	fish.rod_id = "rod_1"
	fish.drag_rate = 1.0
	state.fishes["rod_1"] = fish

	world._raikka_cooldown = 0.10
	world._step_raikka_audio(state, 0.04)
	assert_almost_eq(world._raikka_cooldown, 0.06, 0.0001, "Raikka cooldown decrements by passed frame delta (0.04s)")

	free_node(world)
