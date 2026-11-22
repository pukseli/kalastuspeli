class_name RodState
extends RefCounted
## Pure state model for a fishing rod's line projection, angular lag, and planer board.

var rod_id: String = ""
var trail_angle: float = 0.0
var trail_factor: float = 0.0
var planer: PlanerBoard = PlanerBoard.new()


func is_deployed() -> bool:
	return planer != null and planer.is_in_water()


func get_line_out() -> float:
	return planer.line_out if planer != null else 0.0


func clone() -> RodState:
	var copy := RodState.new()
	copy.rod_id = rod_id
	copy.trail_angle = trail_angle
	copy.trail_factor = trail_factor
	copy.planer = planer.clone() if planer != null else PlanerBoard.new()
	return copy


func to_dict() -> Dictionary:
	if planer == null:
		planer = PlanerBoard.new()
	return {
		"rod_id": rod_id,
		"trail_angle": trail_angle,
		"trail_factor": trail_factor,
		"planer": planer.to_dict(),
	}


func from_dict(data: Dictionary) -> void:
	rod_id = str(data.get("rod_id", rod_id))
	trail_angle = wrapf(float(data.get("trail_angle", 0.0)), -PI, PI)
	trail_factor = clampf(float(data.get("trail_factor", 0.0)), 0.0, 1.0)
	if planer == null:
		planer = PlanerBoard.new()
	var raw_planer: Variant = data.get("planer", null)
	if raw_planer is Dictionary:
		planer.from_dict(raw_planer as Dictionary)
