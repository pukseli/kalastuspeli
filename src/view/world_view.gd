class_name WorldView
extends Node3D

const CAMERA_OFFSET := Vector3(0.0, 7.0, 12.0)
const CAMERA_PITCH_DEG: float = -28.0
const WATER_Y: float = -0.25
const LINE_HIGH_RATIO: float = 0.55
const LINE_CRITICAL_RATIO: float = 0.80
const METER_BAR_WIDTH: float = 252.0
const METER_BAR_HEIGHT: float = 16.0
const METER_SPOOL_HEIGHT: float = 6.0
const METER_DRAG_MARKER_WIDTH: float = 4.0

var boat_view: BoatView
var camera: Camera3D
var hud_label: Label
var catch_hud_label: Label
var fish_alert_label: Label
var prompt_label: Label
var line_prompt_label: Label
var tension_meter_root: Control
var tension_meter_title: Label
var tension_meter_footer: Label
var tension_bar_bg: ColorRect
var tension_danger_zone: ColorRect
var tension_bar_fill: ColorRect
var drag_marker: ColorRect
var spool_bar_bg: ColorRect
var spool_bar_fill: ColorRect
var trolling_lines_container: Node3D
var trolling_lines_mesh_instance: MeshInstance3D
var planers_container: Node3D
var lures_container: Node3D
var fishes_container: Node3D
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
var _fish_views: Dictionary = {}
var _fish_body_mesh: CapsuleMesh
var _fish_tail_mesh: BoxMesh
var _fish_dorsal_mesh: BoxMesh
var _fish_belly_mesh: BoxMesh
var _fish_mats: Dictionary = {}
var _orca_belly_mat: StandardMaterial3D
var _raikka_player: AudioStreamPlayer
var _raikka_cooldown: float = 0.0
var _rod_simulator_helper: RodSimulator = RodSimulator.new()
var _fish_simulator_helper: FishSimulator = FishSimulator.new()
var _tick_boat_pos: Vector3 = Vector3.ZERO
var _tick_boat_heading: float = 0.0
var material_assign_count: int = 0
var _planer_parts: Dictionary = {}
var _fish_parts: Dictionary = {}
var _fish_species_cache: Dictionary = {}
var _line_start_world: Dictionary = {}
var _line_points_by_rod: Dictionary = {}
var _line_color_by_rod: Dictionary = {}
var _line_vib_time: float = 0.0
var _last_in_helm: bool = false


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

	fishes_container = Node3D.new()
	fishes_container.name = "FishesContainer"
	trolling_lines_container.add_child(fishes_container)

	_init_raikka_audio()

	camera = Camera3D.new()
	var init_cam_xform := camera_controller.compute_camera_transform(Vector3.ZERO, 0.0)
	camera.position = init_cam_xform["position"]
	camera.rotation = init_cam_xform["rotation"]
	add_child(camera)

	hud_label = Label.new()
	hud_label.position = Vector2(12.0, 12.0)
	add_child(hud_label)

	catch_hud_label = Label.new()
	catch_hud_label.position = Vector2(12.0, 432.0)
	catch_hud_label.text = "Saalis: 0 kpl"
	add_child(catch_hud_label)

	fish_alert_label = Label.new()
	fish_alert_label.position = Vector2(12.0, 456.0)
	add_child(fish_alert_label)

	prompt_label = Label.new()
	prompt_label.position = Vector2(12.0, 480.0)
	add_child(prompt_label)

	line_prompt_label = Label.new()
	line_prompt_label.position = Vector2(12.0, 504.0)
	add_child(line_prompt_label)

	_init_tension_meter_hud()


func _init_tension_meter_hud() -> void:
	tension_meter_root = Control.new()
	tension_meter_root.name = "TensionMeterHUD"
	tension_meter_root.position = Vector2(680.0, 416.0)
	tension_meter_root.size = Vector2(268.0, 78.0)
	tension_meter_root.visible = false
	add_child(tension_meter_root)

	var panel_bg := ColorRect.new()
	panel_bg.position = Vector2.ZERO
	panel_bg.size = Vector2(268.0, 78.0)
	panel_bg.color = Color(0.06, 0.08, 0.11, 0.78)
	tension_meter_root.add_child(panel_bg)

	tension_meter_title = Label.new()
	tension_meter_title.position = Vector2(8.0, 4.0)
	tension_meter_title.size = Vector2(METER_BAR_WIDTH, 16.0)
	tension_meter_title.add_theme_font_size_override("font_size", 12)
	tension_meter_root.add_child(tension_meter_title)

	tension_bar_bg = ColorRect.new()
	tension_bar_bg.position = Vector2(8.0, 22.0)
	tension_bar_bg.size = Vector2(METER_BAR_WIDTH, METER_BAR_HEIGHT)
	tension_bar_bg.color = Color(0.14, 0.16, 0.20, 0.95)
	tension_meter_root.add_child(tension_bar_bg)

	tension_danger_zone = ColorRect.new()
	tension_danger_zone.position = Vector2(METER_BAR_WIDTH * 0.80, 0.0)
	tension_danger_zone.size = Vector2(METER_BAR_WIDTH * 0.20, METER_BAR_HEIGHT)
	tension_danger_zone.color = Color(0.65, 0.14, 0.14, 0.55)
	tension_bar_bg.add_child(tension_danger_zone)

	tension_bar_fill = ColorRect.new()
	tension_bar_fill.position = Vector2.ZERO
	tension_bar_fill.size = Vector2(0.0, METER_BAR_HEIGHT)
	tension_bar_fill.color = Color(0.24, 0.84, 0.36)
	tension_bar_bg.add_child(tension_bar_fill)

	drag_marker = ColorRect.new()
	drag_marker.position = Vector2(0.0, -2.0)
	drag_marker.size = Vector2(METER_DRAG_MARKER_WIDTH, METER_BAR_HEIGHT + 4.0)
	drag_marker.color = Color(0.98, 0.98, 0.92)
	tension_bar_bg.add_child(drag_marker)

	spool_bar_bg = ColorRect.new()
	spool_bar_bg.position = Vector2(8.0, 44.0)
	spool_bar_bg.size = Vector2(METER_BAR_WIDTH, METER_SPOOL_HEIGHT)
	spool_bar_bg.color = Color(0.14, 0.16, 0.20, 0.95)
	tension_meter_root.add_child(spool_bar_bg)

	spool_bar_fill = ColorRect.new()
	spool_bar_fill.position = Vector2.ZERO
	spool_bar_fill.size = Vector2(METER_BAR_WIDTH, METER_SPOOL_HEIGHT)
	spool_bar_fill.color = Color(0.32, 0.74, 0.95)
	spool_bar_bg.add_child(spool_bar_fill)

	tension_meter_footer = Label.new()
	tension_meter_footer.position = Vector2(8.0, 54.0)
	tension_meter_footer.size = Vector2(METER_BAR_WIDTH, 18.0)
	tension_meter_footer.add_theme_font_size_override("font_size", 11)
	tension_meter_root.add_child(tension_meter_footer)


