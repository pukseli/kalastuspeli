class_name RodState
extends RefCounted
## Pure state model for a fishing rod's line projection, angular lag, tension, drag, and planer board.

const DEFAULT_LINE_MAX_STRENGTH: float = 100.0
const DEFAULT_DRAG_SETTING: float = 60.0
const MIN_DRAG_SETTING: float = 0.0
const MAX_DRAG_SETTING: float = 125.0
const DEFAULT_SPOOL_CAPACITY: float = 150.0

var rod_id: String = ""
var trail_angle: float = 0.0
var trail_factor: float = 0.0
var planer: PlanerBoard = PlanerBoard.new()
var line_tension: float = 0.0
var line_max_strength: float = DEFAULT_LINE_MAX_STRENGTH
var drag_setting: float = DEFAULT_DRAG_SETTING
var line_remaining_on_spool: float = DEFAULT_SPOOL_CAPACITY
var line_integrity: float = 1.0
var is_drag_slipping: bool = false


func is_deployed() -> bool:
	return planer != null and planer.is_in_water()


func get_line_out() -> float:
	return planer.line_out if planer != null else 0.0


func get_effective_max_strength() -> float:
	return line_max_strength * line_integrity


func reset_line_condition(spool_capacity: float = DEFAULT_SPOOL_CAPACITY) -> void:
	line_tension = 0.0
	line_integrity = 1.0
	line_remaining_on_spool = maxf(0.0, spool_capacity)
	is_drag_slipping = false


func copy_from(other: RodState) -> void:
	if other == null:
		return
	rod_id = other.rod_id
	trail_angle = other.trail_angle
	trail_factor = other.trail_factor
	line_tension = other.line_tension
	line_max_strength = other.line_max_strength
	drag_setting = other.drag_setting
	line_remaining_on_spool = other.line_remaining_on_spool
	line_integrity = other.line_integrity
	is_drag_slipping = other.is_drag_slipping
	if planer == null:
		planer = PlanerBoard.new()
	if other.planer != null:
		planer.copy_from(other.planer)


func clone() -> RodState:
	var copy := RodState.new()
	copy.copy_from(self)
	return copy


func to_dict() -> Dictionary:
	if planer == null:
		planer = PlanerBoard.new()
	return {
		"rod_id": rod_id,
		"trail_angle": trail_angle,
		"trail_factor": trail_factor,
		"planer": planer.to_dict(),
		"line_tension": line_tension,
		"line_max_strength": line_max_strength,
		"drag_setting": drag_setting,
		"line_remaining_on_spool": line_remaining_on_spool,
		"line_integrity": line_integrity,
		"is_drag_slipping": is_drag_slipping,
	}


func from_dict(data: Dictionary) -> void:
	rod_id = str(data.get("rod_id", rod_id))
	trail_angle = wrapf(float(data.get("trail_angle", 0.0)), -PI, PI)
	trail_factor = clampf(float(data.get("trail_factor", 0.0)), 0.0, 1.0)
	line_tension = maxf(0.0, float(data.get("line_tension", 0.0)))
	line_max_strength = maxf(1.0, float(data.get("line_max_strength", DEFAULT_LINE_MAX_STRENGTH)))
	drag_setting = clampf(float(data.get("drag_setting", DEFAULT_DRAG_SETTING)), MIN_DRAG_SETTING, MAX_DRAG_SETTING)
	line_remaining_on_spool = maxf(0.0, float(data.get("line_remaining_on_spool", DEFAULT_SPOOL_CAPACITY)))
	line_integrity = clampf(float(data.get("line_integrity", 1.0)), 0.0, 1.0)
	is_drag_slipping = bool(data.get("is_drag_slipping", false))
	if planer == null:
		planer = PlanerBoard.new()
	var raw_planer: Variant = data.get("planer", null)
	if raw_planer is Dictionary:
		planer.from_dict(raw_planer as Dictionary)
