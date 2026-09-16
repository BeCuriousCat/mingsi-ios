import XCTest
import UIKit
@testable import MingSi

@MainActor
final class MentorReadingPositionTests: XCTestCase {
    func testShortContentClampsAtBottomWithoutOverwritingTheSavedOffset() async throws {
        let fixture = ReadingScrollFixture()
        defer { fixture.close() }
        fixture.scroll.contentSize.height = 1700
        let coordinator = MentorReadingPositionCoordinator()
        defer { coordinator.reset() }
        let lesson = fixture.lesson(section: .boundary, offset: 180, layoutKey: "320/large")
        var saves: [MentorReadingPositionCoordinator.Position] = []
        coordinator.attach(fixture.scroll)
        coordinator.update(lesson: lesson, frames: fixture.frames(), viewport: fixture.viewport,
            layoutKey: "320/large", canSave: true) { saves.append($0) }
        try await settle { abs(fixture.scroll.contentOffset.y - 1200) < 0.5 }
        coordinator.update(lesson: lesson, frames: fixture.frames(), viewport: fixture.viewport,
            layoutKey: "320/large", canSave: true) { saves.append($0) }
        coordinator.flush()
        XCTAssertTrue(saves.isEmpty, "Native scroll bounds must not replace the historical reading offset")
    }

    func testNativeMarkersObserveScrollingAndFlushBeforeNavigation() async throws {
        let fixture = ReadingScrollFixture()
        defer { fixture.close() }
        fixture.scroll.contentInset.top = 60 // navigation bar / safe area
        let coordinator = MentorReadingPositionCoordinator()
        let geometry = MentorReadingGeometry()
        defer { geometry.reset(); coordinator.reset() }
        let lesson = fixture.lesson(section: .example, offset: 85, layoutKey: "320/large")
        var saves: [MentorReadingPositionCoordinator.Position] = []
        geometry.configure(coordinator: coordinator, lesson: lesson, layoutKey: "320/large", canSave: true,
            save: { saves.append($0) }, presented: { _ in })
        fixture.mountMarkers(geometry: geometry)
        try await settle { abs(fixture.scroll.contentOffset.y - 625) < 0.5 }
        fixture.scroll.setContentOffset(CGPoint(x: 0, y: 680), animated: false)
        // Navigation can precede both the next sampling task and debounce.
        geometry.flush()
        coordinator.flush()
        XCTAssertEqual(saves, [.init(itemID: fixture.itemID, section: .example, offset: 140, layoutKey: "320/large")])
        geometry.reset()
        coordinator.reset()
        fixture.scroll.setContentOffset(CGPoint(x: 0, y: 1450), animated: false)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(saves.count, 1, "A dismissed reader must not keep sampling its old scroll view")
    }

    func testSameLayoutRestoresOffsetAndSavesSubsequentScrollWithoutRestoreFeedback() async throws {
        let fixture = ReadingScrollFixture()
        defer { fixture.close() }
        let coordinator = MentorReadingPositionCoordinator()
        defer { coordinator.reset() }
        let lesson = fixture.lesson(section: .example, offset: 85, layoutKey: "320/large")
        var saves: [MentorReadingPositionCoordinator.Position] = []
        coordinator.attach(fixture.scroll)
        coordinator.update(lesson: lesson, frames: fixture.frames(), viewport: fixture.viewport,
            layoutKey: "320/large", canSave: true) { saves.append($0) }
        try await settle { abs(fixture.scroll.contentOffset.y - 685) < 0.5 }

        // Deliver the geometry produced by restoration, as SwiftUI would.
        coordinator.update(lesson: lesson, frames: fixture.frames(), viewport: fixture.viewport,
            layoutKey: "320/large", canSave: true) { saves.append($0) }
        coordinator.flush()
        XCTAssertTrue(saves.isEmpty, "Restoring a position must not create a new reading revision")

        fixture.scroll.setContentOffset(CGPoint(x: 0, y: 740), animated: false)
        coordinator.update(lesson: lesson, frames: fixture.frames(), viewport: fixture.viewport,
            layoutKey: "320/large", canSave: true) { saves.append($0) }
        coordinator.flush()
        XCTAssertEqual(saves, [.init(itemID: fixture.itemID, section: .example,
                                    offset: 140, layoutKey: "320/large")])
        coordinator.update(lesson: lesson, frames: fixture.frames(), viewport: fixture.viewport,
            layoutKey: "320/large", canSave: true) { saves.append($0) }
        coordinator.flush()
        XCTAssertEqual(saves.count, 1, "Repeated geometry for the same position must not be offered twice")
    }

