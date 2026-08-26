# pi-image — turn a Raspberry Pi into a ThreadMapper probe

> **Setting one up for the first time? Start with [SETUP.md](SETUP.md)** — the
> full walkthrough, from what to buy through to seeing measured data in the app.
> It covers two things that are easy to discover too late: a Pi has no Thread
> radio of its own, and joining your *existing* Thread network needs credentials
> you may not be able to export.
>
> `SETUP.md` is also the source for the public web page
> [`docs/probe-setup.html`](../../docs/probe-setup.html), which the product site
> links to. After editing it, run `make docs` — CI fails on a stale page.

This file is the reference for what the scripts do. Two routes to the same
result: the first is verified, the second packages it.

```bash
# On a Pi already running Raspberry Pi OS (Bookworm, 64-bit):
sudo ./install.sh

# Or build a flashable image (~45 min, ~1.5 GB out):
./build-image.sh
```

## Read this first: a Pi cannot do Thread on its own

**There is no 802.15.4 radio in a Raspberry Pi.** Wi-Fi and Bluetooth are not
Thread. A probe needs a USB dongle flashed with RCP firmware:

| Dongle | Notes |
|---|---|
| Nordic **nRF52840** | ~$10, the cheapest route. Flash with `nrfutil`. |
| **SkyConnect** / Sonoff **ZBDongle-E** | Silicon Labs. What most Home Assistant users already own. Flash with `universal-silabs-flasher`. |

`install.sh` detects which family is attached and configures the right baud rate
and flow control, but **it does not flash firmware** — a wrong image bricks the
dongle, and the vendor tools handle it properly. Flash first, then run this.

## What `install.sh` does

1. Detects the dongle by USB serial ID, falling back to USB vendor ID, and
   builds the matching `spinel+hdlc+uart://` radio URL.
2. Installs `otbr-agent` — from packages if available, else builds from source
   (~20 min on a Pi).
3. Installs the probe agent to `/usr/local/lib/threadmapper-probe/`.
4. Writes and enables two systemd units.

Idempotent — re-run it to upgrade the agent or repair the units.

Afterwards, the Thread network needs forming or joining once:

```bash
sudo ot-ctl dataset init new && sudo ot-ctl dataset commit active
sudo ot-ctl ifconfig up && sudo ot-ctl thread start
```

Then put `http://<pi>:8099` into ThreadMapper under **Settings → ThreadMapper Probe**.

## What is and isn't verified

**Verified** against Debian Bookworm arm64 — the same distribution and
architecture as Raspberry Pi OS:

- dongle detection for both families, and a clear refusal with no dongle attached
- the generated `ExecStart` produces correct argv, with the backbone interface
  resolved at boot (this caught a real bug: systemd does **not** expand `$(…)`
  in `ExecStart`, so the first version would have failed on a real Pi)
- the agent installs and runs

**Not verified**: the `.img` from `build-image.sh`. Nobody here has a Pi or a
dongle, so it has never been booted. If you want the path that has actually been
exercised, flash stock Raspberry Pi OS and run `install.sh`.

## Services

| Unit | |
|---|---|
| `otbr-agent.service` | the border router, REST on 8081 |
| `threadmapper-probe.service` | the agent, JSON on 8099 |

The probe is ordered *after* otbr-agent but not bound to it — it answers 503
with a reason when the border router is down, which tells a user staring at the
app far more than a service that silently isn't running.

```bash
curl http://localhost:8099/health
journalctl -u threadmapper-probe -u otbr-agent -f
```
