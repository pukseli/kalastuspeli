class_name WorldView
extends Node3D

const CAMERA_OFFSET := Vector3(0.0, 7.0, 12.0)
const CAMERA_PITCH_DEG: float = -28.0
const WATER_Y: float = -0.25

var boat_view: BoatView
var camera: Camera3D
var hud_label: Label
var prompt_label: Label
var line_prompt_label: Label
var trolling_lines_container: Node3D
var trolling_lines_mesh_instance: MeshInstance3D
var planers_container: Node3D
var lures_container: Node3D
var net_status_text: String = "Net: OFFLINE | Peers: 0 | Sync: 20 Hz | Bots: 0"
var debug_hud_enabled: bool = true
var camera_controller: CameraController = CameraController.new()

var _lines_mesh: ImmediateMesh
var _line_mat: StandardMaterial3D
var _planer_body_mesh: BoxMesh
var _planer_flag_mesh: CylinderMesh
var _planer_body_mats: Dictionary = {}
var _flag_mats: Dictionary = {}
var _lure_meshes: Array[SphereMesh] = []
var _planer_views: Dictionary = {}
var _lure_views: Dictionary = {}
var _rod_simulator_helper: RodSimulator = RodSimulator.new()


func _init() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	sun.shadow_enabled = false
	add_child(sun)

	var water_mesh := MeshInstance3D.new()
	var water_plane := PlaneMesh.new()
	water_plane.size = Vector2(300.0, 300.0)
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.12, 0.38, 0.52)
	water_plane.material = water_mat
	water_mesh.mesh = water_plane
	water_mesh.position = Vector3(0.0, -0.25, 0.0)
	add_child(water_mesh)

	var buoy_mat := StandardMaterial3D.new()
	buoy_mat.albedo_color = Color(0.9, 0.35, 0.15)
	var buoy_cylinder := CylinderMesh.new()
	buoy_cylinder.top_radius = 0.4
	buoy_cylinder.bottom_radius = 0.4
	buoy_cylinder.height = 1.2
	buoy_cylinder.radial_segments = 12
	buoy_cylinder.rings = 1
	buoy_cylinder.material = buoy_mat

	var buoy_radius := 20.0
	for i in range(8):
		var angle := (TAU / 8.0) * float(i)
		var buoy := MeshInstance3D.new()
		buoy.mesh = buoy_cylinder
		buoy.position = Vector3(cos(angle) * buoy_radius, 0.3, sin(angle) * buoy_radius)
		add_child(buoy)

	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.76, 0.79, 0.83)
	var pillar_cylinder := CylinderMesh.new()
	pillar_cylinder.top_radius = 1.6
	pillar_cylinder.bottom_radius = 2.0
	pillar_cylinder.height = 10.0
	pillar_cylinder.radial_segments = 8
	pillar_cylinder.rings = 1
	pillar_cylinder.material = pillar_mat

	var outer_pillar_count := 8
	var outer_pillar_radius := 110.0
	var outer_angle_offset := TAU / float(outer_pillar_count * 2)
	for i in range(outer_pillar_count):
		var angle := (TAU / float(outer_pillar_count)) * float(i) + outer_angle_offset
		var pillar := MeshInstance3D.new()
		pillar.mesh = pillar_cylinder
		pillar.position = Vector3(cos(angle) * outer_pillar_radius, 4.75, sin(angle) * outer_pillar_radius)
		add_child(pillar)

	boat_view = BoatView.new()
	add_child(boat_view)

	trolling_lines_container = Node3D.new()
	trolling_lines_container.name = "TrollingLinesContainer"
	add_child(trolling_lines_container)

	_init_trolling_resources()

	trolling_lines_mesh_instance = MeshInstance3D.new()
	trolling_lines_mesh_instance.name = "TrollingLinesMesh"
	_lines_mesh = ImmediateMesh.new()
	trolling_lines_mesh_instance.mesh = _lines_mesh
	trolling_lines_container.add_child(trolling_lines_mesh_instance)

	planers_container = Node3D.new()
	planers_container.name = "PlanersContainer"
	trolling_lines_container.add_child(planers_container)

	lures_container = Node3D.new()
	lures_container.name = "LuresContainer"
	trolling_lines_container.add_child(lures_container)

	camera = Camera3D.new()
	var init_cam_xform := camera_controller.compute_camera_transform(Vector3.ZERO, 0.0)
	camera.position = init_cam_xform["position"]
	camera.rotation = init_cam_xform["rotation"]
	add_child(camera)

	hud_label = Label.new()
	hud_label.position = Vector2(12.0, 12.0)
	add_child(hud_label)

	prompt_label = Label.new()
	prompt_label.position = Vector2(12.0, 480.0)
	add_child(prompt_label)

	line_prompt_label = Label.new()
	line_prompt_label.position = Vector2(12.0, 504.0)
	add_child(line_prompt_label)


