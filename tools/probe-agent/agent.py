#!/usr/bin/env python3
"""ThreadMapper probe agent — serves real Thread measurements as JSON.

**Why this exists.** ThreadMapper's mesh graph is inferred: HomeKit exposes no
RSSI, no parent/child, no routing, so the app guesses from accessory category
and room name. The obvious fix was to read an OpenThread Border Router's REST
API — but that API does not deliver per-node data. Measured on a live two-node
mesh (see `tools/otbr-sim`): a correctly-formed `getNetworkDiagnosticTask`
either completes with an empty result or times out against a real peer,
`/api/diagnostics` stays at `total: 0`, and `/api/devices` never populates.

The data is *there*. The same stack answers `ot-ctl` instantly. This agent is
the path out: it runs alongside otbr-agent, reads the CLI, and serves clean
JSON the app can consume.

That also puts the API contract on our side of the line. In the course of one
afternoon upstream's REST surface produced a nonexistent endpoint, two key
casings, a wrong key name and four wrong TLV names — not a foundation to build
a product on.

Deliberately stdlib-only and Python 3.6-compatible: it has to run on whatever
old userland the border-router image ships (the stock OTBR image is Ubuntu
18.04) without a package install.

    ./agent.py [--port 8099] [--ot-ctl /usr/sbin/ot-ctl] [--db PATH] [--no-record]

    GET /health       liveness, plus whether ot-ctl answered
    GET /topology     network facts, nodes, routes, per-child error rates
    GET /scan/energy  measured noise floor for all 16 channels
    GET /history      OpenThread's own event log (role changes, joins, leaves)
    GET /counters     MAC counters — retries, CCA failures, busy channel
    GET /traffic      per-node liveness snapshot, for correlating nodes to devices
    GET /series       recorded history — ?metric=&from=&to=

The endpoints above are all *instantaneous*. `/series` is what makes the probe
worth leaving plugged in: a background sampler records to SQLite, so it can
answer what happened while nobody was looking.
"""

import argparse
import json
import os
import re
import sqlite3
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

AGENT_VERSION = "0.3.0"

# ot-ctl calls are local IPC to otbr-agent and normally answer in milliseconds.
# The timeout exists so a wedged agent degrades to a partial response rather
# than hanging the HTTP request forever.
CTL_TIMEOUT_SECONDS = 5
# An energy scan dwells on each of the 16 channels in turn, so it is the one
# command that legitimately takes seconds rather than milliseconds.
SCAN_TIMEOUT_SECONDS = 30


class OTCtl:
    """Thin wrapper over the `ot-ctl` CLI."""

    def __init__(self, binary):
        self.binary = binary

    def run(self, *args, **kwargs):
        """Return stdout as a list of lines, or None if the command failed.

        None and [] mean different things to callers — None is "could not ask",
        [] is "asked, nothing there" — so a node with no children is not
        reported the same way as an unreachable border router.
        """
        timeout = kwargs.get("timeout", CTL_TIMEOUT_SECONDS)
        try:
            proc = subprocess.run(
                [self.binary] + list(args),
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout,
            )
        except (OSError, subprocess.SubprocessError):
            return None
        if proc.returncode != 0:
            return None
        lines = [ln.rstrip("\r") for ln in proc.stdout.decode("utf-8", "replace").splitlines()]
        # ot-ctl ends a successful response with "Done" and an unsuccessful one
        # with "Error <n>: <name>".
        if any(ln.startswith("Error ") for ln in lines):
            return None
        return [ln for ln in lines if ln.strip() and ln.strip() != "Done"]

    def scalar(self, *args):
        lines = self.run(*args)
        return lines[0].strip() if lines else None


# ── Parsing ───────────────────────────────────────────────────────────────────

def parse_table(lines):
    """Parse an ot-ctl ASCII table into dicts keyed by column header.

    Columns come from the header row rather than fixed indices, because the
    tables differ per command and have gained columns across OpenThread
    releases (`child table` alone carries CSL, QMsgCnt and Suprvsn now).
    Reading the header keeps this working when they change again.
    """
    if not lines:
        return []
    header, rows = None, []
    for line in lines:
        if not line.startswith("|"):
            continue
        if set(line) <= set("+-|"):          # separator row
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if header is None:
            header = cells
        elif len(cells) == len(header):
            rows.append(dict(zip(header, cells)))
    return rows


