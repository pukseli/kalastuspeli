# 02 — Roadmap (Viipalekartta)

> *"Sumuvalo-periaate: vain seuraava viipale speksataan tarkasti (`specs/slices/`). Muut ovat tässä yhden rivin tavoitteina. Järjestystä saa muuttaa."*
> **Kehitysfilosofia:** Netcode ensin (`S5`) → uistelun ydinsilmukka ensimmäiseen saaliiseen (`S6–S10`, ⛳ *find the fun* -portti) → kalastuksen syvyys (`S11–S13`) → kaaoskerrokset (`S14–S16`) → ulkoinen testaus ja demoerä (`S17–S20`) → "väriä" (`S21–S22`) → backlog.
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
| S7 | `07-camera-controls` | kääntää kameraa (Field of Vision) vapaasti 360° kannella ja ruorissa, kävellä kamerasuuntaisesti, palauttaa näkymän (`R`) ja vaihtaa ohjausprofiilia (`K`: `arrows_wasd` / `wasd_mouse`) | Client-paikallinen, laite-agnostinen `CameraController` + ohjausprofiili (`src/view/`) | `done` |
| S8 | `08-trolling-lines` | laskea siiman veteen, säätää sen pituutta ja nähdä vieheet ja plaanarit viuhkana veneen perässä | `RodState` (siima, viehe ja `PlanerBoard`) | `done` |
| S9a | `09a-bite-and-reel` | saada tärpin vapaan (lajikohtaiset signaalit, jarru/räikkä, pintahypyt), kelata kalan vapa kädessä veneen viereen ja yrittää nostoa ilman haavia | `FishState` (tärppi, lajit, jarru/räikkä ja kelaus) | `done` |
| S9b | `09b-planer-detach` | kelata plaanarin veneen laidalle irrotuslukkoon ja irrottaa sen pitämällä `E`-näppäintä pohjassa mittarin täyttymiseen asti (yksin tai kaverin auttamana) | Jatkuva pidettävä interaktio (`PlayerInput.interact_held` + `detach_progress`) | `done` |
| S10 | `10-landing-net-and-catch` | poimia keskikannella lojuvan haavin (`E`), pudottaa sen vapaasti kannelle, kauhaista kalan (onnistuminen väsymyksen mukaan) ja nähdä tiimin saalislaskurin ⛳ | Haavi (`HeldItem` `"net"` + vapaa kansisijainti) ja saalisloki | `done` |
| S10c | `10c-catch-summary` | pelata pitkiä uistelusessioita ilman että kasvava saalismäärä hidastaa peliä tai paisuttaa verkkopaketteja | Tiivistetty saalisloki (`catch_count`, `biggest_catch_kg`, `CATCH_LOG_MAX = 20`) | `done` |
| S10d | `10d-lean-client-snapshot` | liittyä peliin clientinä ilman kaksinkertaista snapshotin parsintaa, turhia `to_dict()`-allokaatioita tai aikahyppyjä taaksepäin | Kertaparsittu snapshot (`GameState.new(false)`, `copy_from`, monotoninen `tick`-suodatus) | `done` |
| S10e | `10e-render-decoupling` | pelata 120/144 Hz:n näytöllä ilman 60 Hz:n mikronykimistä ja irrottaa piirto fysiikkatickistä | Render-interpolaatio (`RenderInterpolator` + `_process(delta)`) | `done` |
| S10f | `10f-view-dirty-checks` | ajaa näkymäpäivitystä ilman turhia materiaali-/polkuhakuja ja nähdä siiman pysyvän kiinni taipuvan 3D-vavan kärjessä | Näkymäkerroksen dirty-tarkistus ja visuaalinen 3D-vavan kärkisynkka | `done` |
| S10g | `10g-sim-indexes` | ajaa simulaatiotickiä $O(1)$-telinehaulla ja ilman ruorin `E`-kaappausta tai plaanarin palautusbugia | Simulaation hakemistot (`_holder_index`, `tip_local_position`, `_collect_detaching_rods`) | `done` |
| S11a | `11a-line-physics-and-drag` | hallita siiman kireyttä ja kelan jarrua (`Z`/`X`): jarru luistaa suojaten siimaa, ylikiristys/puolan tyhjeneminen/hankauma katkaisee (`TANGLED`), löysä siima päästää kalan | `LinePhysics` + `RodState`-jännitys/jarru (`PlayerInput.drag_input`) | `done` |
| S11b | `11b-line-visuals-and-rod-bend` | nähdä siiman virtauskaaren (löysä vs. kireä, värinä/varoitusväri), vavan taipuman ja visuaalisen kireys-/jarrumittarin HUDissa | Jännitysreaktiivinen 3D-siimakäyrä ja vavan taipuma (`src/view/`) | `done` |
| S11c | `11c-fish-fatigue` | väsyttää isoja kaloja aktiivisesti oikealla rytmillä ja jarrulla ennen haavitusta | Kalan syvempi väsytysmalli (`stamina`-silmukka) | `draft` |
| S12 | `12-trolling-window-and-tangles` | pitää vauhdin uisteluikkunassa, kokea siimasotkut (pysähdys tai jyrkkä käännös) ja selvittää solmun kannella | Siimasotkutila (uisteluikkuna laukaisimena) | `draft` |
| S13 | `13-rod-threading` | pujottaa tärppivavan ulommaiseksi (`-1 → -3`) kaverin siirtäessä vapoja tieltä; sisäpaikalta kelaaminen sotkee siimat | Siimojen risteämisen tunnistus | `draft` |
| S14 | `14-water-motion-and-lure-physics` | nähdä liikkuvan veden pinnan ja kokea oikean vesifysiikan: paikallaan ollessa uistin ja siima vajoavat syvyyteen (eivät liu'u keinotekoisesti perää kohti) ja veden virtaus kuljettaa plaanaria/siimaa | Vesifysiikka ja veden liike (`WaterCurrent` + 3D-vajoamissyvyys + animoitu vesipinta) | `draft` |
| S14b | `14b-waves-and-buoyancy` | ajaa aallokossa, jossa vene keikkuu ja kallistuu | Deterministinen `WaveField` (4 pisteen kellunta) | `draft` |
| S15 | `15-wind-drift` | kokea tuulen ja sivuvirran, joka ajaa venettä pois kurssilta ilman korjausta | Tuuli ulkoisena voimana `BoatSimulator`issa | `draft` |
| S16 | `16-lake-obstacles` | väistää saaria ja karikoita; törmäys pysäyttää veneen ja sotkee vedessä olevat siimat | `WorldFeatures` (saaret ja karikot törmäyksineen) | `draft` |
| S17 | `17-lobby-ui` | hostata ja liittyä ilman komentoriviä (näyttää paikalliset IP:t) | Aula-UI | `draft` |
| S18 | `18-export` | ajaa pelin kaverin Windows-koneella | Export-putki (presetit ja templatet) | `draft` |
| S19 | `19-demo-round` | pelata aikarajoitetun demoerän ja nähdä tuloksen lopussa | Erätila (eräkello ja tulos) | `draft` |
| S20 | `20-event-director` | kokea rytmitetyt kaaospiikit (tuplatärpit) tyynien jaksojen välissä | `EventDirector` | `draft` |
| S21 | `21-helm-visuals` | nähdä 3D-vauhtisauvan, pyörivän ohjauspyörän ja asento-/nopeusosoittimen pulpetissa | Ruorin 3D-visuaalit (esityskerros) | `draft` |
| S22 | `22-feedback-polish` | erottaa tärpit, kireyden, sotkut ja saaliit viimeistellyistä visuaali- ja äänimerkeistä | Palautekerroksen viimeistely | `draft` |
| — | `xx-solo-pass` | ohittaa telinevavan yksin oikealla yli/ali-asennolla (`Q` / `Shift`) | Vavan yli/ali-asento | `backlog` |
| — | `xx-emergency-rest` | laskea väsytettävän vavan hetkeksi `-3`/`+3`-telineeseen haavin hakua varten | Hätälaskun karkausajastin | `backlog` |
| — | `xx-client-prediction` | ohjata venettä ruorista ilman tuntuvaa syöteviivettä | Client-ennustus ja täsmäytys | `backlog` |
| — | `xx-fish-hotspots` | ajaa karikoiden lähellä oleviin kalaparviin hakemaan isoja saaliita ja tuplatärppejä | Kalaparvet (`WorldFeatures` + `EventDirector`) | `backlog` |
| — | `xx-fishing-orders` | pelata uistelukisaa kilotavoitteilla tai kalatilauksilla | Lajitilaukset ja kisapisteet (eräkello tulee S19:ssä) | `backlog` |
| — | `xx-sonar-station` | käyttää kaikuluotainasemaa kalaparvien ja piilokarikoiden huutamiseen kipparille | Kaikuluotain / kartanlukija (`Station` + `WorldFeatures`) | `backlog` |
| — | `xx-snags-and-upkeep` | selvittää pohjatärpit, roskat vieheessä, moottoriviat ja pilssiveden myrskyssä | Vieheen syvyys/roskat + veneen huoltoasemat | `backlog` |
| — | `xx-dedicated-server` | ajaa palvelimen ilman pelaajaa (`--server`) | Dedicated-tila | `backlog` |
| — | `xx-gamepad-and-keybinds` | pelata peliohjaimella (gamepad) ja muokata näppäinasetuksia valikossa | Semanttinen `InputMap`-asetuskerros ja ohjaintuki | `backlog` |
| — | `xx-planer-drop` | kokea plaanarin putoamisen veteen, jos sen irrottaminen menee täysin pieleen | Plaanarin menetys | `backlog` |

**Tilat:** `draft` = idea, `approved` = speksi hyväksytty, `in-progress` = työn alla, `done` = DoD täyttyy, `backlog` = tarvittaessa.

---

## Speksatut mekaniikat (toteutetaan kohdeviipaleessa)

> Mekaniikkaspeksit: [`boat-physics.md`](02-mechanics/boat-physics.md) (veneen fysiikka), [`trolling-gameplay.md`](02-mechanics/trolling-gameplay.md) (uistelun ydinsilmukka, roolit ja laajennuspisteet; suuntaa antava) ja [`planer-boards.md`](02-mechanics/planer-boards.md) (pikkuplaanarit, sisäkaarre ja karikkohavainnot). Viipalespeksi poimii tarvitsemansa säännöt ja on ristiriidassa sitova. Valmiiden viipaleiden säännöt ovat niiden speksitiedostoissa (`specs/slices/`). Alla vain tiedot, jotka eivät näy taulukosta.

| Kohdeviipale | Mekaniikka | Sovittu sääntö |
| :--- | :--- | :--- |
| **S12** | Uistelukaasu | `BoatSimulator`-kaasukäyrän matala pää ja uisteluikkunan rajat kalibroidaan samassa viipaleessa. |
| **S14** | Vesifysiikka & veden liike | Korvaa paikallaan olevan veneen keinotekoisen `min_stopped_trail_factor`-peräliukumisen uistimen todellisella vajoamisella syvyyteen, veden virtausvektorilla ja liikkuvalla vesipinnalla. |
| **S14b** | Aallokko | `WaveField` (`src/core/`) tarjoaa `get_wave_height(x, z, time)` ja 4 pisteen kellunnan (`y`, `pitch`, `roll`). |
| **S16** | Shokkikuorma | Äkillinen karikkoshokki (`SNAGGED`) kovalla vauhdilla/jarrulla lisätään esteviipaleessa (ks. [`line-physics.md`](02-mechanics/line-physics.md)). |
| **S21** | Ruorin visuaalit | Vauhtisauva seuraa `throttle`-arvoa, ohjauspyörä `steering_angle`-kulmaa. |
| **S22** | Palaute | Vavan taipuma, räikkä-/tärppiääni, kireysväri ja roiskahdus haavituksessa. |
