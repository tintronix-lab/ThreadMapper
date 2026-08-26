# Ställa in en ThreadMapper-sond på en Raspberry Pi

Steg för steg, från ett tomt skrivbord till uppmätta Thread-data i appen.

Räkna med en kväll. Det mesta är väntan på nedladdningar och ett bygge på cirka 20 minuter.

---

## Läs det här innan du köper något

Två saker avgör om det här är värt att göra för *din* uppsättning. Båda är lätta att missa tills delarna ligger på bordet.

### 1. En Raspberry Pi klarar inte Thread på egen hand

Det finns ingen 802.15.4-radio i en Raspberry Pi. Wi-Fi och Bluetooth är andra radiosystem och kan inte tala Thread. **Du behöver en USB-dongel**, och den behöver RCP-firmware — vilket inte är vad de här donglarna levereras med.

### 2. Att gå med i *ditt* Thread-nätverk är den svåra biten

En gränsrouter som bildar sitt eget nya nätverk kommer bara att sitta där och se ingenting annat än sig själv. Dina verkliga enheter finns på det nätverk som din HomePod, Apple TV eller Nest-hubb skapade, och för att kunna observera dem måste sonden **gå med i det nätverket** — vilket innebär att få tag på dess autentiseringsuppgifter (Active Operational Dataset).

| Din uppsättning | Kan sonden gå med i ditt riktiga nätverk? |
|---|---|
| Du kör **Home Assistant** | **Ja.** HA:s iOS Companion-app kan hämta Apples Thread-autentiseringsuppgifter — *Settings → Devices & services → Thread → Configure → Send credentials to Home Assistant* — och därifrån kan du lämna över datasetet till sonden. |
| Du kör redan en **OTBR** (t.ex. HA:s tillägg) | **Ja.** Läs av datasetet direkt från den. |
| **Enbart gränsroutrar från Apple eller Google**, ingen Home Assistant | **Inte idag.** Det finns inget sätt för användare att exportera Apples Thread-autentiseringsuppgifter. Du kan fortfarande bilda ett *nytt* nätverk på sonden och driftsätta några tillbehör i det för att se appen fungera hela vägen, men det visar dig inte ditt befintliga mesh-nät. |

Den tredje raden är en verklig vägg, och inte en som det här projektet kan riva utifrån: den sanktionerade vägen är Apples rättighet `com.apple.developer.thread-network-credentials`, som ThreadMapper har ansökt om men inte har. Om den beviljas kan appen lämna över dina autentiseringsuppgifter direkt till sonden och hela det här avsnittet försvinner.

**Hamnar du på den tredje raden och bara vill övervaka ditt befintliga Apple-mesh-nät, bör du överväga att stanna här tills den rättigheten är på plats.**

---

## Inköpslista

| Artikel | Kommentar |
|---|---|
| Raspberry Pi 4 eller 5 | 2 GB RAM räcker gott. En Pi Zero 2 W fungerar, men bygget i steg 4 tar mycket längre tid. |
| microSD-kort, 16 GB+ | Vilket välrenommerat märke som helst. |
| USB-C-nätaggregat | Det officiella; Thread-donglar är känsliga för spänningsfall. |
| **En 802.15.4-dongel** | Välj en — se nedan. |

**Dongelalternativ**, båda fungerar:

- **Nordic nRF52840-dongel** (~10 dollar) — billigast, och firmware byggs från källkod så du slipper leta efter en nedladdning.
- **SkyConnect / Sonoff ZBDongle-E** (~25 dollar) — Silicon Labs. Har du redan en för Home Assistant, använd den. Flashningen sköts av ett verktyg med ett enda kommando.

---

## Steg 1 — Lägg RCP-firmware på dongeln

Gör det här **innan** du rör din Pi, på din Mac eller PC. Det är det enda steget som installationsprogrammet medvetet inte automatiserar: att flasha fel avbild förstör dongeln, och tillverkarnas egna verktyg gör det ordentligt.

RCP-firmware (”Radio Co-Processor”) gör dongeln till en dum radio som `otbr-agent` styr. En dongel som levererats för Zigbee har annan firmware och fungerar inte förrän den flashas om.

### Silicon Labs (SkyConnect, Sonoff ZBDongle-E)

```bash
pipx install universal-silabs-flasher     # or: pip install universal-silabs-flasher
universal-silabs-flasher --device /dev/tty.usbserial-XXXX probe
universal-silabs-flasher --device /dev/tty.usbserial-XXXX flash --firmware <ot-rcp-firmware.gbl>
```

