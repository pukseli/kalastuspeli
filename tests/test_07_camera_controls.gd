extends "res://tests/test_case.gd"


func test_default_deck_and_helm_views_and_mode_switch_reset() -> void:
	var state := GameState.new()
	state.boat.world_position = Vector3.ZERO
	state.boat.heading = 0.0
	state.ensure_player(1)

	var world := WorldView.new()
	world.apply_game_state(state, "", 1, true)

	# Default deck camera faces aft (+Z, heading + PI), pitch -28 deg, positioned forward of bow looking over deck toward stern
	assert_true(absf(angle_difference(world.camera.rotation.y, PI)) < 0.001, "Default deck camera faces aft (+Z)")
	assert_almost_eq(world.camera.rotation_degrees.x, -28.0, 0.05, "Default deck camera pitch is -28 deg")
	assert_true(world.camera.position.z < -3.6, "Default deck camera sits forward of bow so full deck and 25+ m behind stern are visible")

	# Rotate deck camera away from default, then enter helm
	world.camera_controller.apply_axes(1.0, 1.0, 0.5)
	world.camera_controller.apply_zoom(2.0)
	world.apply_game_state(state, "", 1, true)
	assert_true(absf(angle_difference(world.camera.rotation.y, PI)) > 0.2, "Deck camera rotates away from default before mode switch")

	state.stations[StationConfig.HELM_STATION_ID] = 1
	world.apply_game_state(state, "", 1, true)
	assert_true(absf(angle_difference(world.camera.rotation.y, 0.0)) < 0.001, "Helm camera resets to forward (-Z)")
	assert_almost_eq(world.camera.rotation_degrees.x, StationConfig.HELM_CAM_PITCH_DEG, 0.05, "Helm camera pitch matches StationConfig")
	assert_almost_eq(world.camera.position.x, StationConfig.HELM_CAM_OFFSET.x, 0.01, "Helm camera X matches HELM_CAM_OFFSET")
	assert_almost_eq(world.camera.position.y, StationConfig.HELM_CAM_OFFSET.y, 0.01, "Helm camera Y matches HELM_CAM_OFFSET")
	assert_almost_eq(world.camera.position.z, StationConfig.HELM_CAM_OFFSET.z, 0.01, "Helm camera Z matches HELM_CAM_OFFSET")

	# Rotate helm camera away, then leave helm -> resets to deck default aft view
	world.camera_controller.apply_axes(-1.0, 1.0, 0.5)
	world.apply_game_state(state, "", 1, true)
	state.stations[StationConfig.HELM_STATION_ID] = 0
	state.boat.heading = PI / 2.0
	world.apply_game_state(state, "", 1, true)
	assert_true(absf(angle_difference(world.camera.rotation.y, wrapf(PI / 2.0 + PI, -PI, PI))) < 0.001, "Leaving helm resets deck camera to aft relative to boat heading")
	assert_almost_eq(world.camera.rotation_degrees.x, -28.0, 0.05, "Leaving helm resets deck camera pitch to -28 deg")
	assert_almost_eq(world.camera_controller.current_dist, CameraController.DECK_DEFAULT_DIST, 0.01, "Leaving helm restores default deck orbit distance")

	free_node(world)