func _init_trolling_resources() -> void:
	_line_mat = StandardMaterial3D.new()
	_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_mat.vertex_color_use_as_albedo = true
	_line_mat.albedo_color = Color.WHITE

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

	var mat_detach := StandardMaterial3D.new()
	mat_detach.albedo_color = Color(0.22, 0.92, 0.52)
	_planer_body_mats["detach_ready"] = mat_detach

	var flag_normal := StandardMaterial3D.new()
	flag_normal.albedo_color = Color(1.0, 0.90, 0.15)
	_flag_mats["normal"] = flag_normal

	var flag_bobbing := StandardMaterial3D.new()
	flag_bobbing.albedo_color = Color(1.0, 0.55, 0.12)
	_flag_mats["bobbing"] = flag_bobbing

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

	_fish_body_mesh = CapsuleMesh.new()
	_fish_body_mesh.radius = 0.5
	_fish_body_mesh.height = 1.0
	_fish_body_mesh.radial_segments = 8
	_fish_body_mesh.rings = 3

	_fish_tail_mesh = BoxMesh.new()
	_fish_tail_mesh.size = Vector3(0.08, 0.52, 0.28)

	_fish_dorsal_mesh = BoxMesh.new()
	_fish_dorsal_mesh.size = Vector3(0.07, 0.36, 0.22)

	_fish_belly_mesh = BoxMesh.new()
	_fish_belly_mesh.size = Vector3(0.68, 0.44, 0.62)

	_orca_belly_mat = StandardMaterial3D.new()
	_orca_belly_mat.albedo_color = Color(0.95, 0.96, 0.98)

	var species_colors := {
		FishState.SPECIES_VENDACE: Color(0.75, 0.85, 0.95),
		FishState.SPECIES_PERCH: Color(0.32, 0.60, 0.28),
		FishState.SPECIES_ZANDER: Color(0.50, 0.58, 0.44),
		FishState.SPECIES_PIKE: Color(0.20, 0.45, 0.24),
		FishState.SPECIES_ORCA: Color(0.10, 0.11, 0.14),
		FishState.SPECIES_BLUE_WHALE: Color(0.24, 0.44, 0.68),
	}
	for sp in species_colors:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = species_colors[sp]
		_fish_mats[sp] = mat


func _init_raikka_audio() -> void:
	_raikka_player = AudioStreamPlayer.new()
	_raikka_player.name = "RaikkaAudioPlayer"
	_raikka_player.volume_db = -8.0

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 11025
	wav.stereo = false
	var sample_count := 280
	var data := PackedByteArray()
	data.resize(sample_count)
	for i in range(sample_count):
		var env := 1.0 - float(i) / float(sample_count)
		var wave := sin(float(i) * 0.95) * env * 0.7
		var signed_byte := clampi(roundi(wave * 127.0), -127, 127)
		data[i] = signed_byte & 0xFF
	wav.data = data
	_raikka_player.stream = wav
	add_child(_raikka_player)


func configure_holders(item_config: ItemConfig) -> void:
	boat_view.configure_holders(item_config)


func apply_state(boat: BoatState, net_info: String = "") -> void:
	if not net_info.is_empty():
		net_status_text = net_info
	boat_view.apply_state(boat)
	_update_tension_meter_hud(null, null, null)
	_update_camera_and_hud(boat, "", false, false, "—")