_KV = re.compile(r"([a-z0-9-]+):(\S*)")
_SECTION = re.compile(r"^([a-z0-9-]+)\s+-\s+(.*)$")


def parse_kv_blocks(lines):
    """Parse `meshdiag` output: unindented lines start a record, indented lines
    continue it, and some carry a `section - key:value` prefix.

        rloc16:0xd401 ext-addr:6698a0680f62b850 ver:5
            rss - ave:-20 last:-20 margin:80
            err-rate - frame:0.00% msg:0.00%

    becomes {"rloc16": "0xd401", …, "rss.ave": "-20", "err-rate.frame": "0.00%"}.
    Sections are namespaced because `ave` appears under both `rss` and `csl`.
    """
    blocks, current = [], None
    for line in lines or []:
        if not line.strip():
            continue
        body = line.strip()
        if not line[0].isspace():
            current = {}
            blocks.append(current)
        if current is None:
            continue
        prefix = ""
        section = _SECTION.match(body)
        if section:
            prefix, body = section.group(1) + ".", section.group(2)
        for key, value in _KV.findall(body):
            current[prefix + key] = value
    return blocks


def parse_counters(lines):
    """`counters mac` prints `Name: value`, indenting sub-counters one level."""
    out = {}
    for line in lines or []:
        if ":" not in line:
            continue
        name, _, value = line.partition(":")
        number = to_int(value)
        if number is not None:
            out[name.strip()] = number
    return out


def to_int(value):
    if value is None:
        return None
    text = value.strip().rstrip("%")
    try:
        return int(text[2:], 16) if text.lower().startswith("0x") else int(text, 10)
    except ValueError:
        return None


def to_float(value):
    if value is None:
        return None
    try:
        return float(value.strip().rstrip("%"))
    except ValueError:
        return None


def hex16(value):
    """Normalise an RLOC16 to `0xabcd`, whatever form the CLI printed.

    Always parsed as hex: ot-ctl prints RLOC16 with an `0x` prefix inside the
    tables but *bare* from the scalar `rloc16` command, so `to_int` would read
    `c400` as invalid decimal and a plausible `1024` as decimal when it means
    0x1024. This field is hex in every form the CLI emits.
    """
    if value is None:
        return None
    text = value.strip()
    if text.lower().startswith("0x"):
        text = text[2:]
    try:
        return "0x{:04x}".format(int(text, 16))
    except ValueError:
        return None


def duration_seconds(value):
    """`00:00:52.406` (and `1d.02:03:04`) → seconds, as history reports ages."""
    if not value:
        return None
    text = value.strip()
    days = 0
    if "d." in text:
        day_part, _, text = text.partition("d.")
        days = to_int(day_part) or 0
    parts = text.split(":")
    try:
        parts = [float(p) for p in parts]
    except ValueError:
        return None
    seconds = 0.0
    for part in parts:
        seconds = seconds * 60 + part
    return round(days * 86400 + seconds, 3)


# ── Collection ────────────────────────────────────────────────────────────────

_ROLE_LETTER = {"R": "router", "C": "child", "L": "leader", "E": "endDevice"}


def network_facts(ctl):
    return {
        "role": ctl.scalar("state"),
        "rloc16": hex16(ctl.scalar("rloc16")),
        "extAddress": ctl.scalar("extaddr"),
        "networkName": ctl.scalar("networkname"),
        "channel": to_int(ctl.scalar("channel")),
        "panId": ctl.scalar("panid"),
        "extPanId": ctl.scalar("extpanid"),
        "partitionId": to_int(ctl.scalar("partitionid")),
        "uptimeSeconds": duration_seconds(ctl.scalar("uptime")),
    }


