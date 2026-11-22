class_name PlanerBoard
extends RefCounted
## Pure state model for a line-mounted planer board and line length.

const SIDE_LEFT: int = -1
const SIDE_RIGHT: int = 1

const STATE_STOWED: String = "STOWED"
const STATE_DEPLOYING: String = "DEPLOYING"
const STATE_TROLLING: String = "TROLLING"
const STATE_TRIPPED: String = "TRIPPED"
const STATE_TANGLED: String = "TANGLED"
const STATE_SNAGGED: String = "SNAGGED"

const VALID_STATES: Array[String] = [
	STATE_STOWED,
	STATE_DEPLOYING,
	STATE_TROLLING,
	STATE_TRIPPED,
	STATE_TANGLED,
	STATE_SNAGGED,
]

var side: int = SIDE_RIGHT
var attached: bool = true
var lateral_offset: float = 0.0
var line_out: float = 0.0
var state: String = STATE_STOWED
var snag_world_position: Vector2 = Vector2.ZERO


func is_in_water() -> bool:
	return line_out > 0.001


func is_active_trolling() -> bool:
	return attached and is_in_water() and (
		state == STATE_DEPLOYING or state == STATE_TROLLING or state == STATE_TRIPPED
	)


func clone() -> PlanerBoard:
	var copy := PlanerBoard.new()
	copy.side = side
	copy.attached = attached
	copy.lateral_offset = lateral_offset
	copy.line_out = line_out
	copy.state = state
	copy.snag_world_position = snag_world_position
	return copy


func to_dict() -> Dictionary:
	return {
		"side": side,
		"attached": attached,
		"lateral_offset": lateral_offset,
		"line_out": line_out,
		"state": state,
		"snag_world_position": {
			"x": snag_world_position.x,
			"y": snag_world_position.y,
		},
	}


func from_dict(data: Dictionary) -> void:
	side = SIDE_LEFT if int(data.get("side", SIDE_RIGHT)) < 0 else SIDE_RIGHT
	attached = bool(data.get("attached", true))
	lateral_offset = float(data.get("lateral_offset", 0.0))
	line_out = maxf(0.0, float(data.get("line_out", 0.0)))
	var next_state := str(data.get("state", STATE_STOWED))
	state = next_state if VALID_STATES.has(next_state) else STATE_STOWED

	var raw_snag: Variant = data.get("snag_world_position", null)
	if raw_snag is Vector2:
		snag_world_position = raw_snag as Vector2
	elif raw_snag is Dictionary:
		var sd := raw_snag as Dictionary
		snag_world_position = Vector2(float(sd.get("x", 0.0)), float(sd.get("y", 0.0)))
	else:
		snag_world_position = Vector2.ZERO
