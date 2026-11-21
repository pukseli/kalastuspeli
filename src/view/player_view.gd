class_name PlayerView
extends Node3D

const PALETTE: Array[Color] = [
	Color(0.92, 0.30, 0.25),
	Color(0.25, 0.72, 0.90),
	Color(0.35, 0.82, 0.38),
	Color(0.95, 0.78, 0.22),
]

var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D
var _color_index: int = -1


func _init() -> void:
	_material = StandardMaterial3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.32
	capsule.height = 1.2
	capsule.radial_segments = 8
	capsule.rings = 4
	capsule.material = _material

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = capsule
	_mesh_instance.position = Vector3(0.0, capsule.height * 0.5, 0.0)
	add_child(_mesh_instance)
	set_color_index(0)


func set_color_index(index: int) -> void:
	var normalized := posmod(index, PALETTE.size())
	if normalized == _color_index:
		return
	_color_index = normalized
	_material.albedo_color = PALETTE[normalized]


func apply_state(player: PlayerState) -> void:
	position = player.local_position
	set_color_index(player.color_index)