def collect_topology(ctl):
    """Network facts, every node this router can see, and the routing table."""
    network = network_facts(ctl)

    neighbors = parse_table(ctl.run("neighbor", "table"))
    children = parse_table(ctl.run("child", "table"))
    routers = parse_table(ctl.run("router", "table"))

    # The border router is not in its own neighbour table, but a topology is
    # not renderable without its root, so include it explicitly and flagged.
    nodes = [{
        "extAddress": network["extAddress"],
        "rloc16": network["rloc16"],
        "role": network["role"] or "unknown",
        "averageRssi": None,      # a radio cannot measure itself
        "lastRssi": None,
        "linkQualityIn": None,
        "ageSeconds": None,
        "threadVersion": None,
        "rxOnWhenIdle": True,     # a border router is mains-powered by definition
        "fullThreadDevice": True,
        "isChild": False,
        "isSelf": True,
    }]

    # `neighbor table` covers children and router peers alike, and is the only
    # table carrying RSSI — the whole point, given the app's current "RSSI" is
    # derived from HomeKit read latency and is not a radio measurement.
    for row in neighbors:
        nodes.append({
            "extAddress": row.get("Extended MAC"),
            "rloc16": hex16(row.get("RLOC16")),
            "role": _ROLE_LETTER.get(row.get("Role", "").strip(), "unknown"),
            "averageRssi": to_int(row.get("Avg RSSI")),
            "lastRssi": to_int(row.get("Last RSSI")),
            "linkQualityIn": to_int(row.get("LQ In")),
            "ageSeconds": to_int(row.get("Age")),
            "threadVersion": to_int(row.get("Version")),
            # R/D/N are the MLE mode flags: rx-on-when-idle, full Thread device,
            # full network data. R separates a mains node from a sleepy one.
            "rxOnWhenIdle": row.get("R") == "1",
            "fullThreadDevice": row.get("D") == "1",
            "isChild": False,
        })

    by_ext = {n["extAddress"]: n for n in nodes if n["extAddress"]}
    for row in children:
        ext = row.get("Extended MAC")
        node = by_ext.get(ext)
        if node is None:
            node = {"extAddress": ext, "rloc16": hex16(row.get("RLOC16")),
                    "role": "child", "averageRssi": None, "lastRssi": None,
                    "linkQualityIn": to_int(row.get("LQ In")),
                    "ageSeconds": to_int(row.get("Age")),
                    "threadVersion": to_int(row.get("Ver")),
                    "rxOnWhenIdle": row.get("R") == "1",
                    "fullThreadDevice": row.get("D") == "1"}
            nodes.append(node)
            if ext:
                by_ext[ext] = node
        node["isChild"] = True
        node["timeoutSeconds"] = to_int(row.get("Timeout"))

    # `meshdiag childtable` is richer than `child table`: it adds link margin
    # and per-child frame/message error rates, which are the only real
    # reliability signals available — everything else is a snapshot of state.
    own_rloc = network["rloc16"]
    if own_rloc:
        for block in parse_kv_blocks(ctl.run("meshdiag", "childtable", own_rloc)):
            node = by_ext.get(block.get("ext-addr"))
            if node is None:
                continue
            node["linkMargin"] = to_int(block.get("rss.margin"))
            node["frameErrorRate"] = to_float(block.get("err-rate.frame"))
            node["messageErrorRate"] = to_float(block.get("err-rate.msg"))
            node["connectedSeconds"] = duration_seconds(block.get("conn-time"))
            node["queuedMessages"] = to_int(block.get("q-msg"))

    routes = [{
        "routerId": to_int(row.get("ID")),
        "rloc16": hex16(row.get("RLOC16")),
        "extAddress": row.get("Extended MAC"),
        "nextHop": to_int(row.get("Next Hop")),
        "pathCost": to_int(row.get("Path Cost")),
        "linkQualityIn": to_int(row.get("LQ In")),
        "linkQualityOut": to_int(row.get("LQ Out")),
        "isDirectLink": row.get("Link") == "1",
    } for row in routers]

    # `meshdiag topology` discovers every *router* in the mesh, including ones
    # this node has no direct link to — the only source of whole-mesh shape
    # rather than "what my own radio can hear".
    mesh_routers = []
    for block in parse_kv_blocks(ctl.run("meshdiag", "topology", timeout=SCAN_TIMEOUT_SECONDS)):
        if "rloc16" not in block:
            continue
        mesh_routers.append({
            "routerId": to_int(block.get("id")),
            "rloc16": hex16(block.get("rloc16")),
            "extAddress": block.get("ext-addr"),
            "threadVersion": to_int(block.get("ver")),
        })

    return {"agent": "threadmapper-probe", "agentVersion": AGENT_VERSION,
            "network": network, "nodes": nodes, "routes": routes,
            "meshRouters": mesh_routers}


