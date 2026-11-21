# 01 — Elävä Tietoskeema (Living State Schema)

> **Sääntö:** Tämä dokumentti kuvaa kulloinkin toteutettujen viipaleiden tietorakenteet (`src/core/state/`). Tulevien viipaleiden (esim. vavat, kalat, AI Directorin kaaostapahtumat) tietorakenteet lisätään tähän vasta kyseisen viipaleen yhteydessä.

---

## Viipale 1 (`01-boat-and-deck-core`) — Tietorakenteet

### 1. `BoatState` (`extends RefCounted`, `src/core/state/boat_state.gd`)

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `world_position` | `Vector3` | `Vector3.ZERO` | Veneen sijainti maailmankoordinaatistossa |
| `heading` | `float` | `0.0` | Keulan suunta radiaaneina (`0` = `-Z` eteenpäin) |
| `forward_speed` | `float` | `0.0` | Etenemisnopeus (m/s) |
| `throttle` | `float` | `0.0` | Kaasusyöte (`-1.0 .. 1.0`) |
| `steering_input` | `float` | `0.0` | Ohjaussyöte (`-1.0 .. 1.0`) |
| `driver_peer_id` | `int` | `0` | Ruorissa olevan pelaajan `peer_id` (`0` = ei kuskia) |
| `deck_half_extents` | `Vector2` | `Vector2(1.8, 3.6)` | Kannen kävelyalueen puolileveys (`X`) ja puolipituus (`Z`) metreinä |

**Serialisointi:** `to_dict() -> Dictionary`, `from_dict(data: Dictionary) -> void`

---

### 2. `PlayerState` (`extends RefCounted`, `src/core/state/player_state.gd`)

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `peer_id` | `int` | `0` | Verkkopelaajan yksilöivä tunniste |
| `slot_index` | `int` | `0` | Paikkaindeksi (`0..3`), määrittää pelaajakapselin värin ja aloituspisteen |
| `local_position` | `Vector3` | `Vector3.ZERO` | Sijainti **veneen paikallisessa koordinaatistossa** kannen päällä |
| `local_yaw` | `float` | `0.0` | Katsesuunta veneen koordinaatistossa radiaaneina |
| `move_input` | `Vector2` | `Vector2.ZERO` | Liikesyöte kannella (`X` = sivuttain, `Y` = eteen/taakse, `-1.0 .. 1.0`) |
| `is_driving_boat` | `bool` | `false` | Ohjaako pelaaja parhaillaan venettä |

**Serialisointi:** `to_dict() -> Dictionary`, `from_dict(data: Dictionary) -> void`

---

### 3. `GameState` (`extends RefCounted`, `src/core/state/game_state.gd`)

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `tick` | `int` | `0` | Simulaation tick-laskuri |
| `boat` | `BoatState` | `BoatState.new()` | Veneen nykyinen tila |
| `players` | `Dictionary` | `{}` | Pelaajakartta: `int (peer_id) -> PlayerState` |

**Metodit ja Serialisointi:**

| Method | Signature | Description |
| :--- | :--- | :--- |
| `add_player` | `add_player(peer_id: int) -> PlayerState` | Lisää pelaajan annetulla `peer_id`:llä ja palauttaa luodun `PlayerState`-instanssin |
| `remove_player` | `remove_player(peer_id: int) -> void` | Poistaa pelaajan `players`-sanakirjasta |
| `get_player` | `get_player(peer_id: int) -> PlayerState` | Palauttaa pelaajan `PlayerState`-instanssin (tai `null` jos puuttuu) |
| `to_dict` | `to_dict() -> Dictionary` | Serialisoi koko pelitilan (`tick`, `boat`, `players`) sanakirjaksi |
| `from_dict` | `from_dict(data: Dictionary) -> void` | Palauttaa pelitilan sanakirjasta |
