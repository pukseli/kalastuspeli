# Mekaniikkaspeksi: Plaanarit (Planer Boards)

> **Suuntaa antava mekaniikkaspeksi (Specs as Code).** Atomiset viipalespeksit (`specs/slices/NN-*.md`) poimivat tarvitsemansa säännöt vaiheittain ja ovat ristiriitatilanteessa sitovia. Koordinaatisto ja aika-askel (`FIXED_DELTA = 1.0 / 60.0`) noudattavat tiedostoa [`boat-physics.md`](boat-physics.md): kun `heading == 0`, keula osoittaa suuntaan `-Z`, oikea kylki suuntaan `+X`, perä suuntaan `+Z` ja positiivinen `angular_velocity` ($\omega > 0$) kääntää venettä vasemmalle.

---

## 1. Yleiskuva ja tavoite

Pelissä käytetään **pikkuplaanaria** eli siimaan vavan ja vieheen väliin kiinnitettävää kelluvaa levittäjää. Veneen liikkuessa eteenpäin veden virtaus työntää plaanaria viistosti ulos veneen sivulle.

| Tavoite | Pelimekaaninen vaikutus |
| :--- | :--- |
| **Laajempi pyyntileveys** | Vieheet levittäytyvät pois veneen rungon ja potkurivirran melusta; 2–3 vapaa per puoli vetää rinnakkain ilman välitöntä sotkua. |
| **Riski vs. palkinto** | Mitä enemmän siimaa on ulkona, sitä leveämpi veneen "siipiväli" on: parvet osuvat laajemmalla kaistalla, mutta käännökset, karikot ja tärpit aiheuttavat jatkuvaa tiimikaaosta. |
| **Suhde 6 vavan asetelmaan** | Plaanari on vapaakohtainen (`attached: bool`) kuuden telineen asetelmassa (`-3..-1 \| +1..+3`, `ItemConfig.side`: `-1` = `LEFT`, `+1` = `RIGHT`). Kylkivavat (`-3/-2`, `+2/+3`) ja tarvittaessa perävavat (`-1/+1`) voivat uistella plaanarilla tai suorana siimana. |

---

## 2. Tilamalli, tilakone ja konfiguraatio

`PlanerBoard` kuuluu osaksi vavan tilaa (`RodState.planer`, ks. [`specs/01-state-schema.md`](../01-state-schema.md)). Yhden totuuden lähteen sääntöä noudattaen vavasta ulkona olevan siiman pituus asuu yhdessä kentässä (`line_out`), eikä rinnakkaista `line_length`-kenttää ylläpidetä.

### 2.1 `PlanerBoard`-kentät

| Kenttä | Tyyppi | Oletus | Kuvaus |
| :--- | :--- | :--- | :--- |
| `side` | `int` | `1` | Puoli: `LEFT = -1`, `RIGHT = +1` (määräytyy vavan/telineen puolesta) |
| `attached` | `bool` | `true` | Onko pikkuplaanari kiinnitetty siimaan (irrotetaan ennen haavitusta) |
| `lateral_offset` | `float` | `0.0` | Sivuetäisyys veneen keskilinjasta metreinä (`< 0` vasen, `> 0` oikea) |
| `line_out` | `float` | `0.0` | Vavasta plaanarille (tai suorana vieheelle) laskettu siimapituus (m) |
| `state` | `String` | `"STOWED"` | Nykyinen tila: `STOWED`, `DEPLOYING`, `TROLLING`, `TRIPPED`, `TANGLED`, `SNAGGED` |
| `snag_world_position` | `Vector2` | `Vector2.ZERO` | Maailmankoordinaatiston lukituspiste `SNAGGED`-tilassa (`S16`) |

### 2.2 Tilakone

