# Eine ThreadMapper-Sonde auf einem Raspberry Pi einrichten

Schritt für Schritt, vom leeren Schreibtisch bis zu gemessenen Thread-Daten in der App.

Planen Sie einen Abend ein. Das meiste davon ist Warten auf Downloads und ein Build von etwa 20 Minuten.

---

## Lesen Sie das, bevor Sie etwas kaufen

Zwei Dinge entscheiden, ob sich das für *Ihre* Umgebung lohnt. Beide übersieht man leicht, bis die Teile da sind.

### 1. Ein Raspberry Pi kann Thread nicht von allein

In einem Raspberry Pi steckt kein 802.15.4-Funkmodul. WLAN und Bluetooth sind andere Funkmodule und sprechen kein Thread. **Sie brauchen einen USB-Dongle**, und darauf muss RCP-Firmware laufen — die diese Dongles ab Werk nicht mitbringen.

### 2. Der schwierige Teil ist der Beitritt zu *Ihrem* Thread-Netzwerk

Ein Border Router, der ein eigenes neues Netzwerk bildet, sieht dort nichts außer sich selbst. Ihre tatsächlichen Geräte hängen an dem Netzwerk, das Ihr HomePod, Apple TV oder Nest Hub aufgebaut hat, und um sie zu beobachten, muss die Sonde **diesem Netzwerk beitreten** — und dafür braucht sie dessen Zugangsdaten (das Active Operational Dataset).

| Ihre Umgebung | Kann die Sonde Ihrem echten Netzwerk beitreten? |
|---|---|
| Sie nutzen **Home Assistant** | **Ja.** Die iOS-Companion-App von HA kann Apples Thread-Zugangsdaten abrufen — *Settings → Devices & services → Thread → Configure → Send credentials to Home Assistant* — und von dort übergeben Sie das Dataset an die Sonde. |
| Sie betreiben bereits einen **OTBR** (z. B. das Add-on von HA) | **Ja.** Lesen Sie das Dataset direkt dort aus. |
| **Nur Border Router von Apple oder Google**, kein Home Assistant | **Derzeit nicht.** Es gibt keinen Weg für Endanwender, Apples Thread-Zugangsdaten zu exportieren. Sie können auf der Sonde trotzdem ein *neues* Netzwerk bilden und einiges Zubehör darauf anmelden, um die App durchgängig arbeiten zu sehen, aber Ihr bestehendes Netz zeigt sie Ihnen damit nicht. |

Die dritte Zeile ist eine echte Wand, und dieses Projekt kann sie nicht von außen einreißen: Der vorgesehene Weg ist Apples Berechtigung `com.apple.developer.thread-network-credentials`, die ThreadMapper beantragt, aber nicht erhalten hat. Kommt sie durch, kann die App Ihre Zugangsdaten direkt an die Sonde übergeben, und dieser ganze Abschnitt entfällt.

**Wenn Sie in der dritten Zeile stehen und nur Ihr bestehendes Apple-Netz überwachen möchten, hören Sie hier besser auf, bis diese Berechtigung da ist.**

---

## Einkaufsliste

| Teil | Hinweise |
|---|---|
| Raspberry Pi 4 oder 5 | 2 GB RAM reichen völlig. Ein Pi Zero 2 W funktioniert auch, aber der Build in Schritt 4 dauert dort deutlich länger. |
| microSD-Karte, 16 GB+ | Irgendeine von einem seriösen Hersteller. |
| USB-C-Netzteil | Das offizielle; Thread-Dongles reagieren empfindlich auf Spannungseinbrüche. |
| **Ein 802.15.4-Dongle** | Wählen Sie einen aus — siehe unten. |

**Dongle-Optionen**, beide sind in Ordnung:

- **Nordic nRF52840 Dongle** (ca. 10 $) — am günstigsten, und die Firmware wird aus dem Quellcode gebaut, sodass Sie keinen Download suchen müssen.
- **SkyConnect / Sonoff ZBDongle-E** (ca. 25 $) — Silicon Labs. Wenn Sie schon einen für Home Assistant haben, nehmen Sie den. Das Flashen erledigt ein Werkzeug mit einer einzigen Zeile.

