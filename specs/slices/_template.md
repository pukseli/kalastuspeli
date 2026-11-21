# Slice NN — <Nimi> (`NN-<slug>`)

## 0. Tavoite

| Kohta | Arvo |
| :--- | :--- |
| **Nyt voin** | `<mitä pelaaja/kehittäjä voi nyt tehdä>` |
| **Uusi käsite** | `<yksi uusi arkkitehtuurikäsite>` |
| **Riippuvuudet** | `<aiemmat viipaleet>` |

## 1. Ei kuulu tähän viipaleeseen

- `<asia 1>`
- `<asia 2>`

## 2. State Delta

Ks. `specs/01-state-schema.md`.

| Luokka | Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- | :--- |
| `<Luokka>` | `<kenttä>` | `<Tyyppi>` | `<oletus>` | `<kuvaus>` |

## 3. Rules & Math

- `<sääntö tai kaava>`

| Parametri | Arvo | Yksikkö |
| :--- | :--- | :--- |
| `<PARAM>` | `<arvo>` | `<yksikkö>` |

## 4. Headless Acceptance Test

Tiedosto: `tests/test_NN_<slug>.gd` (enintään 5 testiä).

- `test_<nimi>`: **Given** `<alkutila>` **When** `<toiminto>` **Then** `<odotettu tulos>`

## 5. Manuaalinen verifiointi

- `<mitä käyttäjä tekee ja näkee ruudulla; view-viipaleissa myös budjettitarkistus>`

## 6. Tiedostot

| Polku | Toimenpide | Vastuu |
| :--- | :--- | :--- |
| `<polku>` | `[NEW]` / `[MODIFY]` | `<vastuu>` |

<!-- Raja: ≤ 60 ei-tyhjää riviä. Jos ylittyy → pilko viipale (00-architecture.md §5). -->