    func testLayoutChangeKeepsLatestPendingSectionAndRestoresItsStart() async throws {
        let fixture = ReadingScrollFixture()
        defer { fixture.close() }
        let coordinator = MentorReadingPositionCoordinator()
        defer { coordinator.reset() }
        let oldLesson = fixture.lesson(section: .claim, offset: 40, layoutKey: "320/large")
        var saves: [MentorReadingPositionCoordinator.Position] = []
        coordinator.attach(fixture.scroll)
        coordinator.update(lesson: oldLesson, frames: fixture.frames(), viewport: fixture.viewport,
            layoutKey: "320/large", canSave: true) { saves.append($0) }
        try await settle { abs(fixture.scroll.contentOffset.y - 140) < 0.5 }

        fixture.scroll.setContentOffset(CGPoint(x: 0, y: 1268), animated: false)
        coordinator.update(lesson: oldLesson, frames: fixture.frames(), viewport: fixture.viewport,
            layoutKey: "320/large", canSave: true) { saves.append($0) }
        XCTAssertTrue(saves.isEmpty, "The latest paragraph is still inside the debounce window")

        fixture.useExpandedTextLayout()
        // The Store snapshot can still contain the older section when the new
        // geometry arrives. The coordinator owns the latest pending scroll.
        coordinator.update(lesson: oldLesson, frames: fixture.frames(), viewport: fixture.viewport,
            layoutKey: "500/accessibility3", canSave: true) { saves.append($0) }
        try await settle { abs(fixture.scroll.contentOffset.y - 1600) < 0.5 }
        XCTAssertEqual(saves, [.init(itemID: fixture.itemID, section: .boundary,
                                    offset: 68, layoutKey: "320/large")])

        let current = fixture.lesson(section: .boundary, offset: 68, layoutKey: "320/large")
        coordinator.update(lesson: current, frames: fixture.frames(), viewport: fixture.viewport,
            layoutKey: "500/accessibility3", canSave: true) { saves.append($0) }
        coordinator.flush()
        XCTAssertEqual(saves.count, 1, "Layout fallback must not pretend the user scrolled")
        fixture.scroll.setContentOffset(CGPoint(x: 0, y: 1637), animated: false)
        coordinator.update(lesson: current, frames: fixture.frames(), viewport: fixture.viewport,
            layoutKey: "500/accessibility3", canSave: true) { saves.append($0) }
        coordinator.flush()
        XCTAssertEqual(saves.last, MentorReadingPositionCoordinator.Position(itemID: fixture.itemID, section: .boundary,
                                         offset: 37, layoutKey: "500/accessibility3"))
    }

    func testMissingTargetDuringRestoreCanRetryWhenItsFrameReturns() async throws {
        let fixture = ReadingScrollFixture()
        defer { fixture.close() }
        let coordinator = MentorReadingPositionCoordinator()
        defer { coordinator.reset() }
        let lesson = fixture.lesson(section: .example, offset: 64, layoutKey: "320/large")
        var saves: [MentorReadingPositionCoordinator.Position] = []
        coordinator.attach(fixture.scroll)
        coordinator.update(lesson: lesson, frames: fixture.frames(), viewport: fixture.viewport,
            layoutKey: "320/large", canSave: true) { saves.append($0) }
        // Replace the snapshot before the restore task's first actor turn.
        coordinator.update(lesson: lesson, frames: fixture.frames(excluding: .example), viewport: fixture.viewport,
            layoutKey: "320/large", canSave: true) { saves.append($0) }
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(fixture.scroll.contentOffset.y, 0, accuracy: 0.5)

        coordinator.update(lesson: lesson, frames: fixture.frames(), viewport: fixture.viewport,
            layoutKey: "320/large", canSave: true) { saves.append($0) }
        try await settle { abs(fixture.scroll.contentOffset.y - 664) < 0.5 }
        coordinator.flush()
        XCTAssertTrue(saves.isEmpty)
    }

