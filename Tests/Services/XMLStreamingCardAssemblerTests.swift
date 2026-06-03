import XCTest
@testable import MingSi

final class XMLStreamingCardAssemblerTests: XCTestCase {
    func testAppend_createsAndClosesCardsAcrossChunks() {
        let assembler = XMLStreamingCardAssembler()

        _ = assembler.append("<MINGSI_STREAM version=\"1\"><CARD><TYPE>fact</TYPE><TITLE>会前")
        XCTAssertEqual(assembler.currentCards.count, 1)
        XCTAssertEqual(assembler.currentCards[0].title, "会前")
        XCTAssertEqual(assembler.currentCards[0].status, .receiving)

        _ = assembler.append("没有确认事项</TITLE><BODY>会议前没有列出必须确认的问题。</BODY><IMPORTANCE>high</IMPORTANCE><SENSITIVITY>normal</SENSITIVITY><CONFIDENCE>high</CONFIDENCE><REASON>流程问题</REASON></CARD></MINGSI_STREAM>")

        XCTAssertEqual(assembler.currentCards.count, 1)
        XCTAssertEqual(assembler.currentCards[0].title, "会前没有确认事项")
        XCTAssertEqual(assembler.currentCards[0].status, .closed)
        XCTAssertEqual(assembler.currentCards[0].domainCard?.title, "会前没有确认事项")
        XCTAssertEqual(assembler.currentCards[0].domainCard?.priority, .high)
    }

    func testFinish_marksUnclosedCardInvalid() {
        let assembler = XMLStreamingCardAssembler()

        _ = assembler.append("<CARD><TITLE>未闭合卡片</TITLE><BODY>还没有结束")
        _ = assembler.finish()

        XCTAssertEqual(assembler.currentCards.count, 1)
        XCTAssertEqual(assembler.currentCards[0].status, .invalid("流式输出中断，卡片没有闭合。"))
        XCTAssertNil(assembler.currentCards[0].domainCard)
    }

    func testAppend_preservesAngleBracketTextInsideBody() {
        let assembler = XMLStreamingCardAssembler()

        _ = assembler.append("<CARD><TYPE>task</TYPE><TITLE>限制会议时间</TITLE><BODY>把同步会控制在 < 30 分钟，并提前列出结论。</BODY><IMPORTANCE>high</IMPORTANCE><SENSITIVITY>normal</SENSITIVITY><CONFIDENCE>high</CONFIDENCE></CARD>")

        XCTAssertEqual(assembler.currentCards[0].status, .closed)
        XCTAssertEqual(assembler.currentCards[0].body, "把同步会控制在 < 30 分钟，并提前列出结论。")
        XCTAssertEqual(assembler.currentCards[0].domainCard?.body, "把同步会控制在 < 30 分钟，并提前列出结论。")
    }

    func testAppend_invalidTypeDoesNotBecomeDomainCard() {
        let assembler = XMLStreamingCardAssembler()

        _ = assembler.append("<CARD><TYPE>unknown</TYPE><TITLE>未知类型</TITLE><BODY>不应默认成 idea。</BODY><IMPORTANCE>high</IMPORTANCE><SENSITIVITY>normal</SENSITIVITY><CONFIDENCE>high</CONFIDENCE></CARD>")

        guard case .invalid(let reason) = assembler.currentCards[0].status else {
            XCTFail("Expected invalid card")
            return
        }
        XCTAssertTrue(reason.contains("TYPE"))
        XCTAssertNil(assembler.currentCards[0].domainCard)
    }
}