func _init_trolling_resources() -> void:
	_line_mat = StandardMaterial3D.new()
	_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_mat.albedo_color = Color(0.92, 0.96, 1.0)

	_planer_body_mesh = BoxMesh.new()
	_planer_body_mesh.size = Vector3(0.28, 0.12, 0.55)

	_planer_flag_mesh = CylinderMesh.new()
	_planer_flag_mesh.top_radius = 0.02
	_planer_flag_mesh.bottom_radius = 0.02
	_planer_flag_mesh.height = 0.34
	_planer_flag_mesh.radial_segments = 6
	_planer_flag_mesh.rings = 1

	var mat_normal := StandardMaterial3D.new()
	mat_normal.albedo_color = Color(1.0, 0.50, 0.10)
	_planer_body_mats["normal"] = mat_normal

	var mat_tangled := StandardMaterial3D.new()
	mat_tangled.albedo_color = Color(0.75, 0.25, 0.90)
	_planer_body_mats["tangled"] = mat_tangled

	var mat_snagged := StandardMaterial3D.new()
	mat_snagged.albedo_color = Color(0.95, 0.18, 0.18)
	_planer_body_mats["snagged"] = mat_snagged

	var flag_normal := StandardMaterial3D.new()
	flag_normal.albedo_color = Color(1.0, 0.90, 0.15)
	_flag_mats["normal"] = flag_normal

	var flag_tripped := StandardMaterial3D.new()
	flag_tripped.albedo_color = Color(0.98, 0.18, 0.18)
	_flag_mats["tripped"] = flag_tripped

	for accent_color in PlayerView.ROD_ACCENT_PALETTE:
		var lure_mat := StandardMaterial3D.new()
		lure_mat.albedo_color = accent_color
		var lure_mesh := SphereMesh.new()
		lure_mesh.radius = 0.14
		lure_mesh.height = 0.24
		lure_mesh.radial_segments = 8
		lure_mesh.rings = 4
		lure_mesh.material = lure_mat
		_lure_meshes.append(lure_mesh)


func configure_holders(item_config: ItemConfig) -> void:
	boat_view.configure_holders(item_config)


func apply_state(boat: BoatState, net_info: String = "") -> void:
	if not net_info.is_empty():
		net_status_text = net_info
	boat_view.apply_state(boat)
	_update_camera_and_hud(boat, "", false, false, "—")


