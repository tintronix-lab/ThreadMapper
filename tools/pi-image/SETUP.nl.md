# Een ThreadMapper-probe opzetten op een Raspberry Pi

Stap voor stap, van een leeg bureau tot gemeten Thread-gegevens in de app.

Reken op een avond. Het grootste deel daarvan is wachten op downloads en op één build van ongeveer 20 minuten.

---

## Lees dit voordat je iets koopt

Twee dingen bepalen of dit de moeite waard is voor *jouw* opstelling. Beide zie je makkelijk over het hoofd tot de onderdelen binnen zijn.

### 1. Een Raspberry Pi kan zelf geen Thread

Een Raspberry Pi heeft geen 802.15.4-radio. Wifi en Bluetooth zijn andere radio’s en spreken geen Thread. **Je hebt een USB-dongle nodig**, en daar moet RCP-firmware op staan — en dat is niet wat er standaard op zit.

### 2. Aansluiten op *jouw* Thread-netwerk is het lastige deel

Een border router die zijn eigen nieuwe netwerk vormt, ziet daar niets anders dan zichzelf. Je echte apparaten zitten op het netwerk dat je HomePod, Apple TV of Nest hub heeft aangemaakt, en om ze te kunnen zien moet de probe **zich bij dat netwerk aansluiten** — en daarvoor heb je de netwerkgegevens nodig (de Active Operational Dataset).

| Jouw opstelling | Kan de probe zich bij je echte netwerk aansluiten? |
|---|---|
| Je draait **Home Assistant** | **Ja.** De iOS Companion-app van HA kan de Thread-netwerkgegevens van Apple ophalen — *Settings → Devices & services → Thread → Configure → Send credentials to Home Assistant* — en van daaruit geef je de dataset door aan de probe. |
| Je draait al een **OTBR** (bijv. de add-on van HA) | **Ja.** Lees de dataset daar rechtstreeks uit. |
| **Alleen border routers van Apple of Google**, geen Home Assistant | **Nu nog niet.** Er is geen weg via de gebruikersinterface om de Thread-netwerkgegevens van Apple te exporteren. Je kunt op de probe wel een *nieuw* netwerk vormen en er een paar accessoires op aanmelden om de app van begin tot eind te zien werken, maar je bestaande mesh laat het je niet zien. |

Die derde rij is een echte muur, en niet een die dit project van buitenaf kan omvertrekken: de officiële weg is Apples entitlement `com.apple.developer.thread-network-credentials`, die ThreadMapper heeft aangevraagd maar niet bezit. Komt die er, dan kan de app je netwerkgegevens rechtstreeks aan de probe doorgeven en verdwijnt dit hele onderdeel.

**Val je in de derde rij en wil je alleen je bestaande Apple-mesh in de gaten houden, overweeg dan om hier te stoppen tot dat entitlement er is.**

---

## Boodschappenlijst

| Onderdeel | Opmerkingen |
|---|---|
| Raspberry Pi 4 of 5 | 2 GB RAM is ruim voldoende. Een Pi Zero 2 W werkt ook, maar de build in stap 4 duurt dan veel langer. |
| microSD-kaart, 16 GB+ | Elk degelijk merk. |
| USB-C-voeding | De officiële; Thread-dongles zijn kieskeurig als de spanning wegzakt. |
| **Een 802.15.4-dongle** | Kies er een — zie hieronder. |

**Dongle-opties**, allebei prima:

- **Nordic nRF52840-dongle** (~$10) — de goedkoopste, en de firmware wordt uit de broncode gebouwd, dus je hoeft geen download te zoeken.
- **SkyConnect / Sonoff ZBDongle-E** (~$25) — Silicon Labs. Heb je er al een voor Home Assistant, gebruik die dan. Flashen gaat met één regel.

---

## Stap 1 — Zet RCP-firmware op de dongle

Doe dit **voordat** je de Pi aanraakt, op je Mac of pc. Het is de enige stap die het installatiescript bewust niet automatiseert: het verkeerde image flashen maakt de dongle onbruikbaar, en de tools van de fabrikant doen het goed.

RCP-firmware (‘Radio Co-Processor’) maakt van de dongle een domme radio die door `otbr-agent` wordt aangestuurd. Een dongle die voor Zigbee is geleverd, heeft andere firmware en werkt pas na opnieuw flashen.

### Silicon Labs (SkyConnect, Sonoff ZBDongle-E)

```bash
pipx install universal-silabs-flasher     # or: pip install universal-silabs-flasher
universal-silabs-flasher --device /dev/tty.usbserial-XXXX probe
universal-silabs-flasher --device /dev/tty.usbserial-XXXX flash --firmware <ot-rcp-firmware.gbl>
```

Haal de `ot-rcp`-`.gbl` uit de silabs-firmwarereleases van Home Assistant — dezelfde images die de OTBR-add-on gebruikt. Zoek het bestand dat bij precies jouw donglemodel hoort; SkyConnect en ZBDongle-E zijn **niet** uitwisselbaar.

