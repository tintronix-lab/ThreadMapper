import Foundation

/// Optional real-data source that augments the inferred mesh with actual Thread
/// routing and/or network facts.
///
/// HomeKit cannot provide either; a `ThreadNetwork` credential read can provide
/// network facts, and an OpenThread Border Router (OTBR) REST connection can
/// provide the real routing table. When no provider yields data,
/// `MeshTopologyBuilder` falls back to inference (today's behavior).
protocol DiagnosticsProvider: AnyObject, Sendable {
    /// Real network-level facts (name, channel, PAN ID) when available.
    func threadNetworks() async -> [ThreadNetworkInfo]

    /// Real per-node routing keyed by `ThreadDevice.id`, when available.
    /// Receives the current HomeKit device list so providers can correlate
    /// Thread addresses (RLOC16 / ext-address) to known devices.
    func nodeDiagnostics(for devices: [ThreadDevice]) async -> [UUID: ThreadNodeDiagnostics]
}

/// Default provider used until a real source is wired up: yields nothing, so the
/// mesh stays inferred. Keeps call sites simple (no optionals) before Feature #2.
/// Stateless, so it is genuinely `Sendable` — no `@unchecked` escape needed.
final class NoDiagnosticsProvider: DiagnosticsProvider {
    func threadNetworks() async -> [ThreadNetworkInfo] { [] }
    func nodeDiagnostics(for devices: [ThreadDevice]) async -> [UUID: ThreadNodeDiagnostics] { [:] }
}
