class_name CameraController
extends RefCounted
## Device-agnostic client-local spherical camera controller and semantic input profile mapper.

const SCHEME_ARROWS_WASD: String = "arrows_wasd"
const SCHEME_WASD_MOUSE: String = "wasd_mouse"
const CONTROL_SCHEMES: Array[String] = [SCHEME_ARROWS_WASD, SCHEME_WASD_MOUSE]

const DECK_PIVOT := Vector3(0.0, 1.0, 1.5)
const DECK_DEFAULT_YAW_DEG: float = 180.0
const DECK_DEFAULT_PITCH_DEG: float = -28.0
const DECK_DEFAULT_DIST: float = 11.5
const DECK_MIN_DIST: float = 7.0
const DECK_MAX_DIST: float = 20.0
const DECK_MIN_PITCH_DEG: float = -65.0
const DECK_MAX_PITCH_DEG: float = -8.0

const HELM_DEFAULT_YAW_DEG: float = 0.0
const HELM_DEFAULT_PITCH_DEG: float = StationConfig.HELM_CAM_PITCH_DEG
const HELM_MIN_PITCH_DEG: float = -45.0
const HELM_MAX_PITCH_DEG: float = 25.0

const YAW_SPEED_DEG: float = 120.0
const PITCH_SPEED_DEG: float = 75.0
const MOUSE_SENS_DEG: float = 0.25
const ZOOM_STEP: float = 1.2
const SMOOTH_FACTOR: float = 0.15

var in_helm: bool = false
var control_scheme: String = SCHEME_ARROWS_WASD

var target_yaw: float = PI
var target_pitch: float = DECK_DEFAULT_PITCH_DEG
var target_dist: float = DECK_DEFAULT_DIST
var target_pivot: Vector3 = DECK_PIVOT

var current_yaw: float = PI
var current_pitch: float = DECK_DEFAULT_PITCH_DEG
var current_dist: float = DECK_DEFAULT_DIST
var current_pivot: Vector3 = DECK_PIVOT


func _init() -> void:
	reset_to_default(true)


func set_mode(helm_active: bool, snap: bool = false) -> void:
	if helm_active != in_helm:
		in_helm = helm_active
		reset_to_default(snap)
	elif snap:
		step(true)


func reset_to_default(snap: bool = false) -> void:
	if in_helm:
		target_yaw = deg_to_rad(HELM_DEFAULT_YAW_DEG)
		target_pitch = HELM_DEFAULT_PITCH_DEG
		target_dist = 0.0
		target_pivot = StationConfig.HELM_CAM_OFFSET
	else:
		target_yaw = PI
		target_pitch = DECK_DEFAULT_PITCH_DEG
		target_dist = DECK_DEFAULT_DIST
		target_pivot = DECK_PIVOT
	if snap:
		step(true)


func _get_pitch_bounds() -> Vector2:
	if in_helm:
		return Vector2(HELM_MIN_PITCH_DEG, HELM_MAX_PITCH_DEG)
	return Vector2(DECK_MIN_PITCH_DEG, DECK_MAX_PITCH_DEG)


func apply_axes(yaw_axis: float, pitch_axis: float, delta: float = 1.0 / 60.0) -> void:
	var bounds := _get_pitch_bounds()
	target_yaw = wrapf(target_yaw + yaw_axis * deg_to_rad(YAW_SPEED_DEG) * delta, -PI, PI)
	target_pitch = clampf(target_pitch + pitch_axis * PITCH_SPEED_DEG * delta, bounds.x, bounds.y)


func apply_mouse_drag(relative_px: Vector2) -> void:
	var bounds := _get_pitch_bounds()
	target_yaw = wrapf(target_yaw - deg_to_rad(relative_px.x * MOUSE_SENS_DEG), -PI, PI)
	target_pitch = clampf(target_pitch - relative_px.y * MOUSE_SENS_DEG, bounds.x, bounds.y)


func apply_zoom(zoom_delta: float) -> void:
	if in_helm:
		target_dist = 0.0
		return
	target_dist = clampf(target_dist - zoom_delta * ZOOM_STEP, DECK_MIN_DIST, DECK_MAX_DIST)


func step(snap: bool = false) -> void:
	if snap:
		current_yaw = target_yaw
		current_pitch = target_pitch
		current_dist = target_dist
		current_pivot = target_pivot
		return
	current_yaw = wrapf(lerp_angle(current_yaw, target_yaw, SMOOTH_FACTOR), -PI, PI)
	current_pitch = lerpf(current_pitch, target_pitch, SMOOTH_FACTOR)
	current_dist = lerpf(current_dist, target_dist, SMOOTH_FACTOR)
	current_pivot = current_pivot.lerp(target_pivot, SMOOTH_FACTOR)


