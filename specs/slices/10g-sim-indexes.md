# Slice 10g — Simulaation hakemistot sekä interaktio- ja plaanarikorjaukset (`10g-sim-indexes`)

## 0. Tavoite

| Kohta | Arvo |
| :--- | :--- |
| **Nyt voin** | ajaa simulaatiotickiä ilman toistuvia lineaarisia telinehakuja, Euler-trigonometriaa tai $O(n^2)$-irrotushakuja sekä poimia haavin ja palauttaa plaanarin ilman ruori- tai karkausbugeja |
| **Uusi käsite** | Simulaation hakemistot (`_holder_index`, esilaskettu `tip_local_position` ja `_collect_detaching_rods`) |
| **Riippuvuudet** | `S4`, `S6`, `S8`, `S9b`, `S10`, `10f` |

## 1. Ei kuulu tähän viipaleeseen

- Binäärinen verkkokoodekki (`10h`)
- Uudet kalalajit tai uistelusäännöt

## 2. State Delta

Ks. `specs/01-state-schema.md`. Ei muutoksia verkkosnapshotin kenttiin.

| Luokka | Kenttä / Metodi | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- | :--- |
| `ItemConfig` | `_holder_index` / `tip_local_position` | `Dictionary` / `Vector3` | `{}` | $O(1)$-telinehaku ja esilaskettu lepovavan kärkipiste |
| `FishSimulator` | `_collect_detaching_rods(state, inputs)` | `Dictionary` | — | Laskee plaanaria irrottavat vavat kerran tickissä ($O(n)$) |
| `StationSimulator` | `_has_higher_priority_interaction(...)` | `bool` | `false` | Estää ruoria kaappaamasta `E`-painallusta, kun haavi/vapa/plaanari on lähempänä |

## 3. Rules & Math

- `ItemConfig._normalize_holder` esilaskee `"tip_local_position": pos + Basis.from_euler(Vector3(deg_to_rad(tilt.x), deg_to_rad(tilt.y), deg_to_rad(tilt.z))) * Vector3(0.0, 1.69, 0.0)`.
- `ItemConfig.get_holder(holder_id)` käyttää `_holder_index`-hajautustaulua, joka rakennetaan uudelleen jos `holders`-taulukon viite tai koko muuttuu.
- `RodSimulator._step_single_rod`: kun `rod.planer.line_out <= 0.001` ja `not holder_cfg.is_empty()`, `rod.planer.attached = bool(holder_cfg.get("default_planer_attached", false))` palautetaan myös vavan ollessa kädessä (`last_holder_id`:n perusteella).
- `StationSimulator.step`: ennen asemaan (`best_sid`, etäisyys `best_dist`) lukitsemista tarkistetaan `WorldView`-promptien prioriteettisäännöllä, ettei pelaajalla ole `detach_target`-kohdetta (`distance < best_dist`), kannella olevaa esinettä (`deck_dist <= best_dist`) tai telineinteraktiota (`holder_dist < best_dist`).
- Kahden saman siemenen (`seed = 42069`) 600 tickin ajon tilatiivisteet (SHA-256) täsmäävät bitilleen ja eroavat toisesta siemenestä (determinismi säilyy tulevien viipaleiden yli).

## 4. Headless Acceptance Test

Tiedosto: `tests/test_10g_sim_indexes.gd` (5 testiä).

- `test_given_default_config_when_get_holder_then_indexed_result_and_cached_tip_match_exact_math`
- `test_given_seed_42069_and_600_ticks_when_simulated_twice_then_state_hashes_match`
- `test_given_holders_array_replaced_when_get_holder_then_index_rebuilt`
- `test_given_net_or_coop_detach_closer_than_helm_when_player_presses_interact_then_helm_does_not_hijack`
- `test_given_escaped_fish_after_planer_detach_when_reeled_to_zero_in_hand_then_default_planer_restored`

## 5. Manuaalinen verifiointi

- Haavin poimiminen ruorin läheltä poimii haavin silloin kun HUD näyttää `[E] Poimi haavi`.

## 6. Tiedostot

| Polku | Toimenpide | Vastuu |
| :--- | :--- | :--- |
| `src/core/simulation/item_config.gd` | `[MODIFY]` | `_holder_index` ja esilaskettu `tip_local_position` |
| `src/core/simulation/rod_simulator.gd` | `[MODIFY]` | Esilasketun kärkipisteen käyttö ja plaanarin palautus `line_out == 0`:ssa |
| `src/core/simulation/fish_simulator.gd` | `[MODIFY]` | `_collect_detaching_rods` kerran tickissä |
| `src/core/simulation/station_simulator.gd` | `[MODIFY]` | Allokaatioiden poisto ja interaktioprioriteetin tarkistus |
| `tests/test_10g_sim_indexes.gd` | `[NEW]` | Viipaleen 10g hyväksymistestit |
