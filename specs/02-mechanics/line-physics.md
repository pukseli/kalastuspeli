# Mekaniikkaspeksi: Siiman Fysiikka, Kelan Jarru ja Katkeamismekaniikka

> **Suuntaa antava mekaniikkaspeksi (Specs as Code).** Atomiset viipalespeksit (`specs/slices/NN-*.md`) poimivat tarvitsemansa säännöt vaiheittain ja ovat ristiriitatilanteessa sitovia. Viittaa tiedostoihin [`00-architecture.md`](../00-architecture.md), [`01-state-schema.md`](../01-state-schema.md) ja [`planer-boards.md`](planer-boards.md).

---

## 1. Yleiskuva ja periaatteet

Uistelussa siima on **tarkoituksella jatkuvasti kireällä** veneen liikkeen, veden vastuksen ja plaanarin tai vieheen uinnin ansiosta. Kireä siima on normaali toimintatila ja edellytys sille, että viehe ui oikein ja koukku tarttuu kalaan. **Siima ei katkea pelkästä kireydestä.**

Siiman ja kelan mekaniikka pohjautuu kolmeen peruspilariin:
1. **Jännitys vs. Vetolujuus (`line_tension` vs. `effective_max_strength`):** Siima kestää jatkuvaa vetoa aina murtolujuuteensa saakka.
2. **Kelan jarru (`drag_setting` ja `is_drag_slipping`):** Kelan säädettävä jarru on siiman tärkein suoja katkeamista vastaan. Kun jännitys ylittää jarrun asetusarvon, puola antaa siimaa ulos ja estää jännitystä kasvamasta yli siiman kestävyyden.
3. **Löysän siiman riski (Slack line):** Jos jännitys putoaa lähelle nollaa kalan ollessa kiinni, koukku pääsee löystymään ja kala voi ravistaa itsensä irti (hook slip / shake-off).

---

## 2. Tilamalli ja parametrit (`RodState` & `PlayerInput`)

Siiman tila tallennetaan keskitetysti vavan tilaan (`RodState`):

| Kenttä | Tyyppi | Oletus | Yksikkö | Kuvaus |
| :--- | :--- | :--- | :--- | :--- |
| `line_tension` | `float` | `0.0` | N | Siimaan tällä hetkellä kohdistuva todellinen vetojännitys |
| `line_max_strength` | `float` | `100.0` | N | Siiman nimellinen maksimivetolujuus ehjänä |
| `drag_setting` | `float` | `60.0` | N | Kelan jarrun säätöarvo (`0.0 .. 125.0 N`; `> 100.0 N` = punainen ylikiristysalue) |
| `line_remaining_on_spool` | `float` | `150.0` | m | Puolalla jäljellä oleva varasiima (kapasiteetti `150.0 m`, erotettu manuaalisesta `max_deploy_line_out = 35.0 m` -laskurajasta; päivittyy `± delta_line` ja nollautuu täydeksi `STOWED`-tilassa) |
| `line_integrity` | `float` | `1.0` | `0.0 .. 1.0` | Siiman kunto (`1.0` = uusi/ehjä; hankaumaraja `0.15` sotkupätkällä, palautuu `1.0`:een `STOWED`-tilassa) |
| `is_drag_slipping` | `bool` | `false` | — | Luistaako kelan jarru parhaillaan (`line_remaining_on_spool > 0.0` ja $F_{\text{load}} > \text{drag\_setting}$) |

- **Ohjaussyöte (`PlayerInput.drag_input: float`):** Säätöväli `-1.0 .. 1.0` (`Z` löysää jarrua / `X` kiristää jarrua). Toimii vapa kädessä sekä tyhjäkäsin lähimmän vapatelineen äärellä.

### Johdettu todellinen vetolujuus:
$$\text{effective\_max\_strength} = \text{line\_max\_strength} \times \text{line\_integrity}$$

---

## 3. Voimat ja jännityksen muodostuminen ($F_{\text{load}}$ vs. `line_tension`)

Simulaatio erottaa **ulkoisen vetokuorman ($F_{\text{load}}$)** ja **siimaan syntyvän todellisen jännityksen (`line_tension`)**:

$$F_{\text{load}} = F_{\text{water}} + F_{\text{fish/snag}} + F_{\text{reel}}$$

1. **Veden vastus ($F_{\text{water}}$):**
   - Kasvaa veneen nopeuden ($v_{\text{boat}}$), ulkona olevan siiman pituuden (`line_out`) ja vieheen/plaanarin poikkipinta-alan mukaan.
   - Pysähtyneellä veneellä $F_{\text{water}} \approx 0$.
2. **Kalan veto ($F_{\text{fish}}$) tai pohjatakertuma ($F_{\text{snag}}$):**
   - Kalalla on laji- ja kokokohtainen perusveto (`base_pull`) ja syöksyveto (`surge_pull`), skaalattuna Newtoneiksi.
   - `SNAGGED`-tilassa veneen liike esteeseen nähden kasvattaa vetoa voimakkaasti (`snag_tension_rate`).