def collect_energy_scan(ctl):
    """Measured noise floor per channel — the real interference picture.

    The app's Channel Scanner currently counts devices per channel and infers
    Wi-Fi overlap from channel *numbers*. This is what the radio actually hears,
    which is the difference between "channel 11 overlaps Wi-Fi 1 in theory" and
    "channel 11 is sitting at -30 dBm right now".
    """
    rows = parse_table(ctl.run("scan", "energy", timeout=SCAN_TIMEOUT_SECONDS))
    channels = [{"channel": to_int(r.get("Ch")), "rssi": to_int(r.get("RSSI"))} for r in rows]
    channels = [c for c in channels if c["channel"] is not None]
    quietest = sorted((c for c in channels if c["rssi"] is not None),
                      key=lambda c: c["rssi"])[:3]
    return {"channels": channels,
            "quietestChannels": [c["channel"] for c in quietest],
            "currentChannel": to_int(ctl.scalar("channel"))}


def collect_history(ctl):
    """OpenThread's own event log — role changes and neighbours joining/leaving.

    This is what makes 24/7 monitoring possible: the phone only sees the mesh
    while the app is open, but the border router was watching the whole time.
    """
    net = []
    for row in parse_table(ctl.run("history", "netinfo", "20")):
        net.append({"ageSeconds": duration_seconds(row.get("Age")),
                    "role": row.get("Role"),
                    "rloc16": hex16(row.get("RLOC16")),
                    "partitionId": to_int(row.get("Partition ID"))})

    neighbors = []
    for row in parse_table(ctl.run("history", "neighbor", "20")):
        neighbors.append({"ageSeconds": duration_seconds(row.get("Age")),
                          "type": row.get("Type"),
                          "event": row.get("Event"),
                          "extAddress": row.get("Extended Address"),
                          "rloc16": hex16(row.get("RLOC16")),
                          "averageRssi": to_int(row.get("Ave RSS"))})

    return {"networkInfo": net, "neighborEvents": neighbors}


def collect_counters(ctl):
    """MAC counters — retries, CCA failures, busy channel.

    These are the only hard reliability numbers on offer. A rising TxRetry or
    TxErrCca is congestion; everything else the app shows is a state snapshot
    that looks fine right up until it doesn't.
    """
    mac = parse_counters(ctl.run("counters", "mac"))
    mle = parse_counters(ctl.run("counters", "mle"))
    return {"mac": mac, "mle": mle}


def collect_traffic(ctl):
    """A cheap liveness snapshot, for binding Thread nodes to named devices.

    Thread identifies a node by ext-address; HomeKit identifies an accessory by
    an opaque UUID, and nothing links them. But a node that just transmitted has
    its neighbour-table `Age` reset to zero. So: poll this, actuate a device
    through HomeKit, and whichever node's age collapses is that device.

    Deliberately minimal — it is meant to be polled about once a second during
    a correlation run, so it reads one table and nothing else.
    """
    rows = parse_table(ctl.run("neighbor", "table"))
    return {
        "sampledAt": round(time.time(), 3),
        "nodes": [{"extAddress": r.get("Extended MAC"),
                   "rloc16": hex16(r.get("RLOC16")),
                   "ageSeconds": to_int(r.get("Age")),
                   "lastRssi": to_int(r.get("Last RSSI"))} for r in rows],
    }


# ── Recording ─────────────────────────────────────────────────────────────────