func test_camera_360_yaw_pitch_clamping_and_reset() -> void:
	var ctrl := CameraController.new()

	# Deck mode: full 360+ deg rotation wraps cleanly into [-PI, PI) and pitch clamps to [-65, -8]
	ctrl.apply_axes(1.0, 0.0, 3.5) # 3.5s * 120 deg/s = 420 deg -> +60 deg from PI
	assert_true(ctrl.target_yaw >= -PI and ctrl.target_yaw <= PI, "Deck yaw stays wrapped within [-PI, PI]")
	assert_true(absf(angle_difference(ctrl.target_yaw, wrapf(PI + deg_to_rad(60.0), -PI, PI))) < 0.01, "Deck 360-deg rotation wraps accurately past +/-180 deg")

	ctrl.apply_axes(0.0, 1.0, 5.0)
	assert_almost_eq(ctrl.target_pitch, CameraController.DECK_MAX_PITCH_DEG, 0.01, "Deck pitch clamps at upper bound (-8 deg)")
	ctrl.apply_axes(0.0, -1.0, 5.0)
	assert_almost_eq(ctrl.target_pitch, CameraController.DECK_MIN_PITCH_DEG, 0.01, "Deck pitch clamps at lower bound (-65 deg)")

	ctrl.reset_to_default(true)
	assert_true(absf(angle_difference(ctrl.current_yaw, PI)) < 0.001, "Deck reset restores aft yaw")
	assert_almost_eq(ctrl.current_pitch, CameraController.DECK_DEFAULT_PITCH_DEG, 0.01, "Deck reset restores -28 deg pitch")

	# Helm mode: full 360 deg yaw and pitch clamps to [-45, +25]
	ctrl.set_mode(true, true)
	ctrl.apply_axes(-1.0, 0.0, 2.0) # -240 deg -> +120 deg
	assert_true(absf(angle_difference(ctrl.target_yaw, deg_to_rad(120.0))) < 0.01, "Helm allows free 360-deg yaw wrap")

	ctrl.apply_axes(0.0, 1.0, 5.0)
	assert_almost_eq(ctrl.target_pitch, CameraController.HELM_MAX_PITCH_DEG, 0.01, "Helm pitch clamps at +25 deg")
	ctrl.apply_axes(0.0, -1.0, 5.0)
	assert_almost_eq(ctrl.target_pitch, CameraController.HELM_MIN_PITCH_DEG, 0.01, "Helm pitch clamps at -45 deg")

	ctrl.reset_to_default(true)
	assert_true(absf(angle_difference(ctrl.current_yaw, 0.0)) < 0.001, "Helm reset restores forward yaw")
	assert_almost_eq(ctrl.current_pitch, CameraController.HELM_DEFAULT_PITCH_DEG, 0.01, "Helm reset restores -15 deg pitch")


func test_screen_relative_deck_walk_projection_tracks_camera_yaw() -> void:
	# Facing bow (yaw = 0): W -> (0, -1), D -> (+1, 0)
	var w_bow := CameraController.project_deck_input(0.0, 1.0, 0.0)
	var d_bow := CameraController.project_deck_input(1.0, 0.0, 0.0)
	assert_almost_eq(w_bow.x, 0.0, 0.001, "Yaw 0: W move_x is 0")
	assert_almost_eq(w_bow.y, -1.0, 0.001, "Yaw 0: W moves toward bow (-Z)")
	assert_almost_eq(d_bow.x, 1.0, 0.001, "Yaw 0: D moves starboard (+X)")
	assert_almost_eq(d_bow.y, 0.0, 0.001, "Yaw 0: D move_z is 0")

	# Default aft view (yaw = PI): W -> (0, +1) toward stern, D -> (-1, 0) toward port (screen right)
	var w_aft := CameraController.project_deck_input(0.0, 1.0, PI)
	var d_aft := CameraController.project_deck_input(1.0, 0.0, PI)
	assert_almost_eq(w_aft.x, 0.0, 0.001, "Yaw PI: W move_x is 0")
	assert_almost_eq(w_aft.y, 1.0, 0.001, "Yaw PI: W moves toward stern (+Z)")
	assert_almost_eq(d_aft.x, -1.0, 0.001, "Yaw PI: D moves port (-X, right on screen)")
	assert_almost_eq(d_aft.y, 0.0, 0.001, "Yaw PI: D move_z is 0")

	# Facing port (yaw = +PI/2): W -> (-1, 0), D -> (0, -1)
	var w_port := CameraController.project_deck_input(0.0, 1.0, PI / 2.0)
	var d_port := CameraController.project_deck_input(1.0, 0.0, PI / 2.0)
	assert_almost_eq(w_port.x, -1.0, 0.001, "Yaw +PI/2: W moves port (-X)")
	assert_almost_eq(w_port.y, 0.0, 0.001, "Yaw +PI/2: W move_z is 0")
	assert_almost_eq(d_port.x, 0.0, 0.001, "Yaw +PI/2: D move_x is 0")
	assert_almost_eq(d_port.y, -1.0, 0.001, "Yaw +PI/2: D moves toward bow (-Z)")

	# Facing starboard (yaw = -PI/2): W -> (+1, 0), D -> (0, +1)
	var w_stbd := CameraController.project_deck_input(0.0, 1.0, -PI / 2.0)
	var d_stbd := CameraController.project_deck_input(1.0, 0.0, -PI / 2.0)
	assert_almost_eq(w_stbd.x, 1.0, 0.001, "Yaw -PI/2: W moves starboard (+X)")
	assert_almost_eq(w_stbd.y, 0.0, 0.001, "Yaw -PI/2: W move_z is 0")
	assert_almost_eq(d_stbd.x, 0.0, 0.001, "Yaw -PI/2: D move_x is 0")
	assert_almost_eq(d_stbd.y, 1.0, 0.001, "Yaw -PI/2: D moves toward stern (+Z)")


