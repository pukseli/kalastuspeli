# Slice 09b — Planer Detach Lock & Hold Interact (`09b-planer-detach`)

## 0. Tavoite

| Kohta | Arvo |
| :--- | :--- |
| **Nyt voin** | kelata plaanarin veneen laidalle irrotuslukkoon ja irrottaa sen pitämällä `E`-näppäintä pohjassa mittarin täyttymiseen asti (yksin telineestä tai kaverin auttamana) |
| **Uusi käsite** | Jatkuva pidettävä interaktio (`PlayerInput.interact_held` + `FishState.detach_progress`) |
| **Riippuvuudet** | `S6`, `S8`, `S9a` |

## 1. Ei kuulu tähän viipaleeseen

- Haavi, kalasumppu ja saalislaskuri (`S10`)
- Plaanarin pudotus veteen irrotuksen epäonnistuessa (`xx-planer-drop`) tai siiman kireys/katkeaminen (`S11`)

## 2. State Delta

Ks. `specs/01-state-schema.md`.

| Luokka | Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- | :--- |
| `PlayerInput` | `interact_held` | `bool` | `false` | Jatkuva `E`-näppäimen pito (`src/main.gd` + verkkosynkka) |
| `FishState` | `detach_progress` | `float` | `0.0` | Plaanarin irrotusmittarin edistyminen (`0.0 .. 1.0`) |

## 3. Rules & Math

| Parametri | Arvo | Yksikkö |
| :--- | :--- | :--- |
| `detach_distance` / `detach_window_distance` | `2.0` / `3.5` | m |
| `detach_hold_duration` / `detach_decay_rate` | `0.8` / `1.5` | s / s⁻¹ |
| `coop_detach_radius` | `1.6` | m |

- **Irrotuslukko:** Koukutettu plaanarivapa (`attached == true`) pysähtyy kädessä kelattaessa etäisyydelle `detach_distance` (`2.0 m`) ilman automaattista ohitusta. Suoralla siimalla (`attached == false`) kelaus etenee suoraan `READY_TO_LAND`-tilaan (`1.5 m`).
- **Yksin telineestä & co-op:** Irrotuskelpoinen vapa (`line_out <= detach_window_distance`, ei `TANGLED`/`SNAGGED`) vaatii tyhjäkätisen pelaajan pitämään `E` (`interact_held`) pohjassa joko telineen äärellä (`holder_radius`) tai kelaavan kaverin vieressä (`<= coop_detach_radius`). Aktiivinen `find_detach_target_for_player` estää `ItemSimulator`-poiminnan ja keskeyttää jarruluiston irrotuksen ajaksi.
- **Mittari & valmistuminen:** Pito kasvattaa `detach_progress`-arvoa nopeudella `1.0 / 0.8 s`, vapautus laskee `1.5 /s`. Täyttyessä (`>= 1.0`) `attached = false`, `lateral_offset = 0.0`, `line_out += leader_length` (`+6.0 m`), `reset_strike_reaction()`, `detach_progress = 0.0`, `surfaced` päivittyy ja HUD ilmoittaa irrotuksesta.
- **Verkko & näkymä:** `NetworkManager` välittää `interact_held`-tilan nollaamatta sitä tickin lopussa; `SnapshotInterpolator` interpoloi `detach_progress`-arvon. `WorldView` korostaa irrotusvalmiin plaanarin vihreällä ja näyttää kantaja-, co-op- ja telinekehotteet mittariprosentteineen.

## 4. Headless Acceptance Test

Tiedosto: `tests/test_09b_planer_detach.gd` (5 testiä).

- `test_reel_stops_at_detach_lock_and_straight_rod_unaffected`: **Given** koukutettu plaanari- ja suora vapa **When** niitä kelataan kädessä **Then** plaanari lukittuu `2.0 m`:iin eikä kelaaja voi irrottaa kädestä; suora siima etenee `READY_TO_LAND`-tilaan.
- `test_solo_holder_detach_blocks_pickup_fills_meter_and_unlocks_reel`: **Given** irrotusvalmis vapa telineessä **When** tyhjäkäsinen pelaaja painaa ja pitää `E` **Then** `ItemSimulator` ei poimi vapaa, mittari täyttyy ja laskee vapauttaessa, `0.8 s` irrottaa plaanarin (`+6.0 m`) ja vapauttaa vavan kelattavaksi laidalle.
- `test_coop_teammate_detaches_while_carrier_holds_rod_with_range_and_hands_checks`: **Given** Pelaaja 1 pitelee lukossa olevaa vapaa ja Pelaaja 2 on kannella **When** Pelaaja 2 yrittää kaukana, kädet täynnä tai tyhjäkätisenä vieressä **Then** vain tyhjäkätinen `<= 1.6 m` kaveri täyttää mittarin ja irrottaa plaanarin Pelaaja 1:n kädestä.
- `test_network_replicates_interact_held_and_interpolates_detach_progress`: **Given** Host, Client ja `SnapshotInterpolator` **When** asiakas pitää `interact_held = true` **Then** pito säilyy tickien yli, irrottaa plaanarin ja `detach_progress` interpoloituu sulavasti.
- `test_world_view_shows_detach_lock_coop_prompts_progress_and_highlight`: **Given** `WorldView` irrotusvalmiilla plaanarilla **When** tila renderöidään kantajalle, co-op-auttajalle ja yksin telineellä **Then** plaanari korostuu vihreällä ja oikeat kehotteet/prosentit näkyvät.

## 5. Manuaalinen verifiointi

- Testaa 1 ja 2 ikkunassa: ota tärppi (`F`), kelaa plaanari `2.0 m` lukkoon (plaanari vihertyy), yksin laske vapa telineeseen (`E`) ja pidä `E` pohjassa `0.8 s` tai kaverina seiso kelaajan vieressä ja pidä `E`, poimi/kelaa kala pintaan, varmista `FPS >= 60`, `Draw Calls < 100`, `Tris < 20 000`.

## 6. Tiedostot

| Polku | Toimenpide | Vastuu |
| :--- | :--- | :--- |
| `src/core/state/player_input.gd` | `[MODIFY]` | `interact_held`-kenttä ja serialisointi |
| `src/core/state/fish_state.gd` | `[MODIFY]` | `detach_progress`-kenttä ja serialisointi |
| `src/core/simulation/fish_simulator.gd` | `[MODIFY]` | Irrotuslukko, kohdehaku (`holder`/`coop`), pitoajastin ja irrotus |
| `src/core/simulation/item_simulator.gd` | `[MODIFY]` | Poiminnan esto irrotusvalmiilla teline-/co-op-kohteella |
| `src/core/simulation/rod_simulator.gd` | `[MODIFY]` | Sotkusuoja aktiivisen irrotuksen aikana |
| `src/network/network_manager.gd` | `[MODIFY]` | `interact_held`-välitys ilman tickin lopun nollausta |
| `src/network/snapshot_interpolator.gd` | `[MODIFY]` | `detach_progress`-interpolointi |
| `src/main.gd` | `[MODIFY]` | Jatkuvan `KEY_E`-pitotilan lukeminen |
| `src/view/world_view.gd` | `[MODIFY]` | Vihreä plaanarikorostus sekä yksin- ja co-op-irrotuskehotteet |
| `tests/test_09a_bite_and_reel.gd`, `tests/test_09b_planer_detach.gd` | `[MODIFY]`/`[NEW]` | Päivitetty ohitussilmukka ja 5 S9b-hyväksymistestiä |
