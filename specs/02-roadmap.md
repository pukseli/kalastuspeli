# 02 — Roadmap (Viipalekartta)

> *"Sumuvalo-periaate: vain seuraava viipale speksataan tarkasti (`specs/slices/`). Muut ovat tässä yhden rivin tavoitteina. Järjestystä saa muuttaa."*

| # | Viipale (tiedosto) | "Nyt voin ___" | Uusi käsite | Tila |
| :--- | :--- | :--- | :--- | :--- |
| S0 | Ympäristö ja perusta | ajaa headless-testiportin | Testiportti | `done` |
| S1 | `01-boat-on-water` | ajaa venettä järvellä yhdessä ikkunassa | Core + 3D-näkymän runko | `done` |
| S2 | `02-two-windows-one-boat` | nähdä saman veneen kahdessa ikkunassa (`--host` / `--join` / `--port` / `--sync-hz`, `T`-tickrate) | Verkkosynkka (vain `BoatState`) | `done` |
| S3 | `03-crew-on-deck` | kävellä 3D-hahmolla kannella matalammasta kamerakulmasta (`-28°`), nähdä toiset ikkunat ja säätää testipelaajia (`B` / `--bots`) | Paikallinen kansikoordinaatisto verkon yli | `done` |
| S4 | `04-stations` | kävellä toimintopaikan äärelle, tarttua ruoriin (`E`), kokea ohjaamonäkymä ja säätää säilyvää kaasua/kääntöä keskinapsahduksilla | Yleinen `Station`-järjestelmä (`StationConfig.STATIONS`, `GameState.stations`), ohjaamonäkymä ja keskinapsahdus | `done` |
| S5 | `05-helm-controls` | nähdä ja säätää 3D-vauhtisauvaa, pyörivää ohjauspyörää sekä asento-osoitinta ruoripulpetissa | Ruoriohjauksen 3D-visuaalit, asento-osoitin ja tavoitenopeuskäyrä | `draft` |
| S6 | `06-smooth-sync` | pelata ilman nykimistä 100 ms viiveellä | Interpolointi (vene + miehistö) + viivesimulaatio | `draft` |
| S7 | `07-lobby-ui` | hostata ja liittyä ilman komentoriviä (näyttää paikalliset IP:t) | UI | `draft` |
| S8 | `08-lure-and-line` | laskea vieheen veteen vapa-asemalta ja nähdä siiman sekä vieheen kulkevan veneen perässä | `RodState` + vieheen/siiman perussimulaatio (pituus, kireyden perusta, kytkentä `Station`-asemaan) | `draft` |
| S9 | `09-first-catch` | saada tärpin, hallita siiman kireyttä ja kelata kalan veneeseen | Kalastuksen ydinsilmukan prototyyppi ("find the fun": tärppi, veto, kelaus, ylösotto) | `draft` |
| S10 | `10-multi-rod-handling` | kalastaa usealla vavalla ja siirtää/liikuttaa vapoja tieltä kalan väsytyksen aikana | Monivapa-asetelma + vapojen aktiivinen siirto/väistö | `draft` |
| S11 | `11-waves-and-buoyancy` | ajaa erikokoisissa aalloissa, joissa vene keikkuu ja kallistuu | Matemaattinen `WaveField` + 4 pisteen kellunta (`y`, `pitch`, `roll`) | `draft` |
| — | `xx-fish-and-lure-sim` | kokea järven kalasimuloinnin, vieheen syvyyden ja siimasotkut | Kalojen liike/käyttäytyminen + vieheen syvyysmalli + siimasotkut | `backlog` |
| — | `xx-dedicated-server` | ajaa palvelimen ilman pelaajaa (`--server`) | Dedicated-tila | `backlog` |
| — | `xx-export` | ajaa pelin pöytäkoneella (Windows-export) | Export presetit + templatet | `backlog` |

**Tilat:** `draft` = idea, `approved` = speksi hyväksytty, `in-progress` = työn alla, `done` = DoD täyttyy, `backlog` = tarvittaessa.

---

## Speksatut mekaniikkaideat (Toteutetaan kohdeviipaleessa)

> Nämä pelimekaniikat on sovittu etukäteen ja poimitaan mukaan, kun kohdeviipaleen `specs/slices/NN-*.md` laaditaan. Tulevia ideoita ei jalosteta ennenaikaisesti.

