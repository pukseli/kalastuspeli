# 00 — Arkkitehtuuri ja Kehitysideologia

## 1. Projektin Kehitysideologia

### Atomic Vertical Slicing (Specs as Code)

| Taso | Tiedostot | Sääntö |
| :--- | :--- | :--- |
| **Perustuslaki & Elävä Skeema** | `00-environment.md`, `00-architecture.md`, `01-state-schema.md` | Pysyvä perusta + tietoskeema, joka kasvaa **vain viipale kerrallaan** (ei tulevaisuuden ominaisuuksien etukäteisspeksausta / YAGNI). |
| **Atomiset Viipalespeksit** | `specs/slices/XX-<nimi>.md` (30–50 riviä / viipale) | 3 osaa: *State Delta*, *Rules & Math* ja *Headless Acceptance Test*. Putki: `Mikrospeksi -> Headless-testi -> Koodi -> Verifiointi` valmiiksi ennen seuraavaa viipaletta. |

### Token-optimoitu Monimallityönkulku (Multi-Model Token Efficiency)

| Rooli | Malli / Agentti | Vastuu |
| :--- | :--- | :--- |
| **Arkkitehti** | Pääagentti (kalliimpi malli) | Suunnittelee rajapinnat, kirjoittaa *Zero-Exploration*-tehtäväkortit (valmiit polut, luokat, tyypit ilman etsintää) ja tarkistaa testitulokset. |
| **Rakentaja** | `flash`-alagentti | Tuottaa 85–90 % output-tokeneista (`.md`, `.gd`, yksikkötestit), ajaa itse `godot --headless` -testin ja korjaa virheet ennen palautusta. |
| **Apuri** | `flash_lite`-alagentti | Mekaaniset rutiinitehtävät. |
| **Token-Dense Specs** | Kaikki speksit | Kirjoitetaan tiiviinä taulukoina ja tyyppimäärittelyinä pitkän proosan sijaan. |

### Code-First & Kielisääntö

| Sääntö | Toteutus |
| :--- | :--- |
| **Yksi skenetiedosto** | Vain **yksi** `.tscn`-tiedosto (`src/main.tscn`). Kaikki 3D-primitiivit, materiaalit, valot, kamerat ja UI rakennetaan proseduraalisesti GDScriptillä. |
| **Kieli** | Koodi, luokat, muuttujat ja kommentit **englanniksi**; speksidokumentaatio **suomeksi**. |

## 2. Kansiorakenne ja Arkkitehtuurikerrokset

| Polku / Kerros | Luonne | Vastuu ja Rajoitteet |
| :--- | :--- | :--- |
| `specs/` | Dokumentaatio | Perustus (`00-*`, `01-*`) + atomiset viipalespeksit (`specs/slices/`). |
| `src/core/` | **Headless Core** | Puhtaat `RefCounted`-luokat kansioissa `state/` ja `simulation/`. **0 riippuvuutta** `Node3D`-, renderöinti- tai verkkoluokkiin. |
| `src/network/` | **3-kerroksinen moninpeli** | Kerros 1 (`src/core/`): verkosta riippumaton (`peer_id: int`, syötevektorit, `Dictionary`-tila).<br>Kerros 2 (`src/network/network_manager.gd`): synkronoi tilan Godotin abstraktin `MultiplayerAPI`-rajapinnan yli (20 Hz tick rate). Tukee alusta asti sekä **Listen Serveriä** (Host `peer_id == 1` on pelaaja) että **Dedicated Headless Serveriä** (`--headless --server`, ajaa simulaatiota ilman omaa pelaajakapselia).<br>Kerros 3 (`src/network/network_transport.gd`): vaihtokelpoinen `MultiplayerPeer`-tehdas. MVP: `ENetMultiplayerPeer` (kuuntelee `*` / `0.0.0.0`, Direct IP + portti `7777` + CLI-vivut `--host`, `--join <ip>`, `--port <port>`, `--server`). Julkaisussa vaihdettavissa `SteamMultiplayerPeer`- tai `WebRTCMultiplayerPeer`-toteutukseen muuttamatta pelilogiikkaa tai RPC-synkronointia. |
| `src/view/` | **Proseduraalinen 3D & UI** | Low-poly 3D-näkymä ja HUD. **Veneen paikallinen koordinaatisto (Boat Local Space):** pelaajat liikkuvat ja synkronoidaan veneen paikallisessa koordinaatistossa (`local_position: Vector3`), ja `PlayerView`-solmut ovat `BoatView`-solmun lapsia (`BoatView/PlayersContainer/PlayerView`). |
| `tests/` | **Headless-yksikkötestit** | Automaattitestit ilman grafiikkaa tai ääntä. |

## 3. Automaattitestausstrategia (Headless Gatekeeper)

Jokainen viipale verifioidaan komennolla:

```bash
godot --headless --audio-driver Dummy --path /home/akseli/kalastuspeli --script res://tests/run_tests.gd
```

| Laatukriteeri | Vaatimus |
| :--- | :--- |
| **Paluukoodi** | `exit code 0` |
| **Virheet** | `0` virhettä ja kaikki testit läpäisty |