func apply_game_state(game_state: GameState, net_info: String = "", local_peer_id: int = 1, snap_camera: bool = false) -> void:
	if not net_info.is_empty():
		net_status_text = net_info
	boat_view.apply_state(game_state.boat)
	boat_view.apply_items(game_state.items, game_state.item_config)
	boat_view.apply_players(game_state.players, game_state.items)
	_apply_trolling_rods(game_state)

	var active_station := game_state.get_player_station(local_peer_id) if local_peer_id != 0 else ""
	var is_in_helm := (active_station == StationConfig.HELM_STATION_ID)
	var held_item := game_state.get_player_held_item(local_peer_id) if local_peer_id != 0 else null
	var held_label := _format_held_item_label(held_item)
	var prompt := ""
	var line_prompt := ""
	var best_hid := ""
	var best_holder: Dictionary = {}

	if not active_station.is_empty():
		var cfg := StationConfig.get_station_config(active_station)
		prompt = str(cfg.get("prompt_leave", "[E] Irrota ote"))
	elif local_peer_id != 0 and game_state.players.has(local_peer_id):
		var lp: PlayerState = game_state.players[local_peer_id]
		var best_sid := ""
		var best_station_dist := INF
		for sid_raw in game_state.stations.keys():
			var sid := str(sid_raw)
			var station_pos := StationConfig.get_station_position(sid)
			var radius := StationConfig.get_station_radius(sid)
			var dx := lp.local_position.x - station_pos.x
			var dz := lp.local_position.z - station_pos.z
			var dist := sqrt(dx * dx + dz * dz)
			if dist <= radius and (dist < best_station_dist or (is_equal_approx(dist, best_station_dist) and sid < best_sid)):
				best_station_dist = dist
				best_sid = sid

		var best_holder_dist := INF
		if game_state.item_config != null:
			for holder in game_state.item_config.holders:
				var hid := str(holder.get("id", ""))
				if hid.is_empty():
					continue
				var pos: Vector3 = holder.get("local_position", Vector3.ZERO)
				var radius := float(holder.get("radius", ItemConfig.DEFAULT_HOLDER_RADIUS))
				var dx := lp.local_position.x - pos.x
				var dz := lp.local_position.z - pos.z
				var dist := sqrt(dx * dx + dz * dz)
				if dist <= radius and dist < best_holder_dist:
					best_holder_dist = dist
					best_hid = hid
					best_holder = holder

		if not best_sid.is_empty() and (best_hid.is_empty() or best_station_dist <= best_holder_dist):
			var cfg := StationConfig.get_station_config(best_sid)
			var occupant := int(game_state.stations.get(best_sid, 0))
			if occupant != 0:
				prompt = str(cfg.get("prompt_occupied", "[Varattu]"))
			elif held_item != null:
				prompt = "[Laske vapa ensin]" if held_item.item_type == ItemConfig.ITEM_TYPE_ROD else "[Kädet täynnä]"
			else:
				prompt = str(cfg.get("prompt_enter", "[E] Tartu"))
		elif not best_hid.is_empty():
			var label := str(best_holder.get("label", best_hid))
			var holder_item := game_state.get_holder_item(best_hid)
			if held_item == null:
				if holder_item != null:
					prompt = "[E] Poimi vapa (%s)" % label
				else:
					prompt = "[Tyhjä teline (%s)]" % label
			else:
				if not game_state.item_config.is_type_allowed(best_hid, held_item.item_type):
					prompt = "[Väärä teline (%s)]" % label
				elif holder_item == null:
					prompt = "[E] Aseta vapa (%s)" % label
				else:
					prompt = "[E] Vaihda vapa (%s)" % label

		var active_rod_item: HeldItem = null
		if held_item != null and held_item.item_type == ItemConfig.ITEM_TYPE_ROD:
			active_rod_item = held_item
		elif not best_hid.is_empty():
			var nearby_item := game_state.get_holder_item(best_hid)
			if nearby_item != null and nearby_item.item_type == ItemConfig.ITEM_TYPE_ROD:
				active_rod_item = nearby_item

		if active_rod_item != null:
			var active_rod := game_state.get_rod_state(active_rod_item.id)
			if active_rod != null:
				var rod_name := _format_held_item_label(active_rod_item)
				var planer_tag := " (Plaanari)" if active_rod.planer.attached else ""
				line_prompt = "[Q/Shift] Laske | [Space] Kelaa | %s%s: %.1f m [%s]" % [
					rod_name,
					planer_tag,
					active_rod.planer.line_out,
					active_rod.planer.state,
				]

	_update_camera_and_hud(
		game_state.boat,
		prompt,
		is_in_helm,
		snap_camera,
		held_label,
		line_prompt,
		game_state.get_deployed_rod_count(),
		game_state.rods.size()
	)


func _format_held_item_label(item: HeldItem) -> String:
	if item == null:
		return "—"
	if item.item_type == ItemConfig.ITEM_TYPE_ROD:
		if item.id.begins_with("rod_"):
			return "Vapa #%s" % item.id.substr(4)
		return "Vapa"
	return item.id if not item.id.is_empty() else item.item_type


