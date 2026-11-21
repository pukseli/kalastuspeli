# 02 — Roadmap (Viipalekartta)

> *"Sumuvalo-periaate: vain seuraava viipale speksataan tarkasti (`specs/slices/`). Muut ovat tässä yhden rivin tavoitteina. Järjestystä saa muuttaa."*

| # | Viipale (tiedosto) | "Nyt voin ___" | Uusi käsite | Tila |
| :--- | :--- | :--- | :--- | :--- |
| S0 | Ympäristö ja perusta | ajaa headless-testiportin | Testiportti | `done` |
| S1 | `01-boat-on-water` | ajaa venettä järvellä yhdessä ikkunassa | Core + 3D-näkymän runko | `in-progress` |
| S2 | `02-two-windows-one-boat` | nähdä saman veneen kahdessa ikkunassa (`--host` / `--join` / `--port`) | Verkkosynkka (vain `BoatState`) | `draft` |
| S3 | `03-crew-on-deck` | kävellä kannella, ja toinen ikkuna näkee sen | Paikallinen koordinaatisto verkon yli | `draft` |
| S4 | `04-helm` | ottaa ruorin, säätää vauhtisauvaa ja luovuttaa ruorin | Ohjausoikeus (`driver_peer_id`) + vauhtisauva (`throttle_lever`) | `draft` |
| S5 | `05-smooth-sync` | pelata ilman nykimistä 100 ms viiveellä | Interpolointi + viivesimulaatio | `draft` |
| S6 | `06-lobby-ui` | hostata ja liittyä ilman komentoriviä (näyttää paikalliset IP:t) | UI | `draft` |
| S7 | `07-first-catch` | saada kalan (yksi vapa, yksi tärppi) | Ydinsilmukan prototyyppi ("find the fun") | `draft` |
| S8 | `08-waves-and-buoyancy` | ajaa erikokoisissa aalloissa, joissa vene keikkuu ja kallistuu | Matemaattinen `WaveField` + 4 pisteen kellunta (`y`, `pitch`, `roll`) | `draft` |
| — | `xx-dedicated-server` | ajaa palvelimen ilman pelaajaa (`--server`) | Dedicated-tila | `backlog` |
| — | `xx-export` | ajaa pelin pöytäkoneella (Windows-export) | Export presetit + templatet | `backlog` |

**Tilat:** `draft` = idea, `approved` = speksi hyväksytty, `in-progress` = työn alla, `done` = DoD täyttyy, `backlog` = tarvittaessa.

---

## Speksatut mekaniikkaideat (Toteutetaan kohdeviipaleessa)

> Nämä pelimekaniikat on sovittu etukäteen ja poimitaan mukaan, kun kohdeviipaleen `specs/slices/NN-*.md` laaditaan.

| Kohdeviipale | Mekaniikka | Speksattu sääntö |
| :--- | :--- | :--- |
| **S3 / S4** | **Matalampi 3D-kamerakulma** | Kamera tuodaan alemmas ja suunnataan enemmän eteenpäin (esim. `-18° .. -25°` korkean `-45°` lintuperspektiivin sijaan), jotta 3D-syvyys, horisontti ja aaltojen korkeuserot tulevat selkeästi esiin. |
| **S4 (`04-helm`)** | **Vauhtisauva (`throttle_lever`)** | `W` / `Up` siirtää vauhtisauvan asentoa (`throttle_lever: float`, `-1.0 .. 1.0`, alkutila `0.0`) eteenpäin ja `S` / `Down` taaksepäin. Kun näppäimen päästää irti, **vauhtisauva jää paikalleen** (myös jos kuski poistuu ruorista). Veneen tavoitenopeus määräytyy vauhtisauvan asennosta (`throttle_lever * max_speed`), jota kohti `forward_speed` hakeutuu. Pieni `0.0`-keskinapsahdus helpottaa pysäyttämistä. |
| **S4 (`04-helm`)** | **Ohjauspyörä (`wheel_angle`)** | `A` / `Left` kääntää ohjauspyörän asentoa (`wheel_angle: float`, `-1.0 .. 1.0`, alkutila `0.0`) vasemmalle ja `D` / `Right` oikealle. Kun näppäimen päästää irti, **ohjauspyörä jää paikalleen** (ei automaattista keskitystä). Veneen kääntymisnopeus määräytyy ohjauspyörän asennosta. Pieni `0.0`-keskinapsahdus ja visuaalinen asento-osoitin helpottavat suorana ajoa. |
| **S8 (`08-waves-and-buoyancy`)** | **Erikokoiset aallot ja aaltofysiikka** | Deterministinen `WaveField` (`src/core/`) laskee erikokoisten aaltojen korkeuden `get_wave_height(x, z, time)`. Veneen kellunta lasketaan 4 pisteestä (keula, perä, vasen, oikea), mikä tuottaa korkeuden (`y`), keulan nyökkimisen (`pitch`), sivukallistuksen (`roll`) ja aaltovastuksen. 3D-vesi piirtää saman aaltomuodon kevyellä low-poly-gridillä/shaderilla, ja kannella olevat pelaajat keinuvat veneen paikallisessa koordinaatistossa automaattisesti mukana. |
