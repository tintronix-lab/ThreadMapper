import Foundation
import Combine
import OSLog

private let log = Logger(subsystem: "com.tintronixlab.ThreadMapper", category: "DashboardPrefs")

final class DashboardPreferences: ObservableObject {
    @Published var allDevicesExpanded: Bool {
        didSet {
            UserDefaults.standard.set(allDevicesExpanded, forKey: "dashboard.allDevicesExpanded")
            log.debug("wrote allDevicesExpanded=\(self.allDevicesExpanded)")
        }
    }
    @Published var roomCoverageExpanded: Bool {
        didSet {
            UserDefaults.standard.set(roomCoverageExpanded, forKey: "dashboard.roomCoverageExpanded")
            log.debug("wrote roomCoverageExpanded=\(self.roomCoverageExpanded)")
        }
    }

    init() {
        let ud = UserDefaults.standard
        let all  = ud.object(forKey: "dashboard.allDevicesExpanded")   as? Bool
        let room = ud.object(forKey: "dashboard.roomCoverageExpanded") as? Bool
        log.debug("init: allDevicesExpanded raw=\(String(describing: all)), roomCoverageExpanded raw=\(String(describing: room))")
        allDevicesExpanded   = all  ?? true
        roomCoverageExpanded = room ?? true
    }
}
