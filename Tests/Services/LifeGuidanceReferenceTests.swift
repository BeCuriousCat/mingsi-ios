import XCTest
@testable import MingSi

final class LifeGuidanceReferenceTests: XCTestCase {
    func testBundledReferenceDataHasExpectedCoverageAndSearchesAcrossFields() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent("Sources/Resources/LifeGuidance/life-guidance-reference.json")
        let book = try LifeGuidanceReferenceBook.decode(Data(contentsOf: url))

        XCTAssertEqual(book.counts.sections, 34)
        XCTAssertEqual(book.counts.entries, 670)
        XCTAssertEqual(book.sections.count, 34)
        XCTAssertEqual(book.entries.count, 670)
        XCTAssertEqual(book.longReads.count, 10)
        XCTAssertGreaterThanOrEqual(book.readmeSections.count, 10)
        XCTAssertEqual(book.glossary.count, 41)
        XCTAssertTrue(book.search("安全带").contains { $0.title.contains("安全带") })
        XCTAssertTrue(book.search("税务", evidenceLevel: "C").allSatisfy { $0.evidenceLevel == "C" })
        XCTAssertTrue(book.search("死亡率").contains { $0.lens == "死亡率" })
        XCTAssertTrue(book.search("不存在的词", benefitLevel: "大").isEmpty)
        XCTAssertTrue(book.search("", benefitLevel: "小").allSatisfy { $0.benefitLevel == "小" })
        XCTAssertTrue(book.search("", lowCostOnly: true).allSatisfy {
            ["0", "少"].contains($0.moneyCost) && $0.timeCost == "少" && $0.willCost == "否"
        })
        XCTAssertEqual(book.search("不存在的词").count, 0)
        let selector = LifeGuidanceSelector(catalog: book.recommendationItems)
        XCTAssertEqual(selector.eligibleItems().count, 670)
        XCTAssertTrue(selector.approvedItems().isEmpty, "原文收录不能伪装为审核完成")
        for (index, item) in selector.eligibleItems().enumerated() {
            XCTAssertEqual(selector.dailySelection(dayKey: "ignored", seed: index)?.itemID, item.id)
            XCTAssertEqual(item.referenceEntry, book.entries.first { $0.id == item.id })
            XCTAssertEqual(item.boundary, item.referenceEntry?.note)
            XCTAssertTrue(item.captureMaterial.contains(item.referenceEntry!.rawMarkdown))
            XCTAssertTrue(item.captureMaterial.contains(book.sourceCommit))
            var tampered = item
            tampered.whyItMayHelp = "篡改的收益"
            XCTAssertFalse(LifeGuidanceSelector.isEligible(tampered))
        }
    }

    func testOldSavedItemWithoutReferenceFieldStillDecodes() throws {
        let original = BuiltinLifeGuidanceCatalog.items[0]
        let data = try JSONEncoder().encode(original)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(object["referenceEntry"])
        XCTAssertEqual(try JSONDecoder().decode(LifeGuidanceItem.self, from: data), original)
    }
}
