#if os(iOS)
import ActivityKit
import Foundation

struct ThreadNetworkActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var grade: String
        var score: Int
        var deviceCount: Int
        var offlineCount: Int
        var isScanning: Bool
        var alertMessage: String?
    }

    var networkName: String
}
#endif
