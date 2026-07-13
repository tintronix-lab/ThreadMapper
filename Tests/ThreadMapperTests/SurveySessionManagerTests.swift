import Testing
import Foundation
import CoreLocation
@testable import ThreadMapper

@Suite("SurveySessionManager")
@MainActor
struct SurveySessionManagerTests {

    private static let coord = CLLocationCoordinate2D(latitude: 37.33, longitude: -122.01)

    // MARK: - recordSample

    @Test("recordSample increments sampleCount")
    func recordIncrementsSampleCount() {
        let mgr = SurveySessionManager()
        mgr.recordSample(deviceID: "d1", rssi: -65, location: nil)
        mgr.recordSample(deviceID: "d2", rssi: -70, location: nil)
        #expect(mgr.sampleCount == 2)
    }

    @Test("currentMeanRSSI is average of all recorded RSSI values")
    func meanRSSIIsAverage() {
        let mgr = SurveySessionManager()
        mgr.recordSample(deviceID: "d1", rssi: -60, location: nil)
        mgr.recordSample(deviceID: "d2", rssi: -80, location: nil)
        #expect(mgr.currentMeanRSSI == -70.0)
    }

    @Test("currentWeakIDs contains devices with RSSI strictly below -80")
    func weakIDsThreshold() {
        let mgr = SurveySessionManager()
        mgr.recordSample(deviceID: "strong", rssi: -80, location: nil)  // -80 is NOT weak
        mgr.recordSample(deviceID: "weak",   rssi: -81, location: nil)  // -81 IS weak
        #expect(!mgr.currentWeakIDs.contains("strong"))
        #expect(mgr.currentWeakIDs.contains("weak"))
    }

    // MARK: - endSession

    @Test("endSession returns nil when no samples have been recorded")
    func endSessionNilWhenEmpty() {
        let mgr = SurveySessionManager()
        #expect(mgr.endSession() == nil)
    }

    @Test("endSession returns nil when no sample has a valid location")
    func endSessionNilWhenNoLocation() {
        let mgr = SurveySessionManager()
        mgr.recordSample(deviceID: "d1", rssi: -65, location: nil)
        #expect(mgr.endSession() == nil)
    }

    @Test("endSession computes correct mean RSSI from all samples")
    func endSessionMeanRSSI() {
        let mgr = SurveySessionManager()
        mgr.recordSample(deviceID: "d1", rssi: -60, location: Self.coord)
        mgr.recordSample(deviceID: "d2", rssi: -80, location: nil)
        let point = mgr.endSession()
        #expect(point?.meanRSSI == -70.0)
    }

    @Test("endSession uses the first sample's coordinate")
    func endSessionUsesFirstLocation() {
        let mgr = SurveySessionManager()
        let first  = CLLocationCoordinate2D(latitude: 10.0, longitude: 20.0)
        let second = CLLocationCoordinate2D(latitude: 99.0, longitude: 99.0)
        mgr.recordSample(deviceID: "d1", rssi: -65, location: first)
        mgr.recordSample(deviceID: "d2", rssi: -70, location: second)
        let point = mgr.endSession()
        #expect(point?.latitude  == 10.0)
        #expect(point?.longitude == 20.0)
    }

    @Test("endSession records correct sampleCount on the returned point")
    func endSessionSampleCount() {
        let mgr = SurveySessionManager()
        mgr.recordSample(deviceID: "d1", rssi: -60, location: Self.coord)
        mgr.recordSample(deviceID: "d2", rssi: -70, location: nil)
        let point = mgr.endSession()
        #expect(point?.sampleCount == 2)
    }

    @Test("endSession propagates the room label to the returned point")
    func endSessionRoomLabel() {
        let mgr = SurveySessionManager()
        mgr.recordSample(deviceID: "d1", rssi: -65, location: Self.coord)
        let point = mgr.endSession(room: "Kitchen")
        #expect(point?.room == "Kitchen")
    }

    @Test("endSession marks weak devices (RSSI < -80) in the returned point")
    func endSessionWeakDevices() {
        let mgr = SurveySessionManager()
        mgr.recordSample(deviceID: "strong", rssi: -70, location: Self.coord)
        mgr.recordSample(deviceID: "weak1",  rssi: -85, location: nil)
        let point = mgr.endSession()
        #expect(point?.weakDeviceList == ["weak1"])
    }

    @Test("endSession clears samples, meanRSSI, and weakIDs after returning")
    func endSessionClearsSamples() {
        let mgr = SurveySessionManager()
        mgr.recordSample(deviceID: "d1", rssi: -65, location: Self.coord)
        _ = mgr.endSession()
        #expect(mgr.sampleCount == 0)
        #expect(mgr.currentMeanRSSI == nil)
        #expect(mgr.currentWeakIDs.isEmpty)
    }

    // MARK: - startSession

    @Test("startSession resets sampleCount and derived state")
    func startSessionResetsState() {
        let mgr = SurveySessionManager()
        mgr.recordSample(deviceID: "d1", rssi: -65, location: nil)
        mgr.recordSample(deviceID: "d2", rssi: -82, location: nil)
        mgr.startSession()
        #expect(mgr.sampleCount == 0)
        #expect(mgr.currentMeanRSSI == nil)
        #expect(mgr.currentWeakIDs.isEmpty)
    }
}
