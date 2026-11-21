# 02 — Roadmap (Viipalekartta)

> *"Sumuvalo-periaate: vain seuraava viipale speksataan tarkasti (`specs/slices/`). Muut ovat tässä yhden rivin tavoitteina. Järjestystä saa muuttaa."*
> **Kehitysfilosofia:** Netcode & perusfysiikka ensin (`S5–S7`) → uistelun ydinfunktionaalisuudet (`S8–S14`) → "väriä", ergonomia & UI (`S15–S17`) → laajennettava backlog.

| # | Viipale (tiedosto) | "Nyt voin ___" | Uusi käsite | Tila |
| :--- | :--- | :--- | :--- | :--- |
| S0 | Ympäristö ja perusta | ajaa headless-testiportin | Testiportti | `done` |
| S1 | `01-boat-on-water` | ajaa venettä järvellä yhdessä ikkunassa | Core + 3D-näkymän runko | `done` |
| S2 | `02-two-windows-one-boat` | nähdä saman veneen kahdessa ikkunassa (`--host` / `--join` / `--port` / `--sync-hz`, `T`-tickrate) | Verkkosynkka (vain `BoatState`) | `done` |
| S3 | `03-crew-on-deck` | kävellä 3D-hahmolla kannella matalammasta kamerakulmasta (`-28°`), nähdä toiset ikkunat ja säätää testipelaajia (`B` / `--bots`) | Paikallinen kansikoordinaatisto verkon yli | `done` |
| S4 | `04-stations` | kävellä toimintopaikan äärelle, tarttua ruoriin (`E`), kokea ohjaamonäkymä ja säätää säilyvää kaasua/kääntöä keskinapsahduksilla | Yleinen `Station`-järjestelmä (`StationConfig.STATIONS`, `GameState.stations`), ohjaamonäkymä ja keskinapsahdus | `done` |
| S5 | `05-smooth-sync` | pelata ilman nykimistä 100 ms viiveellä | Interpolointi (vene + miehistö) + viivesimulaatio | `draft` |
| S6 | `06-waves-and-wind` | ajaa aallokossa ja tuulessa, jossa vene keikkuu, kallistuu ja ajautuu sivuun ilman kurssin korjausta | Deterministinen `WaveField` + 4 pisteen kellunta (`y`, `pitch`, `roll`) + tuuli/sivuvirta + uistelukaasualueen hienosäätö | `draft` |
| S7 | `07-lake-obstacles` | väistää järven saaria ja karikoita, joihin törmääminen pysäyttää/kimmottaa veneen | Geneerinen `WorldFeatures`-rakenne (saaret/karikot) + törmäysfysiikka | `draft` |
| S8 | `08-held-items-and-racks` | poimia vavan tai haavin telineestä käteen, kävellä sen kanssa kannella ja asettaa vavan toiseen kylkitelineeseen (`-3..-1`, `+1..+3`) | Kannettavat esineet (`HeldItem`) + kylkivapatelineet, haaviteline & kalasumppu | `draft` |
| S9 | `09-trolling-lines` | laskea 1–6 viehettä veteen viuhkaan (`-3..+3`), säätää siiman pituutta ja nähdä uistelunopeusikkunan | `RodState` + 6 siiman/vieheen perussimulaatio + nopeus-/käännösikkuna | `draft` |
| S10 | `10-line-tangles` | kokea siimasotkut (pysähdys, karikkotörmäys tai jyrkkä käännös) ja selvittää solmun kannella | Siimasotkutila, automaattiset sotkulaukaisimet + selvitystoiminto | `draft` |
| S11 | `11-bite-and-fighting` | saada kalan tärpin vapaan, hallita siiman kireyttä ja väsyttää kalan veneen vierelle | `FishState` + tärppi, syöksyt, kireys (`tension`), katkeaminen / karkaaminen | `draft` |
| S12 | `12-rod-threading` | pujottaa tärppivavan ulommaiseksi (`-1 → -2 → -3`) kaverin siirtäessä/nostaessa vapoja tieltä tai itse varovasti yli/ali ohittaen ilman sotkua | Yhdistelmäpujotus (telinevaihto + yli/ali-ohitus) ja sisäpaikan kelausrangaistus (sotku) | `draft` |
| S13 | `13-landing-net-and-catch` | kauhaista ulkolaidalle (`-3`/`+3`) kelatun kalan haavilla ja kipata sen sumppuun (myös hätälaskulla telineeseen) | Haavitusikkuna, yksinpelin hätälaskuajastin ja saalislaskuri (`cooler`) | `draft` |
| S14 | `14-chaos-demo-loop` | pelata kaveriporukalla demokierroksen, jossa tuplatärpit, aallokko, tuuli ja karikot ruuhkauttavat miehistön | Geneerinen `EventDirector` (tärppien/tuplatärppien rytmitys) + demoerän tila | `draft` |
| S15 | `15-helm-controls` | nähdä ja säätää 3D-vauhtisauvaa, pyörivää ohjauspyörää sekä asento-/nopeusosoitinta pulpetissa | Ruoriohjauksen 3D-visuaalit ja mittaristo | `draft` |
| S16 | `16-lobby-ui` | hostata ja liittyä ilman komentoriviä (näyttää paikalliset IP:t) | Aula-UI | `draft` |
| S17 | `17-visual-audio-feedback` | erottaa tärpit, siiman kireyden, sotkut ja saaliit selkeistä visuaali- ja äänimerkeistä | Vavan taipuma, räikkä-/tärppimerkki, kireys- ja roiskepalaute | `draft` |
| — | `xx-fish-hotspots` | ajaa karikoiden lähellä oleviin kalaparviin hakemaan isoja saaliita ja tuplatärppejä | Kalaparvet (`WorldFeatures` + `EventDirector`) | `backlog` |
| — | `xx-fishing-orders` | pelata aikarajoitettua uistelukisaa kilotavoitteilla tai kalatilauksilla | Eräkello, kisapisteet & lajitilaukset | `backlog` |
| — | `xx-sonar-station` | käyttää kaikuluotainasemaa kalaparvien ja piilokarikoiden huutamiseen kipparille | Kaikuluotain / kartanlukija (`Station` + `WorldFeatures`) | `backlog` |
| — | `xx-snags-and-upkeep` | selvittää pohjatärpit, roskat vieheessä, moottoriviat ja pilssiveden myrskyssä | Vieheen syvyys/roskat + veneen huoltoasemat | `backlog` |
| — | `xx-dedicated-server` | ajaa palvelimen ilman pelaajaa (`--server`) | Dedicated-tila | `backlog` |
| — | `xx-export` | ajaa pelin pöytäkoneella (Windows-export) | Export presetit + templatet | `backlog` |

