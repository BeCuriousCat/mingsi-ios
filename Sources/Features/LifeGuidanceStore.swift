import Foundation

@MainActor
final class LifeGuidanceStore: ObservableObject {
    @Published private(set) var exposures: [LifeGuidanceExposure] = []
    @Published private(set) var feedback: [LifeGuidanceFeedback] = []
    @Published private(set) var dayKey = CaptureDayKey.value(for: .now)
    @Published private(set) var errorMessage: String?
    @Published private(set) var isMatching = false
    private let repository: LifeGuidanceRepository?
    private let catalog: [LifeGuidanceItem]
    let referenceBook: LifeGuidanceReferenceBook
    private let now: () -> Date
    private let chooseIndex: (Int) -> Int
    private let onChange: (() -> Void)?
    private let referenceBookmarkDefaults: UserDefaults?
    private var refreshTask: Task<Void, Never>?
    private static let referenceBookmarkKey = "mingsi.lifeGuidance.referenceBookmarks"

    init(repository: LifeGuidanceRepository?, catalog: [LifeGuidanceItem] = BuiltinLifeGuidanceCatalog.items,
         referenceBook: LifeGuidanceReferenceBook = .loadBundled(),
         now: @escaping () -> Date = { .now }, chooseIndex: @escaping (Int) -> Int = { Int.random(in: 0..<$0) },
         onChange: (() -> Void)? = nil,
         referenceBookmarkDefaults: UserDefaults? = nil) {
        self.repository = repository; self.catalog = catalog + referenceBook.recommendationItems; self.referenceBook = referenceBook
        self.now = now; self.chooseIndex = chooseIndex
        self.onChange = onChange
        self.referenceBookmarkDefaults = referenceBookmarkDefaults
    }

    var cards: [LifeGuidanceCardContext] {
        let today = exposures.filter { $0.dayKey == dayKey && $0.item != nil }
        let latestReview = today.filter { $0.trigger == .dailyReview }.max { $0.createdAt < $1.createdAt }
        let active = today.filter { $0.trigger == .daily || $0.id == latestReview?.id }.sorted {
            if $0.trigger != $1.trigger { return $0.trigger == .daily }
            return $0.createdAt > $1.createdAt
        }
        var result: [LifeGuidanceCardContext] = []
        for exposure in active {
            guard let item = exposure.item, state(for: item)?.dismissedDayKeys.contains(dayKey) != true else { continue }
            if let index = result.firstIndex(where: { $0.item.contentHash == item.contentHash }) {
                result[index].triggers.insert(exposure.trigger)
                if exposure.trigger == .dailyReview {
                    result[index].event = exposure.event
                    result[index].explanation = exposure.explanation
                }
            } else {
                result.append(LifeGuidanceCardContext(item: item, triggers: [exposure.trigger], event: exposure.event, explanation: exposure.explanation))
            }
        }
        return result
    }

    var savedItems: [LifeGuidanceFeedback] { feedback.filter { $0.isSaved || $0.hasTried }.sorted { $0.updatedAt > $1.updatedAt } }

    /// The complete reviewed catalogue is available as a browseable reference.
    /// Daily selection and review matching still use their own rules.
    var catalogItems: [LifeGuidanceItem] {
        LifeGuidanceSelector(catalog: catalog).approvedItems()
    }

    var catalogCategories: [String] {
        Array(Set(catalogItems.map(\.category))).sorted()
    }

    var referenceEntries: [LifeGuidanceReferenceEntry] { referenceBook.entries }

    var recommendationItems: [LifeGuidanceItem] { LifeGuidanceSelector(catalog: catalog).eligibleItems() }

    var bookmarkedReferenceRecords: [LifeGuidanceFeedback] {
        savedItems.filter { $0.isSaved && $0.item.referenceEntry != nil }
    }

    var bookmarkedReferenceEntries: [LifeGuidanceReferenceEntry] {
        bookmarkedReferenceRecords.compactMap { $0.item.referenceEntry }
    }

    func isBookmarked(_ entry: LifeGuidanceReferenceEntry) -> Bool {
        bookmarkedReferenceRecords.contains { $0.item.referenceEntry == entry }
    }

    @discardableResult
    func toggleBookmark(_ entry: LifeGuidanceReferenceEntry) async -> Bool {
        guard let item = referenceBook.item(for: entry) else { return false }
        return await update(item) { $0.isSaved.toggle() }
    }

    func state(for item: LifeGuidanceItem) -> LifeGuidanceFeedback? {
        feedback.first { $0.item.id == item.id && $0.item.contentHash == item.contentHash }
    }