Hämta `.gbl`-filen för `ot-rcp` från releaserna av Home Assistants silabs-firmware — samma avbilder som OTBR-tillägget använder. Matcha filen mot din exakta dongelmodell; SkyConnect och ZBDongle-E är **inte** utbytbara.

### Nordic nRF52840

Bygg firmware från OpenThreads Nordic-port och flasha sedan över USB DFU:

```bash
git clone --recurse-submodules https://github.com/openthread/ot-nrf528xx.git
cd ot-nrf528xx && ./script/bootstrap && ./script/build nrf52840 USB_trans
# → build/bin/ot-rcp  (convert to .hex/.zip per the repo's README, then:)
nrfutil dfu usb-serial -pkg ot-rcp.zip -p /dev/tty.usbmodemXXXX
```

Följ README i det repot för det aktuella paketeringssteget — det ändras då och då och är bättre att läsa där än att kopiera hit.

**Kontrollera att det gick vägen:** sätt i dongeln i din Pi längre fram, så rapporterar `install.sh` `Found <family> radio at /dev/serial/by-id/...`. Hittar den ingenting, gick flashningen inte igenom.

---

## Steg 2 — Flasha Raspberry Pi OS

1. Installera **Raspberry Pi Imager**.
2. Välj **Raspberry Pi OS Lite (64-bit)**. Lite — det behövs inget skrivbord.
3. Klicka på knappen **kugghjul / Edit Settings** *innan* du skriver, och ställ in:
   - värdnamn: `threadmapper-probe`
   - **Enable SSH**, med lösenord eller nyckel
   - användarnamn och lösenord
   - Wi-Fi-uppgifter, om du inte använder Ethernet
4. Skriv kortet, sätt i det i din Pi, anslut dongeln och slå på strömmen.

Ethernet är mer tillförlitligt än Wi-Fi här, och en gränsrouter mår bra av en stabil upplänk. Använd det om du kan.

---

## Steg 3 — Logga in

```bash
ssh <your-username>@threadmapper-probe.local
```

Om värdnamnet inte går att slå upp, leta rätt på din Pis IP-adress i routerns klientlista och kör `ssh <user>@<ip>` i stället.

Bekräfta att dongeln syns innan du går vidare:

```bash
ls -l /dev/serial/by-id/
```

Du bör se en post som namnger din dongel. **Är listan tom, stanna** — resten kommer inte att fungera. Sätt i den på nytt, prova en annan USB-port och gå igenom steg 1 igen.

---

## Steg 4 — Installera sonden

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/tintronix-lab/ThreadMapper.git
sudo ./ThreadMapper/tools/pi-image/install.sh
```

Det identifierar dongeln, installerar `otbr-agent` och sondagenten och aktiverar båda som systemd-tjänster.

**Det här tar ~20 minuter på en Pi 4**, nästan allt av det kompilering av `otbr-agent`. Installationen har inte hängt sig. När den är klar skriver den ut sondens adress.

Om identifieringen misslyckas men du känner till enhetssökvägen:

```bash
sudo ./ThreadMapper/tools/pi-image/install.sh --radio-url spinel+hdlc+uart:///dev/ttyACM0
```

Det är säkert att köra om — skriptet är idempotent, och det är så du uppgraderar agenten längre fram.

---

## Steg 5 — Kom in på ett Thread-nätverk

Välj den rad som stämde in på dig i ”Läs det här innan du köper något”.

### Väg A — Gå med i ditt befintliga nätverk (det du egentligen vill)

Hämta Active Operational Dataset som en hexsträng från det som redan har dina autentiseringsuppgifter.

Från en befintlig OTBR (inklusive Home Assistants tillägg):

```bash
curl -s http://<existing-otbr>:8081/node/dataset/active \
     -H 'Accept: text/plain'
