@testable import ThreadMapper
import XCTest

/// Guards `AINetworkAnalyzer.relativeAge`. Event ages are interpolated into the
/// prompt and the model echoes them verbatim, so raw minutes previously leaked
/// into user-facing summaries as nonsense like "7391m ago".
// `AINetworkAnalyzer` is @MainActor-isolated (it reads live `ThreadDevice`
// objects the poll loop mutates on the main actor), so its tests are too.
@available(iOS 26, *)
@MainActor
final class RelativeAgeTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func age(_ secondsAgo: TimeInterval) -> String {
        AINetworkAnalyzer.relativeAge(now.addingTimeInterval(-secondsAgo), now: now)
    }

    func testUnderNinetySecondsReadsAsJustNow() {
        XCTAssertEqual(age(0), "just now")
        XCTAssertEqual(age(30), "just now")
    }

    func testMinutes() {
        XCTAssertEqual(age(5 * 60), "5 minutes ago")
        XCTAssertEqual(age(59 * 60), "59 minutes ago")
    }

    func testHoursAreSingularAndPlural() {
        XCTAssertEqual(age(3600), "1 hour ago")
        XCTAssertEqual(age(4 * 3600), "4 hours ago")
    }

    func testDaysAreSingularAndPlural() {
        XCTAssertEqual(age(86_400), "1 day ago")
        XCTAssertEqual(age(5 * 86_400), "5 days ago")
    }

    /// The exact regression seen in the Activity AI Summary.
    func testLongIntervalIsHumanisedNotRawMinutes() {
        let text = age(7391 * 60)          // 7391 minutes ≈ 5.1 days
        XCTAssertEqual(text, "5 days ago")
        XCTAssertFalse(text.contains("7391"), "raw minutes must never reach the user")
    }

    /// A clock skew that puts an event slightly in the future must not produce
    /// a negative age.
    func testFutureTimestampClampsToJustNow() {
        XCTAssertEqual(age(-120), "just now")
    }
}