func apply_game_state(game_state: GameState, net_info: String = "", local_peer_id: int = 1, snap_camera: bool = false, step_frame: bool = true) -> void:
	if not net_info.is_empty():
		net_status_text = net_info
	_tick_boat_pos = game_state.boat.world_position
	_tick_boat_heading = game_state.boat.heading
	if step_frame:
		_line_vib_time += 1.0 / 60.0
	if trolling_lines_container != null:
		trolling_lines_container.transform = Transform3D.IDENTITY
	boat_view.apply_state(game_state.boat, step_frame)
	boat_view.apply_items(game_state.items, game_state.item_config, game_state.fishes, game_state.rods)
	boat_view.apply_players(game_state.players, game_state.items, game_state.fishes, game_state.rods)
	_apply_trolling_rods(game_state)
	if step_frame:
		_step_raikka_audio(game_state, 1.0 / 60.0)

	var active_station := game_state.get_player_station(local_peer_id) if local_peer_id != 0 else ""
	var is_in_helm := (active_station == StationConfig.HELM_STATION_ID)
	_last_in_helm = is_in_helm
	var held_item := game_state.get_player_held_item(local_peer_id) if local_peer_id != 0 else null
	var held_label := _format_held_item_label(held_item)
	var prompt := ""
	var line_prompt := ""
	var best_hid := ""
	var best_holder: Dictionary = {}
	var active_rod_item: HeldItem = null
	var active_rod: RodState = null
	var active_fish: FishState = null

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

		var detach_target: Dictionary = {}
		var deck_target: Dictionary = {}
		if held_item == null:
			detach_target = FishSimulator.find_detach_target_for_player(game_state, local_peer_id)
			deck_target = ItemSimulator.find_nearest_deck_item(game_state, lp.local_position)

		var deck_dist := float(deck_target.get("distance", INF))
		var use_detach_prompt := not detach_target.is_empty() and (best_sid.is_empty() or float(detach_target.get("distance", INF)) < best_station_dist)
		var deck_prompt_active := false
		if held_item != null and held_item.item_type == ItemConfig.ITEM_TYPE_NET:
			prompt = "[E] Pudota haavi"
		elif use_detach_prompt:
			var target_rid := str(detach_target["rod_id"])
			var target_item := game_state.items.get(target_rid, null) as HeldItem
			var target_rod := game_state.get_rod_state(target_rid)
			var target_fish := game_state.get_fish_state(target_rid)
			var detach_pct := roundi(target_fish.detach_progress * 100.0) if target_fish != null else 0
			var rod_name := _format_held_item_label(target_item)
			if str(detach_target.get("mode", "")) == "coop":
				prompt = "[Pidä E] Irrota kaverin plaanari (%d%%)" % detach_pct
				line_prompt = "[Pidä E pohjassa] Auta irrottamaan plaanari (%d%%) | %s" % [detach_pct, rod_name]
			else:
				var holder_label := target_item.holder_id.substr(4) if (target_item != null and target_item.holder_id.begins_with("rod_")) else best_hid
				if target_item != null and game_state.item_config != null:
					var h_cfg := game_state.item_config.get_holder(target_item.holder_id)
					if not h_cfg.is_empty():
						holder_label = str(h_cfg.get("label", holder_label))
				prompt = "[Pidä E] Irrota plaanari (%s) %d%%" % [holder_label, detach_pct]
				var dist_m := target_rod.planer.line_out if target_rod != null else 0.0
				line_prompt = "[Pidä E pohjassa] Irrota plaanari (%d%%) | %s (Plaanari): %.1f m" % [detach_pct, rod_name, dist_m]
		elif not deck_target.is_empty() and (best_sid.is_empty() or deck_dist <= best_station_dist) and (best_hid.is_empty() or deck_dist < best_holder_dist):
			deck_prompt_active = true
			var deck_item := deck_target["item"] as HeldItem
			prompt = "[E] Poimi haavi" if deck_item.item_type == ItemConfig.ITEM_TYPE_NET else "[E] Poimi %s" % _format_held_item_label(deck_item)
		elif not best_sid.is_empty() and (best_hid.is_empty() or best_station_dist <= best_holder_dist):
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

		if line_prompt.is_empty() and held_item != null and held_item.item_type == ItemConfig.ITEM_TYPE_NET:
			var scoop_target := FishSimulator.find_scoop_target_for_player(game_state, local_peer_id)
			if not scoop_target.is_empty():
				var scoop_rid := str(scoop_target["rod_id"])
				var scoop_fish := game_state.get_fish_state(scoop_rid)
				var scoop_item := game_state.items.get(scoop_rid, null) as HeldItem
				var scoop_pct := roundi(scoop_fish.scoop_progress * 100.0) if scoop_fish != null else 0
				var sp_label := "%s (%s)" % [
					FishSimulator.get_species_display_name(scoop_fish.species),
					FishSimulator.format_weight(scoop_fish.weight_kg),
				]
				var rod_name := _format_held_item_label(scoop_item)
				line_prompt = "[Space] Kauhaise (%d%%) | %s | %s" % [scoop_pct, sp_label, rod_name]

		if held_item != null and held_item.item_type == ItemConfig.ITEM_TYPE_ROD:
			active_rod_item = held_item
		elif held_item == null and not deck_prompt_active and game_state.item_config != null:
			var best_rod_dist := INF
			for holder in game_state.item_config.holders:
				var hid := str(holder.get("id", ""))
				if hid.is_empty():
					continue
				var nearby_item := game_state.get_holder_item(hid)
				if nearby_item == null or nearby_item.item_type != ItemConfig.ITEM_TYPE_ROD:
					continue
				var pos: Vector3 = holder.get("local_position", Vector3.ZERO)
				var radius := float(holder.get("radius", ItemConfig.DEFAULT_HOLDER_RADIUS))
				var dx := lp.local_position.x - pos.x
				var dz := lp.local_position.z - pos.z
				var dist := sqrt(dx * dx + dz * dz)
				if dist <= radius and dist < best_rod_dist:
					best_rod_dist = dist
					active_rod_item = nearby_item

		if active_rod_item != null:
			active_rod = game_state.get_rod_state(active_rod_item.id)
			active_fish = game_state.get_fish_state(active_rod_item.id)
		if line_prompt.is_empty() and active_rod_item != null:
			if active_rod != null:
				var rod_name := _format_held_item_label(active_rod_item)
				var planer_tag := " (Plaanari)" if active_rod.planer.attached else ""
				if active_fish != null:
					var fish_dist := _fish_simulator_helper.get_fish_distance(active_rod, _rod_simulator_helper)
					if held_item == active_rod_item:
						if active_fish.is_ready_to_land():
							var sp_label := "%s (%s)" % [
								FishSimulator.get_species_display_name(active_fish.species),
								FishSimulator.format_weight(active_fish.weight_kg),
							]
							var risk_pct := roundi(FishSimulator.get_lift_escape_chance(active_fish) * 100.0)
							var lift_pct := roundi(active_fish.lift_progress * 100.0)
							line_prompt = "[Space pohjassa] Nosta ilman haavia (%d%%) | %s | Karkausriski: %d%%" % [
								lift_pct,
								sp_label,
								risk_pct,
							]
						elif FishSimulator.is_rod_ready_for_planer_detach(active_rod, active_fish):
							if active_fish.detach_progress > 0.01:
								var detach_pct := roundi(active_fish.detach_progress * 100.0)
								line_prompt = "[Kaveri irrottaa plaanaria: %d%%] Pidä vapa vakaana! | %s" % [detach_pct, rod_name]
							else:
								line_prompt = "[PLAANARI LAIDALLA] Aseta vapa telineeseen [E] tai pyydä kaveri [Pidä E] | %s: %.1f m" % [
									rod_name,
									active_rod.planer.line_out,
								]
						else:
							var is_slipping := active_fish.is_drag_active() or active_rod.is_drag_slipping
							var raikka_tag := " [RÄIKKÄ!]" if is_slipping else ""
							var sp_tag := " (%s)" % FishSimulator.get_species_display_name(active_fish.species) if active_fish.surfaced else " (Tuntematon kala)"
							line_prompt = "[Space] Kelaa%s | %s%s: %.1f m" % [
								raikka_tag,
								rod_name,
								sp_tag,
								fish_dist,
							]
					else:
						var big_or_tripped := (
							bool(FishSimulator.get_strike_reaction_profile(active_fish.size_class).get("trips_planer", false))
							or active_rod.planer.state == PlanerBoard.STATE_TRIPPED
							or active_fish.is_drag_active()
							or active_rod.is_drag_slipping
						)
						if big_or_tripped:
							line_prompt = "[KALA KIINNI!] Poimi vapa [E] ja kelaa! | %s%s: %.1f m [%s]" % [
								rod_name,
								planer_tag,
								active_rod.planer.line_out,
								active_rod.planer.state,
							]
						else:
							line_prompt = "[Vapa nykii!] Poimi vapa [E] ja tarkista | %s%s: %.1f m [%s]" % [
								rod_name,
								planer_tag,
								active_rod.planer.line_out,
								active_rod.planer.state,
							]
				elif active_rod.planer.state == PlanerBoard.STATE_TANGLED:
					line_prompt = "[SOTKU] Kelaa ylös [Space] (0 m) | %s%s: %.1f m [TANGLED]" % [
						rod_name,
						planer_tag,
						active_rod.planer.line_out,
					]
				elif active_rod.planer.state == PlanerBoard.STATE_SNAGGED:
					line_prompt = "[KIINNI] Kelaa ylös [Space] (0 m) | %s%s: %.1f m [SNAGGED]" % [
						rod_name,
						planer_tag,
						active_rod.planer.line_out,
					]
				else:
					line_prompt = "[Q/Shift] Laske | [Space] Kelaa | %s%s: %.1f m [%s]" % [
						rod_name,
						planer_tag,
						active_rod.planer.line_out,
						active_rod.planer.state,
					]
				var eff_max := maxf(1.0, active_rod.get_effective_max_strength())
				var tension_pct := roundi((active_rod.line_tension / eff_max) * 100.0)
				line_prompt += " | Jarru [Z/X]: %d N | Kireys: %d%% | Puola: %d m" % [
					roundi(active_rod.drag_setting),
					tension_pct,
					roundi(active_rod.line_remaining_on_spool),
				]
				var any_slip := (active_fish != null and active_fish.is_drag_active()) or active_rod.is_drag_slipping
				if any_slip and not line_prompt.contains("[RÄIKKÄ!]"):
					line_prompt += " [RÄIKKÄ!]"
				elif active_fish != null and not active_fish.is_ready_to_land() and active_rod.line_tension < LinePhysics.SLACK_TENSION_THRESHOLD:
					line_prompt += " [LÖYSÄ!]"

	_update_tension_meter_hud(active_rod_item, active_rod, active_fish)
	var fish_alert := _build_fish_alert_text(game_state)
	var catch_hud := _build_catch_hud_text(game_state)
	_update_camera_and_hud(
		game_state.boat,
		prompt,
		is_in_helm,
		snap_camera,
		held_label,
		line_prompt,
		game_state.get_deployed_rod_count(),
		game_state.rods.size(),
		fish_alert,
		catch_hud,
		step_frame
	)


