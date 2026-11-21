# Slice 06 — Held Items & Configurable Rod Holders (`06-held-items`)

## 0. Tavoite

| Kohta | Arvo |
| :--- | :--- |
| **Nyt voin** | poimia vavan telineestä käteen (`E`), kävellä sen kanssa kannella ja asettaa tai vaihtaa sen toiseen kylkitelineeseen (`-3..-1`, `+1..+3`) |
| **Uusi käsite** | Kannettava esine (`HeldItem`) ja konfiguroitava telineasettelu (`ItemConfig`) |
| **Riippuvuudet** | `S3` (`03-crew-on-deck`), `S4` (`04-stations`), `S5` (`05-smooth-sync`) |

## 1. Ei kuulu tähän viipaleeseen

- Siima ja viehe (`S7`), tärppi ja kelaus (`S8`), haavi ja kalasumppu (`S9`)
- Vavan pudottaminen vapaasti kannelle; useiden venemallien valinta-UI

## 2. State Delta

Ks. `specs/01-state-schema.md`. `GameState.item_config: ItemConfig` on staattinen (ei replikoidu).

| Luokka | Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- | :--- |
| `HeldItem` | `id`, `item_type`, `color_index` | `String`, `String`, `int` | `""`, `"rod"`, `0` | Esineen tunniste, tyyppi ja korostusväri |
| `HeldItem` | `carrier_peer_id`, `holder_id`, `last_holder_id` | `int`, `String`, `String` | `0`, `""`, `""` | Yksi totuuden lähde: joko `carrier_peer_id != 0` tai `holder_id != ""` |
| `GameState` | `items` | `Dictionary` | `item_config.create_initial_items()` | `item_id: String -> HeldItem` (replikoitu) |

## 3. Rules & Math

- **Konfiguroitava `ItemConfig`:** Oletuksena 6 kylkitelinettä (`rod_-3..rod_-1`, `rod_+1..rod_+3`) ja `rod_count = 6` (`--rods <N>` / `ItemConfig`), täyttöjärjestys sisältä ulos (`-1, +1, -2, +2, -3, +3`) tai mukautetun veneen telinejärjestyksessä.
- **Interaktio (`E`):** 2D XZ -etäisyys `<= radius`, lähin yhteensopiva teline voittaa, deterministinen `peer_id`-järjestys; teline lukittuu tickin ajaksi ensimmäisen toimijan jälkeen. Tyhjin käsin poimii; vapa kädessä asettaa tyhjään tai vaihtaa (`swap`) varatun telineen kanssa; kaukana telineestä ei pudota kannelle.
- **Ruori & disconnect:** `StationSimulator` estää ruorin varauksen esine kädessä (HUD `[Laske vapa ensin]`, yleinen `[Kädet täynnä]`); ruorista poistuminen samalla tickillä ei poimi vapaa. `GameState.remove_player` palauttaa kannetun esineen `last_holder_id`-telineeseen (jos vapaa) tai ensimmäiseen vapaaseen yhteensopivaan telineeseen.
- **Verkko & näkymä:** `SnapshotInterpolator` lukee `items`-tilan diskreettinä uusimmasta snapshotista. `BoatView` luo telineet ja telinevavat dynaamisesti `ItemConfig`:sta; `PlayerView` näyttää kannetun vavan (`HeldItemAnchor`); `WorldView` näyttää `[E] Poimi/Aseta/Vaihda vapa (<slot>)`, `[Laske vapa ensin]` ja HUDin `Kädessä`-tilan.

| Parametri | Arvo | Yksikkö |
| :--- | :--- | :--- |
| `DEFAULT_ROD_COUNT` / `DEFAULT_HOLDER_RADIUS` / `HOLDER_MOUNT_Y` | `6` / `0.85` / `0.65` | kpl / m / m |
| Kylkitelineet (`rod_-3..-1`, `rod_+1..+3`) | `X = ±1.55`, `Z = 0.6 / 1.6 / 2.6` | m |

