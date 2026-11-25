# Slice 11b — Line Visuals, Rod Bend & HUD Meter (`11b-line-visuals-and-rod-bend`)

## 0. Tavoite

| Kohta | Arvo |
| :--- | :--- |
| **Nyt voin** | nähdä siiman virtauskaaren (löysä pussittaa vs. kireä suoristuu, `>= 80 %` värisee ja muuttuu punaiseksi 0 lisäpiirtokutsulla), vavan kaksivaiheisen taipuman kireyden mukaan telineessä ja kädessä sekä graafisen kireys-, jarru- ja puolamittarin HUDissa |
| **Uusi käsite** | Jännitysreaktiivinen 3D-siimakäyrä (vertex-värit & värinä), kaksiosainen vavan taipuma ja graafinen kireys-/jarrumittari (`src/view/`) |
| **Riippuvuudet** | `S8`, `S9a`, `10e`, `10f`, `S11a` |

## 1. Ei kuulu tähän viipaleeseen

- `src/core/`-simulaatio- tai tietoskeemamuutokset (`S11a` valmis)
- Kalan aktiivinen väsytysrytmi (`S11c`) ja karikkoshokkikuorma (`S16`)

## 2. State Delta

Ks. `specs/01-state-schema.md`. Ei muutoksia `GameState`-verkkoskeemaan (puhdas `src/view/`-viipale).

| Luokka | Kenttä / Metodi | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- | :--- |
| `WorldView` | `compute_line_color(...)`, `get_line_points_world(rod_id)`, `get_line_color(rod_id)` | `Color`, `PackedVector3Array` | — | Siimakäyrän väri- ja kärkipisteiden lukurajapinta |
| `WorldView` | `tension_meter_root` (`tension_bar_fill`, `tension_danger_zone`, `drag_marker`, `spool_bar_fill`, otsikko/alatunniste) | `Control` / `ColorRect` | piilotettu | Graafinen kireys-, jarru- ja puolamittari |
| `BoatView` | `TipPivot`, `apply_items(..., rods)`, `apply_players(..., rods)`, `get_resting_rod_bend_degrees(rod_id)` | `Node3D`, `float` | `0.0` | Telinevavan kaksiosainen taipuma ja kärkisynkka |
| `PlayerView` | `_held_tip_pivot`, `apply_held_item(item, fish, rod)`, `get_held_rod_bend_degrees()` | `Node3D`, `float` | `0.0` | Käsivavan kaksiosainen taipuma ja kärkisynkka |

## 3. Rules & Math

| Parametri | Arvo | Yksikkö |
| :--- | :--- | :--- |
| `LINE_HIGH_RATIO` / `LINE_CRITICAL_RATIO` | `0.55` / `0.80` | osuus |
| `SLACK_MAX_SAG` / `TAUT_MIN_SAG` | `1.10` / `0.025` | m |
| `VIB_AMP` (`>= 80 %` / luisto) | `0.035..0.085` / `0.012` | m |
| `MAX_ROD_BEND_DEG` / `METER_BAR_WIDTH` | `46.0` / `252.0` | ° / px |

- **Siimakäyrä:** 5-pisteen parabeli (4 segmenttiä pääsiima, 2 peruke) yhden `ImmediateMesh`-pinnan ja `_line_mat.vertex_color_use_as_albedo = true` sisällä (`0` uutta draw callia). Löysä (`< 10 N`) pussittaa alas/perää kohti; kireä suoristuu; `>= 80 %` värisee ja muuttuu punaiseksi; päätepisteet pysyvät kiinni kärjessä ja vieheessä/plaanarissa.
- **Vavan taipuma:** `Shaft` + `TipPivot` (0 uutta draw callia) taipuu `line_tension / effective_max_strength` -suhteessa (säilyttäen kalan nykäykset ja `S10f`-vähimmäistaipuman, kun `tension_ratio < 0.02`); `get_visual_rod_tip_world` seuraa `TipPivot`-ketjua.
- **HUD-mittari:** `tension_meter_root` näkyy vapa kädessä tai telineen vieressä (piilossa ruorissa / tyhjäkäsin / haavilla), näyttää `0..125 N` -kireyspalkin, liukuvan `drag_marker`-jarruosoittimen, `effective_max_strength`-murtorajan (`tension_danger_zone`) ja puolapalkin (`0..150 m`).

## 4. Headless Acceptance Test

Tiedosto: `tests/test_11b_line_visuals_and_rod_bend.gd` (5 testiä).

- `test_given_slack_vs_taut_rod_when_applied_to_world_view_then_slack_sags_more_and_uses_single_surface`: **Given** löysä ja kireä uisteluvapa **When** näkymä päivitetään **Then** löysä pussittaa selvästi enemmän ja piirto pysyy yhdessä `ImmediateMesh`-pinnassa vertex-väreillä.
- `test_given_critical_tension_over_80_percent_when_stepped_then_line_turns_warning_red_and_vibrates_with_pinned_endpoints`: **Given** tuore ja kulunut `>= 80 %` kriittinen siima sekä rauhallinen siima **When** näkymää askelletaan **Then** kriittiset siimat värjäytyvät punaiseksi ja värisevät päätepisteet lukittuna.
- `test_given_increasing_line_tension_when_applied_to_resting_and_held_rods_then_bend_increases_and_line_stays_attached`: **Given** teline- ja käsivapa **When** `line_tension` kasvaa `0 -> 40 -> 90 N` **Then** molempien taipuma kasvaa ja siima pysyy kiinni taipuneen kärjen päässä.
- `test_given_active_rod_when_tension_drag_and_integrity_change_then_hud_meter_updates_fill_marker_and_danger_zone`: **Given** aktiivinen vapa **When** kireys, jarru, puola ja kuluminen muuttuvat **Then** HUD-mittari näkyy vain vavan äärellä/kädessä ja päivittää täytön, jarruosoittimen, vaaravyöhykkeen sekä puolan.
- `test_given_unchanged_view_state_when_reapplied_then_no_material_reassignments_and_single_draw_call_preserved`: **Given** muuttumaton 4 vavan näkymätila **When** `apply_game_state` kutsutaan uudelleen **Then** `material_assign_count` ei kasva ja pinta pysyy yhtenä.

## 5. Manuaalinen verifiointi

- Aja `bash tools/test-snapshot.sh whale_strike_2s` tai laske vavat veteen, vertaa löysää vs. kireää siimaa, säädä jarrua `Z`/`X` (HUD-palkki ja `drag_marker`), pakota tärppi (`F`) ja testaa `>= 80 %` punainen värinä sekä vavan kaareva taipuma; varmista `FPS >= 60`, `Draw Calls < 100`, `Tris < 20 000`.

## 6. Tiedostot

| Polku | Toimenpide | Vastuu |
| :--- | :--- | :--- |
| `src/view/player_view.gd` | `[MODIFY]` | Käsivavan `TipPivot`, kaksiosainen jännitystaipuma ja kärkisynkka |
| `src/view/boat_view.gd` | `[MODIFY]` | Telinevavan `TipPivot`, `rods`-taipuma ja kärkisynkka |
| `src/view/world_view.gd` | `[MODIFY]` | Vertex-väritetty 3D-siimakäyrä, `>= 80 %` värinä ja graafinen HUD-mittari |
| `tests/test_11b_line_visuals_and_rod_bend.gd` | `[NEW]` | 5 hyväksymistestiä |