func _format_held_item_label(item: HeldItem) -> String:
	if item == null:
		return "—"
	if item.item_type == ItemConfig.ITEM_TYPE_NET:
		return "Haavi"
	if item.item_type == ItemConfig.ITEM_TYPE_ROD:
		if item.id.begins_with("rod_"):
			return "Vapa #%s" % item.id.substr(4)
		return "Vapa"
	return item.id if not item.id.is_empty() else item.item_type


func _build_catch_hud_text(game_state: GameState) -> String:
	var count := game_state.get_catch_count()
	if count <= 0:
		return "Saalis: 0 kpl"
	var biggest := game_state.get_biggest_catch_weight()
	return "Saalis: %d kpl | Isoin: %s" % [count, FishSimulator.format_weight(biggest)]


func _update_camera_and_hud(
	boat: BoatState,
	prompt: String,
	in_helm: bool,
	snap_camera: bool = false,
	held_label: String = "—",
	line_prompt: String = "",
	deployed_rods: int = 0,
	total_rods: int = 0,
	fish_alert: String = "",
	catch_hud: String = "Saalis: 0 kpl",
	step_frame: bool = true
) -> void:
	camera_controller.set_mode(in_helm, snap_camera)
	if step_frame or snap_camera:
		camera_controller.step(snap_camera, 1.0 / 60.0)
		var cam_xform := camera_controller.compute_camera_transform(boat.world_position, boat.heading)
		camera.position = cam_xform["position"]
		camera.rotation = cam_xform["rotation"]

	var control_mode := camera_controller.get_control_mode_hud_text(in_helm, held_label)
	var lines_hud := "Vedessä: %d/%d" % [deployed_rods, total_rods]
	if debug_hud_enabled:
		var fps := Engine.get_frames_per_second()
		var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		hud_label.text = "[TEST] FPS: %d | Draw Calls: %d | Tris: %d\nNopeus: %.2f m/s | Kaasu: %.0f%% | Ruori: %.0f° | %s\n%s\nTila: %s\nB: Botit | T: Sync Hz | L: Viive | I: Interp | F: Tärppi | F5/F9: Snapshot" % [
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

	if catch_hud_label != null:
		catch_hud_label.text = catch_hud
	if fish_alert_label != null:
		fish_alert_label.text = fish_alert
	prompt_label.text = prompt
	if line_prompt_label != null:
		line_prompt_label.text = line_prompt


func _build_fish_alert_text(game_state: GameState) -> String:
	if not game_state.fish_notice_text.is_empty() and game_state.fish_notice_timer > 0.0:
		return game_state.fish_notice_text
	var tripped_labels: Array[String] = []
	var any_drag := false
	var rod_ids: Array[String] = []
	for rid in game_state.rods.keys():
		rod_ids.append(str(rid))
	rod_ids.sort()
	for rid in rod_ids:
		var rod := game_state.get_rod_state(rid)
		var fish := game_state.get_fish_state(rid)
		var item := game_state.items.get(rid, null) as HeldItem
		if rod == null or item == null:
			continue
		var is_tripped := rod.planer.state == PlanerBoard.STATE_TRIPPED
		var loud_fish := fish != null and (bool(FishSimulator.get_strike_reaction_profile(fish.size_class).get("trips_planer", false)) or fish.is_drag_active() or rod.is_drag_slipping)
		if is_tripped or loud_fish:
			tripped_labels.append(_format_held_item_label(item))
		if (fish != null and fish.is_drag_active()) or rod.is_drag_slipping:
			any_drag = true
	if tripped_labels.is_empty():
		return ""
	var drag_suffix := " | RÄIKKÄ SOI!" if any_drag else ""
	return "TÄRPPI! %s%s" % [", ".join(tripped_labels), drag_suffix]


func _update_tension_meter_hud(item: HeldItem, rod: RodState, fish: FishState) -> void:
	if tension_meter_root == null:
		return
	if item == null or rod == null:
		tension_meter_root.visible = false
		return
	tension_meter_root.visible = true
	var eff_max := maxf(1.0, rod.get_effective_max_strength())
	var max_scale := RodState.MAX_DRAG_SETTING
	var tension_ratio := clampf(rod.line_tension / eff_max, 0.0, 1.0)
	tension_bar_fill.size.x = clampf(rod.line_tension / max_scale, 0.0, 1.0) * METER_BAR_WIDTH
	if tension_ratio >= LINE_CRITICAL_RATIO:
		tension_bar_fill.color = Color(0.96, 0.20, 0.16)
	elif tension_ratio >= LINE_HIGH_RATIO or rod.is_drag_slipping:
		tension_bar_fill.color = Color(0.96, 0.74, 0.18)
	elif rod.is_deployed() and rod.line_tension < LinePhysics.SLACK_TENSION_THRESHOLD:
		tension_bar_fill.color = Color(0.45, 0.72, 0.88)
	else:
		tension_bar_fill.color = Color(0.24, 0.84, 0.36)

	var break_x := clampf(eff_max / max_scale, 0.0, 1.0) * METER_BAR_WIDTH
	tension_danger_zone.position.x = break_x
	tension_danger_zone.size.x = maxf(0.0, METER_BAR_WIDTH - break_x)

	var drag_x := clampf(rod.drag_setting / max_scale, 0.0, 1.0) * METER_BAR_WIDTH - METER_DRAG_MARKER_WIDTH * 0.5
	drag_marker.position.x = clampf(drag_x, 0.0, METER_BAR_WIDTH - METER_DRAG_MARKER_WIDTH)

	var spool_ratio := clampf(rod.line_remaining_on_spool / RodState.DEFAULT_SPOOL_CAPACITY, 0.0, 1.0)
	spool_bar_fill.size.x = spool_ratio * METER_BAR_WIDTH
	spool_bar_fill.color = Color(0.92, 0.32, 0.22) if spool_ratio < 0.20 else Color(0.32, 0.74, 0.95)

	var label := _format_held_item_label(item)
	var slip_tag := " [RÄIKKÄ]" if (rod.is_drag_slipping or (fish != null and fish.is_drag_active())) else ""
	tension_meter_title.text = "%s | Kireys %d%%%s" % [label, roundi((rod.line_tension / eff_max) * 100.0), slip_tag]
	tension_meter_footer.text = "Jarru [Z/X]: %d N | Murtoraja: %d N | Puola: %d m" % [
		roundi(rod.drag_setting),
		roundi(eff_max),
		roundi(rod.line_remaining_on_spool),
	]


func update_frame(blend: Dictionary, delta: float, game_state: GameState = null) -> void:
	_line_vib_time += maxf(0.0, delta)
	var b_pos: Vector3 = blend.get("boat_pos", _tick_boat_pos)
	var b_head: float = float(blend.get("boat_heading", _tick_boat_heading))
	boat_view.apply_frame(b_pos, b_head, delta)
	var players_blend: Variant = blend.get("players", {})
	if players_blend is Dictionary:
		for pid in (players_blend as Dictionary):
			var pv := boat_view.get_player_view(int(pid))
			if pv != null:
				pv.position = (players_blend as Dictionary)[pid]
	if trolling_lines_container != null:
		var tick_xform := Transform3D(Basis(Vector3.UP, _tick_boat_heading), _tick_boat_pos)
		var blend_xform := Transform3D(Basis(Vector3.UP, b_head), b_pos)
		trolling_lines_container.transform = blend_xform * tick_xform.affine_inverse()
	camera_controller.step(false, delta)
	var cam_xform := camera_controller.compute_camera_transform(b_pos, b_head)
	camera.position = cam_xform["position"]
	camera.rotation = cam_xform["rotation"]
	if game_state != null:
		_step_raikka_audio(game_state, delta)


func _step_raikka_audio(game_state: GameState, delta: float = 1.0 / 60.0) -> void:
	var max_drag := 0.0
	for fid in game_state.fishes:
		var fish: FishState = game_state.fishes[fid]
		if fish != null and fish.drag_rate > max_drag:
			max_drag = fish.drag_rate
	for rid in game_state.rods:
		var rod: RodState = game_state.rods[rid]
		if rod != null and rod.is_drag_slipping:
			max_drag = maxf(max_drag, 0.7)
	if max_drag <= 0.01:
		_raikka_cooldown = 0.0
		return
	_raikka_cooldown -= delta
	if _raikka_cooldown <= 0.0:
		var interval := clampf(0.16 - max_drag * 0.058, 0.045, 0.16)
		_raikka_cooldown = interval
		if _raikka_player != null and is_inside_tree():
			_raikka_player.pitch_scale = clampf(0.9 + max_drag * 0.25, 0.85, 1.5)
			_raikka_player.play()


func _set_mat(mi: MeshInstance3D, mat: Material) -> void:
	if mi != null and mi.material_override != mat:
		mi.material_override = mat
		material_assign_count += 1


static func compute_line_color(tension_ratio: float, is_slack: bool, is_slipping: bool, planer_state: String) -> Color:
	if tension_ratio >= LINE_CRITICAL_RATIO:
		return Color(0.98, 0.22, 0.18)
	if planer_state == PlanerBoard.STATE_TANGLED:
		return Color(0.78, 0.34, 0.94)
	if planer_state == PlanerBoard.STATE_SNAGGED:
		return Color(0.96, 0.36, 0.20)
	if is_slack:
		return Color(0.50, 0.72, 0.86)
	if is_slipping or tension_ratio >= LINE_HIGH_RATIO:
		return Color(0.98, 0.78, 0.22)
	return Color(0.92, 0.96, 1.0)


func get_line_start_world(rod_id: String) -> Vector3:
	return _line_start_world.get(rod_id, Vector3.ZERO) as Vector3


func get_line_points_world(rod_id: String) -> PackedVector3Array:
	return _line_points_by_rod.get(rod_id, PackedVector3Array()) as PackedVector3Array


func get_line_color(rod_id: String) -> Color:
	return _line_color_by_rod.get(rod_id, Color(0.92, 0.96, 1.0)) as Color


func _apply_trolling_rods(game_state: GameState) -> void:
	_lines_mesh.clear_surfaces()
	_line_start_world.clear()
	_line_points_by_rod.clear()
	_line_color_by_rod.clear()
	var line_vertices: Array[Vector3] = []
	var line_colors: Array[Color] = []
	var deployed_rods: Dictionary = {}
	var active_planers: Dictionary = {}
	var active_lures: Dictionary = {}
	var active_fishes: Dictionary = {}
	var aft_world := Vector3(sin(game_state.boat.heading), 0.0, cos(game_state.boat.heading))

	for rid in game_state.rods:
		var rod := game_state.rods[rid] as RodState
		var item := game_state.items.get(rid, null) as HeldItem
		if rod == null or item == null or not rod.is_deployed():
			continue

		var rid_str := str(rid)
		deployed_rods[rid_str] = true
		var tip_world := boat_view.get_visual_rod_tip_world(item, game_state)
		_line_start_world[rid_str] = tip_world
		var fish := game_state.get_fish_state(rid_str)
		var show_fish := fish != null and (fish.surfaced or fish.is_jumping())
		var end_world := Vector3.ZERO

		if show_fish:
			var fish_2d := _fish_simulator_helper.get_fish_world_pos_2d(game_state, item, rod, fish, _rod_simulator_helper)
			var y_pos := WATER_Y + 0.04
			var jump_pitch := 0.0
			var thrash_scale := lerpf(0.35, 1.45, clampf(fish.stamina, 0.0, 1.0)) if fish.is_ready_to_land() else 1.0
			if fish.is_jumping():
				y_pos = WATER_Y + FishSimulator.get_fish_jump_height_offset(fish)
				jump_pitch = cos(fish.jump_progress * PI) * 0.85
			else:
				var wiggle_lat := sin(fish.fight_phase * 2.5) * 0.14 * thrash_scale
				var right_2d := Vector2(cos(game_state.boat.heading), -sin(game_state.boat.heading))
				fish_2d += right_2d * wiggle_lat
			end_world = Vector3(fish_2d.x, y_pos, fish_2d.y)
			active_fishes[rid_str] = {
				"pos": end_world,
				"species": fish.species,
				"yaw": game_state.boat.heading + rod.trail_angle + sin(fish.fight_phase * 3.0) * 0.22 * thrash_scale,
				"pitch": jump_pitch,
			}
		else:
			var lure_2d := _rod_simulator_helper.get_lure_world_pos_2d(game_state, item, rod)
			end_world = Vector3(lure_2d.x, WATER_Y + 0.05, lure_2d.y)
			active_lures[rid_str] = {"pos": end_world, "color_index": item.color_index}

		var eff_max := maxf(1.0, rod.get_effective_max_strength())
		var tension_ratio := clampf(rod.line_tension / eff_max, 0.0, 1.0)
		var is_slack := rod.line_tension < LinePhysics.SLACK_TENSION_THRESHOLD
		var is_slipping := rod.is_drag_slipping or (fish != null and fish.is_drag_active())
		var line_color := compute_line_color(tension_ratio, is_slack, is_slipping, rod.planer.state)
		_line_color_by_rod[rid_str] = line_color

		var tautness := clampf(maxf(rod.line_tension / 45.0, tension_ratio), 0.0, 1.0)
		var straighten := 1.0 - pow(1.0 - tautness, 2.0)
		var vib_amp := 0.0
		if tension_ratio >= LINE_CRITICAL_RATIO:
			var crit_t := clampf((tension_ratio - LINE_CRITICAL_RATIO) / (1.0 - LINE_CRITICAL_RATIO), 0.0, 1.0)
			vib_amp = lerpf(0.035, 0.085, crit_t)
		elif is_slipping:
			vib_amp = 0.012
		var vib_phase := (_line_vib_time + float(game_state.tick) * (1.0 / 60.0)) * 28.0 + float(rid_str.hash() & 0xFF) * 0.13
		var rod_poly: Array[Vector3] = []

		var main_end := end_world
		if rod.planer.attached:
			var board_2d := _rod_simulator_helper.get_board_world_pos_2d(game_state, item, rod)
			var submersion := rod.planer.submersion
			var shake := rod.planer.shake_intensity
			var phase := fish.fight_phase if fish != null else float(game_state.tick) * 0.25
			var shake_x := sin(phase * 11.0) * 0.09 * shake
			var shake_y := cos(phase * 17.0) * 0.04 * shake
			var shake_z := sin(phase * 13.0) * 0.08 * shake
			var board_y := WATER_Y + 0.05 - submersion * 0.65 + shake_y
			main_end = Vector3(board_2d.x + shake_x, board_y, board_2d.y + shake_z)
			var board_pitch := clampf(rod.planer.pull_back_offset * 0.085, 0.0, 0.60)
			var board_roll := sin(phase * 9.0) * 0.35 * shake
			var board_yaw := game_state.boat.heading + rod.trail_angle + cos(phase * 7.0) * 0.18 * shake
			var detach_ready := FishSimulator.is_rod_ready_for_planer_detach(rod, fish)
			active_planers[rid_str] = {
				"pos": main_end,
				"state": rod.planer.state,
				"yaw": board_yaw,
				"pitch": board_pitch,
				"roll": board_roll,
				"flag_angle": rod.planer.flag_angle,
				"detach_ready": detach_ready,
			}

		var span := tip_world.distance_to(main_end)
		var sag := lerpf(minf(1.10, span * 0.14), minf(0.025, span * 0.002), straighten)
		var aft_bow := sag * 0.26 * (1.0 - straighten)
		_append_curved_segment(line_vertices, line_colors, rod_poly, tip_world, main_end, 4, sag, line_color, aft_world, aft_bow, vib_amp, vib_phase)
		if rod.planer.attached:
			var leader_span := main_end.distance_to(end_world)
			var leader_sag := lerpf(minf(0.18, leader_span * 0.05), 0.0, straighten)
			_append_curved_segment(line_vertices, line_colors, rod_poly, main_end, end_world, 2, leader_sag, line_color, aft_world, 0.0, vib_amp * 0.6, vib_phase + 1.1)

		_line_points_by_rod[rid_str] = PackedVector3Array(rod_poly)

	if not line_vertices.is_empty():
		_lines_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _line_mat)
		for idx in range(line_vertices.size()):
			_lines_mesh.surface_set_color(line_colors[idx])
			_lines_mesh.surface_add_vertex(line_vertices[idx])
		_lines_mesh.surface_end()

	for existing_pid in _planer_views.keys():
		if not active_planers.has(existing_pid):
			var stale_planer: Node3D = _planer_views[existing_pid]
			_planer_views.erase(existing_pid)
			_planer_parts.erase(existing_pid)
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
		p_node.rotation = Vector3(float(p_info["pitch"]), float(p_info["yaw"]), float(p_info["roll"]))
		_update_planer_visual_state(rid, p_node, str(p_info["state"]), float(p_info["flag_angle"]), bool(p_info.get("detach_ready", false)))

	for existing_lid in _lure_views.keys():
		if not deployed_rods.has(existing_lid):
			var stale_lure: Node3D = _lure_views[existing_lid]
			_lure_views.erase(existing_lid)
			_free_node_safe(stale_lure)
		elif not active_lures.has(existing_lid):
			(_lure_views[existing_lid] as Node3D).visible = false

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
		l_node.visible = true
		l_node.position = l_info["pos"]
		if not _lure_meshes.is_empty():
			var target_mesh := _lure_meshes[posmod(int(l_info["color_index"]), _lure_meshes.size())]
			if l_node.mesh != target_mesh:
				l_node.mesh = target_mesh

	for existing_fid in _fish_views.keys():
		if not deployed_rods.has(existing_fid) or not game_state.fishes.has(existing_fid):
			var stale_fish: Node3D = _fish_views[existing_fid]
			_fish_views.erase(existing_fid)
			_fish_parts.erase(existing_fid)
			_fish_species_cache.erase(existing_fid)
			_free_node_safe(stale_fish)
		elif not active_fishes.has(existing_fid):
			(_fish_views[existing_fid] as Node3D).visible = false

	for rid in active_fishes:
		var f_info: Dictionary = active_fishes[rid]
		var f_node: Node3D
		if _fish_views.has(rid):
			f_node = _fish_views[rid] as Node3D
		else:
			f_node = _create_fish_node(rid)
			fishes_container.add_child(f_node)
			_fish_views[rid] = f_node
		f_node.visible = true
		var sp := str(f_info["species"])
		var spec := FishSimulator.get_species_spec(sp)
		var v_len := float(spec.get("visual_length", 0.6))
		var v_rad := float(spec.get("visual_radius", 0.12))
		f_node.position = f_info["pos"]
		f_node.rotation = Vector3(float(f_info["pitch"]), float(f_info["yaw"]), 0.0)
		f_node.scale = Vector3(v_rad * 2.0, v_rad * 2.0, v_len)
		_update_fish_visual_species(rid, f_node, sp)


