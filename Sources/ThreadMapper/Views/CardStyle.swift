import SwiftUI

extension View {
    /// Standard card chrome used across the app: secondary grouped background
    /// clipped to a continuous rounded rectangle. Radius 12 is the app-wide
    /// default; larger radii are used for hero/summary cards.
    func cardBackground(cornerRadius: CGFloat = 12) -> some View {
        background(Color(UIColor.secondarySystemGroupedBackground),
                   in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
