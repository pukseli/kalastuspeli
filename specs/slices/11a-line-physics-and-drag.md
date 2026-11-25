# Slice 11a — Line Physics & Reel Drag (`11a-line-physics-and-drag`)

## 0. Tavoite

| Kohta | Arvo |
| :--- | :--- |
| **Nyt voin** | hallita siiman kireyttä ja säätää kelan jarrua (`Z`/`X`): kireä uistelu ei katkaise siimaa, jarru luistaa suojaten siimaa (ja estää kelauksen syöksyssä), ylikiristys/tyhjä puola/hankauma katkaisee (`TANGLED`), löysä siima päästää aktiivisen kalan ja tila näkyy HUDissa sekä verkon yli |
| **Uusi käsite** | `LinePhysics` (`src/core/simulation/line_physics.gd`), `RodState`-jännitys/jarru/puola/kunto ja `PlayerInput.drag_input` |
| **Riippuvuudet** | `S8`, `S9a`, `S9b`, `S10`, `10d`, `10g` |

## 1. Ei kuulu tähän viipaleeseen

- 3D-siimakäyrä (parabeli/vertex-värit/värinä), vavan taipuma ja graafinen mittari (`S11b`)
- Kalan aktiivinen väsytysrytmi (`S11c`), kovavauhtinen shokkikuorma (`S16`) ja solmun selvitys kannella (`S12`)

## 2. State Delta

Ks. `specs/01-state-schema.md`.

| Luokka | Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- | :--- |
| `RodState` | `line_tension`, `line_max_strength`, `drag_setting`, `line_remaining_on_spool`, `line_integrity`, `is_drag_slipping` | `float`, `bool` | `0.0`, `100.0`, `60.0`, `150.0`, `1.0`, `false` | Jännitys (N), vetolujuus, jarru (`0..125 N`), varasiima (m), kunto (`0..1`), luisto; lisätään `get_effective_max_strength()`, `reset_line_condition()`, `copy_from()` |
| `PlayerInput` | `drag_input` | `float` | `0.0` | Jarrun säätö (`-1.0` `Z` löysää, `+1.0` `X` kiristä) |

## 3. Rules & Math

| Parametri | Arvo | Yksikkö |
| :--- | :--- | :--- |
| `LINE_MAX_STRENGTH` / `DEFAULT_DRAG` / `DRAG_RANGE` | `100.0` / `60.0` / `0.0 .. 125.0` | N |
| `SPOOL_CAPACITY` / `MAX_DEPLOY_LINE_OUT` / `SNAP_STUB_LINE_OUT` | `150.0` / `35.0` / `6.0` | m |
| `FISH_PULL_TO_NEWTONS` / `DRAG_SLIP_GAIN` / `MAX_DRAG_SLIP_SPEED` | `60.0` / `1/60` / `2.0` | N / m·s⁻¹·N⁻¹ / m/s |
| `WATER_DRAG` (`base`/`per_m`/`planer`/`tripped`) / `REEL_LOAD` | `3.0`/`0.15`/`2.5`/`0.5` / `15.0` | N·s/m / N |
| `SNAG_BASE_PULL` / `SNAG_STRETCH_GAIN` | `20.0` / `30.0` | N / N/m |
| `ABRASION_SNAGGED` / `ABRASION_TANGLED` / `MIN_ABRASION_INTEGRITY` | `0.05` / `0.06` / `0.15` | s⁻¹ / s⁻¹ / — |
| `SLACK_TENSION_THRESHOLD` / `SLACK_ESCAPE_HAZARD` / `DRAG_ADJUST_RATE` | `10.0` / `+0.40` / `40.0` | N / s⁻¹ / N/s |

- **Voima & jarru (`LinePhysics.step_rod_line`):** `RodSimulator.step` kutsuu kalattomille, `FishSimulator.step` kalallisille (1 ajo/vapa/tick). $F_{\text{water}} = \max(0, v_{\text{fwd}}) \cdot (3.0 + 0.15 \cdot \text{line\_out} + k_{\text{planer}})$, $F_{\text{fish}} = \text{raw\_pull} \cdot 60.0$, $F_{\text{snag}} = 20.0 + 30.0 \cdot \max(0, \text{snag\_dist} - \text{line\_out})$ kun `SNAGGED`, $F_{\text{ext}} = F_{\text{water}} + F_{\text{fish}} + F_{\text{snag}}$, $F_{\text{load}} = F_{\text{ext}} + F_{\text{reel}}$. Kun puolalla siimaa (`> 0`) ja $F_{\text{ext}} > \text{drag\_setting}$ → `is_drag_slipping = true`, `line_tension = drag_setting`, $v_{\text{slip}} = \text{clampf}((F_{\text{ext}} - \text{drag\_setting})/60.0, 0, 2.0)$ (josta `FishState.drag_rate` johdetaan), `line_out += delta_out` & `line_remaining_on_spool -= delta_out` (ei irrotuksen aikana). Muuten `is_drag_slipping = false` ja `line_tension = min(F_load, drag_setting)` kun puolalla siimaa (tai `F_load` jos puola tyhjä).
- **Kelaus & `Z`/`X`:** `RodSimulator._process_drag_inputs` säätää kädessä olevan tai lähimmän telinevavan `drag_setting`-arvoa `±40 N/s` myös kalan ollessa kiinni. Kalavavan `Space`-kelaus estyy kun `is_drag_slipping`; muuten nopeus on `spec.reel_speed * lerpf(0.60, 1.0, (drag_setting - F_ext) / max(1, drag_setting))`. Manuaalinen lasku (`Q`/`Shift`) pysyy `<= 35.0 m` ja päivittää `line_remaining_on_spool ± delta_line`.
- **Katkeaminen & palautuminen:** `SNAGGED` (`-0.05/s`) ja `TANGLED` (`-0.06/s`, `line_out > 0`) laskevat `line_integrity`:ä (`>= 0.15`). Kun `line_tension >= line_max_strength * line_integrity` (ja vapa ei ole jo kalaton `TANGLED`-tynkä): kala karkaa, HUD-ilmoitus syystä, `attached = false`, `state = TANGLED`, `line_out = clampf(line_out, 2.0, 6.0)`, `line_tension = 0.0`, `is_drag_slipping = false`. Kelaus `0 m → STOWED` kutsuu `reset_line_condition()` (`1.0` / `150.0 m`) ja palauttaa oletusplaanarin.
- **Löysä siima (`hook slip`):** Kun aktiivisen kalan (`HOOKED`, `stamina > 0.05`, `hooked_time >= grace_period_sec`, ei irrotuksessa) `line_tension < 10.0 N`, `FishSimulator` lisää ravistusrullaan `+0.40 /s` myös syöksyjen ulkopuolella.
- **Verkko & HUD:** `NetworkManager` välittää `drag_input`; `SnapshotInterpolator` interpoloi jatkuvat ja kopioi diskreetit (`copy_from`). `WorldView` näyttää `line_prompt`-tekstissä `[Z/X]`-jarrun (`N`), kireyden (`%`), puolan (`m`) ja `[RÄIKKÄ!]`/`[LÖYSÄ!]`, sekä soittaa räikkää myös `is_drag_slipping`-tilasta.

