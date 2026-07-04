import SwiftUI

struct NetworkHealthScore {
    let score: Int        // 0–100
    let grade: String     // A B C D F
    let color: Color
    let summary: String
    let issues: [Issue]
    let tips: [String]

    struct Issue: Identifiable {
        let id = UUID()
        let message: String
        let icon: String
        let isCritical: Bool
    }

    static func compute(devices: [ThreadDevice]) -> NetworkHealthScore {
        guard !devices.isEmpty else {
            return NetworkHealthScore(
                score: 0, grade: "F", color: .red,
                summary: "No devices found",
                issues: [Issue(message: "No Thread devices detected", icon: "antenna.radiowaves.left.and.right.slash", isCritical: true)],
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
            issues.append(Issue(message: "No border router detected", icon: "antenna.radiowaves.left.and.right.slash", isCritical: true))
            tips.append("Add a HomePod mini or Apple TV as a Thread border router")
        } else if borderRouters.count == 1 {
            score -= 15
            issues.append(Issue(message: "Single border router — no redundancy", icon: "exclamationmark.triangle.fill", isCritical: false))
            tips.append("Add a second border router for resilience against outages")
        }

        // Offline devices
        let offline = devices.filter { $0.rssi == -100 }
        if !offline.isEmpty {
            score -= min(30, offline.count * 12)
            issues.append(Issue(message: "\(offline.count) device\(offline.count == 1 ? "" : "s") offline", icon: "network.slash", isCritical: true))
        }

        // Weak signal
        let weak = devices.filter { let r = $0.rssi ?? -65; return r < -80 && r > -100 }
        if !weak.isEmpty {
            score -= min(25, weak.count * 7)
            issues.append(Issue(message: "\(weak.count) device\(weak.count == 1 ? "" : "s") with weak signal", icon: "wifi.exclamationmark", isCritical: weak.count > 2))
            if weak.count > 1 { tips.append("Add a Thread router between weak devices and the border router") }
        }

        // Low battery
        let lowBatt = devices.filter { ($0.batteryPercentage ?? 100) < 15 }
        if !lowBatt.isEmpty {
            score -= 5
            issues.append(Issue(message: "\(lowBatt.count) device\(lowBatt.count == 1 ? "" : "s") battery < 15%", icon: "battery.25", isCritical: false))
            tips.append("Replace or charge batteries in low-power devices")
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
