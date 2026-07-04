import SwiftUI

// Single source of truth for RSSI → visual mapping used across all views.
extension Int {
    var rssiColor: Color {
        if self < -80 { return .red }
        if self < -65 { return .orange }
        if self < -50 { return .mint }
        return .green
    }

    var rssiSystemIcon: String {
        self < -80 ? "wifi.exclamationmark" : "wifi"
    }

    var rssiQualityLabel: String {
        if self > -50 { return "Excellent" }
        if self > -65 { return "Good" }
        if self > -80 { return "Fair" }
        return "Weak"
    }

    // Link quality 1–4 used by MeshLink
    var rssiLinkQuality: Int {
        if self > -50 { return 4 }
        if self > -65 { return 3 }
        if self > -80 { return 2 }
        return 1
    }
}

extension Optional where Wrapped == Int {
    var rssiColor: Color { self?.rssiColor ?? .secondary }
    var rssiSystemIcon: String { self.map { $0.rssiSystemIcon } ?? "questionmark.circle" }
}
