# Slice 07 — Camera Controls & Screen-Relative Walk (`07-camera-controls`)

## 0. Tavoite

| Kohta | Arvo |
| :--- | :--- |
| **Nyt voin** | kääntää kameraa (Field of Vision) vapaasti 360° kannella ja ruorissa, kävellä kamerasuuntaisesti ja palauttaa näkymän oletukseen (`R`) |
| **Uusi käsite** | Client-paikallinen `CameraController` (`src/view/camera_controller.gd`, 0 verkkoreplikointia) |
| **Riippuvuudet** | `S3` (`03-crew-on-deck`), `S4` (`04-stations`), `S6` (`06-held-items`) |

## 1. Ei kuulu tähän viipaleeseen

- Siimat ja vieheet (`S8`), kameran synkronointi verkon yli, ruorikameran kääntösektorin rajoitus (tarvittaessa myöhemmin)
- Kameran törmäyssäde saariin tai esteisiin (`S16`)

## 2. State Delta

Ei muutoksia tiedostoon `specs/01-state-schema.md` (`GameState` ja `PlayerInput` pysyvät muuttumattomina — kamera on client-paikallinen esitystila).

| Luokka | Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- | :--- |
| `CameraController` | `target_yaw`, `target_pitch`, `target_dist` | `float` | tilakohtainen | Haluttu vene-paikallinen yaw (rad), pitch (deg) ja etäisyys (m) |
| `CameraController` | `current_yaw`, `current_pitch`, `current_dist`, `current_pivot` | `float` / `Vector3` | tilakohtainen | Pehmeästi interpoloitu kameratila (`lerp_angle` + `lerpf`) |

## 3. Rules & Math

- **Ohjaus ruorissa (`in_helm == true`):** Nuolinäppäimet (`↑/↓/←/→`) ohjaavat venettä (`throttle`/`steering`); `WASD` kääntää kameraa (`A/D` yaw vasen/oikea, `W/S` pitch ylös/alas).
- **Ohjaus kannella (`in_helm == false`):** `WASD` kävelee **kamerasuuntaisesti** (`move_x = sx*cos(y) - sf*sin(y)`, `move_z = -sx*sin(y) - sf*cos(y)`, missä `y = current_yaw`); nuolinäppäimet (`←/→/↑/↓`) kääntävät kameraa.
- **Reset & hiiri:** `R` palauttaa kameran pehmeästi tilan oletukseen; oikea hiiren nappi pohjassa + veto kääntää kameraa, hiiren rulla säätää kannen zoom-etäisyyttä (`[7.0, 20.0]` m). Tilanvaihto `E` (ruori ↔ kansi) palauttaa uuden tilan oletukseen.
- **Pallokoordinaattikamera:** `fwd = (-cos(p)*sin(y), sin(p), -cos(p)*cos(y))`, `local_pos = current_pivot - fwd * current_dist`. Maailmasijainti `boat.world_position + local_pos.rotated(UP, heading)`, rotaatio `(p, wrapf(heading + y, -PI, PI), 0)`. Molemmissa tiloissa vapaa 360° yaw (`wrapf`).
- **Regressiohuomio (`S3`):** Kannen oletussuunta kääntyy katsomaan perään (`+Z`, `yaw = PI`, `pitch = -28°`), jolloin koko kansi ja perän takaa 25+ m uistelualuetta näkyvät suoraan; toteutuksessa päivitetään `tests/test_03_crew_on_deck.gd` rivi 109 (`heading + PI`).

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
- `test_camera_zoom_clamps_and_mouse_drag_updates_orbit`: **Given** `CameraController` **When** hiiren vetoa ja zoom-rullaa syötetään yli rajojen **Then** kannen etäisyys rajautuu `[7.0, 20.0]` m, ruorin etäisyys pysyy `0.0` ja reset palauttaa oletusetäisyyden.
- `test_camera_stays_client_local_and_updates_hud_controls`: **Given** `GameState` ja `WorldView` **When** paikallista kameraa käännetään **Then** `GameState.to_dict()` ei sisällä kamerakenttiä, `WorldView` päivittää kameran ja HUD näyttää `Nuolet` / `WASD` / `R`-ohjeet.

## 5. Manuaalinen verifiointi

- Testaa Offline ja Host+Client: ruorissa ajo nuolilla + kameran kääntö `WASD`:lla + reset `R`; kannella kamerasuuntainen kävely `WASD`:lla + kamera nuolilla ja hiiren oikealla napilla/rullalla + reset `R`; tarkista ettei toisen ikkunan kamera liiku ja budjetit (`FPS >= 60`, `Draw Calls < 100`, `Tris < 20 000`).

## 6. Tiedostot

| Polku | Toimenpide | Vastuu |
| :--- | :--- | :--- |
| `src/view/camera_controller.gd` | `[NEW]` | Client-paikallinen pallokoordinaattikamera, 360° yaw, pitch, zoom, reset ja `project_deck_input` |
| `src/view/world_view.gd` | `[MODIFY]` | `CameraController`-integraatio ja päivitetty HUD-ohjeteksti |
| `src/main.gd` | `[MODIFY]` | Ruori (Nuolet=ajo, `WASD`=kamera), kansi (`WASD`=kamerasuuntainen kävely, Nuolet=kamera), `R`-reset ja hiiriohjaus |
| `tests/test_03_crew_on_deck.gd` | `[MODIFY]` | Päivitä rivi 109 uuteen kannen oletussuuntaan (`heading + PI`) |
| `tests/test_07_camera_controls.gd` | `[NEW]` | 5 hyväksymistestiä |
