# 02 — Roadmap (Viipalekartta)

> *"Sumuvalo-periaate: vain seuraava viipale speksataan tarkasti (`specs/slices/`). Muut ovat tässä yhden rivin tavoitteina. Järjestystä saa muuttaa."*
> **Kehitysfilosofia:** Netcode ensin (`S5`) → uistelun ydinsilmukka ensimmäiseen saaliiseen (`S6–S9`, ⛳ *find the fun* -portti) → kalastuksen syvyys (`S10–S12`) → kaaoskerrokset (`S13–S15`) → ulkoinen testaus ja demoerä (`S16–S19`) → "väriä" (`S20–S21`) → backlog.
> **Viipalesääntö:** "Uusi käsite" -sarakkeessa on täsmälleen yksi käsite. Jokaisen pelimekaniikkaviipaleen DoD sisältää minimipalautteen (HUD/debug), jolla mekaniikka on pelattavissa ilman viimeisteltyä grafiikkaa.

| # | Viipale (tiedosto) | "Nyt voin ___" | Uusi käsite | Tila |
| :--- | :--- | :--- | :--- | :--- |
| S0 | Ympäristö ja perusta | ajaa headless-testiportin | Testiportti | `done` |
| S1 | `01-boat-on-water` | ajaa venettä järvellä yhdessä ikkunassa | Core + 3D-näkymän runko | `done` |
| S2 | `02-two-windows-one-boat` | nähdä saman veneen kahdessa ikkunassa (`--host` / `--join` / `--port` / `--sync-hz`, `T`-tickrate) | Verkkosynkka (vain `BoatState`) | `done` |
| S3 | `03-crew-on-deck` | kävellä 3D-hahmolla kannella matalammasta kamerakulmasta (`-28°`), nähdä toiset ikkunat ja säätää testipelaajia (`B` / `--bots`) | Paikallinen kansikoordinaatisto verkon yli | `done` |
| S4 | `04-stations` | kävellä toimintopaikan äärelle, tarttua ruoriin (`E`), kokea ohjaamonäkymä ja säätää säilyvää kaasua/kääntöä keskinapsahduksilla | Yleinen `Station`-järjestelmä (`StationConfig.STATIONS`, `GameState.stations`), ohjaamonäkymä ja keskinapsahdus | `done` |
| S5 | `05-smooth-sync` | nähdä veneen ja toisten pelaajien liikkuvan ilman nykimistä 100 ms viiveellä | Snapshot-interpolointi (viivesimulaatio testityökaluna) | `done` |
| S6 | `06-held-items` | poimia vavan telineestä käteen, kävellä sen kanssa kannella ja asettaa sen toiseen telineeseen (2 perässä, 2+2 kyljillä: `-3..-1`, `+1..+3`) | Kannettava esine (`HeldItem`) | `done` |
| S7 | `07-trolling-lines` | laskea siiman veteen, säätää sen pituutta ja nähdä vieheet viuhkana veneen perässä | `RodState` (siima ja viehe) | `draft` |
| S8 | `08-bite-and-reel` | saada tärpin vapaan ja kelata kalan ulkolaidalta (`-3`/`+3`) veneen viereen | `FishState` (tärppi ja kelaus) | `draft` |
| S9 | `09-landing-net-and-catch` | hakea haavin telineestä, kauhaista kalan ja kipata sen sumppuun, jolloin saalislaskuri kasvaa ⛳ | Haavitus (haavi → sumppu → saalislaskuri) | `draft` |
| S10 | `10-line-tension` | hallita siiman kireyttä kalan syöksyissä: ylikelaus katkaisee siiman, löysä siima päästää kalan | Siiman kireys (`tension`) | `draft` |
| S11 | `11-trolling-window-and-tangles` | pitää vauhdin uisteluikkunassa, kokea siimasotkut (pysähdys tai jyrkkä käännös) ja selvittää solmun kannella | Siimasotkutila (uisteluikkuna laukaisimena) | `draft` |
| S12 | `12-rod-threading` | pujottaa tärppivavan ulommaiseksi (`-1 → -3`) kaverin siirtäessä vapoja tieltä; sisäpaikalta kelaaminen sotkee siimat | Siimojen risteämisen tunnistus | `draft` |
| S13 | `13-waves-and-buoyancy` | ajaa aallokossa, jossa vene keikkuu ja kallistuu | Deterministinen `WaveField` (4 pisteen kellunta) | `draft` |
| S14 | `14-wind-drift` | kokea tuulen ja sivuvirran, joka ajaa venettä pois kurssilta ilman korjausta | Tuuli ulkoisena voimana `BoatSimulator`issa | `draft` |
| S15 | `15-lake-obstacles` | väistää saaria ja karikoita; törmäys pysäyttää veneen ja sotkee vedessä olevat siimat | `WorldFeatures` (saaret ja karikot törmäyksineen) | `draft` |
| S16 | `16-lobby-ui` | hostata ja liittyä ilman komentoriviä (näyttää paikalliset IP:t) | Aula-UI | `draft` |
| S17 | `17-export` | ajaa pelin kaverin Windows-koneella | Export-putki (presetit ja templatet) | `draft` |
| S18 | `18-demo-round` | pelata aikarajoitetun demoerän ja nähdä tuloksen lopussa | Erätila (eräkello ja tulos) | `draft` |
| S19 | `19-event-director` | kokea rytmitetyt kaaospiikit (tuplatärpit) tyynien jaksojen välissä | `EventDirector` | `draft` |
| S20 | `20-helm-visuals` | nähdä 3D-vauhtisauvan, pyörivän ohjauspyörän ja asento-/nopeusosoittimen pulpetissa | Ruorin 3D-visuaalit (esityskerros) | `draft` |
| S21 | `21-feedback-polish` | erottaa tärpit, kireyden, sotkut ja saaliit viimeistellyistä visuaali- ja äänimerkeistä | Palautekerroksen viimeistely | `draft` |
| — | `xx-solo-pass` | ohittaa telinevavan yksin oikealla yli/ali-asennolla (`Q` / `Shift`) | Vavan yli/ali-asento | `backlog` |
| — | `xx-emergency-rest` | laskea väsytettävän vavan hetkeksi `-3`/`+3`-telineeseen haavin hakua varten | Hätälaskun karkausajastin | `backlog` |
| — | `xx-client-prediction` | ohjata venettä ruorista ilman tuntuvaa syöteviivettä | Client-ennustus ja täsmäytys | `backlog` |
| — | `xx-fish-hotspots` | ajaa karikoiden lähellä oleviin kalaparviin hakemaan isoja saaliita ja tuplatärppejä | Kalaparvet (`WorldFeatures` + `EventDirector`) | `backlog` |
| — | `xx-fishing-orders` | pelata uistelukisaa kilotavoitteilla tai kalatilauksilla | Lajitilaukset ja kisapisteet (eräkello tulee S18:ssa) | `backlog` |
| — | `xx-sonar-station` | käyttää kaikuluotainasemaa kalaparvien ja piilokarikoiden huutamiseen kipparille | Kaikuluotain / kartanlukija (`Station` + `WorldFeatures`) | `backlog` |
| — | `xx-snags-and-upkeep` | selvittää pohjatärpit, roskat vieheessä, moottoriviat ja pilssiveden myrskyssä | Vieheen syvyys/roskat + veneen huoltoasemat | `backlog` |
| — | `xx-dedicated-server` | ajaa palvelimen ilman pelaajaa (`--server`) | Dedicated-tila | `backlog` |

