# 01 — Elävä Tietoskeema (Living State Schema)

> **Sääntö:** Tämä dokumentti kuvaa kulloinkin toteutettujen viipaleiden tietorakenteet (`src/core/state/`). Tulevien viipaleiden (esim. vavat, kalat, AI Directorin kaaostapahtumat) tietorakenteet lisätään tähän vasta kyseisen viipaleen yhteydessä.

## Skeemasäännöt

| Sääntö | Perustelu | Esimerkki |
| :--- | :--- | :--- |
| **Yksi totuuden lähde:** ei johdettuja kenttiä kahteen paikkaan | Estää ristiriitaiset tilat | `GameState.stations["helm"]`; "ajaako pelaaja" johdetaan siitä, ei erillistä `is_driving_boat`-kenttää |
| **Syöte ≠ tila:** asiakkaan syötteet erillisessä `PlayerInput`-rakenteessa | Server-authoritative-malli: asiakas lähettää aikeet, palvelin päättää tuloksen | `move_input`, `throttle` ja `steering` kuuluvat `PlayerInput`-rakenteeseen, eivät replikoituun tilaan |
| **Staattinen konfiguraatio ei kuulu replikoituun tilaan** | Ei turhaa verkkoliikennettä 20 kertaa sekunnissa | Kannen mitat `const`- tai `BoatConfig`-arvona |
| **Serialisointi:** jokaisella tilaluokalla `to_dict()` / `from_dict()` | Verkkovalmius | — |

## Toteutetut tietorakenteet

### Viipale S1 (`01-boat-on-water`) & Mekaniikkapäivitys (`specs/02-mechanics/boat-physics.md`)

#### 1. `BoatState` (`extends RefCounted`, `src/core/state/boat_state.gd`)

| Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- |
| `world_position` | `Vector3` | `Vector3.ZERO` | Veneen sijainti maailmankoordinaatistossa |
| `heading` | `float` | `0.0` | Keulan suunta radiaaneina (`0` = `-Z` eteenpäin) |
| `forward_speed` | `float` | `0.0` | Etenemisnopeus rungon suuntaan (m/s) |
| `velocity` | `Vector2` | `Vector2.ZERO` | 2D-nopeusvektori maailman X/Z-tasossa |
| `angular_velocity` | `float` | `0.0` | Pyörimisnopeus Y-akselin ympäri (rad/s) |
| `throttle` | `float` | `0.0` | Nykyinen kaasun taso (`-1.0 .. 1.0`) |
| `steering_angle` | `float` | `0.0` | Perämoottorin kääntökulma radiaaneina |

**Serialisointi:** `to_dict() -> Dictionary`, `from_dict(data: Dictionary) -> void`

#### 2. `PlayerInput` (`extends RefCounted`, `src/core/state/player_input.gd`)

| Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- |
| `throttle` | `float` | `0.0` | Kaasusyöte (`-1.0 .. 1.0`, erillään replikoidusta venetilasta) |
| `steering` | `float` | `0.0` | Ohjaussyöte (`-1.0 .. 1.0`, `+1.0` vasen, `-1.0` oikea) |
| `move_x` | `float` | `0.0` | Kansikävelysyöte X-akselilla (`-1.0 .. 1.0`: `A = -1.0`, `D = +1.0`, lisätty S3) |
| `move_z` | `float` | `0.0` | Kansikävelysyöte Z-akselilla (`-1.0 .. 1.0`: `W = -1.0` keulaan, `S = +1.0` perään, lisätty S3) |
| `interact` | `bool` | `false` | Aseman varaus/vapautus (`E`-näppäin, lisätty S4) |
| `interact_held` | `bool` | `false` | Jatkuva pidetty interaktio (`E` pohjassa plaanarin irrotukseen, lisätty S9b) |
| `line_input` | `float` | `0.0` | Siiman säätösyöte (`+1.0` ulos `Q`/`Shift`, `-1.0` sisään `Space`, lisätty S8) |
| `drag_input` | `float` | `0.0` | Kelan jarrun säätösyöte (`-1.0` `Z` löysää, `+1.0` `X` kiristä, lisätty S11a) |

**Serialisointi:** `to_dict() -> Dictionary`, `from_dict(data: Dictionary) -> void`

### Viipale S3 (`03-crew-on-deck`)

#### 3. `PlayerState` (`extends RefCounted`, `src/core/state/player_state.gd`)

| Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- |
| `peer_id` | `int` | `1` | Omistajan ID (`>= 1` pelaaja, `-1 .. -3` botti) |
| `local_position` | `Vector3` | `Vector3(0.0, 0.25, 0.0)` | Sijainti veneen paikallisessa koordinaatistossa |
| `color_index` | `int` | `0` | Hahmon väri-indeksi (`0 .. 3`) |
| `is_bot` | `bool` | `false` | Staattinen testinukke (`true` boteilla `-1 .. -3`) |