3. **Pelaajan kelaus ($F_{\text{reel}}$):**
   - Sisäänkelaus (`line_input < -0.1`) kohdistaa lisävetoa, jos vastapuoli (kala, plaanari tai pohja) panee vastaan.

### Jarrurajoitus:
- **Jos puolalla on siimaa (`line_remaining_on_spool > 0.0`) ja $F_{\text{load}} > \text{drag\_setting}$:**
  `is_drag_slipping = true` ja $\text{line\_tension} = \text{drag\_setting}$.
- **Muuten (`line_remaining_on_spool <= 0.0` tai $F_{\text{load}} \le \text{drag\_setting}$):**
  `is_drag_slipping = false` ja $\text{line\_tension} = F_{\text{load}}$.

### Normaali kireys vs. Löysä siima (Slack / Hook slip)
- **Normaali tila:** $\text{line\_tension} \in [10.0\text{ N},\; \text{drag\_setting}]$. Siima on täysin suorana ja tiukkana, eikä kulu tai katkea.
- **Löysä siima ($\text{line\_tension} < 10.0\text{ N}$):**
  - Kun kyseessä on **aktiivisesti taisteleva kala** (`state == HOOKED`, `stamina > 0.05`, `hooked_time >= grace_period_sec`, eikä plaanarin irrotus ole käynnissä), löysä siima lisää `FishSimulator`-ravistusrullaan kiinteän karkauslisän **`+0.40 /s`** (voimassa myös syöksyjen ulkopuolella).
  - Väsyneet kalat (`stamina <= 0.05`), pikkukalat ja `READY_TO_LAND`-vaihe eivät karkaa löysästä siimasta.

---

## 4. Kelan jarru (Drag / Clutch) ja kelaus

Kelan jarru on mekaaninen luistokytkin, joka estää siimaa katkeamasta:

1. **Kun `is_drag_slipping == true` ($F_{\text{load}} > \text{drag\_setting}$ ja `line_remaining_on_spool > 0.0`):**
   - Siimaa purkautuu ulos nopeudella:
     $$v_{\text{slip}} = \text{clampf}\!\left(k_{\text{slip}} \times (F_{\text{load}} - \text{drag\_setting}),\; 0.0,\; \text{max\_drag\_slip\_speed}\right)$$
   - `FishState.drag_rate` johdetaan suoraan tästä yhdestä arvosta (`v_slip`, ei rinnakkaista jarrumatematiikkaa).
   - `line_out` kasvaa ja `line_remaining_on_spool` vähenee samassa suhteessa (`± delta_line`).
   - Kelan räikkä huutaa (ääniefekti ja HUD-ilmaisin).
   - Jarrun luistaessa **`line_tension` pysyy rajattuna `drag_setting`-arvoon**, joten oikein säädetyllä jarrulla (`drag_setting < effective_max_strength`) **siima EI katkea**.

2. **Realistinen kytkin kelatessa (`Space`):**
   - Jos $F_{\text{water}} + F_{\text{fish}} > \text{drag\_setting}$ (`is_drag_slipping == true`), kala vie siimaa ulos eikä `Space` tuo siimaa sisään.
   - Kun $F_{\text{water}} + F_{\text{fish}} \le \text{drag\_setting}$, sisäänkelausnopeus skaalautuu jäljellä olevan jarruvaran mukaan lajin `reel_speed`-maksimiin saakka.

3. **Jarrun säätö (`drag_setting`):**
   - Oletusarvo on turvallinen `60.0 N` (60 % 100 N siimasta).
   - Pelaaja säätää jarrua näppäimillä **`Z` (löysää)** ja **`X` (kiristä)** välillä `0.0 .. 125.0 N` (toimii vapa kädessä tai tyhjäkäsin lähimmän vapatelineen äärellä).

---

## 5. Siiman katkeamisehdot (Snap Conditions) ja palautuminen

Siima katkeaa **vain** silloin, kun todellinen vetojännitys saavuttaa tai ylittää todellisen vetolujuuden ($\text{line\_tension} \ge \text{effective\_max\_strength}$):

1. **Jarru liian tiukalla (`S11a`):**
   - Pelaaja on asettanut `drag_setting >= effective_max_strength` (esim. ylikiristysalue `> 100.0 N`).
   - Kalan rynnistys tai veneen vauhti nostaa `line_tension`-arvon yli vetolujuuden ilman, että jarru luistaa.
2. **Puola tyhjenee (`S11a`):**
   - Kala tai este on vetänyt siimaa niin pitkään, että `line_remaining_on_spool <= 0.0`.
   - Puolan jarru lukittuu (`is_drag_slipping = false`), jolloin $\text{line\_tension} = F_{\text{load}} \ge \text{effective\_max\_strength}$ katkaisee siiman välittömästi.
3. **Hankauma ja kuluminen (`S11a`):**
   - `TANGLED`- tai `SNAGGED`-tilassa `line_integrity` laskee tasaisesti (alaraja `0.15` solmupätkällä, jottei katkennut tynkä katkea uudelleen silmukassa).
   - Kulunut siima voi katketa jo tavanomaisella jarrulla (`drag_setting >= line_max_strength * line_integrity`).
