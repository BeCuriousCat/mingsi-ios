import Foundation
import Combine

/// Global recommendation preferences do not belong to the open conversation.
@MainActor
final class MentorLessonPreferencesStore: ObservableObject {
    @Published private(set) var isResetting = false
    @Published private(set) var error: String?
    @Published private(set) var didReset = false
    private let repository: MentorRepository

    init(repository: MentorRepository) { self.repository = repository }

    func resetKnownFeedback() async {
        guard !isResetting else { return }
        isResetting = true
        error = nil
        didReset = false
        defer { isResetting = false }
        do {
            try await repository.resetKnownLessonFeedback(commandID: UUID(), at: .now)
            didReset = true
        } catch {
            self.error = "暂时没有重置成功，请重试。"
        }
    }
}
