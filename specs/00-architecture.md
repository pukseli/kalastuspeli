# 00 — Arkkitehtuuri ja Kehitysideologia

## 1. Projektin Kehitysideologia

### Atomic Vertical Slicing (Specs as Code)

| Taso | Tiedostot | Sääntö |
| :--- | :--- | :--- |
| **Perustuslaki & Elävä Skeema** | `00-vision.md`, `00-environment.md`, `00-architecture.md`, `01-state-schema.md`, `02-roadmap.md` | Pysyvä perusta + tietoskeema, joka kasvaa **vain viipale kerrallaan** (ei tulevaisuuden ominaisuuksien etukäteisspeksausta / YAGNI). |
| **Atomiset Viipalespeksit** | `specs/slices/XX-<nimi>.md` (pohja: `specs/slices/_template.md`, roadmap: `specs/02-roadmap.md`, ≤ 60 ei-tyhjää riviä / viipale) | 7 osaa, ks. _template.md. Putki: `Mikrospeksi -> Headless-testi -> Koodi -> Verifiointi` valmiiksi ennen seuraavaa viipaletta. |

### Token-optimoitu Monimallityönkulku (Multi-Model Token Efficiency)

| Rooli | Malli / Agentti | Vastuu |
| :--- | :--- | :--- |
| **Arkkitehti** | Pääagentti (kalliimpi malli) | Suunnittelee rajapinnat, kirjoittaa *Zero-Exploration*-tehtäväkortit (valmiit polut, luokat, tyypit ilman etsintää) ja tarkistaa testitulokset. |
| **Rakentaja** | `flash`-alagentti | Tuottaa 85–90 % output-tokeneista (`.md`, `.gd`, yksikkötestit), ajaa `bash tests/run.sh`, ei muokkaa hyväksymistestejä (§4), ja korjaa virheet ennen palautusta. |
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
| `specs/` | Dokumentaatio | Perustus (`00-*`, `01-*`, `02-*`) + atomiset viipalespeksit (`specs/slices/`). |
| `src/core/` | **Headless Core** | Puhtaat `RefCounted`-luokat kansioissa `state/` ja `simulation/`. **0 riippuvuutta** `Node3D`-, renderöinti- tai verkkoluokkiin. |
| `src/core/simulation/` | **Aika-askel** | Simulaatio `step(state, delta)` kutsutaan kiinteällä `1.0 / 60.0`-arvolla `_physics_process`-metodista. Testit käyttävät samaa vakiota. Verkkosnapshot 20 Hz (joka 3. tick). |
| `src/network/` | **3-kerroksinen moninpeli** | Kerros 1 (`src/core/`): verkosta riippumaton (`peer_id: int`, syötevektorit, `Dictionary`-tila).<br>Kerros 2 (`src/network/network_manager.gd`): synkronoi tilan Godotin abstraktin `MultiplayerAPI`-rajapinnan yli (20 Hz tick rate). MVP = **Listen Server + Client** (Host `peer_id == 1` on pelaaja). *Arkkitehtuuri ei estä Dedicated Headless Serveriä (`--server`); toteutus omassa viipaleessaan tarvittaessa (ks. roadmap).*<br>Kerros 3 (`src/network/network_transport.gd`): vaihtokelpoinen `MultiplayerPeer`-tehdas. MVP: `ENetMultiplayerPeer` (kuuntelee `*` / `0.0.0.0`, Direct IP + portti `7777` + CLI-vivut `--host`, `--join <ip>`, `--port <port>`, `--server`). Julkaisussa vaihdettavissa `SteamMultiplayerPeer`- tai `WebRTCMultiplayerPeer`-toteutukseen muuttamatta pelilogiikkaa tai RPC-synkronointia. |
| `src/view/` | **Proseduraalinen 3D & UI** | Low-poly 3D-näkymä ja HUD. **Veneen paikallinen koordinaatisto (Boat Local Space):** pelaajat liikkuvat ja synkronoidaan veneen paikallisessa koordinaatistossa (`local_position: Vector3`), ja `PlayerView`-solmut ovat `BoatView`-solmun lapsia (`BoatView/PlayersContainer/PlayerView`). |
| `tests/` | **Headless-yksikkötestit** | Automaattitestit ilman grafiikkaa tai ääntä. |

