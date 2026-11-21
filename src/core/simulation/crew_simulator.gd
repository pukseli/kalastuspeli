class_name CrewSimulator
extends RefCounted

const FIXED_DELTA: float = 1.0 / 60.0
const PLAYER_SPEED: float = 4.0
const PLAYER_RADIUS: float = 0.35
const DECK_MIN_X: float = -1.3
const DECK_MAX_X: float = 1.3
const DECK_MIN_Z: float = -2.1
const DECK_MAX_Z: float = 3.0
const DECK_SURFACE_Y: float = 0.25
const MAX_BOTS: int = 3

const BOT_SPAWNS: Array[Vector3] = [
	Vector3(-0.8, DECK_SURFACE_Y, -0.8),
	Vector3(0.8, DECK_SURFACE_Y, -0.8),
	Vector3(0.0, DECK_SURFACE_Y, 1.5),
]


func sync_bots(state: GameState, bot_count: int) -> void:
	var target := clampi(bot_count, 0, MAX_BOTS)
	for idx in range(1, MAX_BOTS + 1):
		var bot_id := -idx
		if idx <= target:
			var existed := state.players.has(bot_id)
			var bot := state.ensure_player(bot_id, true)
			bot.is_bot = true
			bot.color_index = idx % 4
			if not existed:
				bot.local_position = BOT_SPAWNS[idx - 1]
		else:
			state.remove_player(bot_id)


func step(state: GameState, inputs: Dictionary, delta: float = FIXED_DELTA) -> void:
	var ids: Array[int] = []
	for key in state.players.keys():
		ids.append(int(key))
	ids.sort()

	for pid in ids:
		var player: PlayerState = state.players[pid]
		if not player.is_bot and inputs.has(pid):
			var move := _extract_move_vector(inputs[pid])
			if move.length() > 1.0:
				move = move.normalized()
			player.local_position.x += move.x * PLAYER_SPEED * delta
			player.local_position.z += move.y * PLAYER_SPEED * delta
		_clamp_to_deck(player)

	var min_dist := PLAYER_RADIUS * 2.0
	var min_dist_sq := min_dist * min_dist
	for i in range(ids.size()):
		var pa: PlayerState = state.players[ids[i]]
		for j in range(i + 1, ids.size()):
			var pb: PlayerState = state.players[ids[j]]
			var dx := pb.local_position.x - pa.local_position.x
			var dz := pb.local_position.z - pa.local_position.z
			var dist_sq := dx * dx + dz * dz
			if dist_sq < min_dist_sq:
				var dir_x := 1.0
				var dir_z := 0.0
				var dist := sqrt(dist_sq)
				if dist > 0.0001:
					dir_x = dx / dist
					dir_z = dz / dist
				var push := (min_dist - dist) * 0.5
				pa.local_position.x -= dir_x * push
				pa.local_position.z -= dir_z * push
				pb.local_position.x += dir_x * push
				pb.local_position.z += dir_z * push

	for pid in ids:
		_clamp_to_deck(state.players[pid] as PlayerState)


func _extract_move_vector(raw_input: Variant) -> Vector2:
	if raw_input is PlayerInput:
		var pi := raw_input as PlayerInput
		return Vector2(pi.move_x, pi.move_z)
	if raw_input is Dictionary:
		var d := raw_input as Dictionary
		return Vector2(float(d.get("move_x", 0.0)), float(d.get("move_z", 0.0)))
	return Vector2.ZERO


func _clamp_to_deck(player: PlayerState) -> void:
	player.local_position.x = clampf(player.local_position.x, DECK_MIN_X, DECK_MAX_X)
	player.local_position.y = DECK_SURFACE_Y
	player.local_position.z = clampf(player.local_position.z, DECK_MIN_Z, DECK_MAX_Z)
