# 00 — Ympäristö ja Laitteistobudjetti

## 1. Kohdelaitteisto ja "Perunakone"-budjetti (Target Hardware Budget)

| Parametri | Budjetti / Arvo | Huomiot |
| :--- | :--- | :--- |
| **Renderöijä** | `gl_compatibility` (OpenGL 3.3 / ES 3.0) | `rendering/renderer/rendering_method="gl_compatibility"` |
| **Piirtokutsut (Draw Calls)** | `< 100` / ruutu | Yksinkertaiset `StandardMaterial3D`-väripinnat |
| **Kolmiomäärä (Triangles)** | `< 20 000` | Low-poly-primitiivit (`radial_segments = 12`, `rings = 4`) |
| **Valaistus** | Max `1` `DirectionalLight3D` | Ei SSAO, ei SSR, ei SDFGI, ei volumetrista sumua |
| **Fysiikka** | Matemaattinen 2D/3D-rajoitus (`BoatSimulator`) | Ei raskasta `RigidBody3D`-fysiikkaverkkosynkronointia |
| **Muistibudjetti** | `< 250 MB` RAM/VRAM / instanssi | 4 samanaikaista ikkunaa `< 1 GB` kokonaismuistilla |
| **Testi-ikkuna** | `960 × 540` (qHD, skaalautuva) | 4 ikkunaa mahtuu 2×2-ruudukkoon |
| **Tavoite-FPS** | `60 FPS` | Integroidulla näytönohjaimella |

## 2. Kehitys- ja Ajoympäristö (Tämä kone)

| Komponentti | Konfiguraatio / Arvo |
| :--- | :--- |
| **CPU** | AMD Ryzen AI 7 350 (8 ydintä / 16 säiettä) |
| **GPU** | Integroitu AMD Radeon 860M (jaettu muisti) |
| **RAM** | 15 GiB (WSL2) / 4 GiB Swap |
| **OS / Alusta** | Ubuntu 26.04 LTS (WSL2, Linux `6.18-microsoft-standard`) + Windows-isäntäyhteensopivuus |
| **Grafiikkasilta** | WSLg (`/dev/dxg`) + Mesa `d3d12_dri.so` (DirectX 12 -silta), varalla `swrast_dri.so` |
| **Ikkunointi** | X11 / Wayland (`libgl1`, `libfontconfig1`, `libxcursor1`, `libxi6`, `libxinerama1`, `libxrandr2` valmiina) |
| **Ääni (MVP)** | Ei `libpulse0` / `libasound2` WSL2-imagessa -> ajetaan vivulla `--audio-driver Dummy` |
| **Moottori & CLI** | Godot `4.3-stable` (Standard GDScript, Linux `x86_64`, `~/.local/bin/godot`) |

## 3. Fyysinen Verkkoympäristö (Testiverkko vs. Tuotanto)

| Tilanne | Topologia / Osoitteet | Sääntö ja Vaatimukset |
| :--- | :--- | :--- |
| **Yhden koneen testi** | Loopback `127.0.0.1:7777` | 2–4 ikkunaa samalla koneella; toimii aina ilman NAT-konfigurointia. |
| **Kotiverkon Aliverkko 1 (Pääreititin)** | Pöytäkone (Ethernet seinässä) + Mesh-tukiaseman WAN | Pöytäkone toimii **Hostina** (tai Dedicated Serverinä). |
| **Kotiverkon Aliverkko 2 (Mesh WLAN NAT)** | `192.168.68.0/24` — Läppäri `192.168.68.113`, GW `192.168.68.1` | Läppäri yhdistää (**Join**) suoraan pöytäkoneen IP-osoitteeseen ulospäin Mesh-NATin läpi. |
| **Kotiverkon Aliverkko 3 (WSL2 sisäinen NAT)** | `172.27.192.0/20` — WSL2 Linux `172.27.200.168`, GW `172.27.192.1` | Double NAT: ei riippuvuutta LAN UDP Broadcastista eri aliverkkojen välillä -> vaatii Direct IP Joinin ja Hostin paikallisten IP-osoitteiden näyttämisen. |
| **WSL2 Hostina** | WSL2 NAT `172.27.x` | Saapuva UDP ei pääse WSL2:n NATin läpi (`netsh portproxy` ei tue UDP:tä). Ratkaisu: WSL:n `networkingMode=mirrored` (`.wslconfig`) **tai** Host ajetaan Windows-buildina. WSL2 **Clientina** toimii ilman muutoksia. |
| **Windowsin palomuuri** | Host-kone (pöytäkone / läppäri) | Salli saapuva **UDP 7777** Godot- tai pelibinäärille. |
| **Tuotantoverkko (Julkaisu)** | Pelaajat kotireitittimien ja NAT-palomuurien takana | Vaatii NAT-läpäisevän siirtotien (Steam P2P Relay / WebRTC) tai pilvessä ajettavan Dedicated Headless Serverin. |

## 4. Avoimet asiat

| Asia | Tila / Suunnitelma |
| :--- | :--- |
| **Export ja jakelu pöytäkoneelle** | Windows-export presetit + export templatet 4.3 → roadmap `xx-export` |
