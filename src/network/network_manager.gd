class_name NetworkManager
extends Node

signal snapshot_received(snapshot: Dictionary)
signal game_snapshot_received(snapshot: Dictionary)

const DEFAULT_PORT: int = 7777
const DEFAULT_ADDRESS: String = "127.0.0.1"
const DEFAULT_SYNC_HZ: int = 20
const PHYSICS_HZ: int = 60
const SYNC_RATE_PRESETS: Array[int] = [20, 30, 60, 5, 10]

var mode: String = "offline"
var address: String = DEFAULT_ADDRESS
var port: int = DEFAULT_PORT
var sync_rate_hz: int = DEFAULT_SYNC_HZ
var bot_count: int = 0
var transport: NetworkTransport = NetworkTransport.new()

var _tick_counter: int = 0
var _client_inputs: Dictionary = {}
var _connected_peers: Dictionary = {}
var _disconnected_peers: Array[int] = []
var _combined_input: PlayerInput = PlayerInput.new()
var _net_state: String = "offline"


static func parse_cli_args(args: PackedStringArray) -> Dictionary:
	var parsed_mode: String = "offline"
	var parsed_address: String = DEFAULT_ADDRESS
	var parsed_port: int = DEFAULT_PORT
	var parsed_sync_hz: int = DEFAULT_SYNC_HZ
	var parsed_bots: int = 0

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
			"--bots":
				if i + 1 < args.size() and args[i + 1].is_valid_int():
					parsed_bots = clampi(int(args[i + 1]), 0, CrewSimulator.MAX_BOTS)
					i += 1
		i += 1

	return {
		"mode": parsed_mode,
		"address": parsed_address,
		"port": parsed_port,
		"sync_hz": parsed_sync_hz,
		"bots": parsed_bots,
	}


func configure_from_args(args: PackedStringArray) -> void:
	var cfg := parse_cli_args(args)
	mode = str(cfg.get("mode", "offline"))
	address = str(cfg.get("address", DEFAULT_ADDRESS))
	port = int(cfg.get("port", DEFAULT_PORT))
	set_sync_rate_hz(int(cfg.get("sync_hz", DEFAULT_SYNC_HZ)))
	set_bot_count(int(cfg.get("bots", 0)))
	_net_state = "offline"


func start_session() -> Error:
	if mode == "offline":
		_net_state = "offline"
		return OK
	if not is_inside_tree() or multiplayer == null:
		return ERR_UNCONFIGURED

	if mode == "host":
		var host_peer := transport.create_host_peer(port)
		if host_peer == null:
			_net_state = "bind_failed"
			return ERR_CANT_CREATE
		multiplayer.multiplayer_peer = host_peer
		if not multiplayer.peer_connected.is_connected(_on_peer_connected):
			multiplayer.peer_connected.connect(_on_peer_connected)
		if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
			multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_net_state = "hosting"
		print("[NET] Hosting on UDP *:%d (sync: %d Hz)" % [port, sync_rate_hz])
		return OK

	if mode == "client":
		var client_peer := transport.create_client_peer(address, port)
		if client_peer == null:
			_net_state = "failed"
			return ERR_CANT_CREATE
		multiplayer.multiplayer_peer = client_peer
		if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
			multiplayer.connected_to_server.connect(_on_connected_to_server)
		if not multiplayer.connection_failed.is_connected(_on_connection_failed):
			multiplayer.connection_failed.connect(_on_connection_failed)
		if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
			multiplayer.server_disconnected.connect(_on_server_disconnected)
		_net_state = "connecting"
		print("[NET] Connecting to %s:%d ..." % [address, port])
		return OK

	return OK


func set_sync_rate_hz(hz: int) -> void:
	sync_rate_hz = clampi(hz, 1, PHYSICS_HZ)


func cycle_sync_rate() -> int:
	var idx := SYNC_RATE_PRESETS.find(sync_rate_hz)
	var next_idx := 0 if idx == -1 else (idx + 1) % SYNC_RATE_PRESETS.size()
	set_sync_rate_hz(SYNC_RATE_PRESETS[next_idx])
	return sync_rate_hz


func set_bot_count(count: int) -> void:
	bot_count = clampi(count, 0, CrewSimulator.MAX_BOTS)


func cycle_bot_count() -> int:
	bot_count = (bot_count + 1) % (CrewSimulator.MAX_BOTS + 1)
	return bot_count


func get_snapshot_interval_ticks() -> int:
	return maxi(1, roundi(float(PHYSICS_HZ) / float(sync_rate_hz)))


func is_authority() -> bool:
	return mode != "client"


func get_local_peer_id() -> int:
	if mode == "client":
		if is_inside_tree() and multiplayer != null and multiplayer.has_multiplayer_peer():
			return multiplayer.get_unique_id()
		return 0
	return 1


