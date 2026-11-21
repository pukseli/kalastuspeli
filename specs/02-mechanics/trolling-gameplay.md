# Mekaniikkaspeksi: Uistelun Ydinsilmukka, 6 Vavan Pujotus ja Tiimikaaos

> **Suuntaa antava pohjoistähti.** Viipalespeksi (`specs/slices/NN-*.md`) on sitova ja saa poiketa tästä. Viipalenumerot (`S6`, `S9` …) viittaavat tiedostoon `specs/02-roadmap.md`.

## 1. Yleiskuva ja tehtäväsaturaation periaate

Peli suunnitellaan niin, että **6 vavan uistelussa yhtäaikaisia tehtäviä on enemmän kuin käsiä**. Yhden roolin pettäminen käynnistää ketjureaktion (esim. pysähdys tai törmäys sotkee siimat), joten tiimityö ja jatkuva kommunikointi syntyvät roolien sopimisesta lennossa.

| Rooli | Kamera / Näkökenttä | Päävastuu | Mitä kädet tekevät / riski |
| :--- | :--- | :--- | :--- |
| **Kippari** | Ruorikamera eteen (`-15°`), ei näe perävapoihin | Pitää vauhdin uisteluikkunassa, tekee loivia kaarroksia, korjaa aallokon/tuulen ja väistää saaret/karikot | Kaasu & ruori säilyvät ruorista poistuttaessa — ruorin jättäminen yksin vie kohti karikkoa |
| **Väsyttäjä** | Kansikamera perään (`-28°`) | Nappaa tärppivavan, pujottaa sen ulommaiseksi (`-1 → -3` / `+1 → +3`), kelaa & hallitsee siiman kireyden (`tension`) | Kädet sidottu vapaan väsytyksen ajan |
| **Vapa-apuri / Pujottaja** | Kansikamera perään (`-28°`) | Siirtää/nostaa `-2`- ja `-3`-vapoja tieltä pujotuksen aikana, selvittää siimasotkut, vahtii muita vapoja tuplatärpiltä | Ehtii nopeisiin telinevaihtoihin ja solmujenselvitykseen |
| **Haavimies** | Kansikamera perään (`-28°`) | Hakee kannettavan haavin, asemoituu ulkolaidalle (`-3`/`+3`), kauhaisee kalan kyytiin ja kippaa sen kalasumppuun (`cooler`) | Oikea ajoitus & paikka; myöhästyminen päästää kalan irti |

---

## 2. 6 vavan uisteluasetelma kannella (`-3..-1 | +1..+3`)

Veneen (`BoatView`) mitat ovat `3.6 m × 7.2 m`, kävelyalue `X ∈ [-1.3, 1.3]`, `Z ∈ [-2.1, 3.0]`, ruori `(0.0, 0.25, -0.6)` ja perämoottori `(0.0, 0.4, 3.7)`. Vapatelineet sijoitetaan veneen takaosan kyljille `~1.0 m` välein (`X ≈ ±1.55`), ja haaviteline sekä kalasumppu keski-/etukannelle selkeän liikkumiskierroksen luomiseksi.

```text
                   KEULA (-Z)
                /-------------\
               |    [RUORI]    |  <- Kippari (näkee eteen: saaret, karikot)
               |               |
  Haaviteline  |    [Kansi]    |  Kalasumppu (cooler)
               |               |
  Vasen (-3)   |   Z ≈ 0.6     |  Oikea (+3)   <- ULOIN: vapaa kaista kelaukseen & haavitukseen
  Vasen (-2)   |   Z ≈ 1.6     |  Oikea (+2)   <- KESKIMMÄINEN
  Vasen (-1)   |   Z ≈ 2.6     |  Oikea (+1)   <- SISIN (lähellä perämoottoria)
                \====[MOO]====/
                  PERÄ (+Z)
          \   \   \   | |   /   /   /
          -3  -2  -1  | |  +1  +2  +3   <- 6 siimaa & viehettä viuhkana vedessä
```

| Positio (`Slot`) | Sijainti (`X`, `Z`) | Siimaviuhka | Sallittu käyttö |
| :--- | :--- | :--- | :--- |
| `-3` / `+3` | `X ≈ ∓1.55`, `Z ≈ 0.6` | Levein kulma, **uloin siima** | Uistelu + **ainoa paikka kalan kelaukseen veneen vierelle ja haavitukseen** |
| `-2` / `+2` | `X ≈ ∓1.55`, `Z ≈ 1.6` | Keskikulma, keskisiima | Uistelu + pujotuksen väliaskel (ei saa kelata kalaa suoraan veneelle) |
| `-1` / `+1` | `X ≈ ∓1.55`, `Z ≈ 2.6` | Kapein kulma, **sisin siima** | Uistelu lähimpänä perää (tärpin jälkeen pujotettava ulommaiseksi) |

---

## 3. Ydinmekaniikat ja ketjureaktiot

