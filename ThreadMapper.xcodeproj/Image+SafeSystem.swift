import SwiftUI

// Provides a safe way to load SF Symbols with a runtime fallback when a symbol is unavailable
public extension Image {
    /// Returns an Image initialized with the given SF Symbol name if it exists on the current OS,
    /// otherwise returns an Image using the provided fallback symbol name.
    /// - Parameters:
    ///   - name: Preferred SF Symbol name.
    ///   - fallback: Fallback SF Symbol name to use if `name` is unavailable at runtime.
    static func safeSystem(_ name: String, fallback: String) -> Image {
        #if canImport(UIKit)
        if UIImage(systemName: name) != nil {
            return Image(systemName: name)
        } else {
            return Image(systemName: fallback)
        }
        #elseif canImport(AppKit)
        // On macOS, NSImage(systemSymbolName:accessibilityDescription:) is available on 11+
        if let _ = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
            return Image(systemName: name)
        } else {
            return Image(systemName: fallback)
        }
        #else
        // Fallback platforms: just use the preferred name
        return Image(systemName: name)
        #endif
    }
}
