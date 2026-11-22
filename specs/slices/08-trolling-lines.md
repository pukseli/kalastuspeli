# Slice 08 — Trolling Lines & Planer Boards (`08-trolling-lines`)

## 0. Tavoite

| Kohta | Arvo |
| :--- | :--- |
| **Nyt voin** | laskea siiman veteen (`Q`/`Shift`) ja kelata sisään (`Space`) vapa kädessä tai telineen äärellä sekä nähdä plaanarit, kaarevat siimat ja vieheet viuhkana veneen perässä (vauhdissa levittyen, pysähdyksessä supistuen) |
| **Uusi käsite** | `RodState` (siima, viehe ja `PlanerBoard`-tila) |
| **Riippuvuudet** | `S4`, `S5`, `S6`, `S7` + mekaniikkaspeksi [`planer-boards.md`](../02-mechanics/planer-boards.md) |

## 1. Ei kuulu tähän viipaleeseen

- Tärppi ja kalan kelaus (`S9`), haavitus ja plaanarin irrotuslukko (`S10`)
- Siiman kireys/katkeaminen (`S11`), sotkun selvitys kannella ja uisteluikkunan kaasukalibrointi (`S12`)
- Siimojen pujotus (`S13`) ja maailman saaret/karikot (`S16`, tässä vain puhdas esterajapinta yksikkötesteille)

## 2. State Delta

Ks. `specs/01-state-schema.md`. `PlanerBoard.line_out` on ainoa siimanpituuden totuuden lähde.

| Luokka | Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- | :--- |
| `PlanerBoard` | `side`, `attached`, `lateral_offset`, `line_out`, `state`, `snag_world_position` | `int`, `bool`, `float`, `float`, `String`, `Vector2` | `1`, `true`, `0.0`, `0.0`, `"STOWED"`, `ZERO` | Plaanarin puoli (`-1`/`+1`), kiinnitys, sivuetäisyys, siima (m), tila ja esteankkuri |
| `RodState` | `rod_id`, `trail_angle`, `trail_factor`, `planer` | `String`, `float`, `float`, `PlanerBoard` | `""`, `0.0`, `0.0`, `new()` | Vavan tila, suoran siiman kulmahitaus, paikallaan supistuminen ja plaanari |
| `GameState` | `rods` | `Dictionary` | `{}` | `rod_id: String -> RodState` (synkronoitu `items`-vapoihin) |
| `PlayerInput` | `line_input` | `float` | `0.0` | Siimansäätö (`+1.0` ulos `Q`/`Shift`, `-1.0` sisään `Space`) |

## 3. Rules & Math

- **Säätö ja elinkaari:** Kaikki vavat alkavat `line_out = 0.0` (`STOWED`). Portaaton säätö `8.0 m/s` välillä `[0.0, 35.0] m` toimii molemmissa ohjausprofiileissa sekä vapa kädessä että tyhjin käsin lähimmän varatun telineen äärellä (1 toimija/vapa/tick). Vavan poiminta, vaihto (`swap`) ja disconnect säilyttävät siiman tilan.
- **Telinekulmat (`ItemConfig`):** `-3/+3` (`±55°`, `attached = true`), `-2/+2` (`±38°`, `attached = true`), perävavat `-1/+1` (`±8°`, `attached = false` suora siima kulmahitauksella `trail_angle`).
- **Plaanarifysiikka (`RodSimulator`):** $v_{\text{board}} = v_{\text{fwd}} + \omega \cdot \text{lateral\_offset}$. Kun $v_{\text{board}} \ge 0.8\text{ m/s}$, plaanari levittyy kohti `side * p * min(22.0, line_out * sin(spread_angle))` suhteessa kulmaansa; kun $v_{\text{board}} < 0.8\text{ m/s}$, se supistuu kohti `0.0`. `trail_factor` supistaa paikallaan vaakaprojektiota (`0.18..1.0`).
- **Sotku, este & bonus:** Samalla puolella `board_tangle_distance <= 1.5 m`, leikkaavat siimat tai kylkisakkaus `< 1.2 m` (`abs(omega) >= 0.35`) vaihtavat tilaksi `TANGLED`; 2D-ympyräesteosuma vaihtaa tilaksi `SNAGGED` (`snag_world_position`). `TROLLING`-plaanari sivulla `>= 4.0 m` antaa `1.2×`-tärppikertoimen.
- **Verkko & näkymä:** `SnapshotInterpolator` interpoloi jatkuvat kentät (`line_out`, `lateral_offset`, `trail_angle`, `trail_factor`) ja lukee diskreetit uusimmasta snapshotista. `WorldView` piirtää siimat yhdellä `ImmediateMesh`illä (`1` draw call), plaanarit + liput sekä värikoodatut vieheet ja näyttää `Vedessä: X/Y` + `line_prompt_label` rikkomatta `prompt_label`-tekstiä.

