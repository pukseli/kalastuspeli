# Slice 03 — Crew on Deck (`03-crew-on-deck`)

## 0. Tavoite

| Kohta | Arvo |
| :--- | :--- |
| **Nyt voin** | kävellä low-poly 3D-hahmolla kannella veneen mukana kääntyvästä matalasta kamerakulmasta (`-28°`), törmätä muihin pelaajiin, nähdä toiset ikkunat ja säätää testipelaajia (`B` / `--bots`) |
| **Uusi käsite** | Paikallinen kansikoordinaatisto verkon yli (`GameState`, `PlayerState`, `CrewSimulator`, `PlayerView` `BoatView`:n lapsena) |
| **Riippuvuudet** | `S1` (`01-boat-on-water`), `S2` (`02-two-windows-one-boat`) |

## 1. Ei kuulu tähän viipaleeseen

- Toimintopaikat (`Station`), `E`-varaus ja veneen ohjauksen rajaaminen `"helm"`-asemalle (`S4`)
- Vauhtisauva ja ohjauspyörä (`S5`), interpolointi ja viivesimulaatio (`S6`)
- Botti-AI (botit ovat staattisia testinukkeja)

## 2. State Delta

Ks. `specs/01-state-schema.md`. Yksi atominen `GameState`-snapshot per tick (nolla repeilyä veneen ja miehistön välillä, valmis S6-interpoloinnille).

| Luokka | Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- | :--- |
| `PlayerInput` | `move_x`, `move_z` | `float` | `0.0` | Kansikävelysyöte (`-1..1`: `A/D`, `W=-Z` / `S=+Z`) |
| `PlayerState` | `peer_id` | `int` | `1` | Omistajan ID (`>=1` pelaaja, `-1..-3` botti) |
| `PlayerState` | `local_position` | `Vector3` | `(0, 0.25, 0)` | Sijainti veneen paikallisessa koordinaatistossa |
| `PlayerState` | `color_index` | `int` | `0` | Hahmon väri-indeksi (`0..3`) |
| `PlayerState` | `is_bot` | `bool` | `false` | Staattinen testinukke |
| `GameState` | `tick` | `int` | `0` | Simulaation tick-laskuri (valmis S6-interpolointiin) |
| `GameState` | `boat` | `BoatState` | `BoatState.new()` | Veneen maailmatila |
| `GameState` | `players` | `Dictionary` | `{}` | `peer_id: int -> PlayerState` |

## 3. Rules & Math

- **Ohjaus (S3):** `WASD` → `move_x`/`move_z` (absoluuttinen veneen koordinaatisto: `W=-Z` keulaan, `D=+X` oikealle); nuolinäppäimet → `throttle`/`steering`.
- **Kävely & rajaus (`CrewSimulator.step`):** normalisoi `(move_x, move_z)` jos pituus `> 1.0`; `local_position += Vector3(mx, 0, mz) * PLAYER_SPEED * delta`; clamp `x ∈ [-1.3, 1.3]`, `z ∈ [-2.1, 3.0]`, `y = 0.25`.
- **Pelaaja–pelaaja-törmäys:** deterministisessä `peer_id`-järjestyksessä jokaiselle parille, jos XZ-etäisyys `< 2 * PLAYER_RADIUS` (`0.70` m), työnnetään kumpaakin puoliksi erilleen (nollaetäisyydellä `+X`), minkä jälkeen kansi-clamp.
- **Botit (`--bots <0..3>`, `B`-näppäin):** vain authority; `B` kiertää `0 → 1 → 2 → 3 → 0` (oletus `0`). Bottien ID:t `-1..-3` staattisissa spawnpisteissä; synkronoituvat `GameState.players`:ssa.
- **Kamera & 3D-hahmo:** `camera.position = boat.world_position + CAMERA_OFFSET.rotated(Vector3.UP, boat.heading)`, `camera.rotation = Vector3(deg_to_rad(-28.0), boat.heading, 0.0)`. `PlayerView` = mahdollisimman low-poly "muna" (`CapsuleMesh`/`SphereMesh`, `radial_segments=8, rings=4`) `BoatView/PlayersContainer`-alla.

