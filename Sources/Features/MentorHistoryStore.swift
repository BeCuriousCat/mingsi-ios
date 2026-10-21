import Foundation
import Combine

/// Merge independently paginated sources without dropping unshown rows.
/// Stores advance a local copy, committing it only after the whole page succeeds.
struct MentorHistoryPager {
    private var mentorRows: [MentorSessionSummary] = []
    private var legacyRows: [MentorSessionSummary] = []
    private var mentorCursor: MentorSessionCursor?
    private var legacyCursor: LegacyNudgeSummaryCursor?
    private var hasReadMentor = false
    private var hasReadLegacy = false
    private var emittedIDs = Set<UUID>()

    var hasMore: Bool {
        !mentorRows.isEmpty || !legacyRows.isEmpty || !hasReadMentor || !hasReadLegacy ||
            mentorCursor != nil || legacyCursor != nil
    }

    static func isNewer(_ lhs: MentorSessionSummary, than rhs: MentorSessionSummary) -> Bool {
        if lhs.activityAt != rhs.activityAt { return lhs.activityAt > rhs.activityAt }
        return lhs.id.uuidString > rhs.id.uuidString
    }

    mutating func nextPage(repository: MentorRepository, legacy: LegacyNudgeAdapter?,
                           limit: Int = 20) async throws -> [MentorSessionSummary] {
        guard (1...20).contains(limit) else {
            throw PersistenceError.validationFailed("mentor page size must be between 1 and 20")
        }
        var result: [MentorSessionSummary] = []
        while result.count < limit {
            if mentorRows.isEmpty && (!hasReadMentor || mentorCursor != nil) {
                let page = try await repository.recentSessions(after: mentorCursor, limit: limit)
                try Task.checkCancellation()
                mentorRows = page.sessions
                mentorCursor = page.nextCursor
                hasReadMentor = true
            }
            if legacyRows.isEmpty && (!hasReadLegacy || legacyCursor != nil) {
                if let legacy {
                    let page = try await legacy.recentSummaries(after: legacyCursor, limit: limit)
                    try Task.checkCancellation()
                    legacyRows = page.sessions
                    legacyCursor = page.nextCursor
                }
                hasReadLegacy = true
            }
            let next: MentorSessionSummary
            if let mentor = mentorRows.first {
                if let legacy = legacyRows.first, Self.isNewer(legacy, than: mentor) {
                    next = legacyRows.removeFirst()
                } else {
                    next = mentorRows.removeFirst()
                }
            } else if !legacyRows.isEmpty {
                next = legacyRows.removeFirst()
            } else {
                break
            }
            if emittedIDs.insert(next.id).inserted { result.append(next) }
        }
        return result
    }
}

/// History pagination is independent of the current conversation and home preview.
@MainActor
final class MentorHistoryStore: ObservableObject {
    @Published private(set) var sessions: [MentorSessionSummary] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var hasMore = false
    private let repository: MentorRepository
    private let legacyNudgeAdapter: LegacyNudgeAdapter?
    private var pager = MentorHistoryPager()
    private var task: Task<Void, Never>?
    private var generation = UUID()

    init(repository: MentorRepository, legacyNudgeAdapter: LegacyNudgeAdapter? = nil) {
        self.repository = repository
        self.legacyNudgeAdapter = legacyNudgeAdapter
    }
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
                var nextPager = MentorHistoryPager()
                for _ in 0..<pageCount {
                    refreshed += try await nextPager.nextPage(repository: repository, legacy: legacyNudgeAdapter)
                    if !nextPager.hasMore { break }
                }
                try Task.checkCancellation()
                guard generation == token else { return }
                sessions = refreshed
                pager = nextPager
                hasMore = nextPager.hasMore
            } catch {
                guard !Task.isCancelled, generation == token else { return }
                self.error = "交流记录暂时无法读取，请重试。"
            }
            isLoading = false
        }
    }

    func loadMore() {
        guard !isLoading, hasMore else { return }
        let token = generation
        isLoading = true
        error = nil
        task = Task { [weak self] in
            guard let self else { return }
            do {
                var nextPager = pager
                let page = try await nextPager.nextPage(repository: repository, legacy: legacyNudgeAdapter)
                try Task.checkCancellation()
                guard generation == token else { return }
                sessions += page
                pager = nextPager
                hasMore = nextPager.hasMore
            } catch {
                guard !Task.isCancelled, generation == token else { return }
                self.error = "更多交流暂时无法读取，请重试。"
            }
            isLoading = false
        }
    }

}
