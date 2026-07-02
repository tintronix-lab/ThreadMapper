import Foundation

let devices = [
    ThreadDevice(name: "Weak", manufacturer: "Test", productName: "X", deviceType: "Sensor",
                 uniqueIdentifier: UUID(), rssi: -90),
]
let score = SignalExtrapolator.coverageScore(for: devices)
print("coverage: \(score)")
assert(score >= 0 && score <= 1, "coverage score must be 0..1")