### Nordic nRF52840

Bouw de firmware uit de Nordic-port van OpenThread en flash die vervolgens via USB DFU:

```bash
git clone --recurse-submodules https://github.com/openthread/ot-nrf528xx.git
cd ot-nrf528xx && ./script/bootstrap && ./script/build nrf52840 USB_trans
# → build/bin/ot-rcp  (convert to .hex/.zip per the repo's README, then:)
nrfutil dfu usb-serial -pkg ot-rcp.zip -p /dev/tty.usbmodemXXXX
```

Volg de README van die repository voor de actuele verpakkingsstap — die verandert af en toe en kun je beter daar lezen dan hier gekopieerd.

**Controleer of het gelukt is:** steek de dongle straks in de Pi en `install.sh` meldt `Found <family> radio at /dev/serial/by-id/...`. Vindt het script niets, dan is de firmware er niet op gekomen.

---

## Stap 2 — Raspberry Pi OS flashen

1. Installeer **Raspberry Pi Imager**.
2. Kies **Raspberry Pi OS Lite (64-bit)**. Lite — een bureaublad heb je hier niet nodig.
3. Klik op de knop **tandwiel / Edit Settings** *voordat* je schrijft, en stel in:
   - hostnaam: `threadmapper-probe`
   - **Enable SSH**, met wachtwoord of sleutel
   - gebruikersnaam en wachtwoord
   - wifigegevens, als je geen ethernet gebruikt
4. Schrijf de kaart, doe hem in de Pi, sluit de dongle aan en zet hem aan.

Ethernet is hier betrouwbaarder dan wifi, en een border router heeft baat bij een stabiele uplink. Gebruik het als het kan.

---

## Stap 3 — Inloggen

```bash
ssh <your-username>@threadmapper-probe.local
```

Lost de hostnaam niet op, zoek dan het IP-adres van de Pi in de clientlijst van je router en gebruik `ssh <user>@<ip>`.

Controleer dat de dongle zichtbaar is voordat je verdergaat:

```bash
ls -l /dev/serial/by-id/
```

Je hoort één regel te zien met de naam van je dongle. **Is dit leeg, stop dan** — de rest werkt niet. Steek hem opnieuw in, probeer een andere USB-poort en loop stap 1 nog eens na.

---

## Stap 4 — De probe installeren

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/tintronix-lab/ThreadMapper.git
sudo ./ThreadMapper/tools/pi-image/install.sh
```

Het script detecteert de dongle, installeert `otbr-agent` en de probe-agent, en schakelt beide in als systemd-services.

**Op een Pi 4 duurt dit ongeveer 20 minuten**, waarvan bijna alles opgaat aan het compileren van `otbr-agent`. Het hangt niet. Als het klaar is, drukt het script het adres van de probe af.

Lukt de detectie niet, maar ken je het apparaatpad wel:

```bash
sudo ./ThreadMapper/tools/pi-image/install.sh --radio-url spinel+hdlc+uart:///dev/ttyACM0
```

Opnieuw draaien is veilig — het script is idempotent, en zo werk je de agent later bij.

---

## Stap 5 — Op een Thread-netwerk komen

Kies de rij die bij jou paste onder ‘Lees dit voordat je iets koopt’.

### Route A — Aansluiten op je bestaande netwerk (wat je eigenlijk wilt)

Haal de Active Operational Dataset als hexstring op uit wat je netwerkgegevens al bevat.

Vanaf een bestaande OTBR (ook de add-on van Home Assistant):

```bash
curl -s http://<existing-otbr>:8081/node/dataset/active \
     -H 'Accept: text/plain'
