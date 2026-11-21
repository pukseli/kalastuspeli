extends "res://tests/test_case.gd"


func test_parse_cli_args_modes_and_defaults() -> void:
	var offline := NetworkManager.parse_cli_args(PackedStringArray([]))
	assert_eq(offline.get("mode"), "offline", "Empty args should default to offline mode")
	assert_eq(offline.get("address"), "127.0.0.1", "Default address should be 127.0.0.1")
	assert_eq(offline.get("port"), 7777, "Default port should be 7777")
	assert_eq(offline.get("sync_hz"), 20, "Default sync_hz should be 20")

	var host_cfg := NetworkManager.parse_cli_args(PackedStringArray(["--host", "--port", "7888", "--sync-hz", "30"]))
	assert_eq(host_cfg.get("mode"), "host", "--host sets mode to host")
	assert_eq(host_cfg.get("port"), 7888, "--port parses custom port")
	assert_eq(host_cfg.get("sync_hz"), 30, "--sync-hz parses custom tick rate")

	var join_default := NetworkManager.parse_cli_args(PackedStringArray(["--join", "--port", "7999"]))
	assert_eq(join_default.get("mode"), "client", "--join without IP sets mode to client")
	assert_eq(join_default.get("address"), "127.0.0.1", "--join without IP keeps 127.0.0.1")
	assert_eq(join_default.get("port"), 7999, "--port after flag-only --join parses port")

	var join_ip := NetworkManager.parse_cli_args(PackedStringArray(["--join", "192.168.1.50"]))
	assert_eq(join_ip.get("mode"), "client", "--join with IP sets mode to client")
	assert_eq(join_ip.get("address"), "192.168.1.50", "--join parses explicit IP address")


func test_transport_creates_host_and_client_peers() -> void:
	var transport := NetworkTransport.new()
	var host_peer := transport.create_host_peer(17777, 4)
	assert_true(host_peer != null, "NetworkTransport should create ENet host peer")
	var client_peer := transport.create_client_peer("127.0.0.1", 17777)
	assert_true(client_peer != null, "NetworkTransport should create ENet client peer")
	if client_peer != null:
		client_peer.close()
	if host_peer != null:
		host_peer.close()


func test_client_input_drives_host_boat_simulation() -> void:
	var net := NetworkManager.new()
	net.configure_from_args(PackedStringArray(["--host"]))
	var boat := BoatState.new()
	var host_input := PlayerInput.new()
	var sim := BoatSimulator.new()

	net.receive_client_input(2, {"throttle": 1.0, "steering": 0.5})
	for _i in range(30):
		net.step_network_tick(boat, host_input, sim)

	assert_true(boat.forward_speed > 2.0, "Client throttle input should accelerate host boat")
	assert_true(boat.heading > 0.2, "Client steering input should turn host boat")
	assert_true(boat.world_position.z < -0.5, "Host boat should advance forward")
	net.free()


func test_configurable_sync_rate_and_client_snapshot_apply() -> void:
	var host_net := NetworkManager.new()
	host_net.configure_from_args(PackedStringArray(["--host"]))
	var client_net := NetworkManager.new()
	client_net.configure_from_args(PackedStringArray(["--join", "127.0.0.1"]))

	var host_boat := BoatState.new()
	var client_boat := BoatState.new()
	var host_input := PlayerInput.new()
	host_input.throttle = 1.0
	var sim := BoatSimulator.new()

	# Default 20 Hz -> snapshot every 3 ticks at 60 Hz
	assert_eq(host_net.get_snapshot_interval_ticks(), 3, "20 Hz at 60 Hz physics equals 3 ticks")
	var snap1 := host_net.step_network_tick(host_boat, host_input, sim)
	var snap2 := host_net.step_network_tick(host_boat, host_input, sim)
	var snap3 := host_net.step_network_tick(host_boat, host_input, sim)
	assert_true(snap1.is_empty() and snap2.is_empty(), "No snapshot on ticks 1 and 2 at 20 Hz")
	assert_true(not snap3.is_empty(), "Snapshot emitted on tick 3 at 20 Hz")

	# Client does not simulate locally; it applies remote snapshot
	client_net.step_network_tick(client_boat, host_input, sim)
	assert_almost_eq(client_boat.world_position.z, 0.0, 0.0001, "Client must not advance boat locally")
	client_net.apply_remote_snapshot(client_boat, snap3)
	assert_almost_eq(client_boat.world_position.z, host_boat.world_position.z, 0.0001, "Client BoatState matches host snapshot")

	# Cycling sync rate: 20 -> 30 -> 60 -> 5 -> 10
	assert_eq(host_net.cycle_sync_rate(), 30, "First cycle moves 20 -> 30 Hz")
	assert_eq(host_net.get_snapshot_interval_ticks(), 2, "30 Hz equals every 2 ticks")
	assert_eq(host_net.cycle_sync_rate(), 60, "Second cycle moves 30 -> 60 Hz")
	assert_eq(host_net.get_snapshot_interval_ticks(), 1, "60 Hz equals every 1 tick")

	host_net.free()
	client_net.free()
