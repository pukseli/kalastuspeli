extends "res://tests/test_case.gd"


func test_loads_test_and_prod_profiles() -> void:
	var default_cfg := EnvConfig.load_from_sources(PackedStringArray([]))
	assert_true(default_cfg.is_test(), "Default profile should be test")
	assert_eq(default_cfg.env_name, "test", "Default env_name should be test")
	assert_true(default_cfg.debug_hud, "Test profile enables debug_hud")
	assert_true(default_cfg.debug_hotkeys, "Test profile enables debug_hotkeys")
	assert_true(default_cfg.verbose_net_logs, "Test profile enables verbose_net_logs")
	assert_true(default_cfg.allow_bots, "Test profile enables allow_bots")
	assert_eq(default_cfg.transport, "enet", "Test profile uses enet transport")
	assert_eq(default_cfg.default_address, "127.0.0.1", "Test profile defaults to 127.0.0.1")
	assert_eq(default_cfg.default_port, 7777, "Test profile defaults to port 7777")
	assert_eq(default_cfg.sync_hz, 20, "Test profile defaults to 20 Hz")
	assert_eq(default_cfg.max_clients, 4, "Test profile defaults to 4 max_clients")

	var prod_cli_cfg := EnvConfig.load_from_sources(PackedStringArray(["--env", "prod"]))
	assert_true(prod_cli_cfg.is_prod(), "--env prod selects prod profile")
	assert_eq(prod_cli_cfg.env_name, "prod", "Prod env_name should be prod")
	assert_true(not prod_cli_cfg.debug_hud, "Prod profile disables debug_hud")
	assert_true(not prod_cli_cfg.debug_hotkeys, "Prod profile disables debug_hotkeys")
	assert_true(not prod_cli_cfg.verbose_net_logs, "Prod profile disables verbose_net_logs")
	assert_true(not prod_cli_cfg.allow_bots, "Prod profile disables allow_bots")
	assert_eq(prod_cli_cfg.transport, "enet", "Prod profile uses enet transport")
	assert_eq(prod_cli_cfg.default_address, "", "Prod profile clears default_address")
	assert_eq(prod_cli_cfg.default_port, 7777, "Prod profile defaults to port 7777")
	assert_eq(prod_cli_cfg.sync_hz, 20, "Prod profile defaults to 20 Hz")
	assert_eq(prod_cli_cfg.max_clients, 4, "Prod profile defaults to 4 max_clients")

	var prod_feature_cfg := EnvConfig.load_from_sources(PackedStringArray([]), {}, true)
	assert_true(prod_feature_cfg.is_prod(), "prod feature tag selects prod profile")
	assert_true(not prod_feature_cfg.debug_hud, "prod feature profile disables debug_hud")
	assert_true(not prod_feature_cfg.allow_bots, "prod feature profile disables allow_bots")
	assert_eq(prod_feature_cfg.default_address, "", "prod feature profile clears default_address")


func test_env_vars_override_profile_and_cli_overrides_env() -> void:
	var env_vars := {
		"KALASTUSPELI_PORT": "8888",
		"KALASTUSPELI_SYNC_HZ": "30",
		"KALASTUSPELI_ADDRESS": "10.20.30.40",
		"KALASTUSPELI_DEBUG_HUD": "true",
	}
	var env_cfg := EnvConfig.load_from_sources(PackedStringArray(["--env", "prod"]), env_vars)
	assert_true(env_cfg.is_prod(), "Profile remains prod when overridden by env vars")
	assert_eq(env_cfg.default_port, 8888, "KALASTUSPELI_PORT overrides profile port")
	assert_eq(env_cfg.sync_hz, 30, "KALASTUSPELI_SYNC_HZ overrides profile sync_hz")
	assert_eq(env_cfg.default_address, "10.20.30.40", "KALASTUSPELI_ADDRESS overrides profile address")
	assert_true(env_cfg.debug_hud, "KALASTUSPELI_DEBUG_HUD overrides profile debug_hud")

	var net_cli := NetworkManager.new()
	net_cli.configure_from_args(PackedStringArray(["--join", "192.168.50.10", "--port", "9000"]), env_cfg)
	assert_eq(net_cli.mode, "client", "--join sets client mode")
	assert_eq(net_cli.address, "192.168.50.10", "Explicit --join IP overrides EnvConfig default_address")
	assert_eq(net_cli.port, 9000, "Explicit --port overrides EnvConfig default_port")
	assert_eq(net_cli.sync_rate_hz, 30, "Sync rate inherits from EnvConfig when --sync-hz omitted")
	net_cli.free()

	var net_bare_join := NetworkManager.new()
	net_bare_join.configure_from_args(PackedStringArray(["--join"]), env_cfg)
	assert_eq(net_bare_join.mode, "client", "Bare --join sets client mode")
	assert_eq(net_bare_join.address, "10.20.30.40", "Bare --join preserves EnvConfig default_address")
	assert_eq(net_bare_join.port, 8888, "Bare --join preserves EnvConfig default_port")
	net_bare_join.free()


func test_prod_disables_bots_and_debug_hud() -> void:
	var prod_cfg := EnvConfig.load_from_sources(PackedStringArray(["--env", "prod"]))
	var net := NetworkManager.new()
	net.configure_from_args(PackedStringArray(["--host", "--bots", "3"]), prod_cfg)
	assert_eq(net.bot_count, 0, "Prod profile rejects --bots 3")
	assert_eq(net.cycle_bot_count(), 0, "Prod profile keeps cycle_bot_count at 0")
	assert_eq(net.bot_count, 0, "Prod profile keeps bot_count at 0")
	assert_eq(net.get_status_text(), "HOST | Pelaajat: 1", "Prod host status text is clean Finnish label")

	var world := WorldView.new()
	world.debug_hud_enabled = prod_cfg.debug_hud
	var state := GameState.new()
	world.apply_game_state(state, net.get_status_text(), 1, true)
	assert_true(not world.hud_label.text.contains("FPS:"), "Prod HUD hides FPS counter")
	assert_true(not world.hud_label.text.contains("B: Botit"), "Prod HUD hides debug hotkey hints")
	assert_true(world.hud_label.text.contains("HOST | Pelaajat: 1"), "Prod HUD shows clean host status text")

	net.free()
	free_node(world)


func test_transport_backend_dispatch() -> void:
	assert_true(NetworkTransport.is_supported_backend("enet"), "enet backend is supported")
	assert_true(not NetworkTransport.is_supported_backend("steam"), "steam backend is not yet supported")

	var transport := NetworkTransport.new()
	var host_peer := transport.create_host(17778, 4)
	assert_true(host_peer != null, "NetworkTransport.create_host returns valid peer for enet")
	var client_peer := transport.create_client("127.0.0.1", 17778)
	assert_true(client_peer != null, "NetworkTransport.create_client returns valid peer for enet")

	if client_peer != null:
		client_peer.close()
	if host_peer != null:
		host_peer.close()