func _update_camera_and_hud(
	boat: BoatState,
	prompt: String,
	in_helm: bool,
	snap_camera: bool = false,
	held_label: String = "—",
	line_prompt: String = "",
	deployed_rods: int = 0,
	total_rods: int = 0
) -> void:
	camera_controller.set_mode(in_helm, snap_camera)
	camera_controller.step(snap_camera)
	var cam_xform := camera_controller.compute_camera_transform(boat.world_position, boat.heading)
	camera.position = cam_xform["position"]
	camera.rotation = cam_xform["rotation"]

	var control_mode := camera_controller.get_control_mode_hud_text(in_helm, held_label)
	var lines_hud := "Vedessä: %d/%d" % [deployed_rods, total_rods]
	if debug_hud_enabled:
		var fps := Engine.get_frames_per_second()
		var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		hud_label.text = "[TEST] FPS: %d | Draw Calls: %d | Tris: %d\nNopeus: %.2f m/s | Kaasu: %.0f%% | Ruori: %.0f° | %s\n%s\nTila: %s\nB: Botit | T: Sync Hz | L: Viive | I: Interp" % [
			fps,
			draw_calls,
			primitives,
			boat.forward_speed,
			boat.throttle * 100.0,
			rad_to_deg(boat.steering_angle),
			lines_hud,
			net_status_text,
			control_mode,
		]
	else:
		hud_label.text = "Nopeus: %.2f m/s | Kaasu: %.0f%% | Ruori: %.0f° | %s\n%s\nTila: %s" % [
			boat.forward_speed,
			boat.throttle * 100.0,
			rad_to_deg(boat.steering_angle),
			lines_hud,
			net_status_text,
			control_mode,
		]

	prompt_label.text = prompt
	if line_prompt_label != null:
		line_prompt_label.text = line_prompt


func _apply_trolling_rods(game_state: GameState) -> void:
	_lines_mesh.clear_surfaces()
	var line_vertices: Array[Vector3] = []
	var active_planers: Dictionary = {}
	var active_lures: Dictionary = {}

	for rid in game_state.rods:
		var rod := game_state.rods[rid] as RodState
		var item := game_state.items.get(rid, null) as HeldItem
		if rod == null or item == null or not rod.is_deployed():
			continue

		var tip_world := _rod_simulator_helper.get_rod_tip_world(game_state, item)
		var lure_2d := _rod_simulator_helper.get_lure_world_pos_2d(game_state, item, rod)
		var lure_world := Vector3(lure_2d.x, WATER_Y + 0.02, lure_2d.y)
		active_lures[str(rid)] = {"pos": lure_world, "color_index": item.color_index}

		if rod.planer.attached:
			var board_2d := _rod_simulator_helper.get_board_world_pos_2d(game_state, item, rod)
			var board_world := Vector3(board_2d.x, WATER_Y + 0.04, board_2d.y)
			active_planers[str(rid)] = {"pos": board_world, "state": rod.planer.state}
			_append_curved_segment(line_vertices, tip_world, board_world, 3, 0.22)
			_append_curved_segment(line_vertices, board_world, lure_world, 2, 0.05)
		else:
			_append_curved_segment(line_vertices, tip_world, lure_world, 4, 0.30)

	if not line_vertices.is_empty():
		_lines_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _line_mat)
		for v in line_vertices:
			_lines_mesh.surface_add_vertex(v)
		_lines_mesh.surface_end()

	for existing_pid in _planer_views.keys():
		if not active_planers.has(existing_pid):
			var stale_planer: Node3D = _planer_views[existing_pid]
			_planer_views.erase(existing_pid)
			_free_node_safe(stale_planer)

	for rid in active_planers:
		var p_info: Dictionary = active_planers[rid]
		var p_node: Node3D
		if _planer_views.has(rid):
			p_node = _planer_views[rid] as Node3D
		else:
			p_node = _create_planer_node(rid)
			planers_container.add_child(p_node)
			_planer_views[rid] = p_node
		p_node.position = p_info["pos"]
		p_node.rotation = Vector3(0.0, game_state.boat.heading, 0.0)
		_update_planer_visual_state(p_node, str(p_info["state"]))

	for existing_lid in _lure_views.keys():
		if not active_lures.has(existing_lid):
			var stale_lure: Node3D = _lure_views[existing_lid]
			_lure_views.erase(existing_lid)
			_free_node_safe(stale_lure)

	for rid in active_lures:
		var l_info: Dictionary = active_lures[rid]
		var l_node: MeshInstance3D
		if _lure_views.has(rid):
			l_node = _lure_views[rid] as MeshInstance3D
		else:
			l_node = MeshInstance3D.new()
			l_node.name = "Lure_%s" % rid
			lures_container.add_child(l_node)
			_lure_views[rid] = l_node
		l_node.position = l_info["pos"]
		if not _lure_meshes.is_empty():
			l_node.mesh = _lure_meshes[posmod(int(l_info["color_index"]), _lure_meshes.size())]