func compute_camera_transform(boat_world_pos: Vector3, boat_heading: float) -> Dictionary:
	var p := deg_to_rad(current_pitch)
	var y := current_yaw
	var fwd := Vector3(-cos(p) * sin(y), sin(p), -cos(p) * cos(y))
	var local_pos := current_pivot - fwd * current_dist
	var world_pos := boat_world_pos + local_pos.rotated(Vector3.UP, boat_heading)
	var world_rot := Vector3(p, wrapf(boat_heading + y, -PI, PI), 0.0)
	return {
		"position": world_pos,
		"rotation": world_rot,
	}


static func project_deck_input(screen_x: float, screen_forward: float, cam_yaw_rad: float) -> Vector2:
	var move_x := screen_x * cos(cam_yaw_rad) - screen_forward * sin(cam_yaw_rad)
	var move_z := -screen_x * sin(cam_yaw_rad) - screen_forward * cos(cam_yaw_rad)
	return Vector2(move_x, move_z)


func set_control_scheme(scheme: String) -> String:
	if CONTROL_SCHEMES.has(scheme):
		control_scheme = scheme
	else:
		control_scheme = SCHEME_ARROWS_WASD
	return control_scheme


func cycle_control_scheme() -> String:
	var idx := CONTROL_SCHEMES.find(control_scheme)
	var next_idx := (idx + 1) % CONTROL_SCHEMES.size()
	control_scheme = CONTROL_SCHEMES[next_idx]
	return control_scheme


static func parse_control_scheme_from_args(args: PackedStringArray) -> String:
	var i := 0
	while i < args.size():
		var arg := args[i]
		if arg == "--controls":
			if i + 1 < args.size():
				var candidate := args[i + 1].strip_edges().to_lower()
				if CONTROL_SCHEMES.has(candidate):
					return candidate
				i += 1
		elif arg.begins_with("--controls="):
			var candidate := arg.substr(11).strip_edges().to_lower()
			if CONTROL_SCHEMES.has(candidate):
				return candidate
		i += 1
	return SCHEME_ARROWS_WASD


static func map_control_inputs(
	scheme: String,
	helm_active: bool,
	wasd_x: float,
	wasd_y: float,
	arrow_x: float,
	arrow_y: float,
	cam_yaw_rad: float
) -> Dictionary:
	var throttle := 0.0
	var steering := 0.0
	var move_x := 0.0
	var move_z := 0.0
	var cam_yaw_axis := 0.0
	var cam_pitch_axis := 0.0

	var use_wasd_for_move := (scheme == SCHEME_WASD_MOUSE)
	var move_in_x := wasd_x if use_wasd_for_move else arrow_x
	var move_in_y := wasd_y if use_wasd_for_move else arrow_y

	if not use_wasd_for_move:
		cam_yaw_axis = -wasd_x
		cam_pitch_axis = wasd_y

	if helm_active:
		throttle = clampf(move_in_y, -1.0, 1.0)
		steering = clampf(-move_in_x, -1.0, 1.0)
	else:
		var projected := project_deck_input(move_in_x, move_in_y, cam_yaw_rad)
		move_x = projected.x
		move_z = projected.y

	return {
		"throttle": throttle,
		"steering": steering,
		"move_x": move_x,
		"move_z": move_z,
		"cam_yaw_axis": cam_yaw_axis,
		"cam_pitch_axis": cam_pitch_axis,
	}


func get_control_mode_hud_text(helm_active: bool, held_label: String) -> String:
	if helm_active:
		if control_scheme == SCHEME_WASD_MOUSE:
			return "RUORISSA (Ajo: WASD | Kamera: Hiiri | Reset: R | Profiili [K]: %s | E: Poistu)" % control_scheme
		return "RUORISSA (Ajo: Nuolet | Kamera: WASD/Hiiri | Reset: R | Profiili [K]: %s | E: Poistu)" % control_scheme
	if control_scheme == SCHEME_WASD_MOUSE:
		return "KANNELLA (Kävely: WASD | Kamera: Hiiri/Rulla | Reset: R | Profiili [K]: %s | E: Käytä) | Kädessä: %s" % [control_scheme, held_label]
	return "KANNELLA (Kävely: Nuolet | Kamera: WASD/Hiiri/Rulla | Reset: R | Profiili [K]: %s | E: Käytä) | Kädessä: %s" % [control_scheme, held_label]
