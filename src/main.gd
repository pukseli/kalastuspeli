extends Node

var game_state: GameState = GameState.new()
var render_state: GameState = GameState.new()
var player_input: PlayerInput = PlayerInput.new()
var boat_simulator: BoatSimulator = BoatSimulator.new()
var crew_simulator: CrewSimulator = CrewSimulator.new()
var station_simulator: StationSimulator = StationSimulator.new()
var env_config: EnvConfig = EnvConfig.new()
var network_manager: NetworkManager
var world_view: WorldView


func _ready() -> void:
	network_manager = NetworkManager.new()
	add_child(network_manager)

	var cli_args := OS.get_cmdline_user_args()
	if cli_args.is_empty():
		cli_args = OS.get_cmdline_args()
	env_config = EnvConfig.load_for_runtime(cli_args)
	network_manager.configure_from_args(cli_args, env_config)
	network_manager.game_snapshot_received.connect(_on_game_snapshot_received)
	network_manager.start_session()

	world_view = WorldView.new()
	add_child(world_view)
	world_view.debug_hud_enabled = env_config.debug_hud
	world_view.apply_game_state(game_state, network_manager.get_status_text(), network_manager.get_local_peer_id())


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


func _physics_process(_delta: float) -> void:
	_read_local_input()
	network_manager.step_game_tick(game_state, player_input, boat_simulator, crew_simulator, station_simulator)
	player_input.interact = false
	var display_state := game_state
	if not network_manager.is_authority() and network_manager.interpolation_enabled:
		if network_manager.interpolator.step(render_state, BoatSimulator.FIXED_DELTA):
			display_state = render_state
	world_view.apply_game_state(display_state, network_manager.get_status_text(), network_manager.get_local_peer_id())


func _on_game_snapshot_received(snapshot: Dictionary) -> void:
	network_manager.apply_game_snapshot(game_state, snapshot)
	network_manager.interpolator.push_snapshot(snapshot)


func _read_local_input() -> void:
	var local_id := network_manager.get_local_peer_id()
	var in_helm := local_id != 0 and int(game_state.stations.get(StationConfig.HELM_STATION_ID, 0)) == local_id

	var move_x := 0.0
	var move_z := 0.0
	var throttle := 0.0
	var steering := 0.0

	if in_helm:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			throttle += 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			throttle -= 1.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			steering += 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			steering -= 1.0
	else:
		if Input.is_physical_key_pressed(KEY_W):
			move_z -= 1.0
		if Input.is_physical_key_pressed(KEY_S):
			move_z += 1.0
		if Input.is_physical_key_pressed(KEY_A):
			move_x -= 1.0
		if Input.is_physical_key_pressed(KEY_D):
			move_x += 1.0

	player_input.move_x = move_x
	player_input.move_z = move_z
	player_input.throttle = throttle
	player_input.steering = steering