**Tilat:** `draft` = idea, `approved` = speksi hyväksytty, `in-progress` = työn alla, `done` = DoD täyttyy, `backlog` = tarvittaessa.

---

## Speksatut mekaniikkaideat (Toteutetaan kohdeviipaleessa)

> Nämä pelimekaniikat on sovittu etukäteen ja poimitaan mukaan, kun kohdeviipaleen `specs/slices/NN-*.md` laaditaan. Ydinkaaoksen kokonaissuunnitelma ja laajennuspisteet on dokumentoitu tiedostoon `specs/02-mechanics/trolling-gameplay.md`.

| Kohdeviipale | Mekaniikka | Speksattu sääntö |
| :--- | :--- | :--- |
| **S1 / Mekaniikka** | **Perämoottori, liuku ja hitaus (`specs/02-mechanics/boat-physics.md`)** | 2D X/Z-fysiikkamalli: kääntöpiste massakeskipisteessä (kansi pysyy ehjänä), perämoottorin vektoriohjaus kaasulla ja vapaalla, pakki jarruna/suunnan kääntäjänä, anisotrooppinen sivuttaisvastus (driftaus), hitaus ilman äkkijarrua sekä visuaalinen pitch/roll esityskerroksessa. |
| **S3 (`03-crew-on-deck`)** | **Matalampi 3D-kamerakulma & 3D-hahmot** | Kamera tuodaan alemmas ja suunnataan enemmän eteenpäin (`-28°`), jotta 3D-syvyys, horisontti ja 3D-hahmot kannella tulevat esiin. Peli toimii myös yksinpelinä ja testipelaajia voi säätää lennosta (`B` / `--bots`, kevyet testinuket ilman AI:ta). |
| **S4 (`04-stations`)** | **Yleinen toimintopaikka (`Station`)** | Veneessä on `N` kpl paikallisia toimintopaikkoja (`StationConfig.STATIONS`, esim. kuskin paikka `"helm"`). Toiminto aktivoituu **vain olemalla kyseisen paikan äärellä** (`E`, 1 pelaaja / paikka). Venettä ohjataan **vain** `"helm"`-asemalta (`GameState.stations[station_id] = occupant_peer_id`), ja kaasussa/ohjauksessa on `0.0`-keskinapsahdus sekä progressiivinen ohjauskäyrä. |
| **S6 (`06-waves-and-wind`)** | **Aallokko, tuuli & uistelukaasu** | Deterministinen `WaveField` (`src/core/`) laskee aallonkorkeuden `get_wave_height(x, z, time)` ja tuottaa 4 pisteen kellunnan (`y`, `pitch`, `roll`), minkä lisäksi tuuli/sivuvirta kampeaa venettä pois kurssilta. Samalla hienosäädetään `BoatSimulator`-kaasukäyrän matala pää uistelunopeusikkunaan sopivaksi. |
| **S7 (`07-lake-obstacles`)** | **Järven esteet (`WorldFeatures`)** | Geneerinen `WorldFeatures`-rakenne saarille ja karikoille; törmäys pysäyttää tai kimmottaa veneen. |
| **S8–S14 (`trolling-gameplay.md`)** | **6 vavan uistelu, pujotus (`-1 → -3`), sotkut, haavi & `EventDirector`** | `HeldItem` + 6 kylkivapatelinettä (`-3..-1`, `+1..+3`), jatkuvan liikkeen vauhti-/käännösikkuna, siimasotkut (pysähdys, törmäys, jyrkkä käännös, väärä pujotus/kelaus), yhdistelmäpujotus ulommaiseksi, haavitus hätälaskulla ja `EventDirector`-kaaospiikit. Ks. `specs/02-mechanics/trolling-gameplay.md`. |
| **S15 (`15-helm-controls`)** | **3D-vauhtisauva, ohjauspyörä & asento-osoitin** | Pulpetin 3D-vauhtisauva kääntyy `throttle`-tilan mukana, 3D-ohjauspyörä pyörii `steering_angle`-kulman mukana ja keskipiste-/nopeusosoitin helpottaa suorana ajoa ja uistelunopeuden pitoa. |
| **S17 (`17-visual-audio-feedback`)** | **Visuaali- ja äänipalaute** | Vavan taipuma, räikkä-/tärppiääni, siiman kireysväri/merkki ja kalan roiskahdus haavituksessa. |
| **Backlog (`xx-*`)** | **Parvet, kisatilaukset, kaikuluotain, pohjatärpit & huollot** | Kytkeytyvät suoraan neljään laajennuspisteeseen (`WorldFeatures`, `Station`+`HeldItem`, modulaariset `RodState`-tekijät, `EventDirector`). Ks. `specs/02-mechanics/trolling-gameplay.md`. |
