class_name StationSimulator
extends RefCounted

const FIXED_DELTA: float = 1.0 / 60.0
const LEVER_ADJUST_SPEED: float = 1.5
const STEER_MIN_SPEED: float = 0.35
const STEER_MAX_SPEED: float = 1.6
const STEER_RETURN_SPEED: float = 1.2
const DETENT_HOLD_TIME: float = 0.25


func _get_player_input(inputs: Dictionary, pid: int) -> Variant:
	if inputs.has(pid):
		return inputs[pid]
	var str_pid := str(pid)
	if inputs.has(str_pid):
		return inputs[str_pid]
	return null


func step(state: GameState, inputs: Dictionary, _delta: float = FIXED_DELTA) -> void:
	var pids: Array[int] = []
	for pid_raw in inputs.keys():
		var pid := int(pid_raw)
		if pid != 0 and not pids.has(pid):
			pids.append(pid)
	pids.sort()

	var occupied_at_start: Dictionary = state.stations.duplicate()
	var prev_helm := int(state.stations.get(StationConfig.HELM_STATION_ID, 0))

	var station_ids: Array[String] = []
	for sid_raw in state.stations.keys():
		station_ids.append(str(sid_raw))
	station_ids.sort()

	for pid in pids:
		if not state.players.has(pid):
			continue
		var player: PlayerState = state.players[pid]
		if player.is_bot:
			continue

		var raw_input: Variant = _get_player_input(inputs, pid)
		var interact_pressed := false
		if raw_input is PlayerInput:
			interact_pressed = (raw_input as PlayerInput).interact
		elif raw_input is Dictionary:
			interact_pressed = bool((raw_input as Dictionary).get("interact", false))

		if not interact_pressed:
			continue

		var current_station := state.get_player_station(pid)
		if not current_station.is_empty():
			state.stations[current_station] = 0
		else:
			var best_sid := ""
			var best_dist := INF
			for sid in station_ids:
				if int(state.stations.get(sid, 0)) != 0 or int(occupied_at_start.get(sid, 0)) != 0:
					continue
				var station_pos := StationConfig.get_station_position(sid)
				var radius := StationConfig.get_station_radius(sid)
				var dx := player.local_position.x - station_pos.x
				var dz := player.local_position.z - station_pos.z
				var dist := sqrt(dx * dx + dz * dz)
				if dist <= radius and dist < best_dist:
					best_dist = dist
					best_sid = sid
			if not best_sid.is_empty():
				state.stations[best_sid] = pid
				player.local_position = StationConfig.get_station_position(best_sid)

	for sid_raw in state.stations:
		var sid := str(sid_raw)
		var occ := int(state.stations[sid_raw])
		if occ != 0 and state.players.has(occ):
			var occupant: PlayerState = state.players[occ]
			occupant.local_position = StationConfig.get_station_position(sid)

	var next_helm := int(state.stations.get(StationConfig.HELM_STATION_ID, 0))
	if next_helm != prev_helm:
		state.reset_helm_detents()
		state.helm_last_occupant = next_helm


func apply_helm_input_to_boat(
	state: GameState,
	inputs: Dictionary,
	delta: float = FIXED_DELTA,
	max_steering_angle: float = BoatSimulator.DEFAULT_MAX_STEERING_ANGLE
) -> void:
	var helm_occupant := int(state.stations.get(StationConfig.HELM_STATION_ID, 0))
	if helm_occupant == 0 or helm_occupant != state.helm_last_occupant:
		state.reset_helm_detents()
		state.helm_last_occupant = helm_occupant
	if helm_occupant == 0:
		return

	var raw_input: Variant = _get_player_input(inputs, helm_occupant)
	if raw_input == null:
		state.reset_helm_detents()
		return

	var throttle_in := 0.0
	var steering_in := 0.0
	if raw_input is PlayerInput:
		throttle_in = (raw_input as PlayerInput).throttle
		steering_in = (raw_input as PlayerInput).steering
	elif raw_input is Dictionary:
		throttle_in = float((raw_input as Dictionary).get("throttle", 0.0))
		steering_in = float((raw_input as Dictionary).get("steering", 0.0))

	var throttle_res := _step_detent_axis(
		state.boat.throttle,
		throttle_in,
		LEVER_ADJUST_SPEED,
		1.0,
		state.helm_throttle_detent_timer,
		state.helm_throttle_detent_sign,
		delta
	)
	state.boat.throttle = throttle_res[0]
	state.helm_throttle_detent_timer = throttle_res[1]
	state.helm_throttle_detent_sign = throttle_res[2]

	var steer_speed := _compute_steering_speed(state.boat.steering_angle, steering_in, max_steering_angle)
	var steer_res := _step_detent_axis(
		state.boat.steering_angle,
		steering_in,
		steer_speed,
		max_steering_angle,
		state.helm_steer_detent_timer,
		state.helm_steer_detent_sign,
		delta
	)
	state.boat.steering_angle = steer_res[0]
	state.helm_steer_detent_timer = steer_res[1]
	state.helm_steer_detent_sign = steer_res[2]


func _compute_steering_speed(current_angle: float, steering_in: float, max_steering_angle: float) -> float:
	if absf(steering_in) <= 0.01:
		return STEER_MIN_SPEED
	var s_sign := 1 if steering_in > 0.0 else -1
	var is_moving_toward_zero := (current_angle > 0.0001 and s_sign < 0) or (current_angle < -0.0001 and s_sign > 0)
	if is_moving_toward_zero:
		return STEER_RETURN_SPEED
	var norm_deflection := clampf(absf(current_angle) / max_steering_angle, 0.0, 1.0) if max_steering_angle > 0.0001 else 0.0
	return lerpf(STEER_MIN_SPEED, STEER_MAX_SPEED, norm_deflection * norm_deflection)


func _step_detent_axis(
	current_value: float,
	input_value: float,
	speed: float,
	max_abs: float,
	detent_timer: float,
	detent_sign: int,
	delta: float
) -> Array:
	if absf(input_value) <= 0.01:
		return [current_value, 0.0, 0]

	var sign_dir := 1 if input_value > 0.0 else -1
	var mag := clampf(absf(input_value), 0.0, 1.0)
	if detent_timer > 0.0:
		detent_timer -= delta
		if detent_sign != 0 and sign_dir != detent_sign:
			detent_timer = 0.0
		else:
			current_value = 0.0
		if detent_timer > 0.0:
			return [0.0, detent_timer, detent_sign]

	var next_value := current_value + float(sign_dir) * mag * speed * delta
	if (current_value > 0.0 and next_value <= 0.0) or (current_value < 0.0 and next_value >= 0.0):
		return [0.0, DETENT_HOLD_TIME, sign_dir]
	return [clampf(next_value, -max_abs, max_abs), 0.0, 0]


func get_active_boat_input(
	state: GameState,
	max_steering_angle: float = BoatSimulator.DEFAULT_MAX_STEERING_ANGLE
) -> PlayerInput:
	var active_input := PlayerInput.new()
	active_input.throttle = state.boat.throttle
	if max_steering_angle > 0.0001:
		active_input.steering = clampf(state.boat.steering_angle / max_steering_angle, -1.0, 1.0)
	else:
		active_input.steering = 0.0
	return active_input
