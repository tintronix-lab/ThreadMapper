import SwiftUI

// Equatable so the view model can skip reassigning `health` (and re-rendering the
// whole Dashboard) when a poll tick produces an identical score (fixes D4).
struct NetworkHealthScore: Equatable {
    let score: Int        // 0–100
    let grade: String     // A B C D F
    let color: Color
    let summary: String
    let issues: [Issue]
    let tips: [String]

    struct Issue: Identifiable, Equatable {
        // Stable ID derived from content so ForEach doesn't recreate rows on every poll tick.
        var id: String { "\(icon)|\(message)" }
        let message: String
        let icon: String
        let isCritical: Bool
        let affectedDevices: [ThreadDevice]
    }

    static func compute(devices: [ThreadDevice]) -> NetworkHealthScore {
        guard !devices.isEmpty else {
            return NetworkHealthScore(
                score: 0, grade: "F", color: .red,
                summary: "No devices found",
                issues: [Issue(message: "No Thread devices detected", icon: "antenna.radiowaves.left.and.right.slash", isCritical: true, affectedDevices: [])],
                tips: ["Open the Home app and add a Thread border router", "Ensure HomeKit access is granted in Settings"]
            )
        }

        var score = 100
        var issues: [Issue] = []
        var tips: [String] = []

        // Border router redundancy
        let borderRouters = devices.filter { $0.isBorderRouter }
        if borderRouters.isEmpty {
            score -= 40
            issues.append(Issue(message: "No border router detected", icon: "antenna.radiowaves.left.and.right.slash", isCritical: true, affectedDevices: []))
            tips.append("Add a HomePod mini or Apple TV as a Thread border router")
        } else if borderRouters.count == 1 {
            score -= 15
            issues.append(Issue(message: "Single border router — no redundancy", icon: "exclamationmark.triangle.fill", isCritical: false, affectedDevices: borderRouters))
            tips.append("Add a second border router for resilience against outages")
        }

        // Offline devices
        let offline = devices.filter(\.isOffline)
        if !offline.isEmpty {
            score -= min(30, offline.count * 12)
            issues.append(Issue(message: "\(offline.count) device\(offline.count == 1 ? "" : "s") offline", icon: "network.slash", isCritical: true, affectedDevices: offline))
        }

        // Weak signal
        let weak = devices.filter(\.isWeak)
        if !weak.isEmpty {
            score -= min(25, weak.count * 7)
            issues.append(Issue(message: "\(weak.count) device\(weak.count == 1 ? "" : "s") with weak signal", icon: "wifi.exclamationmark", isCritical: weak.count > 2, affectedDevices: weak))
            if weak.count > 1 { tips.append("Add a Thread router between weak devices and the border router") }
        }

        // Low battery
        let lowBatt = devices.filter { ($0.batteryPercentage ?? 100) < 15 }
        if !lowBatt.isEmpty {
            score -= 5
            issues.append(Issue(message: "\(lowBatt.count) device\(lowBatt.count == 1 ? "" : "s") battery < 15%", icon: "battery.25", isCritical: false, affectedDevices: lowBatt))
            tips.append("Replace or charge batteries in low-power devices")
        }

        // Channel interference — Thread channels that overlap 2.4 GHz WiFi channels 1, 6, or 11
        // WiFi ch 1 ≈ Thread ch 11-14, WiFi ch 6 ≈ Thread ch 17-19, WiFi ch 11 ≈ Thread ch 22-24
        let usedChannels = Set(devices.compactMap(\.channel))
        let wifiOverlapChannels: Set<Int> = [11, 12, 13, 14, 17, 18, 19, 22, 23, 24]
        let conflicting = usedChannels.intersection(wifiOverlapChannels)
        if !conflicting.isEmpty {
            let chList = conflicting.sorted().map { "CH\($0)" }.joined(separator: ", ")
            let channelDevices = devices.filter { device in
                guard let ch = device.channel else { return false }
                return conflicting.contains(ch)
            }
            score -= 5
            issues.append(Issue(
                message: "Thread channel overlaps 2.4 GHz WiFi (\(chList))",
                icon: "wifi.router.fill",
                isCritical: false,
                affectedDevices: channelDevices
            ))
            tips.append("Switch to Thread channels 15, 20, or 25 to reduce WiFi interference")
        }

        score = max(0, score)

        let (grade, color, summary): (String, Color, String)
        switch score {
        case 90...:
            (grade, color, summary) = ("A", .green, "Excellent — network is healthy")
        case 75..<90:
            (grade, color, summary) = ("B", .mint, "Good — minor issues present")
        case 60..<75:
            (grade, color, summary) = ("C", .yellow, "Fair — attention recommended")
        case 40..<60:
            (grade, color, summary) = ("D", .orange, "Poor — action needed")
        default:
            (grade, color, summary) = ("F", .red, "Critical — network issues detected")
        }

        return NetworkHealthScore(score: score, grade: grade, color: color, summary: summary, issues: issues, tips: tips)
    }
}
