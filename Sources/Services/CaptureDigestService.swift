import Foundation

/// Small synchronous writes serialize editor changes before reporting recovery
/// as available. Fragment creation and clearing its draft share one transaction.
protocol CaptureInputDraftRepository {
    func inputDraft() throws -> CaptureInputDraft
    func saveInputDraft(_ draft: CaptureInputDraft) throws
    func commitInputDraft(_ expected: CaptureInputDraft) throws
}

protocol CaptureFragmentRepository {
    func save(_ fragment: CaptureFragment) async throws -> CaptureFragment
    func fragments(forDayKey dayKey: String, statuses: [CaptureFragment.Status]?) async throws -> [CaptureFragment]
    func archive(id: UUID) async throws
    func saveDigest(_ digest: DailyCaptureDigest, markingIncluded fragmentIDs: [UUID]) async throws
    func currentDigest(forDayKey dayKey: String) async throws -> DailyCaptureDigest?
    func updateDigestStatus(_ status: DailyCaptureDigest.Status, id: UUID) async throws
}

protocol CaptureDigestGenerating {
    func generate(for fragments: [CaptureFragment], dayKey: String) async throws -> DailyCaptureDigest
}

enum CaptureDigestError: LocalizedError, Equatable {
    case insufficientFragments
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .insufficientFragments: return "至少记录两条闪念后才能整理。"
        case .invalidResponse: return "整理结果格式不符合要求，请重试。"
        }
    }
}

final class CaptureDigestService: CaptureDigestGenerating {
    private let promptProvider: PromptProvider
    private let llmClient: LLMClient

    init(promptProvider: PromptProvider, llmClient: LLMClient) {
        self.promptProvider = promptProvider; self.llmClient = llmClient
    }

    func generate(for fragments: [CaptureFragment], dayKey: String) async throws -> DailyCaptureDigest {
        guard fragments.count >= 2 else { throw CaptureDigestError.insufficientFragments }
        let sourceIDs = fragments.map { $0.id.uuidString }
        guard fragments.allSatisfy({
            $0.dayKey == dayKey &&
                $0.status == .pending &&
                !$0.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }),
        Set(sourceIDs).count == sourceIDs.count
        else { throw CaptureDigestError.invalidResponse }
        let input = fragments.map { item in
            "[\(item.id.uuidString)] \(item.rawText)"
        }.joined(separator: "\n")
        let template = promptProvider.template(for: .digestCaptures, mode: .standard)
        let data = try await llmClient.complete(LLMRequest(prompt: template, inputSummary: input, sourceRecordIDs: sourceIDs))
        let response = try JSONDecoder().decode(CaptureDigestResponse.self, from: data)
        let validRefs = Set(sourceIDs)
        guard !response.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (1...3).contains(response.themes.count),
              response.themes.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              response.recommendedQuestion.map({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? true,
              sourceIDs.count == validRefs.count,
              response.sourceRefs.count == sourceIDs.count,
              Set(response.sourceRefs).count == response.sourceRefs.count,
              Set(response.sourceRefs) == validRefs
        else { throw CaptureDigestError.invalidResponse }
        return DailyCaptureDigest(dayKey: dayKey, summary: response.summary, themes: response.themes, recommendedQuestion: response.recommendedQuestion, sourceFragmentIDs: response.sourceRefs.compactMap(UUID.init(uuidString:)))
    }
}

/// Isolates AppIntent persistence so it is usable in focused tests without AppIntents.
protocol CaptureIntentSaving {
    func saveIntentCapture(_ text: String) async throws
}

final class CaptureIntentSaver: CaptureIntentSaving {
    private let repository: CaptureFragmentRepository
    init(repository: CaptureFragmentRepository) { self.repository = repository }
    func saveIntentCapture(_ text: String) async throws {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw PersistenceError.validationFailed("capture text is empty") }
        _ = try await repository.save(CaptureFragment(rawText: cleaned, source: .appIntent, dayKey: CaptureDayKey.value(for: .now)))
    }
}
