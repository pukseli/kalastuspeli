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

const HELD_BASE_ROT_DEG := Vector3(-42.0, 0.0, -10.0)
const HELD_TIP_PIVOT_Y: float = 0.78
const HELD_TIP_FROM_PIVOT := Vector3(0.0, 0.445, 0.0)

var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D
var _color_index: int = -1
var _held_item_anchor: Node3D
var _rod_visual: Node3D
var _net_visual: Node3D
var _held_tip_mat: StandardMaterial3D
var _held_tip_pivot: Node3D
var _held_rod_bend_deg: float = 0.0


static func create_landing_net_visual() -> Node3D:
	var root := Node3D.new()
	root.name = "LandingNetVisual"

	var handle_mat := StandardMaterial3D.new()
	handle_mat.albedo_color = Color(0.52, 0.36, 0.20)
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.020
	handle_mesh.bottom_radius = 0.024
	handle_mesh.height = 0.95
	handle_mesh.radial_segments = 6
	handle_mesh.rings = 1
	handle_mesh.material = handle_mat
	var handle_node := MeshInstance3D.new()
	handle_node.name = "Handle"
	handle_node.mesh = handle_mesh
	handle_node.position = Vector3(0.0, 0.42, 0.0)
	root.add_child(handle_node)

	var hoop_mat := StandardMaterial3D.new()
	hoop_mat.albedo_color = Color(0.75, 0.78, 0.82)
	var hoop_mesh := TorusMesh.new()
	hoop_mesh.inner_radius = 0.20
	hoop_mesh.outer_radius = 0.24
	hoop_mesh.rings = 8
	hoop_mesh.ring_segments = 6
	hoop_mesh.material = hoop_mat
	var hoop_node := MeshInstance3D.new()
	hoop_node.name = "Hoop"
	hoop_node.mesh = hoop_mesh
	hoop_node.position = Vector3(0.0, 1.12, 0.0)
	hoop_node.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	root.add_child(hoop_node)

	var basket_mat := StandardMaterial3D.new()
	basket_mat.albedo_color = Color(0.18, 0.56, 0.44, 0.82)
	basket_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	basket_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var basket_mesh := CylinderMesh.new()
	basket_mesh.top_radius = 0.21
	basket_mesh.bottom_radius = 0.12
	basket_mesh.height = 0.24
	basket_mesh.radial_segments = 8
	basket_mesh.rings = 1
	basket_mesh.material = basket_mat
	var basket_node := MeshInstance3D.new()
	basket_node.name = "Basket"
	basket_node.mesh = basket_mesh
	basket_node.position = Vector3(0.0, 1.12, -0.12)
	basket_node.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	root.add_child(basket_node)

	return root


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
	_held_item_anchor.rotation_degrees = HELD_BASE_ROT_DEG
	add_child(_held_item_anchor)

	_rod_visual = Node3D.new()
	_rod_visual.name = "RodVisual"
	_held_item_anchor.add_child(_rod_visual)

	var shaft_mat := StandardMaterial3D.new()
	shaft_mat.albedo_color = Color(0.16, 0.17, 0.20)
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.015
	shaft_mesh.bottom_radius = 0.025
	shaft_mesh.height = 0.92
	shaft_mesh.radial_segments = 6
	shaft_mesh.rings = 1
	shaft_mesh.material = shaft_mat
	var shaft_node := MeshInstance3D.new()
	shaft_node.mesh = shaft_mesh
	shaft_node.position = Vector3(0.0, 0.34, 0.0)
	_rod_visual.add_child(shaft_node)

	_held_tip_pivot = Node3D.new()
	_held_tip_pivot.name = "TipPivot"
	_held_tip_pivot.position = Vector3(0.0, HELD_TIP_PIVOT_Y, 0.0)
	_rod_visual.add_child(_held_tip_pivot)

	_held_tip_mat = StandardMaterial3D.new()
	_held_tip_mat.albedo_color = ROD_ACCENT_PALETTE[0]
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.013
	tip_mesh.bottom_radius = 0.019
	tip_mesh.height = 0.46
	tip_mesh.radial_segments = 6
	tip_mesh.rings = 1
	tip_mesh.material = _held_tip_mat
	var tip_node := MeshInstance3D.new()
	tip_node.mesh = tip_mesh
	tip_node.position = Vector3(0.0, 0.215, 0.0)
	_held_tip_pivot.add_child(tip_node)

	_net_visual = create_landing_net_visual()
	_net_visual.visible = false
	_held_item_anchor.add_child(_net_visual)

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


func apply_held_item(item: HeldItem, fish: FishState = null, rod: RodState = null) -> void:
	if item == null:
		_held_item_anchor.visible = false
		_rod_visual.visible = false
		_net_visual.visible = false
		_held_item_anchor.rotation_degrees = HELD_BASE_ROT_DEG
		if _held_tip_pivot != null:
			_held_tip_pivot.rotation_degrees = Vector3.ZERO
		_held_rod_bend_deg = 0.0
		return
	_held_item_anchor.visible = true
	if item.item_type == ItemConfig.ITEM_TYPE_NET:
		_rod_visual.visible = false
		_net_visual.visible = true
		_held_item_anchor.rotation_degrees = HELD_BASE_ROT_DEG
		if _held_tip_pivot != null:
			_held_tip_pivot.rotation_degrees = Vector3.ZERO
		_held_rod_bend_deg = 0.0
		return
	_rod_visual.visible = true
	_net_visual.visible = false
	var idx := posmod(item.color_index, ROD_ACCENT_PALETTE.size())
	_held_tip_mat.albedo_color = ROD_ACCENT_PALETTE[idx]
	var tension_ratio := 0.0
	if rod != null and rod.is_deployed():
		tension_ratio = clampf(rod.line_tension / maxf(1.0, rod.get_effective_max_strength()), 0.0, 1.0)
	var bend_deg := tension_ratio * 34.0
	var osc_x := 0.0
	var osc_y := 0.0
	if fish != null:
		var big := bool(FishSimulator.get_strike_reaction_profile(fish.size_class).get("trips_planer", false))
		if tension_ratio < 0.02:
			var fallback_min := (14.0 if big else 5.0) + (6.0 if fish.is_drag_active() else 0.0)
			bend_deg = maxf(bend_deg, fallback_min)
		var osc := sin(fish.fight_phase * (2.2 if big else 3.0))
		osc_x = osc * (4.5 if big else 2.2)
		osc_y = osc * (3.5 if big else 1.5)
	elif rod != null and rod.is_drag_slipping:
		bend_deg += 4.0
	var total_bend := clampf(bend_deg, 0.0, 46.0)
	_held_rod_bend_deg = total_bend
	_held_item_anchor.rotation_degrees = HELD_BASE_ROT_DEG + Vector3(-total_bend * 0.42 + osc_x, osc_y, 0.0)
	if _held_tip_pivot != null:
		_held_tip_pivot.rotation_degrees = Vector3(-total_bend * 0.92 + osc_x * 0.6, 0.0, 0.0)


func has_visible_held_item() -> bool:
	return _held_item_anchor != null and _held_item_anchor.visible


func get_held_rod_bend_degrees() -> float:
	return _held_rod_bend_deg


func get_held_rod_tip_local_to_player() -> Vector3:
	if _held_item_anchor == null:
		return RodSimulator.HELD_TIP_LOCAL_OFFSET
	if _held_tip_pivot != null:
		return _held_item_anchor.transform * (_held_tip_pivot.transform * HELD_TIP_FROM_PIVOT)
	return _held_item_anchor.transform * RodSimulator.HELD_TIP_LOCAL_OFFSET