| Tila | Sisääntuloehto | Käyttäytyminen simulaatiossa | Palautuminen / Seuraava tila |
| :--- | :--- | :--- | :--- |
| `STOWED` | `not attached` tai `line_out <= 0.0` | `lateral_offset = 0.0`, ei levityssuuntaista vetoa | Siima lasketaan veteen ja `attached == true` → `DEPLOYING` |
| `DEPLOYING` | `attached` ja `0.0 < line_out` (siimaa lasketaan tai levittäytyy kohti tavoitetta) | Plaanari liukuu kohti kohde-etäisyyttä $x_{\text{target}}$ | Saavuttaa vakaan uisteluaseman (`abs(lateral_offset - x_target) < 0.25` m ja `v_board >= min_pull_speed`) → `TROLLING`; sisäänkelaus `0 m` → `STOWED` |
| `TROLLING` | Vakaa uisteluasema saavutettu | Pitää sivuetäisyyden vauhdista riippuvana; antaa tärppibonuksen | Vauhdin hiipuminen / kääntösotku → `TANGLED`; tärppi → `TRIPPED`; este → `SNAGGED`; sisäänkelaus `0 m` → `STOWED` |
| `TRIPPED` | Kala iskee plaanarin takana olevaan vieheeseen (`S9`) | Vetoteho putoaa murto-osaan (`tripped_pull_factor = 0.15`), plaanari nykäisee taaksepäin/sisään ja lippu reagoi | Kelataan laidalle (`line_out <= detach_distance`) → pelaaja irrottaa plaanarin (`E`) → `attached = false`, `state = STOWED` |
| `TANGLED` | Plaanarien tai veneen kyljen välinen kynnys rikkoutuu (`S12`) | Plaanari ei levittäydy; siima lukittuu sotkuun eikä vedä kaloja | Selvitys kannella → `STOWED` (tai uudelleenlaskuun `DEPLOYING`) |
| `SNAGGED` | Plaanari tai viehe osuu esteeseen / karikkoon (`S16`) | Lukittuu `snag_world_position`-pisteeseen; siiman kireys nousee nopeasti veneen liikkuessa eteenpäin | Veneen pysäytys/peruutus ja irrotus → `DEPLOYING` / `STOWED`, tai siiman katkeaminen (`S11`) |

### 2.3 Konfiguraatioparametrit (`PlanerBoardConfig`, puhdas `RefCounted`)

| Parametri | Oletusarvo | Yksikkö | Kuvaus |
| :--- | :--- | :--- | :--- |
| `max_line_out` | `35.0` | m | Maksimipituus vavasta plaanariin |
| `leader_length` | `6.0` | m | Tapsin / perukkeen pituus plaanarista vieheeseen |
| `max_lateral_offset` | `22.0` | m | Plaanarin suurin sivuetäisyys veneen keskilinjasta |
| `max_spread_angle_deg` | `55.0` | ° | Maksimilevityskulma suhteessa perälinjaan (`line_out * sin(angle)`) |
| `min_pull_speed` | `0.8` | m/s | Pienin paikallinen virtausnopeus, jolla plaanari vetää sivulle |
| `optimal_pull_speed` | `3.0` | m/s | Virtausnopeus, jolla saavutetaan täysi vetoteho (`p = 1.0`) |
| `spread_rate` | `3.0` | m/s | Maksiminopeus, jolla plaanari levittäytyy ulospäin |
| `collapse_rate` | `1.6` | m/s | Perusvalumisnopeus kohti venettä vauhdin loppuessa |
| `stall_collapse_gain` | `1.2` | 1 | Lisäkerroin valumisnopeudelle sakkauksen voimakkuuden mukaan |
| `tripped_pull_factor` | `0.15` | 1 | Vetotehon kerroin tärppitilassa (`TRIPPED`) |
| `board_tangle_distance` | `1.5` | m | Kahden aktiivisen plaanarin välinen minimi-2D-etäisyys ennen sotkua |
| `hull_tangle_margin` | `1.2` | m | Veneen kyljen sotkumarginaali sakkauksen aikana |
| `sharp_turn_omega` | `0.35` | rad/s | Jyrkän käännöksen kulmanopeuskynnys kylkikosketussotkulle |
| `board_collision_radius` | `0.45` | m | Plaanarin törmäyssäde esteisiin |
| `lure_collision_radius` | `0.25` | m | Vieheen törmäyssäde esteisiin |
| `detach_distance` | `2.0` | m | Etäisyys vavan kärjestä, jolla plaanarin voi irrottaa siimasta |
| `detach_duration` | `0.5` | s | Lyhyt interaktio kelaajan tai tiimikaverin toimesta plaanarin irrotukseen |
| `quiet_water_offset` | `4.0` | m | Sivuetäisyys, jolla viehe on pois potkurimelusta |
| `quiet_water_bite_bonus` | `1.2` | 1 | Tärppitodennäköisyyden kerroin (`+20 %`) hiljaisessa vedessä |
| `snag_tension_rate` | `0.45` | /s | Kireyden kasvunopeus (`S11`) veneen vetäessä karikkoa vastaan |

