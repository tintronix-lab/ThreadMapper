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
        switch rssi {
        case -50...: .green
        case -65...: .mint
        case -80...: .orange
        default: .red
        }
    }

    private func battColor(for batt: Int) -> Color {
        batt > 20 ? .green : .red
    }
}
