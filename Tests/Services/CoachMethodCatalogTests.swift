import XCTest
@testable import MingSi

final class CoachMethodCatalogTests: XCTestCase {
    func testBookCandidatesNeedCurrentEvidenceAndHaveBoundedSourceScope() throws {
        let catalog = try CoachMethodCatalog.loadBundled()
        XCTAssertEqual(catalog.methods.count, 5)
        XCTAssertEqual(Set(catalog.methods.map(\.id)).count, 5)
        for method in catalog.methods {
            XCTAssertFalse(method.snapshot.sourceScope.isEmpty)
            XCTAssertEqual(method.snapshot.contentHash.count, 64)
            XCTAssertFalse(method.snapshot.sourceHashes.isEmpty)
            if !method.isAvailable(promptVersion: CoachMethodCatalog.currentPromptVersion) {
                XCTAssertNil(CoachMethodCatalog.usableSnapshot(id: method.id))
                XCTAssertFalse(method.holdReason.isEmpty)
            }
        }
        XCTAssertEqual(BuiltinLensCatalog.items.count, 10)
        for lens in BuiltinLensCatalog.items {
            XCTAssertEqual(CoachMethodCatalog.usableSnapshot(id: "lens." + lens.id)?.title, lens.title)
        }
        XCTAssertNil(CoachMethodCatalog.usableSnapshot(id: "untrusted-external-method"))
    }

    func testQualityGateRejectsNoGainCriticalFailureStaleContentAndPrompt() throws {
        let snapshot = try XCTUnwrap(CoachMethodCatalog.bundled?.methods.first?.snapshot)
        let required = ["positive-1", "positive-2", "neighbor", "stop", "missing", "changed"]
        func evidence(passed: [String]? = nil, gain: [String] = ["positive-1"], critical: [String] = [],
                      hash: String? = nil, prompt: String = "2.18.0", decision: String = "scopedTrial") -> CoachMethodEvaluation {
            CoachMethodEvaluation(batchID: "synthetic-unit", reportPath: "unit-fixture", reviewer: "AI test fixture",
                contentHash: hash ?? snapshot.contentHash, promptVersion: prompt, passedCases: passed ?? required,
                requiredCases: required, improvedPairs: gain, criticalFailures: critical, decision: decision)
        }
        XCTAssertTrue(evidence().permits(snapshot, promptVersion: "2.18.0"))
        XCTAssertTrue(evidence(passed: required.filter { $0 != "neighbor" }).permits(snapshot, promptVersion: "2.18.0"))
        XCTAssertFalse(evidence(gain: []).permits(snapshot, promptVersion: "2.18.0"))
        XCTAssertFalse(evidence(gain: ["fictional-pair"]).permits(snapshot, promptVersion: "2.18.0"))
        XCTAssertFalse(evidence(critical: ["fabricated-fact"]).permits(snapshot, promptVersion: "2.18.0"))
        XCTAssertFalse(evidence(hash: "old-content").permits(snapshot, promptVersion: "2.18.0"))
        XCTAssertFalse(evidence(prompt: "2.17.0").permits(snapshot, promptVersion: "2.18.0"))
        XCTAssertFalse(evidence(decision: "hold").permits(snapshot, promptVersion: "2.18.0"))
        for boundary in ["stop", "missing", "changed"] {
            XCTAssertFalse(evidence(passed: required.filter { $0 != boundary }).permits(snapshot, promptVersion: "2.18.0"))
        }
    }

    func testFrozenMethodSurvivesReplayWithoutBecomingUserEvidenceAndLegacyDecodes() throws {
        let method = try XCTUnwrap(CoachMethodCatalog.bundled?.methods.first?.snapshot)
        let session = MentorSession(id: UUID(), initialEntry: "discuss", lifecycle: .active,
            draftText: "", draftRevision: 0, activityAt: .now)
        let item = MentorTimelineItem(id: UUID(), sessionID: session.id, sequence: 1, kind: .user,
            payloadJSON: "{\"text\":\"请比较实现目标的两种方式。\"}")
        let builder = MentorContextBuilder()
        let built = try builder.build(session: session, items: [item], intent: "reply", selectedMethod: method)
        XCTAssertEqual(try builder.replay(json: built.json, session: session).payload.selectedMethod, method)
        XCTAssertEqual(built.validation.sentSources.count, 1)
        XCTAssertEqual(built.validation.userExpressionSources.count, 1)
        XCTAssertEqual(built.payload.sources.count, 1)
        let old = try builder.build(session: session, items: [item], intent: "reply")
        XCTAssertNil(try builder.replay(json: old.json, session: session).payload.selectedMethod)
        XCTAssertFalse(old.json.contains("selected_method"))
        let prompt = LocalPromptProvider().template(for: .mentorRespond, mode: .standard)
        let prior = try XCTUnwrap(LocalPromptProvider().template(for: .mentorRespond, mode: .standard, version: "2.17.0"))
        XCTAssertEqual(prompt.version, "2.18.0")
        XCTAssertTrue(prompt.systemText.hasPrefix(prior.systemText))
        XCTAssertFalse(prior.systemText.contains("selected_method"))
        XCTAssertEqual(prompt.outputSchemaVersion, prior.outputSchemaVersion)
    }
}
