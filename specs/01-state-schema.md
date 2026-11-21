# 01 — Elävä Tietoskeema (Living State Schema)

> **Sääntö:** Tämä dokumentti kuvaa kulloinkin toteutettujen viipaleiden tietorakenteet (`src/core/state/`). Tulevien viipaleiden (esim. vavat, kalat, AI Directorin kaaostapahtumat) tietorakenteet lisätään tähän vasta kyseisen viipaleen yhteydessä.

## Skeemasäännöt

| Sääntö | Perustelu | Esimerkki |
| :--- | :--- | :--- |
| **Yksi totuuden lähde:** ei johdettuja kenttiä kahteen paikkaan | Estää ristiriitaiset tilat | `driver_peer_id` veneessä; "ajaako pelaaja" johdetaan siitä, ei erillistä `is_driving_boat`-kenttää |
| **Syöte ≠ tila:** asiakkaan syötteet erillisessä `PlayerInput`-rakenteessa | Server-authoritative-malli: asiakas lähettää aikeet, palvelin päättää tuloksen | `move_input`, `throttle` ja `steering` kuuluvat `PlayerInput`-rakenteeseen, eivät replikoituun tilaan |
| **Staattinen konfiguraatio ei kuulu replikoituun tilaan** | Ei turhaa verkkoliikennettä 20 kertaa sekunnissa | Kannen mitat `const`- tai `BoatConfig`-arvona |
| **Serialisointi:** jokaisella tilaluokalla `to_dict()` / `from_dict()` | Verkkovalmius | — |

## Toteutetut tietorakenteet

### Viipale S1 (`01-boat-on-water`)

#### 1. `BoatState` (`extends RefCounted`, `src/core/state/boat_state.gd`)

| Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- |
| `world_position` | `Vector3` | `Vector3.ZERO` | Veneen sijainti maailmankoordinaatistossa |
| `heading` | `float` | `0.0` | Keulan suunta radiaaneina (`0` = `-Z` eteenpäin) |
| `forward_speed` | `float` | `0.0` | Etenemisnopeus (m/s) |

**Serialisointi:** `to_dict() -> Dictionary`, `from_dict(data: Dictionary) -> void`

#### 2. `PlayerInput` (`extends RefCounted`, `src/core/state/player_input.gd`)

| Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- |
| `throttle` | `float` | `0.0` | Kaasusyöte (`-1.0 .. 1.0`, erillään replikoidusta venetilasta) |
| `steering` | `float` | `0.0` | Ohjaussyöte (`-1.0 .. 1.0`, `+1.0` vasen, `-1.0` oikea) |
| `move_x` | `float` | `0.0` | Kansikävelysyöte X-akselilla (`-1.0 .. 1.0`: `A = -1.0`, `D = +1.0`, lisätty S3) |
| `move_z` | `float` | `0.0` | Kansikävelysyöte Z-akselilla (`-1.0 .. 1.0`: `W = -1.0` keulaan, `S = +1.0` perään, lisätty S3) |

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
| `tick` | `int` | `0` | Simulaation tick-laskuri (valmis S6-interpolointiin) |
| `boat` | `BoatState` | `BoatState.new()` | Veneen maailmatila |
| `players` | `Dictionary` | `{}` | `peer_id: int -> PlayerState` |

**Apumetodit:** `ensure_player(peer_id: int, is_bot: bool = false) -> PlayerState`, `remove_player(peer_id: int) -> void`
**Serialisointi:** `to_dict() -> Dictionary`, `from_dict(data: Dictionary) -> void`
