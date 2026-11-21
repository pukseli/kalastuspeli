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
| **Arkkitehti** | Pääagentti (kalliimpi malli) | Suunnittelee rajapinnat, kirjoittaa *Zero-Exploration*-tehtäväkortit (valmiit polut, sallitut ja kielletyt tiedostot ilman etsintää), lukitsee speksin ja testit SHA-256-tiivisteellä (`lock_slice.sh`) ennen Rakentajan ajoa ja ajaa hyväksyntäportin (`check_slice.sh`) aina itse. |
| **Rakentaja** | `flash`-alagentti | Tuottaa 85–90 % output-tokeneista (`.md`, `.gd`, yksikkötestit) vain sallituissa tiedostoissa, ei tee git-committeja, noudattaa max 3 korjausyrityksen rajaa, ajaa `bash tests/run.sh`, ei muokkaa hyväksymistestejä (§4) ja raportoi tulosteet sellaisenaan. |
| **Apuri** | `flash_lite`-alagentti | Mekaaniset rutiinitehtävät. |
| **Token-Dense Specs** | Kaikki speksit | Kirjoitetaan tiiviinä taulukoina ja tyyppimäärittelyinä pitkän proosan sijaan. |

### Code-First, Kieli- ja Git-sääntö

| Sääntö | Toteutus |
| :--- | :--- |
| **Yksi skenetiedosto** | Vain **yksi** `.tscn`-tiedosto (`src/main.tscn`). Kaikki 3D-primitiivit, materiaalit, valot, kamerat ja UI rakennetaan proseduraalisesti GDScriptillä. |
| **Kieli** | Koodi, luokat, muuttujat ja kommentit **englanniksi**; speksidokumentaatio **suomeksi**. |
| **Git Commit & Push** | **Globaali sääntö:** Jokaisen vaiheen, jokaisen AI-ajon ja jokaisen muutoksen jälkeen tehdään `git commit` ja `git push origin main`. |

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

Jokainen viipale verifioidaan pääagentin ajamana porttiskriptillä (joka ajaa lopuksi `bash tests/run.sh`):

```bash
bash .agents/skills/godot-gatekeeper/scripts/check_slice.sh
```

| Laatukriteeri | Vaatimus |
| :--- | :--- |
| **Viipaleen koko** | Speksi `≤ 60` ei-tyhjää riviä ja viipaletestit `≤ 5` `func test_` -metodia |
| **Yksi skene & Core-raja** | Vain `src/main.tscn`; `src/core/` ilman `Node`/näkymä/verkkoriippuvuuksia |
| **SHA-256 / Testilukko** | Lukitut hyväksymistestit ja speksit (`.agents/slice_lock.sha256`) muuttumattomat |
| **Paluukoodi & Virheet** | `bash tests/run.sh` → `exit code 0`, `0` virhettä (`SCRIPT ERROR` / `ERROR:`) |
| **Import-vaihe** | `class_name`-välimuisti syntyy vain `--import`-ajolla |

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
| **Arkkitehti** | Kirjoittaa viipalespeksin ja hyväksymistestit (`tests/test_*.gd`), lukitsee ne `lock_slice.sh`:lla ennen delegointia, ajaa `check_slice.sh`:n itse ja hyväksyy korkeintaan **1** uusintapyynnön virheen sattuessa ennen muutosten palautusta (`git checkout`) ja omaa korjausta. |
| **Rakentaja** | Muokkaa vain tehtäväkortissa sallittuja tiedostoja, **ei saa muokata lukittuja hyväksymistestejä eikä commitoida**, pysähtyy viimeistään 3 korjausyrityksen jälkeen ja raportoi tulosteet sellaisenaan Arkkitehdille. |
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
- [ ] `git commit` (`feat(slice-NN): …`) ja `git push origin main`

## 7. Pysyvät päätökset (ADR-tiivistelmä)

| Päätös | Miksi | Hylätty vaihtoehto |
| :--- | :--- | :--- |
| `gl_compatibility`-renderöijä | Integroitu GPU ja WSLg-silta, 60 FPS "perunalla" | Forward+/Vulkan (efektit eivät siirry takaisin) |
| Pelaajat veneen paikallisessa koordinaatistossa | Kävely liikkuvalla kannella pysyy sulavana viiveestä huolimatta | Maailmakoordinaatit + fysiikkasynkka |
| Palvelin päättää tilasta (server-authoritative), asiakas lähettää vain syötteitä | Yksi totuuden lähde, ei huijaus- tai desync-ongelmia | P2P-lockstep |
| Headless Core (`RefCounted`) erillään näkymästä | Logiikka testataan ilman grafiikkaa | Logiikka `Node3D`-skripteissä |
| Code-first, vain yksi `.tscn` | UID-viittaukset eivät rikkoudu, agenttiystävällinen | Editorissa rakennetut scenet |
| Matemaattinen veneen liike | Kevyt ja deterministinen verkkosynkka | `RigidBody3D`-fysiikka |
