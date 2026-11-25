class_name BoatView
extends Node3D

var players_container: Node3D
var holders_container: Node3D
var holder_rods_container: Node3D
var deck_items_container: Node3D
var _player_views: Dictionary = {}
var _holder_meta: Dictionary = {}
var _holder_rod_views: Dictionary = {}
var _deck_item_views: Dictionary = {}
var _configured_layout_sig: String = ""
var _holder_socket_mesh: CylinderMesh
var _rod_shaft_mesh: CylinderMesh
var _rod_tip_meshes: Array[CylinderMesh] = []
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

	# Left & Right Stern Transom Rails flanking the outboard motor
	add_child(_make_box(Vector3(1.25, 0.4, 0.2), Vector3(-0.975, 0.45, 3.5), hull_mat))
	add_child(_make_box(Vector3(1.25, 0.4, 0.2), Vector3(0.975, 0.45, 3.5), hull_mat))

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

	holders_container = Node3D.new()
	holders_container.name = "HoldersContainer"
	add_child(holders_container)

	holder_rods_container = Node3D.new()
	holder_rods_container.name = "HolderRodsContainer"
	add_child(holder_rods_container)

	deck_items_container = Node3D.new()
	deck_items_container.name = "DeckItemsContainer"
	add_child(deck_items_container)

	players_container = Node3D.new()
	players_container.name = "PlayersContainer"
	add_child(players_container)

	_init_holder_resources()
	configure_holders(ItemConfig.new())


func _init_holder_resources() -> void:
	var holder_mat := StandardMaterial3D.new()
	holder_mat.albedo_color = Color(0.24, 0.26, 0.30)
	_holder_socket_mesh = CylinderMesh.new()
	_holder_socket_mesh.top_radius = 0.055
	_holder_socket_mesh.bottom_radius = 0.065
	_holder_socket_mesh.height = 0.30
	_holder_socket_mesh.radial_segments = 8
	_holder_socket_mesh.rings = 1
	_holder_socket_mesh.material = holder_mat

	var shaft_mat := StandardMaterial3D.new()
	shaft_mat.albedo_color = Color(0.16, 0.17, 0.20)
	_rod_shaft_mesh = CylinderMesh.new()
	_rod_shaft_mesh.top_radius = 0.015
	_rod_shaft_mesh.bottom_radius = 0.025
	_rod_shaft_mesh.height = 1.6
	_rod_shaft_mesh.radial_segments = 6
	_rod_shaft_mesh.rings = 1
	_rod_shaft_mesh.material = shaft_mat

	for accent_color in PlayerView.ROD_ACCENT_PALETTE:
		var tip_mat := StandardMaterial3D.new()
		tip_mat.albedo_color = accent_color
		var tip_mesh := CylinderMesh.new()
		tip_mesh.top_radius = 0.018
		tip_mesh.bottom_radius = 0.022
		tip_mesh.height = 0.28
		tip_mesh.radial_segments = 6
		tip_mesh.rings = 1
		tip_mesh.material = tip_mat
		_rod_tip_meshes.append(tip_mesh)


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


func configure_holders(item_config: ItemConfig) -> void:
	if item_config == null:
		return
	var sig := item_config.get_layout_signature()
	if sig == _configured_layout_sig:
		return
	_configured_layout_sig = sig
	_holder_meta.clear()
	_holder_rod_views.clear()
	_free_children_safe(holder_rods_container)
	_free_children_safe(holders_container)

	for holder in item_config.holders:
		var hid := str(holder.get("id", ""))
		if hid.is_empty():
			continue
		var pos: Vector3 = holder.get("local_position", Vector3.ZERO)
		var side := int(holder.get("side", 1))
		var tilt_deg: Vector3 = holder.get("tilt_degrees", Vector3(14.0, 0.0, -float(side) * 38.0))
		var socket := MeshInstance3D.new()
		socket.name = "Holder_%s" % hid
		socket.mesh = _holder_socket_mesh
		socket.position = pos
		socket.rotation_degrees = tilt_deg
		holders_container.add_child(socket)
		_holder_meta[hid] = {
			"local_position": pos,
			"side": side,
			"rotation_degrees": tilt_deg,
		}


