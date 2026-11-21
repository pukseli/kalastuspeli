# Slice 04 — Stations & Helm (`04-stations`)

## 0. Tavoite

| Kohta | Arvo |
| :--- | :--- |
| **Nyt voin** | kävellä ohjaamon äärelle, tarttua ruoriin (`E`), kokea ohjaamonäkymä kamerasta, säätää veneen kaasua ja kääntökulmaa jotka jäävät voimaan myös ruorista poistuttaessa (`E`) |
| **Uusi käsite** | Toimintopaikkajärjestelmä ja ruoriohjaus (`StationConfig`, `StationSimulator`, `GameState.stations`, ohjaamonäkymä) |
| **Riippuvuudet** | `S1` (`01-boat-on-water`), `S2` (`02-two-windows-one-boat`), `S3` (`03-crew-on-deck`) |

## 1. Ei kuulu tähän viipaleeseen

- Vapa-asemat ja kalastusmekaniikka (`S8`)
- Monimutkainen verkkointerpolointi tai viivesimulaatio (`S6`)
- UI-mittaristot ja analogiset viisarit

## 2. State Delta

Ks. `specs/01-state-schema.md`.

| Luokka | Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- | :--- |
| `PlayerInput` | `interact` | `bool` | `false` | Aseman varaus/vapautus (`E`-näppäin) |
| `GameState` | `stations` | `Dictionary` | `{"helm": 0}` | Asemat: `station_id: String -> occupant_peer_id: int` |

## 3. Rules & Math

- **Asemakonfiguraatio (`StationConfig`):** Ruori `"helm"`, `local_position = Vector3(0.0, 0.25, -0.6)`, `radius = 1.0`.
- **Varaus & vapautus (`StationSimulator.step`):**
  - Jos pelaaja antaa `interact = true` ja etäisyys ruoriin `< radius` ja ruori on vapaa (`occupant == 0`), hänet lukitaan ruoriin (`stations["helm"] = peer_id`).
  - Jos ruorissa oleva pelaaja antaa `interact = true`, ruori vapautuu (`stations["helm"] = 0`).
  - Pelaajan poistuessa pelistä (`remove_player`), hänen varaamansa asema vapautuu automaattisesti (`occupant = 0`).
- **Ruorissa olo ja ohjaus:**
  - Ruorissa olevan pelaajan `local_position` lukittuu ruorin sijaintiin eikä liiku kansikävelyllä.
  - Vain ruorissa olevan pelaajan syötteet säätävät veneen kaasua ja kääntökulmaa (`BoatSimulator.step`).
  - **Säilyvä tila:** Kaasu ja kääntökulma säilyvät nykyisessä asennossaan näppäimen vapauduttua ja ruorista poistuttaessa. Vene jatkaa matkaa nykyisellä tilallaan.
- **Kamera & View:**
  - Kun paikallinen pelaaja on ruorissa, kamera siirtyy ohjaamonäkymään (`Vector3(0.0, 2.0, 1.2)`, pitch `-15°`). Muulloin kansinäkymä (`(0, 7, 12)`, `-28°`).
  - 3D-kannella näkyy ohjauspulpetti. HUD näyttää tilannekohtaisen kehotteen `[E] Tartu ruoriin` tai `[E] Irrota ote`.

| Parametri | Arvo | Yksikkö |
| :--- | :--- | :--- |
| `HELM_LOCAL_POS` | `(0.0, 0.25, -0.6)` | Vector3 |
| `HELM_INTERACTION_RADIUS` | `1.0` | m |
| `HELM_CAM_OFFSET` / `HELM_CAM_PITCH_DEG` | `(0.0, 2.0, 1.2)` / `-15.0` | m / deg |

## 4. Headless Acceptance Test

Tiedosto: `tests/test_04_stations.gd` (5 testiä).

- `test_interact_within_radius_occupies_helm`: **Given** pelaaja ruorin lähellä **When** `interact = true` **Then** ruori varataan ja pelaaja lukittuu ruoriin.
- `test_interact_again_releases_helm`: **Given** pelaaja ruorissa **When** `interact = true` **Then** ruori vapautuu ja pelaaja voi liikkua.
- `test_only_helm_occupant_steers_boat`: **Given** kaksi pelaajaa, toinen ruorissa **When** molemmat antavat ohjaussyötteitä **Then** vain ruorissa olevan syöte muuttaa venettä.
- `test_boat_retains_throttle_and_steering_when_helm_vacated`: **Given** vene kiihdytetty ruorista **When** pelaaja poistuu ruorista **Then** vene säilyttää kaasun ja kääntökulman.
- `test_disconnect_frees_occupied_station`: **Given** pelaaja ruorissa **When** pelaaja poistetaan **Then** asema vapautuu (`occupant = 0`).

## 5. Manuaalinen verifiointi

- Kävele pulpettia kohti → HUD näyttää `[E] Tartu ruoriin`.
- Paina `E` → Kamera siirtyy ohjaamonäkymään tuulilasin taakse, hahmo pysyy ruorissa.
- Kiihdytä ja käännä nuolilla → Vene kääntyy ja kiihtyy.
- Paina `E` → Hahmo irrottaa otteen, kamera palaa ylös, vene jatkaa ajamista kääntyen ja kulkien annetulla teholla.

## 6. Tiedostot

| Polku | Toimenpide | Vastuu |
| :--- | :--- | :--- |
| `src/core/state/player_input.gd` | [MODIFY] | `interact`-kenttä |
| `src/core/state/game_state.gd` | [MODIFY] | `stations`-sanakirja ja synkronointi |
| `src/core/simulation/station_config.gd` | [NEW] | Ruorin staattiset koordinaatit ja säde |
| `src/core/simulation/station_simulator.gd` | [NEW] | Asemien varaus, lukitus ja ohjauskytkentä |
| `src/network/network_manager.gd` | [MODIFY] | Syötteiden ja aseman hallinta tickissä |
| `src/view/boat_view.gd` | [MODIFY] | Ohjauspulpetti 3D-kannelle |
| `src/view/world_view.gd` | [MODIFY] | Ohjaamonäkymäkamera ja HUD-kehote |
| `src/main.gd` | [MODIFY] | `E`-interaktiosyöte ja ohjaamonäkymän tila |
| `tests/test_04_stations.gd` | [NEW] | 5 hyväksymistestiä |
