extends Node

var game_state: GameState = GameState.new()
var render_state: GameState = GameState.new()
var player_input: PlayerInput = PlayerInput.new()
var boat_simulator: BoatSimulator = BoatSimulator.new()
var crew_simulator: CrewSimulator = CrewSimulator.new()
var station_simulator: StationSimulator = StationSimulator.new()
var item_config: ItemConfig = ItemConfig.new()
var item_simulator: ItemSimulator = ItemSimulator.new()
var rod_simulator: RodSimulator = RodSimulator.new()
var fish_simulator: FishSimulator = FishSimulator.new()
var env_config: EnvConfig = EnvConfig.new()
var network_manager: NetworkManager
var world_view: WorldView
var render_interpolator: RenderInterpolator = RenderInterpolator.new()
var _display_state: GameState = null
var _view_tick_dirty: bool = false
var _rmb_dragging: bool = false
var _quitting: bool = false


func _ready() -> void:
	network_manager = NetworkManager.new()
	add_child(network_manager)

	var cli_args := OS.get_cmdline_user_args()
	if cli_args.is_empty():
		cli_args = OS.get_cmdline_args()
	env_config = EnvConfig.load_for_runtime(cli_args)
	network_manager.configure_from_args(cli_args, env_config)
	item_config = ItemConfig.create_default_config(network_manager.rod_count, ItemConfig.DEFAULT_NET_COUNT)
	item_simulator = ItemSimulator.new(item_config)
	game_state.configure_items(item_config)
	render_state.configure_items(item_config)
	network_manager.interpolator.item_config = item_config
	network_manager.game_snapshot_received.connect(_on_game_snapshot_received)
	network_manager.start_session()

	world_view = WorldView.new()
	add_child(world_view)
	world_view.configure_holders(item_config)
	world_view.debug_hud_enabled = env_config.debug_hud
	world_view.camera_controller.set_control_scheme(CameraController.parse_control_scheme_from_args(cli_args))
	world_view.apply_game_state(game_state, network_manager.get_status_text(), network_manager.get_local_peer_id(), true)
	_display_state = game_state
	render_interpolator.capture(game_state)


static func is_quit_shortcut(event: InputEvent, alt_held: bool = false) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed:
		return false
	if key_event.ctrl_pressed or key_event.meta_pressed:
		return false
	var is_f4 := (
		key_event.keycode == KEY_F4
		or key_event.physical_keycode == KEY_F4
		or key_event.key_label == KEY_F4
	)
	if not is_f4:
		return false
	return key_event.alt_pressed or alt_held


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_quit()


func _input(event: InputEvent) -> void:
	var alt_held := Input.is_key_pressed(KEY_ALT) or Input.is_physical_key_pressed(KEY_ALT)
	if is_quit_shortcut(event, alt_held):
		if is_inside_tree():
			var viewport := get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
		_request_quit()


func _request_quit() -> void:
	if _quitting:
		return
	_quitting = true
	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			tree.quit()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_T or event.keycode == KEY_T:
			if env_config.debug_hotkeys:
				network_manager.cycle_sync_rate()
		elif event.physical_keycode == KEY_B or event.keycode == KEY_B:
			if env_config.debug_hotkeys and env_config.allow_bots and network_manager.is_authority():
				network_manager.cycle_bot_count()
		elif event.physical_keycode == KEY_L or event.keycode == KEY_L:
			if env_config.debug_hotkeys and not network_manager.is_authority():
				network_manager.cycle_latency_preset()
		elif event.physical_keycode == KEY_I or event.keycode == KEY_I:
			if env_config.debug_hotkeys and not network_manager.is_authority():
				network_manager.toggle_interpolation()
		elif event.physical_keycode == KEY_E or event.keycode == KEY_E:
			player_input.interact = true
		elif event.physical_keycode == KEY_R or event.keycode == KEY_R:
			world_view.camera_controller.reset_to_default(false)
		elif event.physical_keycode == KEY_K or event.keycode == KEY_K:
			world_view.camera_controller.cycle_control_scheme()
		elif event.physical_keycode == KEY_F or event.keycode == KEY_F:
			if env_config.debug_hotkeys and network_manager.is_authority():
				fish_simulator.force_bite(game_state, rod_simulator)