func apply_items(items: Dictionary, item_config: ItemConfig = null, fishes: Dictionary = {}) -> void:
	if item_config != null:
		configure_holders(item_config)

	var active_resting: Dictionary = {}
	var active_deck: Dictionary = {}
	for iid in items:
		var item: HeldItem = items[iid]
		if item == null:
			continue
		if not item.is_carried() and _holder_meta.has(item.holder_id):
			active_resting[str(iid)] = item
		elif item.is_on_deck():
			active_deck[str(iid)] = item

	for existing_iid in _holder_rod_views.keys():
		if not active_resting.has(existing_iid):
			var stale_rod: Node3D = _holder_rod_views[existing_iid]
			_holder_rod_views.erase(existing_iid)
			_free_node_safe(stale_rod)

	for iid in active_resting:
		var item: HeldItem = active_resting[iid]
		var meta: Dictionary = _holder_meta[item.holder_id]
		var rod_node: Node3D
		if _holder_rod_views.has(iid):
			rod_node = _holder_rod_views[iid] as Node3D
		else:
			rod_node = _create_resting_rod_node(iid)
			holder_rods_container.add_child(rod_node)
			_holder_rod_views[iid] = rod_node

		rod_node.position = meta["local_position"]
		var base_rot: Vector3 = meta["rotation_degrees"]
		var fish := fishes.get(iid, null) as FishState
		if fish != null:
			var side_sign := -float(int(meta.get("side", 1)))
			var big := bool(FishSimulator.get_strike_reaction_profile(fish.size_class).get("trips_planer", false))
			var bend_amp := 16.0 if big else 6.0
			var osc := sin(fish.fight_phase * (2.2 if big else 3.0))
			var drag_kick := 6.0 if fish.is_drag_active() else 0.0
			rod_node.rotation_degrees = base_rot + Vector3(
				(bend_amp * 0.55 + drag_kick) + osc * (bend_amp * 0.45),
				0.0,
				side_sign * (bend_amp * 0.4 + osc * bend_amp * 0.35)
			)
		else:
			rod_node.rotation_degrees = base_rot
		var tip := rod_node.get_node_or_null("Tip") as MeshInstance3D
		if tip != null and not _rod_tip_meshes.is_empty():
			tip.mesh = _rod_tip_meshes[posmod(item.color_index, _rod_tip_meshes.size())]

	for existing_did in _deck_item_views.keys():
		if not active_deck.has(existing_did):
			var stale_deck: Node3D = _deck_item_views[existing_did]
			_deck_item_views.erase(existing_did)
			_free_node_safe(stale_deck)

	for iid in active_deck:
		var deck_item: HeldItem = active_deck[iid]
		var deck_node: Node3D
		if _deck_item_views.has(iid):
			deck_node = _deck_item_views[iid] as Node3D
		else:
			deck_node = _create_deck_item_node(iid, deck_item.item_type)
			deck_items_container.add_child(deck_node)
			_deck_item_views[iid] = deck_node
		deck_node.position = deck_item.deck_position + Vector3(0.0, 0.04, 0.0)
		deck_node.rotation_degrees = Vector3(90.0, 20.0, 0.0)


func get_visible_resting_rod_count() -> int:
	var count := 0
	for child in holder_rods_container.get_children():
		if child is Node3D and (child as Node3D).visible:
			count += 1
	return count


func get_visible_deck_item_count() -> int:
	if deck_items_container == null:
		return 0
	var count := 0
	for child in deck_items_container.get_children():
		if child is Node3D and (child as Node3D).visible:
			count += 1
	return count


func _create_deck_item_node(item_id: String, item_type: String) -> Node3D:
	var root := Node3D.new()
	root.name = "DeckItem_%s" % item_id
	if item_type == ItemConfig.ITEM_TYPE_NET:
		var net_vis := PlayerView.create_landing_net_visual()
		net_vis.position = Vector3(0.0, -0.55, 0.0)
		root.add_child(net_vis)
	else:
		root.add_child(_create_resting_rod_node(item_id))
	return root


func _create_resting_rod_node(item_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "RestingRod_%s" % item_id

	var shaft := MeshInstance3D.new()
	shaft.name = "Shaft"
	shaft.mesh = _rod_shaft_mesh
	shaft.position = Vector3(0.0, 0.80, 0.0)
	root.add_child(shaft)

	var tip := MeshInstance3D.new()
	tip.name = "Tip"
	tip.mesh = _rod_tip_meshes[0] if not _rod_tip_meshes.is_empty() else null
	tip.position = Vector3(0.0, 1.55, 0.0)
	root.add_child(tip)
	return root


func _clear_meshes_recursive(node: Node) -> void:
	for child in node.get_children():
		_clear_meshes_recursive(child)
	if node is MeshInstance3D:
		(node as MeshInstance3D).mesh = null


func _free_node_safe(node: Node) -> void:
	if node == null:
		return
	var was_in_tree := node.is_inside_tree()
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	if was_in_tree:
		node.queue_free()
	else:
		_clear_meshes_recursive(node)
		node.free()


func _free_children_safe(parent: Node) -> void:
	if parent == null:
		return
	for child in parent.get_children():
		_free_node_safe(child)


func apply_players(players: Dictionary, items: Dictionary = {}, fishes: Dictionary = {}) -> void:
	for pid in _player_views.keys():
		if not players.has(pid):
			var stale_view: PlayerView = _player_views[pid]
			_player_views.erase(pid)
			_free_node_safe(stale_view)

	var carried_by_peer: Dictionary = {}
	for iid in items:
		var item: HeldItem = items[iid]
		if item != null and item.is_carried():
			carried_by_peer[item.carrier_peer_id] = item

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
		var carried := carried_by_peer.get(int(pid), null) as HeldItem
		var carried_fish := fishes.get(carried.id, null) as FishState if carried != null else null
		view.apply_held_item(carried, carried_fish)


func get_player_view(peer_id: int) -> PlayerView:
	return _player_views.get(peer_id, null) as PlayerView
