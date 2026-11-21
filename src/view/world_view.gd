class_name WorldView
extends Node3D

const CAMERA_OFFSET := Vector3(0.0, 7.0, 12.0)
const CAMERA_PITCH_DEG: float = -28.0

var boat_view: BoatView
var camera: Camera3D
var hud_label: Label
var prompt_label: Label
var net_status_text: String = "Net: OFFLINE | Peers: 0 | Sync: 20 Hz | Bots: 0"
var debug_hud_enabled: bool = true

var _current_cam_offset: Vector3 = CAMERA_OFFSET
var _current_cam_pitch: float = CAMERA_PITCH_DEG


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

	boat_view = BoatView.new()
	add_child(boat_view)

	camera = Camera3D.new()
	camera.position = CAMERA_OFFSET
	camera.rotation = Vector3(deg_to_rad(CAMERA_PITCH_DEG), 0.0, 0.0)
	add_child(camera)

	hud_label = Label.new()
	hud_label.position = Vector2(12.0, 12.0)
	add_child(hud_label)

	prompt_label = Label.new()
	prompt_label.position = Vector2(12.0, 480.0)
	add_child(prompt_label)


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

	var active_station := game_state.get_player_station(local_peer_id) if local_peer_id != 0 else ""
	var is_in_helm := (active_station == StationConfig.HELM_STATION_ID)
	var held_item := game_state.get_player_held_item(local_peer_id) if local_peer_id != 0 else null
	var held_label := _format_held_item_label(held_item)
	var prompt := ""

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

		var best_holder: Dictionary = {}
		var best_hid := ""
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

	_update_camera_and_hud(game_state.boat, prompt, is_in_helm, snap_camera, held_label)


func _format_held_item_label(item: HeldItem) -> String:
	if item == null:
		return "—"
	if item.item_type == ItemConfig.ITEM_TYPE_ROD:
		if item.id.begins_with("rod_"):
			return "Vapa #%s" % item.id.substr(4)
		return "Vapa"
	return item.id if not item.id.is_empty() else item.item_type


func _update_camera_and_hud(boat: BoatState, prompt: String, in_helm: bool, snap_camera: bool = false, held_label: String = "—") -> void:
	var target_offset := StationConfig.HELM_CAM_OFFSET if in_helm else CAMERA_OFFSET
	var target_pitch := StationConfig.HELM_CAM_PITCH_DEG if in_helm else CAMERA_PITCH_DEG

	if snap_camera:
		_current_cam_offset = target_offset
		_current_cam_pitch = target_pitch
	else:
		_current_cam_offset = _current_cam_offset.lerp(target_offset, 0.15)
		_current_cam_pitch = lerpf(_current_cam_pitch, target_pitch, 0.15)

	camera.position = boat.world_position + _current_cam_offset.rotated(Vector3.UP, boat.heading)
	camera.rotation = Vector3(deg_to_rad(_current_cam_pitch), boat.heading, 0.0)

	var control_mode := "RUORISSA (Ajo: WASD / Nuolet | E: Poistu)" if in_helm else "KANNELLA (Kävely: WASD | E: Käytä) | Kädessä: %s" % held_label
	if debug_hud_enabled:
		var fps := Engine.get_frames_per_second()
		var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		hud_label.text = "[TEST] FPS: %d | Draw Calls: %d | Tris: %d\nNopeus: %.2f m/s | Kaasu: %.0f%% | Ruori: %.0f°\n%s\nTila: %s\nB: Botit | T: Sync Hz | L: Viive | I: Interp" % [
			fps,
			draw_calls,
			primitives,
			boat.forward_speed,
			boat.throttle * 100.0,
			rad_to_deg(boat.steering_angle),
			net_status_text,
			control_mode,
		]
	else:
		hud_label.text = "Nopeus: %.2f m/s | Kaasu: %.0f%% | Ruori: %.0f°\n%s\nTila: %s" % [
			boat.forward_speed,
			boat.throttle * 100.0,
			rad_to_deg(boat.steering_angle),
			net_status_text,
			control_mode,
		]

	prompt_label.text = prompt
