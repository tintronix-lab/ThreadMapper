import SwiftUI

/// Shared visual vocabulary for the app and the widget.
/// Single source of truth — do not redeclare these mappings in views.
enum TMStyle {
    /// Health grade → color. Matches the scale used by the Dashboard hero
    /// ring, room rows, device rows, and all widget families.
    static func gradeColor(_ grade: String) -> Color {
        switch grade {
        case "A": return .green
        case "B": return .mint
        case "C": return .yellow
        case "D": return .orange
        default:  return .red
        }
    }

    /// Room name → SF Symbol.
    static func roomIcon(_ room: String) -> String {
        let l = room.lowercased()
        if l.contains("kitchen")  { return "oven.fill" }
        if l.contains("bedroom")  { return "bed.double.fill" }
        if l.contains("living")   { return "sofa.fill" }
        if l.contains("bath")     { return "shower.fill" }
        if l.contains("garage")   { return "car.fill" }
        if l.contains("office")   { return "desktopcomputer" }
        if l.contains("garden") || l.contains("outdoor") { return "leaf.fill" }
        if l.contains("hall")     { return "door.left.hand.open" }
        return "house.fill"
    }
}
