import XCTest
import SwiftUI
import GRDB
@testable import MingSi

@MainActor
final class MentorUnderstandingEditorTests: XCTestCase {
    func testEditorRenderingAcrossSizeAndAccessibilityConfigurations() async throws {
        let repository = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let store = MentorFeatureStore(repository: repository, transport: EditorOfflineTransport())
        store.start(entry: "discuss")
        try await settle { store.state.session != nil && !store.state.isTransitioningSession }
        store.beginUnderstanding()
        store.saveUnderstanding(text: "完成了，不代表变好了。\n\n下次改完一个功能，我会先检查：用户是否更容易完成原来的任务？")
        try await settle { store.state.pendingUnderstandingOperations == 0 }

        let configurations: [(String, CGSize, ColorScheme, DynamicTypeSize)] = [
            ("small-light", CGSize(width: 375, height: 812), .light, .large),
            ("small-dark", CGSize(width: 375, height: 812), .dark, .large),
            ("landscape", CGSize(width: 812, height: 375), .light, .large),
            ("accessibility", CGSize(width: 375, height: 812), .dark, .accessibility5)
        ]
        for (name, size, scheme, typeSize) in configurations {
            let host = UIHostingController(rootView: MentorUnderstandingEditor(store: store)
                .environment(\.colorScheme, scheme)
                .environment(\.dynamicTypeSize, typeSize))
            let window = UIWindow(frame: CGRect(origin: .zero, size: size))
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.frame = window.bounds
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(150))
            let image = UIGraphicsImageRenderer(size: size).image { _ in
                host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "mentor-understanding-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
            if name == "accessibility" || name == "landscape" {
                let scroll = scrollViews(in: host.view).max { $0.contentSize.height < $1.contentSize.height }
                let outer = try XCTUnwrap(scroll)
                XCTAssertGreaterThan(outer.contentSize.height, outer.bounds.height)
                outer.setContentOffset(CGPoint(x: 0, y: max(0, outer.contentSize.height - outer.bounds.height)), animated: false)
                try await Task.sleep(for: .milliseconds(100))
                let bottom = UIGraphicsImageRenderer(size: size).image { _ in
                    host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
                }
                let bottomAttachment = XCTAttachment(image: bottom)
                bottomAttachment.name = "mentor-understanding-\(name)-bottom"
                bottomAttachment.lifetime = .keepAlways
                add(bottomAttachment)
            }
            window.isHidden = true
            window.rootViewController = nil
        }
        // Rendering must not confirm, resubmit or create another understanding.
        let notes = try await repository.understandings(sessionID: XCTUnwrap(store.state.session?.id))
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes.first?.state, .draft)
        XCTAssertEqual(notes.first?.text, store.state.understandingInputText)
    }

    private func scrollViews(in view: UIView) -> [UIScrollView] {
        ((view as? UIScrollView).map { [$0] } ?? []) + view.subviews.flatMap { scrollViews(in: $0) }
    }

    private func settle(_ condition: () -> Bool) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Editor fixture did not settle")
    }
}

private struct EditorOfflineTransport: MentorTransport {
    func complete(_ request: LLMRequest) async throws -> Data {
        XCTFail("Editing a personal understanding must stay offline")
        throw CancellationError()
    }
}
