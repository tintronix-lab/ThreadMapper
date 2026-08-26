# Configurare una sonda ThreadMapper su un Raspberry Pi

Passo dopo passo, da una scrivania vuota ai dati Thread misurati nell’app.

Mettici in conto una serata. Per la maggior parte è attesa: i download e una compilazione da circa 20 minuti.

---

## Leggi questo prima di comprare qualsiasi cosa

Due cose decidono se ne vale la pena per la *tua* installazione. Sono entrambe facili da non notare finché non arrivano i pezzi.

### 1. Un Raspberry Pi non sa fare Thread da solo

In un Raspberry Pi non c’è nessuna radio 802.15.4. Il Wi-Fi e il Bluetooth sono radio diverse e non sanno parlare Thread. **Ti serve una chiavetta USB**, e sopra le serve il firmware RCP — che non è quello con cui queste chiavette vengono vendute.

### 2. Entrare nella *tua* rete Thread è la parte difficile

Un border router che forma una rete nuova tutta sua se ne starà lì a vedere soltanto se stesso. I tuoi dispositivi veri sono sulla rete creata dal tuo HomePod, dalla tua Apple TV o dal tuo hub Nest, e per osservarli la sonda deve **entrare in quella rete** — il che significa procurarsi le sue credenziali (l’Active Operational Dataset).

| La tua installazione | La sonda può entrare nella tua rete vera? |
|---|---|
| Usi **Home Assistant** | **Sì.** L’app Companion di HA per iOS può estrarre le credenziali Thread di Apple — *Impostazioni → Dispositivi e servizi → Thread → Configura → Invia credenziali a Home Assistant* — e da lì puoi passare il dataset alla sonda. |
| Hai già un **OTBR** in funzione (per es. il componente aggiuntivo di HA) | **Sì.** Leggi il dataset direttamente da lì. |
| **Solo border router Apple o Google**, senza Home Assistant | **Oggi no.** Non esiste alcun modo accessibile all’utente per esportare le credenziali Thread di Apple. Puoi comunque formare una rete *nuova* sulla sonda e aggregarvi qualche accessorio per vedere l’app funzionare da un capo all’altro, ma non ti mostrerà la tua rete mesh esistente. |

Quella terza riga è un muro vero, e non è uno che questo progetto possa abbattere dall’esterno: la via autorizzata è l’entitlement `com.apple.developer.thread-network-credentials` di Apple, che ThreadMapper ha richiesto ma non possiede. Se venisse concesso, l’app potrebbe passare le tue credenziali direttamente alla sonda e tutta questa sezione sparirebbe.

**Se ti trovi nella terza riga e vuoi soltanto tenere d’occhio la tua mesh Apple esistente, valuta di fermarti qui finché quell’entitlement non arriva.**

---

## Lista della spesa

| Componente | Note |
|---|---|
| Raspberry Pi 4 o 5 | 2 GB di RAM sono più che sufficienti. Un Pi Zero 2 W funziona, ma la compilazione del passo 4 richiede molto più tempo. |
| Scheda microSD, 16 GB o più | Una qualsiasi di marca affidabile. |
| Alimentatore USB-C | Quello ufficiale; le chiavette Thread sono schizzinose sui cali di tensione. |
| **Una chiavetta 802.15.4** | Scegline una — vedi sotto. |

**Le chiavette possibili**, vanno bene entrambe:

- **Chiavetta Nordic nRF52840** (circa 10 $) — la più economica, e il firmware si compila dai sorgenti, quindi non c’è nessun download da cercare.
- **SkyConnect / Sonoff ZBDongle-E** (circa 25 $) — di Silicon Labs. Se ne hai già una per Home Assistant, usa quella. Per scriverle il firmware basta uno strumento da una riga.

---

## Passo 1 — Scrivi il firmware RCP sulla chiavetta

Fallo **prima** di toccare il Pi, sul tuo Mac o PC. È l’unico passo che l’installatore deliberatamente non automatizza: scrivere l’immagine sbagliata rende la chiavetta inservibile, e gli strumenti del produttore lo fanno come si deve.

Il firmware RCP («Radio Co-Processor») trasforma la chiavetta in una radio stupida pilotata da `otbr-agent`. Una chiavetta venduta per Zigbee ha un firmware diverso e non funzionerà finché non la riscrivi.

### Silicon Labs (SkyConnect, Sonoff ZBDongle-E)

```bash
pipx install universal-silabs-flasher     # or: pip install universal-silabs-flasher
universal-silabs-flasher --device /dev/tty.usbserial-XXXX probe
universal-silabs-flasher --device /dev/tty.usbserial-XXXX flash --firmware <ot-rcp-firmware.gbl>
```