---

## 3. Kevyt 2D-simulaatiomalli (`src/core/`, X/Z-taso)

Kaikki laskenta tehdään kevyesti 2D-tasossa `(x, z)` kiinteällä askelvälillä `dt = FIXED_DELTA`.

### 3.1 Koordinaatisto ja johdettu maailmasijainti (`world_position`)

Veneen suunnasta $h = \text{boat.heading}$ saadaan yksikkövektorit:

$$\vec{u}_{\text{fwd}} = \begin{pmatrix} -\sin h \\ -\cos h \end{pmatrix}, \quad \vec{u}_{\text{right}} = \begin{pmatrix} \cos h \\ -\sin h \end{pmatrix}, \quad \vec{u}_{\text{stern}} = -\vec{u}_{\text{fwd}} = \begin{pmatrix} \sin h \\ \cos h \end{pmatrix}$$

Vavan kärjen vene-paikallinen sijainti on $(x_{\text{tip}}, z_{\text{tip}})$. Kun plaanari ei ole `SNAGGED`-tilassa, sen jättämä peräetäisyys ja maailmasijainti johdetaan suoraan veneen ja plaanarin tilasta:

$$\Delta x = \text{lateral\_offset} - x_{\text{tip}}, \qquad \text{trail\_z} = \sqrt{\max\!\left(0.0,\; \text{line\_out}^2 - \Delta x^2\right)}$$

$$\vec{p}_{\text{board}} = \vec{p}_{\text{boat},xz} + \text{lateral\_offset}\,\vec{u}_{\text{right}} + (z_{\text{tip}} + \text{trail\_z})\,\vec{u}_{\text{stern}}$$

- **`SNAGGED`-tilassa:** $\vec{p}_{\text{board}} = \text{snag\_world\_position}$ (plaanari jää ankkuroituna esteeseen).
- **Vieheen sijainti:** $\vec{p}_{\text{lure}} = \vec{p}_{\text{board}} + (\text{leader\_length} \cdot \text{trail\_factor})\,\vec{u}_{\text{stern}}$ (paikallaan vaakaprojektio lyhenee `trail_factor`-kertoimella vieheen vajotessa).

### 3.2 A. Liikkuminen ja vauhtiriippuvuus

Veneen kääntyessä kulmanopeudella $\omega = \text{boat.angular\_velocity}$ plaanarin paikallinen virtausnopeus riippuu sekä veneen etenemisnopeudesta $v_{\text{fwd}}$ että etäisyydestä keskilinjaan:

$$v_{\text{board}} = v_{\text{fwd}} + \omega \cdot \text{lateral\_offset}$$

- **Merkkisäännön tarkistus (`boat-physics.md`):**
  - Vasen käännös ($\omega > 0$): vasen laita (`lateral_offset < 0`) saa $v_{\text{board}} < v_{\text{fwd}}$ (sisäkaarre hidastuu), oikea laita (`lateral_offset > 0`) saa $v_{\text{board}} > v_{\text{fwd}}$ (ulkokaarre kiihtyy).
  - Oikea käännös ($\omega < 0$): oikea laita (`lateral_offset > 0`) on sisäkaarre ($v_{\text{board}} < v_{\text{fwd}}$) ja vasen laita (`lateral_offset < 0`) ulkokaarre ($v_{\text{board}} > v_{\text{fwd}}$).

Vetoteho ja tavoiteltu sivuetäisyys lasketaan seuraavasti:

$$p_{\text{base}} = \operatorname{clamp}\!\left(\frac{v_{\text{board}} - v_{\text{min\_pull}}}{v_{\text{optimal}} - v_{\text{min\_pull}}},\; 0.0,\; 1.0\right)$$

