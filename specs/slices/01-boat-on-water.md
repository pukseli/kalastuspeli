# Slice 01 — Boat on Water (`01-boat-on-water`)

## 0. Tavoite

| Kohta | Arvo |
| :--- | :--- |
| **Nyt voin** | ajaa venettä järvellä yhdessä ikkunassa |
| **Uusi käsite** | Core (`BoatState`, `PlayerInput`, `BoatSimulator`) + 3D-näkymän runko (`WorldView`, `BoatView`) |
| **Riippuvuudet** | `S0` (Ympäristö ja perusta) |

## 1. Ei kuulu tähän viipaleeseen

- Pelaajakapselit ja kansikävely (`S3`)
- Verkkosynkronointi (`S2`) ja Lobby UI (`S6`)
- Kalastusmekaniikat (`S7`) ja AI Director

## 2. State Delta

Ks. `specs/01-state-schema.md`.

| Luokka | Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- | :--- |
| `BoatState` | `world_position` | `Vector3` | `Vector3.ZERO` | Veneen sijainti maailmankoordinaatistossa |
| `BoatState` | `heading` | `float` | `0.0` | Keulan suunta radiaaneina (`0` = `-Z` eteenpäin) |
| `BoatState` | `forward_speed` | `float` | `0.0` | Etenemisnopeus (m/s) |
| `PlayerInput` | `throttle` | `float` | `0.0` | Kaasusyöte (`-1.0 .. 1.0`, erillään tilasta) |
| `PlayerInput` | `steering` | `float` | `0.0` | Ohjaussyöte (`-1.0 .. 1.0`, `+1` vasen, `-1` oikea) |

## 3. Rules & Math

- Kiinteä aika-askel: `BoatSimulator.step(boat: BoatState, input: PlayerInput, delta: float = FIXED_DELTA)`.
- Jos `absf(throttle) > 0.001`: `forward_speed += clampf(throttle, -1.0, 1.0) * BOAT_ACCEL * delta`, muuten `move_toward(forward_speed, 0.0, BOAT_WATER_DRAG * delta)`.
- `forward_speed = clampf(forward_speed, BOAT_MAX_REVERSE_SPEED, BOAT_MAX_SPEED)`.
- `heading += clampf(steering, -1.0, 1.0) * BOAT_TURN_SPEED * delta`.
- `forward_dir = Vector3(-sin(heading), 0.0, -cos(heading))` -> `world_position += forward_dir * forward_speed * delta`.

| Parametri | Arvo | Yksikkö |
| :--- | :--- | :--- |
| `FIXED_DELTA` | `1.0 / 60.0` | s |
| `BOAT_ACCEL` | `6.0` | m/s² |
| `BOAT_MAX_SPEED` | `8.0` | m/s |
| `BOAT_MAX_REVERSE_SPEED` | `-3.0` | m/s |
| `BOAT_WATER_DRAG` | `2.5` | m/s² |
| `BOAT_TURN_SPEED` | `1.2` | rad/s |

## 4. Headless Acceptance Test

Tiedosto: `tests/test_01_boat_on_water.gd` (5 testiä).

- `test_boat_accelerates_and_clamps_max_speed`: **Given** paikallaan oleva vene **When** `throttle = 1.0` ajetaan 120 tickiä **Then** `forward_speed == 8.0` ja `world_position.z < -10.0`.
- `test_water_drag_stops_boat`: **Given** `forward_speed = 5.0` **When** `throttle = 0.0` ajetaan 180 tickiä **Then** `forward_speed == 0.0`.
- `test_boat_steering_changes_heading_and_direction`: **Given** `throttle = 1.0, steering = 1.0` **When** ajetaan 60 tickiä **Then** `heading > 0.0` ja `world_position.x < 0.0`.
- `test_boat_state_serialization_roundtrip`: **Given** muokattu `BoatState` ja `PlayerInput` **When** `to_dict()` / `from_dict()` kutsutaan **Then** kentät säilyvät identtisinä.
- `test_world_and_boat_view_sync_transform`: **Given** `WorldView` **When** `apply_state(boat)` kutsutaan **Then** `boat_view.position == boat.world_position` ja `boat_view.rotation.y == boat.heading`.

## 5. Manuaalinen verifiointi

- Käynnistä peli (`godot --path .`), aja venettä `WASD`- tai nuolinäppäimillä poijujen välissä ja tarkista debug-HUDista: `FPS >= 60`, `Draw Calls < 100`, `Triangles < 20 000`.

## 6. Tiedostot

| Polku | Toimenpide | Vastuu |
| :--- | :--- | :--- |
| `src/core/state/boat_state.gd` | `[NEW]` | `BoatState` + `to_dict` / `from_dict` |
| `src/core/state/player_input.gd` | `[NEW]` | `PlayerInput` + `to_dict` / `from_dict` |
| `src/core/simulation/boat_simulator.gd` | `[NEW]` | `BoatSimulator` (60 Hz veneliike) |
| `src/view/boat_view.gd` | `[NEW]` | Proseduraalinen low-poly laatikkovene |
| `src/view/world_view.gd` | `[NEW]` | Vesi, poijut, suuntavalo, seuraintakamera, debug-HUD |
| `src/main.gd` & `src/main.tscn` | `[NEW]` | Juurisolmu, `_physics_process` syöte + simulaatio |
| `project.godot` | `[MODIFY]` | `run/main_scene="res://src/main.tscn"` |

<!-- Raja: ≤ 60 ei-tyhjää riviä. Jos ylittyy → pilko viipale (00-architecture.md §5). -->
