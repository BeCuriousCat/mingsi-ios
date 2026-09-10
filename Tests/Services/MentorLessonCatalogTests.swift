import XCTest
@testable import MingSi

final class MentorLessonCatalogTests: XCTestCase {
    func testCatalogValidatesPackAndOrdersLessons() throws {
        let pack = makePack()
        let catalog = try MentorLessonCatalog(pack: pack)
        XCTAssertEqual(catalog.lessonsInEditorialOrder.map(\.editorialOrder), Array(1...24))
        XCTAssertEqual(catalog.lesson(id: "L01", version: "1.0")?.title, "Lesson 1")
    }

    func testCatalogRejectsDuplicateOrder() {
        var pack = makePack()
        pack = MentorLessonPack(schemaVersion: pack.schemaVersion, packID: pack.packID, version: pack.version,
                                lessons: pack.lessons.dropLast() + [copy(pack.lessons[0], order: 1)])
        XCTAssertThrowsError(try MentorLessonCatalog(pack: pack)) { error in
            XCTAssertEqual(error as? MentorLessonValidationError, .duplicateEditorialOrder(1))
        }
    }

    private func makePack() -> MentorLessonPack {
        let lessons = (1...24).map { index in
            MentorLesson(id: String(format: "L%02d", index), version: "1.0", editorialOrder: index,
                         title: "Lesson \(index)", theme: MentorLesson.Theme.allCases[(index - 1) / 4],
                         applicableContexts: ["fixture"], claim: "claim", example: "example", boundary: "boundary",
                         observation: nil, sourceType: .teachingExample, citations: [],
                         contentHash: "sha256:" + String(repeating: "0", count: 64),
                         review: .init(status: .draft, reviewedBy: nil, reviewedAt: nil, note: nil))
        }
        return MentorLessonPack(schemaVersion: "1.0.0", packID: "fixture", version: "1.0", lessons: lessons)
    }

    private func copy(_ lesson: MentorLesson, order: Int) -> MentorLesson {
        MentorLesson(id: "L25", version: lesson.version, editorialOrder: order, title: lesson.title,
                     theme: lesson.theme, applicableContexts: lesson.applicableContexts, claim: lesson.claim,
                     example: lesson.example, boundary: lesson.boundary, observation: lesson.observation,
                     sourceType: lesson.sourceType, citations: lesson.citations, contentHash: lesson.contentHash,
                     review: lesson.review)
    }
}