Prendi il `.gbl` di `ot-rcp` dalle release del firmware silabs di Home Assistant — le stesse immagini che usa il componente aggiuntivo OTBR. Fai corrispondere il file al modello esatto della tua chiavetta; SkyConnect e ZBDongle-E **non** sono intercambiabili.

### Nordic nRF52840

Compila il firmware dal port Nordic di OpenThread, poi scrivilo via USB DFU:

```bash
git clone --recurse-submodules https://github.com/openthread/ot-nrf528xx.git
cd ot-nrf528xx && ./script/bootstrap && ./script/build nrf52840 USB_trans
# → build/bin/ot-rcp  (convert to .hex/.zip per the repo's README, then:)
nrfutil dfu usb-serial -pkg ot-rcp.zip -p /dev/tty.usbmodemXXXX
```

Per il passo di impacchettamento attuale segui il README di quel repository — cambia ogni tanto ed è meglio leggerlo lì che copiarlo qui.

**Verifica che abbia funzionato:** più avanti collega la chiavetta al Pi e `install.sh` riporterà `Found <family> radio at /dev/serial/by-id/...`. Se non trova nulla, il firmware non è stato scritto.

---

## Passo 2 — Scrivi Raspberry Pi OS sulla scheda

1. Installa **Raspberry Pi Imager**.
2. Scegli **Raspberry Pi OS Lite (64 bit)**. Lite — un desktop non serve.
3. Premi il pulsante **dell’ingranaggio / Modifica impostazioni** *prima* di scrivere, e imposta:
   - hostname: `threadmapper-probe`
   - **Abilita SSH**, con password o chiave
   - nome utente e password
   - le credenziali Wi-Fi, se non usi l’Ethernet
4. Scrivi la scheda, mettila nel Pi, collega la chiavetta, accendi.

Qui l’Ethernet è più affidabile del Wi-Fi, e un border router trae vantaggio da un collegamento a monte stabile. Usala se puoi.

---

## Passo 3 — Accedi

```bash
ssh <your-username>@threadmapper-probe.local
```

Se l’hostname non si risolve, trova l’IP del Pi nell’elenco dei client del tuo router e usa invece `ssh <user>@<ip>`.

Prima di andare avanti, conferma che la chiavetta sia visibile:

```bash
ls -l /dev/serial/by-id/
```

Dovresti vedere una voce che nomina la tua chiavetta. **Se è vuoto, fermati** — il resto non funzionerà. Riestraila e rinseriscila, prova un’altra porta USB e ricontrolla il passo 1.

---

## Passo 4 — Installa la sonda

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/tintronix-lab/ThreadMapper.git
sudo ./ThreadMapper/tools/pi-image/install.sh
```

Rileva la chiavetta, installa `otbr-agent` e l’agente della sonda, e abilita entrambi come servizi systemd.

**Su un Pi 4 ci vogliono circa 20 minuti**, quasi tutti spesi a compilare `otbr-agent`. Non è bloccato. Quando finisce stampa l’indirizzo della sonda.

Se il rilevamento fallisce ma conosci il percorso del dispositivo:

```bash
sudo ./ThreadMapper/tools/pi-image/install.sh --radio-url spinel+hdlc+uart:///dev/ttyACM0
```

Rieseguirlo è sicuro — è idempotente, ed è così che aggiornerai l’agente più avanti.

---

## Passo 5 — Entra in una rete Thread

Scegli la riga che ti corrispondeva in «Leggi questo prima di comprare qualsiasi cosa».

### Percorso A — Entra nella tua rete esistente (quello che vuoi davvero)

Procurati l’Active Operational Dataset come stringa esadecimale da qualunque cosa già detenga le tue credenziali.

Da un OTBR esistente (compreso il componente aggiuntivo di Home Assistant):

```bash
curl -s http://<existing-otbr>:8081/node/dataset/active \
     -H 'Accept: text/plain'