func _append_curved_segment(out: Array[Vector3], start_pos: Vector3, end_pos: Vector3, segments: int, max_sag: float) -> void:
	var count := maxi(1, segments)
	var span := start_pos.distance_to(end_pos)
	var sag := minf(max_sag, span * 0.025)
	var prev := start_pos
	for i in range(1, count + 1):
		var frac := float(i) / float(count)
		var pt := start_pos.lerp(end_pos, frac)
		pt.y -= sin(frac * PI) * sag
		out.append(prev)
		out.append(pt)
		prev = pt


func _create_planer_node(rod_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Planer_%s" % rod_id

	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _planer_body_mesh
	body.material_override = _planer_body_mats["normal"]
	root.add_child(body)

	var flag_pivot := Node3D.new()
	flag_pivot.name = "FlagPivot"
	flag_pivot.position = Vector3(0.0, 0.08, -0.05)
	root.add_child(flag_pivot)

	var flag := MeshInstance3D.new()
	flag.name = "Flag"
	flag.mesh = _planer_flag_mesh
	flag.position = Vector3(0.0, 0.17, 0.0)
	flag.material_override = _flag_mats["normal"]
	flag_pivot.add_child(flag)
	return root


func _update_planer_visual_state(planer_node: Node3D, state_name: String) -> void:
	var body := planer_node.get_node_or_null("Body") as MeshInstance3D
	var flag_pivot := planer_node.get_node_or_null("FlagPivot") as Node3D
	var flag := planer_node.get_node_or_null("FlagPivot/Flag") as MeshInstance3D

	if body != null:
		if state_name == PlanerBoard.STATE_TANGLED:
			body.material_override = _planer_body_mats["tangled"]
		elif state_name == PlanerBoard.STATE_SNAGGED:
			body.material_override = _planer_body_mats["snagged"]
		else:
			body.material_override = _planer_body_mats["normal"]

	if flag_pivot != null and flag != null:
		if state_name == PlanerBoard.STATE_TRIPPED:
			flag_pivot.rotation_degrees = Vector3(-65.0, 0.0, 0.0)
			flag.material_override = _flag_mats["tripped"]
		elif state_name == PlanerBoard.STATE_TANGLED or state_name == PlanerBoard.STATE_SNAGGED:
			flag_pivot.rotation_degrees = Vector3(-30.0, 0.0, 0.0)
			flag.material_override = _flag_mats["tripped"]
		else:
			flag_pivot.rotation_degrees = Vector3.ZERO
			flag.material_override = _flag_mats["normal"]


func get_visible_lure_count() -> int:
	if lures_container == null:
		return 0
	var count := 0
	for child in lures_container.get_children():
		if child is Node3D and (child as Node3D).visible:
			count += 1
	return count


func get_visible_planer_count() -> int:
	if planers_container == null:
		return 0
	var count := 0
	for child in planers_container.get_children():
		if child is Node3D and (child as Node3D).visible:
			count += 1
	return count


func get_trolling_line_surface_count() -> int:
	if _lines_mesh == null:
		return 0
	return _lines_mesh.get_surface_count()


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
