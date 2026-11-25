class_name GameSnapshot
extends RefCounted
## Pure test-only game snapshot serializer, loader, and delayed event runner.
## Zero Node, view, input, or network dependencies (Headless Core boundary compliant).

const SNAPSHOT_VERSION: int = 1
const FIXED_DELTA: float = 1.0 / 60.0
const SNAPSHOTS_DIR: String = "res://config/snapshots"
const QUICKSAVE_PATH: String = "user://snapshots/quicksave.json"
const DEFAULT_TEST_SNAPSHOT: String = "whale_strike_2s"
const TIME_EPSILON: float = 0.0005

var snapshot_name: String = ""
var description: String = ""
var source_path: String = ""
var rng_seed: int = -1
var suppress_auto_bites_while_pending: bool = false
var state_data: Dictionary = {}
var scheduled_events: Array[Dictionary] = []

var _elapsed_sec: float = 0.0
var _pending_events: Array[Dictionary] = []
var _saved_bite_rate: float = -1.0
var _suppressed_fish_sim: FishSimulator = null


## Extracts the snapshot name or file path from `--snapshot <val>` or `--snapshot=<val>`.
static func extract_cli_snapshot(cli_args: PackedStringArray) -> String:
	var flag := "--snapshot"
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


## Resolves a short snapshot name (e.g. `whale_strike_2s`) or explicit path to a file path.
static func resolve_path(ref: String) -> String:
	var trimmed := ref.strip_edges()
	if trimmed.is_empty():
		return ""
	var is_explicit := (
		trimmed.begins_with("res://")
		or trimmed.begins_with("user://")
		or trimmed.begins_with("/")
		or trimmed.contains("/")
		or trimmed.contains("\\")
		or trimmed.ends_with(".json")
	)
	if is_explicit:
		if not trimmed.ends_with(".json") and not FileAccess.file_exists(trimmed) and FileAccess.file_exists(trimmed + ".json"):
			return trimmed + ".json"
		return trimmed
	return "%s/%s.json" % [SNAPSHOTS_DIR, trimmed]


## Loads and parses a GameSnapshot from a name or path, returning null if missing or invalid.
static func load_from_file(ref_or_path: String) -> GameSnapshot:
	var resolved := resolve_path(ref_or_path)
	if resolved.is_empty() or not FileAccess.file_exists(resolved):
		return null
	var file := FileAccess.open(resolved, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	if text.strip_edges().is_empty():
		return null
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return null
	return from_dict(json.data as Dictionary, resolved)


## Normalizes a snapshot event dictionary into a canonical structure.
static func _normalize_event(raw_ev: Dictionary) -> Dictionary:
	var normalized := {
		"delay_sec": maxf(0.0, float(raw_ev.get("delay_sec", 0.0))),
		"type": str(raw_ev.get("type", "")).strip_edges(),
		"rod_id": str(raw_ev.get("rod_id", "")).strip_edges(),
		"species": str(raw_ev.get("species", "")).strip_edges(),
		"weight_kg": float(raw_ev.get("weight_kg", -1.0)) if raw_ev.get("weight_kg", null) != null else -1.0,
		"trigger_jump": bool(raw_ev.get("trigger_jump", false)),
		"notice": str(raw_ev.get("notice", "")),
		"notice_duration": maxf(0.0, float(raw_ev.get("notice_duration", 4.0))),
		"text": str(raw_ev.get("text", "")),
		"duration": maxf(0.0, float(raw_ev.get("duration", 4.0))),
	}
	return normalized


## Builds a GameSnapshot from a parsed JSON dictionary (envelope or raw GameState dict).
static func from_dict(data: Dictionary, path: String = "") -> GameSnapshot:
	if data.is_empty():
		return null
	var raw_state: Dictionary = {}
	if data.has("state") and data["state"] is Dictionary:
		raw_state = (data["state"] as Dictionary).duplicate(true)
	elif data.has("boat") and data.has("players"):
		raw_state = data.duplicate(true)
	else:
		return null

	var snap := GameSnapshot.new()
	snap.source_path = path
	var fallback_name := path.get_file().get_basename() if not path.is_empty() else "snapshot"
	snap.snapshot_name = str(data.get("name", fallback_name)).strip_edges()
	if snap.snapshot_name.is_empty():
		snap.snapshot_name = fallback_name
	snap.description = str(data.get("description", ""))
	if data.has("rng_seed") and data["rng_seed"] != null:
		snap.rng_seed = int(data["rng_seed"])
	else:
		snap.rng_seed = -1
	snap.suppress_auto_bites_while_pending = bool(data.get("suppress_auto_bites_while_pending", false))
	snap.state_data = raw_state

	var raw_events: Variant = data.get("scheduled_events", null)
	if raw_events is Array:
		for ev in (raw_events as Array):
			if ev is Dictionary:
				snap.scheduled_events.append(_normalize_event(ev as Dictionary))
	return snap


## Captures the live GameState into a serializable GameSnapshot.
static func capture_from_state(
	state: GameState,
	snap_name: String = "quicksave",
	snap_description: String = "",
	events: Array = [],
	seed_value: int = -1,
	suppress_bites: bool = false
) -> GameSnapshot:
	var snap := GameSnapshot.new()
	snap.snapshot_name = snap_name
	snap.description = snap_description
	snap.rng_seed = seed_value
	snap.suppress_auto_bites_while_pending = suppress_bites
	if state != null:
		snap.state_data = state.to_dict()
	for ev in events:
		if ev is Dictionary:
			snap.scheduled_events.append(_normalize_event(ev as Dictionary))
	return snap


## Serializes this snapshot into a JSON-ready Dictionary.
func to_dict() -> Dictionary:
	var events_copy: Array = []
	for ev in scheduled_events:
		events_copy.append(ev.duplicate(true))
	var out := {
		"version": SNAPSHOT_VERSION,
		"name": snapshot_name,
		"description": description,
		"suppress_auto_bites_while_pending": suppress_auto_bites_while_pending,
		"state": state_data.duplicate(true),
		"scheduled_events": events_copy,
	}
	if rng_seed >= 0:
		out["rng_seed"] = rng_seed
	return out


## Writes this snapshot to a JSON file, creating parent directories when needed.
func save_to_file(path: String = QUICKSAVE_PATH) -> bool:
	var target_path := path.strip_edges()
	if target_path.is_empty():
		return false
	var parent_dir := target_path.get_base_dir()
	if not parent_dir.is_empty():
		var dir_err := DirAccess.make_dir_recursive_absolute(parent_dir)
		if dir_err != OK:
			return false
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dict(), "\t") + "\n")
	file.close()
	source_path = target_path
	return true


