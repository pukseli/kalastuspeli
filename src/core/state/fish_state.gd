class_name FishState
extends RefCounted
## Pure state model for a hooked fish, stamina, reel drag, breach jump, and netless lift progress.

const STATE_HOOKED: String = "HOOKED"
const STATE_READY_TO_LAND: String = "READY_TO_LAND"

const VALID_STATES: Array[String] = [
	STATE_HOOKED,
	STATE_READY_TO_LAND,
]

const SPECIES_VENDACE: String = "vendace"
const SPECIES_PERCH: String = "perch"
const SPECIES_ZANDER: String = "zander"
const SPECIES_PIKE: String = "pike"
const SPECIES_ORCA: String = "orca"
const SPECIES_BLUE_WHALE: String = "blue_whale"

const VALID_SPECIES: Array[String] = [
	SPECIES_VENDACE,
	SPECIES_PERCH,
	SPECIES_ZANDER,
	SPECIES_PIKE,
	SPECIES_ORCA,
	SPECIES_BLUE_WHALE,
]

const SIZE_SMALL: String = "SMALL"
const SIZE_MEDIUM: String = "MEDIUM"
const SIZE_LARGE: String = "LARGE"
const SIZE_MONSTER: String = "MONSTER"

const VALID_SIZE_CLASSES: Array[String] = [
	SIZE_SMALL,
	SIZE_MEDIUM,
	SIZE_LARGE,
	SIZE_MONSTER,
]

var rod_id: String = ""
var species: String = SPECIES_PERCH
var weight_kg: float = 0.5
var size_class: String = SIZE_SMALL
var state: String = STATE_HOOKED
var stamina: float = 1.0
var drag_rate: float = 0.0
var surge_timer: float = 0.0
var surge_cooldown: float = 2.0
var jump_progress: float = 0.0
var lift_progress: float = 0.0
var hooked_time: float = 0.0
var unattended_time: float = 0.0
var surfaced: bool = false
var fight_phase: float = 0.0


func is_ready_to_land() -> bool:
	return state == STATE_READY_TO_LAND


func is_jumping() -> bool:
	return jump_progress > 0.001 and jump_progress < 0.999


func is_drag_active() -> bool:
	return drag_rate > 0.01


static func compute_size_class(
	weight: float,
	small_max_kg: float = 1.0,
	medium_max_kg: float = 4.0,
	large_max_kg: float = 8.0
) -> String:
	if weight < small_max_kg:
		return SIZE_SMALL
	if weight < medium_max_kg:
		return SIZE_MEDIUM
	if weight <= large_max_kg:
		return SIZE_LARGE
	return SIZE_MONSTER


func clone() -> FishState:
	var copy := FishState.new()
	copy.rod_id = rod_id
	copy.species = species
	copy.weight_kg = weight_kg
	copy.size_class = size_class
	copy.state = state
	copy.stamina = stamina
	copy.drag_rate = drag_rate
	copy.surge_timer = surge_timer
	copy.surge_cooldown = surge_cooldown
	copy.jump_progress = jump_progress
	copy.lift_progress = lift_progress
	copy.hooked_time = hooked_time
	copy.unattended_time = unattended_time
	copy.surfaced = surfaced
	copy.fight_phase = fight_phase
	return copy


func to_dict() -> Dictionary:
	return {
		"rod_id": rod_id,
		"species": species,
		"weight_kg": weight_kg,
		"size_class": size_class,
		"state": state,
		"stamina": stamina,
		"drag_rate": drag_rate,
		"surge_timer": surge_timer,
		"surge_cooldown": surge_cooldown,
		"jump_progress": jump_progress,
		"lift_progress": lift_progress,
		"hooked_time": hooked_time,
		"unattended_time": unattended_time,
		"surfaced": surfaced,
		"fight_phase": fight_phase,
	}


func from_dict(data: Dictionary) -> void:
	rod_id = str(data.get("rod_id", rod_id))
	var next_species := str(data.get("species", SPECIES_PERCH))
	species = next_species if VALID_SPECIES.has(next_species) else SPECIES_PERCH
	weight_kg = maxf(0.01, float(data.get("weight_kg", 0.5)))
	var next_size := str(data.get("size_class", ""))
	size_class = next_size if VALID_SIZE_CLASSES.has(next_size) else compute_size_class(weight_kg)
	var next_state := str(data.get("state", STATE_HOOKED))
	state = next_state if VALID_STATES.has(next_state) else STATE_HOOKED
	stamina = clampf(float(data.get("stamina", 1.0)), 0.0, 1.0)
	drag_rate = maxf(0.0, float(data.get("drag_rate", 0.0)))
	surge_timer = maxf(0.0, float(data.get("surge_timer", 0.0)))
	surge_cooldown = maxf(0.0, float(data.get("surge_cooldown", 2.0)))
	jump_progress = clampf(float(data.get("jump_progress", 0.0)), 0.0, 1.0)
	lift_progress = clampf(float(data.get("lift_progress", 0.0)), 0.0, 1.0)
	hooked_time = maxf(0.0, float(data.get("hooked_time", 0.0)))
	unattended_time = maxf(0.0, float(data.get("unattended_time", 0.0)))
	surfaced = bool(data.get("surfaced", false))
	fight_phase = wrapf(float(data.get("fight_phase", 0.0)), 0.0, TAU)
