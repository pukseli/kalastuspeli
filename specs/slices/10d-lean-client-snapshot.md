# Slice 10d — Kevyt client-snapshot ja aikajärjestys (`10d-lean-client-snapshot`)

## 0. Tavoite

| Kohta | Arvo |
| :--- | :--- |
| **Nyt voin** | liittyä peliin clientinä ilman kaksinkertaista snapshotin parsintaa, turhia `to_dict()`-allokaatioita tai vanhan paketin aiheuttamaa aikahyppyä taaksepäin |
| **Uusi käsite** | Kertaparsittu snapshot (`GameState.new(false)`, `copy_from` ja monotoninen `tick`-suodatus) |
| **Riippuvuudet** | `S5`, `10c` |

## 1. Ei kuulu tähän viipaleeseen

- Binäärinen verkkokoodekki (`10h`)
- Render-interpolointi `_process`-silmukassa (`10e`)

## 2. State Delta

Ks. `specs/01-state-schema.md`.

| Luokka | Kenttä / Metodi | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- | :--- |
| `GameState` | `_init(populate_defaults)` | `bool` | `true` | `false` luo tyhjän tilan ilman oletusesineiden allokointia |
| `FishState` / `PlanerBoard` / `HeldItem` | `copy_from(other)` | `void` | — | Suora kenttäkopio ilman `to_dict()`/`from_dict()`-välisanakirjaa |
| `SnapshotInterpolator` | `item_config` / `get_latest_state()` | `ItemConfig` / `GameState` | `null` | Jakaa jo parsitun uusimman tilan clientille |

## 3. Rules & Math

- `SnapshotInterpolator.push_snapshot` luo `GameState.new(false)`, asettaa `parsed.item_config = item_config` (jos asetettu) ja parsii snapshotin kerran.
- `SnapshotInterpolator` kopioi `FishState`-, `PlanerBoard`- ja `HeldItem`-oliot `copy_from`-metodilla ilman `to_dict()`-allokaatiota.
- `NetworkManager.step_game_tick` ohittaa `game_state.to_dict()`-kutsun, kun `mode == "offline"`.
- `NetworkManager.apply_game_snapshot` hylkää snapshotin, jos `game_state.tick > 0` ja `int(snapshot.get("tick", 0)) < game_state.tick`.
- `NetworkManager.receive_incoming_game_snapshot` säilyttää pakettien järjestyksen, kun viive pudotetaan nollaan (`_incoming_snapshot_queue` ei ohitu).

## 4. Headless Acceptance Test

Tiedosto: `tests/test_10d_lean_client_snapshot.gd` (5 testiä).

- `test_given_bare_game_state_when_created_then_items_and_rods_empty`
- `test_given_states_when_copy_from_then_all_fields_equal_without_dict_roundtrip`
- `test_given_pushed_snapshot_when_get_latest_state_then_parsed_state_uses_configured_item_config`
- `test_given_out_of_order_snapshot_or_latency_drop_when_applied_then_older_tick_rejected`
- `test_given_offline_vs_host_mode_when_snapshot_tick_then_offline_skips_and_host_emits`

## 5. Manuaalinen verifiointi

- Headless-benchmark (`catches=0`): `push` ja `step` pienenevät eikä `SnapshotInterpolator` sisällä yhtään `to_dict()`-kutsua.

## 6. Tiedostot

| Polku | Toimenpide | Vastuu |
| :--- | :--- | :--- |
| `src/core/state/game_state.gd` | `[MODIFY]` | `_init(populate_defaults: bool = true)` |
| `src/core/state/fish_state.gd` | `[MODIFY]` | `copy_from(other: FishState)` |
| `src/core/state/planer_board.gd` | `[MODIFY]` | `copy_from(other: PlanerBoard)` |
| `src/core/state/held_item.gd` | `[MODIFY]` | `copy_from(other: HeldItem)` |
| `src/network/snapshot_interpolator.gd` | `[MODIFY]` | `GameState.new(false)`, `item_config`, `get_latest_state()`, `copy_from` |
| `src/network/network_manager.gd` | `[MODIFY]` | Offline `to_dict`-ohitus, vanhan `tick`:n hylkäys ja tyhjän jonon pikapolku |
| `src/main.gd` | `[MODIFY]` | Kertaparsinta `get_latest_state()`-viitteellä |
| `tests/test_10d_lean_client_snapshot.gd` | `[NEW]` | Viipaleen 10d hyväksymistestit |
