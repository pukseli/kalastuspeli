class_name BoatView
extends Node3D

var players_container: Node3D
var _player_views: Dictionary = {}
var _current_pitch: float = 0.0
var _current_roll: float = 0.0


func _init() -> void:
	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = Color(0.55, 0.36, 0.20)

	var bow_mat := StandardMaterial3D.new()
	bow_mat.albedo_color = Color(0.70, 0.50, 0.30)

	var motor_mat := StandardMaterial3D.new()
	motor_mat.albedo_color = Color(0.2, 0.22, 0.25)

	# Deck / Hull
	add_child(_make_box(Vector3(3.6, 0.5, 7.2), Vector3.ZERO, hull_mat))

	# Left & Right Gunwales / Rails
	add_child(_make_box(Vector3(0.2, 0.4, 7.2), Vector3(-1.7, 0.45, 0.0), hull_mat))
	add_child(_make_box(Vector3(0.2, 0.4, 7.2), Vector3(1.7, 0.45, 0.0), hull_mat))

	# Bow / Front Marker (-Z forward)
	add_child(_make_box(Vector3(1.6, 0.35, 1.2), Vector3(0.0, 0.4, -3.0), bow_mat))

	# Outboard Motor Box at stern (+Z)
	add_child(_make_box(Vector3(0.7, 0.8, 0.7), Vector3(0.0, 0.4, 3.7), motor_mat))

	# Steering Console (Helm) in front of helm position
	var helm_pos := StationConfig.HELM_LOCAL_POS
	var console_mat := StandardMaterial3D.new()
	console_mat.albedo_color = Color(0.3, 0.32, 0.35)
	add_child(_make_box(Vector3(0.8, 0.5, 0.35), helm_pos + Vector3(0.0, 0.20, -0.58), console_mat))

	# Steering wheel / dash
	var wheel_mat := StandardMaterial3D.new()
	wheel_mat.albedo_color = Color(0.15, 0.15, 0.15)
	add_child(_make_box(Vector3(0.3, 0.3, 0.06), helm_pos + Vector3(0.0, 0.47, -0.38), wheel_mat))

	# Low windshield with alpha transparency
	var glass_mat := StandardMaterial3D.new()
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.albedo_color = Color(0.5, 0.8, 0.95, 0.3)
	glass_mat.roughness = 0.1
	add_child(_make_box(Vector3(0.78, 0.18, 0.03), helm_pos + Vector3(0.0, 0.50, -0.62), glass_mat))

	players_container = Node3D.new()
	players_container.name = "PlayersContainer"
	add_child(players_container)


func _make_box(box_size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	box.material = mat
	mesh_instance.mesh = box
	mesh_instance.position = pos
	return mesh_instance


func apply_state(boat: BoatState) -> void:
	position = boat.world_position
	var target_pitch := clampf(boat.throttle * 0.05 + boat.forward_speed * 0.004, -0.04, 0.08)
	var target_roll := clampf(boat.angular_velocity * boat.forward_speed * 0.02, -0.15, 0.15)
	_current_pitch = lerpf(_current_pitch, target_pitch, 0.1)
	_current_roll = lerpf(_current_roll, target_roll, 0.1)
	rotation = Vector3(_current_pitch, boat.heading, _current_roll)


func apply_players(players: Dictionary) -> void:
	for pid in _player_views.keys():
		if not players.has(pid):
			var stale_view: PlayerView = _player_views[pid]
			_player_views.erase(pid)
			var was_in_tree := stale_view.is_inside_tree()
			players_container.remove_child(stale_view)
			if was_in_tree:
				stale_view.queue_free()
			else:
				for child in stale_view.get_children():
					if child is MeshInstance3D:
						(child as MeshInstance3D).mesh = null
				stale_view.free()

	for pid in players:
		var player_state: PlayerState = players[pid]
		var view: PlayerView
		if _player_views.has(pid):
			view = _player_views[pid] as PlayerView
		else:
			view = PlayerView.new()
			view.name = "Player_%d" % int(pid)
			players_container.add_child(view)
			_player_views[pid] = view
		view.apply_state(player_state)