$$p = \begin{cases} p_{\text{base}} \cdot \text{tripped\_pull\_factor}, & \text{kun state} = \text{TRIPPED} \\ p_{\text{base}}, & \text{muulloin} \end{cases}$$

$$L_{\text{max}} = \min\!\left(\text{max\_lateral\_offset},\; \text{line\_out} \cdot \sin(\theta_{\text{max}})\right), \qquad x_{\text{target}} = \text{side} \cdot p \cdot L_{\text{max}}$$

1. **Veto riittää ($v_{\text{board}} \ge v_{\text{min\_pull}}$):** Plaanari liikkuu kohti tavoitetta nopeudella `spread_rate * max(p, 0.25) * dt` (`move_toward(lateral_offset, x_target, ...)`). Kun `line_out` kasvaa tai vauhti nousee, `lateral_offset` kasvaa tasaisesti kohti laitimmaista rajaa.
2. **Pysähtyminen tai hidas vauhti ($v_{\text{board}} < v_{\text{min\_pull}}$):** Plaanari menettää vetonsa ja valuu kohti venettä (`0.0`) nopeudella `collapse_v = collapse_rate + (v_min_pull - v_board) * stall_collapse_gain`.
3. **Siima kelattu ylös (`line_out <= 0.0`):** `lateral_offset = 0.0` ja `state = STOWED`.

### 3.3 B. Kääntyminen ja kaaos (Sisäkaarre vs. Ulkokaarre)

- **Ulkokaarre:** Koska $\omega \cdot \text{lateral\_offset} > 0$, ulkokaarteen plaanarit saavat suuremman virtausnopeuden ($v_{\text{board}} > v_{\text{fwd}}$) ja pysyvät tiukasti levitettyinä.
- **Sisäkaarre:** Ulompana oleva sisäkaarteen plaanari menettää suhteellisesti eniten nopeutta (suurin $|\text{lateral\_offset}|$), joten se sakkaa ensimmäisenä ja valuu nopeammin taaksepäin/sisään kuin sisempi plaanari.
- **`TANGLED`-laukaisimet (`DEPLOYING` / `TROLLING` / `TRIPPED`):**
  1. **Plaanarien törmäys toisiinsa:** Kahden aktiivisen plaanarin välinen 2D-etäisyys maailmassa alittaa kynnysarvon: $\lVert \vec{p}_{\text{board},a} - \vec{p}_{\text{board},b} \rVert \le \text{board\_tangle\_distance}$ (`1.5 m`). Molemmat siirtyvät tilaan `TANGLED`.
  2. **Sakkaus veneen kylkeen:** Ulkona oleva plaanari (`line_out > detach_distance`) valuu jyrkässä käännöksessä ($|\omega| \ge \text{sharp\_turn\_omega}$ ja $v_{\text{board}} < v_{\text{min\_pull}}$) veneen kyljen alle (`abs(lateral_offset) < hull_tangle_margin`) → siirtyy tilaan `TANGLED`.
- **Tiimidynamiikka:** Kuskin on tehtävä loivia kaarroksia ja varoitettava miehistöä käännöksistä, jotta sisäkaarteen siimoja voidaan tarvittaessa lyhentää ajoissa.

### 3.4 C. Esteet ja karikot (`SNAGGED`)

Esteet esitetään kevyellä 2D-ympyrärajapinnalla `{position: Vector2, radius: float}` (yhteensopiva `S16 WorldFeatures`:n saarien ja karikoiden kanssa).

- Jokaisella tikillä testataan aktiivisten plaanarien ja niiden vieheiden osuma esteisiin:
  $$\lVert \vec{p}_{\text{board}} - \vec{p}_{\text{obs}} \rVert \le r_{\text{obs}} + r_{\text{board}} \quad \text{tai} \quad \lVert \vec{p}_{\text{lure}} - \vec{p}_{\text{obs}} \rVert \le r_{\text{obs}} + r_{\text{lure}}$$
