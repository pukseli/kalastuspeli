# Mekaniikkaspeksi: Veneen fysiikka (Perämoottori, liuku ja hitaus)

## 1. Yleiskuva ja tavoite
Tämä speksi korvaa viipaleen S1 (`01-boat-on-water`) yksinkertaistetun suora- ja kääntymisnopeusmallin todellisen perämoottoriveneen 2D-fysiikkamallilla (X/Z-taso maailmankoordinaatistossa).

Tavoitteena on saavuttaa luonnollinen vesikulkuneuvon ajotuntuma:
- Vene liukuu vapaalla pitkään eteenpäin (pieni pitkittäisvastus).
- Kaarteissa vene driftaa kylki edellä ulkokaarretta kohti, mutta sivuvastus puree vähitellen (anisotrooppinen vastus).
- Ohjaus perustuu perässä olevan moottorin työntövoiman suuntaukseen (vektoriohjaus), jolloin kaasulla kääntyminen on huomattavasti tehokkaampaa kuin pelkällä liukunopeudella.
- Veneen perä heilahtaa kaarteissa ulospäin, koska kääntöpiste on massakeskipisteessä eikä perälaudassa.

---

## 2. Kääntöpiste (Pivot) ja viipalesuhde kannen koordinaatistoon (S3)

1. **Massakeskipisteen sijainti:**
   - Vene kääntyy massakeskipisteensä (tai n. 1/3 keulasta taaksepäin, veneen rungon keskipistealueella) ympäri.
   - Veneen paikallinen origo `(0, 0, 0)` vastaa tätä kääntöpistettä.
   - Koska moottori sijaitsee perässä (`+Z`), moottorin kääntäminen ohjaa perää sivulle, jolloin perä liukuu kurvissa ulkokaarteen suuntaan ja keula hakeutuu sisäkurviin.

2. **Kannen paikallinen koordinaatisto (`local_position`):**
   - Viipaleessa S3 (`03-crew-on-deck`) määritelty miehistön koordinaatisto säilyy ehjänä. Pelaajien `local_position` on suhteessa veneen kääntöpisteeseen / origoon.
   - Kannen rajat (`DECK_MIN_X`, `DECK_MAX_X`, `DECK_MIN_Z`, `DECK_MAX_Z`) pysyvät voimassa veneen paikallisessa avaruudessa.

---

## 3. Matemaattinen fysiikkamalli (Core 2D X/Z)

Simulaatio ajetaan deterministisesti kiinteällä aika-askeleella (`FIXED_DELTA = 1.0 / 60.0`) luokassa `src/core/simulation/boat_simulator.gd`.

### 3.1 Veneen koordinaatisto ja suuntavektorit
Godotin 3D-maailmassa keula osoittaa oletuksena `-Z`-akselin suuntaan, kun `heading == 0.0`. Kierto `heading` on radiaaneina Y-akselin ympäri (positiivinen vastapäivään ylhäältä katsottuna eli vasemmalle).

Maailman X/Z-tasossa (`Vector2(world_x, world_z)`):
- Eteenpäin-vektori (forward):
  $$\vec{u}_{\text{fwd}} = \begin{pmatrix} -\sin(\text{heading}) \\ -\cos(\text{heading}) \end{pmatrix}$$
- Oikealle osoittava sivuvektori (right/lateral):
  $$\vec{u}_{\text{right}} = \begin{pmatrix} \cos(\text{heading}) \\ -\sin(\text{heading}) \end{pmatrix}$$

### 3.2 Paikalliset nopeuskomponentit ja anisotrooppinen vastus
Maailmankoordinaatiston nopeus $\vec{v} = (v_x, v_z)$ hajotetaan veneen paikallisiksi nopeuksiksi:
- Eteenpäin-nopeus: $v_{\text{fwd}} = \vec{v} \cdot \vec{u}_{\text{fwd}}$
- Sivuttaisnopeus: $v_{\text{lat}} = \vec{v} \cdot \vec{u}_{\text{right}}$

Vastusten vaimennus tikin aikana:
- Eteenpäin suuntautuva liukuvastus on pieni:
  $$v_{\text{fwd\_damped}} = v_{\text{fwd}} \cdot \max(0.0, 1.0 - \text{forward\_drag} \cdot \Delta t)$$
- Sivuttaisvastus on selvästi suurempi, mikä estää loputtoman sivuluisun mutta sallii hallitun driftauksen:
  $$v_{\text{lat\_damped}} = v_{\text{lat}} \cdot \max(0.0, 1.0 - \text{lateral\_drag} \cdot \Delta t)$$

Vaimennetut komponentit muodostavat vaimennetun maailmannopeuden:
$$\vec{v}_{\text{damped}} = v_{\text{fwd\_damped}} \vec{u}_{\text{fwd}} + v_{\text{lat\_damped}} \vec{u}_{\text{right}}$$

### 3.3 Perämoottorin työntövoima ja vektoriohjaus (Vectored Thrust)
Perämoottorin asentoa kuvaa `steering_angle` (radiaaneina, rajoitettu välille `[-max_steering_angle, max_steering_angle]`).
Pelaajan syöte `steering` (-1.0 .. 1.0 vasen/oikea) kääntää moottoria tai asettaa sen kulman:
$$\text{steering\_angle} = \text{clamp}(\text{steering} \cdot \text{max\_steering\_angle}, -\text{max\_steering\_angle}, \text{max\_steering\_angle})$$