func receive_client_input(peer_id: int, input_dict: Dictionary) -> void:
	var prev_interact := false
	if _client_inputs.has(peer_id):
		prev_interact = bool(_client_inputs[peer_id].get("interact", false))
	_client_inputs[peer_id] = {
		"throttle": clampf(float(input_dict.get("throttle", 0.0)), -1.0, 1.0),
		"steering": clampf(float(input_dict.get("steering", 0.0)), -1.0, 1.0),
		"move_x": clampf(float(input_dict.get("move_x", 0.0)), -1.0, 1.0),
		"move_z": clampf(float(input_dict.get("move_z", 0.0)), -1.0, 1.0),
		"interact": prev_interact or bool(input_dict.get("interact", false)),
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


func step_game_tick(game_state: GameState, local_input: PlayerInput, boat_sim: BoatSimulator, crew_sim: CrewSimulator, station_sim: StationSimulator = null) -> Dictionary:
	if is_authority():
		for disconnected_id in _disconnected_peers:
			game_state.remove_player(disconnected_id)
		_disconnected_peers.clear()

		game_state.ensure_player(1, false)
		var crew_inputs: Dictionary = {1: local_input}
		for peer_id in _client_inputs:
			var pid := int(peer_id)
			game_state.ensure_player(pid, false)
			crew_inputs[pid] = _client_inputs[peer_id]

		crew_sim.sync_bots(game_state, bot_count)
		if station_sim != null:
			station_sim.step(game_state, crew_inputs, CrewSimulator.FIXED_DELTA)
			station_sim.apply_helm_input_to_boat(game_state, crew_inputs, BoatSimulator.FIXED_DELTA, boat_sim.config.max_steering_angle)
			boat_sim.step(game_state.boat, station_sim.get_active_boat_input(game_state, boat_sim.config.max_steering_angle), BoatSimulator.FIXED_DELTA)
		else:
			var combined := get_combined_input(local_input)
			boat_sim.step(game_state.boat, combined, BoatSimulator.FIXED_DELTA)
		crew_sim.step(game_state, crew_inputs, CrewSimulator.FIXED_DELTA)

		for pid in crew_inputs:
			if crew_inputs[pid] is Dictionary:
				crew_inputs[pid]["interact"] = false

		game_state.tick += 1
		_tick_counter += 1
		if _tick_counter % get_snapshot_interval_ticks() == 0:
			var snapshot := game_state.to_dict()
			if mode == "host" and _has_active_peer():
				rpc_sync_game_state.rpc(snapshot)
			return snapshot
		return {}

	if _is_client_connected():
		if local_input.interact:
			rpc_submit_client_interact.rpc_id(1)
		var payload := local_input.to_dict()
		payload["interact"] = false
		rpc_submit_client_input.rpc_id(1, payload)
	return {}


func apply_remote_snapshot(boat_state: BoatState, snapshot: Dictionary) -> void:
	if is_authority():
		return
	if not snapshot.is_empty():
		boat_state.from_dict(snapshot)


func apply_game_snapshot(game_state: GameState, snapshot: Dictionary) -> void:
	if is_authority():
		return
	if not snapshot.is_empty():
		game_state.from_dict(snapshot)


func get_status_text() -> String:
	if mode == "host":
		var host_label := "HOST BIND FAILED (:%d)" % port if _net_state == "bind_failed" else "HOST (:%d)" % port
		return "Net: %s | Peers: %d | Sync: %d Hz | Bots: %d" % [host_label, _connected_peers.size(), sync_rate_hz, bot_count]
	if mode == "client":
		var connected := _is_client_connected()
		var peer_count := 1 if connected else 0
		var state_tag := "CONNECTED" if connected else _net_state.to_upper()
		if state_tag == "OFFLINE":
			state_tag = "CONNECTING"
		return "Net: CLIENT (%s %s:%d) | Peers: %d | Sync: %d Hz | Bots: %d" % [state_tag, address, port, peer_count, sync_rate_hz, bot_count]
	return "Net: OFFLINE | Peers: 0 | Sync: %d Hz | Bots: %d" % [sync_rate_hz, bot_count]


@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_submit_client_input(input_dict: Dictionary) -> void:
	if not is_authority():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return
	receive_client_input(sender_id, input_dict)


@rpc("any_peer", "call_remote", "reliable")
func rpc_submit_client_interact() -> void:
	if not is_authority():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return
	if not _client_inputs.has(sender_id):
		_client_inputs[sender_id] = {
			"throttle": 0.0,
			"steering": 0.0,
			"move_x": 0.0,
			"move_z": 0.0,
			"interact": true,
		}
	else:
		_client_inputs[sender_id]["interact"] = true


@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_sync_boat_state(snapshot: Dictionary) -> void:
	if is_authority():
		return
	snapshot_received.emit(snapshot)


@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_sync_game_state(snapshot: Dictionary) -> void:
	if is_authority():
		return
	game_snapshot_received.emit(snapshot)


func _on_peer_connected(peer_id: int) -> void:
	_connected_peers[peer_id] = true
	if not _client_inputs.has(peer_id):
		_client_inputs[peer_id] = {
			"throttle": 0.0,
			"steering": 0.0,
			"move_x": 0.0,
			"move_z": 0.0,
			"interact": false,
		}
	print("[NET] Peer connected: %d" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	_connected_peers.erase(peer_id)
	_client_inputs.erase(peer_id)
	if not _disconnected_peers.has(peer_id):
		_disconnected_peers.append(peer_id)
	print("[NET] Peer disconnected: %d" % peer_id)


func _on_connected_to_server() -> void:
	_net_state = "connected"
	print("[NET] Connected to server %s:%d (local peer_id=%d)" % [address, port, get_local_peer_id()])


func _on_connection_failed() -> void:
	_net_state = "failed"
	print("[NET] Connection failed to %s:%d (check Host IP, UDP port %d, and firewall)" % [address, port, port])


func _on_server_disconnected() -> void:
	_net_state = "disconnected"
	print("[NET] Disconnected from server %s:%d" % [address, port])


func _is_client_connected() -> bool:
	if mode != "client":
		return false
	if not is_inside_tree() or multiplayer == null:
		return false
	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return false
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _has_active_peer() -> bool:
	if not is_inside_tree() or multiplayer == null or not multiplayer.has_multiplayer_peer():
		return false
	return _is_client_connected() or not _connected_peers.is_empty()