func test_control_profiles_and_zoom_clamping() -> void:
	# CLI parsing & cycling
	assert_eq(CameraController.parse_control_scheme_from_args(PackedStringArray([])), CameraController.SCHEME_ARROWS_WASD, "Default control scheme is arrows_wasd")
	assert_eq(CameraController.parse_control_scheme_from_args(PackedStringArray(["--controls", "wasd_mouse"])), CameraController.SCHEME_WASD_MOUSE, "CLI --controls parses wasd_mouse")

	# Profile arrows_wasd in helm: arrows drive boat, WASD turns PoV camera
	var helm_aw := CameraController.map_control_inputs(CameraController.SCHEME_ARROWS_WASD, true, -1.0, 1.0, 1.0, 1.0, 0.0)
	assert_almost_eq(float(helm_aw["throttle"]), 1.0, 0.001, "arrows_wasd helm: UP arrow controls throttle")
	assert_almost_eq(float(helm_aw["steering"]), -1.0, 0.001, "arrows_wasd helm: RIGHT arrow steers right (-1)")
	assert_almost_eq(float(helm_aw["cam_yaw_axis"]), 1.0, 0.001, "arrows_wasd helm: A turns camera left (+1)")
	assert_almost_eq(float(helm_aw["cam_pitch_axis"]), 1.0, 0.001, "arrows_wasd helm: W tilts camera up (+1)")

	# Profile arrows_wasd on deck: arrows STILL drive movement, WASD STILL turns PoV camera (keys never swap)
	var deck_aw := CameraController.map_control_inputs(CameraController.SCHEME_ARROWS_WASD, false, -1.0, -1.0, 0.0, 1.0, PI)
	assert_almost_eq(float(deck_aw["move_z"]), 1.0, 0.001, "arrows_wasd deck: UP arrow projects walk toward stern (+Z) when facing aft")
	assert_almost_eq(float(deck_aw["move_x"]), 0.0, 0.001, "arrows_wasd deck: UP arrow produces zero lateral walk")
	assert_almost_eq(float(deck_aw["cam_yaw_axis"]), 1.0, 0.001, "arrows_wasd deck: A turns camera left (+1)")
	assert_almost_eq(float(deck_aw["cam_pitch_axis"]), -1.0, 0.001, "arrows_wasd deck: S tilts camera down (-1)")

	# Profile wasd_mouse in helm: WASD drives boat, arrows ignored, keyboard camera axes stay 0 (mouse handles PoV)
	var helm_wm := CameraController.map_control_inputs(CameraController.SCHEME_WASD_MOUSE, true, -1.0, 1.0, 1.0, -1.0, 0.0)
	assert_almost_eq(float(helm_wm["throttle"]), 1.0, 0.001, "wasd_mouse helm: W controls throttle")
	assert_almost_eq(float(helm_wm["steering"]), 1.0, 0.001, "wasd_mouse helm: A steers left (+1)")
	assert_almost_eq(float(helm_wm["cam_yaw_axis"]), 0.0, 0.001, "wasd_mouse helm: keyboard does not turn camera yaw")
	assert_almost_eq(float(helm_wm["cam_pitch_axis"]), 0.0, 0.001, "wasd_mouse helm: keyboard does not turn camera pitch")

	# Profile wasd_mouse on deck: WASD STILL drives movement, keyboard camera axes stay 0 (keys never swap)
	var deck_wm := CameraController.map_control_inputs(CameraController.SCHEME_WASD_MOUSE, false, 0.0, 1.0, -1.0, -1.0, PI)
	assert_almost_eq(float(deck_wm["move_z"]), 1.0, 0.001, "wasd_mouse deck: W projects walk toward stern (+Z) when facing aft")
	assert_almost_eq(float(deck_wm["move_x"]), 0.0, 0.001, "wasd_mouse deck: W produces zero lateral walk")
	assert_almost_eq(float(deck_wm["cam_yaw_axis"]), 0.0, 0.001, "wasd_mouse deck: keyboard does not turn camera yaw")
	assert_almost_eq(float(deck_wm["cam_pitch_axis"]), 0.0, 0.001, "wasd_mouse deck: keyboard does not turn camera pitch")

	# Zoom clamping + mouse drag + helm distance lock
	var ctrl := CameraController.new()
	var initial_yaw := ctrl.target_yaw
	ctrl.apply_mouse_drag(Vector2(40.0, -20.0))
	assert_true(absf(angle_difference(ctrl.target_yaw, initial_yaw)) > 0.1, "Mouse drag rotates camera yaw")
	assert_true(ctrl.target_pitch > CameraController.DECK_DEFAULT_PITCH_DEG, "Upward mouse drag increases pitch")

	ctrl.apply_zoom(50.0)
	assert_almost_eq(ctrl.target_dist, CameraController.DECK_MIN_DIST, 0.01, "Deck zoom clamps at DECK_MIN_DIST (7.0 m)")
	ctrl.apply_zoom(-50.0)
	assert_almost_eq(ctrl.target_dist, CameraController.DECK_MAX_DIST, 0.01, "Deck zoom clamps at DECK_MAX_DIST (20.0 m)")
	ctrl.reset_to_default(true)
	assert_almost_eq(ctrl.current_dist, CameraController.DECK_DEFAULT_DIST, 0.01, "Reset restores default deck distance")

	ctrl.set_mode(true, true)
	ctrl.apply_zoom(-10.0)
	assert_almost_eq(ctrl.target_dist, 0.0, 0.001, "Helm camera distance remains 0.0 despite scroll zoom")