```

Restituisce una sola lunga stringa esadecimale. Sul Pi:

```bash
sudo ot-ctl dataset set active <that-long-hex-string>
sudo ot-ctl ifconfig up
sudo ot-ctl thread start
```

Aspetta circa 30 secondi, poi:

```bash
sudo ot-ctl state
```

Aspettati `child` oppure `router` — è entrata. `leader` qui vorrebbe dire che ha formato una rete tutta sua, che non è quello che vuoi su questo percorso.

### Percorso B — Forma una rete nuova (per prova, o se non c’è modo di ottenere le credenziali)

```bash
sudo ot-ctl dataset init new
sudo ot-ctl dataset commit active
sudo ot-ctl ifconfig up
sudo ot-ctl thread start
sudo ot-ctl state          # expect: leader
```

Ora hai una rete vuota con un solo nodo. Per vedere qualcosa di interessante devi aggregarvi degli accessori — il che significa prima toglierli dalla tua rete Apple. **Non farlo con dispositivi su cui fai affidamento.**

Stampa il dataset se più avanti vuoi aggiungerci altre cose:

```bash
sudo ot-ctl dataset active -x
```

---

## Passo 6 — Punta l’app su di essa

```bash
curl http://localhost:8099/health
```

Aspettati `"otCtlReachable": true` e un `role`. Poi, dal telefono collegato alla stessa rete, in **ThreadMapper → Impostazioni → Sonda ThreadMapper**:

```
http://threadmapper-probe.local:8099
```

Se `.local` non si risolve su iOS, usa invece l’indirizzo IP del Pi. Tocca **Prova la connessione** — se qualcosa non va dice qual è il problema, invece di mostrare solo una X rossa.

---

## Passo 7 — Guarda che cosa hai ottenuto

- **Pannello → ⋯ → Rete Thread** — RSSI misurato per singolo nodo, qualità del collegamento e la tabella di instradamento con costo del percorso e hop successivo. I nodi compaiono con l’indirizzo Thread, non con il nome; vedi «Che cosa non funziona ancora» più sotto.
- **Rete mesh → strumenti → Scanner dei canali** — ora con il badge **Misurato**. L’altezza delle barre è il livello di rumore reale su tutti e 16 i canali, e i canali consigliati sono i più silenziosi osservati davvero, non un’ipotesi ricavata da una tabella di sovrapposizioni con il Wi-Fi.

Lo Scanner dei canali è quello da guardare per primo. È la differenza più netta fra quello che l’app poteva mostrare prima e quello che può mostrare adesso.

---

## Risoluzione dei problemi

| Sintomo | Causa e rimedio |
|---|---|
| `install.sh` dice «No 802.15.4 dongle detected» | La chiavetta non c’è, oppure il passo 1 non è andato a buon fine. Controlla `ls /dev/serial/by-id/`. |
| Prova la connessione: *«non raggiunge il border router accanto»* | L’agente è attivo ma `otbr-agent` no. `sudo systemctl status otbr-agent`, poi `journalctl -u otbr-agent -n 50`. Di solito è un radio URL sbagliato, o una chiavetta rimasta senza alimentazione. |
| Prova la connessione: *«non è un agente sonda di ThreadMapper»* | Su quella porta sta rispondendo qualcos’altro. L’agente è sulla 8099; la 8081 è l’API REST del border router stesso. |
| Prova la connessione: *«Impossibile raggiungere quell’indirizzo»* | IP sbagliato, oppure il telefono è su una subnet diversa o su una VLAN ospiti. |
| `ot-ctl state` dice `detached` | Ha le credenziali ma non trova la rete. Dataset sbagliato, oppure fuori dalla portata radio di ogni altro nodo. |
| `ot-ctl state` dice `disabled` | `ifconfig up` / `thread start` non sono stati eseguiti, oppure la radio non è riuscita a partire. |
| La schermata Rete Thread non ha nessun peer | La sonda è sulla sua rete — controlla di non essere `leader` quando volevi entrare in una rete esistente. |
| Funziona tutto, poi dopo un riavvio muore | `systemctl is-enabled otbr-agent threadmapper-probe` — entrambi devono dire `enabled`. |

I log di entrambi i servizi insieme:

```bash
journalctl -u threadmapper-probe -u otbr-agent -f
```

---

## Che cosa non funziona ancora

**I nodi compaiono senza nome.** Thread identifica un nodo tramite il suo indirizzo esteso; HomeKit identifica un accessorio tramite un identificatore opaco, e niente collega i due. Vedrai quindi una topologia reale e corretta fatta di nodi anonimi, invece di «la lampada della cucina».

La soluzione è costruita ma non finita: l’endpoint `/traffic` dell’agente riporta l’attività per singolo nodo, quindi azionare un dispositivo tramite HomeKit e guardare quale nodo risponde li legherebbe insieme. Per sviluppare quell’interazione servono accessori veri su una mesh vera, che è esattamente ciò che avrai una volta che tutto questo sarà in funzione. Tracciato come **H1** in `WORKPLAN.md`.

**La scheda Rete mesh resta dedotta.** Il suo grafico è costruito a partire dagli accessori HomeKit, quindi non può usare i dati della sonda finché non si risolve quanto sopra. Le schermate che mostrano misure sono Rete Thread e Scanner dei canali.

---

## Se qui c’è qualcosa di sbagliato

Questa guida non è stata percorsa da capo a fondo su hardware reale — nel progetto nessuno ha ancora un Pi o una chiavetta. Lo script di provisioning è testato su Debian Bookworm arm64 e ogni endpoint dell’agente è testato contro un `otbr-agent` vero su una radio simulata, ma i passi fisici qui sopra sono scritti a partire dalla documentazione dei produttori, non dall’averli eseguiti.

Se un passo è sbagliato, vale la pena correggerlo in questo file.
