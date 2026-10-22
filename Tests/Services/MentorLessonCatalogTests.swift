import XCTest
@testable import MingSi

final class MentorLessonCatalogTests: XCTestCase {
    func testAppBundleIncludesRequiredReasonManifestAndCalendarReadDescription() throws {
        // Check the built host app, so an unbundled source plist cannot pass.
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let manifest = try XCTUnwrap(PropertyListSerialization.propertyList(
            from: Data(contentsOf: url), format: nil) as? [String: Any])
        let entries = try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let reasons = entries.reduce(into: [String: [String]]()) { result, entry in
            if let category = entry["NSPrivacyAccessedAPIType"] as? String,
               let values = entry["NSPrivacyAccessedAPITypeReasons"] as? [String] {
                result[category] = values
            }
        }
        XCTAssertTrue(reasons["NSPrivacyAccessedAPICategoryUserDefaults"]?.contains("CA92.1") == true)
        XCTAssertTrue(reasons["NSPrivacyAccessedAPICategorySystemBootTime"]?.contains("35F9.1") == true)
        let calendarDescription = try XCTUnwrap(
            Bundle.main.object(forInfoDictionaryKey: "NSCalendarsFullAccessUsageDescription") as? String)
        XCTAssertFalse(calendarDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testProductionBundleContainsUserAuthorizedAIReviewedLessons() throws {
        let catalog = try MentorLessonCatalog.loadBundled()
        XCTAssertEqual(catalog.pack.version, "1.1")
        XCTAssertEqual(catalog.pack.lessons.count, 24)
        XCTAssertEqual(Set(catalog.pack.lessons.map(\.theme)).count, 6)
        for lesson in catalog.pack.lessons {
            XCTAssertEqual(lesson.review.status, .approved)
            XCTAssertEqual(lesson.review.reviewedBy, "Codex (AI editor; user-authorized personal exploration)")
            XCTAssertNotNil(lesson.review.reviewedAt)
            XCTAssertEqual(lesson.contentHash, MentorLessonCatalog.contentHash(for: lesson))
            XCTAssertEqual(lesson.version, ["L08", "L14", "L16"].contains(lesson.id) ? "1.1" : "1.0")
            XCTAssertEqual(lesson.sourceType, .teachingExample)
        }
    }

    #if DEBUG
    func testAppBundleContainsCompleteEditorialDraftButReleaseLoaderRejectsIt() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "mentor-lessons-m1.draft", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let catalog = try MentorLessonCatalog(jsonData: data, mode: .editorialPreview)
        XCTAssertEqual(catalog.pack.packID, "mingsi-mentor-m1")
        XCTAssertEqual(catalog.pack.lessons.count, 24)
        XCTAssertEqual(Set(catalog.pack.lessons.map(\.claim)).count, 24)
        XCTAssertEqual(Set(catalog.pack.lessons.map(\.example)).count, 24)
        XCTAssertEqual(Set(catalog.pack.lessons.map(\.boundary)).count, 24)
        for lesson in catalog.pack.lessons {
            let length = [lesson.claim, lesson.example, lesson.boundary, lesson.observation ?? ""].joined().unicodeScalars.count
            XCTAssertTrue((250...400).contains(length), "Editorial reading budget: \(lesson.id)")
            XCTAssertEqual(lesson.review.status, .draft)
            XCTAssertNil(lesson.review.reviewedBy)
            XCTAssertNil(lesson.review.reviewedAt)
            XCTAssertEqual(lesson.sourceType, .teachingExample)
            XCTAssertTrue(lesson.citations.isEmpty)
        }
        XCTAssertEqual(catalog.lesson(id: "L01", version: "1.0")?.title, "改动之前，先说清希望什么变好。")
        XCTAssertEqual(catalog.lesson(id: "L02", version: "1.0")?.title, "给观察和解释各留一个位置。")
        XCTAssertThrowsError(try MentorLessonCatalog.loadBundled(resource: "mentor-lessons-m1.draft")) {
            XCTAssertEqual($0 as? MentorLessonValidationError, .unapprovedLesson("L01"))
        }
    }
    #endif

    func testCatalogValidatesPackAndOrdersLessons() throws {
        let pack = makePack()
        let catalog = try MentorLessonCatalog(pack: pack, mode: .editorialPreview)
        XCTAssertEqual(catalog.lessonsInEditorialOrder.map(\.editorialOrder), Array(1...24))
        XCTAssertEqual(catalog.lesson(id: "L01", version: "1.0")?.title, "Lesson 1")
    }

    func testCatalogRejectsDuplicateOrder() {
        var pack = makePack()
        pack = MentorLessonPack(schemaVersion: pack.schemaVersion, packID: pack.packID, version: pack.version,
                                lessons: pack.lessons.dropLast() + [copy(pack.lessons[0], order: 1)])
        XCTAssertThrowsError(try MentorLessonCatalog(pack: pack, mode: .editorialPreview)) { error in
            XCTAssertEqual(error as? MentorLessonValidationError, .duplicateEditorialOrder(1))
        }
    }

    func testCanonicalHashMatchesIndependentUTF8Vectors() throws {
        let lesson = makePack().lessons[0]
        // Golden values computed outside Swift with Python's sorted, compact UTF-8 JSON.
        XCTAssertEqual(MentorLessonCatalog.contentHash(for: lesson), "sha256:46cf52547271f0cc679ce45bcb7a0e5a207de9a9bab5459d0ea0f4c1ce3a0142")
        let special = changing(lesson, claim: "中文/🧭e\u{0301}\n\t\r\u{08}\u{0c}\u{01}\"\\\u{2028}")
        XCTAssertEqual(MentorLessonCatalog.contentHash(for: special), "sha256:35b65017da468df72fd2e9da96dfefc8b7a8b53752e674919dc936d43df02a80")
    }

    func testContentTamperingAndVersionReuseAreRejected() throws {
        let original = makePack()
        let previous = try MentorLessonCatalog(pack: original, mode: .editorialPreview)
        var lessons = original.lessons
        lessons[0] = changing(lessons[0], claim: "changed")
        let tampered = replacing(original, lessons: lessons)
        XCTAssertThrowsError(try MentorLessonCatalog(pack: tampered, mode: .editorialPreview)) {
            XCTAssertEqual($0 as? MentorLessonValidationError, .invalidContentHash("L01"))
        }
        lessons[0] = signed(lessons[0])
        XCTAssertThrowsError(try MentorLessonCatalog(pack: replacing(original, lessons: lessons), mode: .editorialPreview, previous: previous)) {
            XCTAssertEqual($0 as? MentorLessonValidationError, .changedVersion("L01"))
        }
        lessons[0] = signed(changing(lessons[0], version: "1.1"))
        XCTAssertNoThrow(try MentorLessonCatalog(pack: replacing(original, lessons: lessons), mode: .editorialPreview, previous: previous))
    }

    func testReleaseRequiresApprovalAndKeepsReviewOutsideContentHash() throws {
        XCTAssertThrowsError(try MentorLessonCatalog(pack: makePack())) {
            XCTAssertEqual($0 as? MentorLessonValidationError, .unapprovedLesson("L01"))
        }
        let data = try approvedData()
        let catalog = try MentorLessonCatalog(jsonData: data)
        XCTAssertEqual(catalog.pack.lessons[0].contentHash, makePack().lessons[0].contentHash)
        XCTAssertNotNil(catalog.pack.lessons[0].review.reviewedAt)
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var lessons = object["lessons"] as! [[String: Any]]
        lessons[0]["review"] = ["status": "rejected", "reviewed_by": "fixture editor", "reviewed_at": "2026-09-10T10:00:00Z"]
        object["lessons"] = lessons
        XCTAssertThrowsError(try MentorLessonCatalog(jsonData: JSONSerialization.data(withJSONObject: object))) {
            XCTAssertEqual($0 as? MentorLessonValidationError, .unapprovedLesson("L01"))
        }
    }

    func testStrictShapeAndFieldValidation() throws {
        let data = try approvedData()
        let mutations: [(inout [String: Any]) -> Void] = [
            { $0["unknown"] = true },
            { $0["pack_id"] = "invalid space" },
            { $0["version"] = "next" }
        ]
        for mutate in mutations {
            var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            mutate(&object)
            XCTAssertThrowsError(try MentorLessonCatalog(jsonData: JSONSerialization.data(withJSONObject: object)))
        }
        let lessonMutations: [(inout [String: Any]) -> Void] = [
            { $0["unknown"] = true }, { $0.removeValue(forKey: "boundary") },
            { $0["observation"] = NSNull() }, { $0["title"] = "  \n" },
            { $0["title"] = String(repeating: "a", count: 201) },
            { $0["claim"] = String(repeating: "a", count: 4001) },
            { $0["id"] = "L01\n" }, { $0["version"] = "1" },
            { $0["editorial_order"] = true },
            { $0["applicable_contexts"] = [] },
            { $0["applicable_contexts"] = ["repeated", "repeated"] },
            { $0["review"] = ["status": "approved", "reviewed_by": " ", "reviewed_at": "2026-09-10T10:00:00Z"] },
            { $0["review"] = ["status": "approved", "reviewed_by": "editor", "reviewed_at": "bad time"] },
            { $0["review"] = ["status": "draft", "note": NSNull()] },
            { $0["review"] = ["status": "approved", "surprise": true] },
            { $0["source_type"] = "external_reference" },
            { $0["citations"] = [["title": "test", "url": "file:///private/test"]] },
            { $0["citations"] = [["title": "test", "url": "https://example.org", "unknown": true]] }
        ]
        for (index, mutate) in lessonMutations.enumerated() {
            var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            var lessons = object["lessons"] as! [[String: Any]]
            mutate(&lessons[0]); object["lessons"] = lessons
            XCTAssertThrowsError(try MentorLessonCatalog(jsonData: JSONSerialization.data(withJSONObject: object)), "Mutation \(index) must fail")
        }
    }

    func testBundleLoadingRejectsMissingDraftAndCorruptContent() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bundle")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let info: [String: Any] = ["CFBundleIdentifier": "com.codex.mingsi.lesson-fixture", "CFBundlePackageType": "BNDL"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: directory.appendingPathComponent("Info.plist"))
        let url = directory.appendingPathComponent("fixture.json")
        try approvedData().write(to: url)
        let bundle = try XCTUnwrap(Bundle(url: directory))
        let loaded = try MentorLessonCatalog.loadBundled(bundle: bundle, resource: "fixture")
        XCTAssertEqual(loaded.pack.lessons.count, 24)
        XCTAssertThrowsError(try MentorLessonCatalog.loadBundled(bundle: bundle, resource: "missing")) {
            XCTAssertEqual($0 as? MentorLessonValidationError, .missingResource("missing"))
        }
        try JSONEncoder().encode(makePack()).write(to: url)
        XCTAssertThrowsError(try MentorLessonCatalog.loadBundled(bundle: bundle, resource: "fixture"))
        try Data("{broken".utf8).write(to: url)
        XCTAssertThrowsError(try MentorLessonCatalog.loadBundled(bundle: bundle, resource: "fixture"))
    }

