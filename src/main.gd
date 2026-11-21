extends Node

var game_state: GameState = GameState.new()
var player_input: PlayerInput = PlayerInput.new()
var boat_simulator: BoatSimulator = BoatSimulator.new()
var crew_simulator: CrewSimulator = CrewSimulator.new()
var network_manager: NetworkManager
var world_view: WorldView


func _ready() -> void:
	network_manager = NetworkManager.new()
	add_child(network_manager)

	var cli_args := OS.get_cmdline_user_args()
	if cli_args.is_empty():
		cli_args = OS.get_cmdline_args()
	network_manager.configure_from_args(cli_args)
	network_manager.game_snapshot_received.connect(_on_game_snapshot_received)
	network_manager.start_session()

	world_view = WorldView.new()
	add_child(world_view)
	world_view.apply_game_state(game_state, network_manager.get_status_text())


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_T or event.keycode == KEY_T:
			network_manager.cycle_sync_rate()
		elif event.physical_keycode == KEY_B or event.keycode == KEY_B:
			if network_manager.is_authority():
				network_manager.cycle_bot_count()


func _physics_process(_delta: float) -> void:
	_read_local_input()
	network_manager.step_game_tick(game_state, player_input, boat_simulator, crew_simulator)
	world_view.apply_game_state(game_state, network_manager.get_status_text())


func _on_game_snapshot_received(snapshot: Dictionary) -> void:
	network_manager.apply_game_snapshot(game_state, snapshot)


func _read_local_input() -> void:
	var move_x := 0.0
	var move_z := 0.0
	if Input.is_physical_key_pressed(KEY_W):
		move_z -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		move_z += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		move_x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		move_x += 1.0

	var throttle := 0.0
	if Input.is_physical_key_pressed(KEY_UP):
		throttle += 1.0
	if Input.is_physical_key_pressed(KEY_DOWN):
		throttle -= 1.0

	var steering := 0.0
	if Input.is_physical_key_pressed(KEY_LEFT):
		steering += 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT):
		steering -= 1.0

	player_input.move_x = move_x
	player_input.move_z = move_z
	player_input.throttle = throttle
	player_input.steering = steering
