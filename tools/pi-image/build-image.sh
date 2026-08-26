#!/usr/bin/env bash
#
# Build a flashable Raspberry Pi image with the ThreadMapper probe preinstalled.
#
#   ./tools/pi-image/build-image.sh            # builds into ./build/pi-image/
#
# Wraps `pi-gen`, the Raspberry Pi Foundation's own image builder, adding one
# custom stage that drops in `install.sh` and the agent and runs the install on
# first boot. The provisioning itself is the same script verified against
# Debian Bookworm arm64 — this only packages it.
#
# Expect ~40-60 minutes and ~8 GB of scratch space; the output .img is ~1.5 GB.
# Build on arm64 (Apple Silicon works) so no emulation is involved.
#
# WHAT THIS CANNOT DO: it is not tested on hardware. Nobody in this repository
# has a Raspberry Pi or an 802.15.4 dongle, so the image has never been booted.
# `install.sh` is verified; this wrapper is not. Treat the first flash as the
# real test, and prefer `install.sh` on a stock Raspberry Pi OS install if you
# want the path that has actually been exercised.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
WORK="${WORK:-$REPO/build/pi-image}"
PI_GEN="$WORK/pi-gen"
IMG_NAME="${IMG_NAME:-threadmapper-probe}"

command -v docker >/dev/null || { echo "docker is required (brew install colima docker && colima start)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "docker daemon unreachable — is colima started?" >&2; exit 1; }

mkdir -p "$WORK"
if [[ ! -d "$PI_GEN/.git" ]]; then
  echo "==> cloning pi-gen"
  git clone --depth 1 --branch arm64 https://github.com/RPi-Distro/pi-gen.git "$PI_GEN"
fi

# Stages 0-2 give a working Raspberry Pi OS Lite: base system, networking, SSH.
# Stages 3-5 add the desktop, which a headless probe has no use for.
echo "==> configuring"
for stage in stage3 stage4 stage5; do touch "$PI_GEN/$stage/SKIP" "$PI_GEN/$stage/SKIP_IMAGES" 2>/dev/null || true; done

STAGE="$PI_GEN/stage-threadmapper"
rm -rf "$STAGE"
mkdir -p "$STAGE/00-install/files"
touch "$STAGE/EXPORT_IMAGE"
echo "threadmapper-probe" > "$STAGE/prerun.sh.tmp" && rm -f "$STAGE/prerun.sh.tmp"

cat > "$STAGE/prerun.sh" <<'PRERUN'
#!/bin/bash -e
if [ ! -d "${ROOTFS_DIR}" ]; then
    copy_previous
fi
PRERUN
chmod +x "$STAGE/prerun.sh"

cp "$HERE/install.sh" "$STAGE/00-install/files/install.sh"
cp "$REPO/tools/probe-agent/agent.py" "$STAGE/00-install/files/agent.py"

# The install runs on *first boot*, not at image-build time: it has to detect
# which 802.15.4 dongle is attached, and there is no dongle inside a build
# container. Baking a fixed radio URL would defeat the auto-detection.
cat > "$STAGE/00-install/00-run.sh" <<'RUN'
#!/bin/bash -e
install -d "${ROOTFS_DIR}/boot/threadmapper"
install -m 0755 files/install.sh "${ROOTFS_DIR}/boot/threadmapper/install.sh"
install -m 0755 files/agent.py   "${ROOTFS_DIR}/boot/threadmapper/agent.py"

install -m 0644 /dev/stdin "${ROOTFS_DIR}/etc/systemd/system/threadmapper-firstboot.service" <<'UNIT'
[Unit]
Description=ThreadMapper probe first-boot provisioning
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/var/lib/threadmapper/provisioned

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/boot/threadmapper/install.sh
# Record success only; a failed run (usually "no dongle attached yet") must be
# allowed to retry on the next boot rather than latching a broken install.
ExecStartPost=/bin/sh -c 'mkdir -p /var/lib/threadmapper && touch /var/lib/threadmapper/provisioned'

[Install]
WantedBy=multi-user.target
UNIT

on_chroot << 'EOF'
systemctl enable threadmapper-firstboot.service
EOF
RUN
chmod +x "$STAGE/00-install/00-run.sh"

cat > "$PI_GEN/config" <<CONFIG
IMG_NAME='${IMG_NAME}'
TARGET_HOSTNAME='threadmapper-probe'
FIRST_USER_NAME='probe'
ENABLE_SSH=1
DEPLOY_COMPRESSION=none
STAGE_LIST='stage0 stage1 stage2 stage-threadmapper'
CONFIG

echo "==> building (40-60 min)"
( cd "$PI_GEN" && ./build-docker.sh )

echo
echo "Image(s):"
find "$PI_GEN/deploy" -name '*.img' -exec ls -lh {} \; 2>/dev/null || echo "  (none found — check the pi-gen log above)"
echo
echo "Flash with Raspberry Pi Imager, attach an nRF52840 or Silicon Labs dongle,"
echo "and boot. Provisioning runs on first boot; if no dongle is attached it"
echo "retries on the next boot rather than failing permanently."
echo
echo "NOT TESTED ON HARDWARE — see the warning at the top of this script."