**Serialisointi:** `to_dict() -> Dictionary`, `from_dict(data: Dictionary) -> void`

#### 4. `GameState` (`extends RefCounted`, `src/core/state/game_state.gd`)

| Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- |
| `tick` | `int` | `0` | Simulaation tick-laskuri (käytössä S5-snapshot-interpoloinnissa) |
| `boat` | `BoatState` | `BoatState.new()` | Veneen maailmatila |
| `players` | `Dictionary` | `{}` | `peer_id: int -> PlayerState` |
| `stations` | `Dictionary` | `{"helm": 0}` | Asemat: `station_id: String -> occupant_peer_id: int` (lisätty S4) |
| `items` | `Dictionary` | `item_config.create_initial_items()` | Kannettavat esineet: `item_id: String -> HeldItem` (lisätty S6) |
| `item_config` | `ItemConfig` | `ItemConfig.new()` | Staattinen telineasettelu ja `rod_count` (ei replikoidu, lisätty S6) |
| `rods` | `Dictionary` | `sync_rods_with_items()` | Vapojen siima- ja plaanaritilat: `rod_id: String -> RodState` (lisätty S8) |
| `fishes` | `Dictionary` | `{}` | Koukutettujen kalojen tilat: `rod_id: String -> FishState` (lisätty S9a) |
| `fish_notice_seq` | `int` | `0` | Juokseva ilmoitustunniste saaliille/karkauksille (lisätty S9a) |
| `fish_notice_text` | `String` | `""` | Viimeisin kalailmoitus HUDiin (lisätty S9a) |
| `fish_notice_timer` | `float` | `0.0` | Kalailmoituksen jäljellä oleva näyttöaika sekunteina (lisätty S9a) |
| `catches` | `Array` | `[]` | Tiimin viimeisimmät saaliit (rajattu `CATCH_LOG_MAX = 20`): `{"species", "weight_kg", "size_class", "method"}` per kala (lisätty S10, rajattu 10c) |
| `catch_count` | `int` | `0` | Tiimin kokonaissaalismäärä (säilyy vaikka `catches`-loki rajataan, lisätty 10c) |
| `biggest_catch_kg` | `float` | `0.0` | Suurimman saaliin paino kilogrammoina ($O(1)$-haku, lisätty 10c) |

**Apumetodit:** `_init(populate_defaults: bool = true)`, `ensure_player(peer_id: int, is_bot: bool = false) -> PlayerState`, `remove_player(peer_id: int) -> void`, `is_player_at_station(peer_id: int) -> bool`, `get_player_station(peer_id: int) -> String`, `reset_helm_detents() -> void`, `configure_items(cfg: ItemConfig) -> void`, `sync_rods_with_items() -> void`, `get_rod_state(rod_id: String) -> RodState`, `get_deployed_rod_count() -> int`, `get_fish_state(rod_id: String) -> FishState`, `has_fish_on_rod(rod_id: String) -> bool`, `get_hooked_fish_count() -> int`, `set_fish_notice(text: String, duration: float = 4.5) -> void`, `record_catch(species: String, weight_kg: float, size_class: String, method: String = "net") -> void`, `get_catch_count() -> int`, `get_biggest_catch_weight() -> float`, `get_player_held_item(peer_id: int) -> HeldItem`, `is_player_holding_item(peer_id: int) -> bool`, `get_holder_item(holder_id: String) -> HeldItem`, `return_item_to_holder(item: HeldItem) -> bool`
**Serialisointi:** `to_dict() -> Dictionary`, `from_dict(data: Dictionary) -> void`

### Viipale S6 (`06-held-items`)

#### 5. `HeldItem` (`extends RefCounted`, `src/core/state/held_item.gd`)

| Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- |
| `id` | `String` | `""` | Esineen yksilöllinen tunniste (esim. `"rod_1"`) |
| `item_type` | `String` | `"rod"` | Esineen tyyppi (`"rod"` tai `"net"`, lisätty S10) |
| `color_index` | `int` | `0` | Korostusväri-indeksi (`0 .. 5`) |
| `carrier_peer_id` | `int` | `0` | Kantavan pelaajan `peer_id` (`0` = telineessä tai kannella) |
| `holder_id` | `String` | `""` | Nykyisen telineen tunniste (`""` = kädessä tai kannella) |
| `last_holder_id` | `String` | `""` | Viimeisin teline disconnect-palautusta varten |
| `deck_position` | `Vector3` | `Vector3.ZERO` | Kansisijainti veneen paikallisessa koordinaatistossa, kun esine lojuu kannella (lisätty S10) |