| Kohdeviipale | Mekaniikka | Speksattu sääntö |
| :--- | :--- | :--- |
| **S1 / Mekaniikka** | **Perämoottori, liuku ja hitaus (`specs/02-mechanics/boat-physics.md`)** | 2D X/Z-fysiikkamalli: kääntöpiste massakeskipisteessä (kansi pysyy ehjänä), perämoottorin vektoriohjaus kaasulla ja vapaalla, pakki jarruna/suunnan kääntäjänä, anisotrooppinen sivuttaisvastus (driftaus), hitaus ilman äkkijarrua sekä visuaalinen pitch/roll esityskerroksessa. |
| **S3 (`03-crew-on-deck`)** | **Matalampi 3D-kamerakulma & 3D-hahmot** | Kamera tuodaan alemmas ja suunnataan enemmän eteenpäin (`-28°`), jotta 3D-syvyys, horisontti ja 3D-hahmot kannella tulevat esiin. Peli toimii myös yksinpelinä ja testipelaajia voi säätää lennosta (`B` / `--bots`, kevyet testinuket ilman AI:ta). |
| **S4 (`04-stations`)** | **Yleinen toimintopaikka (`Station`)** | Veneessä on `N` kpl paikallisia toimintopaikkoja (`StationConfig.STATIONS`, esim. kuskin paikka `"helm"`, myöhemmin vavat, moottori, haavi). Toiminto aktivoituu **vain olemalla kyseisen paikan äärellä** (`E`, 1 pelaaja / paikka). Venettä ohjataan **vain** `"helm"`-asemalta (`GameState.stations[station_id] = occupant_peer_id`), ja kaasussa/ohjauksessa on `0.0`-keskinapsahdus sekä progressiivinen ohjauskäyrä. |
| **S5 (`05-helm-controls`)** | **3D-vauhtisauva & tavoitenopeuskäyrä** | Pulpetin 3D-vauhtisauva kääntyy `throttle`-tilan mukana, ja veneen tavoitenopeus voidaan sovittaa hienostuneempaan matkavauhtikäyrään (`throttle * max_speed`). |
| **S5 (`05-helm-controls`)** | **3D-ohjauspyörä & asento-osoitin** | Pulpetin 3D-ohjauspyörä pyörii `steering_angle`-kulman mukana ja visuaalinen keskipiste-/asento-osoitin pulpetissa tai HUD:ssa helpottaa suorana ajoa. |
| **S8 (`08-lure-and-line`)** | **Viehe- ja siimasimulaation perusta** | Vapa kytketään `Station`-järjestelmään: siiman pituus, kireyden laskennan perusta ja vieheen kulku vedessä veneen perässä. |
| **S9 (`09-first-catch`)** | **Tärppi ja kalan ylös vetäminen** | Kala jää koukkuun (tärppi ja kalan veto), pelaaja hallitsee kireyttä ja kelaa kalan veneeseen (ydinsilmukan "find the fun" -testi). |
| **S10 (`10-multi-rod-handling`)** | **Useat vavat ja vapojen liikuttaminen** | Useampi vapa-asema veneessä; pelaajat voivat aktiivisesti liikuttaa ja siirtää muita vapoja tieltä kalan väsytyksen aikana. |
| **S11 (`11-waves-and-buoyancy`)** | **Erikokoiset aallot ja aaltofysiikka** | Deterministinen `WaveField` (`src/core/`) laskee erikokoisten aaltojen korkeuden `get_wave_height(x, z, time)`. Veneen kellunta lasketaan 4 pisteestä (keula, perä, vasen, oikea), mikä tuottaa korkeuden (`y`), keulan nyökkimisen (`pitch`), sivukallistuksen (`roll`) ja aaltovastuksen. 3D-vesi piirtää saman aaltomuodon kevyellä low-poly-gridillä/shaderilla, ja kannella olevat pelaajat keinuvat veneen paikallisessa koordinaatistossa automaattisesti mukana. |
| **Backlog (`xx-fish-and-lure-sim`)** | **Kalasimulointi, syvyys ja siimasotkut** | Kalojen liike/käyttäytyminen järvessä, vieheen syvyyskäyrä nopeuden ja siiman pituuden mukaan sekä siimasotkut, jos vapoja ei siirretä tieltä. |
