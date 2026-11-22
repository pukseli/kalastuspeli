# Slice 09a — Bite, Drag & Netless Lift (`09a-bite-and-reel`)

## 0. Tavoite

| Kohta | Arvo |
| :--- | :--- |
| **Nyt voin** | saada tärpin vapaan (lajikohtaiset signaalit, jarru/räikkä, pintahypyt), kelata kalan vapa kädessä veneen viereen (automaattinen plaanariohitus) ja yrittää nostoa ilman haavia |
| **Uusi käsite** | `FishState` (`GameState.fishes` ja `FishSimulator`) |
| **Riippuvuudet** | `S6`, `S8` |

## 1. Ei kuulu tähän viipaleeseen

- Manuaalinen `E`-pitomittarilla tehtävä plaanarin irrotus (`S9b`) ja haavi/kalasumppu/saalislaskuri (`S10`)
- Siiman kireys/katkeaminen (`S11`), ulkolaitapakko `-3`/`+3` ja siimojen pujotus (`S13`), plaanarin pudotus veteen (`xx-planer-drop`)

## 2. State Delta

Ks. `specs/01-state-schema.md`.

| Luokka | Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- | :--- |
| `FishState` | `rod_id`, `species`, `weight_kg`, `state`, `stamina`, `drag_rate`, `surge_timer`, `surge_cooldown`, `jump_progress`, `lift_progress`, `hooked_time`, `unattended_time`, `surfaced`, `fight_phase` | `String`, `float`, `bool` | `""`, `"HOOKED"`, `false`, `0.0` | Koukutetun kalan tila (`HOOKED` / `READY_TO_LAND`), jarru, syöksy, hyppy, nostomittari ja pintautuminen |
| `GameState` | `fishes`, `fish_notice_seq`, `fish_notice_text`, `fish_notice_timer` | `Dictionary`, `int`, `String`, `float` | `{}`, `0`, `""`, `0.0` | `rod_id -> FishState` sekä ajastettu saalis-/karkausilmoitus |

## 3. Rules & Math

| Laji | Paino (kg) | Esiintyvyys | Lippu (`TRIPPED`) | Hyppy | Jarru / Luisto | Nostokarkaus |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `vendace` (Muikku) | `0.03 .. 0.08` | Yleinen (`24`) | Ei (vain vavan nykinä) | Ei | `0.0 m/s` (väsyy heti) | `5 % .. 12 %` |
| `perch` (Ahven) | `0.30 .. 1.20` | Yleinen (`30`) | Ei (vain vavan nykinä) | Ei | `0.0 m/s` (väsyy heti) | `15 % .. 32 %` |
| `zander` (Kuha) | `1.20 .. 4.50` | Melko yleinen (`22`) | Kyllä | Ei | Kevyt syöksyssä (`<= 0.6 m/s`) | `48 % .. 70 %` |
| `pike` (Hauki) | `2.50 .. 12.0` | Normaali (`20`) | Kyllä | Kyllä | Hallittu (`<= 1.5 m/s`) | `75 % .. 92 %` |
| `orca` (Miekkavalas) | `3000 .. 5500` | Harvinainen (`3`) | Kyllä | Kyllä | Voimakas (`<= 2.0 m/s`) | `96 % .. 98 %` |
| `blue_whale` (Sinivalas) | `80000 .. 150000` | Erittäin harvinainen (`1`) | Kyllä | Kyllä | Maksimi (`<= 2.0 m/s`) | `98 % .. 99.5 %` |

- **Tärppikelpoisuus & debug:** Kelpoinen vapa (`line_out >= 5.0 m`, `boat.forward_speed >= 0.8 m/s`, ei `TANGLED`/`SNAGGED`, ei kalaa) voi saada tärpin samanaikaisesti muiden kanssa (`1 - exp(-base_rate * mult * dt)`, jossa `mult = 1.2×` hiljaisen veden plaanaribonus). `test`-profiilin `F` (`force_bite`) pakottaa tärpin heti.
- **Jarru, väsyminen & irtoaminen:** Kiinteä jarru (`drag_resistance = 1.0`, `max_drag_slip_speed = 2.0 m/s`) luistaa ja nostaa `drag_rate`-arvoa vain, kun kalan veto ylittää jarrun. Alun suoja (`grace_period_sec = 7.0 s`) estää välittömän irtoamisen; sen jälkeen vastustava kala (`stamina > 0`) voi pienellä satunnaisuudella ravistaa itsensä irti syöksyn aikana, kun taas väsynyt (`stamina <= 0`, pienillä heti) ei enää irtoa.
- **Kelaus, ohitus & nosto:** Kalavapaa kelataan (`Space`) vain kädessä ja se suojataan vääristä `TRIPPED`-plaanarisotkuista; telineeseen lasku ja disconnect säilyttävät kalan. S9a ohittaa plaanarin automaattisesti `<= 2.0 m` (`attached = false`, `+6.0 m` tapsi), kala pintautuu `<= 8.0 m` (`surfaced = true`) ja pysähtyy veneen laidalle (`1.5 m`, `READY_TO_LAND`). Jatkamalla `Space` pohjassa (`1.2 s` nostomittari) yritetään nostoa ilman haavia lajin/koon karkausriskillä.
- **Verkko & näkymä:** `NetworkManager` ajaa `FishSimulator`in; `SnapshotInterpolator` interpoloi jatkuvat `FishState`-kentät ja lukee diskreetit uusimmasta snapshotista. `WorldView`/`BoatView`/`PlayerView` näyttävät vavan nykimisen, pinnan ylle hyppivät ja pintautuneet 3D-kalat/valaat, HUD-mittarit ja proseduraalisen räikkä-äänen.

