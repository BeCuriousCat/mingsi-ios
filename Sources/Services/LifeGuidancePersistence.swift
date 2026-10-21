import Foundation
import GRDB

protocol LifeGuidanceRepository {
    func exposures() async throws -> [LifeGuidanceExposure]
    func insertExposure(_ exposure: LifeGuidanceExposure) async throws -> LifeGuidanceExposure
    func feedback() async throws -> [LifeGuidanceFeedback]
    func saveFeedback(_ feedback: LifeGuidanceFeedback) async throws
    func deleteFeedback(id: String) async throws
    func deleteReviewExposures(prefix: String) async throws
}

final class SQLiteLifeGuidanceRepository: LifeGuidanceRepository {
    private let database: AppDatabase
    init(database: AppDatabase) { self.database = database }

    static func registerMigration(on migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v71_life_guidance") { db in
            for name in ["life_guidance_exposures", "life_guidance_feedback"] {
                try db.create(table: name) { table in
                    table.column("id", .text).primaryKey()
                    table.column("payload_json", .text).notNull()
                    if name == "life_guidance_exposures", (try? db.tableExists("mentor_sessions")) == true {
                        table.column("mentor_session_id", .text).references("mentor_sessions", onDelete: .cascade)
                    }
                }
            }
        }
    }

    func exposures() async throws -> [LifeGuidanceExposure] {
        try await database.dbQueue.read { db in
            try String.fetchAll(db, sql: "SELECT payload_json FROM life_guidance_exposures")
                .map { try JSONDecoder().decode(LifeGuidanceExposure.self, from: Data($0.utf8)) }
        }
    }

    func insertExposure(_ exposure: LifeGuidanceExposure) async throws -> LifeGuidanceExposure {
        let json = String(decoding: try JSONEncoder().encode(exposure), as: UTF8.self)
        return try await database.dbQueue.write { db in
            // First selection wins, even across simultaneous scene refreshes.
            if exposure.id.hasPrefix("review:mentor:") {
                let sessionID = String(exposure.id.dropFirst("review:mentor:".count))
                guard try db.tableExists("mentor_sessions"),
                      try Bool.fetchOne(db, sql: "SELECT EXISTS(SELECT 1 FROM mentor_sessions WHERE id = ?)", arguments: [sessionID]) == true
                else { throw PersistenceError.validationFailed("review session no longer exists") }
                try db.execute(sql: "INSERT OR IGNORE INTO life_guidance_exposures (id, payload_json, mentor_session_id) VALUES (?, ?, ?)", arguments: [exposure.id, json, sessionID])
            } else {
                try db.execute(sql: "INSERT OR IGNORE INTO life_guidance_exposures (id, payload_json) VALUES (?, ?)", arguments: [exposure.id, json])
            }
            let stored = try String.fetchOne(db, sql: "SELECT payload_json FROM life_guidance_exposures WHERE id = ?", arguments: [exposure.id])!
            return try JSONDecoder().decode(LifeGuidanceExposure.self, from: Data(stored.utf8))
        }
    }

    func feedback() async throws -> [LifeGuidanceFeedback] {
        try await database.dbQueue.read { db in
            try String.fetchAll(db, sql: "SELECT payload_json FROM life_guidance_feedback")
                .map { try JSONDecoder().decode(LifeGuidanceFeedback.self, from: Data($0.utf8)) }
        }
    }

    func saveFeedback(_ feedback: LifeGuidanceFeedback) async throws {
        let json = String(decoding: try JSONEncoder().encode(feedback), as: UTF8.self)
        try await database.dbQueue.write { db in
            try db.execute(sql: "INSERT INTO life_guidance_feedback (id, payload_json) VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET payload_json = excluded.payload_json", arguments: [feedback.id, json])
        }
    }

    func deleteFeedback(id: String) async throws {
        try await database.dbQueue.write { db in
            try db.execute(sql: "DELETE FROM life_guidance_feedback WHERE id = ?", arguments: [id])
        }
    }

    func deleteReviewExposures(prefix: String) async throws {
        try await database.dbQueue.write { db in
            try db.execute(sql: "DELETE FROM life_guidance_exposures WHERE substr(id, 1, ?) = ?", arguments: [prefix.count, prefix])
        }
    }
}