**Tilat:** `draft` = idea, `approved` = speksi hyväksytty, `in-progress` = työn alla, `done` = DoD täyttyy, `backlog` = tarvittaessa.

---

## Speksatut mekaniikat (toteutetaan kohdeviipaleessa)

> Mekaniikkaspeksit: [`boat-physics.md`](02-mechanics/boat-physics.md) (veneen fysiikka) ja [`trolling-gameplay.md`](02-mechanics/trolling-gameplay.md) (uistelun ydinsilmukka, roolit ja laajennuspisteet; suuntaa antava). Viipalespeksi poimii tarvitsemansa säännöt ja on ristiriidassa sitova. Valmiiden viipaleiden säännöt ovat niiden speksitiedostoissa (`specs/slices/`). Alla vain tiedot, jotka eivät näy taulukosta.

| Kohdeviipale | Mekaniikka | Sovittu sääntö |
| :--- | :--- | :--- |
| **S11** | Uistelukaasu | `BoatSimulator`-kaasukäyrän matala pää ja uisteluikkunan rajat kalibroidaan samassa viipaleessa. |
| **S13** | Aallokko | `WaveField` (`src/core/`) tarjoaa `get_wave_height(x, z, time)` ja 4 pisteen kellunnan (`y`, `pitch`, `roll`). |
| **S20** | Ruorin visuaalit | Vauhtisauva seuraa `throttle`-arvoa, ohjauspyörä `steering_angle`-kulmaa. |
| **S21** | Palaute | Vavan taipuma, räikkä-/tärppiääni, kireysväri ja roiskahdus haavituksessa. |
