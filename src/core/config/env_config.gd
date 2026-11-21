class_name EnvConfig
extends RefCounted
## Environment profile and runtime configuration loader (test vs. prod).
## Pure RefCounted core class with zero Node, rendering, or networking dependencies.

const ENV_TEST: String = "test"
const ENV_PROD: String = "prod"
const ENV_CONFIG_DIR: String = "res://config/env"
const USER_OVERRIDE_PATH: String = "user://env.override.cfg"

const _RUNTIME_ENV_KEYS: Array[String] = [
	"KALASTUSPELI_ENV",
	"KALASTUSPELI_CONFIG",
	"KALASTUSPELI_TRANSPORT",
	"KALASTUSPELI_ADDRESS",
	"KALASTUSPELI_PORT",
	"KALASTUSPELI_SYNC_HZ",
	"KALASTUSPELI_MAX_CLIENTS",
	"KALASTUSPELI_DEBUG_HUD",
	"KALASTUSPELI_DEBUG_HOTKEYS",
	"KALASTUSPELI_VERBOSE_NET_LOGS",
	"KALASTUSPELI_ALLOW_BOTS",
]

var env_name: String = ENV_TEST
var debug_hud: bool = true
var debug_hotkeys: bool = true
var verbose_net_logs: bool = true
var allow_bots: bool = true
var transport: String = "enet"
var default_address: String = "127.0.0.1"
var default_port: int = 7777
var sync_hz: int = 20
var max_clients: int = 4


func is_prod() -> bool:
	return env_name == ENV_PROD


func is_test() -> bool:
	return env_name == ENV_TEST


func apply_profile_defaults(profile_name: String) -> void:
	var normalized := profile_name.to_lower().strip_edges()
	if normalized == ENV_PROD:
		env_name = ENV_PROD
		debug_hud = false
		debug_hotkeys = false
		verbose_net_logs = false
		allow_bots = false
		transport = "enet"
		default_address = ""
		default_port = 7777
		sync_hz = 20
		max_clients = 4
	else:
		env_name = ENV_TEST if normalized.is_empty() else normalized
		debug_hud = true
		debug_hotkeys = true
		verbose_net_logs = true
		allow_bots = true
		transport = "enet"
		default_address = "127.0.0.1"
		default_port = 7777
		sync_hz = 20
		max_clients = 4


func load_config_file(path: String) -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var cf := ConfigFile.new()
	var err := cf.load(path)
	if err != OK:
		return false

	if cf.has_section_key("environment", "name"):
		env_name = str(cf.get_value("environment", "name")).to_lower().strip_edges()
	if cf.has_section_key("environment", "debug_hud"):
		debug_hud = _parse_bool(cf.get_value("environment", "debug_hud"), debug_hud)
	if cf.has_section_key("environment", "debug_hotkeys"):
		debug_hotkeys = _parse_bool(cf.get_value("environment", "debug_hotkeys"), debug_hotkeys)
	if cf.has_section_key("environment", "verbose_net_logs"):
		verbose_net_logs = _parse_bool(cf.get_value("environment", "verbose_net_logs"), verbose_net_logs)
	if cf.has_section_key("environment", "allow_bots"):
		allow_bots = _parse_bool(cf.get_value("environment", "allow_bots"), allow_bots)

	if cf.has_section_key("network", "transport"):
		transport = str(cf.get_value("network", "transport")).to_lower().strip_edges()
	if cf.has_section_key("network", "default_address"):
		default_address = str(cf.get_value("network", "default_address")).strip_edges()
	if cf.has_section_key("network", "default_port"):
		default_port = clampi(int(cf.get_value("network", "default_port")), 1, 65535)
	if cf.has_section_key("network", "sync_hz"):
		sync_hz = clampi(int(cf.get_value("network", "sync_hz")), 1, 60)
	if cf.has_section_key("network", "max_clients"):
		max_clients = clampi(int(cf.get_value("network", "max_clients")), 1, 32)

	return true


static func _extract_cli_value(cli_args: PackedStringArray, flag: String) -> String:
	var eq_prefix := flag + "="
	var i := 0
	while i < cli_args.size():
		var arg := cli_args[i]
		if arg == flag:
			if i + 1 < cli_args.size() and not cli_args[i + 1].begins_with("--"):
				return cli_args[i + 1].strip_edges()
			return ""
		if arg.begins_with(eq_prefix):
			return arg.substr(eq_prefix.length()).strip_edges()
		i += 1
	return ""