---

## Schritt 1 — RCP-Firmware auf den Dongle bringen

Erledigen Sie das an Ihrem Mac oder PC, **bevor** Sie den Pi anfassen. Es ist der einzige Schritt, den das Installationsskript bewusst nicht automatisiert: Ein falsches Image macht den Dongle unbrauchbar, und die Werkzeuge der Hersteller machen es richtig.

RCP-Firmware („Radio Co-Processor“) macht den Dongle zu einem simplen Funkmodul, das `otbr-agent` ansteuert. Ein für Zigbee ausgelieferter Dongle hat eine andere Firmware und funktioniert erst nach dem Neuflashen.

### Silicon Labs (SkyConnect, Sonoff ZBDongle-E)

```bash
pipx install universal-silabs-flasher     # or: pip install universal-silabs-flasher
universal-silabs-flasher --device /dev/tty.usbserial-XXXX probe
universal-silabs-flasher --device /dev/tty.usbserial-XXXX flash --firmware <ot-rcp-firmware.gbl>
```

Holen Sie sich die `.gbl`-Datei für `ot-rcp` aus den Silabs-Firmware-Releases von Home Assistant — dieselben Images, die auch das OTBR-Add-on verwendet. Achten Sie darauf, dass die Datei zu Ihrem genauen Dongle-Modell passt; SkyConnect und ZBDongle-E sind **nicht** austauschbar.

### Nordic nRF52840

Bauen Sie die Firmware aus dem Nordic-Port von OpenThread und flashen Sie sie anschließend per USB DFU:

```bash
git clone --recurse-submodules https://github.com/openthread/ot-nrf528xx.git
cd ot-nrf528xx && ./script/bootstrap && ./script/build nrf52840 USB_trans
# → build/bin/ot-rcp  (convert to .hex/.zip per the repo's README, then:)
nrfutil dfu usb-serial -pkg ot-rcp.zip -p /dev/tty.usbmodemXXXX
```

Folgen Sie für den aktuellen Verpackungsschritt der README dieses Repos — er ändert sich gelegentlich und wird besser dort gelesen als hier kopiert.

**Prüfen, ob es geklappt hat:** Stecken Sie den Dongle später in den Pi, dann meldet `install.sh` `Found <family> radio at /dev/serial/by-id/...`. Findet es nichts, hat die Firmware nicht gegriffen.

---

## Schritt 2 — Raspberry Pi OS flashen

1. Installieren Sie den **Raspberry Pi Imager**.
2. Wählen Sie **Raspberry Pi OS Lite (64-bit)**. Lite — einen Desktop brauchen Sie nicht.
3. Klicken Sie *vor* dem Schreiben auf das Zahnrad bzw. **Edit Settings** und stellen Sie ein:
   - hostname: `threadmapper-probe`
   - **Enable SSH**, mit Passwort oder Schlüssel
   - Benutzername und Passwort
   - WLAN-Zugangsdaten, falls Sie kein Ethernet nutzen
4. Schreiben Sie die Karte, stecken Sie sie in den Pi, schließen Sie den Dongle an und schalten Sie ein.

Ethernet ist hier zuverlässiger als WLAN, und ein Border Router profitiert von einer stabilen Anbindung. Nutzen Sie es, wenn Sie können.

---

## Schritt 3 — Anmelden

```bash
ssh <your-username>@threadmapper-probe.local
```

Wenn sich der Hostname nicht auflösen lässt, suchen Sie die IP des Pi in der Client-Liste Ihres Routers und nutzen Sie stattdessen `ssh <user>@<ip>`.

Vergewissern Sie sich, dass der Dongle sichtbar ist, bevor Sie weitermachen:

```bash
ls -l /dev/serial/by-id/
```

Sie sollten einen Eintrag sehen, der Ihren Dongle nennt. **Wenn hier nichts steht, hören Sie auf** — der Rest funktioniert dann nicht. Stecken Sie ihn neu ein, probieren Sie einen anderen USB-Anschluss und prüfen Sie Schritt 1 noch einmal.

---