    func refresh() async {
        if let refreshTask { await refreshTask.value; return }
        let task = Task { [self] in
            defer { refreshTask = nil }
            dayKey = CaptureDayKey.value(for: now())
            guard let repository else {
                errorMessage = "建议记录暂不可用，请重启后重试。"
                return
            }
            do {
                let loadedExposures = try await repository.exposures()
                let loadedFeedback = try await repository.feedback()
                exposures = loadedExposures; feedback = loadedFeedback
                // Migrate the old ID-only bookmarks only after every snapshot is saved.
                let legacyIDs = referenceBookmarkDefaults?.stringArray(forKey: Self.referenceBookmarkKey) ?? []
                for legacyID in legacyIDs {
                    guard let item = recommendationItems.first(where: { $0.id == legacyID }) else { continue }
                    var value = state(for: item) ?? LifeGuidanceFeedback(item: item, updatedAt: now())
                    value.isSaved = true
                    try await repository.saveFeedback(value)
                    feedback.removeAll { $0.id == value.id }
                    feedback.append(value)
                    onChange?()
                }
                if !legacyIDs.isEmpty {
                    let unresolved = legacyIDs.filter { id in !recommendationItems.contains { $0.id == id } }
                    if unresolved.isEmpty { referenceBookmarkDefaults?.removeObject(forKey: Self.referenceBookmarkKey) }
                    else { referenceBookmarkDefaults?.set(unresolved, forKey: Self.referenceBookmarkKey) }
                }
                let id = "daily:" + dayKey
                if !exposures.contains(where: { $0.id == id }) {
                    let items = recommendationItems
                    if !items.isEmpty {
                        let index = min(max(chooseIndex(items.count), 0), items.count - 1)
                        let exposure = try await repository.insertExposure(LifeGuidanceExposure(id: id, dayKey: dayKey,
                            trigger: .daily, item: items[index], event: nil, explanation: nil, createdAt: now()))
                        exposures.append(exposure)
                        onChange?()
                    }
                }
                errorMessage = nil
            } catch { errorMessage = "建议记录没有读取成功，请重试。已有记录仍保留。" }
        }
        refreshTask = task
        await task.value
    }

    /// Persist empty decisions too: returning to the same review does not make another model request.
    func recommend(reviewID: String, events: [LifeGuidanceEvent], matcher: LifeGuidanceReviewMatching) async {
        guard !isMatching else { return }
        isMatching = true
        defer { isMatching = false }
        await refresh()
        let id = "review:" + reviewID
        guard errorMessage == nil, let repository, !exposures.contains(where: { $0.id == id }),
              !events.isEmpty, Set(events.map(\.id)).count == events.count,
              events.allSatisfy({ !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { return }
        let candidates = recommendationItems.filter { item in
            !exposures.contains { exposure in
                guard exposure.trigger == .dailyReview, exposure.item?.id == item.id,
                      let days = LifeGuidanceCalendar.distance(from: exposure.dayKey, to: dayKey) else { return false }
                return (0..<14).contains(days)
            }
        }
        do {
            let decision = try await matcher.match(events: events, candidates: candidates)
            try Task.checkCancellation()
            // Only a validated candidate from this exact input can enter the local history.
            if let decision {
                guard candidates.contains(decision.item),
                      events.contains(where: { $0.id == decision.event.id && $0.text.contains(decision.event.text) }) else { throw LifeGuidanceReviewError.invalidResponse }
            }
            let stored = try await repository.insertExposure(LifeGuidanceExposure(id: id, dayKey: dayKey,
                trigger: .dailyReview, item: decision?.item, event: decision?.event,
                explanation: decision?.explanation, createdAt: now()))
            exposures.append(stored)
            onChange?()
            errorMessage = nil
        } catch is CancellationError { }
        catch { errorMessage = "回顾相关建议暂未匹配成功，回顾内容已保留。" }
    }

    @discardableResult
    func update(_ item: LifeGuidanceItem, change: (inout LifeGuidanceFeedback) -> Void) async -> Bool {
        guard let repository else { errorMessage = "建议记录暂不可用，请重启后重试。"; return false }
        var value = state(for: item) ?? LifeGuidanceFeedback(item: item, updatedAt: now())
        change(&value)
        value.updatedAt = now()
        do {
            try await repository.saveFeedback(value)
            feedback.removeAll { $0.id == value.id }
            feedback.append(value)
            errorMessage = nil
            onChange?()
            return true
        } catch { errorMessage = "没有保存成功，请重试。输入内容仍保留。"; return false }
    }

    @discardableResult
    func deleteRecord(_ value: LifeGuidanceFeedback) async -> Bool {
        guard let repository else { return false }
        do {
            try await repository.deleteFeedback(id: value.id)
            feedback.removeAll { $0.id == value.id }
            onChange?()
            return true
        } catch { errorMessage = "记录没有删除成功，请重试。"; return false }
    }

    func deleteReview(sessionID: UUID) async throws {
        guard let repository else { return }
        let prefix = "review:mentor:" + sessionID.uuidString
        try await repository.deleteReviewExposures(prefix: prefix)
        exposures.removeAll { $0.id.hasPrefix(prefix) }
        onChange?()
    }
}