static func _parse_bool(raw: Variant, fallback: bool) -> bool:
	if raw is bool:
		return raw
	if raw is int or raw is float:
		return int(raw) != 0
	var s := str(raw).to_lower().strip_edges()
	if s in ["1", "true", "yes", "on"]:
		return true
	if s in ["0", "false", "no", "off"]:
		return false
	return fallback


static func load_for_runtime(cli_args: PackedStringArray) -> EnvConfig:
	var env_vars := {}
	for key in _RUNTIME_ENV_KEYS:
		if OS.has_environment(key):
			env_vars[key] = OS.get_environment(key)
	return load_from_sources(cli_args, env_vars, OS.has_feature("prod"), true)


static func load_from_sources(cli_args: PackedStringArray, env_vars: Dictionary = {}, has_prod_feature: bool = false, check_user_override: bool = false) -> EnvConfig:
	var selected_env := _extract_cli_value(cli_args, "--env")
	if selected_env.is_empty():
		selected_env = str(env_vars.get("KALASTUSPELI_ENV", "")).strip_edges()
	if selected_env.is_empty():
		selected_env = ENV_PROD if has_prod_feature else ENV_TEST
	selected_env = selected_env.to_lower()

	var cfg := EnvConfig.new()
	cfg.apply_profile_defaults(selected_env)
	cfg.load_config_file("%s/%s.cfg" % [ENV_CONFIG_DIR, selected_env])

	var override_path := _extract_cli_value(cli_args, "--config")
	if override_path.is_empty():
		override_path = str(env_vars.get("KALASTUSPELI_CONFIG", "")).strip_edges()
	if override_path.is_empty() and check_user_override:
		override_path = USER_OVERRIDE_PATH
	if not override_path.is_empty():
		cfg.load_config_file(override_path)

	if env_vars.has("KALASTUSPELI_TRANSPORT"):
		var raw_transport := str(env_vars["KALASTUSPELI_TRANSPORT"]).to_lower().strip_edges()
		if not raw_transport.is_empty():
			cfg.transport = raw_transport

	if env_vars.has("KALASTUSPELI_ADDRESS"):
		cfg.default_address = str(env_vars["KALASTUSPELI_ADDRESS"]).strip_edges()

	if env_vars.has("KALASTUSPELI_PORT"):
		var raw_port := str(env_vars["KALASTUSPELI_PORT"]).strip_edges()
		if not raw_port.is_empty() and raw_port.is_valid_int():
			cfg.default_port = clampi(int(raw_port), 1, 65535)

	if env_vars.has("KALASTUSPELI_SYNC_HZ"):
		var raw_hz := str(env_vars["KALASTUSPELI_SYNC_HZ"]).strip_edges()
		if not raw_hz.is_empty() and raw_hz.is_valid_int():
			cfg.sync_hz = clampi(int(raw_hz), 1, 60)

	if env_vars.has("KALASTUSPELI_MAX_CLIENTS"):
		var raw_max := str(env_vars["KALASTUSPELI_MAX_CLIENTS"]).strip_edges()
		if not raw_max.is_empty() and raw_max.is_valid_int():
			cfg.max_clients = clampi(int(raw_max), 1, 32)

	if env_vars.has("KALASTUSPELI_DEBUG_HUD") and not str(env_vars["KALASTUSPELI_DEBUG_HUD"]).strip_edges().is_empty():
		cfg.debug_hud = _parse_bool(env_vars["KALASTUSPELI_DEBUG_HUD"], cfg.debug_hud)
	if env_vars.has("KALASTUSPELI_DEBUG_HOTKEYS") and not str(env_vars["KALASTUSPELI_DEBUG_HOTKEYS"]).strip_edges().is_empty():
		cfg.debug_hotkeys = _parse_bool(env_vars["KALASTUSPELI_DEBUG_HOTKEYS"], cfg.debug_hotkeys)
	if env_vars.has("KALASTUSPELI_VERBOSE_NET_LOGS") and not str(env_vars["KALASTUSPELI_VERBOSE_NET_LOGS"]).strip_edges().is_empty():
		cfg.verbose_net_logs = _parse_bool(env_vars["KALASTUSPELI_VERBOSE_NET_LOGS"], cfg.verbose_net_logs)
	if env_vars.has("KALASTUSPELI_ALLOW_BOTS") and not str(env_vars["KALASTUSPELI_ALLOW_BOTS"]).strip_edges().is_empty():
		cfg.allow_bots = _parse_bool(env_vars["KALASTUSPELI_ALLOW_BOTS"], cfg.allow_bots)

	return cfg
