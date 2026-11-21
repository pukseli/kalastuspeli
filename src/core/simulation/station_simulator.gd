class_name StationSimulator
extends RefCounted

const FIXED_DELTA: float = 1.0 / 60.0
const LEVER_ADJUST_SPEED: float = 2.0
const STEERING_ADJUST_SPEED: float = 3.0

var _active_input: PlayerInput = PlayerInput.new()


func step(state: GameState, inputs: Dictionary, _delta: float = FIXED_DELTA) -> void:
	for pid_raw in inputs:
		var pid := int(pid_raw)
		var raw_input = inputs[pid_raw]
		var interact_pressed := false
		if raw_input is PlayerInput:
			interact_pressed = (raw_input as PlayerInput).interact
		elif raw_input is Dictionary:
			interact_pressed = bool((raw_input as Dictionary).get("interact", false))

		if not interact_pressed:
			continue

		var current_occupant := int(state.stations.get(StationConfig.HELM_STATION_ID, 0))
		if current_occupant == pid:
			# Release helm
			state.stations[StationConfig.HELM_STATION_ID] = 0
		elif current_occupant == 0:
			# Check if player is close enough to claim helm
			if state.players.has(pid):
				var player: PlayerState = state.players[pid]
				var dx := player.local_position.x - StationConfig.HELM_LOCAL_POS.x
				var dz := player.local_position.z - StationConfig.HELM_LOCAL_POS.z
				var dist := sqrt(dx * dx + dz * dz)
				if dist <= StationConfig.HELM_RADIUS:
					state.stations[StationConfig.HELM_STATION_ID] = pid
					player.local_position = StationConfig.HELM_LOCAL_POS

	# Ensure occupant stays snapped to helm
	var helm_occupant := int(state.stations.get(StationConfig.HELM_STATION_ID, 0))
	if helm_occupant != 0 and state.players.has(helm_occupant):
		var occupant: PlayerState = state.players[helm_occupant]
		occupant.local_position = StationConfig.HELM_LOCAL_POS


func apply_helm_input_to_boat(state: GameState, inputs: Dictionary, delta: float = FIXED_DELTA) -> void:
	var helm_occupant := int(state.stations.get(StationConfig.HELM_STATION_ID, 0))
	if helm_occupant != 0 and inputs.has(helm_occupant):
		var raw_input = inputs[helm_occupant]
		var throttle_in := 0.0
		var steering_in := 0.0
		if raw_input is PlayerInput:
			throttle_in = (raw_input as PlayerInput).throttle
			steering_in = (raw_input as PlayerInput).steering
		elif raw_input is Dictionary:
			throttle_in = float((raw_input as Dictionary).get("throttle", 0.0))
			steering_in = float((raw_input as Dictionary).get("steering", 0.0))

		if absf(throttle_in) > 0.01:
			state.boat.throttle = clampf(state.boat.throttle + throttle_in * LEVER_ADJUST_SPEED * delta, -1.0, 1.0)
		if absf(steering_in) > 0.01:
			var max_angle: float = deg_to_rad(35.0)
			state.boat.steering_angle = clampf(state.boat.steering_angle + steering_in * STEERING_ADJUST_SPEED * delta, -max_angle, max_angle)

	_update_active_input(state)


func get_active_boat_input(state: GameState) -> PlayerInput:
	_update_active_input(state)
	return _active_input


func _update_active_input(state: GameState) -> void:
	_active_input.throttle = state.boat.throttle
	var max_angle: float = deg_to_rad(35.0)
	if max_angle > 0.0001:
		_active_input.steering = state.boat.steering_angle / max_angle
	else:
		_active_input.steering = 0.0
