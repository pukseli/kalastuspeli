# Slice 10 — Landing Net & Catch Log (`10-landing-net-and-catch`)

## 0. Tavoite

| Kohta | Arvo |
| :--- | :--- |
| **Nyt voin** | poimia keskikannella lojuvan haavin (`E`), pudottaa sen vapaasti kannelle (`E`), kauhaista laidalla olevan kalan (`Space`, onnistuminen kalan väsymyksen mukaan) ja nähdä tiimin saalislaskurin HUDissa |
| **Uusi käsite** | Haavi (`HeldItem` `"net"` + vapaa kansisijainti `deck_position`) ja tiimin saalisloki (`GameState.catches`) |
| **Riippuvuudet** | `S6`, `S9a`, `S9b` |

## 1. Ei kuulu tähän viipaleeseen

- Kalasumppuun kippaaminen / perkaaminen (kalan käsittely päättyy heti haavitukseen)
- Syvempi kalan väsytysmekaniikka (`S11b`), siiman kireys/katkeaminen (`S11`), ulkolaitapakko (`S13`)

## 2. State Delta

Ks. `specs/01-state-schema.md`.

| Luokka | Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- | :--- |
| `HeldItem` | `deck_position` | `Vector3` | `Vector3.ZERO` | Esineen kansisijainti, kun `carrier_peer_id == 0` ja `holder_id == ""` |
| `FishState` | `scoop_progress` | `float` | `0.0` | Haavituksen `Space`-pitomittari (`0.0 .. 1.0`) |
| `GameState` | `catches` | `Array` | `[]` | Saalisloki (`{species, weight_kg, size_class, method}` per kala) |

## 3. Rules & Math

| Parametri | Arvo | Yksikkö |
| :--- | :--- | :--- |
| `DEFAULT_NET_COUNT` / `DEFAULT_NET_DECK_POS` | `1` / `(0.0, 0.25, 0.6)` | kpl / m |
| `deck_pickup_radius` / `scoop_radius` | `0.95` / `1.6` | m |
| `scoop_hold_duration` / `scoop_decay_rate` | `0.4` / `1.8` | s / s⁻¹ |
| `scoop_tired_stamina` / `scoop_fail_bolt_line` | `0.1` / `5.0` | — / m |

- **Haavi kannella (`ItemConfig` & `ItemSimulator`):** Veneessä on `1` haavi (`"net_1"`, `item_type = "net"`), joka alkaa keskikannelta. Tyhjäkäsin `E` poimii kannelta lähimmän esineen (`<= 0.95 m`); haavi kädessä `E` pudottaa sen pelaajan kansisijaintiin (`clamp` kävelyalueelle) koskematta vapatelineisiin. Disconnect pudottaa haavin pelaajan sijaintiin. `create_default_config(rod_count, net_count = 0)` säilyttää S6-testiyhteensopivuuden; `main.gd` käyttää `DEFAULT_NET_COUNT`.
- **Kauhaus & väsymys (`FishSimulator`):** Haavi kädessä `Space` (`line_input < -0.1`) täyttää lähimmän `READY_TO_LAND`-kalan (kaverin kädestä tai telineestä, `<= 1.6 m`) `scoop_progress`-mittarin (`0.4 s`). Täyttyessä väsynyt kala (`stamina <= 0.1`) nousee aina `100 %`; virkeällä (`stamina > 0.1`) epäonnistumisriski on `lerpf(0.15, 0.85, (stamina - 0.1) / 0.9)`. Epäonnistuessa kala syöksähtää takaisin (`HOOKED`, `+5.0 m` siimaa, `surge_timer = 1.2 s`).
- **Saalis & HUD:** Onnistunut haavitus (ja S9a-nosto ilman haavia) kirjaa kalan `GameState.catches`-listaan ja nollaa vavan `STOWED`-tilaan; haavi jää vapaaksi käteen. `SnapshotInterpolator` synkkaa `catches`-listan, `deck_position`-sijainnin ja `scoop_progress`-mittarin. `WorldView` näyttää kevyen HUD-laskurin (kalamäärä `kpl` + isoimman paino `kg`) ja kalan väsymyksen **vain visuaalisesti vedessä** (virkeä sätkii nopeammin, ei tekstivihjettä kehotteessa).

