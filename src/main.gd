extends Node

var boat_state: BoatState = BoatState.new()
var player_input: PlayerInput = PlayerInput.new()
var simulator: BoatSimulator = BoatSimulator.new()
var network_manager: NetworkManager
var world_view: WorldView


func _ready() -> void:
	network_manager = NetworkManager.new()
	add_child(network_manager)

	var cli_args := OS.get_cmdline_user_args()
	if cli_args.is_empty():
		cli_args = OS.get_cmdline_args()
	network_manager.configure_from_args(cli_args)
	network_manager.snapshot_received.connect(_on_snapshot_received)
	network_manager.start_session()

	world_view = WorldView.new()
	add_child(world_view)
	world_view.apply_state(boat_state, network_manager.get_status_text())


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_T or event.keycode == KEY_T:
			network_manager.cycle_sync_rate()


func _physics_process(_delta: float) -> void:
	_read_local_input()
	network_manager.step_network_tick(boat_state, player_input, simulator)
	world_view.apply_state(boat_state, network_manager.get_status_text())


func _on_snapshot_received(snapshot: Dictionary) -> void:
	network_manager.apply_remote_snapshot(boat_state, snapshot)


func _read_local_input() -> void:
	var throttle := 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		throttle += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		throttle -= 1.0

	var steering := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		steering += 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		steering -= 1.0

	player_input.throttle = throttle
	player_input.steering = steering