## 4. Headless Acceptance Test

Tiedostot: `tests/test_08_trolling_lines.gd` (5 testiä) ja `tests/test_planer_boards.gd` (4 testiä).

- `test_deploy_reel_at_holder_and_in_hand_and_carry_preserves_line`: **Given** 6 vapaa ylhäällä **When** lasketaan/kelataan telineellä, poimitaan käteen, vaihdetaan ja katkaistaan yhteys **Then** säätö toimii, 1 toimija/tick lukittuu ja siimapituus säilyy.
- `test_boat_speed_spreads_planer_fan_and_stop_collapses_offset`: **Given** lasketut kylki- ja perävavat **When** vene ajaa eteenpäin (`3.0 m/s`) ja sitten pysähtyy **Then** plaanarit levittäytyvät puolilleen (`TROLLING`) ilman väärää sotkua ja valuvat pysähdyksessä sisään.
- `test_straight_line_angular_lag_and_bite_bonus_api`: **Given** suora perävapa ja levitetty plaanari **When** vene kääntyy ja sitten kulkee suoraan **Then** `trail_angle` laahaa, pidempi siima oikenee hitaammin ja `TROLLING`-plaanari antaa `1.2×` kertoimen.
- `test_rods_replicate_over_network_and_interpolate_smoothly`: **Given** Host/Client ja `SnapshotInterpolator` **When** asiakas laskee siimaa ja snapshoteja interpoloidaan **Then** `rods` replikoituu, jatkuvat kentät interpoloituvat ja diskreetit seuraavat uusinta.
- `test_world_view_renders_lines_planers_lures_and_updates_hud`: **Given** `WorldView` tyhjillä ja lasketuilla vavoilla **When** tila renderöidään **Then** `ImmediateMesh` käyttää `1` surfacea, plaanarit/vieheet näkyvät, HUD näyttää `Vedessä: 2/6` ja `line_prompt_label` päivittyy.

## 5. Manuaalinen verifiointi

- Testaa yhdessä ikkunassa ja kahdessa ikkunassa (`--host` / `--join`): aseta ruorista uistelukaasu, poistu kannelle, laske kylkivapojen plaanarit (`Q`/`Shift`) ja perävavat, säädä pituutta (`Space`), nosta vedessä oleva vapa ja kävele kannella, pysäytä vene ja tee jyrkkä käännös; tarkista budjetit (`FPS >= 60`, `Draw Calls < 100`, `Tris < 20 000`).

## 6. Tiedostot

| Polku | Toimenpide | Vastuu |
| :--- | :--- | :--- |
| `src/core/state/planer_board.gd` | `[NEW]` | `PlanerBoard`-tietomalli ja serialisointi |
| `src/core/state/rod_state.gd` | `[NEW]` | `RodState`-tietomalli ja serialisointi |
| `src/core/state/player_input.gd` | `[MODIFY]` | `line_input`-akseli (`-1.0 .. 1.0`) |
| `src/core/simulation/item_config.gd` | `[MODIFY]` | Telineiden `spread_angle_deg` ja `default_planer_attached` |
| `src/core/state/game_state.gd` | `[MODIFY]` | `GameState.rods`, synkronointi `items`:iin ja serialisointi |
| `src/core/simulation/rod_simulator.gd` | `[NEW]` | Siiman säätö, plaanari-/kulmahitausfysiikka, sotku-, este- ja sijaintilaskenta |
| `src/network/network_manager.gd` | `[MODIFY]` | `line_input`-välitys ja `RodSimulator`-tick |
| `src/network/snapshot_interpolator.gd` | `[MODIFY]` | `rods`-tilan pehmeä + diskreetti interpolointi |
| `src/view/world_view.gd` | `[MODIFY]` | `ImmediateMesh`-siimat, greybox-plaanarit, vieheet ja HUD/`line_prompt_label` |
| `src/main.gd` | `[MODIFY]` | `Q`/`Shift`/`Space`-syöte ja `RodSimulator`-kytkentä |
| `tests/test_08_trolling_lines.gd` | `[NEW]` | 5 viipaleen hyväksymistestiä |
| `tests/test_planer_boards.gd` | `[NEW]` | 4 determinististä plaanarimekaniikkatestiä |
