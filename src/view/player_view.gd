class_name PlayerView
extends Node3D

const PALETTE: Array[Color] = [
	Color(0.92, 0.30, 0.25),
	Color(0.25, 0.72, 0.90),
	Color(0.35, 0.82, 0.38),
	Color(0.95, 0.78, 0.22),
]

const ROD_ACCENT_PALETTE: Array[Color] = [
	Color(0.95, 0.25, 0.22),
	Color(0.18, 0.72, 0.96),
	Color(0.32, 0.86, 0.36),
	Color(0.98, 0.80, 0.16),
	Color(0.92, 0.38, 0.86),
	Color(1.00, 0.52, 0.14),
]

var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D
var _color_index: int = -1
var _held_item_anchor: Node3D
var _held_tip_mat: StandardMaterial3D


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

	_held_item_anchor = Node3D.new()
	_held_item_anchor.name = "HeldItemAnchor"
	_held_item_anchor.visible = false
	_held_item_anchor.position = Vector3(0.30, 0.78, 0.12)
	_held_item_anchor.rotation_degrees = Vector3(-42.0, 0.0, -10.0)
	add_child(_held_item_anchor)

	var shaft_mat := StandardMaterial3D.new()
	shaft_mat.albedo_color = Color(0.16, 0.17, 0.20)
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.015
	shaft_mesh.bottom_radius = 0.025
	shaft_mesh.height = 1.35
	shaft_mesh.radial_segments = 6
	shaft_mesh.rings = 1
	shaft_mesh.material = shaft_mat
	var shaft_node := MeshInstance3D.new()
	shaft_node.mesh = shaft_mesh
	shaft_node.position = Vector3(0.0, 0.55, 0.0)
	_held_item_anchor.add_child(shaft_node)

	_held_tip_mat = StandardMaterial3D.new()
	_held_tip_mat.albedo_color = ROD_ACCENT_PALETTE[0]
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.018
	tip_mesh.bottom_radius = 0.022
	tip_mesh.height = 0.24
	tip_mesh.radial_segments = 6
	tip_mesh.rings = 1
	tip_mesh.material = _held_tip_mat
	var tip_node := MeshInstance3D.new()
	tip_node.mesh = tip_mesh
	tip_node.position = Vector3(0.0, 1.15, 0.0)
	_held_item_anchor.add_child(tip_node)

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


func apply_held_item(item: HeldItem) -> void:
	if item == null:
		_held_item_anchor.visible = false
		return
	_held_item_anchor.visible = true
	var idx := posmod(item.color_index, ROD_ACCENT_PALETTE.size())
	_held_tip_mat.albedo_color = ROD_ACCENT_PALETTE[idx]


func has_visible_held_item() -> bool:
	return _held_item_anchor != null and _held_item_anchor.visible