## Schritt 4 — Die Sonde installieren

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/tintronix-lab/ThreadMapper.git
sudo ./ThreadMapper/tools/pi-image/install.sh
```

Es erkennt den Dongle, installiert `otbr-agent` und den Sonden-Agenten und aktiviert beide als systemd-Dienste.

**Auf einem Pi 4 dauert das etwa 20 Minuten**, fast durchgehend das Kompilieren von `otbr-agent`. Es hängt nicht. Zum Schluss gibt das Skript die Adresse der Sonde aus.

Wenn die Erkennung fehlschlägt, Sie den Gerätepfad aber kennen:

```bash
sudo ./ThreadMapper/tools/pi-image/install.sh --radio-url spinel+hdlc+uart:///dev/ttyACM0
```

Ein erneuter Durchlauf ist unbedenklich — das Skript ist idempotent, und genau so aktualisieren Sie den Agenten später.

---

## Schritt 5 — In ein Thread-Netzwerk kommen

Wählen Sie die Zeile, die unter „Lesen Sie das, bevor Sie etwas kaufen“ auf Sie zutraf.

### Weg A — Ihrem bestehenden Netzwerk beitreten (was Sie eigentlich wollen)

Holen Sie sich das Active Operational Dataset als Hex-String von dem, was Ihre Zugangsdaten bereits vorhält.

Von einem vorhandenen OTBR (auch dem Add-on von Home Assistant):

```bash
curl -s http://<existing-otbr>:8081/node/dataset/active \
     -H 'Accept: text/plain'
