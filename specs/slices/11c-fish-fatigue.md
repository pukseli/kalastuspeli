# Slice 11c — Active Fish Fatigue & Fight Rhythm (`11c-fish-fatigue`)

## 0. Tavoite

| Kohta | Arvo |
| :--- | :--- |
| **Nyt voin** | väsyttää isoja kaloja aktiivisesti oikealla rytmillä ja jarrulla ennen haavitusta: kireys ja oikea-aikainen jarrun myötäily/kelaus rakentavat rytmin ja kuluttavat kestävyyttä, löysä siima palauttaa virkeän kalan voimia, syöksyt harvenevat väsyessä ja tila näkyy taistelu-HUDissa sekä 3D-kalassa |
| **Uusi käsite** | Kalan aktiivinen väsytys- ja rytmisilmukka (`FishState.fight_rhythm` + jännitys-/rytmipohjainen `stamina`-päivitys) |
| **Riippuvuudet** | `S9a`, `S9b`, `S10`, `S11a`, `S11b` |

## 1. Ei kuulu tähän viipaleeseen

- Uudet näppäinsyötteet (esim. pumppausnappi; käytetään nykyisiä `Space` + `Z`/`X`, `PlayerInput` ei muutu)
- Uisteluikkunakalibrointi & solmun selvitys (`S12`), ulkolaitapakko (`S13`), karikkoshokkikuorma (`S16`), hätälaskuajastin (`xx-emergency-rest`)
- Väsymystekstivihjeet haavituksen `Kauhaise`-kehotteessa (`S10`-sääntö säilyy)

## 2. State Delta

Ks. `specs/01-state-schema.md`.

| Luokka | Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- | :--- |
| `FishState` | `fight_rhythm` | `float` | `0.0` | Taistelurytmin laatu (`0.0 .. 1.0`); lisätään `EXHAUSTED_STAMINA = 0.05`, `is_exhausted()`, `copy_from()`, `to_dict()`, `from_dict()` |

## 3. Rules & Math

| Parametri | Arvo | Yksikkö |
| :--- | :--- | :--- |
| `EXHAUSTED_STAMINA` / `fatigue_min_work_tension` / `fatigue_tension_ref` | `0.05` / `15.0` / `75.0` | — / N / N |
| `stamina_drain_surge_drag` / `reeling` / `passive_held` / `holder_slip` / `passive` | `0.13` / `0.11` / `0.025` / `0.030` / `0.015` | s⁻¹ |
| `stamina_recovery_rate` / `rhythm_drain_bonus_max` / `panic_reel_drain_mult` / `panic_shakeoff` | `0.06` / `1.65x` / `0.50x` / `+0.03` | s⁻¹ / — / — / s⁻¹ |
| `rhythm_gain_yield` / `reel` / `penalty_panic` / `decay_idle` / `holder` / `slack` | `+0.35` / `+0.30` / `-0.80` / `-0.25` / `-0.35` / `-0.45` | s⁻¹ |

- **Väsytyssilmukka (`FishSimulator._step_fish_fatigue`):** Päivittyy `LinePhysics.step_rod_line()`-kutsun jälkeen nykytickin `rod.line_tension`- ja `is_drag_slipping`-arvoilla (`is_detaching` keskeyttää). `eff_scale = stamina_drain_scale * lerpf(1.15, 0.80, weight_frac)` (`get_fatigue_drain_scale`). Uupunut (`is_exhausted()`) tai `initial_stamina <= 0` nollaa `fight_rhythm = 0.0` ja `surge_timer = 0.0` eikä koskaan palaudu.
- **Löysä vs. 5 työtilaa:** Kun virkeän kalan `line_tension < 15 N`: `fight_rhythm -= 0.45 * dt` ja `stamina += 0.06 * ((15 - tension)/15) * dt` (enintään `initial_stamina`). Kun `>= 15 N`: `tw = clamp((tension - 15)/60, 0, 1.35)`, `rm = lerpf(1.0, 1.65, fight_rhythm)`. (1) Paniikkikelaus luistoon (`is_reeling and is_slipping`): `rhythm -0.80/s`, kulutus `0.13 * tw * 0.50 * eff_scale`, karkauslisä `+0.03/s` suoja-ajan jälkeen; (2) Puhdas myötäily kädessä (`is_carried`, ei kelata, `is_slipping or surging`): `rhythm +0.35/s`, `0.13 * tw * rm * eff_scale`; (3) Puhdas kelaus (`is_reeling and not is_slipping`): `rhythm +0.30/s`, `0.11 * max(0.35, tw) * rm * eff_scale`; (4) Passiivinen pito kädessä: `rhythm -0.25/s`, `0.025 * tw * eff_scale`; (5) Hoitamaton telineessä: `rhythm -0.35/s`, `(0.030 jos luistaa muuten 0.015) * tw * eff_scale`.
- **Dynaamiset syöksyt, verkko & näkymä:** Syöksyn kesto skaalautuu `lerpf(0.55, 1.15, stamina)` ja tauko `lerpf(1.65, 0.85, stamina)`. `SnapshotInterpolator` interpoloi `fight_rhythm`in. `WorldView` näyttää `fatigue_row_root` (`Kala` + `Rytmi` -palkit `tension_meter_root`issa) vain `HOOKED`-taistelussa (piilossa `READY_TO_LAND`), ohjaa `[Anna juosta!] [RÄIKKÄ!]` / `[Space] Kelaa [RYTMI %]` ja kallistaa uupuneen pintakalan kyljelleen (`roll = 0.55 rad`, `0` lisä-draw-callia).

