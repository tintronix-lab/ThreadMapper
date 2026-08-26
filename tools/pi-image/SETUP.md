# Setting up a ThreadMapper probe on a Raspberry Pi

Step by step, from an empty desk to measured Thread data in the app.

Budget an evening. Most of it is waiting for downloads and one ~20 minute build.

---

## Read this before you buy anything

Two things decide whether this is worth doing for *your* setup. Both are easy to
miss until the parts arrive.

### 1. A Raspberry Pi cannot do Thread on its own

There is no 802.15.4 radio in a Raspberry Pi. Wi-Fi and Bluetooth are different
radios and cannot speak Thread. **You need a USB dongle**, and it needs RCP
firmware on it — which is not what these dongles ship with.

### 2. Joining *your* Thread network is the hard part

A border router that forms its own new network will sit there seeing nothing but
itself. Your actual devices are on the network your HomePod, Apple TV or Nest
hub created, and to observe them the probe has to **join that network** — which
means getting its credentials (the Active Operational Dataset).

| Your setup | Can the probe join your real network? |
|---|---|
| You run **Home Assistant** | **Yes.** HA's iOS Companion app can pull Apple's Thread credentials — *Settings → Devices & services → Thread → Configure → Send credentials to Home Assistant* — and you can hand the dataset to the probe from there. |
| You already run an **OTBR** (e.g. HA's add-on) | **Yes.** Read the dataset off it directly. |
| **Apple or Google border routers only**, no Home Assistant | **Not today.** There is no user-facing way to export Apple's Thread credentials. You can still form a *new* network on the probe and commission some accessories onto it to see the app working end to end, but it will not show you your existing mesh. |

That third row is a real wall, and it is not one this project can knock down
from the outside: the sanctioned route is Apple's `com.apple.developer.thread-network-credentials`
entitlement, which ThreadMapper has applied for but does not hold. If that comes
through, the app can hand your credentials to the probe directly and this whole
section disappears.

**If you are in the third row and only want to monitor your existing Apple mesh,
consider stopping here until that entitlement lands.**

---

## Shopping list

| Item | Notes |
|---|---|
| Raspberry Pi 4 or 5 | 2 GB RAM is plenty. A Pi Zero 2 W will work but the build in step 4 takes far longer. |
| microSD card, 16 GB+ | Anything reputable. |
| USB-C power supply | The official one; Thread dongles are picky about brown-outs. |
| **An 802.15.4 dongle** | Pick one — see below. |

**Dongle options**, either is fine:

- **Nordic nRF52840 dongle** (~$10) — cheapest, and the firmware is built from
  source so there is no hunting for a download.
- **SkyConnect / Sonoff ZBDongle-E** (~$25) — Silicon Labs. If you already own
  one for Home Assistant, use it. Flashing is a one-line tool.

---

## Step 1 — Put RCP firmware on the dongle

Do this **before** touching the Pi, on your Mac or PC. It is the only step the
installer deliberately does not automate: flashing the wrong image bricks the
dongle, and the vendor tools do it properly.

RCP ("Radio Co-Processor") firmware makes the dongle a dumb radio that
`otbr-agent` drives. A dongle shipped for Zigbee has different firmware and will
not work until reflashed.

### Silicon Labs (SkyConnect, Sonoff ZBDongle-E)

```bash
pipx install universal-silabs-flasher     # or: pip install universal-silabs-flasher
universal-silabs-flasher --device /dev/tty.usbserial-XXXX probe
universal-silabs-flasher --device /dev/tty.usbserial-XXXX flash --firmware <ot-rcp-firmware.gbl>
```

Get the `ot-rcp` `.gbl` from the Home Assistant silabs firmware releases — the
same images the OTBR add-on uses. Match the file to your exact dongle model;
SkyConnect and ZBDongle-E are **not** interchangeable.

### Nordic nRF52840

Build the firmware from OpenThread's Nordic port, then flash over USB DFU:

```bash
git clone --recurse-submodules https://github.com/openthread/ot-nrf528xx.git
cd ot-nrf528xx && ./script/bootstrap && ./script/build nrf52840 USB_trans
# → build/bin/ot-rcp  (convert to .hex/.zip per the repo's README, then:)
nrfutil dfu usb-serial -pkg ot-rcp.zip -p /dev/tty.usbmodemXXXX
```

Follow that repo's README for the current packaging step — it changes
occasionally and is better read there than copied here.

**Check it worked:** plug the dongle into the Pi later and `install.sh` will
report `Found <family> radio at /dev/serial/by-id/...`. If it finds nothing,
the firmware did not take.

---

## Step 2 — Flash Raspberry Pi OS

1. Install **Raspberry Pi Imager**.
2. Choose **Raspberry Pi OS Lite (64-bit)**. Lite — there is no need for a desktop.
3. Click the **gear / Edit Settings** button *before* writing, and set:
   - hostname: `threadmapper-probe`
   - **Enable SSH**, with password or key
   - username and password
   - Wi-Fi credentials, if you are not using Ethernet
4. Write the card, put it in the Pi, attach the dongle, power on.

Ethernet is more reliable than Wi-Fi here, and a border router benefits from a
stable uplink. Use it if you can.

---

## Step 3 — Log in

```bash
ssh <your-username>@threadmapper-probe.local
```

If the hostname does not resolve, find the Pi's IP in your router's client list
and `ssh <user>@<ip>` instead.

Confirm the dongle is visible before going further:

```bash
ls -l /dev/serial/by-id/
```

You should see one entry naming your dongle. **If this is empty, stop** — the
rest will not work. Re-seat it, try another USB port, and re-check step 1.

---

## Step 4 — Install the probe

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/tintronix-lab/ThreadMapper.git
sudo ./ThreadMapper/tools/pi-image/install.sh
```

It detects the dongle, installs `otbr-agent` and the probe agent, and enables
both as systemd services.

**This takes ~20 minutes on a Pi 4**, almost all of it compiling `otbr-agent`.
It is not stuck. When it finishes it prints the probe's address.

If detection fails but you know the device path:

```bash
sudo ./ThreadMapper/tools/pi-image/install.sh --radio-url spinel+hdlc+uart:///dev/ttyACM0
```

Re-running is safe — it is idempotent, and it is how you upgrade the agent later.

---

## Step 5 — Get onto a Thread network

Pick the row that matched you in "Before you buy".

### Path A — Join your existing network (what you actually want)

Get the Active Operational Dataset as a hex string from whatever already holds
your credentials.

From an existing OTBR (including Home Assistant's add-on):

```bash
curl -s http://<existing-otbr>:8081/node/dataset/active \
     -H 'Accept: text/plain'
```

That returns one long hex string. On the Pi:

```bash
sudo ot-ctl dataset set active <that-long-hex-string>
sudo ot-ctl ifconfig up
sudo ot-ctl thread start
```

Wait ~30 seconds, then:

```bash
sudo ot-ctl state
```

Expect `child` or `router` — it joined. `leader` here would mean it formed its
own network instead, which is not what you want on this path.

### Path B — Form a new network (testing, or no way to get credentials)

```bash
sudo ot-ctl dataset init new
sudo ot-ctl dataset commit active
sudo ot-ctl ifconfig up
sudo ot-ctl thread start
sudo ot-ctl state          # expect: leader
```

You now have an empty network with one node. To see anything interesting you
must commission accessories onto it — which means removing them from your Apple
network first. **Do not do this with devices you rely on.**

Print the dataset if you want to join other things to it later:

```bash
sudo ot-ctl dataset active -x
```

---

## Step 6 — Point the app at it

```bash
curl http://localhost:8099/health
```

Expect `"otCtlReachable": true` and a `role`. Then, from your phone on the same
network, in **ThreadMapper → Settings → ThreadMapper Probe**:

```
http://threadmapper-probe.local:8099
```

Use the Pi's IP address instead if `.local` does not resolve on iOS. Tap **Test
Connection** — it names the failure if something is wrong rather than just
showing a red X.

---

## Step 7 — See what you got

- **Dashboard → ⋯ → Thread Network** — measured per-node RSSI, link quality,
  and the routing table with path cost and next hop. Nodes appear by Thread
  address, not by name; see "What will not work yet" below.
- **Mesh → tools → Channel Scanner** — now badged **Measured**. Bar height is
  the real noise floor across all 16 channels, and the recommended channels are
  the quietest ones actually observed rather than a guess from a table of Wi-Fi
  overlap.

The Channel Scanner is the one to look at first. It is the clearest difference
between what the app could show before and what it can show now.

---

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `install.sh` says "No 802.15.4 dongle detected" | The dongle is absent, or step 1 did not take. Check `ls /dev/serial/by-id/`. |
| Test Connection: *"can't reach the border router beside it"* | The agent is up but `otbr-agent` is not. `sudo systemctl status otbr-agent`, then `journalctl -u otbr-agent -n 50`. Usually a wrong radio URL or a dongle that lost power. |
| Test Connection: *"isn't a ThreadMapper probe agent"* | Something else is answering on that port. The agent is 8099; 8081 is the border router's own REST API. |
| Test Connection: *"couldn't reach that address"* | Wrong IP, or the phone is on a different subnet or a guest VLAN. |
| `ot-ctl state` says `detached` | It has credentials but cannot find the network. Wrong dataset, or out of radio range of any other node. |
| `ot-ctl state` says `disabled` | `ifconfig up` / `thread start` did not run, or the radio failed to come up. |
| Thread Network screen is empty of peers | The probe is on its own network — check you are not `leader` when you meant to join one. |
| Everything works, then dies after a reboot | `systemctl is-enabled otbr-agent threadmapper-probe` — both should say `enabled`. |

Logs for both services together:

```bash
journalctl -u threadmapper-probe -u otbr-agent -f
```

---

## What will not work yet

**Nodes appear unnamed.** Thread identifies a node by its extended address;
HomeKit identifies an accessory by an opaque identifier, and nothing links the
two. So you will see a real, correct topology of anonymous nodes rather than
"the kitchen lamp".

The fix is built but not finished: the agent's `/traffic` endpoint reports
per-node activity, so actuating a device through HomeKit and watching which node
responds would bind them. That interaction needs real accessories on a real mesh
to develop against, which is exactly what you will have once this is running.
Tracked as **H1** in `WORKPLAN.md`.

**The Mesh tab is still inferred.** Its graph is built from HomeKit accessories,
so it cannot use probe data until the above is solved. The Thread Network screen
and the Channel Scanner are the ones showing measurements.

---

## If something here is wrong

This guide has not been walked end to end on real hardware — nobody on the
project has a Pi or a dongle yet. The provisioning script is tested against
Debian Bookworm arm64, and every agent endpoint is tested against a real
`otbr-agent` on a simulated radio, but the physical steps above are written from
the vendor documentation rather than from having done them.

If a step is wrong, that is worth fixing in this file.