```

Det ger tillbaka en enda lång hexsträng. På din Pi:

```bash
sudo ot-ctl dataset set active <that-long-hex-string>
sudo ot-ctl ifconfig up
sudo ot-ctl thread start
```

Vänta ~30 sekunder och kör sedan:

```bash
sudo ot-ctl state
```

Förvänta dig `child` eller `router` — då gick den med. `leader` här skulle betyda att den bildade ett eget nätverk i stället, vilket inte är vad du vill på den här vägen.

### Väg B — Bilda ett nytt nätverk (för test, eller när du inte kommer åt några autentiseringsuppgifter)

```bash
sudo ot-ctl dataset init new
sudo ot-ctl dataset commit active
sudo ot-ctl ifconfig up
sudo ot-ctl thread start
sudo ot-ctl state          # expect: leader
```

Nu har du ett tomt nätverk med en enda nod. För att se något intressant måste du driftsätta tillbehör i det — vilket innebär att du först måste ta bort dem från ditt Apple-nätverk. **Gör inte det här med enheter du är beroende av.**

Skriv ut datasetet om du vill ansluta annat till det senare:

```bash
sudo ot-ctl dataset active -x
```

---

## Steg 6 — Rikta appen mot den

```bash
curl http://localhost:8099/health
```

Förvänta dig `"otCtlReachable": true` och ett `role`. Sedan, från din telefon på samma nätverk, i **ThreadMapper → Inställningar → ThreadMapper-sond**:

```
http://threadmapper-probe.local:8099
```

Använd din Pis IP-adress i stället om `.local` inte går att slå upp på iOS. Tryck på **Testa anslutning** — den namnger felet om något är fel i stället för att bara visa ett rött kryss.

---

## Steg 7 — Se vad du fick

- **Instrumentpanel → ⋯ → Thread-nätverk** — uppmätt RSSI per nod, länkkvalitet och routingtabellen med vägkostnad och nästa hopp. Noder visas med sin Thread-adress, inte med namn; se ”Det här fungerar inte än” nedan.
- **Mesh → verktyg → Kanalskanner** — nu märkt **Uppmätt**. Stapelhöjden är den verkliga brusnivån över alla 16 kanaler, och de rekommenderade kanalerna är de tystaste som faktiskt observerats snarare än en gissning ur en tabell över Wi-Fi-överlapp.

Kanalskannern är den du ska titta på först. Den är den tydligaste skillnaden mellan vad appen kunde visa förut och vad den kan visa nu.

---

## Felsökning

| Symtom | Orsak och åtgärd |
|---|---|
| `install.sh` säger ”No 802.15.4 dongle detected” | Dongeln saknas, eller så gick steg 1 inte igenom. Kontrollera med `ls /dev/serial/by-id/`. |
| Testa anslutning: *”den når inte gränsroutern bredvid”* | Agenten är igång men inte `otbr-agent`. Kör `sudo systemctl status otbr-agent` och sedan `journalctl -u otbr-agent -n 50`. Oftast en felaktig radio-URL eller en dongel som tappat strömmen. |
| Testa anslutning: *”det är inte en ThreadMapper-sondagent”* | Något annat svarar på den porten. Agenten är 8099; 8081 är gränsrouterns eget REST-API. |
| Testa anslutning: *”kunde inte nå adressen”* | Fel IP-adress, eller så är telefonen på ett annat subnät eller ett gäst-VLAN. |
| `ot-ctl state` säger `detached` | Den har autentiseringsuppgifter men hittar inte nätverket. Fel dataset, eller utom radioräckhåll för alla andra noder. |
| `ot-ctl state` säger `disabled` | `ifconfig up` / `thread start` kördes inte, eller så kom radion inte igång. |
| Skärmen Thread-nätverk visar inga andra noder | Sonden är på ett eget nätverk — kontrollera att den inte är `leader` när du menade att gå med i ett. |
| Allt fungerar, men dör efter en omstart | `systemctl is-enabled otbr-agent threadmapper-probe` — båda ska säga `enabled`. |

Loggar för båda tjänsterna tillsammans:

```bash
journalctl -u threadmapper-probe -u otbr-agent -f
```

---

## Det här fungerar inte än

**Noder visas utan namn.** Thread identifierar en nod med dess utökade adress; HomeKit identifierar ett tillbehör med en ogenomskinlig identifierare, och ingenting kopplar ihop de två. Du får alltså se en verklig, korrekt topologi av anonyma noder i stället för ”kökslampan”.

Lösningen är byggd men inte färdig: agentens slutpunkt `/traffic` rapporterar aktivitet per nod, så att styra en enhet via HomeKit och se vilken nod som svarar skulle koppla ihop dem. Den funktionen behöver riktiga tillbehör på ett riktigt mesh-nät att utvecklas mot, vilket är precis vad du kommer att ha när det här väl är igång. Följs som **H1** i `WORKPLAN.md`.

**Fliken Mesh är fortfarande härledd.** Dess graf byggs från HomeKit-tillbehör, så den kan inte använda sonddata förrän det ovanstående är löst. Det är skärmen Thread-nätverk och Kanalskannern som visar mätvärden.

---

## Om något här är fel

Den här guiden har inte gåtts igenom hela vägen på riktig hårdvara — ingen i projektet har en Pi eller en dongel än. Provisioneringsskriptet är testat mot Debian Bookworm arm64, och varje slutpunkt i agenten är testad mot en riktig `otbr-agent` på en simulerad radio, men de fysiska stegen ovan är skrivna utifrån tillverkarnas dokumentation snarare än utifrån att någon gjort dem.

Om ett steg är fel är det värt att rätta i den här filen.
