class_name StationConfig
extends RefCounted

const HELM_STATION_ID: String = "helm"
const HELM_LOCAL_POS: Vector3 = Vector3(0.0, 0.25, -0.6)
const HELM_INTERACTION_RADIUS: float = 1.0
const HELM_RADIUS: float = HELM_INTERACTION_RADIUS
const HELM_CAM_OFFSET: Vector3 = Vector3(0.0, 2.0, 1.2)
const HELM_CAM_PITCH_DEG: float = -15.0

const STATIONS: Dictionary = {
	HELM_STATION_ID: {
		"local_position": HELM_LOCAL_POS,
		"radius": HELM_INTERACTION_RADIUS,
		"prompt_enter": "[E] Tartu ruoriin",
		"prompt_leave": "[E] Irrota ote",
		"prompt_occupied": "[Ruori varattu]",
	},
}


static func create_default_stations() -> Dictionary:
	var result: Dictionary = {}
	for sid in STATIONS:
		result[str(sid)] = 0
	return result


static func get_station_config(station_id: String) -> Dictionary:
	if STATIONS.has(station_id):
		return STATIONS[station_id]
	return {}


static func get_station_position(station_id: String) -> Vector3:
	if STATIONS.has(station_id):
		return STATIONS[station_id].get("local_position", Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, 0.0))
	return Vector3(0.0, CrewSimulator.DECK_SURFACE_Y, 0.0)


static func get_station_radius(station_id: String) -> float:
	if STATIONS.has(station_id):
		return float(STATIONS[station_id].get("radius", HELM_INTERACTION_RADIUS))
	return HELM_INTERACTION_RADIUS
