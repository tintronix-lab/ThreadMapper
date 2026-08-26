#!/usr/bin/env bash
#
# Turn a Raspberry Pi running Raspberry Pi OS (Bookworm, 64-bit) into a
# ThreadMapper probe: an OpenThread Border Router plus the agent that reports
# the real mesh to the app.
#
#   curl -fsSL <raw-url>/install.sh | sudo bash
#   sudo ./install.sh --radio-url spinel+hdlc+uart:///dev/ttyACM0   # skip detection
#
# **A Raspberry Pi has no 802.15.4 radio.** Thread needs one, so this expects a
# USB dongle flashed with RCP (Radio Co-Processor) firmware. The script detects
# which of the two common families is attached and reports what it found; it
# does not flash firmware, because flashing the wrong image bricks the dongle
# and the vendor tools do it properly:
#
#   Nordic nRF52840    → nrfutil / the openthread ot-rcp build
#   Silicon Labs       → universal-silabs-flasher (what Home Assistant's
#   (SkyConnect,         OTBR add-on uses)
#    Sonoff ZBDongle-E)
#
# Idempotent: safe to re-run to upgrade the agent or repair units.
set -euo pipefail

AGENT_PORT="${AGENT_PORT:-8099}"
REST_PORT="${REST_PORT:-8081}"
THREAD_IF="${THREAD_IF:-wpan0}"
RADIO_URL="${RADIO_URL:-}"
PREFIX=/usr/local/lib/threadmapper-probe

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --radio-url) RADIO_URL="$2"; shift 2 ;;
    --agent-port) AGENT_PORT="$2"; shift 2 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ $EUID -eq 0 ]] || die "run as root (sudo $0)"