- Osuma vaihtaa tilaksi `SNAGGED` ja tallentaa osumakohdan kenttään `snag_world_position`.
- Veneen jatkaessa eteenpäin etäisyys vavan kärjestä `snag_world_position`-pisteeseen ylittää `line_out`-arvon, mikä kasvattaa siiman kireyttä (`snag_tension_rate`) ja katkaisee siiman (`S11`), ellei kippari pysäytä tai peruuta vapauttaakseen plaanarin.

### 3.5 D. Tärppi (`TRIPPED`), kelaus ja irrotus (Tiimityö)

1. **Tärppisignaali (`S9`):** Kalan iskiessä plaanarin takana olevaan vieheeseen plaanarin tila vaihtuu `TROLLING -> TRIPPED`. Vetoteho putoaa kertoimeen `tripped_pull_factor = 0.15`, plaanari nykäisee taakse/sisään kohti veneen vanavettä ja huomiolippu kaatuu/vaihtaa väriä.
2. **Kelaus laidalle:** Pelaaja kelaa siimaa sisään (`Space`). Kun `line_out <= detach_distance` (`2.0 m`), plaanari on veneen vieressä.
3. **Irrotuslukko ja tiimityö (`S10`):** Jos `attached == true`, kalaa ei voi vielä haavita. Vavan lähellä (joko kelaaja laskettuaan tai vieressä seisova tiimikaveri vapailla käsillä) tehdään lyhyt `E`-interaktio (`detach_duration = 0.5 s`), joka asettaa `attached = false`, `state = STOWED` ja jättää `line_out = leader_length`-mitan (peruke), jonka jälkeen kala kelataan loppuun ja haavitaan.

### 3.6 E. Vaikutus kalastustehokkuuteen

| Tekijä | Sääntö | Vaikutus |
| :--- | :--- | :--- |
| **Parven kattavuus** | Kalaparven/hotspotin (`xx-fish-hotspots` / `S9`) osumatarkistus tehdään vieheen maailmasijainnista $\vec{p}_{\text{lure}}$ veneen keskipisteen sijaan. | Plaanareilla 3 vavan viuhka haravoi jopa ~40 m leveää kaistaa. |
| **Hiljaisen veden bonus** | Jos `attached == true`, `state == TROLLING` ja `abs(lateral_offset) >= quiet_water_offset` (`4.0 m`), tärppitodennäköisyys kerrotaan arvolla `quiet_water_bite_bonus` (`1.2`, eli `+20 %`). | Palkitsee pelaajia leveän ja siistin uisteluviuhkan pitämisestä poissa potkurimelusta. |

---

## 4. Visuaalinen toteutus (`src/view/` – Greybox)

Toteutus pidetään puhtaana koodipohjaisena low-poly-grafiikkana perunakonebudjetin sisällä (`Draw Calls < 100`, `Tris < 20 000`, `FPS >= 60`):

| Elementti | Primitiivi & materiaali | Tilavisualisointi |
| :--- | :--- | :--- |
| **Plaanari** | Kirkkaan oranssi tai keltainen `BoxMesh`-kiila/laatikko veden pinnalla (`y = -0.25`) plaanarin maailmasijainnissa $\vec{p}_{\text{board}}$, suunnattuna veneen `heading`-kulman mukaisesti. | `TROLLING`/`DEPLOYING`: vakaa oranssi/keltainen; `TANGLED`: violetti/vilkkuva; `SNAGGED`: paikallaan karikossa punaisena; `STOWED`: piilotettu. |
| **Huomiolippu** | Ohut pystysylinteri/laatikko plaanarin päällä (`CylinderMesh` / `BoxMesh`). | Normaali uistelu: pystyssä (`0°`, keltainen/vihreä). `TRIPPED` (tärppi): kallistuu taakse (`-65°`) ja vaihtaa värin kirkkaanpunaiseksi. |
| **Siima** | Yksi yhteinen `ImmediateMesh` (`PRIMITIVE_LINES`, `1` draw call kaikille vavoille). | Piirtää kaksi segmenttiä per aktiivinen plaanarivapa: (1) vavan kärki → plaanari $\vec{p}_{\text{board}}$, (2) plaanari $\vec{p}_{\text{board}}$ → viehe $\vec{p}_{\text{lure}}$ veden pinnassa. |

---

