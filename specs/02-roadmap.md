# 02 — Roadmap (Viipalekartta)

> *"Sumuvalo-periaate: vain seuraava viipale speksataan tarkasti (`specs/slices/`). Muut ovat tässä yhden rivin tavoitteina. Järjestystä saa muuttaa."*

| # | Viipale (tiedosto) | "Nyt voin ___" | Uusi käsite | Tila |
| :--- | :--- | :--- | :--- | :--- |
| S0 | Ympäristö ja perusta | ajaa headless-testiportin | Testiportti | `done` |
| S1 | `01-boat-on-water` | ajaa venettä järvellä yhdessä ikkunassa | Core + 3D-näkymän runko | `in-progress` |
| S2 | `02-two-windows-one-boat` | nähdä saman veneen kahdessa ikkunassa (`--host` / `--join` / `--port`) | Verkkosynkka (vain `BoatState`) | `draft` |
| S3 | `03-crew-on-deck` | kävellä kannella, ja toinen ikkuna näkee sen | Paikallinen koordinaatisto verkon yli | `draft` |
| S4 | `04-helm` | ottaa ruorin ja luovuttaa sen | Ohjausoikeus (`driver_peer_id`) | `draft` |
| S5 | `05-smooth-sync` | pelata ilman nykimistä 100 ms viiveellä | Interpolointi + viivesimulaatio | `draft` |
| S6 | `06-lobby-ui` | hostata ja liittyä ilman komentoriviä (näyttää paikalliset IP:t) | UI | `draft` |
| S7 | `07-first-catch` | saada kalan (yksi vapa, yksi tärppi) | Ydinsilmukan prototyyppi ("find the fun") | `draft` |
| — | `xx-dedicated-server` | ajaa palvelimen ilman pelaajaa (`--server`) | Dedicated-tila | `backlog` |
| — | `xx-export` | ajaa pelin pöytäkoneella (Windows-export) | Export presetit + templatet | `backlog` |

**Tilat:** `draft` = idea, `approved` = speksi hyväksytty, `in-progress` = työn alla, `done` = DoD täyttyy, `backlog` = tarvittaessa.