    private func approvedData() throws -> Data {
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(makePack())) as! [String: Any]
        var lessons = object["lessons"] as! [[String: Any]]
        for index in lessons.indices {
            lessons[index]["review"] = ["status": "approved", "reviewed_by": "test fixture only", "reviewed_at": "2026-09-10T10:00:00.125Z"]
        }
        object["lessons"] = lessons
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func replacing(_ pack: MentorLessonPack, lessons: [MentorLesson]) -> MentorLessonPack {
        MentorLessonPack(schemaVersion: pack.schemaVersion, packID: pack.packID, version: pack.version, lessons: lessons)
    }

    private func changing(_ lesson: MentorLesson, claim: String? = nil, version: String? = nil, hash: String? = nil) -> MentorLesson {
        MentorLesson(id: lesson.id, version: version ?? lesson.version, editorialOrder: lesson.editorialOrder,
            title: lesson.title, theme: lesson.theme, applicableContexts: lesson.applicableContexts,
            claim: claim ?? lesson.claim, example: lesson.example, boundary: lesson.boundary, observation: lesson.observation,
            sourceType: lesson.sourceType, citations: lesson.citations, contentHash: hash ?? lesson.contentHash, review: lesson.review)
    }

    private func signed(_ lesson: MentorLesson) -> MentorLesson {
        changing(lesson, hash: MentorLessonCatalog.contentHash(for: lesson))
    }

