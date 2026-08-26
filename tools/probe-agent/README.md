# probe-agent — real Thread topology as JSON

A prototype of the service a ThreadMapper companion device would run alongside
an OpenThread Border Router. It reads the OpenThread CLI and serves clean JSON.

```bash
./tools/probe-agent/agent.py --port 8099
curl http://<border-router>:8099/topology
```

stdlib-only and Python 3.6-compatible, so it runs on whatever userland the
border-router image ships without a package install.

| Endpoint | |
|---|---|
| `GET /health` | liveness, whether `ot-ctl` answered, and whether recording is on |
| `GET /topology` | network facts, nodes, routes |
| `GET /series` | recorded history — `?metric=&from=&to=`; no `metric` returns coverage |

Both return `503` with a reason when `ot-ctl` cannot be reached — an agent that
is up while `otbr-agent` is down is a real state and must be distinguishable.

## Why not just use OTBR's REST API

Because it does not deliver this data. Measured on a live two-node mesh (see
`tools/otbr-sim`): a correctly-formed `getNetworkDiagnosticTask` either
completes with an empty result or times out against a real peer,
`/api/diagnostics` stays at `total: 0`, `/api/devices` never populates, and
`updateDeviceCollectionTask` returns 422.

The data was never missing — only the path out. The same stack answers `ot-ctl`
instantly, which is what this reads.

Owning the contract is worth something on its own: in a single afternoon
upstream's REST surface produced a nonexistent endpoint (`/neighbors`), two key
casings, a wrong key name (`state` vs the documented `role`) and four wrong TLV
names. That is not a foundation to build a product on.

## What it actually returns

Verified output from a real two-node mesh — a border router and a second node
that attached and promoted to router:

```json
{
  "network": { "role": "leader", "rloc16": "0xc400", "networkName": "OpenThread-0157",
               "channel": 11, "panId": "0x0157", "extPanId": "39e2ef22211b12ec" },
  "nodes": [
    { "extAddress": "4a2c8a392fe4b235", "rloc16": "0xc400", "role": "leader", "isSelf": true },
    { "extAddress": "1666d5453afe68c6", "rloc16": "0x5400", "role": "router",
      "averageRssi": -20, "lastRssi": -20, "linkQualityIn": 3,
      "threadVersion": 5, "rxOnWhenIdle": true, "isChild": false }
  ],
  "routes": [
    { "routerId": 21, "rloc16": "0x5400", "nextHop": 63, "pathCost": 0,
      "linkQualityIn": 3, "linkQualityOut": 3, "isDirectLink": true }
  ]
}
```

Every number there is measured. Compare with the app today, where "RSSI" is
bucketed from HomeKit read latency and the mesh graph is inferred from accessory
category and room name.

`nextHop` and `pathCost` are the fields that make a topology multi-hop rather
than a star; nothing else exposes them.

## The gap this does not close

Nodes are identified by Thread ext-address. HomeKit identifies accessories by
opaque UUID. **There is no shared key**, so this data cannot yet be attached to
named devices — a consumer gets a real topology of anonymous nodes.

That is still more truth than an invented one, and it is the prerequisite for
correlating properly later (actuate a device via HomeKit, watch for the
correlated traffic on the mesh, bind the two). It does mean any UI built on this
has to be honest about unnamed nodes.

## Recording

Every endpoint above except `/series` is a *snapshot*. A background sampler
records to SQLite so the probe can answer what happened while nobody was
watching — the reason to leave it plugged in at all.

```bash
curl 'http://<probe>:8099/series'                          # what's on disk
curl 'http://<probe>:8099/series?metric=energy&from=<epoch>&to=<epoch>'
```

Metrics: `energy` (per-channel noise, every 5 min — a scan is slow), `node`,
`counters`, `netinfo` (every 60 s), and `event` (neighbours joining/leaving).
Retention defaults to 30 days; `--no-record` disables it entirely.

**A 24/7 recorder on a Pi's SD card is a well-known way to kill one**, so this
uses WAL with `synchronous=NORMAL`, one transaction per sampler tick rather than
per row, pruning on a timer rather than per write, and incremental auto-vacuum so
a month of retention plateaus instead of growing. A 20-node mesh lands around
45 MB at default settings.

If the database cannot be opened the agent logs it, sets `recording: false` in
`/health`, and carries on serving live data — a probe that still works is better
than one that refuses to start over a missing directory. `/series` then answers
**503 with the reason**, because "recording is off" and "nothing happened" look
identical in a chart and only one of them is a bug.

## Status

Verified against `tools/otbr-sim`, not against physical hardware. Table parsing
keys off the header row rather than fixed column indices, since these tables have
gained columns across OpenThread releases and will again.

**What's next: [ROADMAP.md](ROADMAP.md).** Recording (A1) is done; the RF
waterfall and the "why" engine are what it was built for.
