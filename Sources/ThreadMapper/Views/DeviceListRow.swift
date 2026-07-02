import SwiftUI

struct DeviceListRow: View {
    let device: ThreadDevice

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(device.name).font(.headline)
                Text(device.productName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if device.isBorderRouter {
                Label("Border Router", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
            if let rssi = device.rssi {
                Text("\(rssi) dBm").font(.caption2).foregroundStyle(signalColor(for: rssi))
            }
            if let batt = device.batteryPercentage {
                Text("\(batt)%").font(.caption2).foregroundStyle(battColor(for: batt))
            }
        }
    }

    private func signalColor(for rssi: Int) -> Color {
        if rssi >= -50 { return .green }
        if rssi >= -65 { return .mint }
        if rssi >= -80 { return .orange }
        return .red
    }

    private func battColor(for batt: Int) -> Color {
        batt > 20 ? .green : .red
    }
}