func _append_curved_segment(
	out_verts: Array[Vector3],
	out_colors: Array[Color],
	out_poly: Array[Vector3],
	start_pos: Vector3,
	end_pos: Vector3,
	segments: int,
	sag: float,
	line_color: Color,
	aft_world: Vector3,
	aft_bow: float,
	vib_amp: float,
	vib_phase: float
) -> void:
	var count := maxi(1, segments)
	var chord := end_pos - start_pos
	var lat_dir := Vector3(-chord.z, 0.0, chord.x)
	if lat_dir.length_squared() > 0.0001:
		lat_dir = lat_dir.normalized()
	else:
		lat_dir = Vector3.RIGHT
	var floor_y := minf(WATER_Y + 0.03, minf(start_pos.y, end_pos.y))
	if out_poly.is_empty():
		out_poly.append(start_pos)
	var prev := start_pos
	for i in range(1, count + 1):
		var frac := float(i) / float(count)
		var pt := start_pos.lerp(end_pos, frac)
		if i < count:
			var arc := sin(frac * PI)
			pt.y -= arc * sag
			pt += aft_world * (arc * aft_bow)
			if vib_amp > 0.0001:
				var osc := sin(vib_phase + float(i) * 1.9)
				pt += lat_dir * (arc * osc * vib_amp)
				pt.y += arc * cos(vib_phase * 1.3 + float(i) * 1.7) * (vib_amp * 0.45)
			pt.y = maxf(pt.y, floor_y)
		out_verts.append(prev)
		out_verts.append(pt)
		out_colors.append(line_color)
		out_colors.append(line_color)
		out_poly.append(pt)
		prev = pt


