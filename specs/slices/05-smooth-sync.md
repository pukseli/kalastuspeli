# Slice 05 — Smooth Sync (`05-smooth-sync`)

## 0. Tavoite

| Kohta | Arvo |
| :--- | :--- |
| **Nyt voin** | nähdä veneen ja toisten pelaajien liikkuvan ilman nykimistä 100 ms viiveellä |
| **Uusi käsite** | Snapshot-interpolointi (viivesimulaatio testityökaluna) |
| **Riippuvuudet** | `S2` (`02-two-windows-one-boat`), `S3` (`03-crew-on-deck`), `S4` (`04-stations`) |

## 1. Ei kuulu tähän viipaleeseen

- Client-ennustus ja täsmäytys (`xx-client-prediction` backlogissa)
- Ekstrapolointi (dead reckoning) puskurin kuivuessa
- Uudet pelimekaniikat tai replikoitavat `GameState`-kentät (`S6+`)

## 2. State Delta

Ks. `specs/01-state-schema.md`. Ei uusia replikoitavia `GameState`-kenttiä (`GameState.tick` käytössä).

| Luokka | Polku | Kuvaus |
| :--- | :--- | :--- |
| `SnapshotInterpolator` | `src/network/snapshot_interpolator.gd` | Puhdas `RefCounted`-puskuri ja aikapohjainen `GameState`-interpolointi |

## 3. Rules & Math

- **Aikaleima & puskuri (`SnapshotInterpolator`):** Snapshotien simulaatioaika `sim_time = tick * FIXED_DELTA` (`1/60 s`). Duplikaatti- ja vanhentuneet tickit (`tick <= last_tick`) hylätään; puskurin maksimikoko `32`.
- **Mukautuva puskuriviive:** `current_delay = clampf(maxf(MIN_INTERP_DELAY, measured_interval * 2.0), MIN_INTERP_DELAY, MAX_INTERP_DELAY)`, jossa `measured_interval` lasketaan peräkkäisten snapshotien `tick`-erosta (`20 Hz -> 100 ms`, `10 Hz -> 200 ms`, `5 Hz -> 400 ms`).
- **Interpolointi & kulmakäärintä:** Etsitään `render_time`-hetkeä ympäröivät snapshotit `A` ja `B` (`t = clampf((render_time - tA) / (tB - tA), 0.0, 1.0)`). `BoatState`: `world_position` / `velocity` (`lerp`), `heading` (`lerp_angle` `[-PI, PI]`-rajan yli), skalaarit (`forward_speed`, `angular_velocity`, `throttle`, `steering_angle`) (`lerpf`). `PlayerState`: `local_position` (`lerp`) molemmissa snapshoteissa oleville pelaajille; uudet/poistuneet pelaajat ja metatiedot (`color_index`, `is_bot`) snapshotista `B`.
- **Underrun & diskreetit kentät:** Jos `render_time` ylittää uusimman snapshotin, pysytään viimeisimmässä tilassa (clamp `t = 1.0`, ei ekstrapolointia). `stations` (ja `in_helm`-ohjaustila) luetaan aina uusimmasta saapuneesta snapshotista. Client ajaa interpoloinnin `_physics_process`:ssa (`FIXED_DELTA`); Host/Offline ei interpoloi.
- **Kellon synkronointi:** Ensimmäinen snapshot alustaa `render_time = t0 - current_delay`. Suuri ero (`|error| > 0.5 s`) napsauttaa kellon kohteeseen; pienempi poikkeama (`|error| > 0.05 s`) korjataan pehmeästi (`±25 %` per `delta`).
- **Viivesimulaatio (`NetworkManager`, vain `test`-profiili):** Client-puolen symmetrinen RTT-viivejono (etenee `FIXED_DELTA`:lla, deterministinen): lähtevät syötteet/reliable `interact` ja saapuvat snapshotit viivästyvät `maxf(0.0, sim_latency_ms * 0.5 + jitter)` ms. CLI: `--latency <ms>`, `--jitter <ms>`. Pikanäppäimet (`debug_hotkeys`): `L` kiertää `[0/0, 100/15, 200/30]` ms, `I` kytkee interpoloinnin ON/OFF. `prod`-profiilissa viive/jitter on aina `0` ja interpolointi aina `ON`. `apply_game_snapshot()` säilyttää suoran käytöksensä (S3/S4-regressio).