# ── Detect the radio ──────────────────────────────────────────────────────────
# USB IDs, not device paths: /dev/ttyACM0 vs /dev/ttyUSB0 depends on the chip's
# USB bridge and on what else is plugged in, so naming a path guesses wrong
# about half the time.
detect_radio() {
  local id path
  for path in /dev/serial/by-id/*; do
    [[ -e "$path" ]] || continue
    id="$(basename "$path")"
    case "$id" in
      *nRF52840*|*Nordic*|*OpenThread*)
        echo "nordic|$path"; return 0 ;;
      *SkyConnect*|*Sonoff*|*Silicon_Labs*|*CP210*|*ZBDongle-E*)
        echo "silabs|$path"; return 0 ;;
    esac
  done
  # Fall back to raw USB vendor:product for dongles with unhelpful strings.
  # 1915:cafe = Nordic nRF52840 dongle, 10c4:ea60 = Silicon Labs CP210x.
  if command -v lsusb >/dev/null 2>&1; then
    if lsusb | grep -qi '1915:'; then echo "nordic|"; return 0; fi
    if lsusb | grep -qiE '10c4:ea60|1a86:'; then echo "silabs|"; return 0; fi
  fi
  return 1
}

if [[ -z "$RADIO_URL" ]]; then
  log "Looking for an 802.15.4 radio"
  if detected="$(detect_radio)"; then
    family="${detected%%|*}"
    devpath="${detected#*|}"
    if [[ -n "$devpath" ]]; then
      # SkyConnect and Sonoff run at 460800; Nordic RCP builds default to 115200.
      case "$family" in
        silabs) RADIO_URL="spinel+hdlc+uart://${devpath}?uart-baudrate=460800&uart-flow-control" ;;
        nordic) RADIO_URL="spinel+hdlc+uart://${devpath}?uart-baudrate=1000000" ;;
      esac
      log "Found ${family} radio at ${devpath}"
    else
      warn "Saw a ${family} dongle on USB but no /dev/serial/by-id entry."
      warn "Pass the device explicitly: --radio-url spinel+hdlc+uart:///dev/ttyACM0"
      die  "cannot continue without a radio path"
    fi
  else
    warn "No 802.15.4 dongle detected."
    warn "A Raspberry Pi has no Thread radio of its own — plug in an nRF52840 or"
    warn "a Silicon Labs dongle (SkyConnect, Sonoff ZBDongle-E) flashed with RCP"
    warn "firmware, then re-run. To skip detection:"
    warn "    sudo $0 --radio-url spinel+hdlc+uart:///dev/ttyACM0"
    die  "no radio"
  fi
fi

# ── Packages ──────────────────────────────────────────────────────────────────
log "Installing packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
# python3 for the agent; the rest are otbr-agent's runtime dependencies.
apt-get install -y -qq --no-install-recommends \
  python3 iproute2 iptables ipset dbus libreadline8 ca-certificates curl >/dev/null

# otbr-agent is not in Debian, so use the distro packages the OpenThread project
# publishes if present, else build. Building on a Pi takes ~20 minutes, so it is
# the fallback rather than the default.
if ! command -v otbr-agent >/dev/null 2>&1; then
  log "otbr-agent not present — building from source (this takes a while)"
  apt-get install -y -qq --no-install-recommends \
    git cmake ninja-build build-essential libavahi-common-dev libavahi-client-dev \
    libreadline-dev libncurses-dev >/dev/null
  rm -rf /tmp/ot-br-posix
  git clone --depth 1 --recurse-submodules --shallow-submodules \
    https://github.com/openthread/ot-br-posix.git /tmp/ot-br-posix
  ( cd /tmp/ot-br-posix
    # REST is what serves network facts; the agent supplies everything else.
    ./script/cmake-build -DOTBR_REST=ON -DOTBR_WEB=OFF -DOTBR_DBUS=ON \
                         -DOTBR_BORDER_ROUTING=ON
    cmake --install build/otbr )
  rm -rf /tmp/ot-br-posix
fi

# ── Agent ─────────────────────────────────────────────────────────────────────
log "Installing the probe agent"
install -d "$PREFIX"
if [[ -f "$(dirname "$0")/../probe-agent/agent.py" ]]; then
  install -m 0755 "$(dirname "$0")/../probe-agent/agent.py" "$PREFIX/agent.py"
elif [[ -f /boot/threadmapper/agent.py ]]; then
  # pi-gen drops the agent here so a flashed image needs no network to install.
  install -m 0755 /boot/threadmapper/agent.py "$PREFIX/agent.py"
else
  die "agent.py not found next to this script or in /boot/threadmapper"
fi

# ── Services ──────────────────────────────────────────────────────────────────
log "Writing systemd units"

cat >/etc/systemd/system/otbr-agent.service <<UNIT
[Unit]
Description=OpenThread Border Router Agent
After=network-online.target dbus.service
Wants=network-online.target

[Service]
# Routed through /bin/sh because systemd does not expand command substitution
# in ExecStart — and the backbone interface has to be resolved at *boot*, not
# at install time: a Pi set up over Ethernet and later moved to Wi-Fi would
# otherwise keep pointing at a dead eth0.
ExecStart=/bin/sh -c 'exec /usr/sbin/otbr-agent -I ${THREAD_IF} \\
    -B "\$(ip route show default | awk "{print \\\$5; exit}")" \\
    --rest-listen-address 0.0.0.0 --rest-listen-port ${REST_PORT} \\
    "${RADIO_URL}"'
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

cat >/etc/systemd/system/threadmapper-probe.service <<UNIT
[Unit]
Description=ThreadMapper probe agent
# Ordered after otbr-agent, but not bound to it: the agent reports "border
# router unreachable" as a 503, which is far more useful to a user staring at
# the app than the service silently not running.
After=otbr-agent.service
Wants=otbr-agent.service

[Service]
ExecStart=/usr/bin/python3 ${PREFIX}/agent.py --port ${AGENT_PORT} \\
    --ot-ctl /usr/sbin/ot-ctl --db /var/lib/threadmapper-probe/probe.db
Restart=always
RestartSec=5
# The agent reads the mesh and writes only its recording database.
# StateDirectory creates /var/lib/threadmapper-probe and punches the one hole
# ProtectSystem=strict needs — without it the whole filesystem is read-only and
# recording silently falls back to live-only.
StateDirectory=threadmapper-probe
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
NoNewPrivileges=yes

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now otbr-agent.service
systemctl enable --now threadmapper-probe.service

# ── Report ────────────────────────────────────────────────────────────────────
ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
cat <<EOF

  ThreadMapper probe installed.

  Radio        ${RADIO_URL}
  Probe agent  http://${ip:-<pi-address>}:${AGENT_PORT}
  OTBR REST    http://${ip:-<pi-address>}:${REST_PORT}

  Put the probe agent address into ThreadMapper: Settings -> ThreadMapper Probe.

  The Thread network still needs forming or joining once:
      sudo ot-ctl dataset init new && sudo ot-ctl dataset commit active
      sudo ot-ctl ifconfig up && sudo ot-ctl thread start
  or join an existing one by pasting its active dataset:
      sudo ot-ctl dataset set active <hex> && sudo ot-ctl ifconfig up && sudo ot-ctl thread start

  Check it:    curl http://localhost:${AGENT_PORT}/health
  Logs:        journalctl -u threadmapper-probe -u otbr-agent -f
EOF