## 5. Deterministiset testaus- ja hyväksymiskriteerit (`tests/`)

`src/core/`-simulaation tulee läpäistä seuraavat deterministiset Given–When–Then-yksikkötestit:

| Testiskenaario | Given | When | Then |
| :--- | :--- | :--- | :--- |
| **1. Eteenpäin ajo levittää plaanarit** | Vene paikallaan, kaksi plaanarivapaa (`LEFT`, `RIGHT`) laskettuna (`line_out = 20.0`, `attached = true`) | Vene liikkuu eteenpäin (`v_fwd = 3.0 m/s`) riittävän monta tickiä (`FIXED_DELTA`) | `RIGHT`-plaanarin `lateral_offset > 0.0`, `LEFT`-plaanarin `lateral_offset < 0.0`, ja molemmat lähestyvät tavoitelevitystä (`state == "TROLLING"`). |
| **2. Pysähdys vetää plaanarit sisään** | Plaanarit levitettyinä sivulle (`abs(lateral_offset) > 5.0`, `v_fwd = 3.0 m/s`) | Vene pysäytetään (`v_fwd = 0.0`) ja simulaatiota ajetaan | Plaanarien `abs(lateral_offset)` pienenee yksiselitteisesti jokaisen askeljakson aikana kohti `0.0`:aa. |
| **3. Jyrkkä käännös aiheuttaa `TANGLED`-tilan** | Kaksi saman puolen plaanaria levitettynä vierekkäin (esim. vasemman laidan `-2` ja `-3` eri `line_out`-mitoilla) | Vene tekee jyrkän sisäkaarteen ($\omega > 0.5\text{ rad/s}$) | Sisäkaarteen plaanarit menettävät virtausnopeutta, lähestyvät toisiaan (tai kylkeä) alle kynnysarvon ja vaihtavat tilaksi `"TANGLED"`. |
| **4. Esteeseen osuminen aiheuttaa `SNAGGED`-tilan** | Aktiivinen plaanari vedessä ja 2D-ympyräeste veneen/plaanarin reitillä | Vene kuljettaa plaanarin tai sen vieheen esteen säteen sisään | Plaanarin `state` vaihtuu tilaksi `"SNAGGED"` ja `snag_world_position` lukittuu osumapisteeseen. |

---

## 6. Suhde atomisiin viipaleisiin (`specs/02-roadmap.md`)

Koska projektin arkkitehtuuri ([`specs/00-architecture.md`](../00-architecture.md) §5) rajaa jokaisen viipaleen **yhteen uuteen käsitteeseen**, `≤ 60` ei-tyhjään riviin ja `≤ 5` testiin, plaanarimekaniikka kannattaa aktivoida vaiheittain viipaleiden mukana:

| Viipale | Mitä otetaan käyttöön tästä speksistä |
| :--- | :--- |
| **S8 (`08-trolling-lines`)** | `RodState` + `PlanerBoard`-perusrakenne (`line_out`, `side`, `attached`, `lateral_offset`, `STOWED`/`DEPLOYING`/`TROLLING`), 2D-levitys vauhdista, valuminen pysähdyksissä, harmaalaatikkoinen plaanari + `ImmediateMesh`-siima ja viehe perässä. *(Tai vaihtoehtoisesti S8a/S8b-jako, jos halutaan erottaa suora siima ja plaanari.)* |
| **S9 (`09-bite-and-reel`)** | `TRIPPED`-tila ja lipun reaktio tärpissä, `quiet_water_bite_bonus` ja parvietäisyys vieheen sijainnista. |
| **S10 (`10-landing-net-and-catch`)** | Plaanarin irrotusinteraktio (`attached == true` estää haavituksen kunnes irrotettu veneen laidalla). |
| **S11 (`11-line-tension`)** | `snag_tension_rate`-kireysnousu sekä plaanarin vaikutus kireyteen. |
| **S12 (`12-trolling-window-and-tangles`)** | Sisäkaarteen ja pysähdyksen `TANGLED`-törmäystunnistus + solmun selvitys kannella. |
| **S16 (`16-lake-obstacles`)** | `WorldFeatures`-esteet (saaret/karikot) ja `SNAGGED`-lukitus. |