func _unhandled_input(event: InputEvent) -> void:
	if world_view == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_rmb_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_MIDDLE and mb.pressed:
			world_view.camera_controller.reset_to_default(false)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			var factor := mb.factor if mb.factor > 0.0 else 1.0
			world_view.camera_controller.apply_zoom(1.0 * factor)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			var factor := mb.factor if mb.factor > 0.0 else 1.0
			world_view.camera_controller.apply_zoom(-1.0 * factor)
	elif event is InputEventMouseMotion:
		if _rmb_dragging or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			var mm := event as InputEventMouseMotion
			world_view.camera_controller.apply_mouse_drag(mm.relative)


func _physics_process(_delta: float) -> void:
	_read_local_input()
	network_manager.step_game_tick(game_state, player_input, boat_simulator, crew_simulator, station_simulator, item_simulator, rod_simulator, fish_simulator)
	player_input.interact = false
	var display_state := game_state
	if not network_manager.is_authority() and network_manager.interpolation_enabled:
		if network_manager.interpolator.step(render_state, BoatSimulator.FIXED_DELTA):
			display_state = render_state
	_display_state = display_state
	render_interpolator.capture(display_state)
	_view_tick_dirty = true


func _process(delta: float) -> void:
	if world_view == null:
		return
	var active_state := _display_state if _display_state != null else game_state
	if _view_tick_dirty:
		_view_tick_dirty = false
		world_view.apply_game_state(active_state, network_manager.get_status_text(), network_manager.get_local_peer_id(), false, false)
	var fraction := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	var blend := render_interpolator.blend(fraction)
	world_view.update_frame(blend, delta, active_state)


func _on_game_snapshot_received(snapshot: Dictionary) -> void:
	if network_manager.interpolator.push_snapshot(snapshot):
		var latest := network_manager.interpolator.get_latest_state()
		if latest != null:
			game_state = latest
	else:
		network_manager.apply_game_snapshot(game_state, snapshot)


func _read_local_input() -> void:
	var local_id := network_manager.get_local_peer_id()
	var in_helm := local_id != 0 and int(game_state.stations.get(StationConfig.HELM_STATION_ID, 0)) == local_id

	var wasd_x := 0.0
	var wasd_y := 0.0
	var arrow_x := 0.0
	var arrow_y := 0.0

	if Input.is_physical_key_pressed(KEY_D):
		wasd_x += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		wasd_x -= 1.0
	if Input.is_physical_key_pressed(KEY_W):
		wasd_y += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		wasd_y -= 1.0

	if Input.is_physical_key_pressed(KEY_RIGHT):
		arrow_x += 1.0
	if Input.is_physical_key_pressed(KEY_LEFT):
		arrow_x -= 1.0
	if Input.is_physical_key_pressed(KEY_UP):
		arrow_y += 1.0
	if Input.is_physical_key_pressed(KEY_DOWN):
		arrow_y -= 1.0

	var mapped := CameraController.map_control_inputs(
		world_view.camera_controller.control_scheme,
		in_helm,
		wasd_x,
		wasd_y,
		arrow_x,
		arrow_y,
		world_view.camera_controller.current_yaw
	)

	player_input.move_x = float(mapped["move_x"])
	player_input.move_z = float(mapped["move_z"])
	player_input.throttle = float(mapped["throttle"])
	player_input.steering = float(mapped["steering"])

	var let_out := (
		Input.is_physical_key_pressed(KEY_Q)
		or Input.is_key_pressed(KEY_Q)
		or Input.is_physical_key_pressed(KEY_SHIFT)
		or Input.is_key_pressed(KEY_SHIFT)
	)
	var reel_in := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SPACE)
	player_input.line_input = (1.0 if let_out else 0.0) - (1.0 if reel_in else 0.0)
	var drag_loosen := Input.is_physical_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_Z)
	var drag_tighten := Input.is_physical_key_pressed(KEY_X) or Input.is_key_pressed(KEY_X)
	player_input.drag_input = (1.0 if drag_tighten else 0.0) - (1.0 if drag_loosen else 0.0)
	player_input.interact_held = Input.is_physical_key_pressed(KEY_E) or Input.is_key_pressed(KEY_E)

	world_view.camera_controller.apply_axes(
		float(mapped["cam_yaw_axis"]),
		float(mapped["cam_pitch_axis"]),
		BoatSimulator.FIXED_DELTA
	)