```

Dat levert één lange hexstring op. Op de Pi:

```bash
sudo ot-ctl dataset set active <that-long-hex-string>
sudo ot-ctl ifconfig up
sudo ot-ctl thread start
```

Wacht ongeveer 30 seconden en dan:

```bash
sudo ot-ctl state
```

Verwacht `child` of `router` — dan is hij aangesloten. `leader` zou hier betekenen dat hij juist zijn eigen netwerk heeft gevormd, en dat is niet wat je op deze route wilt.

### Route B — Een nieuw netwerk vormen (om te testen, of als je niet aan de netwerkgegevens komt)

```bash
sudo ot-ctl dataset init new
sudo ot-ctl dataset commit active
sudo ot-ctl ifconfig up
sudo ot-ctl thread start
sudo ot-ctl state          # expect: leader
```

Je hebt nu een leeg netwerk met één knooppunt. Om iets interessants te zien moet je er accessoires op aanmelden — en die moet je eerst uit je Apple-netwerk verwijderen. **Doe dit niet met apparaten waarop je vertrouwt.**

Druk de dataset af als je er later andere dingen op wilt aansluiten:

```bash
sudo ot-ctl dataset active -x
```

---

## Stap 6 — De app erop richten

```bash
curl http://localhost:8099/health
```

Verwacht `"otCtlReachable": true` en een `role`. Ga daarna op je telefoon, op hetzelfde netwerk, naar **ThreadMapper → Instellingen → ThreadMapper-probe**:

```
http://threadmapper-probe.local:8099
```

Gebruik het IP-adres van de Pi als `.local` niet oplost op iOS. Tik op **Test verbinding** — bij een probleem noemt de app de oorzaak in plaats van alleen een rood kruis te tonen.

---

## Stap 7 — Kijken wat je hebt

- **Overzicht → ⋯ → Thread-netwerk** — gemeten RSSI per knooppunt, verbindingskwaliteit en de routeringstabel met padkosten en volgende hop. Knooppunten verschijnen op Thread-adres, niet op naam; zie ‘Wat nog niet werkt’ hieronder.
- **Mesh → Gereedschap → Kanaalscanner** — nu met het label **Gemeten**. De staafhoogte is de echte ruisvloer over alle 16 kanalen, en de aanbevolen kanalen zijn de rustigste die echt zijn waargenomen in plaats van een gok uit een tabel met wifi-overlap.

Kijk eerst naar de Kanaalscanner. Daar is het verschil het duidelijkst tussen wat de app eerder kon tonen en wat hij nu kan tonen.

---

## Problemen oplossen

| Symptoom | Oorzaak en oplossing |
|---|---|
| `install.sh` zegt ‘No 802.15.4 dongle detected’ | De dongle zit er niet in, of stap 1 is niet gelukt. Controleer `ls /dev/serial/by-id/`. |
| Test verbinding: *‘bereikt de border router ernaast niet’* | De agent draait, maar `otbr-agent` niet. `sudo systemctl status otbr-agent`, daarna `journalctl -u otbr-agent -n 50`. Meestal een verkeerde radio-URL of een dongle die zonder stroom kwam te zitten. |
| Test verbinding: *‘het is geen ThreadMapper-probe-agent’* | Er antwoordt iets anders op die poort. De agent zit op 8099; 8081 is de eigen REST-API van de border router. |
| Test verbinding: *‘Kon dat adres niet bereiken’* | Verkeerd IP-adres, of de telefoon zit op een ander subnet of op een gast-VLAN. |
| `ot-ctl state` zegt `detached` | Hij heeft netwerkgegevens maar vindt het netwerk niet. Verkeerde dataset, of buiten radiobereik van elk ander knooppunt. |
| `ot-ctl state` zegt `disabled` | `ifconfig up` / `thread start` is niet uitgevoerd, of de radio kwam niet op. |
| Het scherm Thread-netwerk toont geen peers | De probe zit op zijn eigen netwerk — controleer dat hij geen `leader` is terwijl je wilde aansluiten. |
| Alles werkt, en na een herstart is het weg | `systemctl is-enabled otbr-agent threadmapper-probe` — beide horen `enabled` te zeggen. |

Logs van beide services samen:

```bash
journalctl -u threadmapper-probe -u otbr-agent -f
```

---

## Wat nog niet werkt

**Knooppunten verschijnen zonder naam.** Thread identificeert een knooppunt aan zijn extended address; HomeKit identificeert een accessoire aan een ondoorzichtige identifier, en niets koppelt die twee aan elkaar. Je krijgt dus een echte, kloppende topologie van anonieme knooppunten in plaats van ‘de keukenlamp’.

De oplossing is gebouwd maar niet af: het endpoint `/traffic` van de agent meldt activiteit per knooppunt, dus door een apparaat via HomeKit te bedienen en te kijken welk knooppunt reageert, zou je ze aan elkaar kunnen koppelen. Om die interactie te ontwikkelen zijn echte accessoires op een echte mesh nodig, en dat is precies wat je hebt zodra dit draait. Bijgehouden als **H1** in `WORKPLAN.md`.

**Het Mesh-tabblad blijft afgeleid.** De graaf daar wordt opgebouwd uit HomeKit-accessoires, dus die kan geen probegegevens gebruiken zolang het bovenstaande niet is opgelost. Het scherm Thread-netwerk en de Kanaalscanner zijn de plekken waar metingen staan.

---

## Als hier iets niet klopt

Deze gids is niet van begin tot eind op echte hardware doorlopen — niemand op het project heeft al een Pi of een dongle. Het inrichtingsscript is getest tegen Debian Bookworm arm64, en elk endpoint van de agent is getest tegen een echte `otbr-agent` op een gesimuleerde radio, maar de fysieke stappen hierboven zijn geschreven vanuit de documentatie van de fabrikanten en niet omdat iemand ze heeft uitgevoerd.

Klopt een stap niet, dan is het de moeite waard om dat in dit bestand recht te zetten.
