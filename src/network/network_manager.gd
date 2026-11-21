class_name NetworkManager
extends Node

signal snapshot_received(snapshot: Dictionary)

const DEFAULT_PORT: int = 7777
const DEFAULT_ADDRESS: String = "127.0.0.1"
const DEFAULT_SYNC_HZ: int = 20
const PHYSICS_HZ: int = 60
const SYNC_RATE_PRESETS: Array[int] = [20, 30, 60, 5, 10]

var mode: String = "offline"
var address: String = DEFAULT_ADDRESS
var port: int = DEFAULT_PORT
var sync_rate_hz: int = DEFAULT_SYNC_HZ
var transport: NetworkTransport = NetworkTransport.new()

var _tick_counter: int = 0
var _client_inputs: Dictionary = {}
var _combined_input: PlayerInput = PlayerInput.new()


static func parse_cli_args(args: PackedStringArray) -> Dictionary:
	var parsed_mode: String = "offline"
	var parsed_address: String = DEFAULT_ADDRESS
	var parsed_port: int = DEFAULT_PORT
	var parsed_sync_hz: int = DEFAULT_SYNC_HZ

	var i := 0
	while i < args.size():
		var arg := args[i]
		match arg:
			"--host":
				parsed_mode = "host"
			"--join":
				parsed_mode = "client"
				if i + 1 < args.size() and not args[i + 1].begins_with("--"):
					parsed_address = args[i + 1]
					i += 1
			"--port":
				if i + 1 < args.size() and args[i + 1].is_valid_int():
					parsed_port = clampi(int(args[i + 1]), 1, 65535)
					i += 1
			"--sync-hz":
				if i + 1 < args.size() and args[i + 1].is_valid_int():
					parsed_sync_hz = clampi(int(args[i + 1]), 1, PHYSICS_HZ)
					i += 1
		i += 1

	return {
		"mode": parsed_mode,
		"address": parsed_address,
		"port": parsed_port,
		"sync_hz": parsed_sync_hz,
	}


func configure_from_args(args: PackedStringArray) -> void:
	var cfg := parse_cli_args(args)
	mode = str(cfg.get("mode", "offline"))
	address = str(cfg.get("address", DEFAULT_ADDRESS))
	port = int(cfg.get("port", DEFAULT_PORT))
	set_sync_rate_hz(int(cfg.get("sync_hz", DEFAULT_SYNC_HZ)))


func start_session() -> Error:
	if mode == "offline":
		return OK
	if not is_inside_tree() or multiplayer == null:
		return ERR_UNCONFIGURED

	if mode == "host":
		var host_peer := transport.create_host_peer(port)
		if host_peer == null:
			return ERR_CANT_CREATE
		multiplayer.multiplayer_peer = host_peer
		if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
			multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		return OK

	if mode == "client":
		var client_peer := transport.create_client_peer(address, port)
		if client_peer == null:
			return ERR_CANT_CREATE
		multiplayer.multiplayer_peer = client_peer
		return OK

	return OK


func set_sync_rate_hz(hz: int) -> void:
	sync_rate_hz = clampi(hz, 1, PHYSICS_HZ)


func cycle_sync_rate() -> int:
	var idx := SYNC_RATE_PRESETS.find(sync_rate_hz)
	var next_idx := 0 if idx == -1 else (idx + 1) % SYNC_RATE_PRESETS.size()
	set_sync_rate_hz(SYNC_RATE_PRESETS[next_idx])
	return sync_rate_hz


func get_snapshot_interval_ticks() -> int:
	return maxi(1, roundi(float(PHYSICS_HZ) / float(sync_rate_hz)))


func is_authority() -> bool:
	return mode != "client"


func receive_client_input(peer_id: int, input_dict: Dictionary) -> void:
	_client_inputs[peer_id] = {
		"throttle": clampf(float(input_dict.get("throttle", 0.0)), -1.0, 1.0),
		"steering": clampf(float(input_dict.get("steering", 0.0)), -1.0, 1.0),
	}


func get_combined_input(host_input: PlayerInput) -> PlayerInput:
	var total_throttle := host_input.throttle
	var total_steering := host_input.steering
	for input_data in _client_inputs.values():
		total_throttle += float(input_data.get("throttle", 0.0))
		total_steering += float(input_data.get("steering", 0.0))
	_combined_input.throttle = clampf(total_throttle, -1.0, 1.0)
	_combined_input.steering = clampf(total_steering, -1.0, 1.0)
	return _combined_input


func step_network_tick(boat_state: BoatState, local_input: PlayerInput, simulator: BoatSimulator) -> Dictionary:
	if is_authority():
		var combined := get_combined_input(local_input)
		simulator.step(boat_state, combined, BoatSimulator.FIXED_DELTA)
		_tick_counter += 1
		if _tick_counter % get_snapshot_interval_ticks() == 0:
			var snapshot := boat_state.to_dict()
			if mode == "host" and _has_active_peer():
				rpc_sync_boat_state.rpc(snapshot)
			return snapshot
		return {}

	if _is_client_connected():
		rpc_submit_client_input.rpc_id(1, local_input.to_dict())
	return {}


func apply_remote_snapshot(boat_state: BoatState, snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	boat_state.from_dict(snapshot)


func get_status_text() -> String:
	return "Net: %s | Sync: %d Hz" % [mode.to_upper(), sync_rate_hz]


@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_submit_client_input(input_dict: Dictionary) -> void:
	if not is_authority():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return
	receive_client_input(sender_id, input_dict)


@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_sync_boat_state(snapshot: Dictionary) -> void:
	if is_authority():
		return
	snapshot_received.emit(snapshot)


func _on_peer_disconnected(peer_id: int) -> void:
	_client_inputs.erase(peer_id)


func _has_active_peer() -> bool:
	return is_inside_tree() and multiplayer != null and multiplayer.has_multiplayer_peer()


func _is_client_connected() -> bool:
	return _has_active_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
