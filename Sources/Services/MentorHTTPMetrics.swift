import Foundation

/// Only numeric, system-reported task metrics may cross the transport boundary.
/// This does not count provider-side retries or prove an upstream model identity.
struct MentorHTTPMetrics: Codable, Equatable, Sendable {
    enum FetchKind: Sendable {
        case network, cache, serverPush, unknown
    }

    let transactionCount: Int
    let networkTransactionCount: Int
    let cacheTransactionCount: Int
    let serverPushTransactionCount: Int
    let unknownTransactionCount: Int
    let redirectCount: Int

    /// nil means that at least one transaction's fetch type was unknown. An
    /// empty metrics callback is not proof that no network request occurred.
    var exactNetworkTransactionCount: Int? {
        transactionCount > 0 && unknownTransactionCount == 0 ? networkTransactionCount : nil
    }

    init(fetchKinds: [FetchKind], redirectCount: Int) {
        transactionCount = fetchKinds.count
        networkTransactionCount = fetchKinds.filter { if case .network = $0 { true } else { false } }.count
        cacheTransactionCount = fetchKinds.filter { if case .cache = $0 { true } else { false } }.count
        serverPushTransactionCount = fetchKinds.filter { if case .serverPush = $0 { true } else { false } }.count
        unknownTransactionCount = fetchKinds.filter { if case .unknown = $0 { true } else { false } }.count
        self.redirectCount = max(0, redirectCount)
    }

    init(_ metrics: URLSessionTaskMetrics) {
        self.init(fetchKinds: metrics.transactionMetrics.map { transaction in
            switch transaction.resourceFetchType {
            case .networkLoad: .network
            case .localCache: .cache
            // serverPush is deprecated, but old/system-reported values must not
            // be silently counted as new network requests.
            case .serverPush: .serverPush
            case .unknown: .unknown
            @unknown default: .unknown
            }
        }, redirectCount: metrics.redirectCount)
    }

    private enum CodingKeys: String, CodingKey {
        case transactionCount, networkTransactionCount, cacheTransactionCount
        case serverPushTransactionCount, unknownTransactionCount, redirectCount
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        transactionCount = try values.decode(Int.self, forKey: .transactionCount)
        networkTransactionCount = try values.decode(Int.self, forKey: .networkTransactionCount)
        cacheTransactionCount = try values.decode(Int.self, forKey: .cacheTransactionCount)
        serverPushTransactionCount = try values.decode(Int.self, forKey: .serverPushTransactionCount)
        unknownTransactionCount = try values.decode(Int.self, forKey: .unknownTransactionCount)
        redirectCount = try values.decode(Int.self, forKey: .redirectCount)
        var remaining = transactionCount
        guard remaining >= 0, redirectCount >= 0 else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid transport counters"))
        }
        for count in [networkTransactionCount, cacheTransactionCount, serverPushTransactionCount, unknownTransactionCount] {
            guard count >= 0, count <= remaining else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Inconsistent transport counters"))
            }
            remaining -= count
        }
        guard remaining == 0 else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Incomplete transport counters"))
        }
    }
}

/// Use one delegate per attempt. The caller binds the callback to its own
/// immutable request identity, never to whichever conversation is current.
final class MentorHTTPMetricsDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    private let onMetrics: @Sendable (MentorHTTPMetrics) -> Void

    init(onMetrics: @escaping @Sendable (MentorHTTPMetrics) -> Void) {
        self.onMetrics = onMetrics
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        // Never pass the URLSessionTask or URLSessionTaskMetrics to storage:
        // they also expose URL, headers, network addresses and certificates.
        onMetrics(MentorHTTPMetrics(metrics))
    }
}
