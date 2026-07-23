import CoreSpotlight
import UniformTypeIdentifiers

enum SpotlightService {
    private static let domain  = "com.tintronixlab.ThreadMapper.devices"
    private static let idPrefix = "com.tintronixlab.ThreadMapper.device."

    static func index(_ devices: [ThreadDevice]) {
        guard !devices.isEmpty else { removeAll(); return }

        let items = devices.map { device -> CSSearchableItem in
            let attrs = CSSearchableItemAttributeSet(contentType: UTType.item)
            attrs.title = device.name

            var parts: [String] = []
            if let room = device.room { parts.append(room) }
            if      device.isBorderRouter { parts.append("Border Router") } else if device.isRouter { parts.append("Router") } else { parts.append("Thread Device") }
            attrs.contentDescription = parts.joined(separator: " · ")

            var keywords = ["Thread", "network", "HomeKit"]
            if let room = device.room { keywords.append(room) }
            attrs.keywords = keywords

            return CSSearchableItem(
                uniqueIdentifier: idPrefix + device.uniqueIdentifier.uuidString,
                domainIdentifier: domain,
                attributeSet: attrs
            )
        }
        CSSearchableIndex.default().indexSearchableItems(items) { _ in }
    }

    static func removeAll() {
        CSSearchableIndex.default().deleteSearchableItems(
            withDomainIdentifiers: [domain]) { _ in }
    }
}