    func testReadOnlyHistoryRestoresButNeverWritesPosition() async throws {
        let fixture = ReadingScrollFixture()
        defer { fixture.close() }
        let coordinator = MentorReadingPositionCoordinator()
        defer { coordinator.reset() }
        let lesson = fixture.lesson(section: .boundary, offset: 110, layoutKey: "320/large")
        var saves: [MentorReadingPositionCoordinator.Position] = []
        coordinator.attach(fixture.scroll)
        coordinator.update(lesson: lesson, frames: fixture.frames(), viewport: fixture.viewport,
            layoutKey: "320/large", canSave: false) { saves.append($0) }
        try await settle { abs(fixture.scroll.contentOffset.y - 1310) < 0.5 }
        fixture.scroll.setContentOffset(CGPoint(x: 0, y: 1450), animated: false)
        coordinator.update(lesson: lesson, frames: fixture.frames(), viewport: fixture.viewport,
            layoutKey: "320/large", canSave: false) { saves.append($0) }
        coordinator.flush()
        for _ in 0..<20 { await Task.yield() }
        XCTAssertTrue(saves.isEmpty, "Viewing historical content must preserve its saved reading position")
    }

    private func settle(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Reading-position restoration did not settle", file: file, line: line)
    }
}

/// Real UIKit coordinate conversion keeps the tests sensitive to contentOffset,
/// viewport origin and section geometry rather than duplicating restore math.
@MainActor
private final class ReadingScrollFixture {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 600, height: 800))
    let scroll = UIScrollView(frame: CGRect(x: 20, y: 40, width: 320, height: 500))
    let itemID = UUID()
    let sessionID = UUID()
    private var sections: [MentorReadingSection: UIView] = [:]

    init() {
        let controller = UIViewController()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.frame = window.bounds
        scroll.contentInsetAdjustmentBehavior = .never
        controller.view.addSubview(scroll)
        for (section, y, height) in [
            (MentorReadingSection.title, CGFloat(0), CGFloat(50)),
            (.claim, 100, 400), (.example, 600, 500), (.boundary, 1200, 700), (.observation, 2000, 200)
        ] {
            let view = UIView(frame: CGRect(x: 0, y: y, width: 320, height: height))
            scroll.addSubview(view)
            sections[section] = view
        }
        scroll.contentSize = CGSize(width: 320, height: 3000)
        window.layoutIfNeeded()
    }

    var viewport: CGRect { scroll.convert(scroll.bounds, to: window) }

    func mountMarkers(geometry: MentorReadingGeometry) {
        for (section, view) in sections {
            let marker = MentorReadingMarker.Marker(frame: view.bounds)
            marker.itemID = itemID
            marker.section = section
            marker.geometry = geometry
            view.addSubview(marker)
        }
        window.layoutIfNeeded()
    }

    func frames(excluding omitted: MentorReadingSection? = nil) -> [MentorReadingAnchor: CGRect] {
        Dictionary(uniqueKeysWithValues: sections.compactMap { section, view in
            guard section != omitted else { return nil }
            return (MentorReadingAnchor(itemID: itemID, section: section), view.convert(view.bounds, to: window))
        })
    }

    func useExpandedTextLayout() {
        scroll.frame.size.width = 500
        for (section, y, height) in [
            (MentorReadingSection.title, CGFloat(0), CGFloat(75)),
            (.claim, 120, 600), (.example, 850, 650), (.boundary, 1600, 900), (.observation, 2600, 250)
        ] {
            sections[section]?.frame = CGRect(x: 0, y: y, width: 500, height: height)
        }
        scroll.contentSize = CGSize(width: 500, height: 3500)
        window.layoutIfNeeded()
    }

    func lesson(section: MentorReadingSection, offset: Double, layoutKey: String?) -> MentorSavedLesson {
        let material = MentorLesson(id: "L01", version: "1.0", editorialOrder: 1,
            title: "Reading-position fixture", theme: MentorLesson.Theme.allCases[0], applicableContexts: ["UI geometry test"],
            claim: "Claim", example: "Example", boundary: "Boundary", observation: "Observation",
            sourceType: .teachingExample, citations: [], contentHash: "geometry-test-only",
            review: .init(status: .draft, reviewedBy: nil, reviewedAt: nil, note: nil))
        return MentorSavedLesson(id: itemID, sessionID: sessionID, lesson: material,
            readingSection: section, readingRevision: 1, readingOffset: offset, readingLayoutKey: layoutKey)
    }

    func close() {
        window.isHidden = true
        window.rootViewController = nil
    }
}
