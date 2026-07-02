import Foundation

enum ThreadMapperError: LocalizedError {
    case homeKitNotAuthorized
    case noThreadDevicesFound
    case invalidCoordinate
    case networkTimeout

    var errorDescription: String? {
        switch self {
        case .homeKitNotAuthorized: return "HomeKit access was not authorized."
        case .noThreadDevicesFound: return "No Thread devices were found."
        case .invalidCoordinate: return "Invalid coordinate provided."
        case .networkTimeout: return "Network request timed out."
        }
    }
}