4. **Äkillinen shokkikuorma (siirretty viipaleeseen `S16`):**
   - Kovavauhtisen karikkotörmäyksen (`SNAGGED`) ja äärimmäisen nykäisyn shokkikuormapiikki lisätään esteviipaleessa `S16` (`16-lake-obstacles`).

### Seuraus siiman katkeamisesta ja palautuminen:
- Kala karkaa välittömästi (`state.fishes.erase`).
- Plaanari irtoaa visuaalisesti (`planer.attached = false`) ja vapa siirtyy tilaan `TANGLED` lyhyellä **`6.0 m`** sotkupätkällä (`planer.line_out = 6.0`).
- HUD näyttää katkeamisen syyn (esim. *"Siima katkesi: Jarru oli liian kireällä!"*, *"Puola tyhjeni!"* tai *"Kulunut siima katkesi!"*).
- Pelaaja kelaa sotkun ylös (`Space` → `0.0 m → STOWED`), minkä yhteydessä `line_integrity` palautuu `1.0`:een, `line_remaining_on_spool` täyttyy `150.0 m`:iin ja telineen oletusplaanari palautuu.

---

## 6. Visuaalinen ja esityskerros (`src/view/`, jaettu `S11a` + `S11b`)

- **`S11a` (minimipalaute):** Tekstipohjainen jännitys-, jarru- ja puolanäyttö `line_prompt`-kehotteessa (`[Z/X]` jarru N, kireys %, jäljellä oleva siima m, `[RÄIKKÄ!]`) sekä nykyinen räikkä-ääni kytkettynä jarruluistoon.
- **`S11b` (`11b-line-visuals-and-rod-bend`):**
  1. **Siimakäyrä (3–5 pisteen käyrä):** Löysä siima pussittaa veden pintaan/taaksepäin, kireä siima suoristuu, > 80 % kestävyydestä siima tärisee ja korostuu vertex-väreillä (`0` uutta draw callia).
  2. **Vavan taipuma:** `BoatView` ja `PlayerView` taivuttavat vapaa jännityksen suhteessa.
  3. **Visuaalinen mittari:** Graafinen kireys- ja jarrupalkki HUDissa.

---

## 7. Headless-hyväksymiskriteerit (`tests/`)

Pure simulation -testit (`src/core/`), jotka ajetaan `--headless`:
1. **Normaali kireys ei katkaise:** Vapa uistelee kireällä siimalla (`line_tension < effective_max_strength`) pitkään ilman katkeamista.
2. **Jarru suojaa siiman:** `drag_setting = 60 N`, kalan veto `90 N` → siima ei katkea, `is_drag_slipping == true`, `line_out` kasvaa ja `line_remaining_on_spool` pienenee, `FishState.drag_rate` täsmää.
3. **Puolan tyhjeneminen katkaisee:** Jarru luistaa, kunnes `line_remaining_on_spool <= 0.0` ja veto ylittää vetolujuuden → siima katkeaa (`TANGLED`, `6.0 m`), ja `0 m → STOWED` palauttaa ehjän siiman (`1.0` / `150.0 m`).
4. **Liian kireä jarru katkaisee:** `drag_setting = 120 N` (> `100 N`) kalan rynnistäessä → siima katkeaa tilaan `TANGLED`.
5. **Hankauma heikentää siimaa:** `TANGLED`- tai `SNAGGED`-tilassa `line_integrity` laskee, jolloin pienempikin kuorma katkaisee kuluneen siiman.

---

## 8. Viipalointi ja simulaatioarkkitehtuuri (`src/core/simulation/`)

- Siiman jännitys-, jarru-, puola-, hankauma- ja katkeamiskaavat keskitetään yhteen puhtaaseen `RefCounted`-apuluokkaan **`src/core/simulation/line_physics.gd` (`LinePhysics`)**.
- **Yksi suorituspolku per vapa per tick:** `RodSimulator.step()` kutsuu `LinePhysics`:iä vain kalattomille vavoille, ja `FishSimulator.step()` kutsuu sitä kalallisille vavoille.

| Viipale | Vastuu |
| :--- | :--- |
| **`S11a` (`11a-line-physics-and-drag`)** | `LinePhysics`, `RodState`-kentät, `PlayerInput.drag_input` (`Z`/`X`), 3 katkeamisehtoa → `TANGLED` (`6 m`), löysän siiman `hook slip`, `SnapshotInterpolator` ja teksti-HUD |
| **`S11b` (`11b-line-visuals-and-rod-bend`)** | 3D-siimakäyrä vertex-väreillä ja värinällä, vavan taipuma ja visuaalinen mittari (`src/view/`) |
| **`S11c` (`11c-fish-fatigue`)** | Kalan syvempi väsytysmalli (`stamina`-silmukka) |
| **`S16` (`16-lake-obstacles`)** | `WorldFeatures`-esteet (`SNAGGED`) ja kovavauhtinen shokkikuormakatkeaminen |