## 4. Headless Acceptance Test

Tiedosto: `tests/test_11a_line_physics_and_drag.gd` (5 testiä).

- `test_given_taut_trolling_and_safe_drag_when_fish_surges_then_drag_slips_blocks_reel_and_never_snaps`: **Given** kireä uisteluvapa ja 60 N jarru **When** uistellaan 60 s ja kala syöksyy **Then** siima ei katkea, jarru luistaa, kelaus estyy syöksyssä ja onnistuu rauhallisena.
- `test_given_overtight_drag_or_empty_spool_when_fish_pulls_then_line_snaps_to_tangled_and_recovers_on_stowed`: **Given** ylikireä jarru (120 N) tai tyhjentyvä puola **When** kala vetää **Then** siima katkeaa `TANGLED`-tyngäksi (`2..6 m`), ilmoittaa syyn ja palautuu `STOWED`-tilassa (`1.0` / `150 m`).
- `test_given_tangled_or_snagged_rod_when_abraded_then_integrity_drops_and_lower_load_snaps_line`: **Given** `SNAGGED`/`TANGLED`-vapa **When** hankauma laskee `line_integrity`:ä **Then** pienempi veto katkaisee kuluneen siiman eikä tynkä katkea uudelleen silmukassa.
- `test_given_slack_line_when_active_fish_hooked_then_escape_rate_spikes_while_tired_fish_stay_safe`: **Given** aktiivinen vs. väsynyt kala **When** siima löystyy (`< 10 N`) **Then** aktiivinen karkaa selvästi kireää useammin, kun taas väsynyt pysyy koukussa.
- `test_given_drag_input_when_synced_over_network_then_drag_adjusts_interpolates_and_renders_hud`: **Given** `drag_input`, `NetworkManager`, `SnapshotInterpolator` ja `WorldView` **When** jarrua säädetään ja synkataan **Then** jarru rajoittuu `[0, 125]`, tila interpoloituu ja `line_prompt` näyttää `[Z/X]`, jarrun, `%`, puolan ja `[RÄIKKÄ!]`.

## 5. Manuaalinen verifiointi

- Testaa 1–2 ikkunassa: uistele vavat ulkona, säädä jarrua `Z`/`X` kädessä ja telineellä, pakota tärppi (`F`), kokeile luistoa (`60 N`), ylikiristystä (`> 100 N` → katkeaminen `TANGLED` → kelaus `0 m`) ja löysää jarrua (`< 10 N`); varmista `FPS >= 60`, `Draw Calls < 100`, `Tris < 20 000`.

## 6. Tiedostot

| Polku | Toimenpide | Vastuu |
| :--- | :--- | :--- |
| `src/core/state/rod_state.gd` | `[MODIFY]` | 6 siimakenttää, `get_effective_max_strength`, `reset_line_condition`, `copy_from`, serialisointi |
| `src/core/state/player_input.gd` | `[MODIFY]` | `drag_input`-kenttä ja serialisointi |
| `src/core/simulation/line_physics.gd` | `[NEW]` | Puhdas voima-, jarru-, puola-, hankauma- ja katkeamislaskenta (`LinePhysics`) |
| `src/core/simulation/rod_simulator.gd` | `[MODIFY]` | `Z`/`X`-säätö, `LinePhysics` kalattomille, `STOWED`-palautus ja `35 m` laskuraja |
| `src/core/simulation/fish_simulator.gd` | `[MODIFY]` | `LinePhysics` kalallisille, yhdistetty `drag_rate`, kytkinkelaus ja löysä `hook slip` |
| `src/network/network_manager.gd` | `[MODIFY]` | `drag_input` asiakkaalta palvelimelle |
| `src/network/snapshot_interpolator.gd` | `[MODIFY]` | `RodState`-kenttien interpolointi ja `copy_from` |
| `src/main.gd` | `[MODIFY]` | `Z`/`X` -> `PlayerInput.drag_input` |
| `src/view/world_view.gd` | `[MODIFY]` | `line_prompt`-jännitys/jarru/puola/`[Z/X]`/`[RÄIKKÄ!]`/`[LÖYSÄ!]` ja räikkä-ääni |
| `tests/test_11a_line_physics_and_drag.gd` | `[NEW]` | 5 hyväksymistestiä |