    private func makePack() -> MentorLessonPack {
        let lessons = (1...24).map { index in
            signed(MentorLesson(id: String(format: "L%02d", index), version: "1.0", editorialOrder: index,
                         title: "Lesson \(index)", theme: MentorLesson.Theme.allCases[(index - 1) / 4],
                         applicableContexts: ["fixture"], claim: "claim", example: "example", boundary: "boundary",
                         observation: nil, sourceType: .teachingExample, citations: [],
                         contentHash: "sha256:" + String(repeating: "0", count: 64),
                         review: .init(status: .draft, reviewedBy: nil, reviewedAt: nil, note: nil)))
        }
        return MentorLessonPack(schemaVersion: "1.0.0", packID: "fixture", version: "1.0", lessons: lessons)
    }

    private func copy(_ lesson: MentorLesson, order: Int) -> MentorLesson {
        signed(MentorLesson(id: "L25", version: lesson.version, editorialOrder: order, title: lesson.title,
                     theme: lesson.theme, applicableContexts: lesson.applicableContexts, claim: lesson.claim,
                     example: lesson.example, boundary: lesson.boundary, observation: lesson.observation,
                     sourceType: lesson.sourceType, citations: lesson.citations, contentHash: lesson.contentHash,
                     review: lesson.review))
    }
}
