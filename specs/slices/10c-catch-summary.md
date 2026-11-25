# Slice 10c — Tiivistetty saalisloki (`10c-catch-summary`)

## 0. Tavoite

| Kohta | Arvo |
| :--- | :--- |
| **Nyt voin** | pelata pitkiä uistelusessioita ilman että kasvava saalismäärä hidastaa peliä tai paisuttaa verkkopaketteja |
| **Uusi käsite** | Tiivistetty saalisloki (`catch_count`, `biggest_catch_kg` ja rajattu `CATCH_LOG_MAX = 20`) |
| **Riippuvuudet** | `S5`, `S10` |

## 1. Ei kuulu tähän viipaleeseen

- Binäärinen snapshot-pakkaus (`10h`)
- Saalishistorian erillinen UI-näkymä

## 2. State Delta

Ks. `specs/01-state-schema.md`.

| Luokka | Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- | :--- |
| `GameState` | `catch_count` | `int` | `0` | Tiimin kokonaissaalismäärä (säilyy vaikka `catches`-loki rajataan) |
| `GameState` | `biggest_catch_kg` | `float` | `0.0` | Suurimman saaliin paino (kg, O(1)-haku) |

## 3. Rules & Math

- `record_catch` kasvattaa `catch_count += 1`, päivittää `biggest_catch_kg = maxf(biggest_catch_kg, weight_kg)` ja rajaa `catches`-taulukon korkeintaan `CATCH_LOG_MAX` viimeisimpään merkintään (`pop_front()`).
- `get_catch_count()` palauttaa `catch_count` ja `get_biggest_catch_weight()` palauttaa `biggest_catch_kg` ajassa $O(1)$.
- `SnapshotInterpolator` kloonaa `catches`-taulukon kohdetilaan vain silloin, kun `catch_count` tai `catches.size()` on muuttunut.

| Parametri | Arvo | Yksikkö |
| :--- | :--- | :--- |
| `CATCH_LOG_MAX` | `20` | kpl |

## 4. Headless Acceptance Test

Tiedosto: `tests/test_10c_catch_summary.gd` (5 testiä).

- `test_given_50_catches_when_recorded_then_count_50_log_capped_and_biggest_tracked`
- `test_given_summary_when_to_dict_from_dict_then_count_and_biggest_survive`
- `test_given_legacy_snapshot_without_catch_count_when_from_dict_then_falls_back_to_log`
- `test_given_500_catches_when_serialized_then_snapshot_size_bounded`
- `test_given_interpolator_without_new_catches_when_step_twice_then_catches_array_not_reallocated`

## 5. Manuaalinen verifiointi

- Headless-benchmark (`catches=1000`): snapshotin koko pysyy alle 12 kt:ssa ja interpolaattorin `step` alle 80 µs:ssa.

## 6. Tiedostot

| Polku | Toimenpide | Vastuu |
| :--- | :--- | :--- |
| `src/core/state/game_state.gd` | `[MODIFY]` | `CATCH_LOG_MAX`, `catch_count`, `biggest_catch_kg` ja $O(1)$-apumetodit |
| `src/network/snapshot_interpolator.gd` | `[MODIFY]` | `latest_catch_count`, `latest_biggest_catch_kg` ja ehdollinen `catches`-kloonaus |
| `tests/test_10c_catch_summary.gd` | `[NEW]` | Viipaleen 10c hyväksymistestit |
