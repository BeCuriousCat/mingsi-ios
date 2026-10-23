import Foundation
import Synchronization

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

/// A transport attempt belongs to this immutable request, even after another
/// request advances the session epoch. No URL, credentials or user text belong here.
struct MentorHTTPAttemptIdentity: Codable, Equatable, Sendable {
    let attemptID: UUID
    let traceID: UUID
    let sessionID: UUID
    let requestID: UUID
    let requestEpoch: Int
    let semanticRevision: Int
}

enum MentorHTTPProtocol: String, Sendable { case openAICompatible, responses }
enum MentorHTTPAttemptOutcome: String, Sendable {
    // The transport returned data; this is not proof of validation or saving.
    case returnedData = "returned_data"
    case failed, cancelled
}
enum MentorHTTPObservationError: Error { case unavailable, invalidIdentity, conflict, staleRequest }

protocol MentorHTTPObservationStore: Sendable {
    func beginAttempt(_ identity: MentorHTTPAttemptIdentity, protocolKind: MentorHTTPProtocol, at: Date) async throws
    func recordMetrics(_ metrics: MentorHTTPMetrics, identity: MentorHTTPAttemptIdentity) async throws
    func finishAttempt(_ identity: MentorHTTPAttemptIdentity, outcome: MentorHTTPAttemptOutcome, elapsedMilliseconds: Int64) async throws
}

private final class MentorHTTPWriteFailure: Sendable {
    private let failed = Mutex(false)
    var hasFailed: Bool { failed.withLock { $0 } }
    func record() { failed.withLock { $0 = true } }
}

/// Ephemeral channel, never encoded in model context. Hash by reference just as
/// the per-request preview channel does. Each actual dispatch gets a fresh ID.
final class MentorHTTPObservation: Hashable, Sendable {
    private let traceID: UUID
    private let sessionID: UUID
    private let requestID: UUID
    private let requestEpoch: Int
    private let semanticRevision: Int
    private let store: any MentorHTTPObservationStore

    init(traceID: UUID, sessionID: UUID, requestID: UUID, requestEpoch: Int,
         semanticRevision: Int, store: any MentorHTTPObservationStore) {
        self.traceID = traceID; self.sessionID = sessionID; self.requestID = requestID
        self.requestEpoch = requestEpoch; self.semanticRevision = semanticRevision; self.store = store
    }
    static func == (lhs: MentorHTTPObservation, rhs: MentorHTTPObservation) -> Bool { lhs === rhs }
    func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }

    func beginAttempt(protocolKind: MentorHTTPProtocol) async throws -> MentorHTTPAttempt {
        let identity = MentorHTTPAttemptIdentity(attemptID: UUID(), traceID: traceID,
            sessionID: sessionID, requestID: requestID, requestEpoch: requestEpoch, semanticRevision: semanticRevision)
        let started = ContinuousClock.now
        // Registration must succeed before dispatch. It proves intent to dispatch,
        // not that one HTTP load occurred; only native metrics can supply that.
        try await store.beginAttempt(identity, protocolKind: protocolKind, at: .now)
        return MentorHTTPAttempt(identity: identity, started: started, store: store)
    }
}

final class MentorHTTPAttempt: Sendable {
    let identity: MentorHTTPAttemptIdentity
    let delegate: MentorHTTPMetricsDelegate
    private let started: ContinuousClock.Instant
    private let store: any MentorHTTPObservationStore
    private let writeFailure: MentorHTTPWriteFailure
    var observationWriteFailed: Bool { writeFailure.hasFailed }

    init(identity: MentorHTTPAttemptIdentity, started: ContinuousClock.Instant, store: any MentorHTTPObservationStore) {
        self.identity = identity; self.started = started; self.store = store
        let failure = MentorHTTPWriteFailure()
        writeFailure = failure
        delegate = MentorHTTPMetricsDelegate { metrics in
            // Do not wait for a database or main actor on URLSession's delegate
            // queue. This task remains bound to the old attempt after cancellation.
            Task {
                do { try await store.recordMetrics(metrics, identity: identity) }
                catch { failure.record() } // The persisted pending/conflict state stays unknown.
            }
        }
    }

    func finish(_ outcome: MentorHTTPAttemptOutcome) async throws {
        let elapsed = started.duration(to: .now).components
        let milliseconds = max(0, elapsed.seconds * 1_000 + elapsed.attoseconds / 1_000_000_000_000_000)
        let identity = identity, store = store
        do {
            // A cancelled foreground task must not cancel its accounting write.
            // This cannot save a response or revive a deleted conversation.
            try await Task { try await store.finishAttempt(identity, outcome: outcome, elapsedMilliseconds: milliseconds) }.value
        } catch {
            writeFailure.record()
            throw MentorHTTPObservationError.unavailable
        }
    }
}
