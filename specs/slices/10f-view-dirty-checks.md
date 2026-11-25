# Slice 10f — Näkymän dirty-tarkistukset ja visuaalinen vavan kärki (`10f-view-dirty-checks`)

## 0. Tavoite

| Kohta | Arvo |
| :--- | :--- |
| **Nyt voin** | ajaa näkymäpäivitystä ilman turhia `get_layout_signature()`-, `get_node_or_null()`- ja `material_override`-kutsuja sekä nähdä siiman pysyvän kiinni taipuvan 3D-vavan kärjessä |
| **Uusi käsite** | Näkymäkerroksen dirty-tarkistus, solmujen näkyvyysvälimuisti ja 3D-vavan kärkisynkka |
| **Riippuvuudet** | `S6`, `S8`, `S9a`, `10e` |

## 1. Ei kuulu tähän viipaleeseen

- Core-simulaation telinehakemistot (`10g`)
- Verkkokoodekki (`10h`)

## 2. State Delta

Ks. `specs/01-state-schema.md`. Ei muutoksia `GameState`-verkkoskeemaan (vain `src/view/`).

| Luokka | Kenttä / Metodi | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- | :--- |
| `BoatView` | `layout_rebuild_count` | `int` | `0` | Laskuri telineasettelun uudelleenrakennuksille (`_configured_cfg`-pikapolku) |
| `BoatView` | `get_visual_rod_tip_world(item)` | `Vector3` | — | 3D-vavan kärjen maailmasijainti (sis. veneen kallistuksen ja vavan taipuman) |
| `WorldView` | `material_assign_count` | `int` | `0` | Laskuri todellisille `material_override`-muutoksille |
| `WorldView` | `get_line_start_world(rod_id)` | `Vector3` | `ZERO` | Piirretyn siiman todellinen alkupiste vavalle `rod_id` |

## 3. Rules & Math

- `BoatView.configure_holders` palaa välittömästi, jos `item_config == _configured_cfg` (ilman `get_layout_signature()`-merkkijonoa).
- `WorldView` tallentaa plaanari- ja kalasolmujen osaviitteet (`_planer_parts`, `_fish_parts`) luontihetkellä eikä kutsu `get_node_or_null`-polkuhakua päivityksessä.
- `_set_mat(mesh_instance, mat)` asettaa `material_override = mat` ja kasvattaa `material_assign_count += 1` vain, kun `mesh_instance.material_override != mat`.
- Vedessä olevan vavan viehe- ja kalasolmuja ei tuhota (`queue_free`) kalan hyppiessä ja sukeltaessa, vaan niiden `visible`-tilaa vaihdetaan; solmut vapautetaan vasta kun vapa kelataan ylös (`not rod.is_deployed()`).
- `WorldView._apply_trolling_rods` käyttää siiman alkupisteenä `boat_view.get_visual_rod_tip_world(item)`, joka lasketaan suoraan 3D-solmujen `transform`-ketjusta (`boat_view.transform * rod_node.transform * RESTING_TIP_LOCAL_OFFSET` tai kantajan `_held_item_anchor`-ketjusta).

## 4. Headless Acceptance Test

Tiedosto: `tests/test_10f_view_dirty_checks.gd` (5 testiä).

- `test_given_same_item_config_instance_when_apply_items_repeated_then_layout_not_rebuilt`
- `test_given_fish_jumping_and_diving_when_toggled_then_same_fish_and_lure_nodes_reused`
- `test_given_unchanged_planer_and_fish_state_when_applied_twice_then_materials_not_reassigned`
- `test_given_hooked_fish_bending_rod_when_trolling_lines_drawn_then_line_starts_at_visual_3d_rod_tip`
- `test_given_prompt_inputs_unchanged_when_applied_then_hud_prompts_remain_accurate`

## 5. Manuaalinen verifiointi

- Kalan nykiessä ja veneen keikkuessa siima pysyy kiinni vavan värillisessä kärjessä eikä irtoa ilmaan.

## 6. Tiedostot

| Polku | Toimenpide | Vastuu |
| :--- | :--- | :--- |
| `src/view/boat_view.gd` | `[MODIFY]` | `_configured_cfg`-pikapolku, `layout_rebuild_count`, `get_visual_rod_tip_world` |
| `src/view/player_view.gd` | `[MODIFY]` | `get_held_rod_tip_local_to_player()` 3D-transformketjua varten |
| `src/view/world_view.gd` | `[MODIFY]` | `_planer_parts`, `_fish_parts`, `_set_mat`, `visible`-uudelleenkäyttö ja visuaalinen siiman kärki |
| `tests/test_10f_view_dirty_checks.gd` | `[NEW]` | Viipaleen 10f hyväksymistestit |