func test_camera_stays_client_local_and_updates_hud_controls() -> void:
	var state := GameState.new()
	state.ensure_player(1)
	var snapshot := state.to_dict()
	assert_true(not snapshot.has("camera"), "GameState snapshot must not contain camera state")
	assert_true(not snapshot.has("camera_yaw"), "GameState snapshot must not contain camera_yaw")
	assert_true(not snapshot.has("control_scheme"), "GameState snapshot must not contain control_scheme")

	var world := WorldView.new()
	world.apply_game_state(state, "", 1, true)
	var default_cam_pos := world.camera.position

	world.camera_controller.apply_axes(1.0, 0.0, 0.75)
	world.apply_game_state(state, "", 1, true)
	assert_true(world.camera.position.distance_to(default_cam_pos) > 1.0, "Rotating local camera updates WorldView camera position")
	assert_true(world.hud_label.text.contains("arrows_wasd"), "HUD displays active arrows_wasd control scheme")
	assert_true(world.hud_label.text.contains("Reset: R"), "HUD displays R reset hint")
	assert_true(world.hud_label.text.contains("Kävely: Nuolet"), "Deck HUD shows Arrows walk in arrows_wasd scheme")
	assert_true(world.hud_label.text.contains("Kamera: WASD"), "Deck HUD shows WASD camera in arrows_wasd scheme")

	# Switch to helm and cycle control profile to wasd_mouse
	state.stations[StationConfig.HELM_STATION_ID] = 1
	world.apply_game_state(state, "", 1, true)
	assert_true(world.hud_label.text.contains("Ajo: Nuolet"), "Helm HUD shows Arrows driving in arrows_wasd scheme")
	assert_true(world.hud_label.text.contains("Kamera: WASD"), "Helm HUD shows WASD camera in arrows_wasd scheme")

	world.camera_controller.cycle_control_scheme()
	world.apply_game_state(state, "", 1, true)
	assert_true(world.hud_label.text.contains("wasd_mouse"), "HUD updates when cycling to wasd_mouse scheme")
	assert_true(world.hud_label.text.contains("Ajo: WASD"), "Helm HUD shows WASD driving in wasd_mouse scheme")
	assert_true(world.hud_label.text.contains("Kamera: Hiiri"), "Helm HUD shows Mouse camera in wasd_mouse scheme")

	state.stations[StationConfig.HELM_STATION_ID] = 0
	world.apply_game_state(state, "", 1, true)
	assert_true(world.hud_label.text.contains("Kävely: WASD"), "Deck HUD shows WASD walk in wasd_mouse scheme")
	assert_true(world.hud_label.text.contains("Kamera: Hiiri"), "Deck HUD shows Mouse camera in wasd_mouse scheme")

	free_node(world)
