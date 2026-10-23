import XCTest
@testable import MingSi

final class MentorHTTPMetricsTests: XCTestCase {
    func testRedirectCacheEntryDoesNotInflateNetworkCount() throws {
        // Matches the separately recorded native localhost probe: one app
        // attempt, a redirect, two HTTP loads, plus a cache transaction.
        let value = MentorHTTPMetrics(fetchKinds: [.network, .cache, .network], redirectCount: 1)
        XCTAssertEqual(value.transactionCount, 3)
        XCTAssertEqual(value.networkTransactionCount, 2)
        XCTAssertEqual(value.cacheTransactionCount, 1)
        XCTAssertEqual(value.redirectCount, 1)
        XCTAssertEqual(value.exactNetworkTransactionCount, 2)
        let decoded = try JSONDecoder().decode(MentorHTTPMetrics.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(decoded, value)
    }

    func testMissingAndUnknownMetricsCannotBecomeExactZeroOrOne() {
        XCTAssertNil(MentorHTTPMetrics(fetchKinds: [], redirectCount: 0).exactNetworkTransactionCount)
        let unknown = MentorHTTPMetrics(fetchKinds: [.network, .unknown], redirectCount: 0)
        XCTAssertEqual(unknown.networkTransactionCount, 1, "Known loads are a lower bound")
        XCTAssertNil(unknown.exactNetworkTransactionCount)
        XCTAssertEqual(unknown.unknownTransactionCount, 1)
    }

    func testCacheAndServerPushRemainSeparateFromNewNetworkLoads() {
        let value = MentorHTTPMetrics(fetchKinds: [.cache, .serverPush], redirectCount: 0)
        XCTAssertEqual(value.exactNetworkTransactionCount, 0)
        XCTAssertEqual(value.cacheTransactionCount, 1)
        XCTAssertEqual(value.serverPushTransactionCount, 1)
    }

    func testStoredPayloadContainsOnlyAllowlistedNonnegativeCounters() throws {
        let value = MentorHTTPMetrics(fetchKinds: [.network, .cache, .serverPush, .unknown], redirectCount: 1)
        let data = try JSONEncoder().encode(value)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Int])
        XCTAssertEqual(Set(object.keys), Set(["transactionCount", "networkTransactionCount", "cacheTransactionCount",
            "serverPushTransactionCount", "unknownTransactionCount", "redirectCount"]))
        XCTAssertTrue(object.values.allSatisfy { $0 >= 0 })
        XCTAssertEqual(value.transactionCount, value.networkTransactionCount + value.cacheTransactionCount +
            value.serverPushTransactionCount + value.unknownTransactionCount)
    }

    func testMalformedStoredCountersCannotProduceTrustedCountsOrOverflow() throws {
        let valid = MentorHTTPMetrics(fetchKinds: [.network], redirectCount: 0)
        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(valid)) as? [String: Int])
        for changes in [["networkTransactionCount": -1], ["transactionCount": 2], ["redirectCount": -1],
                        ["transactionCount": Int.max, "networkTransactionCount": Int.max, "cacheTransactionCount": Int.max]] {
            var object = original
            for (key, value) in changes { object[key] = value }
            let data = try JSONSerialization.data(withJSONObject: object)
            XCTAssertThrowsError(try JSONDecoder().decode(MentorHTTPMetrics.self, from: data))
        }
    }
}