## 4. Headless Acceptance Test

Tiedosto: `tests/test_06_held_items.gd` (5 testiä).

- `test_pickup_walk_place_and_no_deck_drop`: **Given** 4 vapaa telineissä **When** pelaaja poimii, kävelee keskikannelle (`E`) ja laskee `-3`:een **Then** kannelle ei pudoteta ja vapa siirtyy `-3`:een.
- `test_swap_occupied_holder_and_same_tick_exclusivity`: **Given** 2 pelaajaa saman telineen äärellä ja varattu `-3` **When** molemmat painavat `E` samalla tickillä ja toinen vaihtaa `-3`:een **Then** vain yksi poimii tickillä ja `swap` vaihtaa vavat.
- `test_helm_blocked_while_holding_item_and_disconnect_returns_item`: **Given** pelaajalla vapa kädessä **When** yrittää ruoriin (`E`), katkaisee yhteyden tai vapauttaa ruorin telineen päällä **Then** ruori estyy (`[Laske vapa ensin]`), vapa palautuu telineeseen eikä ruorista poistuessa poimita.
- `test_configurable_rod_count_and_custom_boat_holder_layout`: **Given** `--rods 4` sekä mukautettu `ItemConfig` (3 telinettä, 2 vapaa) **When** tila ja `BoatView` alustetaan **Then** telineet ja vavat rakentuvat asetuksista ilman kovakoodausta.
- `test_items_replicate_over_network_interpolate_discretely_and_render_in_view`: **Given** Host/Client, `SnapshotInterpolator` ja `WorldView` **When** vapa poimitaan ja snapshoteja interpoloidaan **Then** kävely interpoloituu, esinetila seuraa uusinta snapshotia ja 3D-vavat/HUD päivittyvät.

## 5. Manuaalinen verifiointi

- Testaa yhdessä ikkunassa (oletus 6 vapaa sekä `-- --rods 4`) ja kahdessa ikkunassa (`--host` / `--join 127.0.0.1`): poimi vapa, kävele kannella, vaihda toiseen telineeseen, yritä ruoriin vapa kädessä (`[Laske vapa ensin]`), ja tarkista budjetit (`FPS >= 60`, `Draw Calls < 100`, `Tris < 20 000`).

## 6. Tiedostot

| Polku | Toimenpide | Vastuu |
| :--- | :--- | :--- |
| `src/core/state/held_item.gd` | `[NEW]` | `HeldItem`-tietomalli ja serialisointi |
| `src/core/simulation/item_config.gd` | `[NEW]` | Konfiguroitavat telineet ja oletusvavat (`rod_count`, mukautetut veneet) |
| `src/core/state/game_state.gd` | `[MODIFY]` | `items`, `item_config`, apumetodit ja disconnect-palautus |
| `src/core/simulation/station_simulator.gd` | `[MODIFY]` | Estä aseman varaus esine kädessä |
| `src/core/simulation/item_simulator.gd` | `[NEW]` | Esineiden poiminta, asetus ja vaihto |
| `src/network/network_manager.gd` | `[MODIFY]` | `--rods`, tick-järjestys (`station_sim` -> `item_sim`) |
| `src/network/snapshot_interpolator.gd` | `[MODIFY]` | Diskreetti `items`-synkka uusimmasta snapshotista |
| `src/view/player_view.gd` | `[MODIFY]` | Kannettava 3D-vapa (`HeldItemAnchor`) ja värikoodaus |
| `src/view/boat_view.gd` | `[MODIFY]` | Dynaamiset telineet ja telinevavat `ItemConfig`:n mukaan |
| `src/view/world_view.gd` | `[MODIFY]` | Lähimmän telineen/aseman kehotteet ja `Kädessä`-HUD |
| `src/main.gd` | `[MODIFY]` | `ItemConfig`- ja `ItemSimulator`-kytkentä |
| `tests/test_06_held_items.gd` | `[NEW]` | 5 hyväksymistestiä |