```

Das liefert einen langen Hex-String. Auf dem Pi:

```bash
sudo ot-ctl dataset set active <that-long-hex-string>
sudo ot-ctl ifconfig up
sudo ot-ctl thread start
```

Warten Sie etwa 30 Sekunden, dann:

```bash
sudo ot-ctl state
```

Erwarten Sie `child` oder `router` — dann ist der Beitritt geglückt. `leader` hieße hier, dass die Sonde stattdessen ein eigenes Netzwerk gebildet hat, was auf diesem Weg nicht gewollt ist.

### Weg B — Ein neues Netzwerk bilden (zum Testen, oder wenn es keinen Weg zu den Zugangsdaten gibt)

```bash
sudo ot-ctl dataset init new
sudo ot-ctl dataset commit active
sudo ot-ctl ifconfig up
sudo ot-ctl thread start
sudo ot-ctl state          # expect: leader
```

Sie haben jetzt ein leeres Netzwerk mit einem einzigen Knoten. Um etwas Interessantes zu sehen, müssen Sie Zubehör darauf anmelden — was bedeutet, es zuerst aus Ihrem Apple-Netzwerk zu entfernen. **Machen Sie das nicht mit Geräten, auf die Sie angewiesen sind.**

Geben Sie das Dataset aus, wenn Sie später weitere Geräte damit verbinden möchten:

```bash
sudo ot-ctl dataset active -x
```

---

## Schritt 6 — Die App darauf ausrichten

```bash
curl http://localhost:8099/health
```

Erwarten Sie `"otCtlReachable": true` und ein `role`. Dann auf Ihrem iPhone im selben Netzwerk unter **ThreadMapper → Einstellungen → ThreadMapper-Sonde**:

```
http://threadmapper-probe.local:8099
```

Nutzen Sie stattdessen die IP-Adresse des Pi, wenn sich `.local` unter iOS nicht auflösen lässt. Tippen Sie auf **Verbindung testen** — bei einem Problem wird der Fehler benannt, statt nur ein rotes X zu zeigen.

---

## Schritt 7 — Sehen, was Sie bekommen haben

- **Übersicht → ⋯ → Thread-Netzwerk** — gemessener RSSI je Knoten, Verbindungsqualität und die Routing-Tabelle mit Pfadkosten und nächstem Hop. Knoten erscheinen mit ihrer Thread-Adresse, nicht mit Namen; siehe „Was noch nicht funktioniert“ weiter unten.
- **Netz → Werkzeuge → Kanalscanner** — jetzt mit der Kennzeichnung **Gemessen**. Die Balkenhöhe ist der echte Rauschpegel über alle 16 Kanäle, und die empfohlenen Kanäle sind die tatsächlich ruhigsten statt einer Schätzung aus einer Tabelle mit WLAN-Überschneidungen.

Den Kanalscanner sollten Sie sich zuerst ansehen. Er zeigt am deutlichsten den Unterschied zwischen dem, was die App vorher zeigen konnte, und dem, was sie jetzt zeigt.

---

## Fehlersuche

| Symptom | Ursache und Abhilfe |
|---|---|
| `install.sh` meldet „No 802.15.4 dongle detected“ | Der Dongle fehlt, oder Schritt 1 hat nicht gegriffen. Prüfen Sie `ls /dev/serial/by-id/`. |
| Verbindung testen: *„erreicht den Border Router daneben nicht“* | Der Agent läuft, `otbr-agent` aber nicht. `sudo systemctl status otbr-agent`, dann `journalctl -u otbr-agent -n 50`. Meist eine falsche Radio-URL oder ein Dongle, der die Stromversorgung verloren hat. |
| Verbindung testen: *„ist kein ThreadMapper-Sonden-Agent“* | Etwas anderes antwortet auf diesem Port. Der Agent lauscht auf 8099; 8081 ist die eigene REST-API des Border Routers. |
| Verbindung testen: *„Diese Adresse war nicht erreichbar“* | Falsche IP, oder das iPhone hängt in einem anderen Subnetz oder einem Gast-VLAN. |
| `ot-ctl state` meldet `detached` | Die Sonde hat Zugangsdaten, findet das Netzwerk aber nicht. Falsches Dataset, oder außer Funkreichweite jedes anderen Knotens. |
| `ot-ctl state` meldet `disabled` | `ifconfig up` bzw. `thread start` wurde nicht ausgeführt, oder das Funkmodul kam nicht hoch. |
| Die Ansicht „Thread-Netzwerk“ zeigt keine anderen Knoten | Die Sonde ist in ihrem eigenen Netzwerk — prüfen Sie, dass sie nicht `leader` ist, wenn sie beitreten sollte. |
| Alles läuft, stirbt aber nach einem Neustart | `systemctl is-enabled otbr-agent threadmapper-probe` — beides sollte `enabled` melden. |

Logs beider Dienste zusammen:

```bash
journalctl -u threadmapper-probe -u otbr-agent -f
```

---

## Was noch nicht funktioniert

**Knoten erscheinen ohne Namen.** Thread identifiziert einen Knoten über seine erweiterte Adresse; HomeKit identifiziert Zubehör über eine undurchsichtige Kennung, und nichts verbindet die beiden. Sie sehen also eine echte, korrekte Topologie aus anonymen Knoten statt „die Küchenlampe“.

Die Lösung ist angelegt, aber nicht fertig: Der Endpunkt `/traffic` des Agenten meldet Aktivität je Knoten, sodass sich beide verknüpfen ließen, indem man ein Gerät über HomeKit schaltet und beobachtet, welcher Knoten antwortet. Für diese Interaktion braucht die Entwicklung echtes Zubehör in einem echten Netz — genau das, was Sie haben werden, sobald das hier läuft. Erfasst als **H1** in `WORKPLAN.md`.

**Der Tab „Netz“ bleibt abgeleitet.** Sein Graph wird aus HomeKit-Zubehör aufgebaut und kann daher keine Sondendaten nutzen, solange das Obige nicht gelöst ist. Messwerte zeigen die Ansicht „Thread-Netzwerk“ und der Kanalscanner.

---

## Wenn hier etwas falsch ist

Diese Anleitung wurde noch nicht von Anfang bis Ende an echter Hardware durchlaufen — niemand im Projekt hat bisher einen Pi oder einen Dongle. Das Provisionierungsskript ist gegen Debian Bookworm arm64 getestet, und jeder Endpunkt des Agenten ist gegen einen echten `otbr-agent` an einem simulierten Funkmodul getestet, aber die praktischen Schritte oben sind aus der Herstellerdokumentation geschrieben und nicht aus eigener Erfahrung.

Wenn ein Schritt falsch ist, lohnt es sich, das in dieser Datei zu korrigieren.