1. **Työntövoima (Thrust):**
   Moottorin työntö eteen/taakse veneen rungon pituusakselin suhteen:
   $$F_{\text{thrust}} = \text{throttle} \cdot \cos(\text{steering\_angle}) \cdot \text{engine\_power}$$
   Jos `throttle < 0` (pakki), moottori vetää taaksepäin ja toimii samalla jarruna eteenpäin mentäessä.
   Nopeusvektoriin lisätään kiihtyvyys:
   $$\vec{v}_{\text{new}} = \vec{v}_{\text{damped}} + \vec{u}_{\text{fwd}} \cdot (F_{\text{thrust}} \cdot \Delta t)$$

2. **Kääntävä vääntömomentti (Torque):**
   - **Aktiivinen työntömomentti (kaasulla):**
     $$\tau_{\text{active}} = \text{throttle} \cdot \sin(\text{steering\_angle}) \cdot \text{turn\_power}$$
   - **Passiivinen evä-/peräsinvaikutus (vapaalla rullatessa):**
     Vaikka kaasu olisi 0 (`throttle == 0`), vedessä eteenpäin liikkuva moottorin riki kääntää venettä kevyesti:
     $$\tau_{\text{passive}} = \sin(\text{steering\_angle}) \cdot v_{\text{fwd}} \cdot \text{passive\_turn_power}$$
   - **Kokonaisvääntömomentti:**
     $$\tau = \tau_{\text{active}} + \tau_{\text{passive}}$$
   - **Pakin käyttäytyminen:**
     Kun `throttle < 0`, $\tau_{\text{active}}$ kääntyy vastakkaiseksi, jolloin pakilla veneen perä kääntyy fysiikan mukaisesti toisin päin kuin eteenpäin ajettaessa.

3. **Pyörimisnopeus ja hitaus:**
   Pyörimisliikkeellä (`angular_velocity`) on hitaus ja veden pyörimisvastus:
   $$\omega_{\text{damped}} = \text{angular\_velocity} \cdot \max(0.0, 1.0 - \text{angular\_drag} \cdot \Delta t)$$
   $$\omega_{\text{new}} = \omega_{\text{damped}} + \tau \cdot \Delta t$$
   Uusi suunta:
   $$\text{heading}_{\text{new}} = \text{wrap}(\text{heading} + \omega_{\text{new}} \cdot \Delta t, -\pi, \pi)$$

4. **Sijainnin päivitys:**
   $$\vec{p}_{\text{world}} = \vec{p}_{\text{world}} + \begin{pmatrix} v_{\text{new}, x} \\ 0 \\ v_{\text{new}, z} \end{pmatrix} \cdot \Delta t$$

---

## 4. Konfiguraatioparametrit (`BoatConfig`)

Kaikki fysiikkaparametrit keskitetään helposti säädettäväksi (`src/core/simulation/boat_simulator.gd`):

| Parametri | Oletusarvo | Kuvaus |
| :--- | :--- | :--- |
| `engine_power` | `10.0` | Moottorin maksimikiihdytysvoima (m/s²) |
| `turn_power` | `3.2` | Moottorin kääntövoima kaasulla (rad/s²) |
| `passive_turn_power` | `0.4` | Passiivinen kääntövoima rullatessa per m/s etunopeutta |
| `forward_drag` | `0.35` | Pitkittäisvastuskerroin (pieni -> pitkä liuku) |
| `lateral_drag` | `3.5` | Poikittaisvastuskerroin (korkeampi -> hallittu driftaus) |
| `angular_drag` | `3.0` | Pyörimisvastuskerroin (estää holtittoman pyörimisen) |
| `max_steering_angle` | `0.61` rad (~35°) | Perämoottorin maksimikääntökulma |
| `max_reverse_speed` | `-3.0` m/s | Suurin peruutusnopeus |
| `max_forward_speed` | `10.0` m/s | Suurin sallittu etunopeus |

---

## 5. Visuaalinen kallistuminen (`src/view/boat_view.gd`)

Fysiikkasimulaatio `src/core/` pidetään puhtaasti 2D-tasona (`y = 0`). Visuaalinen 3D-keinunta toteutetaan erillään esityskerroksessa:

1. **Pitch (keulan nousu kiihdytyksessä):**
   - Kiihdytettäessä eteenpäin keula nousee hieman (positiivinen kierto paikallisen X-akselin ympäri).
   - Tavoite: `target_pitch = clamp(-boat.forward_speed * 0.015, -0.08, 0.04)` (tai kiihtyvyyden/kaasun mukaan).
2. **Roll (sivukallistus kaarteissa):**
   - Vauhdikkaassa kaarteessa vene kallistuu sisä- tai ulkokaarteen suuntaan riippuen nopeudesta ja kääntymisestä.
   - Tavoite: `target_roll = clamp(-boat.angular_velocity * boat.forward_speed * 0.02, -0.12, 0.12)`.
3. **Pehmeä interpolointi:**
   - Kallistuskulmat interpoloidaan kohti tavoitearvoa pehmeästi (`lerp` / `move_toward`), jolloin vene ei nykäise.

---

## 6. Suhde muihin viipaleisiin (Slices)

- **S1 (`01-boat-on-water`):** Korvataan aiempi suoraviivainen pisteohjaus perämoottorifysiikalla.
- **S2 (`02-two-windows-one-boat`):** Verkkoreplikointi synkronoi laajennetun `BoatState`-tilan (sisältää `velocity`, `angular_velocity`, `throttle`, `steering_angle`).
- **S3 (`03-crew-on-deck`):** Pelaajat liikkuvat ja pysyvät kannella kääntöpisteen ympärillä.
- **S5 (`05-helm-controls`):** Tuleva vauhtisauva (`throttle_lever`) ja ohjauspyörä (`wheel_angle`) kytkeytyvät suoraan tämän speksin `throttle`- ja `steering_angle`-arvoihin.