| Mekaniikka | Sääntö | Ketjureaktio / Seuraus virheestä |
| :--- | :--- | :--- |
| **Veneen jatkuva liike & uisteluikkuna** | Veneen nopeus pidetään uisteluikkunassa ja käännökset loivina (`BoatSimulator`-kaasukäyrän matala pää ja uisteluikkunan rajat kalibroidaan `S11`:ssä) | Pysähdys / liian hidas vauhti → siimat vajoavat ja sotkeutuvat. Liian kova vauhti → viehe ei pyydä & kireys kasvaa. Jyrkkä käännös → sisäkaarteen siimat sotkuun |
| **Aallokko, tuuli & karikot** | Deterministinen `WaveField` + tuuli/sivuvirta kampeavat venettä kurssilta. Maailman saaret/karikot (`WorldFeatures`) pysäyttävät/kimmottavat törmätessä | Ruorin laiminlyönti vie veneen pois kurssilta tai karikkoon. Äkkipysähdys karikolla → **kaikki vedessä olevat siimat sotkuun** |
| **Tärppi & pujotus (`-1 → -2 → -3`)** | **Yhdistelmämalli:**<br>1. *Tiimipujotus (nopea & turvallinen):* Kaveri siirtää `-2`/`-3`-vavat sisempiin telineisiin tai nostaa/pitelee viereistä vapaa sivuun väsyttäjän kävellessä `-3`:een.<br>2. *Yksinpujotus (hitaampi & riskialttiimpi, backlog `xx-solo-pass`):* Väsyttäjä ohittaa telinevavan itse oikealla yli/ali-asennolla.<br>3. *Kielletty oikotie:* Suora kelaus sisäpaikalta (`-1`, `-2`, `+1`, `+2`) | Väärä yli/ali-asento, huolimaton läpijuoksu tai suora kelaus sisäpaikalta leikkaa ulompien siimojen yli → **siimasotku** |
| **Väsyttäminen & kireys** | Ulommaisesta positiosta (`-3`/`+3`) kala kelataan veneen kyljelle kireyttä (`tension`) halliten | Ylikelaus kalan syöksyessä → siima poikki. Liian löysä siima → kala karkaa |
| **Haavitus, hätälasku & sumppu** | *Tiimisuoritus:* Väsyttäjä pitelee vapaa `-3`/`+3`:ssa, haavimies kauhaisee kalan haavilla ulkolaidalta ja kippaa sumppuun.<br>*Hätälasku (1–2 pelaajaa, backlog `xx-emergency-rest`):* Kalan vavan voi laskea hetkeksi `-3`/`+3`-telineeseen haavin hakua varten | Myöhästyminen haavituksessa tai hätälaskun lyhyen karkausajastimen umpeutuminen → kala riuhtaisee itsensä irti |
| **Siimasotkujen selvitys** | Sotkeutunut vapa lukittuu pois uistelusta, kunnes 1–2 pelaajaa selvittää solmun kannella | Kuormittaa miehistöä (yksi käsipari pois kierrosta) ja sotkuisessa vavassa oleva kala karkaa aikarajan jälkeen |

---

## 4. Interaktiomalli ja ohjaus ("sohvalta pelattava")

Koko pelin kansitoiminta rakentuu kahden selkeän peruskäsitteen varaan:
1. **Kiinteät asemat (`Station`, `S4`):** Ruori (`helm`), 6 kylkivapatelinettä (`-3..-1`, `+1..+3`), haaviteline ja kalasumppu (`cooler`).
2. **Kannettavat esineet (`HeldItem` / "kädet", `S6`):** Pelaajalla on enintään **1 esine kädessä** (`none`, `rod`, `net`, `net_with_fish`), jonka kanssa voi kävellä vapaasti kannella.

| Näppäin | Kannella / Esine kädessä | Ruorissa (`helm`) |
| :--- | :--- | :--- |
| **`WASD`** | Kävely kannella (ahtaassa tilassa törmäilyt muihin pelaajiin) | Kaasu (`W`/`S`) ja ohjaus (`A`/`D` / nuolet), säilyvä asento keskinapsahduksella |
| **`E`** | Tartu ruoriin · Poimi/aseta vapa telineeseen · Poimi/pudota haavi · Kippaa kala sumppuun | Irrota ote ruorista (kaasu ja kääntö jäävät voimaan) |
| **`Space`** | Kelaa siimaa (vapa kädessä) · Kauhaise haavilla (haavi kädessä laidalla) · Selvitä sotku (sotkuisen vavan äärellä) | — |
| **`Q` / `Shift`** | Vavan nosto/lasku yli/ali-pujotuksessa · Siiman lasku veteen | — |

---

## 5. Geneeriset laajennuspisteet (Demossa aallokko & tuuli; muut backlogiin)

Tietoskeema (`specs/01-state-schema.md`) pidetään kevyenä YAGNI-periaatteella ja kasvatetaan vain viipale kerrallaan, mutta ydinkoodi suunnitellaan neljällä avoimella rajapinnalla:

| Laajennuspiste | Demototeutus (S4–S19) | Helppo lisätä backlogista myöhemmin |
| :--- | :--- | :--- |
| **`WorldFeatures`** (`S15`) | Tyypitetty maailmakohdelista: `island`, `rock` | Kalaparvet (`hotspot`), matalikot (`shallow`) |
| **`Station` + `HeldItem`** (`S4`, `S6`, `S9`) | Kiinteät asemat (ruori, telineet, haaviteline, sumppu) + kädessä kannettavat esineet (`rod`, `net`) | Kaikuluotainasema (`sonar`), pilssipumppu (`bilge`), moottorihuolto |
| **Modulaariset `RodState`-tekijät** (`S7–S12`) | Kireys ja sotku lasketaan modulaarisista syötteistä: nopeus, käännös, törmäys, slotti, pujotusasento, kalan veto | Pohjatärpit, roskat vieheessä, vieheen syvyyskäyrä |
| **`EventDirector`** (`S19`) | Erillinen tapahtumasyöttäjä, joka rytmittää demossa tärpit/tuplatärpit ja aallokon/tuulen | Kalaparvitapahtumat, uistelukisan tilaukset (`orders`), moottoriviat |
