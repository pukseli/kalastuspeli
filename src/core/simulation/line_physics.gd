class_name LinePhysics
extends RefCounted
## Pure simulation module for line tension, reel drag clutch, spool capacity, abrasion, and snapping.

const LINE_MAX_STRENGTH: float = RodState.DEFAULT_LINE_MAX_STRENGTH
const DEFAULT_DRAG: float = RodState.DEFAULT_DRAG_SETTING
const MIN_DRAG: float = RodState.MIN_DRAG_SETTING
const MAX_DRAG: float = RodState.MAX_DRAG_SETTING
const DRAG_ADJUST_RATE: float = 40.0

const SPOOL_CAPACITY: float = RodState.DEFAULT_SPOOL_CAPACITY
const MAX_DEPLOY_LINE_OUT: float = 35.0
const SNAP_STUB_LINE_OUT: float = 6.0
const SNAP_MIN_STUB_LINE_OUT: float = 2.0

const FISH_PULL_TO_NEWTONS: float = 60.0
const DRAG_SLIP_GAIN: float = 1.0 / 60.0
const MAX_DRAG_SLIP_SPEED: float = 2.0

const WATER_DRAG_BASE: float = 3.0
const WATER_DRAG_PER_M: float = 0.15
const WATER_DRAG_PLANER: float = 2.5
const WATER_DRAG_TRIPPED: float = 0.5
const REEL_LOAD: float = 15.0

const SNAG_BASE_PULL: float = 20.0
const SNAG_STRETCH_GAIN: float = 30.0

const ABRASION_SNAGGED: float = 0.05
const ABRASION_TANGLED: float = 0.06
const MIN_ABRASION_INTEGRITY: float = 0.15

const SLACK_TENSION_THRESHOLD: float = 10.0
const SLACK_ESCAPE_HAZARD: float = 0.40


## Computes water drag force (N) from boat speed, line_out, and planer attachment state.
static func compute_water_drag(boat_forward_speed: float, rod: RodState) -> float:
	if rod == null or not rod.is_deployed():
		return 0.0
	var v := maxf(0.0, boat_forward_speed)
	var k_planer := 0.0
	if rod.planer.attached:
		if rod.planer.state == PlanerBoard.STATE_TRIPPED:
			k_planer = WATER_DRAG_TRIPPED
		elif (
			rod.planer.state == PlanerBoard.STATE_TROLLING
			or rod.planer.state == PlanerBoard.STATE_DEPLOYING
			or rod.planer.state == PlanerBoard.STATE_SNAGGED
		):
			k_planer = WATER_DRAG_PLANER
	return v * (WATER_DRAG_BASE + WATER_DRAG_PER_M * rod.planer.line_out + k_planer)


## Computes pull force (N) exerted when the line or planer is anchored in SNAGGED state.
static func compute_snag_pull(state: GameState, item: HeldItem, rod: RodState, rod_sim: RodSimulator) -> float:
	if rod == null or rod.planer.state != PlanerBoard.STATE_SNAGGED or rod_sim == null:
		return 0.0
	var tip := rod_sim.get_rod_tip_world(state, item)
	var snag_dist := Vector2(tip.x, tip.z).distance_to(rod.planer.snag_world_position)
	return SNAG_BASE_PULL + SNAG_STRETCH_GAIN * maxf(0.0, snag_dist - rod.planer.line_out)


## Returns true when a snapped stub has already lost its fish/planer and must not re-snap in a loop.
static func is_broken_stub(state: GameState, rod: RodState) -> bool:
	if rod == null or state == null:
		return false
	return (
		rod.planer.state == PlanerBoard.STATE_TANGLED
		and not rod.planer.attached
		and not state.has_fish_on_rod(rod.rod_id)
		and rod.planer.line_out <= SNAP_STUB_LINE_OUT + 0.05
	)


## Advances abrasion, line tension, reel drag slip, and snap checks for one rod tick.
static func step_rod_line(
	state: GameState,
	item: HeldItem,
	rod: RodState,
	rod_sim: RodSimulator,
	delta: float,
	fish_pull_n: float = 0.0,
	is_reeling: bool = false,
	is_detaching: bool = false,
	max_slip_speed: float = MAX_DRAG_SLIP_SPEED
) -> Dictionary:
	if rod == null or not rod.is_deployed():
		if rod != null:
			rod.line_tension = 0.0
			rod.is_drag_slipping = false
		return {"snapped": false, "slip_speed": 0.0, "external_load": 0.0}

	var broken_stub := is_broken_stub(state, rod)
	if rod.planer.state == PlanerBoard.STATE_SNAGGED:
		rod.line_integrity = maxf(MIN_ABRASION_INTEGRITY, rod.line_integrity - ABRASION_SNAGGED * delta)
	elif rod.planer.state == PlanerBoard.STATE_TANGLED and not broken_stub:
		rod.line_integrity = maxf(MIN_ABRASION_INTEGRITY, rod.line_integrity - ABRASION_TANGLED * delta)

	var f_water := compute_water_drag(state.boat.forward_speed, rod)
	if broken_stub:
		f_water *= 0.25
	var f_snag := compute_snag_pull(state, item, rod, rod_sim)
	var f_ext := f_water + maxf(0.0, fish_pull_n) + f_snag
	var f_reel := REEL_LOAD if (is_reeling and f_ext <= rod.drag_setting) else 0.0
	var f_load := f_ext + f_reel

	var slip_speed := 0.0
	if rod.line_remaining_on_spool > 0.001 and f_ext > rod.drag_setting:
		rod.is_drag_slipping = true
		rod.line_tension = rod.drag_setting
		slip_speed = clampf((f_ext - rod.drag_setting) * DRAG_SLIP_GAIN, 0.0, max_slip_speed)
		if not is_detaching:
			var delta_out := minf(rod.line_remaining_on_spool, slip_speed * delta)
			rod.planer.line_out += delta_out
			rod.line_remaining_on_spool = maxf(0.0, rod.line_remaining_on_spool - delta_out)
			if rod.line_remaining_on_spool <= 0.001:
				rod.line_remaining_on_spool = 0.0
				rod.is_drag_slipping = false
				rod.line_tension = f_load
	else:
		rod.is_drag_slipping = false
		rod.line_tension = minf(f_load, rod.drag_setting) if rod.line_remaining_on_spool > 0.001 else f_load

	var eff_max := rod.get_effective_max_strength()
	if not broken_stub and eff_max > 0.0 and rod.line_tension >= eff_max - 0.001:
		var reason := "Siima katkesi: Jarru oli liian kireällä!"
		if rod.line_remaining_on_spool <= 0.001:
			reason = "Siima katkesi: Puola tyhjeni!"
		elif rod.line_integrity < 0.99 and rod.drag_setting < rod.line_max_strength:
			reason = "Siima katkesi: Kulunut siima petti!"
		state.fishes.erase(rod.rod_id)
		state.set_fish_notice(reason, 4.5)
		rod.planer.attached = false
		rod.planer.state = PlanerBoard.STATE_TANGLED
		rod.planer.snag_world_position = Vector2.ZERO
		rod.planer.reset_strike_reaction()
		rod.planer.lateral_offset = 0.0
		rod.planer.line_out = clampf(rod.planer.line_out, SNAP_MIN_STUB_LINE_OUT, SNAP_STUB_LINE_OUT)
		rod.line_tension = 0.0
		rod.is_drag_slipping = false
		return {"snapped": true, "slip_speed": 0.0, "external_load": f_ext}

	return {"snapped": false, "slip_speed": slip_speed, "external_load": f_ext}