| Parametri | Arvo | Yksikkö |
| :--- | :--- | :--- |
| `MIN_INTERP_DELAY` / `MAX_INTERP_DELAY` | `0.1` / `0.6` | s |
| `BUFFER_INTERVAL_MULTIPLIER` / `MAX_BUFFER_SIZE` | `2.0` / `32` | kerroin / kpl |
| `LATENCY_PRESETS` (RTT / ±jitter) | `[0/0, 100/15, 200/30]` | ms |

## 4. Headless Acceptance Test

Tiedosto: `tests/test_05_smooth_sync.gd` (5 testiä).

- `test_boat_position_and_wrapped_heading_interpolate_smoothly`: **Given** kaksi snapshotia joiden `heading` ylittää `-PI/+PI`-rajan **When** `sample_at` ajetaan puolivälissä (`t = 0.5`) **Then** `world_position`, `heading` (lyhin kaari) ja nopeuskentät interpoloituvat tarkasti.
- `test_players_interpolate_in_local_space_while_stations_use_latest`: **Given** liikkuvat pelaajat ja uusi `stations["helm"]`-varaus tuoreimmassa snapshotissa **When** interpolaattoria askelletaan **Then** pelaajien `local_position` interpoloituu ja `stations` vastaa uusinta snapshotia.
- `test_out_of_order_ticks_ignored_and_underrun_clamps_without_overshoot`: **Given** puskuri johon syötetään vanha/duplikaatti tick ja aika etenee yli uusimman snapshotin **When** `step` ajetaan **Then** vanhat tickit hylätään ja tila pysähtyy viimeisimpään snapshotiin ilman ekstrapolointia.
- `test_adaptive_delay_scales_with_tick_interval_and_smooths_jitter`: **Given** `20 Hz` ja `5 Hz` snapshot-välit sekä epätasaisesti (jitterillä) saapuvat snapshotit **When** interpolaattoria askelletaan `FIXED_DELTA`:lla **Then** puskuriviive mukautuu (`100 ms` / `400 ms`) ja veneen sijainti etenee tasaisesti ilman hyppyjä.
- `test_latency_simulator_delays_client_traffic_and_is_disabled_in_prod`: **Given** Client `NetworkManager` (`--latency 100 --jitter 0`) sekä `prod`-profiili **When** `step_game_tick` ajetaan **Then** syötteet (ml. `interact`) ja snapshotit viivästyvät `50 ms` / suunta testitilassa, mutta `prod` pakottaa viiveen nollaan ja interpoloinnin päälle.

## 5. Manuaalinen verifiointi

- Käynnistä Host (`-- --host`) ja Client (`-- --join 127.0.0.1 --latency 100 --jitter 15`). Aja venettä ja kävele kannella; paina Clientissa `I` (interpolointi OFF → näkyvä nykiminen, ON → sulava liike), `L` (viiveprofiilit) ja Hostissa `T` (`5–60 Hz`). Tarkista debug-HUDista viive/interpolointitila sekä budjetit (`FPS >= 60`, `Draw Calls < 100`, `Tris < 20 000`).

## 6. Tiedostot

| Polku | Toimenpide | Vastuu |
| :--- | :--- | :--- |
| `src/network/snapshot_interpolator.gd` | `[NEW]` | `SnapshotInterpolator` (puskuri, mukautuva viive, `lerp` / `lerp_angle`) |
| `src/network/network_manager.gd` | `[MODIFY]` | `--latency`/`--jitter`, `L`/`I`-tilat, deterministinen viivejono, `prod`-suoja |
| `src/main.gd` | `[MODIFY]` | Clientin `SnapshotInterpolator`-kytkentä, `latest` vs `render` tila, `L`/`I`-näppäimet |
| `src/view/world_view.gd` | `[MODIFY]` | Debug-HUD: viive, jitter, interpolointitila ja `L`/`I`-vihjeet |
| `tests/test_05_smooth_sync.gd` | `[NEW]` | 5 hyväksymistestiä |

<!-- Raja: <= 60 ei-tyhjää riviä. Jos ylittyy -> pilko viipale (00-architecture.md §5). -->
