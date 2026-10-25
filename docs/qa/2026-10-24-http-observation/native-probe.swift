import Foundation
import Synchronization
import GRDB
@testable import MingSi

struct Observation: Codable {
    let scenario: String
    let returnedData: Bool
    let terminalState: String
    let metricsState: String
    let nativeMetrics: MentorHTTPMetrics?
    let exactNetworkTransactionCount: Int?
}

@main struct NativeProbe {
    @MainActor static func main() async throws {
        let port = CommandLine.arguments[1]
        let queue = try DatabaseQueue(path: CommandLine.arguments[2])
        try await queue.write { db in
            try db.execute(sql: """
                CREATE TABLE mentor_sessions (id TEXT PRIMARY KEY, request_epoch INTEGER NOT NULL, semantic_revision INTEGER NOT NULL);
                CREATE TABLE mentor_requests (id TEXT PRIMARY KEY, session_id TEXT NOT NULL REFERENCES mentor_sessions(id) ON DELETE CASCADE,
                    state TEXT NOT NULL, epoch INTEGER NOT NULL, expected_revision INTEGER NOT NULL, UNIQUE(session_id, id));
                """)
        }
        var migrator = DatabaseMigrator()
        SQLiteMentorHTTPObservationStore.registerMigration(on: &migrator)
        try migrator.migrate(queue)
        let store = SQLiteMentorHTTPObservationStore(queue: queue)
        var observations: [Observation] = []
        for scenario in ["chat", "redirect", "cancel"] {
            let sessionID = UUID(), requestID = UUID()
            try await queue.write { db in
                try db.execute(sql: "INSERT INTO mentor_sessions VALUES (?, 0, 0)", arguments: [sessionID.uuidString])
                try db.execute(sql: "INSERT INTO mentor_requests VALUES (?, ?, 'in_flight', 0, 0)", arguments: [requestID.uuidString, sessionID.uuidString])
            }
            let sawPreview = Mutex(false)
            var request = LLMRequest()
            request.mentorExecutionPolicy = scenario == "chat" ? .m1 : .responses
            request.mentorStreamProgress = MentorStreamProgress { preview in
                if !preview.isEmpty { sawPreview.withLock { $0 = true } }
            }
            request.mentorHTTPObservation = MentorHTTPObservation(traceID: request.traceID, sessionID: sessionID, requestID: requestID,
                requestEpoch: 0, semanticRevision: 0, store: store)
            let session = URLSession(configuration: .ephemeral)
            let client = DirectGLMClient(apiKey: "localhost-synthetic-key", configuration: GLMClientConfiguration(
                baseURL: URL(string: "http://127.0.0.1:" + port + "/" + scenario)!, model: "synthetic",
                protocolKind: scenario == "chat" ? .openAICompatible : .responses, maxRetryAttempts: 0), session: session)
            let submitted = request
            let operation = Task { try await client.complete(submitted) }
            if scenario == "cancel" {
                let until = ContinuousClock.now.advanced(by: .seconds(5))
                while !sawPreview.withLock({ $0 }) && ContinuousClock.now < until { try await Task.sleep(for: .milliseconds(20)) }
                precondition(sawPreview.withLock { $0 }, "Must cancel a genuinely receiving stream")
                operation.cancel()
            }
            var returnedData = false
            do { _ = try await operation.value; returnedData = true }
            catch { precondition(scenario == "cancel", "Unexpected local transport failure") }
            precondition(returnedData == (scenario != "cancel"))
            let until = ContinuousClock.now.advanced(by: .seconds(5))
            var record: MentorHTTPAttemptRecord?
            repeat {
                record = try await store.attempts(requestID: requestID).first
                if record?.metricsState == "received", record?.terminalState != "pending" { break }
                try await Task.sleep(for: .milliseconds(20))
            } while ContinuousClock.now < until
            guard let record else { preconditionFailure("Missing registration") }
            observations.append(Observation(scenario: scenario, returnedData: returnedData, terminalState: record.terminalState,
                metricsState: record.metricsState, nativeMetrics: record.metrics, exactNetworkTransactionCount: record.exactNetworkTransactionCount))
            session.invalidateAndCancel()
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(observations), as: UTF8.self))
    }
}
