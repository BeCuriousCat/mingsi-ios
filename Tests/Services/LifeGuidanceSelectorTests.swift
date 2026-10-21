import XCTest
@testable import MingSi

final class LifeGuidanceSelectorTests: XCTestCase {
    private let selector = LifeGuidanceSelector()

    func testStableDaySelectionAndExtremeQASeeds() {
        XCTAssertEqual(selector.dailySelection(dayKey: "2026-10-05"), selector.dailySelection(dayKey: "2026-10-05"))
        XCTAssertNotNil(selector.dailySelection(dayKey: "2026-10-05").flatMap(selector.item(for:)))
        XCTAssertEqual(selector.dailySelection(dayKey: "ignored", seed: 2)?.itemID, selector.approvedItems()[2].id)
        XCTAssertNotNil(selector.dailySelection(dayKey: "ignored", seed: Int.min))
    }

    func testDraftAndRetiredContentCannotBeRecommended() {
        for status in [LifeGuidanceReviewStatus.draft, .retired] {
            var item = selector.approvedItems()[0]
            item.reviewStatus = status
            XCTAssertNil(LifeGuidanceSelector(catalog: [item]).dailySelection(dayKey: "2026-10-05"))
        }
    }

    func testVersionBoundaryAndSourceRequiredForPublication() {
        let item = selector.approvedItems()[0]
        var missingVersion = item; missingVersion.version = " "
        var missingBoundary = item; missingBoundary.boundary = " "
        var missingSource = item; missingSource.citations = []
        var badURL = item; badURL.citations[0].url = "javascript:alert(1)"
        var missingAdaptation = item; missingAdaptation.adaptationNote = ""
        for invalid in [missingVersion, missingBoundary, missingSource, badURL, missingAdaptation] {
            XCTAssertFalse(LifeGuidanceSelector.isPublishable(invalid))
            XCTAssertTrue(LifeGuidanceSelector(catalog: [invalid]).approvedItems().isEmpty)
        }
    }

    func testAllReleasedContentHasTraceableAttribution() {
        XCTAssertFalse(selector.approvedItems().isEmpty)
        for item in selector.approvedItems() {
            XCTAssertTrue(LifeGuidanceSelector.isPublishable(item))
            XCTAssertNotNil(item.sourceURL)
            XCTAssertEqual(item.contentHash.count, 64)
        }
    }

    func testLocalDayDistanceDoesNotDependOnDaylightSavingHours() {
        XCTAssertEqual(LifeGuidanceCalendar.distance(from: "2026-03-07", to: "2026-03-21"), 14)
        XCTAssertEqual(LifeGuidanceCalendar.distance(from: "2026-10-25", to: "2026-11-08"), 14)
    }
}