func _create_planer_node(rod_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Planer_%s" % rod_id

	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _planer_body_mesh
	root.add_child(body)

	var flag_pivot := Node3D.new()
	flag_pivot.name = "FlagPivot"
	flag_pivot.position = Vector3(0.0, 0.08, -0.05)
	root.add_child(flag_pivot)

	var flag := MeshInstance3D.new()
	flag.name = "Flag"
	flag.mesh = _planer_flag_mesh
	flag.position = Vector3(0.0, 0.17, 0.0)
	flag_pivot.add_child(flag)

	_planer_parts[rod_id] = {"body": body, "flag_pivot": flag_pivot, "flag": flag}
	return root


func _update_planer_visual_state(rod_id: String, _planer_node: Node3D, state_name: String, flag_angle: float = 0.0, detach_ready: bool = false) -> void:
	var parts := _planer_parts.get(rod_id, {}) as Dictionary
	var body := parts.get("body", null) as MeshInstance3D
	var flag_pivot := parts.get("flag_pivot", null) as Node3D
	var flag := parts.get("flag", null) as MeshInstance3D

	if body != null:
		if state_name == PlanerBoard.STATE_TANGLED:
			_set_mat(body, _planer_body_mats["tangled"])
		elif state_name == PlanerBoard.STATE_SNAGGED:
			_set_mat(body, _planer_body_mats["snagged"])
		elif detach_ready:
			_set_mat(body, _planer_body_mats["detach_ready"])
		else:
			_set_mat(body, _planer_body_mats["normal"])

	if flag_pivot != null and flag != null:
		var eff_angle := flag_angle
		if absf(eff_angle) <= 0.01:
			if state_name == PlanerBoard.STATE_TRIPPED:
				eff_angle = -65.0
			elif state_name == PlanerBoard.STATE_TANGLED or state_name == PlanerBoard.STATE_SNAGGED:
				eff_angle = -30.0
			else:
				eff_angle = 0.0
		flag_pivot.rotation_degrees = Vector3(eff_angle, 0.0, 0.0)
		if state_name == PlanerBoard.STATE_TRIPPED or state_name == PlanerBoard.STATE_TANGLED or state_name == PlanerBoard.STATE_SNAGGED or absf(eff_angle) >= 45.0:
			_set_mat(flag, _flag_mats["tripped"])
		elif absf(eff_angle) >= 5.0:
			_set_mat(flag, _flag_mats["bobbing"])
		else:
			_set_mat(flag, _flag_mats["normal"])


func _create_fish_node(rod_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Fish_%s" % rod_id

	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _fish_body_mesh
	body.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	root.add_child(body)

	var tail := MeshInstance3D.new()
	tail.name = "Tail"
	tail.mesh = _fish_tail_mesh
	tail.position = Vector3(0.0, 0.0, 0.56)
	root.add_child(tail)

	var dorsal := MeshInstance3D.new()
	dorsal.name = "Dorsal"
	dorsal.mesh = _fish_dorsal_mesh
	dorsal.position = Vector3(0.0, 0.42, 0.0)
	root.add_child(dorsal)

	var belly := MeshInstance3D.new()
	belly.name = "BellyPatch"
	belly.mesh = _fish_belly_mesh
	belly.position = Vector3(0.0, -0.22, -0.08)
	belly.material_override = _orca_belly_mat
	belly.visible = false
	root.add_child(belly)

	_fish_parts[rod_id] = {"body": body, "tail": tail, "dorsal": dorsal, "belly": belly}
	return root


func _update_fish_visual_species(rod_id: String, _fish_node: Node3D, species_id: String) -> void:
	if _fish_species_cache.get(rod_id, "") == species_id:
		return
	_fish_species_cache[rod_id] = species_id
	var parts := _fish_parts.get(rod_id, {}) as Dictionary
	var mat := _fish_mats.get(species_id, _fish_mats.get(FishState.SPECIES_PERCH, null)) as StandardMaterial3D
	var body := parts.get("body", null) as MeshInstance3D
	var tail := parts.get("tail", null) as MeshInstance3D
	var dorsal := parts.get("dorsal", null) as MeshInstance3D
	var belly := parts.get("belly", null) as MeshInstance3D
	if mat != null:
		_set_mat(body, mat)
		_set_mat(tail, mat)
		_set_mat(dorsal, mat)
	if tail != null:
		var spec := FishSimulator.get_species_spec(species_id)
		tail.rotation_degrees = Vector3(0.0, 0.0, 90.0 if bool(spec.get("is_whale", false)) else 0.0)
	if belly != null:
		belly.visible = (species_id == FishState.SPECIES_ORCA)


func get_visible_fish_count() -> int:
	if fishes_container == null:
		return 0
	var count := 0
	for child in fishes_container.get_children():
		if child is Node3D and (child as Node3D).visible:
			count += 1
	return count


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
