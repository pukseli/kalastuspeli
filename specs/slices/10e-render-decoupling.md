# Slice 10e — Renderöinnin irrotus fysiikkatickistä (`10e-render-decoupling`)

## 0. Tavoite

| Kohta | Arvo |
| :--- | :--- |
| **Nyt voin** | pelata 120/144 Hz:n näytöllä ilman 60 Hz:n mikronykimistä ja heikolla koneella ilman että fysiikkasilmukka piirtää näkymän useita kertoja saman framen sisällä |
| **Uusi käsite** | Render-interpolaatio (`RenderInterpolator` + `_process(delta)`-päivitys) |
| **Riippuvuudet** | `S1`, `S3`, `S7`, `10d` |

## 1. Ei kuulu tähän viipaleeseen

- Asiakaspuolen syöte-ennustus (`xx-client-prediction`)
- Materiaalimuutosten dirty-laskurit (`10f`)

## 2. State Delta

Ks. `specs/01-state-schema.md`. Ei muutoksia `GameState`-verkkoskeemaan (vain näkymäkerros `src/view/`).

| Luokka | Kenttä / Metodi | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- | :--- |
| `RenderInterpolator` | `capture(state)` / `blend(alpha)` | `RefCounted` | — | Interpoloi kahden peräkkäisen fysiikkatickin välisen veneen ja pelaajien sijainnin (`alpha` $\in [0, 1]$) |
| `CameraController` | `step(snap, delta)` | `void` | `1/60` | Framerate-riippumaton eksponentiaalinen kameran pehmennys |
| `WorldView` | `update_frame(blend, delta)` | `void` | — | Päivittää veneen, pelaajat, siimakontin, kameran ja räikän `_process(delta)`-tahdissa |

## 3. Rules & Math

- Eksponentiaalinen vaimennuskerroin ajalla $\Delta t$: $\alpha(\Delta t) = 1 - (1 - k)^{60 \cdot \Delta t}$, jolloin $\Delta t = 1/60 \implies \alpha = k$.
- `_physics_process` ajaa vain simulaation ja `render_interp.capture(display_state)` sekä merkitsee `_tick_dirty = true` (nolla näkymä- tai HUD-kutsua fysiikkatickissä).
- `_process(delta)` ajaa `apply_game_state` korkeintaan kerran visuaalista framea kohden (kun `_tick_dirty`) ja `update_frame(render_interp.blend(fraction), delta)` jokaisella framella.
- `trolling_lines_container.transform = blended_boat_xform * tick_boat_xform.affine_inverse()`, jolloin siimat, plaanarit ja kalat liikkuvat sulavasti veneen mukana tickien välillä.

## 4. Headless Acceptance Test

Tiedosto: `tests/test_10e_render_decoupling.gd` (5 testiä).

- `test_given_two_captures_when_blend_half_then_boat_pos_and_heading_midpoint_with_pi_wrap`
- `test_given_players_when_blend_then_local_positions_lerped_and_new_player_snaps`
- `test_given_camera_when_stepped_60hz_vs_144hz_then_same_result_within_eps`
- `test_given_world_view_when_update_frame_then_boat_players_and_lines_container_follow_blend`
- `test_given_raikka_when_frame_delta_varies_then_cooldown_scales_with_delta`

## 5. Manuaalinen verifiointi

- 144 Hz:n näytöllä kamera ja vene liikkuvat pehmeästi; `--fps-max 30` -ajossa näkymä päivittyy vain kerran framessa.

## 6. Tiedostot

| Polku | Toimenpide | Vastuu |
| :--- | :--- | :--- |
| `src/view/render_interpolator.gd` | `[NEW]` | Peräkkäisten fysiikkatickien välinen tilainterpolointi |
| `src/view/camera_controller.gd` | `[MODIFY]` | `step(snap, delta)` framerate-riippumattomalla vaimennuksella |
| `src/view/boat_view.gd` | `[MODIFY]` | `apply_frame(pos, heading, delta)` `delta`-pohjaisella kallistuksella |
| `src/view/world_view.gd` | `[MODIFY]` | `update_frame(blend, delta)` ja `delta`-pohjainen räikkäajastin |
| `src/main.gd` | `[MODIFY]` | Näkymäpäivityksen siirto `_physics_process`:sta `_process(delta)`:iin |
| `tests/test_10e_render_decoupling.gd` | `[NEW]` | Viipaleen 10e hyväksymistestit |
