# Slice 02 — Two Windows, One Boat (`02-two-windows-one-boat`)

## 0. Tavoite

| Kohta | Arvo |
| :--- | :--- |
| **Nyt voin** | nähdä saman veneen kahdessa ikkunassa (`--host` / `--join` / `--port` / `--sync-hz`) ja vaihtaa tickratea lennosta (`T`) |
| **Uusi käsite** | 3-kerroksinen verkkosynkka (`NetworkTransport` + `NetworkManager`, vain `BoatState`, säädettävä tickrate) |
| **Riippuvuudet** | `S1` (`01-boat-on-water`) |

## 1. Ei kuulu tähän viipaleeseen

- Pelaajakapselit ja paikallinen kansikoordinaatisto (`S3`)
- Ruorin vuorottelu (`driver_peer_id`), vauhtisauva ja ohjauspyörä (`S4`)
- Interpolointi (`S5`) ja Lobby UI (`S6`)

## 2. State Delta

Ks. `specs/01-state-schema.md` (käyttää S1:n `BoatState`- ja `PlayerInput`-luokkia ilman uusia replikoitavia tilaluokkia).

| Luokka | Polku | Kuvaus |
| :--- | :--- | :--- |
| `NetworkTransport` | `src/network/network_transport.gd` | `ENetMultiplayerPeer`-tehdas (`create_host_peer`, `create_client_peer`, bind `*`) |
| `NetworkManager` | `src/network/network_manager.gd` | CLI-jäsennys, Host/Client-tila, `sync_rate_hz`, syöte-RPC ja `BoatState`-snapshot |

## 3. Rules & Math

- `NetworkManager.parse_cli_args(args: PackedStringArray) -> Dictionary`: jäsentää `--host` (`mode="host"`), `--join [ip]` (`mode="client"`, oletus `"127.0.0.1"`), `--port <int>` (oletus `7777`), `--sync-hz <int>` (oletus `20`), muuten `mode="offline"`.
- `cycle_sync_rate() -> int` kiertää taajuudet `[20, 30, 60, 5, 10]` (`T`-näppäin pelissä); `get_snapshot_interval_ticks() = maxi(1, roundi(60.0 / float(sync_rate_hz)))`.
- `is_authority() == (mode != "client")`: Host/Offline yhdistää `host_input` + `client_inputs` (`clampf(..., -1.0, 1.0)`), kutsuu `BoatSimulator.step()` 60 Hz taajuudella ja lähettää `BoatState.to_dict()`-snapshotin joka `get_snapshot_interval_ticks()` tickillä.
- Client ei aja `BoatSimulator.step()`-kutsua, vaan lähettää `PlayerInput.to_dict()` Hostille ja päivittää `boat_state.from_dict(snapshot)` vastaanottaessaan snapshotin.

| Parametri | Arvo | Yksikkö |
| :--- | :--- | :--- |
| `DEFAULT_PORT` | `7777` | UDP port |
| `DEFAULT_ADDRESS` | `"127.0.0.1"` | IPv4 |
| `DEFAULT_SYNC_HZ` | `20` | Hz (every 3 ticks at 60 Hz) |
| `SYNC_RATE_PRESETS` | `[20, 30, 60, 5, 10]` | Hz |

## 4. Headless Acceptance Test

Tiedosto: `tests/test_02_two_windows_one_boat.gd` (4 testiä).

- `test_parse_cli_args_modes_and_defaults`: **Given** CLI-vivut (`--host`, `--join`, `--port`, `--sync-hz`) **When** `parse_cli_args` kutsutaan **Then** palauttaa oikean `mode`, `address`, `port` ja `sync_hz`.
- `test_transport_creates_host_and_client_peers`: **Given** `NetworkTransport` **When** `create_host_peer` ja `create_client_peer` kutsutaan **Then** palauttaa toimivat `ENetMultiplayerPeer`-oliot.
- `test_client_input_drives_host_boat_simulation`: **Given** Host `NetworkManager` **When** `receive_client_input(2, {"throttle": 1.0, "steering": 0.5})` ja 30 tickiä ajetaan **Then** Hostin vene liikkuu ja kääntyy.
- `test_configurable_sync_rate_and_client_snapshot_apply`: **Given** Host ja Client `NetworkManager` **When** `cycle_sync_rate()` ja `step_network_tick()` ajetaan **Then** snapshot syntyy täsmälleen valitun `sync_rate_hz`-taajuuden jaksolla ja päivittää Clientin `BoatState`-olion.

## 5. Manuaalinen verifiointi

- Käynnistä Host (`-- --host`) ja Client (`-- --join 127.0.0.1`) vierekkäin, aja venettä kummasta tahansa ikkunasta, vaihda tickratea `T`-näppäimellä ja tarkista HUD (`Net: HOST/CLIENT | Sync: XX Hz`).

## 6. Tiedostot

| Polku | Toimenpide | Vastuu |
| :--- | :--- | :--- |
| `src/network/network_transport.gd` | `[NEW]` | `NetworkTransport` (`create_host_peer`, `create_client_peer`) |
| `src/network/network_manager.gd` | `[NEW]` | `NetworkManager` (CLI, `sync_rate_hz`, RPC:t, 20 Hz snapshot) |
| `src/main.gd` | `[MODIFY]` | Kytkee `NetworkManager`, CLI-käynnistyksen ja `T`-näppäimen |
| `src/view/world_view.gd` | `[MODIFY]` | Näyttää `net_mode` ja `sync_rate_hz` debug-HUDissa |

<!-- Raja: ≤ 60 ei-tyhjää riviä. Jos ylittyy → pilko viipale (00-architecture.md §5). -->
