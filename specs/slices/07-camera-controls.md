# Slice 07 — Camera Controls & Control Profiles (`07-camera-controls`)

## 0. Tavoite

| Kohta | Arvo |
| :--- | :--- |
| **Nyt voin** | kääntää kameraa (Field of Vision) vapaasti 360° kannella ja ruorissa, kävellä kamerasuuntaisesti, palauttaa näkymän (`R`) ja vaihtaa ohjausprofiilia (`K`: `arrows_wasd` / `wasd_mouse`) |
| **Uusi käsite** | Client-paikallinen, laite-agnostinen `CameraController` + semanttinen ohjausprofiili (`src/view/`) |
| **Riippuvuudet** | `S3` (`03-crew-on-deck`), `S4` (`04-stations`), `S6` (`06-held-items`) |

## 1. Ei kuulu tähän viipaleeseen

- Siimat ja vieheet (`S8`), peliohjaintuki ja täysi näppäinasetus-UI (backlog `xx-gamepad-and-keybinds`)
- Kameran verkkosynkka, ruorikameran sektorirajoitus, kameran törmäyssäde saariin (`S16`)

## 2. State Delta

Ei muutoksia tiedostoon `specs/01-state-schema.md` (`GameState` ja `PlayerInput` pysyvät muuttumattomina — kamera ja ohjausprofiili ovat client-paikallisia).

| Luokka | Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- | :--- |
| `CameraController` | `target_yaw`, `target_pitch`, `target_dist` | `float` | tilakohtainen | Haluttu vene-paikallinen yaw (rad), pitch (deg) ja etäisyys (m) |
| `CameraController` | `current_yaw`, `current_pitch`, `current_dist`, `current_pivot` | `float` / `Vector3` | tilakohtainen | Pehmeästi interpoloitu kameratila (`lerp_angle` + `lerpf`) |

## 3. Rules & Math

- **Laite-agnostinen rajapinta:** `CameraController` vastaanottaa vain normalisoituja akseleita (`yaw_axis`, `pitch_axis`, `zoom_delta`, `reset()`), ilman `Input`- tai näppäinriippuvuuksia (valmis hiirelle ja tulevalle peliohjaimelle).
- **Ohjausprofiilit (`K` / `--controls`, roolit pysyvät samoina kannella ja ruorissa):**
  - `arrows_wasd` *(oletus)*: **Nuolet** = liike (kannella kamerasuuntainen kävely, ruorissa vene), **`WASD`** (+ oikea hiiri) = kamera/PoV.
  - `wasd_mouse`: **`WASD`** = liike (kannella kamerasuuntainen kävely, ruorissa vene), **oikea hiiri** = kamera/PoV.
- **Kamerasuuntainen kävely:** `move_x = sx*cos(y) - sf*sin(y)`, `move_z = -sx*sin(y) - sf*cos(y)` (`y = current_yaw`).
- **Reset & zoom:** `R` (ja hiiren keskinappi) palauttaa kameran pehmeästi tilan oletukseen; hiiren rulla säätää kannen etäisyyttä (`[7.0, 20.0]` m). Tilanvaihto `E` (ruori ↔ kansi) palauttaa uuden tilan oletukseen.
- **Pallokoordinaattikamera:** `fwd = (-cos(p)*sin(y), sin(p), -cos(p)*cos(y))`, `local_pos = current_pivot - fwd * current_dist`, maailmasijainti `boat.world_position + local_pos.rotated(UP, heading)`, rotaatio `(p, wrapf(heading + y, -PI, PI), 0)`. Vapaa 360° yaw molemmissa tiloissa.
- **Regressiohuomio (`S3`):** Kannen oletussuunta katsoo perään (`+Z`, `yaw = PI`, `pitch = -28°`), joten koko kansi ja 25+ m uistelualuetta näkyvät suoraan; toteutuksessa päivitetään `tests/test_03_crew_on_deck.gd` rivi 109 (`heading + PI`).

