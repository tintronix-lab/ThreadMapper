import SwiftUI

/// Single source of truth for the RSSI bands used across the app.
/// A reading at or below `weak` is considered weak; `offlineSentinel` is the
/// magic value the discovery layer reports for unreachable devices.
enum SignalThresholds {
    static let excellent = -50
    static let good = -65
    static let weak = -80
    static let offlineSentinel = -100
}

// Single source of truth for RSSI → visual mapping used across all views.
extension Int {
    /// True when this reading falls in the "weak" band (worse than -80 dBm).
    var isWeakRSSI: Bool { self < SignalThresholds.weak }

    var rssiColor: Color {
        if self < SignalThresholds.weak { return .red }
        if self < SignalThresholds.good { return .orange }
        if self < SignalThresholds.excellent { return .mint }
        return .green
    }

    var rssiSystemIcon: String {
        self < SignalThresholds.weak ? "wifi.exclamationmark" : "wifi"
    }

    var rssiQualityLabel: LocalizedStringResource {
        if self > SignalThresholds.excellent { return "Excellent" }
        if self > SignalThresholds.good { return "Good" }
        if self > SignalThresholds.weak { return "Fair" }
        return "Weak"
    }

    // Link quality 1–4 used by MeshLink
    var rssiLinkQuality: Int {
        if self > SignalThresholds.excellent { return 4 }
        if self > SignalThresholds.good { return 3 }
        if self > SignalThresholds.weak { return 2 }
        return 1
    }
}

extension Optional where Wrapped == Int {
    var rssiColor: Color { self?.rssiColor ?? .secondary }
    var rssiSystemIcon: String { self.map { $0.rssiSystemIcon } ?? "questionmark.circle" }
}