## 3. Automaattitestausstrategia (Headless Gatekeeper)

Jokainen viipale verifioidaan komennolla:

```bash
bash tests/run.sh
```

| Laatukriteeri | Vaatimus |
| :--- | :--- |
| **Paluukoodi** | `exit code 0` |
| **Virheet** | `0` virhettä ja kaikki testit läpäisty |
| **Import-vaihe** | `class_name`-välimuisti syntyy vain `--import`-ajolla |
| **Virheskannaus** | Ajonaikainen `SCRIPT ERROR` ei muuta Godotin paluukoodia → wrapper skannaa tulosteen |

### Testikäytännöt

| Käytäntö | Sääntö |
| :--- | :--- |
| **Tiedostot** | `tests/test_<NN>_<nimi>.gd` |
| **Metodit** | `test_*` |
| **Kantaluokka** | `extends "res://tests/test_case.gd"` |
| **Regressio** | **Kaikki aiemmat testit ajetaan joka kerta (regressio)** |
| **Näkymäbudjetit** | Näkymäbudjetteja (draw callit, kolmiot, FPS) ei voi mitata headless-ajossa → view-viipaleissa manuaalinen tarkistus debug-HUDista (`Performance.get_monitor(...)`). |

## 4. Roolit ja testien omistajuus

| Rooli | Vastuu ja rajat |
| :--- | :--- |
| **Arkkitehti** | Kirjoittaa viipalespeksin ja hyväksymistestit (`tests/test_*.gd`) ja tarkistaa diffin. |
| **Rakentaja** | Kirjoittaa koodin, **ei saa muokata hyväksymistestejä** ja raportoi Arkkitehdille, jos testi vaikuttaa virheelliseltä. |
| **Käyttäjä** | Hyväksyy speksin ennen koodia ja demon ennen kuin tila on `done`. |

## 5. Viipaleen koko

| # | Sääntö |
| :--- | :--- |
| 1 | Yksi demottava tulos: `"Nyt voin ___"` |
| 2 | Yksi uusi arkkitehtuurikäsite |
| 3 | Enintään 5 hyväksymistestiä |
| 4 | Speksi ≤ 60 ei-tyhjää riviä |

**Jos jokin raja ylittyy → viipale pilkotaan.**

## 6. Valmiin määritelmä (DoD)

- [ ] `bash tests/run.sh` → exit 0
- [ ] `01-state-schema.md` päivitetty viipaleen deltalla
- [ ] view-viipaleissa manuaalinen budjetti- ja demotarkistus tehty
- [ ] käyttäjä on kokeillut `"Nyt voin ___"` -tuloksen
- [ ] `02-roadmap.md`-tila on `done`
- [ ] git commit `feat(slice-NN): …`

## 7. Pysyvät päätökset (ADR-tiivistelmä)

| Päätös | Miksi | Hylätty vaihtoehto |
| :--- | :--- | :--- |
| `gl_compatibility`-renderöijä | Integroitu GPU ja WSLg-silta, 60 FPS "perunalla" | Forward+/Vulkan (efektit eivät siirry takaisin) |
| Pelaajat veneen paikallisessa koordinaatistossa | Kävely liikkuvalla kannella pysyy sulavana viiveestä huolimatta | Maailmakoordinaatit + fysiikkasynkka |
| Palvelin päättää tilasta (server-authoritative), asiakas lähettää vain syötteitä | Yksi totuuden lähde, ei huijaus- tai desync-ongelmia | P2P-lockstep |
| Headless Core (`RefCounted`) erillään näkymästä | Logiikka testataan ilman grafiikkaa | Logiikka `Node3D`-skripteissä |
| Code-first, vain yksi `.tscn` | UID-viittaukset eivät rikkoudu, agenttiystävällinen | Editorissa rakennetut scenet |
| Matemaattinen veneen liike | Kevyt ja deterministinen verkkosynkka | `RigidBody3D`-fysiikka |
