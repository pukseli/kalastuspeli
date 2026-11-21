class_name BoatView
extends Node3D


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
	rotation.y = boat.heading
