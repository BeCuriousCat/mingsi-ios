import Foundation
import CryptoKit

/// First-party, source-scoped method material. This is guidance, never evidence
/// about the user and never an executable imported Skill or author persona.
struct CoachMethodSnapshot: Codable, Equatable, Hashable, Sendable {
    let id: String
    let version: String
    let title: String
    let instructions: String
    let sourceTitle: String
    let sourceURL: String
    let sourceScope: String
    let sourceHashes: [String]

    var contentHash: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(self) else { return "" }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

struct CoachMethodEvaluation: Codable, Equatable {
    let batchID: String
    let reportPath: String
    let reviewer: String
    let contentHash: String
    let promptVersion: String
    let passedCases: [String]
    let requiredCases: [String]
    let improvedPairs: [String]
    let criticalFailures: [String]
    let decision: String

    func permits(_ snapshot: CoachMethodSnapshot, promptVersion: String) -> Bool {
        let required = Set(requiredCases)
        let mandatory: Set<String> = ["positive-1", "positive-2", "neighbor", "stop", "missing", "changed"]
        return decision == "scopedTrial" && !batchID.isEmpty && !reportPath.isEmpty && !reviewer.isEmpty &&
            contentHash == snapshot.contentHash && self.promptVersion == promptVersion &&
            required == mandatory && Set(passedCases).isSubset(of: required) &&
            Set(["stop", "missing", "changed"]).isSubset(of: Set(passedCases)) &&
            Set(improvedPairs).isSubset(of: Set(["positive-1", "positive-2"]).intersection(Set(passedCases))) &&
            Set(passedCases).count >= required.count - 1 && !improvedPairs.isEmpty && criticalFailures.isEmpty
    }
}

struct CoachMethod: Codable, Equatable, Identifiable {
    let snapshot: CoachMethodSnapshot
    let summary: String
    let applicable: String
    let boundaries: String
    let relatedLensIDs: [String]
    let sourceReview: String
    let editorialReviewer: String
    let holdReason: String
    let evaluation: CoachMethodEvaluation?
    var id: String { snapshot.id }

    func isAvailable(promptVersion: String) -> Bool {
        sourceReview == "scoped" && !editorialReviewer.isEmpty &&
            evaluation?.permits(snapshot, promptVersion: promptVersion) == true
    }
}

struct CoachMethodCatalog: Codable {
    let version: String
    let methods: [CoachMethod]
    static let bundled = try? loadBundled()
    static var currentPromptVersion: String {
        LocalPromptProvider().template(for: .mentorRespond, mode: .standard).version
    }
    static func loadBundled(bundle: Bundle = .main) throws -> Self {
        guard let url = bundle.url(forResource: "coach-methods", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let catalog = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        guard Set(catalog.methods.map(\.id)).count == catalog.methods.count,
              catalog.methods.allSatisfy({ !$0.id.hasPrefix("lens.") && !$0.snapshot.instructions.isEmpty &&
                  $0.snapshot.instructions.count <= 4_000 && !$0.snapshot.sourceHashes.isEmpty }) else {
            throw CocoaError(.coderReadCorrupt)
        }
        return catalog
    }

    /// Existing ten lens IDs are preserved; the new library deepens rather than
    /// replaces the older Today workflow. No claim of new book evaluation here.
    static func builtinSnapshot(_ lens: LensCatalogItem) -> CoachMethodSnapshot {
        CoachMethodSnapshot(id: "lens." + lens.id, version: lens.version, title: lens.title,
            instructions: [lens.purpose, lens.promptGuidance, lens.questionStrategy, lens.taskSelectionRule,
                           lens.applicability, lens.disableConditions.joined(separator: "；")].joined(separator: "\n"),
            sourceTitle: "明思内置透镜", sourceURL: "", sourceScope: "现有方法；不代表书籍提炼已通过效果评测。",
            sourceHashes: ["builtin:" + lens.packVersion])
    }

    static func usableSnapshot(id: String) -> CoachMethodSnapshot? {
        if let lens = BuiltinLensCatalog.items.first(where: { "lens." + $0.id == id }) {
            return builtinSnapshot(lens)
        }
        guard let method = bundled?.methods.first(where: { $0.id == id }),
              method.isAvailable(promptVersion: currentPromptVersion) else { return nil }
        return method.snapshot
    }
}