| Parametri | Arvo | Yksikkö |
| :--- | :--- | :--- |
| `DECK_PIVOT` / `DECK_DEFAULT_YAW_DEG` / `DECK_DEFAULT_PITCH_DEG` | `(0, 1.0, 1.5)` / `180.0` / `-28.0` | m / deg / deg |
| `DECK_DEFAULT_DIST` / `[MIN, MAX]` / `DECK_PITCH_RANGE` | `11.5` / `[7.0, 20.0]` / `[-65.0, -8.0]` | m / m / deg |
| `HELM_DEFAULT_YAW_DEG` / `HELM_DEFAULT_PITCH_DEG` / `HELM_PITCH_RANGE` | `0.0` / `-15.0` / `[-45.0, 25.0]` | deg / deg / deg |
| `YAW_SPEED_DEG` / `PITCH_SPEED_DEG` / `MOUSE_SENS_DEG` / `ZOOM_STEP` | `120.0` / `75.0` / `0.25` / `1.2` | deg/s / deg/s / deg/px / m |

## 4. Headless Acceptance Test

Tiedosto: `tests/test_07_camera_controls.gd` (5 testiä).

- `test_default_deck_and_helm_views_and_mode_switch_reset`: **Given** `WorldView` & `GameState` **When** tila vaihdetaan kansi ↔ ruori (`snap=true`) **Then** kansi katsoo perään (`heading + PI`, `-28°`), ruori eteen (`heading`, `-15°`, `HELM_CAM_OFFSET`) ja tilanvaihto nollaa offsetit.
- `test_camera_360_yaw_pitch_clamping_and_reset`: **Given** `CameraController` kannella ja ruorissa **When** yaw käännetään yli ±180°, pitch yli rajojen ja kutsutaan `reset_to_default()` **Then** 360° yaw kiertää siististi, pitch rajautuu ja reset palauttaa oletukset.
- `test_screen_relative_deck_walk_projection_tracks_camera_yaw`: **Given** `CameraController.project_deck_input` **When** testataan kulmilla `0`, `PI`, `+PI/2`, `-PI/2` **Then** `W` kulkee aina kameran eteen ja `D` 90° oikealle veneen paikallisessa koordinaatistossa.
- `test_control_profiles_and_zoom_clamping`: **Given** `arrows_wasd`- ja `wasd_mouse`-profiilit sekä zoom-/hiirisyötteet **When** syötteet mapataan ruorissa ja kannella **Then** liike- ja PoV-näppäimet pysyvät samoina tilojen välillä, kannen zoom rajautuu `[7.0, 20.0]` m ja ruorin etäisyys pysyy `0.0`.
- `test_camera_stays_client_local_and_updates_hud_controls`: **Given** `GameState` ja `WorldView` **When** paikallista kameraa käännetään ja profiilia vaihdetaan **Then** `GameState.to_dict()` ei sisällä kamerakenttiä, `WorldView` päivittää kameran ja HUD näyttää aktiivisen profiilin ohjeet.

## 5. Manuaalinen verifiointi

- Testaa Offline ja Host+Client molemmilla profiileilla (`K`-vaihto): `arrows_wasd` (Nuolet = liike, `WASD` = PoV) ja `wasd_mouse` (`WASD` = liike, hiiri = PoV) sekä kannella että ruorissa (`E` ei vaihda näppäinrooleja), reset `R`, zoom rullalla ja budjetit (`FPS >= 60`, `Draw Calls < 100`, `Tris < 20 000`).

## 6. Tiedostot

| Polku | Toimenpide | Vastuu |
| :--- | :--- | :--- |
| `src/view/camera_controller.gd` | `[NEW]` | Laite-agnostinen pallokoordinaattikamera, 360° yaw, pitch, zoom, reset, `project_deck_input` ja profiilimappaus |
| `src/view/world_view.gd` | `[MODIFY]` | `CameraController`-integraatio ja aktiivisen profiilin HUD-ohjeteksti |
| `src/main.gd` | `[MODIFY]` | Profiilipohjainen syötteenluku (`arrows_wasd` / `wasd_mouse`, `K`, `--controls`), `R`/keskinappi-reset ja hiiriohjaus |
| `tests/test_03_crew_on_deck.gd` | `[MODIFY]` | Päivitä rivi 109 uuteen kannen oletussuuntaan (`heading + PI`) |
| `tests/test_07_camera_controls.gd` | `[NEW]` | 5 hyväksymistestiä |