**Apumetodit:** `is_carried() -> bool`, `is_on_deck() -> bool`, `copy_from(other: HeldItem) -> void`, `clone() -> HeldItem`
**Serialisointi:** `to_dict() -> Dictionary`, `from_dict(data: Dictionary) -> void`

### Viipale S8 (`08-trolling-lines`)

#### 6. `PlanerBoard` (`extends RefCounted`, `src/core/state/planer_board.gd`)

| Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- |
| `side` | `int` | `1` | Puoli: `SIDE_LEFT = -1`, `SIDE_RIGHT = +1` (telineen mukaan) |
| `attached` | `bool` | `true` | Onko pikkuplaanari kiinnitetty siimaan (oletus `true` kylkivavoissa `-3/-2`, `+2/+3`) |
| `lateral_offset` | `float` | `0.0` | Sivuetäisyys veneen keskilinjasta metreinä (`< 0` vasen, `> 0` oikea) |
| `line_out` | `float` | `0.0` | Vavasta ulkona olevan siiman pituus metreinä (**yksi totuuden lähde**) |
| `state` | `String` | `"STOWED"` | Tila: `"STOWED"`, `"DEPLOYING"`, `"TROLLING"`, `"TRIPPED"`, `"TANGLED"`, `"SNAGGED"` |
| `snag_world_position` | `Vector2` | `Vector2.ZERO` | Maailman 2D-lukituspiste esteeseen tarttumisessa (`SNAGGED`) |
| `pull_back_offset` | `float` | `0.0` | Kalan vedon aiheuttama lisäjättämä normaalin uintipaikan taakse metreinä (lisätty S9a) |
| `submersion` | `float` | `0.0` | Plaanarin uppoamissyvyys (`0.0` = pinnalla, `1.0` = pinnan alla, lisätty S9a) |
| `flag_angle` | `float` | `0.0` | Tärppilipun jatkuva kulma asteina (`0° .. -78°`, lisätty S9a) |
| `shake_intensity` | `float` | `0.0` | Kalan päänravistuksen nykimisintensiteetti (`0.0 .. 1.0`, lisätty S9a) |
| `inward_drift_force` | `float` | `0.0` | Kalan sisäänpäin keskilinjaan vetävä voima `m/s` (lisätty S9a) |

**Apumetodit:** `is_in_water() -> bool`, `is_active_trolling() -> bool`, `reset_strike_reaction() -> void`, `copy_from(other: PlanerBoard) -> void`, `clone() -> PlanerBoard`
**Johdetut arvot (ei replikoida):** Plaanarin ja vieheen 2D-maailmasijainti lasketaan `RodSimulator`-luokassa veneen sijainnista, suunnasta ja kentistä `lateral_offset` / `line_out`.
**Serialisointi:** `to_dict() -> Dictionary`, `from_dict(data: Dictionary) -> void`

#### 7. `RodState` (`extends RefCounted`, `src/core/state/rod_state.gd`)

| Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- |
| `rod_id` | `String` | `""` | Vastaavan `HeldItem`-esineen tunniste (esim. `"rod_1"`) |
| `trail_angle` | `float` | `0.0` | Suoran siiman kulmahitaus veneen perälinjaan nähden (rad) |
| `trail_factor` | `float` | `0.0` | Paikallaan olevan vieheen vaakaprojektiokerroin (`0.0 .. 1.0`) |
| `planer` | `PlanerBoard` | `PlanerBoard.new()` | Vapaan kuuluva plaanari- ja `line_out`-tila |
| `line_tension` | `float` | `0.0` | Siimaan kohdistuva todellinen vetojännitys (N, lisätty S11a) |
| `line_max_strength` | `float` | `100.0` | Siiman nimellinen murtolujuus ehjänä (N, lisätty S11a) |
| `drag_setting` | `float` | `60.0` | Kelan jarrun asetusarvo (`0.0 .. 125.0 N`, lisätty S11a) |
| `line_remaining_on_spool` | `float` | `150.0` | Puolalla jäljellä oleva varasiima (m, lisätty S11a) |
| `line_integrity` | `float` | `1.0` | Siiman kunto (`0.0 .. 1.0`, hankaumaraja `0.15`, lisätty S11a) |
| `is_drag_slipping` | `bool` | `false` | Luistaako kelan jarru parhaillaan (lisätty S11a) |

**Apumetodit:** `is_deployed() -> bool`, `get_line_out() -> float`, `get_effective_max_strength() -> float`, `reset_line_condition(spool_capacity: float = 150.0) -> void`, `copy_from(other: RodState) -> void`, `clone() -> RodState`
**Serialisointi:** `to_dict() -> Dictionary`, `from_dict(data: Dictionary) -> void`

