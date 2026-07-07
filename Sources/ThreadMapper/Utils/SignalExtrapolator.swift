import Foundation

struct SignalExtrapolator {
    static func coverageScore(for devices: [ThreadDevice]) -> Double {
        guard !devices.isEmpty else { return 0.0 }
        let routers = devices.filter(\.isRoutingCapable)
        let routerRatio = Double(routers.count) / Double(devices.count)

        let avgRSSI = devices.compactMap { $0.rssi }
            .map { Double($0) }
            .reduce(0, +) / Double(max(devices.count, 1))

        let rssiScore = max(0, min(1, (avgRSSI + 90) / 40))
        return (routerRatio * 0.6 + rssiScore * 0.4)
    }

    static func recommendations(for devices: [ThreadDevice]) -> [String] {
        var recs: [String] = []
        let routers = devices.filter(\.isRoutingCapable)
        if routers.isEmpty { recs.append("Add at least one Thread border router.") }
        if devices.count > 3 && routers.count == 1 {
            recs.append("Add a second router to improve mesh redundancy.")
        }
        let weak = devices.filter { ($0.rssi ?? -50) < -80 }
        if !weak.isEmpty {
            recs.append("\(weak.count) devices have weak signal; move a router closer.")
        }
        return recs
    }
}