class Recorder:
    """Samples the mesh on a schedule and stores it, so history outlives a poll.

    Everything else this agent serves is a snapshot. That is fine for a live
    view and useless for the probe's actual selling point — the phone only
    watches while the app is open, and the interesting failures happen at 3am.

    **SD card wear is a real design constraint here**, not a footnote: a 24/7
    recorder writing per-sample to a Raspberry Pi's SD card is a well-known way
    to kill one. Hence WAL plus `synchronous=NORMAL` (far fewer fsyncs, and safe
    against process crashes — only a power cut mid-write can lose the last
    transaction, which for telemetry is an acceptable trade), one transaction
    per tick rather than per row, pruning on a timer rather than on every write,
    and incremental auto-vacuum so a month of retention reaches a plateau
    instead of growing forever.
    """

    # Cadences chosen against cost: an energy scan dwells on each of 16 channels
    # and takes tens of seconds, so it cannot run often. The rest are single
    # cheap CLI calls. At these rates a 20-node mesh lands around 45 MB over the
    # default 30-day retention.
    INTERVALS = {
        "energy":   300.0,
        "node":      60.0,
        "counters":  60.0,
        "netinfo":   60.0,
        "event":     30.0,
    }
    PRUNE_INTERVAL_SECONDS = 3600.0

    METRICS = ("energy", "node", "counters", "netinfo", "event")

    def __init__(self, ctl, path, retention_days=30, interval_scale=1.0):
        self.ctl = ctl
        self.path = path
        self.retention_seconds = retention_days * 86400
        # Scaling all cadences together makes the recorder testable: at 1.0 an
        # energy column arrives every five minutes, which is right for a probe
        # left running and useless for checking that anything works at all.
        self.intervals = {name: max(1.0, seconds * interval_scale)
                          for name, seconds in self.INTERVALS.items()}
        self._lock = threading.Lock()
        self._stop = threading.Event()
        self._thread = None
        self._db = None
        self.last_error = None

    # -- lifecycle ------------------------------------------------------------

    def start(self):
        """Open the database and begin sampling.

        Returns False rather than raising if the database cannot be opened: a
        probe that still serves live data is far more useful than one that
        refuses to start because a directory is missing.
        """
        try:
            directory = os.path.dirname(self.path)
            if directory:
                os.makedirs(directory, exist_ok=True)
            self._db = sqlite3.connect(self.path, check_same_thread=False)
            self._init_schema()
        except Exception as exc:                       # noqa: BLE001 - report, don't crash
            self.last_error = str(exc)
            sys.stderr.write("[probe-agent] recording disabled: %s\n" % exc)
            self._db = None
            return False
        self._thread = threading.Thread(target=self._loop, name="sampler", daemon=True)
        self._thread.start()
        return True

    def stop(self):
        self._stop.set()

    @property
    def enabled(self):
        return self._db is not None

    def _init_schema(self):
        with self._lock:
            # auto_vacuum only takes effect if set before any table exists.
            self._db.execute("PRAGMA auto_vacuum=INCREMENTAL")
            self._db.execute("PRAGMA journal_mode=WAL")
            self._db.execute("PRAGMA synchronous=NORMAL")
            self._db.executescript("""
                CREATE TABLE IF NOT EXISTS energy (
                    ts INTEGER NOT NULL, channel INTEGER NOT NULL, rssi INTEGER);
                CREATE INDEX IF NOT EXISTS energy_ts ON energy(ts);

                CREATE TABLE IF NOT EXISTS node (
                    ts INTEGER NOT NULL, ext_address TEXT, rloc16 TEXT, role TEXT,
                    avg_rssi INTEGER, last_rssi INTEGER, lqi INTEGER, age INTEGER);
                CREATE INDEX IF NOT EXISTS node_ts ON node(ts);

                CREATE TABLE IF NOT EXISTS counters (
                    ts INTEGER NOT NULL, name TEXT NOT NULL, value INTEGER);
                CREATE INDEX IF NOT EXISTS counters_ts ON counters(ts);

                CREATE TABLE IF NOT EXISTS netinfo (
                    ts INTEGER NOT NULL, role TEXT, rloc16 TEXT, partition_id INTEGER);
                CREATE INDEX IF NOT EXISTS netinfo_ts ON netinfo(ts);

                -- OpenThread reports events by *age*, and the same event comes
                -- back on every poll with a larger age. Converting to an
                -- absolute timestamp makes them stable, and the unique index
                -- turns re-observation into a no-op.
                CREATE TABLE IF NOT EXISTS event (
                    ts INTEGER NOT NULL, kind TEXT, event TEXT,
                    ext_address TEXT, rloc16 TEXT, avg_rssi INTEGER,
                    UNIQUE(ts, kind, event, ext_address, rloc16));
                CREATE INDEX IF NOT EXISTS event_ts ON event(ts);
            """)
            self._db.commit()

    # -- sampling -------------------------------------------------------------

    def _loop(self):
        # Stagger the first run of each metric so a restart does not fire an
        # energy scan and four other samplers in the same second.
        now = time.time()
        due_at = {name: now + offset * 3 for offset, name in enumerate(self.METRICS)}
        prune_at = now + self.PRUNE_INTERVAL_SECONDS

        while not self._stop.is_set():
            now = time.time()
            for name in self.METRICS:
                if now >= due_at[name]:
                    try:
                        self._sample(name)
                    except Exception as exc:           # noqa: BLE001
                        self.last_error = "%s: %s" % (name, exc)
                        sys.stderr.write("[probe-agent] sample %s failed: %s\n" % (name, exc))
                    due_at[name] = time.time() + self.intervals[name]
            if now >= prune_at:
                try:
                    self._prune()
                except Exception as exc:               # noqa: BLE001
                    sys.stderr.write("[probe-agent] prune failed: %s\n" % exc)
                prune_at = time.time() + self.PRUNE_INTERVAL_SECONDS
            self._stop.wait(1.0)

    def _write(self, sql, rows):
        """One transaction per tick, not per row — see the SD card note above."""
        if not rows or self._db is None:
            return
        with self._lock:
            self._db.executemany(sql, rows)
            self._db.commit()

    def _sample(self, metric):
        ts = int(time.time())
        if metric == "energy":
            scan = collect_energy_scan(self.ctl)
            self._write("INSERT INTO energy (ts, channel, rssi) VALUES (?,?,?)",
                        [(ts, c["channel"], c["rssi"]) for c in scan["channels"]])

        elif metric == "node":
            rows = []
            for row in parse_table(self.ctl.run("neighbor", "table")):
                rows.append((ts, row.get("Extended MAC"), hex16(row.get("RLOC16")),
                             _ROLE_LETTER.get(row.get("Role", "").strip(), "unknown"),
                             to_int(row.get("Avg RSSI")), to_int(row.get("Last RSSI")),
                             to_int(row.get("LQ In")), to_int(row.get("Age"))))
            self._write("INSERT INTO node (ts, ext_address, rloc16, role, avg_rssi,"
                        " last_rssi, lqi, age) VALUES (?,?,?,?,?,?,?,?)", rows)

        elif metric == "counters":
            counters = collect_counters(self.ctl)
            # Only the counters that carry a reliability signal — storing all 50
            # every minute would dominate the database for no benefit.
            keep = ("TxTotal", "TxRetry", "TxErrCca", "TxErrBusyChannel",
                    "TxErrAbort", "RxTotal", "RxErrFcs", "RxErrNoFrame")
            rows = [(ts, name, counters["mac"][name])
                    for name in keep if name in counters["mac"]]
            self._write("INSERT INTO counters (ts, name, value) VALUES (?,?,?)", rows)

        elif metric == "netinfo":
            facts = network_facts(self.ctl)
            if facts.get("role"):
                self._write("INSERT INTO netinfo (ts, role, rloc16, partition_id)"
                            " VALUES (?,?,?,?)",
                            [(ts, facts["role"], facts["rloc16"], facts["partitionId"])])

        elif metric == "event":
            self._sample_events(ts)

    # OpenThread reports event *ages*, not timestamps, so an absolute time has
    # to be reconstructed as `poll_time - age`. Those two clocks are different —
    # our wall clock and OpenThread's internal timer — so the reconstruction
    # drifts by up to a second between polls, and the same event lands on
    # neighbouring timestamps. Observed in the rig: one child-to-router
    # promotion recorded twice, at ts and ts+1. Exact-match dedup cannot catch
    # that, so identical events within this window are treated as the same
    # event. Two genuinely distinct joins of the same node three seconds apart
    # is not a distinction worth preserving.
    EVENT_DEDUP_TOLERANCE_SECONDS = 3

    def _sample_events(self, ts):
        history = collect_history(self.ctl)
        candidates = []
        for item in history["neighborEvents"]:
            age = item.get("ageSeconds")
            if age is None:
                continue
            candidates.append((int(ts - age), item.get("type"), item.get("event"),
                               item.get("extAddress"), item.get("rloc16"),
                               item.get("averageRssi")))
        if not candidates:
            return

        tolerance = self.EVENT_DEDUP_TOLERANCE_SECONDS
        fresh = []
        with self._lock:
            for row in candidates:
                event_ts, kind, event, ext, rloc, _ = row
                seen = self._db.execute(
                    "SELECT 1 FROM event WHERE kind IS ? AND event IS ? AND"
                    " ext_address IS ? AND rloc16 IS ? AND ts BETWEEN ? AND ?"
                    " LIMIT 1",
                    (kind, event, ext, rloc, event_ts - tolerance, event_ts + tolerance)
                ).fetchone()
                if seen is None:
                    fresh.append(row)
            if fresh:
                self._db.executemany(
                    "INSERT OR IGNORE INTO event (ts, kind, event, ext_address,"
                    " rloc16, avg_rssi) VALUES (?,?,?,?,?,?)", fresh)
                self._db.commit()

    def _prune(self):
        cutoff = int(time.time() - self.retention_seconds)
        with self._lock:
            for table in self.METRICS:
                self._db.execute("DELETE FROM %s WHERE ts < ?" % table, (cutoff,))
            self._db.commit()
            # Deleting rows does not shrink the file; this hands the freed pages
            # back so a month of retention plateaus rather than growing forever.
            self._db.execute("PRAGMA incremental_vacuum")
            self._db.commit()

    # -- reading --------------------------------------------------------------

    COLUMNS = {
        "energy":   ("ts", "channel", "rssi"),
        "node":     ("ts", "ext_address", "rloc16", "role", "avg_rssi", "last_rssi", "lqi", "age"),
        "counters": ("ts", "name", "value"),
        "netinfo":  ("ts", "role", "rloc16", "partition_id"),
        "event":    ("ts", "kind", "event", "ext_address", "rloc16", "avg_rssi"),
    }

    # SQL columns are snake_case; every other response this agent serves is
    # camelCase. Translating here keeps the HTTP API consistent rather than
    # leaking the storage layer's naming to callers.
    _JSON_KEYS = {
        "ext_address": "extAddress", "avg_rssi": "averageRssi",
        "last_rssi": "lastRssi", "lqi": "linkQualityIn", "age": "ageSeconds",
        "partition_id": "partitionId",
    }

    def series(self, metric, start, end, limit):
        columns = self.COLUMNS[metric]
        sql = ("SELECT %s FROM %s WHERE ts >= ? AND ts <= ? ORDER BY ts LIMIT ?"
               % (", ".join(columns), metric))
        with self._lock:
            rows = self._db.execute(sql, (int(start), int(end), int(limit))).fetchall()
        keys = [self._JSON_KEYS.get(name, name) for name in columns]
        return [dict(zip(keys, row)) for row in rows]

    def coverage(self):
        """What is actually on disk — the first thing to check when a chart is
        empty, since it distinguishes "not recording" from "nothing happened"."""
        out = {}
        with self._lock:
            for table in self.METRICS:
                row = self._db.execute(
                    "SELECT COUNT(*), MIN(ts), MAX(ts) FROM %s" % table).fetchone()
                out[table] = {"rows": row[0], "oldest": row[1], "newest": row[2]}
        # WAL mode keeps recent writes in a sidecar file, so the main database
        # can read as 4 KB while a quarter-megabyte sits beside it. Reporting
        # only the former makes a growing database look static.
        size = 0
        for suffix in ("", "-wal", "-shm"):
            try:
                size += os.path.getsize(self.path + suffix)
            except OSError:
                pass
        return {"metrics": out, "databaseBytes": size,
                "retentionDays": self.retention_seconds // 86400}


# ── HTTP ──────────────────────────────────────────────────────────────────────

class Handler(BaseHTTPRequestHandler):
    ctl = None
    recorder = None

    ROUTES = {
        "/topology": collect_topology,
        "/scan/energy": collect_energy_scan,
        "/history": collect_history,
        "/counters": collect_counters,
        "/traffic": collect_traffic,
    }

    # A day of samples is a few hundred KB, so pulling ranges to the phone is
    # cheap. The cap exists to stop a careless `from=0` returning a month.
    SERIES_DEFAULT_WINDOW = 86400
    SERIES_MAX_ROWS = 20000

    def _send(self, status, payload):
        body = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        # The app reaches this across the LAN, from a different origin.
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        raw_path, _, query = self.path.partition("?")
        path = raw_path.rstrip("/") or "/"

        if path == "/health":
            role = self.ctl.scalar("state")
            recording = self.recorder is not None and self.recorder.enabled
            # Reachability alone is a weak signal — the agent can be up while
            # otbr-agent is down. Reporting the role proves the CLI answered.
            body = {
                "agent": "threadmapper-probe", "agentVersion": AGENT_VERSION,
                "otCtlReachable": role is not None, "role": role,
                "recording": recording,
                "endpoints": ["/health", "/series"] + sorted(self.ROUTES),
            }
            if self.recorder is not None and self.recorder.last_error:
                body["recordingError"] = self.recorder.last_error
            self._send(200 if role else 503, body)
            return

        if path == "/series":
            self._series(_parse_query(query))
            return

        collector = self.ROUTES.get(path)
        if collector is None:
            self._send(404, {"error": "not found",
                             "paths": ["/health"] + sorted(self.ROUTES)})
            return

        # Every collector needs a working CLI; failing here rather than
        # returning a hollow object keeps "border router down" distinguishable
        # from "border router fine, nothing to report".
        if self.ctl.scalar("state") is None:
            self._send(503, {"error": "ot-ctl did not answer; is otbr-agent running?"})
            return

        payload = collector(self.ctl)
        payload.setdefault("agent", "threadmapper-probe")
        payload.setdefault("agentVersion", AGENT_VERSION)
        self._send(200, payload)

    def _series(self, params):
        if self.recorder is None or not self.recorder.enabled:
            # 503, not an empty list: "recording is off" and "nothing happened"
            # look identical in a chart, and only one of them is a bug.
            self._send(503, {"error": "recording is not enabled on this probe",
                             "detail": self.recorder.last_error if self.recorder else None})
            return

        metric = params.get("metric")
        if metric is None:
            self._send(200, self.recorder.coverage())
            return
        if metric not in Recorder.METRICS:
            self._send(400, {"error": "unknown metric",
                             "metrics": list(Recorder.METRICS)})
            return

        now = int(time.time())
        end = _to_int_or(params.get("to"), now)
        start = _to_int_or(params.get("from"), end - self.SERIES_DEFAULT_WINDOW)
        limit = min(_to_int_or(params.get("limit"), self.SERIES_MAX_ROWS),
                    self.SERIES_MAX_ROWS)
        rows = self.recorder.series(metric, start, end, limit)
        self._send(200, {"metric": metric, "from": start, "to": end,
                         "count": len(rows),
                         # Tells the caller to narrow its range rather than
                         # silently charting a truncated window.
                         "truncated": len(rows) >= limit,
                         "rows": rows})

    def log_message(self, fmt, *args):
        sys.stderr.write("[probe-agent] %s\n" % (fmt % args))


def _parse_query(query):
    params = {}
    for part in query.split("&"):
        if not part:
            continue
        key, _, value = part.partition("=")
        params[key] = value
    return params


def _to_int_or(value, fallback):
    parsed = to_int(value)
    return fallback if parsed is None else parsed


def main():
    ap = argparse.ArgumentParser(description="Serve real Thread measurements as JSON.")
    ap.add_argument("--port", type=int, default=8099)
    ap.add_argument("--host", default="0.0.0.0")
    ap.add_argument("--ot-ctl", default="/usr/sbin/ot-ctl")
    ap.add_argument("--db", default="/var/lib/threadmapper-probe/probe.db",
                    help="where recorded history is stored")
    ap.add_argument("--retention-days", type=int, default=30)
    ap.add_argument("--sample-scale", type=float, default=1.0,
                    help="multiply all sampling intervals; <1 samples faster (testing)")
    ap.add_argument("--no-record", action="store_true",
                    help="serve live data only; record nothing")
    args = ap.parse_args()

    ctl = OTCtl(args.ot_ctl)
    Handler.ctl = ctl

    if not args.no_record:
        recorder = Recorder(ctl, args.db, retention_days=args.retention_days,
                            interval_scale=args.sample_scale)
        # A failure here is reported and survived, not fatal: live endpoints are
        # still worth serving from a probe that cannot write to disk.
        started = recorder.start()
        Handler.recorder = recorder
        sys.stderr.write("[probe-agent] recording %s (%s, %d day retention)\n"
                         % ("on" if started else "OFF", args.db, args.retention_days))

    sys.stderr.write("[probe-agent] %s on %s:%d via %s\n"
                     % (AGENT_VERSION, args.host, args.port, args.ot_ctl))
    HTTPServer((args.host, args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