## Restores any previously suppressed automatic bite rate on the tracked FishSimulator.
func restore_bite_rate() -> void:
	if _suppressed_fish_sim != null and _saved_bite_rate >= 0.0:
		_suppressed_fish_sim.config.base_bite_rate_per_rod = _saved_bite_rate
	_suppressed_fish_sim = null
	_saved_bite_rate = -1.0


## Applies the snapshot state to target GameState and arms scheduled test events.
func apply_to(state: GameState, fish_sim: FishSimulator = null, preserve_monotonic_tick: bool = true) -> bool:
	restore_bite_rate()
	if state == null or state_data.is_empty():
		return false
	var prev_tick := state.tick
	state.from_dict(state_data)
	state.reset_helm_detents()
	state.helm_last_occupant = int(state.stations.get(StationConfig.HELM_STATION_ID, 0))
	if preserve_monotonic_tick and prev_tick > 0 and state.tick <= prev_tick:
		state.tick = prev_tick + 1
	if fish_sim != null and rng_seed >= 0:
		fish_sim.set_seed(rng_seed)

	_elapsed_sec = 0.0
	_pending_events.clear()
	for ev in scheduled_events:
		_pending_events.append(ev.duplicate(true))

	if suppress_auto_bites_while_pending and not _pending_events.is_empty() and fish_sim != null:
		_saved_bite_rate = fish_sim.config.base_bite_rate_per_rod
		_suppressed_fish_sim = fish_sim
		fish_sim.config.base_bite_rate_per_rod = 0.0
	return true


## Returns true while at least one scheduled event is still waiting to fire.
func has_pending_events() -> bool:
	return not _pending_events.is_empty()


## Returns seconds remaining until the next pending event, or -1.0 when none remain.
func get_next_event_remaining_sec() -> float:
	if _pending_events.is_empty():
		return -1.0
	var min_rem := INF
	for ev in _pending_events:
		var rem := maxf(0.0, float(ev.get("delay_sec", 0.0)) - _elapsed_sec)
		if rem < min_rem:
			min_rem = rem
	return min_rem if min_rem < INF else -1.0


## Advances the snapshot timer and triggers any due scheduled events.
func step(state: GameState, rod_sim: RodSimulator, fish_sim: FishSimulator, delta: float = FIXED_DELTA) -> Array[Dictionary]:
	var triggered: Array[Dictionary] = []
	if state == null or _pending_events.is_empty():
		restore_bite_rate()
		return triggered

	_elapsed_sec += maxf(0.0, delta)
	var remaining: Array[Dictionary] = []

	for ev in _pending_events:
		if _elapsed_sec + TIME_EPSILON < float(ev.get("delay_sec", 0.0)):
			remaining.append(ev)
			continue

		var ev_type := str(ev.get("type", ""))
		if ev_type == "force_bite":
			if fish_sim != null:
				var desired_rod := str(ev.get("rod_id", ""))
				var target_rod_id := ""
				if not desired_rod.is_empty() and state.rods.has(desired_rod):
					var desired_state := state.get_rod_state(desired_rod)
					if desired_state != null and desired_state.is_deployed() and not state.has_fish_on_rod(desired_rod):
						target_rod_id = desired_rod
				var species := str(ev.get("species", ""))
				var weight_kg := float(ev.get("weight_kg", -1.0))
				var fish := fish_sim.force_bite(state, rod_sim, target_rod_id, species, weight_kg)
				if fish != null and bool(ev.get("trigger_jump", false)) and fish.jump_progress <= 0.001:
					fish.jump_progress = 0.002
				var notice := str(ev.get("notice", ""))
				if fish != null and not notice.is_empty():
					state.set_fish_notice(notice, float(ev.get("notice_duration", 4.0)))
				triggered.append({
					"type": "force_bite",
					"rod_id": fish.rod_id if fish != null else "",
					"species": fish.species if fish != null else "",
					"success": fish != null,
				})
		elif ev_type == "fish_notice":
			state.set_fish_notice(str(ev.get("text", "")), float(ev.get("duration", 4.0)))
			triggered.append({
				"type": "fish_notice",
				"success": true,
			})

	_pending_events = remaining
	if _pending_events.is_empty():
		restore_bite_rate()
	return triggered