## 4. Headless Acceptance Test

Tiedosto: `tests/test_10_landing_net_and_catch.gd` (5 testiä).

- `test_net_spawns_on_deck_pickup_free_drop_and_disconnect_drop`: **Given** oletusvene (`net_1` keskikannella) **When** pelaaja poimii haavin (`E`), kävelee, pudottaa sen (`E`) ja irrottautuu haavi kädessä **Then** haavi siirtyy vapaasti kannelle ilman telinekonfliktia ja säilyy kannella disconnectissa.
- `test_tired_fish_scoop_succeeds_solo_and_coop_and_records_catch`: **Given** väsynyt (`stamina <= 0.1`) `READY_TO_LAND`-kala telineessä ja kaverin kädessä **When** haavimies pitää `Space` (`0.4 s`) **Then** molemmat onnistuvat 100 %, vapa nollautuu, haavi jää käteen ja `catches` kasvaa.
- `test_fresh_fish_scoop_can_fail_and_bolt_back_to_hooked`: **Given** virkeä (`stamina = 1.0`) `READY_TO_LAND`-kala **When** haavitusta yritetään toistuvasti **Then** osa yrityksistä epäonnistuu ja syöksyttää kalan takaisin `HOOKED`-tilaan lisäsiimalla (ei karkaa koukusta).
- `test_catch_log_records_netless_lift_and_network_syncs_net_and_catches`: **Given** Host, Client ja `SnapshotInterpolator` **When** kala saadaan ilman haavia sekä haavilla ja haavi pudotetaan kannelle **Then** `catches` sisältää yksittäiset painot, `get_biggest_catch_weight()` täsmää ja tila synkkaa asiakkaalle.
- `test_world_view_renders_deck_and_held_net_lightweight_hud_and_stamina_thrash`: **Given** `WorldView` haavilla kannella/kädessä ja virkeällä vs. väsyneellä kalalla **When** näkymä päivittyy **Then** 3D-haavi näkyy oikein, HUD näyttää vain kpl + isoimman painon, ja virkeän kalan sätkiminen on nopeampaa ilman tekstivihjettä.

## 5. Manuaalinen verifiointi

- Testaa 1 ja 2 ikkunassa: kelaa kala laidalle, poimi haavi keskikannelta (`E`), tarkkaile kalan sätkimistä vedessä, kauhaise (`Space`), kokeile haavin pudottamista kannelle (`E`), tarkista HUD-saalislaskuri (`kpl` + isoin `kg`) ja varmista `FPS >= 60`, `Draw Calls < 100`, `Tris < 20 000`.

## 6. Tiedostot

| Polku | Toimenpide | Vastuu |
| :--- | :--- | :--- |
| `src/core/state/held_item.gd` | `[MODIFY]` | `deck_position`, `is_on_deck()` ja serialisointi |
| `src/core/state/fish_state.gd` | `[MODIFY]` | `scoop_progress` ja serialisointi |
| `src/core/state/game_state.gd` | `[MODIFY]` | `catches`-loki, apumetodit ja haavin disconnect-pudotus |
| `src/core/simulation/item_config.gd` | `[MODIFY]` | `ITEM_TYPE_NET`, `net_count` ja haavin aloitussijainti kannella |
| `src/core/simulation/item_simulator.gd` | `[MODIFY]` | Haavin poiminta kannelta ja vapaa pudotus kannelle |
| `src/core/simulation/fish_simulator.gd` | `[MODIFY]` | Haavituskohdehaku, `scoop_progress`, väsymystarkistus, syöksy ja saaliskirjaus |
| `src/network/snapshot_interpolator.gd` | `[MODIFY]` | `catches`-, `deck_position`- ja `scoop_progress`-replikaatio |
| `src/main.gd` | `[MODIFY]` | `ItemConfig.create_default_config(rod_count, DEFAULT_NET_COUNT)` |
| `src/view/boat_view.gd`, `src/view/player_view.gd`, `src/view/world_view.gd` | `[MODIFY]` | 3D-haavi kannella/kädessä, sätkimisnopeus, kauhauskehote ja kevyt saalis-HUD |
| `tests/test_10_landing_net_and_catch.gd` | `[NEW]` | 5 viipaleen hyväksymistestiä |