| Parametri | Arvo | Yksikkö |
| :--- | :--- | :--- |
| `PLAYER_SPEED` / `PLAYER_RADIUS` | `4.0` / `0.35` | m/s / m |
| `DECK_BOUNDS_X` / `DECK_BOUNDS_Z` / `DECK_SURFACE_Y` | `[-1.3, 1.3]` / `[-2.1, 3.0]` / `0.25` | m |
| `CAMERA_OFFSET` / `CAMERA_PITCH_DEG` | `(0.0, 7.0, 12.0)` / `-28.0` | m / deg |
| `MAX_BOTS` | `3` | kpl (`0..3`) |

## 4. Headless Acceptance Test

Tiedosto: `tests/test_03_crew_on_deck.gd` (5 testiä).

- `test_player_moves_in_boat_local_space_and_clamps_to_deck`: **Given** pelaaja kannella **When** `move_z = -1.0` ajetaan 120 tickiä **Then** `local_position.z == -2.1` (rajattu keulaan) ja `y == 0.25`.
- `test_player_to_player_collision_separates_overlapping_players`: **Given** kaksi pelaajaa samassa pisteessä **When** `CrewSimulator.step` ajetaan **Then** niiden XZ-etäisyys `>= 0.70` m ja molemmat pysyvät kannen rajojen sisällä.
- `test_bot_count_cli_and_cycle_spawns_and_removes_bots`: **Given** `NetworkManager` **When** `--bots 2` jäsennetään ja `cycle_bot_count()` kutsutaan **Then** `GameState.players` sisältää oikean määrän botteja (`-1..-3`, `is_bot == true`).
- `test_game_state_network_sync_replicates_boat_and_crew`: **Given** Host + Client `NetworkManager` **When** Client lähettää `move_x = 1.0` ja Host tuottaa snapshotin **Then** Clientin `GameState` sisältää päivittyneen veneen ja molemmat pelaajat.
- `test_view_parents_player_to_boat_and_rotates_camera_with_heading`: **Given** `WorldView` ja `GameState` (`boat.heading = PI / 2`) **When** `apply_game_state` kutsutaan **Then** `PlayerView` on `BoatView/PlayersContainer`:n lapsi paikallisessa sijainnissa ja kameran `rotation.y ≈ PI / 2`, `rotation_degrees.x ≈ -28.0`.

## 5. Manuaalinen verifiointi

- Käynnistä Offline sekä Host + Client; kävele `WASD`:lla ja aja venettä nuolinäppäimillä, kierrä botteja `B`:llä (`0..3`), testaa pelaaja–pelaaja-törmäys ja tarkista HUD (`FPS >= 60`, `Draw Calls < 100`, `Tris < 20 000`).

## 6. Tiedostot

| Polku | Toimenpide | Vastuu |
| :--- | :--- | :--- |
| `src/core/state/player_input.gd` | `[MODIFY]` | `move_x`, `move_z` + serialisointi |
| `src/core/state/player_state.gd`, `game_state.gd` | `[NEW]` | `PlayerState` ja yhdistetty `GameState`-snapshot |
| `src/core/simulation/crew_simulator.gd` | `[NEW]` | Kansiliike, rajaus, pelaaja–pelaaja-törmäys, botit |
| `src/network/network_manager.gd` | `[MODIFY]` | `--bots`, `B`-kierto, yhdistetty `GameState`-synkka |
| `src/view/player_view.gd`, `boat_view.gd`, `world_view.gd` | `[NEW]`/`[MODIFY]` | Low-poly muna-hahmo, `PlayersContainer`, `-28°` kääntyvä kamera |
| `src/main.gd` | `[MODIFY]` | `WASD`/nuoli-jako, `B`-näppäin, `GameState`-silmukka |

<!-- Raja: ≤ 60 ei-tyhjää riviä. Jos ylittyy → pilko viipale (00-architecture.md §5). -->