## 4. Headless Acceptance Test

Tiedosto: `tests/test_11c_fish_fatigue.gd` (5 testiä).

- `test_given_hooked_fish_when_fighting_with_high_safe_drag_vs_low_drag_then_tension_scales_fatigue_and_slack_recovers_stamina`: **Given** 7 kg hauet **When** taistellaan 80 N vs 30 N jarrulla tai löysällä (`< 15 N`) tai uupuneena (`stamina = 0`) **Then** isompi turvallinen jarru väsyttää nopeammin, löysä palauttaa virkeää ja uupunut ei koskaan palaudu.
- `test_given_surging_big_fish_when_angler_yields_and_reels_in_rhythm_vs_panic_reeling_then_rhythm_builds_and_tires_fish_much_faster`: **Given** syöksyilevä 7 kg hauki **When** myötäillään luistossa ja kelataan rauhallisena vs. paniikkikelataan luistoon vs. jätetään telineeseen **Then** rytmi kasvaa ja väsyttää kalan selvästi nopeammin.
- `test_given_tiring_fish_when_stamina_drops_then_surges_shorten_rest_windows_lengthen_and_exhausted_fish_scoops_cleanly`: **Given** virkeä vs. väsynyt ja kevyt vs. jätti hauki **When** syöksyt laukeavat ja uupunut kelataan haavittavaksi **Then** väsyessä syöksyt lyhenevät ja lepotauot pitenevät, isompi kala kestää pidempään ja uupunut haavittuu 100 %.
- `test_given_fish_with_fight_rhythm_when_synced_over_network_then_copy_from_serialization_and_interpolation_preserve_it`: **Given** `FishState.fight_rhythm` ja `is_exhausted()` **When** kopioidaan, serialisoidaan `NetworkManager`illa ja interpoloidaan `SnapshotInterpolator`illa **Then** tila säilyy ja interpoloituu tarkasti.
- `test_given_hooked_and_ready_fish_when_applied_to_world_view_then_fatigue_hud_rhythm_prompts_and_exhausted_roll_render_without_scoop_spoilers`: **Given** `WorldView` taistelussa ja `READY_TO_LAND`-haavituksessa **When** näkymä päivittyy **Then** `Kala`/`Rytmi`-HUD ja `[Anna juosta!]`/`[RYTMI]` toimivat, uupunut kala kallistuu kyljelleen ja haavituskehote pysyy ilman väsymysvihjettä.

## 5. Manuaalinen verifiointi

- Aja `bash tools/test-snapshot.sh whale_strike_2s` (tai pakota `F`), taistele `Z`/`X`:llä ja `Space`lla: varmista `[Anna juosta!]` räikän aikana vs. `Space`-kelaus rauhallisessa välissä nostaa `Rytmi`-mittaria, `< 15 N` löysä palauttaa kalaa, uupunut pintakala kallistuu kyljelleen ja haavittuu varmasti; tarkista `FPS >= 60`, `Draw Calls < 100`, `Tris < 20 000`.

## 6. Tiedostot

| Polku | Toimenpide | Vastuu |
| :--- | :--- | :--- |
| `src/core/state/fish_state.gd` | `[MODIFY]` | `EXHAUSTED_STAMINA`, `fight_rhythm`, `is_exhausted()`, `copy_from()` ja serialisointi |
| `src/core/simulation/fish_simulator.gd` | `[MODIFY]` | Jännitys-/rytmipohjainen väsytys, löysä palautuminen, painoskaalaus ja syöksyrytmi |
| `src/network/snapshot_interpolator.gd` | `[MODIFY]` | `FishState.fight_rhythm`-interpolointi |
| `src/view/world_view.gd` | `[MODIFY]` | Taistelu-HUD (`Kala` + `Rytmi`), rytmikehotteet ja uupuneen kalan kylkikallistus |
| `tests/test_11c_fish_fatigue.gd` | `[NEW]` | 5 viipaleen hyväksymistestiä |
