import Foundation
import Combine

/// History pagination is independent of the current conversation and home preview.
@MainActor
final class MentorHistoryStore: ObservableObject {
    @Published private(set) var sessions: [MentorSessionSummary] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var hasMore = false
    private let repository: MentorRepository
    private var cursor: MentorSessionCursor?
    private var task: Task<Void, Never>?
    private var generation = UUID()

    init(repository: MentorRepository) { self.repository = repository }
    deinit { task?.cancel() }

    func refresh() {
        task?.cancel()
        let token = UUID()
        generation = token
        let pageCount = max(1, (sessions.count + 19) / 20)
        isLoading = true
        error = nil
        task = Task { [weak self] in
            guard let self else { return }
            do {
                var refreshed: [MentorSessionSummary] = []
                var next: MentorSessionCursor?
                for _ in 0..<pageCount {
                    let page = try await repository.recentSessions(after: next, limit: 20)
                    try Task.checkCancellation()
                    refreshed.append(contentsOf: page.sessions)
                    next = page.nextCursor
                    if next == nil { break }
                }
                guard generation == token else { return }
                sessions = refreshed
                cursor = next
                hasMore = next != nil
            } catch {
                guard !Task.isCancelled, generation == token else { return }
                self.error = "交流记录暂时无法读取，请重试。"
            }
            isLoading = false
        }
    }

    func loadMore() {
        guard !isLoading, let cursor else { return }
        let token = generation
        isLoading = true
        error = nil
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let page = try await repository.recentSessions(after: cursor, limit: 20)
                try Task.checkCancellation()
                guard generation == token else { return }
                let existing = Set(sessions.map(\.id))
                sessions.append(contentsOf: page.sessions.filter { !existing.contains($0.id) })
                self.cursor = page.nextCursor
                hasMore = page.nextCursor != nil
            } catch {
                guard !Task.isCancelled, generation == token else { return }
                self.error = "更多交流暂时无法读取，请重试。"
            }
            isLoading = false
        }
    }
}