## 4. Headless Acceptance Test

Tiedosto: `tests/test_09a_bite_and_reel.gd` (5 testiä).

- `test_bite_generation_quiet_water_bonus_species_and_planer_trip_tiers`: **Given** kelpoiset/ei-kelpoiset vavat **When** tärppejä arvotaan tai pakotetaan **Then** hiljaisen veden bonus, lajiportaat (`vendace`/`perch` ei `TRIPPED` vs `zander+` `TRIPPED`) ja rinnakkaiset tärpit toimivat.
- `test_drag_raikka_stamina_jumps_and_resisting_shakeoff`: **Given** eri lajien kalat **When** simulaatiota ajetaan **Then** pienet väsyvät heti ilman jarrua/irtoamista, keskikokoiset/isot luistattavat jarrua (`<= 2.0`), isot hyppivät ja voivat irrota vastustaessaan `grace_period_sec`-ajan jälkeen.
- `test_in_hand_reel_auto_planer_bypass_no_false_tangle_and_carry_persistence`: **Given** koukutettu plaanarivapa **When** kelausta yritetään telineestä/kädessä ja vene kääntyy jyrkästi **Then** kelaus vaatii kädessäolon, ei mene valesolmuun, säilyy telineessä/disconnectissa ja ohittaa plaanarin automaattisesti `READY_TO_LAND`-tilaan laidan ulkopuolelle.
- `test_netless_hand_lift_risk_scales_with_size_and_network_sync`: **Given** `READY_TO_LAND`-kala ja Host/Client **When** `Space`-nostomittari täyttyy ja tila synkataan **Then** muikku nousee selvästi useammin kuin sinivalas, vapa nollautuu `STOWED`-tilaan ja `fishes` sekä `fish_notice_*` interpoloituvat.
- `test_world_view_renders_surface_jump_fish_rod_twitch_and_hud`: **Given** `WorldView` sukelluksissa, hyppivällä ja pintautuneella kalalla **When** näkymä päivittyy **Then** kaukainen ei näy, hyppivä on veden yllä, valas on suurempi kuin muikku ja HUD/hälytykset päivittyvät.

## 5. Manuaalinen verifiointi

- Testaa 1 ja 2 ikkunassa (`--host`/`--join`): laske vavat uistelussa, pakota tärppi (`F`) tai odota luonnollista tärppiä, seuraa vavan nykinää / kaatuvaa lippua / räikkää / pintahyppyjä, poimi vapa (`E`), kelaa veneen viereen (`Space`), yritä nosto pitämällä `Space` (`1.2 s`) ja varmista `FPS >= 60`, `Draw Calls < 100`, `Tris < 20 000`.

## 6. Tiedostot

| Polku | Toimenpide | Vastuu |
| :--- | :--- | :--- |
| `src/core/state/fish_state.gd` | `[NEW]` | `FishState`-tietomalli ja serialisointi |
| `src/core/state/game_state.gd` | `[MODIFY]` | `fishes`-sanakirja, ilmoitukset ja serialisointi |
| `src/core/simulation/rod_simulator.gd` | `[MODIFY]` | Koukutetun vavan kelausohitus, sotkusuoja ja laidan ulkopuolinen viehesijainti |
| `src/core/simulation/fish_simulator.gd` | `[NEW]` | Lajitaulukko, tärpit, jarru/räikkä, hypyt, kelaus ja nostoyritys |
| `src/network/network_manager.gd` | `[MODIFY]` | `FishSimulator`-askel authority-tickissä |
| `src/network/snapshot_interpolator.gd` | `[MODIFY]` | `fishes`- ja ilmoitustilan replikaatio ja interpolointi |
| `src/view/boat_view.gd` | `[MODIFY]` | Telinevapojen nykinä ja koukutustilan välitys hahmoille |
| `src/view/player_view.gd` | `[MODIFY]` | Kädessä pidettävän vavan taipuma/nykinä |
| `src/view/world_view.gd` | `[MODIFY]` | Low-poly 3D-kalat/valaat, hyppykaarrokset, HUD ja proseduraalinen räikkä-ääni |
| `src/main.gd` | `[MODIFY]` | `F`-debug-tärppi ja `FishSimulator`-kytkentä |
| `tests/test_09a_bite_and_reel.gd` | `[NEW]` | 5 viipaleen hyväksymistestiä |
