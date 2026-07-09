import Foundation
#if THREAD_CREDENTIALS && canImport(ThreadNetwork)
import ThreadNetwork
#endif

/// Reads real Thread **network** facts (channel, PAN ID, network name) from
/// Apple's Thread credential store via the `ThreadNetwork` framework.
///
/// Scope of what this can (and can't) do — see REVIEW.md "Feature #2":
/// - ✅ Network-level facts: obtainable with the
///   `com.apple.developer.thread-network-credentials` entitlement (Apple-gated).
/// - ❌ Per-node routing (`nodeDiagnostics`): Apple exposes **no** Thread
///   Diagnostics-cluster read to third-party apps, so this stays empty. Real
///   routing must come from an OTBR source (`BorderRouterClient`, Phase 3).
///
/// The live `THClient` mapping is compiled only when the `THREAD_CREDENTIALS`
/// build flag is set (i.e. once the entitlement is provisioned and the exact
/// `THCredentials` API is verified on-device). Until then it returns nothing at
/// runtime and never risks a CI/build break against an unverified SDK surface.
final class ThreadCredentialsService: DiagnosticsProvider {

    /// HomeKit/ThreadNetwork give no per-node routing — always empty here.
    func nodeDiagnostics(for devices: [ThreadDevice]) async -> [UUID: ThreadNodeDiagnostics] { [:] }

    func threadNetworks() async -> [ThreadNetworkInfo] {
        #if THREAD_CREDENTIALS && canImport(ThreadNetwork)
        return await withCheckedContinuation { continuation in
            THClient().retrieveAllActiveCredentials { credentials, _ in
                let infos: [ThreadNetworkInfo] = (credentials ?? []).map { cred in
                    ThreadNetworkInfo(
                        networkName: cred.networkName ?? "Thread",
                        channel: Int(cred.channel) == 0 ? nil : Int(cred.channel),
                        panID: cred.panID?.hexString,
                        extendedPANID: cred.extendedPANID?.hexString,
                        borderAgentID: cred.borderAgentID?.hexString
                    )
                }
                continuation.resume(returning: infos)
            }
        }
        #else
        // Entitlement not provisioned / flag off — no real network data yet.
        return []
        #endif
    }
}

#if THREAD_CREDENTIALS && canImport(ThreadNetwork)
private extension Data {
    var hexString: String { map { String(format: "%02X", $0) }.joined() }
}
#endif