### Viipaleet S9a–S9b (`09a-bite-and-reel`, `09b-planer-detach`)

#### 8. `FishState` (`extends RefCounted`, `src/core/state/fish_state.gd`)

| Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- |
| `rod_id` | `String` | `""` | Vastaavan vavan tunniste (`"rod_1" .. "rod_6"`) |
| `species` | `String` | `"perch"` | Laji: `"vendace"`, `"perch"`, `"zander"`, `"pike"`, `"orca"`, `"blue_whale"` |
| `weight_kg` | `float` | `0.5` | Kalan yksilöllinen paino kilogrammoina |
| `size_class` | `String` | `"SMALL"` | Kokoluokka painosta: `"SMALL"` (`< 1 kg`), `"MEDIUM"` (`1–4 kg`), `"LARGE"` (`4–8 kg`), `"MONSTER"` (`> 8 kg`) |
| `state` | `String` | `"HOOKED"` | Tila: `"HOOKED"` tai `"READY_TO_LAND"` |
| `stamina` | `float` | `1.0` | Jäljellä oleva kestävyys (`0.0 .. 1.0`, pienet lajit `0.0`) |
| `drag_rate` | `float` | `0.0` | Nykyinen jarruluisto- ja räikkänopeus (`m/s`) |
| `surge_timer` | `float` | `0.0` | Meneillään olevan syöksyn jäljellä oleva aika (`s`) |
| `surge_cooldown` | `float` | `2.0` | Aika seuraavaan syöksyyn (`s`) |
| `jump_progress` | `float` | `0.0` | Pintahypyn vaihe (`0.0 .. 1.0`) |
| `lift_progress` | `float` | `0.0` | Ilman haavia nostamisen `Space`-mittari (`0.0 .. 1.0`) |
| `detach_progress` | `float` | `0.0` | Plaanarin irrotusmittari (`0.0 .. 1.0`, lisätty S9b) |
| `scoop_progress` | `float` | `0.0` | Haavituksen `Space`-pitomittari (`0.0 .. 1.0`, lisätty S10) |
| `hooked_time` | `float` | `0.0` | Koukussa oltu kokonaisaika suojajaksoa varten (`s`) |
| `unattended_time` | `float` | `0.0` | Ilman kelausta kulunut aika (`s`) |
| `surfaced` | `bool` | `false` | Onko kala noussut pintaan näkyviin (`<= 8.0 m`) |
| `fight_phase` | `float` | `0.0` | Jatkuva taisteluvärinän vaihe radiaaneina (`0 .. TAU`) |

**Apumetodit:** `is_ready_to_land() -> bool`, `is_jumping() -> bool`, `is_drag_active() -> bool`, `compute_size_class(...) -> String`, `copy_from(other: FishState) -> void`, `clone() -> FishState`
**Serialisointi:** `to_dict() -> Dictionary`, `from_dict(data: Dictionary) -> void`

---

## Suunniteltu tietoskeema (tulevat viipaleet S11+ — ks. [`specs/02-mechanics/line-physics.md`](02-mechanics/line-physics.md) ja [`specs/02-mechanics/planer-boards.md`](02-mechanics/planer-boards.md))

> **Huomio Elävän skeeman säännöstä:** `PlanerBoard`, `RodState` (sis. jännityksen, jarrun, puolan, kunnon ja luiston `S11a`), `GameState.rods`, `FishState`, `GameState.fishes`, `PlayerInput.interact_held`, `PlayerInput.drag_input` (`S11a`), `HeldItem.deck_position`, `FishState.scoop_progress` ja `GameState.catches` (`10c`) on toteutettu viipaleissa `S8–S11a`. Tulevat pelimekaniikkalaajennukset lisätään toteutettuihin vasta kohdeviipaleissaan:
> - **`S11b` (`11b-line-visuals-and-rod-bend`):** Puhdas näkymäviipale (`src/view/`, ei tietoskeemadeltaa): 3D-siimakäyrä, vertex-värit/värinä, vavan taipuma ja visuaalinen kireys-/jarrumittari.
> - **`S11c` (`11c-fish-fatigue`):** Kalan syvempi väsytysmalli (`stamina`-silmukka).
> - **`S12` (`12-trolling-window-and-tangles`):** Uisteluikkunakalibrointi ja `TANGLED`-solmun selvitys kannella.
> - **`S16` (`16-lake-obstacles`):** `WorldFeatures`-saaret ja -karikot (`SNAGGED`), jotka syöttävät esteet `RodSimulator.step(..., obstacles)`-rajapintaan, sekä äkillinen shokkikuormakatkeaminen kovassa vauhdissa/jarrulla.
