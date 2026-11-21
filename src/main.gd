extends Node

var boat_state: BoatState = BoatState.new()
var player_input: PlayerInput = PlayerInput.new()
var simulator: BoatSimulator = BoatSimulator.new()
var world_view: WorldView


func _ready() -> void:
	world_view = WorldView.new()
	add_child(world_view)
	world_view.camera.rotation_degrees = Vector3(-45.0, 0.0, 0.0)
	world_view.apply_state(boat_state)


func _physics_process(_delta: float) -> void:
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

	simulator.step(boat_state, player_input, BoatSimulator.FIXED_DELTA)
	world_view.apply_state(boat_state)
