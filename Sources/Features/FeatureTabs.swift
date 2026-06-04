import SwiftUI
import UIKit

enum HistoryFilterChipKind {
    case project
    case lens
    case cardType
    case questStatus
}

enum HistoryFilterChipMetrics {
    static func minWidth(for kind: HistoryFilterChipKind) -> CGFloat {
        switch kind {
        case .project:
            return 86
        case .lens:
            return 82
        case .cardType, .questStatus:
            return 96
        }
    }

    static func maxWidth(for kind: HistoryFilterChipKind) -> CGFloat {
        switch kind {
        case .project:
            return 136
        case .lens:
            return 128
        case .cardType, .questStatus:
            return 118
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedDate = Date()
    @State private var isCalendarPresented = false
    @State private var isRawInputExpanded = false
    @State private var highlightedSourceId: String?
    @State private var searchText = ""
    @State private var evidenceFilter: HistoryEvidenceFilter = .all
    @State private var selectedProjectFilter: UUID?
    @State private var selectedLensFilter: ThinkingLens?
    @State private var selectedCardTypeFilter: ThinkingCardType?
    @State private var selectedQuestStatusFilter: QuestStatus?
    @State private var repairablePromptRuns: [PromptRun] = []
    @State private var isLoadingRepairablePromptRuns = false
    @State private var historicalRetryCandidates: [HistoricalRetryCandidate] = []

    private var records: [HistoryRecord] {
        if store.historyRecords.isEmpty {
            return [
                HistoryRecord(
                    draft: store.todayDraft,
                    cards: store.thinkingCards,
                    quests: store.quests,
                    principles: store.principles,
                    verification: nil,
                    lensSession: store.todayDraft.selectedLens.map { lens in
                        LensSession(dailyEntryId: store.todayDraft.id, selectedLens: lens, questions: store.questions)
                    }
                )
            ]
        }
        return store.historyRecords
    }

    private var historyQuery: HistorySearchQuery {
        HistorySearchQuery(
            text: searchText,
            filter: evidenceFilter,
            projectId: selectedProjectFilter,
            lens: selectedLensFilter,
            cardType: selectedCardTypeFilter,
            questStatus: selectedQuestStatusFilter
        )
    }

    private var visibleRecords: [HistoryRecord] {
        historyQuery.apply(to: records)
    }

    private var selectedRecord: HistoryRecord? {
        let calendar = Calendar.current
        if let link = store.historyDeepLink {
            return records.first { $0.draft.id == link.dailyEntryId }
        }
        let source = historyQuery.isActive ? visibleRecords : records
        return source.first { calendar.isDate($0.draft.date, inSameDayAs: selectedDate) }
    }

    private var visibleRecord: HistoryRecord {
        selectedRecord ?? visibleRecords.first ?? records.first ?? HistoryRecord(
            draft: store.todayDraft,
            cards: store.thinkingCards,
            quests: store.quests,
            principles: store.principles,
            verification: nil,
            lensSession: store.todayDraft.selectedLens.map { lens in
                LensSession(dailyEntryId: store.todayDraft.id, selectedLens: lens, questions: store.questions)
            }
        )
    }

    private var evidenceCounts: String {
        var parts: [String] = []
        if !visibleRecord.cards.isEmpty { parts.append(visibleRecord.cardCountSummary) }
        if !visibleRecord.quests.isEmpty { parts.append("\(visibleRecord.quests.count) 任务") }
        if !visibleRecord.principles.isEmpty { parts.append("\(visibleRecord.principles.count) 原则") }
        if !visibleRecord.projectLinks.isEmpty { parts.append("\(visibleRecord.projectLinks.count) 项目") }
        if !visibleRecord.growthContributions.isEmpty { parts.append("\(visibleRecord.growthContributions.count) 成长") }
        return parts.isEmpty ? "暂无证据" : parts.joined(separator: " / ")
    }

    private var advancedFilterCount: Int {
        [selectedProjectFilter != nil, selectedLensFilter != nil, selectedCardTypeFilter != nil, selectedQuestStatusFilter != nil]
            .filter { $0 }
            .count
    }

    private var projectFilterOptions: [(id: UUID, name: String)] {
        let ids = records.flatMap(\.projectLinks).map(\.projectId)
        return Array(Set(ids))
            .map { id in
                (id: id, name: store.projectNames[id] ?? String(id.uuidString.prefix(8)).lowercased())
            }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    private var lensFilterOptions: [ThinkingLens] {
        let lenses = records.compactMap(\.lensSession?.selectedLens)
        return ThinkingLens.allCases.filter { lenses.contains($0) }
    }

    private var cardTypeFilterOptions: [ThinkingCardType] {
        let types = records.flatMap(\.cards).map(\.type)
        return ThinkingCardType.allCases.filter { types.contains($0) }
    }

    private var questStatusFilterOptions: [QuestStatus] {
        let statuses = records.flatMap(\.quests).map(\.status)
        return QuestStatus.allCases.filter { statuses.contains($0) }
    }

    var body: some View {
        FeatureContainer(title: "历史", subtitle: "回看事实、判断和行动证据。") {
            VStack(alignment: .leading, spacing: 18) {
                if store.hasResumeableLoop && !store.isResumeBannerDismissed {
                    ResumeTodayRow()
                }

                historySearchSection

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedRecord == nil ? "没有匹配记录" : "正在查看")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.mutedInk)
                        Text(visibleRecord.draft.date.mingsiDisplayDate)
                            .font(.headline)
                            .foregroundStyle(DS.ink)
                    }
                    Spacer()
                    Text(historyQuery.isActive ? "\(visibleRecords.count) 条匹配" : evidenceCounts)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                    Button {
                        isCalendarPresented = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DS.accent)
                            .frame(width: 38, height: 38)
                            .background(DS.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(DS.hairline, lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("打开历史日历")
                }

                HistoryDayHeader(
                    date: visibleRecord.draft.date,
                    title: visibleRecord.draft.state == .sessionComplete ? "闭环完成" : "复盘记录",
                    subtitle: evidenceCounts
                )

                if selectedRecord == nil {
                    EmptyStateLine(text: historyQuery.isActive ? "没有匹配的历史证据。试试换一个关键词或证据类型。" : "这一天还没有复盘记录。打开日历可以往前查看一周、一个月或一年。")
                } else {
                    highlightNotice
                    aiRepairSection
                    rawInputSection
                    cardsSection
                    lensAndQuestionsSection
                    questsSection
                    verificationSection
                    principlesSection
                    projectEvidenceSection
                    growthContributionSection
                }
            }
        }
        .task {
            await store.loadHistoryRecords()
            if let link = store.historyDeepLink {
                highlightedSourceId = link.sourceId
                if let linkedRecord = records.first(where: { $0.draft.id == link.dailyEntryId }) {
                    selectedDate = linkedRecord.draft.date
                }
            } else if let latest = records.first?.draft.date {
                selectedDate = latest
            }
            await loadRepairablePromptRunsForVisibleRecord()
        }
        .onChange(of: store.historyDeepLink) { _, newLink in
            if let newLink {
                highlightedSourceId = newLink.sourceId
                if let linkedRecord = records.first(where: { $0.draft.id == newLink.dailyEntryId }) {
                    selectedDate = linkedRecord.draft.date
                }
                store.historyDeepLink = nil
            }
            Task { await loadRepairablePromptRunsForVisibleRecord() }
        }
        .onChange(of: searchText) { _, _ in
            syncSelectedDateWithFilteredRecords()
            Task { await loadRepairablePromptRunsForVisibleRecord() }
        }
        .onChange(of: evidenceFilter) { _, _ in
            syncSelectedDateWithFilteredRecords()
            Task { await loadRepairablePromptRunsForVisibleRecord() }
        }
        .onChange(of: selectedProjectFilter) { _, _ in
            syncSelectedDateWithFilteredRecords()
            Task { await loadRepairablePromptRunsForVisibleRecord() }
        }
        .onChange(of: selectedLensFilter) { _, _ in
            syncSelectedDateWithFilteredRecords()
            Task { await loadRepairablePromptRunsForVisibleRecord() }
        }
        .onChange(of: selectedCardTypeFilter) { _, _ in
            syncSelectedDateWithFilteredRecords()
            Task { await loadRepairablePromptRunsForVisibleRecord() }
        }
        .onChange(of: selectedQuestStatusFilter) { _, _ in
            syncSelectedDateWithFilteredRecords()
            Task { await loadRepairablePromptRunsForVisibleRecord() }
        }
        .onChange(of: selectedDate) { _, _ in
            Task { await loadRepairablePromptRunsForVisibleRecord() }
        }
        .sheet(isPresented: $isCalendarPresented) {
            HistoryCalendarSheet(
                records: historyQuery.isActive ? visibleRecords : records,
                selectedDate: $selectedDate
            )
            .presentationDetents([.large])
            .presentationContentInteraction(.scrolls)
            .presentationDragIndicator(.visible)
        }
    }

    private var historySearchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
                TextField("搜索历史证据", text: $searchText)
                    .font(.subheadline)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(DS.ink)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DS.mutedInk.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清除搜索")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DS.hairline, lineWidth: 1)
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HistoryEvidenceFilter.allCases) { filter in
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                evidenceFilter = filter
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: filter.systemImage)
                                    .font(.caption2.weight(.bold))
                                Text(filter.title)
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(evidenceFilter == filter ? DS.ink : DS.mutedInk)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                evidenceFilter == filter ? DS.accent.opacity(0.10) : DS.surface.opacity(0.65),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(evidenceFilter == filter ? DS.accent.opacity(0.35) : DS.hairline, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }

            advancedFilterSection
        }
    }

    private var advancedFilterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(advancedFilterCount == 0 ? "细筛" : "细筛 \(advancedFilterCount)", systemImage: "line.3.horizontal.decrease.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
                Spacer()
                if advancedFilterCount > 0 {
                    Button {
                        applyAdvancedFilterChange(clearAdvancedFilters)
                    } label: {
                        Text("清空")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    historyFilterMenu(
                        kind: .project,
                        title: selectedProjectFilter.flatMap(projectFilterTitle) ?? "项目",
                        systemImage: "folder",
                        isActive: selectedProjectFilter != nil,
                        isDisabled: projectFilterOptions.isEmpty
                    ) {
                        Button("全部项目") { applyAdvancedFilterChange { selectedProjectFilter = nil } }
                        ForEach(projectFilterOptions, id: \.id) { option in
                            Button(option.name) { applyAdvancedFilterChange { selectedProjectFilter = option.id } }
                        }
                    }

                    historyFilterMenu(
                        kind: .lens,
                        title: selectedLensFilter?.title ?? "透镜",
                        systemImage: "eye",
                        isActive: selectedLensFilter != nil,
                        isDisabled: lensFilterOptions.isEmpty
                    ) {
                        Button("全部透镜") { applyAdvancedFilterChange { selectedLensFilter = nil } }
                        ForEach(lensFilterOptions) { lens in
                            Button(lens.title) { applyAdvancedFilterChange { selectedLensFilter = lens } }
                        }
                    }

                    historyFilterMenu(
                        kind: .cardType,
                        title: selectedCardTypeFilter?.title ?? "卡片类型",
                        systemImage: "rectangle.stack",
                        isActive: selectedCardTypeFilter != nil,
                        isDisabled: cardTypeFilterOptions.isEmpty
                    ) {
                        Button("全部卡片") { applyAdvancedFilterChange { selectedCardTypeFilter = nil } }
                        ForEach(cardTypeFilterOptions) { cardType in
                            Button(cardType.title) { applyAdvancedFilterChange { selectedCardTypeFilter = cardType } }
                        }
                    }

                    historyFilterMenu(
                        kind: .questStatus,
                        title: selectedQuestStatusFilter?.historyTitle ?? "任务状态",
                        systemImage: "checkmark.circle",
                        isActive: selectedQuestStatusFilter != nil,
                        isDisabled: questStatusFilterOptions.isEmpty
                    ) {
                        Button("全部状态") { applyAdvancedFilterChange { selectedQuestStatusFilter = nil } }
                        ForEach(questStatusFilterOptions) { status in
                            Button(status.historyTitle) { applyAdvancedFilterChange { selectedQuestStatusFilter = status } }
                        }
                    }
                }
                .padding(.vertical, 2)
                .transaction { transaction in
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }
        }
        .padding(.top, 2)
    }

    private func historyFilterMenu<Items: View>(
        kind: HistoryFilterChipKind,
        title: String,
        systemImage: String,
        isActive: Bool,
        isDisabled: Bool,
        @ViewBuilder items: () -> Items
    ) -> some View {
        Menu {
            items()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .foregroundStyle(isActive ? DS.ink : DS.mutedInk)
            .frame(
                minWidth: HistoryFilterChipMetrics.minWidth(for: kind),
                maxWidth: HistoryFilterChipMetrics.maxWidth(for: kind),
                alignment: .leading
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isActive ? DS.note.opacity(0.12) : DS.surface.opacity(0.65), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(isActive ? DS.note.opacity(0.35) : DS.hairline, lineWidth: 1)
            )
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    private func projectFilterTitle(for projectId: UUID) -> String {
        store.projectNames[projectId] ?? String(projectId.uuidString.prefix(8)).lowercased()
    }

    private func clearAdvancedFilters() {
        selectedProjectFilter = nil
        selectedLensFilter = nil
        selectedCardTypeFilter = nil
        selectedQuestStatusFilter = nil
    }

    private func applyAdvancedFilterChange(_ update: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            update()
        }
    }

    private func syncSelectedDateWithFilteredRecords() {
        guard historyQuery.isActive else { return }
        let calendar = Calendar.current
        if visibleRecords.contains(where: { calendar.isDate($0.draft.date, inSameDayAs: selectedDate) }) {
            return
        }
        if let first = visibleRecords.first {
            selectedDate = first.draft.date
        }
    }

    private func loadRepairablePromptRunsForVisibleRecord() async {
        let dailyEntryId = visibleRecord.draft.id
        isLoadingRepairablePromptRuns = true
        async let runs = store.repairablePromptRuns(for: dailyEntryId)
        async let candidates = store.historicalRetryCandidates(for: dailyEntryId)
        let (loadedRuns, loadedCandidates) = await (runs, candidates)
        if visibleRecord.draft.id == dailyEntryId {
            repairablePromptRuns = loadedRuns
            historicalRetryCandidates = loadedCandidates
            isLoadingRepairablePromptRuns = false
        }
    }

    @ViewBuilder
    private var highlightNotice: some View {
        if let highlightedSourceId {
            HStack(spacing: 8) {
                Image(systemName: didLocateHighlightedSource ? "scope" : "exclamationmark.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(didLocateHighlightedSource ? DS.accent : DS.caution)
                Text(didLocateHighlightedSource ? "已定位到来源证据" : "已跳转到来源日期，未定位到具体证据")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
                Spacer()
                Text(highlightedSourceId.prefix(8))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DS.mutedInk.opacity(0.7))
            }
            .summarySurface()
        }
    }

    private var didLocateHighlightedSource: Bool {
        guard let highlightedSourceId else { return false }
        return visibleRecord.sourceIds.contains(highlightedSourceId)
    }

    private func hasProjectLink(sourceId: String) -> Bool {
        visibleRecord.projectLinks.contains { $0.sourceId == sourceId }
    }

    private func isHighlighted(_ id: UUID) -> Bool {
        highlightedSourceId == id.uuidString
    }

    @ViewBuilder
    private var aiRepairSection: some View {
        let unresolvedRuns = repairablePromptRuns.filter { run in
            !historicalRetryCandidates.contains { $0.failedPromptRunId == run.id }
        }

        if isLoadingRepairablePromptRuns {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("正在检查本日 AI 失败记录")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
                Spacer()
            }
            .summarySurface()
        } else if !repairablePromptRuns.isEmpty || !historicalRetryCandidates.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DS.caution)
                    Text("历史 AI 修复")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.ink)
                    Spacer()
                }

                if let summaryLine = HistoryRepairSummary(
                    unresolvedCount: unresolvedRuns.count,
                    reviewableCount: historicalRetryCandidates.filter { $0.status == .candidateReady }.count,
                    completedCount: historicalRetryCandidates.filter { $0.status == .accepted || $0.status == .dismissed }.count,
                    problemCount: historicalRetryCandidates.filter { $0.status == .failed || $0.status == .blocked }.count
                ).summaryLine {
                    Text(summaryLine)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                }

                VStack(spacing: 8) {
                    ForEach(unresolvedRuns) { run in
                        historyRepairableRunRow(run: run)
                    }
                }

                ForEach(historicalRetryCandidates) { candidate in
                    historicalCandidateRow(candidate: candidate)
                }

                if visibleRecord.draft.id == store.todayDraft.id {
                    Button {
                        store.retryPendingAIRepairs()
                    } label: {
                        Label("后台重试当前记录", systemImage: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .summarySurface()
        }
    }

    @ViewBuilder
    private func historyRepairableRunRow(run: PromptRun) -> some View {
        let promptName = PromptID(rawValue: run.promptId)?.displayName ?? run.promptId
        let canRetry = HistoryRepairPromptSupport.canStartHistoricalRetry(promptId: run.promptId)

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(promptName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.ink)
                if canRetry {
                    Text("可修复")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(DS.caution)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(DS.caution.opacity(0.10), in: Capsule())
                } else {
                    Text("暂不支持")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(DS.mutedInk)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(DS.mutedInk.opacity(0.08), in: Capsule())
                }
                Spacer(minLength: 8)
                Text(run.createdAt.mingsiShortDate)
                    .font(.caption2)
                    .foregroundStyle(DS.mutedInk)
            }

            Text(run.error?.isEmpty == false ? run.error ?? "" : run.requestSummary)
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .lineLimit(2)

            Text(canRetry ? "待生成候选 · 点击下方按钮开始修复" : "仅审计 · 暂不支持此类历史修复")
                .font(.caption)
                .foregroundStyle(DS.mutedInk.opacity(0.7))

            if canRetry {
                Button {
                    Task {
                        await store.startHistoricalOrganizeCardsRetry(failedPromptRunId: run.id)
                        await loadRepairablePromptRunsForVisibleRecord()
                    }
                } label: {
                    Label("生成候选卡片", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(DS.accent)
            } else {
                Text("暂不支持此类历史修复")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk.opacity(0.7))
            }
        }
        .padding(10)
        .background(DS.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                .stroke(canRetry ? DS.caution.opacity(0.16) : DS.hairline, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func historicalCandidateRow(candidate: HistoricalRetryCandidate) -> some View {
        let previews = HistoryRepairCardPreview.decode(from: candidate.candidatePayloadJSON)

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(candidate.status.historyRepairTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(candidateStatusColor(candidate.status))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(candidateStatusColor(candidate.status).opacity(0.10), in: Capsule())
                Text(candidate.promptId.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.ink)
                Spacer(minLength: 8)
                Text(candidate.createdAt.mingsiShortDate)
                    .font(.caption2)
                    .foregroundStyle(DS.mutedInk)
            }

            Text(candidate.status.historyRepairDetail)
                .font(.caption)
                .foregroundStyle(DS.mutedInk.opacity(0.7))

            if !candidate.reconstructedInputSummary.isEmpty {
                Text(candidate.reconstructedInputSummary)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .lineLimit(2)
            }

            if let error = candidate.error, !error.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(DS.caution)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .lineLimit(2)
                }
            }

            if let blockedReason = candidate.blockedReason, !blockedReason.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(DS.mutedInk)
                    Text(blockedReason)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .lineLimit(2)
                }
            }

            if !previews.isEmpty {
                VStack(spacing: 6) {
                    Text("候选卡片")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    ForEach(Array(previews.enumerated()), id: \.offset) { _, preview in
                        candidateCardPreviewRow(preview: preview)
                    }
                }
            }

            if visibleRecord.hasHistoricalRepairBlockingEvidence {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(DS.note)
                    Text("该记录已有已确认卡片或下游证据，接受候选可能被阻断。")
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                }
            }

            if candidate.status == .candidateReady {
                HStack(spacing: 10) {
                    Button {
                        Task {
                            await store.acceptHistoricalRetryCandidate(candidate.id)
                            await loadRepairablePromptRunsForVisibleRecord()
                        }
                    } label: {
                        Label("接受候选", systemImage: "checkmark.circle")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(DS.accent)

                    Button {
                        Task {
                            await store.dismissHistoricalRetryCandidate(candidate.id)
                            await loadRepairablePromptRunsForVisibleRecord()
                        }
                    } label: {
                        Label("忽略本次结果", systemImage: "xmark.circle")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(10)
        .background(DS.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                .stroke(candidateStatusColor(candidate.status).opacity(0.20), lineWidth: 1)
        )
    }

    private func candidateCardPreviewRow(preview: HistoryRepairCardPreview) -> some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(DS.mutedInk.opacity(0.30))
                .frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(preview.type)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                    Text(preview.priority)
                        .font(.caption2)
                        .foregroundStyle(DS.mutedInk.opacity(0.6))
                }
                Text(preview.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.ink)
                Text(preview.body)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(8)
        .background(DS.background, in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
    }

    private func candidateStatusColor(_ status: HistoricalRetryCandidateStatus) -> Color {
        switch status {
        case .pending, .retrying:
            return DS.mutedInk
        case .candidateReady:
            return DS.accent
        case .accepted:
            return DS.success
        case .dismissed:
            return DS.mutedInk
        case .blocked:
            return DS.caution
        case .failed:
            return DS.caution
        }
    }

    // MARK: - Raw Input

    private var rawInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isRawInputExpanded.toggle()
                }
            } label: {
                HStack {
                    SectionLabel("原始输入")
                    Spacer()
                    Image(systemName: isRawInputExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                }
            }
            .buttonStyle(.plain)

            if isRawInputExpanded {
                Text(visibleRecord.draft.rawText.isEmpty ? "（无原始输入）" : visibleRecord.draft.rawText)
                    .font(.subheadline)
                    .foregroundStyle(visibleRecord.draft.rawText.isEmpty ? DS.mutedInk : DS.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .evidenceSurface(isHighlighted: isHighlighted(visibleRecord.draft.id))
            }
        }
    }

    // MARK: - Cards

    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("卡片")
            if visibleRecord.cards.isEmpty {
                EmptyStateLine(text: "这一天没有沉淀卡片。")
            } else {
                let confirmed = visibleRecord.cards.filter { $0.isConfirmed }
                let excluded = visibleRecord.cards.filter { $0.isExcludedFromModel }
                ForEach(Array(confirmed.enumerated()), id: \.element.id) { index, card in
                    HistoryTimelineRow(index: index + 1, card: card, isHighlighted: isHighlighted(card.id))
                }
                if !excluded.isEmpty {
                    ForEach(excluded) { card in
                        HStack(spacing: 8) {
                            Text(card.type.title)
                                .font(.caption)
                                .foregroundStyle(DS.mutedInk)
                            Text(card.title)
                                .font(.subheadline)
                                .foregroundStyle(DS.mutedInk)
                                .strikethrough()
                            Spacer()
                            Text("已排除")
                                .font(.caption)
                                .foregroundStyle(DS.mutedInk.opacity(0.6))
                        }
                        .evidenceSurface(isHighlighted: isHighlighted(card.id))
                    }
                }
            }
        }
    }

    // MARK: - Lens & Questions

    private var lensAndQuestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("透镜与追问")
            if let session = visibleRecord.lensSession {
                HStack(spacing: 8) {
                    Image(systemName: "eye")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DS.accent)
                    Text(session.selectedLens.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.ink)
                    Spacer()
                    Text(session.selectedLens.subtitle)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .lineLimit(1)
                }
                .summarySurface()

                let answered = session.questions.filter { !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                let unanswered = session.questions.filter { $0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

                ForEach(answered) { question in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(question.question)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(DS.ink)
                        Text(question.answer)
                            .font(.subheadline)
                            .foregroundStyle(DS.mutedInk)
                    }
                    .questionSurface()
                }

                if !unanswered.isEmpty {
                    ForEach(unanswered) { question in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(question.question)
                                .font(.subheadline)
                                .foregroundStyle(DS.mutedInk)
                            Text("未回答")
                                .font(.caption)
                                .foregroundStyle(DS.mutedInk.opacity(0.5))
                        }
                        .summarySurface()
                    }
                }
            } else {
                EmptyStateLine(text: "这一天没有选择思考透镜。")
            }
        }
    }

    // MARK: - Quests

    private var questsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("明日任务")
            if visibleRecord.quests.isEmpty {
                EmptyStateLine(text: "这一天没有生成明日任务。")
            } else {
                if let mainQuest = visibleRecord.mainQuest {
                    QuestRowCompact(
                        quest: mainQuest,
                        isHighlighted: isHighlighted(mainQuest.id),
                        onSaveProject: hasProjectLink(sourceId: mainQuest.id.uuidString) ? nil : {
                            Task {
                                await store.createProjectFromQuest(mainQuest, dailyEntryId: visibleRecord.draft.id)
                            }
                        }
                    )
                }
                let others = visibleRecord.quests.filter { $0.type != .main }
                ForEach(others) { quest in
                    QuestRowCompact(
                        quest: quest,
                        isHighlighted: isHighlighted(quest.id),
                        onSaveProject: hasProjectLink(sourceId: quest.id.uuidString) ? nil : {
                            Task {
                                await store.createProjectFromQuest(quest, dailyEntryId: visibleRecord.draft.id)
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Verification

    private var verificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("昨日验证")
            if let verification = visibleRecord.verification {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Label("反馈", systemImage: "bubble.left.and.bubble.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.caution)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(DS.caution.opacity(0.10), in: Capsule())
                        Label("来源：昨日主线", systemImage: "arrow.uturn.backward")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.mutedInk)
                        Spacer()
                    }
                    HStack(spacing: 12) {
                        Label(verification.completion.title, systemImage: verification.completion.title == "完成" ? "checkmark.circle" : "circle")
                            .font(.subheadline)
                            .foregroundStyle(DS.ink)
                        Label(verification.valueRating.title, systemImage: "star")
                            .font(.subheadline)
                            .foregroundStyle(DS.ink)
                        Spacer()
                    }
                    Text(verification.calibrationNote)
                        .font(.subheadline)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                    if let issue = verification.likelyIssue, !issue.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(DS.caution)
                            Text(issue)
                                .font(.caption)
                                .foregroundStyle(DS.mutedInk)
                        }
                    }
                    if let rec = verification.recommendation, !rec.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb")
                                .font(.caption)
                                .foregroundStyle(DS.note)
                            Text(rec)
                                .font(.caption)
                                .foregroundStyle(DS.mutedInk)
                        }
                    }
                }
                .evidenceSurface(isHighlighted: isHighlighted(verification.id))
            } else {
                EmptyStateLine(text: "这一天没有验证记录。")
            }
        }
    }

    // MARK: - Principles

    private var principlesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("原则资产")
            if visibleRecord.principles.isEmpty {
                EmptyStateLine(text: "当某个行为规则足够稳定时，会被沉淀为原则资产。")
            } else {
                ForEach(visibleRecord.principles) { principle in
                    PrincipleArchiveRow(
                        principle: principle,
                        isHighlighted: isHighlighted(principle.id),
                        onSaveProject: hasProjectLink(sourceId: principle.id.uuidString) ? nil : {
                            Task {
                                await store.createProjectFromPrinciple(principle, dailyEntryId: visibleRecord.draft.id)
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Project Evidence

    private var projectEvidenceSection: some View {
        HistoryProjectLinksSection(
            links: visibleRecord.projectLinks,
            projectNames: store.projectNames
        )
    }

    // MARK: - Growth Contributions

    private var growthContributionSection: some View {
        HistoryGrowthContributionsSection(
            contributions: visibleRecord.growthContributions
        )
    }

}

private struct QuestRowCompact: View {
    let quest: Quest
    var isHighlighted: Bool = false
    var onSaveProject: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: quest.type.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(quest.type.tint)
                .frame(width: 24, height: 24)
                .background(quest.type.tint.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(quest.type.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(quest.type.tint)
                    Text(quest.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.ink)
                    Spacer()
                }
                Text(quest.completionCriteria)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .lineLimit(2)
                if let onSaveProject {
                    Button(action: onSaveProject) {
                        Label("保存为长期议题", systemImage: "plus.circle")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DS.accent)
                    .padding(.top, 2)
                }
            }
        }
        .evidenceSurface(isHighlighted: isHighlighted, base: .quest(isMain: quest.type == .main))
    }
}

private struct HistoryProjectLinksSection: View {
    let links: [ProjectLink]
    let projectNames: [UUID: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("项目证据")
            if links.isEmpty {
                EmptyStateLine(text: "这一天没有关联的项目证据。")
            } else {
                ProjectLinkListContent(links: links, projectNames: projectNames)
            }
        }
    }
}

private struct ProjectLinkListContent: View {
    let links: [ProjectLink]
    let projectNames: [UUID: String]

    var body: some View {
        VStack(spacing: DS.cardSpacing) {
            ForEach(links) { link in
                projectLinkRow(link: link)
            }
        }
    }

    private func projectLinkRow(link: ProjectLink) -> some View {
        let name = projectNames[link.projectId] ?? String(link.projectId.uuidString.prefix(8)).lowercased()
        return HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(DS.accent)
                .frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                HStack(spacing: 8) {
                    Text(link.linkType.title)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                    Text(link.sourceType.rawValue)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                }
            }
            Spacer()
        }
        .summarySurface()
    }
}

private struct HistoryGrowthContributionsSection: View {
    let contributions: [MetricContribution]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("成长贡献")
            if contributions.isEmpty {
                EmptyStateLine(text: "这一天没有关联的成长贡献。")
            } else {
                GrowthContributionListContent(contributions: contributions)
            }
        }
    }
}

private struct GrowthContributionListContent: View {
    let contributions: [MetricContribution]

    var body: some View {
        VStack(spacing: DS.cardSpacing) {
            ForEach(contributions) { contribution in
                contributionRow(contribution: contribution)
            }
        }
    }

    private func contributionRow(contribution: MetricContribution) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(contribution.direction == .positive ? DS.success : DS.brick)
                .frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(contribution.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                HStack(spacing: 8) {
                    Text(contribution.metric.rawValue)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                    Text(String(format: "%+.2f", contribution.delta))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(contribution.direction == .positive ? DS.success : DS.brick)
                }
            }
            Spacer()
        }
        .summarySurface()
    }
}

struct ProjectsView: View {
    @EnvironmentObject private var store: AppStore

    private var projectItems: [ProjectEvidenceBoardItem] {
        var grouped: [UUID: [(link: ProjectLink, record: HistoryRecord)]] = [:]
        for record in store.historyRecords {
            for link in record.projectLinks {
                grouped[link.projectId, default: []].append((link, record))
            }
        }

        return grouped.map { projectId, entries in
            ProjectEvidenceBoardItem(
                id: projectId,
                name: store.projectNames[projectId] ?? "未命名长期议题",
                entries: entries
            )
        }
        .sorted { $0.latestDate > $1.latestDate }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    projectHeader

                    VStack(alignment: .leading, spacing: 16) {
                        if store.hasResumeableLoop && !store.isResumeBannerDismissed {
                            ResumeTodayRow()
                        }

                        ProjectCurrentFocus(
                            title: store.mainQuest?.title ?? "还没有生成主线任务",
                            detail: store.mainQuest?.completionCriteria ?? "完成今日复盘后，明日任务会成为项目推进的临时焦点。",
                            canCreateProject: store.canCreateProjectFromCurrentFocus,
                            createProject: {
                                Task {
                                    await store.createProjectFromCurrentFocus()
                                }
                            }
                        )

                        projectsCandidateReviewSection
                        projectMergeReviewSection

                        projectBoard
                    }
                    .padding(.horizontal, DS.pagePadding)
                    .padding(.top, 18)
                    .padding(.bottom, DS.primaryScrollBottomReserve)
                }
            }
            .scrollIndicators(.hidden)
            .background(DS.background.ignoresSafeArea())
            .task {
                await store.loadHistoryRecords()
                await store.loadPendingProjectMergeCandidates()
            }
        }
        .background(DS.background.ignoresSafeArea())
        .topSafeAreaScrim()
    }

    private var projectHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("项目")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(DS.ink)
            Text("不是文件夹，也不是关键词聚类；这里只放被历史证据支撑的长期议题。")
                .font(.subheadline)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.pagePadding)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(DS.background)
    }

    @ViewBuilder
    private var projectBoard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("项目工作台")
                Spacer()
                Text(projectItems.isEmpty ? "0 个证据项目" : "\(projectItems.count) 个证据项目")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DS.mutedInk)
            }

            if projectItems.isEmpty {
                ProjectEmptyEvidenceState()
            } else {
                ForEach(projectItems) { item in
                    NavigationLink {
                        ProjectDetailView(
                            item: item,
                            project: store.projectsById[item.id]
                        )
                    } label: {
                        ProjectEvidenceBoardRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var projectsCandidateReviewSection: some View {
        let pendingCandidates = store.projectCandidates.filter { $0.status == .pending }
        let pendingLinks = store.projectLinkCandidates
        if !pendingCandidates.isEmpty || !pendingLinks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel("待确认候选")
                    Spacer()
                    Text("\(pendingCandidates.count + pendingLinks.count) 条")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(DS.mutedInk)
                }

                ForEach(pendingCandidates) { candidate in
                    ProjectCandidateReviewRow(
                        candidate: candidate,
                        onAccept: {
                            Task { await store.acceptProjectCandidate(candidate) }
                        },
                        onDismiss: {
                            Task { await store.dismissProjectCandidate(candidate) }
                        }
                    )
                }
                ForEach(pendingLinks) { link in
                    ProjectLinkCandidateRow(
                        candidate: link,
                        projectName: link.projectId.flatMap { store.projectNames[$0] },
                        onAccept: {
                            Task { await store.acceptProjectLinkCandidate(link) }
                        },
                        onDismiss: {
                            store.dismissProjectLinkCandidate(link)
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var projectMergeReviewSection: some View {
        if projectItems.count >= 2 || !store.pendingProjectMergeCandidates.isEmpty || !store.projectMergeMessage.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel("议题治理")
                        Text("只检查有证据的活跃议题，合并前需要你确认。")
                            .font(.caption)
                            .foregroundStyle(DS.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Button {
                        Task { await store.suggestProjectMerges() }
                    } label: {
                        Label(store.isGeneratingProjectMerges ? "检查中" : "检查合并", systemImage: "arrow.triangle.merge")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(DS.accent)
                    .disabled(store.isGeneratingProjectMerges || projectItems.count < 2)
                }

                if store.isGeneratingProjectMerges {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(DS.accent)
                        Text("正在检查长期议题是否重叠")
                            .font(.caption)
                            .foregroundStyle(DS.mutedInk)
                    }
                } else if !store.projectMergeMessage.isEmpty {
                    Text(store.projectMergeMessage)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                }

                ForEach(store.pendingProjectMergeCandidates) { candidate in
                    ProjectMergeCandidateReviewRow(
                        candidate: candidate,
                        sourceName: store.projectNames[candidate.sourceProjectId] ?? store.projectsById[candidate.sourceProjectId]?.name ?? "源议题",
                        targetName: store.projectNames[candidate.targetProjectId] ?? store.projectsById[candidate.targetProjectId]?.name ?? "目标议题",
                        onAccept: {
                            Task { await store.acceptProjectMergeCandidate(candidate.id) }
                        },
                        onReject: {
                            Task { await store.rejectProjectMergeCandidate(candidate.id) }
                        },
                        onDismiss: {
                            Task { await store.dismissProjectMergeCandidate(candidate.id) }
                        }
                    )
                }
            }
            .summarySurface()
        }
    }
}

struct GrowthView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedMetric: GrowthMetric?
    @State private var isPresentingAddPrinciple = false

    var body: some View {
        FeatureContainer(title: "成长", subtitle: "用趋势和证据看见自己的变化。") {
            VStack(alignment: .leading, spacing: 18) {
                if store.hasResumeableLoop && !store.isResumeBannerDismissed {
                    ResumeTodayRow()
                }

                GrowthSummaryPanel(snapshot: store.growthSnapshot)
                GrowthReportActionPanel(
                    isGenerating: store.isGeneratingGrowthReport,
                    message: store.growthReportMessage,
                    onWeekly: {
                        Task { await store.generateWeeklyGrowthReport() }
                    },
                    onMonthly: {
                        Task { await store.generateMonthlyGrowthReport() }
                    }
                )
                GrowthReportReviewPanel(
                    snapshot: store.growthSnapshot,
                    contributions: store.growthReportReviewContributions,
                    onSelectMetric: { metric in
                        selectedMetric = metric
                    }
                )

                if !store.growthSnapshot.canDisplayScores {
                    GrowthEvidencePanel(
                        title: "证据积累中",
                        text: "先完成 3 次完整复盘，系统才有足够证据判断你的变化。",
                        footnote: "指标只做个人趋势，不做能力标签。"
                    )
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel("训练指标")
                        TappableMetricRow(title: "清晰度", value: store.growthSnapshot.clarity, note: "问题是否被说清楚") {
                            selectedMetric = .clarity
                        }
                        TappableMetricRow(title: "价值判断", value: store.growthSnapshot.valueJudgment, note: "是否选择高杠杆动作") {
                            selectedMetric = .valueJudgment
                        }
                        TappableMetricRow(title: "执行可靠性", value: store.growthSnapshot.executionReliability, note: "任务是否可验证") {
                            selectedMetric = .executionReliability
                        }
                        TappableMetricRow(title: "校准", value: store.growthSnapshot.calibration, note: "预判和结果是否对齐") {
                            selectedMetric = .calibration
                        }
                        TappableMetricRow(title: "反思深度", value: store.growthSnapshot.reflectionDepth, note: "是否发现更底层模式") {
                            selectedMetric = .reflectionDepth
                        }
                    }
                }

                GrowthPrincipleAssetSection(isPresentingAddPrinciple: $isPresentingAddPrinciple)
            }
        }
        .sheet(item: $selectedMetric) { metric in
            MetricDetailSheet(
                snapshot: store.growthSnapshot,
                metric: metric,
                contributions: store.metricContributions.filter { contribution in
                    contribution.metric == metric &&
                    contribution.candidateStatus == .accepted &&
                    !contribution.sourceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                },
                onSelectContribution: { contribution in
                    selectedMetric = nil
                    store.navigateToHistoryDeepLink(
                        HistoryDeepLink(
                            dailyEntryId: contribution.sourceDailyEntryId,
                            sourceId: contribution.sourceId,
                            sourceType: contribution.sourceType
                        )
                    )
                },
                onUpdateContributionFeedback: { contribution, feedback in
                    Task {
                        await store.updateContributionFeedback(feedback, for: contribution)
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: selectedMetric) { _, newValue in
            if let metric = newValue {
                Task {
                    await store.loadMetricContributions(for: metric)
                }
            }
        }
        .task {
            await store.loadGrowthReportReviewContributions()
        }
        .sheet(isPresented: $isPresentingAddPrinciple) {
            ManualPrincipleFormSheet()
        }
    }
}

private struct GrowthPrincipleAssetSection: View {
    @EnvironmentObject private var store: AppStore
    @Binding var isPresentingAddPrinciple: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("原则资产")
                Spacer()
                Button {
                    isPresentingAddPrinciple = true
                } label: {
                    Label("添加原则", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(DS.accent)
            }

            if store.activePrinciples.isEmpty {
                EmptyStateLine(text: "还没有原则资产。可以手工保存一条可复用的行为规则。")
            } else {
                ForEach(store.activePrinciples) { principle in
                    PrincipleArchiveRow(principle: principle)
                }
            }
        }
    }
}

private struct ManualPrincipleFormSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var summary = ""
    @State private var triggerContext = ""
    @State private var actionsText = ""
    @State private var successCriteria = ""
    @State private var exceptions = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("必填") {
                    TextField("标题", text: $title)
                    TextField("摘要", text: $summary, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("适用方式") {
                    TextField("触发场景", text: $triggerContext, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("行动步骤（每行一个）", text: $actionsText, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("成功标准", text: $successCriteria, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("例外情况", text: $exceptions, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(DS.caution)
                }
            }
            .navigationTitle("添加原则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "保存中" : "保存") {
                        Task {
                            await save()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        let actions = actionsText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let didSave = await store.addManualPrinciple(
            title: title,
            summary: summary,
            triggerContext: triggerContext,
            actions: actions,
            successCriteria: successCriteria,
            exceptions: exceptions
        )
        isSaving = false
        if didSave {
            dismiss()
        } else {
            errorMessage = store.todayLoopMessage
        }
    }
}

private struct GrowthReportActionPanel: View {
    let isGenerating: Bool
    let message: String
    let onWeekly: () -> Void
    let onMonthly: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("报告")
                Spacer()
                if isGenerating {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Text("用已确认的复盘、任务、验证和原则生成归因报告。证据不足时只记录积累状态，不给分。")
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(action: onWeekly) {
                    Label("周度校准", systemImage: "calendar.badge.clock")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.accent)
                .disabled(isGenerating)

                Button(action: onMonthly) {
                    Label("月度成长", systemImage: "chart.line.uptrend.xyaxis")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(DS.accent)
                .disabled(isGenerating)
            }
            .font(.footnote.weight(.semibold))

            if !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(message.contains("失败") ? DS.caution : DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .summarySurface()
    }
}

private struct GrowthReportReviewPanel: View {
    let snapshot: MetricSnapshot
    let contributions: [MetricContribution]
    let onSelectMetric: (GrowthMetric) -> Void

    private var acceptedContributions: [MetricContribution] {
        contributions.filter { contribution in
            contribution.isAcceptedForTrend &&
            !contribution.sourceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var positiveCount: Int {
        acceptedContributions.filter { $0.direction == .positive }.count
    }

    private var negativeCount: Int {
        acceptedContributions.filter { $0.direction == .negative }.count
    }

    private var groupedContributions: [(metric: GrowthMetric, contributions: [MetricContribution])] {
        GrowthMetric.allCases.compactMap { metric in
            let metricContributions = acceptedContributions.filter { $0.metric == metric }
            return metricContributions.isEmpty ? nil : (metric, metricContributions)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("最近报告审查")
                Spacer()
                Text(snapshot.period.uppercased())
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
            }

            if !snapshot.canDisplayScores {
                Text("证据还在积累中。完成至少 3 次闭环并保留验证结果后，这里会展示报告依据。")
                    .font(.subheadline)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                reportLedger

                if groupedContributions.isEmpty {
                    Text("这份报告还没有可审查的已接受贡献。重新生成报告或继续积累验证证据后再查看。")
                        .font(.subheadline)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: 8) {
                        ForEach(groupedContributions, id: \.metric) { group in
                            GrowthReportMetricEvidenceRow(
                                metric: group.metric,
                                contributions: group.contributions,
                                onTap: {
                                    onSelectMetric(group.metric)
                                }
                            )
                        }
                    }
                }

                if let focus = snapshot.nextTrainingFocus, !focus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("下一步")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.mutedInk)
                        Text(focus)
                            .font(.subheadline)
                            .foregroundStyle(DS.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .summarySurface()
    }

    private var reportLedger: some View {
        HStack(spacing: 10) {
            GrowthReportLedgerChip(title: "闭环", value: "\(snapshot.completeLoopCount)")
            GrowthReportLedgerChip(title: "正向", value: "\(positiveCount)")
            GrowthReportLedgerChip(title: "负向", value: "\(negativeCount)")
        }
    }
}

private struct GrowthReportLedgerChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DS.mutedInk)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(DS.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
    }
}

private struct GrowthReportMetricEvidenceRow: View {
    let metric: GrowthMetric
    let contributions: [MetricContribution]
    let onTap: () -> Void

    private var metricTitle: String {
        switch metric {
        case .clarity: return "清晰度"
        case .valueJudgment: return "价值判断"
        case .executionReliability: return "执行可靠性"
        case .calibration: return "校准"
        case .reflectionDepth: return "反思深度"
        }
    }

    private var positiveCount: Int {
        contributions.filter { $0.direction == .positive }.count
    }

    private var negativeCount: Int {
        contributions.filter { $0.direction == .negative }.count
    }

    private var leadingContribution: MetricContribution? {
        contributions.max { abs($0.delta) < abs($1.delta) }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 3, height: 42)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(metricTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.ink)
                        Text("+\(positiveCount) / -\(negativeCount)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(DS.mutedInk)
                    }

                    if let leadingContribution {
                        Text(leadingContribution.title)
                            .font(.caption)
                            .foregroundStyle(DS.mutedInk)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
                    .padding(.top, 3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
    }

    private var accentColor: Color {
        negativeCount > positiveCount ? DS.brick : DS.success
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var apiKeyInput = ""
    @State private var baseURLInput = ""
    @State private var modelNameInput = ""
    @State private var clipboardMessage = ""
    @State private var expandedPromptAuditGroups: Set<PromptRunAuditGroupKind> = PromptRunAuditSummary.defaultExpandedGroups
    @State private var promptTemplateExpanded = false
    @State private var selectedPromptID: PromptID = .organizeCards
    @State private var selectedSessionMode: SessionMode = .standard
    @State private var promptSystemTextExpanded = false
    @State private var promptUserTextExpanded = false

    var body: some View {
        FeatureContainer(title: "设置", subtitle: "隐私、模型、通知和数据控制。") {
            VStack(spacing: DS.cardSpacing) {
                apiKeyCard
                promptAuditCard
                promptTemplateCard
                SettingRow(title: "GLM API Key", value: store.apiKeyConfigured ? "已配置" : "未配置")
                SettingRow(title: "请求协议", value: "OpenAI-compatible / 自动 JSON 降级")
                SettingRow(title: "默认模式", value: store.todayDraft.sessionMode.title)
                SettingRow(title: "本地通知", value: store.reminderStatusMessage)
                SettingRow(title: "数据导出", value: "可用")
            }
        }
        .onAppear {
            baseURLInput = store.currentBaseURL
            modelNameInput = store.currentModelName
            Task {
                await store.loadRecentPromptRuns()
            }
        }
    }

    private var promptTemplateCard: some View {
        let template = store.promptTemplate(for: selectedPromptID, mode: selectedSessionMode)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prompt 模板")
                        .font(.headline)
                        .foregroundStyle(DS.ink)
                    Text("查看当前本地 Prompt 模板的系统文本和用户文本。只读，不发送请求。")
                        .font(.footnote)
                        .foregroundStyle(DS.mutedInk)
                }
                Spacer()
                Button {
                    withTransaction(Transaction(animation: nil)) {
                        promptTemplateExpanded.toggle()
                    }
                } label: {
                    Image(systemName: promptTemplateExpanded ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if promptTemplateExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Prompt", selection: $selectedPromptID) {
                        ForEach(PromptID.allCases) { id in
                            Text(id.displayName).tag(id)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("模式", selection: $selectedSessionMode) {
                        ForEach(SessionMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 4) {
                        LabeledContent("模板名称", value: template.id.displayName)
                        LabeledContent("ID", value: template.id.rawValue)
                        LabeledContent("版本", value: template.version)
                        LabeledContent("输出 Schema 版本", value: "\(template.outputSchemaVersion)")
                        LabeledContent("模式", value: selectedSessionMode.title)
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DS.ink)

                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            withTransaction(Transaction(animation: nil)) {
                                promptSystemTextExpanded.toggle()
                            }
                        } label: {
                            HStack {
                                Text("System Text")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(DS.ink)
                                Spacer()
                                Image(systemName: promptSystemTextExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(DS.mutedInk)
                            }
                        }
                        .buttonStyle(.plain)

                        if promptSystemTextExpanded {
                            Text(template.systemText)
                                .font(.caption)
                                .foregroundStyle(DS.ink)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            withTransaction(Transaction(animation: nil)) {
                                promptUserTextExpanded.toggle()
                            }
                        } label: {
                            HStack {
                                Text("User Text")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(DS.ink)
                                Spacer()
                                Image(systemName: promptUserTextExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(DS.mutedInk)
                            }
                        }
                        .buttonStyle(.plain)

                        if promptUserTextExpanded {
                            Text(template.userText)
                                .font(.caption)
                                .foregroundStyle(DS.ink)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .cardSurface()
    }

    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("API 配置")
                .font(.headline)
                .foregroundStyle(DS.ink)
            Text("API Key 只保存到 iOS Keychain，不写入数据库或代码配置。")
                .font(.footnote)
                .foregroundStyle(DS.mutedInk)

            // API Key
            VStack(alignment: .leading, spacing: 6) {
                Text("API Key")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                HStack(spacing: 8) {
                    SettingsTextField(
                        placeholder: "输入你的 GLM API Key",
                        text: $apiKeyInput,
                        isSecure: true
                    )
                    Button {
                        pasteAPIKey()
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                HStack(spacing: 8) {
                    Button("保存") {
                        store.saveGLMAPIKey(apiKeyInput)
                        apiKeyInput = ""
                        clipboardMessage = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.accent)
                    .controlSize(.small)

                    Button("清除") {
                        store.clearGLMAPIKey()
                        apiKeyInput = ""
                        clipboardMessage = ""
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("粘贴并保存") {
                        pasteAndSaveAPIKey()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .font(.footnote.weight(.semibold))
            }

            Divider()

            // Base URL
            VStack(alignment: .leading, spacing: 6) {
                Text("Base URL")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                Text("App 会自动拼接 /chat/completions。")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                HStack(spacing: 8) {
                    SettingsTextField(
                        placeholder: "https://open.bigmodel.cn/api/coding/paas/v4",
                        text: $baseURLInput
                    )
                    Button {
                        pasteEndpointConfiguration()
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            // Model Name
            VStack(alignment: .leading, spacing: 6) {
                Text("模型名")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                Text("不填则使用默认模型。")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                SettingsTextField(
                    placeholder: "例如 glm-4.5-flash",
                    text: $modelNameInput
                )
            }

            HStack(spacing: 8) {
                Button("保存配置") {
                    store.saveGLMEndpointConfiguration(baseURL: baseURLInput, modelName: modelNameInput)
                    clipboardMessage = ""
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.accent)
                .controlSize(.small)

                Button("恢复默认") {
                    baseURLInput = ""
                    modelNameInput = ""
                    store.clearGLMBaseURL()
                    store.saveGLMModelName("")
                    clipboardMessage = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .font(.footnote.weight(.semibold))

            if !clipboardMessage.isEmpty {
                Text(clipboardMessage)
                    .font(.footnote)
                    .foregroundStyle(clipboardMessage.contains("失败") || clipboardMessage.contains("为空") ? DS.caution : DS.mutedInk)
            }

            Divider()

            // Connection test — compact, doesn't dominate
            HStack(spacing: 10) {
                Button {
                    store.testGLMConnection()
                } label: {
                    HStack(spacing: 6) {
                        if store.isTestingGLMConnection {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                        }
                        Text(store.isTestingGLMConnection ? "测试中" : "测试连接")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(store.isTestingGLMConnection)

                if !store.settingsMessage.isEmpty {
                    Text(store.settingsMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
        }
        .cardSurface()
    }

    private var promptAuditCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI 调用审计")
                        .font(.headline)
                        .foregroundStyle(DS.ink)
                    Text("查看最近 Prompt 调用、失败原因和引用证据。")
                        .font(.footnote)
                        .foregroundStyle(DS.mutedInk)
                }
                Spacer()
                Button {
                    Task {
                        await store.loadRecentPromptRuns()
                    }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(.footnote.weight(.semibold))
            }

            if !store.promptRunAuditMessage.isEmpty {
                Text(store.promptRunAuditMessage)
                    .font(.footnote)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if store.recentPromptRuns.isEmpty {
                Text("完成一次 AI 整理、追问或任务生成后，这里会出现可审计记录。")
                    .font(.footnote)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                let summary = PromptRunAuditSummary(runs: store.recentPromptRuns)
                VStack(alignment: .leading, spacing: 10) {
                    Text("最近 \(summary.totalCount) 次 · 失败 \(summary.failed.count) · 成功 \(summary.successful.count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(DS.mutedInk)

                    ForEach(summary.visibleGroupKinds, id: \.self) { kind in
                        PromptRunAuditGroupSection(
                            group: summary.group(for: kind),
                            isExpanded: expandedPromptAuditGroups.contains(kind)
                        ) {
                            togglePromptAuditGroup(kind)
                        }
                    }
                }
            }
        }
        .cardSurface()
    }

    private func pasteClipboard(into binding: Binding<String>) {
        guard let pastedText = currentClipboardString() else {
            clipboardMessage = "剪贴板为空：请先复制文本，模拟器里可用菜单 Edit > Paste 同步到 iOS 剪贴板。"
            return
        }
        binding.wrappedValue = pastedText
        clipboardMessage = "已读取剪贴板，长度 \(pastedText.count) 个字符。"
    }

    private func pasteAPIKey() {
        pasteClipboard(into: $apiKeyInput)
    }

    private func pasteAndSaveAPIKey() {
        guard let pastedText = currentClipboardString() else {
            clipboardMessage = "粘贴失败：剪贴板为空或模拟器剪贴板尚未同步。"
            return
        }
        apiKeyInput = pastedText
        store.saveGLMAPIKey(pastedText)
        apiKeyInput = ""
        clipboardMessage = "已从剪贴板读取并保存 Key，长度 \(pastedText.count) 个字符。"
    }

    private func togglePromptAuditGroup(_ kind: PromptRunAuditGroupKind) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if expandedPromptAuditGroups.contains(kind) {
                expandedPromptAuditGroups.remove(kind)
            } else {
                expandedPromptAuditGroups.insert(kind)
            }
        }
    }

    private func pasteEndpointConfiguration() {
        guard let trimmed = currentClipboardString() else {
            clipboardMessage = "剪贴板为空：请先复制 Base URL 或模型名。"
            return
        }
        if trimmed.lowercased().hasPrefix("http") {
            baseURLInput = trimmed
            clipboardMessage = "已粘贴 Base URL。"
        } else {
            modelNameInput = trimmed
            clipboardMessage = "已粘贴模型名。"
        }
    }

    private func currentClipboardString() -> String? {
        let pasteboard = UIPasteboard.general
        let candidates = [
            pasteboard.string,
            pasteboard.strings?.first,
            pasteboard.items.compactMap { item in
                item["public.utf8-plain-text"] as? String ??
                    item["public.plain-text"] as? String ??
                    item["public.text"] as? String
            }.first
        ]

        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

private struct SettingsTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    private static let fieldBackgroundColor = UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 0.060, green: 0.058, blue: 0.052, alpha: 1.000)
        }
        return UIColor.secondarySystemBackground
    }

    private static let placeholderColor = UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 0.560, green: 0.548, blue: 0.500, alpha: 1.000)
        }
        return UIColor.placeholderText
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.isSecureTextEntry = isSecure
        textField.borderStyle = .roundedRect
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.keyboardType = .asciiCapable
        textField.returnKeyType = .done
        textField.clearButtonMode = .whileEditing
        textField.font = UIFont.preferredFont(forTextStyle: .subheadline)
        textField.adjustsFontForContentSizeCategory = true
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        applyStyle(to: textField)
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        applyStyle(to: textField)
        if textField.isSecureTextEntry != isSecure {
            textField.isSecureTextEntry = isSecure
        }
        if textField.text != text {
            textField.text = text
        }
    }

    private func applyStyle(to textField: UITextField) {
        textField.textColor = UIColor.label
        textField.tintColor = UIColor(DS.accent)
        textField.backgroundColor = Self.fieldBackgroundColor
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: Self.placeholderColor]
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            text = textField.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

// MARK: - Shared Components

struct FeatureContainer<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.sectionSpacing) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.ink)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(DS.mutedInk)
                    }
                    .padding(.horizontal, DS.pagePadding)

                    VStack(spacing: DS.cardSpacing) {
                        content
                    }
                    .padding(.horizontal, DS.pagePadding)
                }
                .padding(.top, DS.primaryScrollTopPadding)
                .padding(.bottom, DS.primaryScrollBottomReserve)
            }
            .scrollIndicators(.hidden)
            .background(DS.background.ignoresSafeArea())
        }
        .topSafeAreaScrim()
    }
}

struct ResumeTodayRow: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.uturn.left")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.loopResumeText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                Text("回到今日继续复盘")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
            }
            Spacer()
            Button("继续") {
                store.selectedTab = .today
            }
            .font(.footnote.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .tint(DS.accent)

            Button {
                store.isResumeBannerDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(DS.cardBackground, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
    }
}

struct ResumeBanner: View {
    let title: String
    let subtitle: String
    let actionTitle: String
    let onDismiss: () -> Void
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(actionTitle, action: onAction)
                .font(.footnote.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(DS.accent)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(DS.cardBackground, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

// MARK: - Card Components

private struct SectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(DS.mutedInk)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

private struct EmptyStateLine: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(DS.mutedInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .summarySurface()
    }
}

private enum HistoryCalendarScope: String, CaseIterable, Identifiable {
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "周"
        case .month: return "月"
        case .year: return "年"
        }
    }

    var titleForPeriod: String {
        switch self {
        case .week: return "按周浏览"
        case .month: return "按月浏览"
        case .year: return "按年浏览"
        }
    }
}

private enum HistoryEvidenceKind: String, CaseIterable, Identifiable {
    case cards
    case taskOrVerification
    case principleOrSummary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cards: return "卡片"
        case .taskOrVerification: return "任务/验证"
        case .principleOrSummary: return "原则/总结"
        }
    }

    var color: Color {
        switch self {
        case .cards: return DS.accent
        case .taskOrVerification: return DS.caution
        case .principleOrSummary: return DS.success
        }
    }
}

private struct HistoryCalendarSheet: View {
    let records: [HistoryRecord]
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    @State private var scope: HistoryCalendarScope = .month
    @State private var anchorDate = Date()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("浏览范围", selection: $scope) {
                        ForEach(HistoryCalendarScope.allCases) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Button {
                            movePeriod(-1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.headline)
                                .frame(width: 38, height: 38)
                        }
                        .buttonStyle(.bordered)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(scope.titleForPeriod)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(DS.mutedInk)
                            Text(periodTitle)
                                .font(.system(size: 24, weight: .semibold, design: .serif))
                                .foregroundStyle(DS.ink)
                        }

                        Spacer()

                        Button {
                            movePeriod(1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.headline)
                                .frame(width: 38, height: 38)
                        }
                        .buttonStyle(.bordered)
                    }

                    calendarBody
                }
                .padding(.horizontal, DS.pagePadding)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(DS.background.ignoresSafeArea())
            .navigationTitle("历史日历")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear {
                anchorDate = selectedDate
            }
        }
    }

    @ViewBuilder
    private var calendarBody: some View {
        switch scope {
        case .week:
            VStack(spacing: 10) {
                ForEach(weekDates, id: \.self) { date in
                    let record = record(on: date)
                    CalendarDateRow(
                        date: date,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                        hasRecord: record != nil,
                        evidenceKinds: record.map(evidenceKinds(for:)) ?? [],
                        summary: summary(for: date)
                    ) {
                        selectedDate = date
                        dismiss()
                    }
                }
            }
        case .month:
            VStack(spacing: 10) {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Calendar.current.veryShortWeekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.mutedInk)
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(monthGridDates, id: \.self) { date in
                        let record = record(on: date)
                        CalendarDayCell(
                            date: date,
                            anchorDate: anchorDate,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            evidenceKinds: record.map(evidenceKinds(for:)) ?? []
                        ) {
                            selectedDate = date
                            dismiss()
                        }
                    }
                }
            }
        case .year:
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(1...12, id: \.self) { month in
                    CalendarMonthCell(
                        title: "\(month)月",
                        count: recordCount(inMonth: month),
                        isSelected: Calendar.current.component(.month, from: selectedDate) == month &&
                            Calendar.current.component(.year, from: selectedDate) == Calendar.current.component(.year, from: anchorDate)
                    ) {
                        anchorDate = dateForMonth(month)
                        scope = .month
                    }
                }
            }
        }
    }

    private var periodTitle: String {
        switch scope {
        case .week:
            return "\(weekDates.first?.mingsiShortDate ?? "") - \(weekDates.last?.mingsiShortDate ?? "")"
        case .month:
            return anchorDate.mingsiMonthTitle
        case .year:
            return "\(Calendar.current.component(.year, from: anchorDate))"
        }
    }

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .weekOfYear, for: anchorDate)
        let start = interval?.start ?? anchorDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var monthGridDates: [Date] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: anchorDate) else { return [] }
        let start = monthInterval.start
        let weekdayOffset = calendar.component(.weekday, from: start) - calendar.firstWeekday
        let leadingDays = (weekdayOffset + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: start) else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    private func movePeriod(_ delta: Int) {
        let component: Calendar.Component
        switch scope {
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        anchorDate = Calendar.current.date(byAdding: component, value: delta, to: anchorDate) ?? anchorDate
    }

    private func record(on date: Date) -> HistoryRecord? {
        records.first { Calendar.current.isDate($0.draft.date, inSameDayAs: date) }
    }

    private func evidenceKinds(for record: HistoryRecord) -> [HistoryEvidenceKind] {
        var kinds: [HistoryEvidenceKind] = []
        if record.hasCardEvidence {
            kinds.append(.cards)
        }
        if record.hasTaskEvidence || record.hasVerificationEvidence {
            kinds.append(.taskOrVerification)
        }
        if record.hasPrincipleEvidence || record.hasSummaryEvidence {
            kinds.append(.principleOrSummary)
        }
        return kinds
    }

    private func summary(for date: Date) -> String {
        guard let record = record(on: date) else {
            return "无记录"
        }
        if let quest = record.mainQuest {
            return quest.title
        }
        return record.cardCountSummary
    }

    private func recordCount(inMonth month: Int) -> Int {
        let year = Calendar.current.component(.year, from: anchorDate)
        return records.filter { record in
            Calendar.current.component(.year, from: record.draft.date) == year &&
                Calendar.current.component(.month, from: record.draft.date) == month
        }.count
    }

    private func dateForMonth(_ month: Int) -> Date {
        let year = Calendar.current.component(.year, from: anchorDate)
        return Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? anchorDate
    }
}

private struct CalendarDateRow: View {
    let date: Date
    let isSelected: Bool
    let hasRecord: Bool
    let evidenceKinds: [HistoryEvidenceKind]
    let summary: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text(date.mingsiDayNumber)
                        .font(.headline.monospacedDigit())
                    Text(date.mingsiWeekday)
                        .font(.caption)
                }
                .foregroundStyle(isSelected ? .white : DS.ink)
                .frame(width: 48, height: 48)
                .background(isSelected ? DS.accent : DS.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(hasRecord ? "有复盘记录" : "没有记录")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.ink)
                        if !evidenceKinds.isEmpty {
                            HistoryEvidenceDots(kinds: evidenceKinds)
                        }
                    }
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .lineLimit(1)
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .summarySurface()
    }
}

private struct CalendarDayCell: View {
    let date: Date
    let anchorDate: Date
    let isSelected: Bool
    let evidenceKinds: [HistoryEvidenceKind]
    let action: () -> Void

    private var isCurrentMonth: Bool {
        Calendar.current.component(.month, from: date) == Calendar.current.component(.month, from: anchorDate)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(date.mingsiDayNumber)
                    .font(.subheadline.monospacedDigit().weight(isSelected ? .bold : .regular))
                HistoryEvidenceDots(kinds: evidenceKinds)
                    .frame(height: 5)
            }
            .foregroundStyle(isSelected ? .white : (isCurrentMonth ? DS.ink : DS.mutedInk.opacity(0.45)))
            .frame(height: 46)
            .frame(maxWidth: .infinity)
            .background(isSelected ? DS.accent : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct HistoryEvidenceDots: View {
    let kinds: [HistoryEvidenceKind]

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(kinds.prefix(3)) { kind in
                Circle()
                    .fill(kind.color)
                    .frame(width: 5, height: 5)
                    .accessibilityLabel(kind.title)
            }
            if kinds.isEmpty {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 5, height: 5)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(kinds.isEmpty ? "无证据标识" : kinds.map(\.title).joined(separator: "，"))
    }
}

private struct CalendarMonthCell: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : DS.ink)
                Text("\(count) 条记录")
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.75) : DS.mutedInk)
            }
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
            .padding(12)
            .background(isSelected ? DS.accent : DS.surface, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                    .stroke(isSelected ? Color.clear : DS.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct HistoryDayHeader: View {
    let date: Date
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(dayText)
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(DS.ink)
                Spacer()
                Text(monthText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(DS.ink)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(DS.mutedInk)
            }
        }
        .padding(18)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DS.accent.opacity(0.22))
                .frame(height: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
    }

    private var dayText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: date)
    }

    private var monthText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM"
        return formatter.string(from: date)
    }
}

private struct HistoryTimelineRow: View {
    let index: Int
    let card: ThinkingCard
    var isHighlighted: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 6) {
                Text("\(index)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(card.type.color, in: Circle())
                Rectangle()
                    .fill(DS.hairline)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(card.type.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(card.type.color)
                    Text(card.priority == .high ? "高优先级" : "记录")
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                }
                Text(card.title)
                    .font(.headline)
                    .foregroundStyle(DS.ink)
                Text(card.body)
                    .font(.subheadline)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
        }
        .evidenceSurface(isHighlighted: isHighlighted, base: .plain)
    }
}

private struct PrincipleArchiveRow: View {
    let principle: PrincipleAsset
    var isHighlighted: Bool = false
    var onSaveProject: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("原则")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DS.caution)
                Spacer()
                Text(principle.status.rawValue)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
            }
            Text(principle.title)
                .font(.headline)
                .foregroundStyle(DS.ink)
            Text(principle.summary)
                .font(.subheadline)
                .foregroundStyle(DS.mutedInk)
            Divider()
            Text(principle.triggerContext)
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .lineLimit(2)
            if let onSaveProject {
                Button(action: onSaveProject) {
                    Label("保存为长期议题", systemImage: "plus.circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.accent)
            }
        }
        .evidenceSurface(isHighlighted: isHighlighted, base: .principle)
    }
}

private struct ProjectEvidenceBoardItem: Identifiable {
    let id: UUID
    let name: String
    let entries: [(link: ProjectLink, record: HistoryRecord)]

    var sortedEntries: [(link: ProjectLink, record: HistoryRecord)] {
        entries.sorted { lhs, rhs in
            if lhs.record.draft.date == rhs.record.draft.date {
                return lhs.link.updatedAt > rhs.link.updatedAt
            }
            return lhs.record.draft.date > rhs.record.draft.date
        }
    }

    var confirmedCount: Int {
        entries.filter(\.link.isUserConfirmed).count
    }

    var evidenceCount: Int {
        entries.count
    }

    var latestDate: Date {
        sortedEntries.first?.record.draft.date ?? .distantPast
    }

    var latestRecord: HistoryRecord? {
        sortedEntries.first?.record
    }

    var digest: ProjectEvidenceDigest {
        ProjectEvidenceDigest(projectId: id, evidence: entries)
    }

    var dominantType: ProjectLinkType {
        let counts = Dictionary(grouping: entries.map(\.link.linkType), by: { $0 })
            .mapValues(\.count)
        return counts.max { lhs, rhs in
            lhs.value == rhs.value ? lhs.key.title < rhs.key.title : lhs.value < rhs.value
        }?.key ?? .evidence
    }

    var statusLabel: String {
        if confirmedCount > 0 {
            return "\(confirmedCount) 条已确认"
        }
        return "待确认"
    }

    var typeSummary: String {
        let types = Array(Set(entries.map(\.link.linkType)))
            .sorted { $0.title < $1.title }
            .prefix(3)
            .map(\.title)
        return types.isEmpty ? "证据" : types.joined(separator: " / ")
    }

    func record(containing link: ProjectLink) -> HistoryRecord? {
        entries.first { $0.link.id == link.id }?.record
    }
}

private struct ProjectCurrentFocus: View {
    let title: String
    let detail: String
    var canCreateProject: Bool = false
    var createProject: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "scope")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DS.accent)
                .frame(width: 30, height: 30)
                .background(DS.accent.opacity(0.08), in: Circle())
            VStack(alignment: .leading, spacing: 7) {
                Text("今日主线")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(DS.ink)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)

                if canCreateProject {
                    Button(action: createProject) {
                        Label("保存为长期议题", systemImage: "plus.circle")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(DS.accent)
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(DS.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(DS.accent.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct ProjectEmptyEvidenceState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(DS.accent)
                .frame(width: 42, height: 42)
                .background(DS.accent.opacity(0.08), in: Circle())
            Text("尚无长期议题证据")
                .font(.headline)
                .foregroundStyle(DS.ink)
            Text("完成几次复盘后，可以从历史证据创建或确认项目。项目只记录被卡片、任务、验证或原则支撑的长期议题，不展示示例数据。")
                .font(.subheadline)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
    }
}

private struct ProjectEvidenceBoardRow: View {
    let item: ProjectEvidenceBoardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(item.dominantType.tint)
                    .frame(width: 4, height: 54)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.name)
                            .font(.system(size: 19, weight: .semibold, design: .serif))
                            .foregroundStyle(DS.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Text(item.statusLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(item.confirmedCount > 0 ? DS.accent : DS.caution)
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        ProjectTinyChip(text: "\(item.evidenceCount) 条证据", systemImage: "number")
                        ProjectTinyChip(text: item.latestDate.mingsiShortDate, systemImage: "calendar")
                        ProjectTinyChip(text: item.typeSummary, systemImage: item.dominantType.systemImage)
                    }

                    if let nextBet = item.digest.nextBet {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Next Bet")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(DS.accent)
                            Text(nextBet)
                                .font(.caption)
                                .foregroundStyle(DS.mutedInk)
                                .lineLimit(2)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(item.sortedEntries.prefix(3)), id: \.link.id) { entry in
                    ProjectEvidenceLine(link: entry.link, record: entry.record)
                }
            }

            if item.evidenceCount > 3 {
                Text("还有 \(item.evidenceCount - 3) 条证据，可在历史中继续追溯。")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
            }
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
    }
}

private struct ProjectDetailView: View {
    @EnvironmentObject private var store: AppStore
    let item: ProjectEvidenceBoardItem
    let project: Project?
    @State private var isEditorPresented = false

    private var digest: ProjectEvidenceDigest {
        item.digest
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                detailHeader
                overviewSection
                projectInsightSection
                progressSignalsSection
                thinkingChangeSection
                evidenceTimeline
            }
            .padding(.horizontal, DS.pagePadding)
            .padding(.top, 18)
            .padding(.bottom, 96)
        }
        .background(DS.background.ignoresSafeArea())
        .navigationTitle("长期议题")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if project != nil {
                    Button {
                        isEditorPresented = true
                    } label: {
                        Label("编辑", systemImage: "slider.horizontal.3")
                    }
                }
            }
        }
        .sheet(isPresented: $isEditorPresented) {
            if let project {
                ProjectEditorSheet(project: project)
                    .environmentObject(store)
            }
        }
        .task(id: item.id) {
            await store.loadProjectInsights(for: item.id)
        }
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(item.dominantType.tint)
                    .frame(width: 4, height: 62)
                VStack(alignment: .leading, spacing: 8) {
                    Text(project?.name ?? item.name)
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundStyle(DS.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        ProjectTinyChip(text: project?.status.title ?? "active", systemImage: "circle.dashed")
                        ProjectTinyChip(text: "\(item.evidenceCount) 条证据", systemImage: "number")
                        ProjectTinyChip(text: item.latestDate.mingsiShortDate, systemImage: "calendar")
                    }
                }
            }
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Overview")
            ProjectDetailFactLine(title: "目标", value: project?.goal ?? "这个长期议题来自历史证据，但缺少完整目标描述。")
            ProjectDetailFactLine(title: "成功标准", value: project?.successCriteria ?? "后续需要用任务和验证补齐成功标准。")
            ProjectDetailFactLine(title: "当前阻塞", value: project?.currentBottleneck ?? "证据不足")
            ProjectDetailFactLine(title: "下一步押注", value: digest.nextBet ?? "证据不足")
            if let openQuestions = project?.openQuestions, !openQuestions.isEmpty {
                ProjectDetailFactLine(title: "开放问题", value: openQuestions.joined(separator: "\n"))
            } else {
                ProjectDetailFactLine(title: "开放问题", value: "证据不足")
            }
            if !digest.evidenceGapMessage.isEmpty {
                ProjectDetailFactLine(title: "证据缺口", value: digest.evidenceGapMessage)
            }
        }
        .summarySurface()
    }

    private var projectInsightSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel("项目洞察")
                    Text("只从已确认历史证据生成，确认后才进入项目叙事。")
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button {
                    Task { await store.generateProjectInsights(for: item.id) }
                } label: {
                    Label(store.isGeneratingProjectInsights ? "生成中" : "生成", systemImage: "sparkle.magnifyingglass")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(DS.accent)
                .disabled(store.isGeneratingProjectInsights)
            }

            if store.isGeneratingProjectInsights {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(DS.accent)
                    Text("正在根据历史证据生成洞察")
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                }
            } else if !store.projectInsightGenerationMessage.isEmpty {
                ProjectInsightNote(message: store.projectInsightGenerationMessage)
            }

            let accepted = store.acceptedProjectInsights.filter { $0.projectId == item.id }
            let pending = store.pendingProjectInsights.filter { $0.projectId == item.id }

            if !accepted.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("已确认叙事")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DS.ink)
                    ForEach(accepted) { insight in
                        ProjectAcceptedInsightCard(insight: insight)
                    }
                }
            }

            if !pending.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("待你判断")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DS.ink)
                    ForEach(pending) { insight in
                        ProjectPendingInsightCard(
                            insight: insight,
                            onAccept: {
                                Task { await store.submitProjectInsightFeedback(.accepted, for: insight.id) }
                            },
                            onInaccurate: {
                                Task { await store.submitProjectInsightFeedback(.inaccurate, for: insight.id) }
                            },
                            onDismiss: {
                                Task { await store.submitProjectInsightFeedback(.dismissed, for: insight.id) }
                            }
                        )
                    }
                }
            }

            if accepted.isEmpty && pending.isEmpty && store.projectInsightGenerationMessage.isEmpty && !store.isGeneratingProjectInsights {
                ProjectInsightNote(message: "还没有经过确认的项目洞察。先积累并确认几条项目证据，再让 AI 提出候选。")
            }
        }
        .summarySurface()
    }

    private var progressSignalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("进展信号")
            if digest.progressSignals.isEmpty {
                Text("还没有可解释的项目证据。")
                    .font(.subheadline)
                    .foregroundStyle(DS.mutedInk)
            } else {
                ForEach(digest.progressSignals.prefix(5)) { signal in
                    Button {
                        store.navigateToHistoryDeepLink(
                            HistoryDeepLink(
                                dailyEntryId: signal.dailyEntryId,
                                sourceId: signal.sourceId,
                                sourceType: nil
                            )
                        )
                    } label: {
                        ProjectProgressSignalRow(signal: signal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .summarySurface()
    }

    private var thinkingChangeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("思考变化")
            Text("证据不足")
                .font(.headline)
                .foregroundStyle(DS.ink)
            Text(digest.hasBeforeAfterEvidence
                 ? "已有多条证据，但还没有经过确认的 before / after 项目洞察；MVP 阶段暂不自动编造变化叙事。"
                 : "当前 MVP 只展示已确认来源证据。没有 before / after 证据时，不生成项目洞察，也不编造思考变化。")
                .font(.subheadline)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .summarySurface()
    }

    private var evidenceTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Evidence Timeline")
            ForEach(item.sortedEntries, id: \.link.id) { entry in
                Button {
                    store.navigateToHistoryDeepLink(
                        HistoryDeepLink(
                            dailyEntryId: entry.record.draft.id,
                            sourceId: entry.link.sourceId,
                            sourceType: nil
                        )
                    )
                } label: {
                    ProjectEvidenceLine(link: entry.link, record: entry.record)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ProjectProgressSignalRow: View {
    let signal: ProjectEvidenceSignal

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: signal.kind.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(signal.kind.tint)
                .frame(width: 26, height: 26)
                .background(signal.kind.tint.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(signal.kind.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(signal.kind.tint)
                    Text(signal.date.mingsiShortDate)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(DS.mutedInk)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(DS.mutedInk.opacity(0.7))
                }

                Text(signal.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(signal.detail)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(DS.background.opacity(0.48), in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
    }
}

private struct ProjectEditorSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let project: Project

    @State private var name: String
    @State private var goal: String
    @State private var successCriteria: String
    @State private var currentBottleneck: String
    @State private var openQuestionsText: String

    init(project: Project) {
        self.project = project
        _name = State(initialValue: project.name)
        _goal = State(initialValue: project.goal)
        _successCriteria = State(initialValue: project.successCriteria)
        _currentBottleneck = State(initialValue: project.currentBottleneck ?? "")
        _openQuestionsText = State(initialValue: project.openQuestions.joined(separator: "\n"))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基础信息") {
                    TextField("名称", text: $name)
                    TextField("目标", text: $goal, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("成功标准", text: $successCriteria, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("当前阻塞", text: $currentBottleneck, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section {
                    TextField("每行一个问题", text: $openQuestionsText, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("开放问题")
                } footer: {
                    Text("编辑只更新项目元信息，不会删除历史证据或项目链接。")
                }

                Section("状态") {
                    HStack {
                        Text("当前状态")
                        Spacer()
                        Text(project.status.title)
                            .foregroundStyle(DS.mutedInk)
                    }
                    if project.status == .archived {
                        Button {
                            Task {
                                await store.restoreProject(project.id)
                                dismiss()
                            }
                        } label: {
                            Label("恢复为 active", systemImage: "arrow.uturn.backward.circle")
                        }
                    } else {
                        Button(role: .destructive) {
                            Task {
                                await store.archiveProject(project.id)
                                dismiss()
                            }
                        } label: {
                            Label("归档项目", systemImage: "archivebox")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DS.background.ignoresSafeArea())
            .navigationTitle("编辑长期议题")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await store.updateProjectDetails(
                                projectId: project.id,
                                name: name,
                                goal: goal,
                                successCriteria: successCriteria,
                                currentBottleneck: currentBottleneck,
                                openQuestions: openQuestionsText
                                    .split(separator: "\n")
                                    .map(String.init)
                            )
                            if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct ProjectDetailFactLine: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.mutedInk)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(DS.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ProjectInsightNote: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.mutedInk)
                .padding(.top, 1)
            Text(message)
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.background.opacity(0.58), in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
    }
}

private struct ProjectPendingInsightCard: View {
    let insight: ProjectInsight
    let onAccept: () -> Void
    let onInaccurate: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProjectInsightHeader(insight: insight, isAccepted: false)
            Text(insight.summary)
                .font(.subheadline)
                .foregroundStyle(DS.ink)
                .fixedSize(horizontal: false, vertical: true)
            if insight.insightType.showsBeforeAfterEvidence {
                ProjectInsightBeforeAfter(insight: insight)
            }
            HStack(spacing: 8) {
                ProjectInsightActionButton(title: "确认", systemImage: "checkmark", tint: DS.accent, action: onAccept)
                ProjectInsightActionButton(title: "不准确", systemImage: "xmark", tint: DS.brick, action: onInaccurate)
                Button(action: onDismiss) {
                    Image(systemName: "minus.circle")
                        .font(.caption.weight(.semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.mutedInk)
                .accessibilityLabel("忽略")
            }
        }
        .padding(12)
        .background(DS.background.opacity(0.48), in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                .stroke(insight.insightType.tint.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct ProjectAcceptedInsightCard: View {
    let insight: ProjectInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProjectInsightHeader(insight: insight, isAccepted: true)
            Text(insight.title)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(DS.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(insight.summary)
                .font(.subheadline)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            if insight.insightType.showsBeforeAfterEvidence {
                ProjectInsightBeforeAfter(insight: insight)
            }
        }
        .padding(12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(insight.insightType.tint)
                .frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
    }
}

private struct ProjectInsightHeader: View {
    let insight: ProjectInsight
    let isAccepted: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: insight.insightType.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(insight.insightType.tint)
                .frame(width: 24, height: 24)
                .background(insight.insightType.tint.opacity(0.10), in: Circle())
            Text(insight.insightType.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(insight.insightType.tint)
            Text("\(insight.sourceRefs.count) 条来源")
                .font(.caption.monospacedDigit())
                .foregroundStyle(DS.mutedInk)
            Spacer(minLength: 0)
            if isAccepted {
                Image(systemName: "checkmark.seal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.accent)
            }
        }
    }
}

private struct ProjectInsightBeforeAfter: View {
    let insight: ProjectInsight

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ProjectInsightChangeColumn(label: "Before", text: insight.beforeText ?? "证据不足")
            ProjectInsightChangeColumn(label: "After", text: insight.afterText ?? "证据不足")
        }
    }
}

private struct ProjectInsightChangeColumn: View {
    let label: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(DS.mutedInk)
            Text(text)
                .font(.caption)
                .foregroundStyle(DS.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Color(.systemBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct ProjectInsightActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .frame(height: 30)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
        .background(tint.opacity(0.08), in: Capsule())
    }
}

private struct ProjectTinyChip: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(DS.mutedInk)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(DS.background.opacity(0.85), in: Capsule())
    }
}

private struct ProjectEvidenceLine: View {
    let link: ProjectLink
    let record: HistoryRecord

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: link.linkType.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(link.linkType.tint)
                .frame(width: 24, height: 24)
                .background(link.linkType.tint.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(link.linkType.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(link.linkType.tint)
                    Text(link.sourceType.title)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                    Text(record.draft.date.mingsiShortDate)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(DS.mutedInk)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(DS.mutedInk.opacity(0.7))
                }
                Text(evidenceTitle)
                    .font(.subheadline)
                    .foregroundStyle(DS.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(DS.background.opacity(0.55), in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
    }

    private var evidenceTitle: String {
        switch link.sourceType {
        case .dailyEntry:
            return record.draft.rawText.isEmpty ? "当日复盘记录" : record.draft.rawText
        case .thinkingCard:
            return record.cards.first { $0.id.uuidString == link.sourceId }?.title ?? "思考卡片"
        case .quest:
            return record.quests.first { $0.id.uuidString == link.sourceId }?.title ?? "明日任务"
        case .verification:
            return record.verification?.calibrationNote ?? "次日验证"
        case .principle:
            return record.principles.first { $0.id.uuidString == link.sourceId }?.title ?? "原则资产"
        }
    }
}

private extension ProjectInsightType {
    var title: String {
        switch self {
        case .progress: return "进展"
        case .blockerChange: return "阻塞变化"
        case .thinkingChange: return "思考变化"
        case .openQuestionClosed: return "问题关闭"
        case .principlePracticed: return "原则实践"
        case .nextBet: return "下一步押注"
        }
    }

    var systemImage: String {
        switch self {
        case .progress: return "chart.line.uptrend.xyaxis"
        case .blockerChange: return "exclamationmark.arrow.triangle.2.circlepath"
        case .thinkingChange: return "arrow.left.arrow.right"
        case .openQuestionClosed: return "questionmark.circle"
        case .principlePracticed: return "seal"
        case .nextBet: return "scope"
        }
    }

    var tint: Color {
        switch self {
        case .progress: return DS.success
        case .blockerChange: return DS.caution
        case .thinkingChange: return DS.accent
        case .openQuestionClosed: return DS.graphite
        case .principlePracticed: return DS.note
        case .nextBet: return DS.brick
        }
    }

    var showsBeforeAfterEvidence: Bool {
        switch self {
        case .thinkingChange, .blockerChange:
            return true
        case .progress, .openQuestionClosed, .principlePracticed, .nextBet:
            return false
        }
    }
}

private extension ProjectLinkType {
    var tint: Color {
        switch self {
        case .evidence: return DS.graphite
        case .blocker: return DS.caution
        case .decision: return DS.accent
        case .task: return DS.success
        case .principle: return DS.note
        case .risk: return DS.brick
        }
    }

    var systemImage: String {
        switch self {
        case .evidence: return "doc.text.magnifyingglass"
        case .blocker: return "exclamationmark.octagon"
        case .decision: return "arrow.triangle.branch"
        case .task: return "checklist"
        case .principle: return "bookmark"
        case .risk: return "shield.lefthalf.filled"
        }
    }
}

private extension ProjectEvidenceSignalKind {
    var tint: Color {
        switch self {
        case .done: return DS.success
        case .learned: return DS.accent
        case .unblocked: return DS.success
        case .newlyBlocked: return DS.caution
        case .newRisk: return DS.brick
        case .nextBet: return DS.graphite
        }
    }

    var systemImage: String {
        switch self {
        case .done: return "checkmark.circle"
        case .learned: return "lightbulb"
        case .unblocked: return "lock.open"
        case .newlyBlocked: return "exclamationmark.octagon"
        case .newRisk: return "shield.lefthalf.filled"
        case .nextBet: return "scope"
        }
    }
}

private extension QuestType {
    var tint: Color {
        switch self {
        case .main: return DS.accent
        case .side: return DS.success
        case .observation: return DS.graphite
        }
    }

    var systemImage: String {
        switch self {
        case .main: return "flag"
        case .side: return "checklist"
        case .observation: return "eye"
        }
    }
}

private extension QuestStatus {
    var historyTitle: String {
        switch self {
        case .draft: return "草稿"
        case .active: return "进行中"
        case .completed: return "已完成"
        case .partial: return "部分完成"
        case .failed: return "未完成"
        case .archived: return "已归档"
        }
    }
}

private extension ProjectStatus {
    var title: String {
        switch self {
        case .active: return "active"
        case .watching: return "watching"
        case .paused: return "paused"
        case .archived: return "archived"
        }
    }
}

private extension ProjectSourceType {
    var title: String {
        switch self {
        case .dailyEntry: return "日记"
        case .thinkingCard: return "卡片"
        case .quest: return "任务"
        case .verification: return "验证"
        case .principle: return "原则"
        }
    }
}

private struct GrowthSummaryPanel: View {
    let snapshot: MetricSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(snapshot.period.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(DS.mutedInk)
            Text(snapshot.summary)
                .font(.system(size: 23, weight: .semibold, design: .serif))
                .foregroundStyle(DS.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
    }
}

private struct TappableMetricRow: View {
    let title: String
    let value: Double
    let note: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.ink)
                        Spacer()
                        Text(String(format: "%.1f", value))
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(DS.accentInk)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.mutedInk)
                    }
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black.opacity(0.06))
                        Capsule()
                            .fill(DS.accent)
                            .frame(width: max(8, proxy.size.width * min(max(value / 5.0, 0), 1)))
                    }
                }
                .frame(height: 6)
            }
        }
        .buttonStyle(.plain)
        .summarySurface()
    }
}

// MARK: - Metric Detail Sheet

struct MetricDetailSheet: View {
    let snapshot: MetricSnapshot
    let metric: GrowthMetric
    let contributions: [MetricContribution]
    let onSelectContribution: (MetricContribution) -> Void
    let onUpdateContributionFeedback: (MetricContribution, MetricContributionFeedback) -> Void

    @Environment(\.dismiss) private var dismiss

    private var metricTitle: String {
        switch metric {
        case .clarity: return "清晰度"
        case .valueJudgment: return "价值判断"
        case .executionReliability: return "执行可靠性"
        case .calibration: return "校准"
        case .reflectionDepth: return "反思深度"
        }
    }

    private var metricNote: String {
        switch metric {
        case .clarity: return "问题是否被说清楚"
        case .valueJudgment: return "是否选择高杠杆动作"
        case .executionReliability: return "任务是否可验证"
        case .calibration: return "预判和结果是否对齐"
        case .reflectionDepth: return "是否发现更底层模式"
        }
    }

    private var currentValue: Double {
        switch metric {
        case .clarity: return snapshot.clarity
        case .valueJudgment: return snapshot.valueJudgment
        case .executionReliability: return snapshot.executionReliability
        case .calibration: return snapshot.calibration
        case .reflectionDepth: return snapshot.reflectionDepth
        }
    }

    private var previousValue: Double? {
        switch metric {
        case .clarity: return snapshot.previousClarity
        case .valueJudgment: return snapshot.previousValueJudgment
        case .executionReliability: return snapshot.previousExecutionReliability
        case .calibration: return snapshot.previousCalibration
        case .reflectionDepth: return snapshot.previousReflectionDepth
        }
    }

    private var deltaValue: Double? {
        switch metric {
        case .clarity: return snapshot.clarityDelta
        case .valueJudgment: return snapshot.valueJudgmentDelta
        case .executionReliability: return snapshot.executionReliabilityDelta
        case .calibration: return snapshot.calibrationDelta
        case .reflectionDepth: return snapshot.reflectionDepthDelta
        }
    }

    private var reason: String? {
        snapshot.metricReasons[metric.rawValue]
    }

    private var positiveContributions: [MetricContribution] {
        contributions.filter { $0.direction == .positive }
    }

    private var negativeContributions: [MetricContribution] {
        contributions.filter { $0.direction == .negative }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    metricHeaderSection
                    changeSection
                    reasonSection

                    if contributions.isEmpty {
                        insufficientEvidenceSection
                    } else {
                        if !positiveContributions.isEmpty {
                            contributionSection(
                                title: "正向信号",
                                contributions: positiveContributions,
                                accentColor: DS.success
                            )
                        }
                        if !negativeContributions.isEmpty {
                            contributionSection(
                                title: "负向信号",
                                contributions: negativeContributions,
                                accentColor: DS.brick
                            )
                        }
                    }

                    trainingFocusSection
                }
                .padding(.horizontal, DS.pagePadding)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .pageBackground()
            .navigationTitle(metricTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var metricHeaderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(metricNote)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.mutedInk)
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(String(format: "%.1f", currentValue))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.ink)

                if let previous = previousValue {
                    Text("上期 \(String(format: "%.1f", previous))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(DS.mutedInk)
                }
            }
        }
        .padding(DS.cardInnerPadding)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
    }

    private var changeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("变化")
            HStack(spacing: 12) {
                if let delta = deltaValue {
                    HStack(spacing: 4) {
                        Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption.weight(.semibold))
                        Text(String(format: "%+.1f", delta))
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                    }
                    .foregroundStyle(delta >= 0 ? DS.success : DS.brick)
                } else {
                    Text("首次评估")
                        .font(.subheadline)
                        .foregroundStyle(DS.mutedInk)
                }
                Spacer()
                if let previous = previousValue {
                    Text("\(String(format: "%.1f", previous)) → \(String(format: "%.1f", currentValue))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(DS.mutedInk)
                }
            }
        }
        .summarySurface()
    }

    @ViewBuilder
    private var reasonSection: some View {
        if let reason, !reason.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("判断依据")
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(DS.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .summarySurface()
        }
    }

    private var insufficientEvidenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("证据不足")
                .font(.headline)
                .foregroundStyle(DS.ink)
            Text("这个指标还没有足够的已接受证据来展示变化来源。继续完成复盘，系统会逐步积累可引用的证据。")
                .font(.subheadline)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .summarySurface()
    }

    private func contributionSection(title: String, contributions: [MetricContribution], accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title)
            ForEach(contributions) { contribution in
                ContributionRow(
                    contribution: contribution,
                    accentColor: accentColor,
                    onSelect: {
                        onSelectContribution(contribution)
                        dismiss()
                    },
                    onUpdateFeedback: { feedback in
                        onUpdateContributionFeedback(contribution, feedback)
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var trainingFocusSection: some View {
        if let focus = snapshot.nextTrainingFocus, !focus.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("下一步训练重点")
                Text(focus)
                    .font(.subheadline)
                    .foregroundStyle(DS.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DS.cardInnerPadding)
            .background(DS.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                    .stroke(DS.accent.opacity(0.15), lineWidth: 1)
            )
        }
    }
}

private struct ContributionRow: View {
    let contribution: MetricContribution
    let accentColor: Color
    let onSelect: () -> Void
    let onUpdateFeedback: (MetricContributionFeedback) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(rowAccentColor)
                    .frame(width: 3, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(contribution.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.ink)
                        if isMarkedInaccurate {
                            Text("不准确")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(DS.brick)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DS.brick.opacity(0.08), in: Capsule())
                        }
                    }
                    Text(contribution.reason)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.mutedInk.opacity(0.7))
            }

            HStack(spacing: 12) {
                Label(sourceTypeLabel, systemImage: sourceTypeIcon)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                Label(String(contribution.sourceDailyEntryId.uuidString.prefix(8)), systemImage: "calendar")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DS.mutedInk)
                if !contribution.sourceId.isEmpty {
                    Text("证据 \(contribution.sourceId.prefix(8))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(DS.mutedInk)
                }
                Spacer()
                feedbackButton
                Text(String(format: "%+.2f", contribution.delta))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(rowAccentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .summarySurface()
        .opacity(isMarkedInaccurate ? 0.72 : 1)
        .accessibilityHint("打开历史中的来源证据")
    }

    @ViewBuilder
    private var feedbackButton: some View {
        Button {
            onUpdateFeedback(isMarkedInaccurate ? .accepted : .inaccurate)
        } label: {
            Label(
                isMarkedInaccurate ? "恢复" : "不准确",
                systemImage: isMarkedInaccurate ? "checkmark.circle" : "exclamationmark.circle"
            )
            .labelStyle(.iconOnly)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isMarkedInaccurate ? DS.success : DS.mutedInk)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isMarkedInaccurate ? "恢复接受这条贡献" : "标记这条贡献不准确")
    }

    private var isMarkedInaccurate: Bool {
        contribution.userFeedback == .inaccurate
    }

    private var rowAccentColor: Color {
        isMarkedInaccurate ? DS.mutedInk.opacity(0.45) : accentColor
    }

    private var sourceTypeLabel: String {
        switch contribution.sourceType {
        case .dailyEntry: return "日记"
        case .thinkingCard: return "卡片"
        case .quest: return "任务"
        case .verification: return "验证"
        case .principle: return "原则"
        case .project: return "项目"
        }
    }

    private var sourceTypeIcon: String {
        switch contribution.sourceType {
        case .dailyEntry: return "doc.text"
        case .thinkingCard: return "square.on.square"
        case .quest: return "flag"
        case .verification: return "checkmark.shield"
        case .principle: return "bookmark"
        case .project: return "folder"
        }
    }
}

private struct MetricRow: View {
    let title: String
    let value: Double
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.ink)
                    Spacer()
                    Text(String(format: "%.1f", value))
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(DS.accentInk)
                }
                Text(note)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.06))
                    Capsule()
                        .fill(DS.accent)
                        .frame(width: max(8, proxy.size.width * min(max(value / 5.0, 0), 1)))
                }
            }
            .frame(height: 6)
        }
        .summarySurface()
    }
}

private struct GrowthEvidencePanel: View {
    let title: String
    let text: String
    let footnote: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(DS.ink)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(DS.mutedInk)
            Text(footnote)
                .font(.caption)
                .foregroundStyle(DS.caution)
                .fixedSize(horizontal: false, vertical: true)
        }
        .summarySurface()
    }
}

private struct SettingRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(DS.mutedInk)
                .multilineTextAlignment(.trailing)
        }
        .summarySurface()
    }
}

enum PromptRunAuditGroupKind: CaseIterable, Hashable {
    case failed
    case successful

    var title: String {
        switch self {
        case .failed:
            return "失败"
        case .successful:
            return "成功"
        }
    }

    var systemImage: String {
        switch self {
        case .failed:
            return "exclamationmark.triangle"
        case .successful:
            return "checkmark.circle"
        }
    }
}

struct PromptRunAuditGroup: Hashable {
    let kind: PromptRunAuditGroupKind
    let title: String
    let runs: [PromptRun]
}

struct PromptRunAuditSummary: Hashable {
    static let defaultExpandedGroups: Set<PromptRunAuditGroupKind> = [.failed]

    let failed: [PromptRun]
    let successful: [PromptRun]

    var totalCount: Int {
        failed.count + successful.count
    }

    var defaultExpandedGroups: Set<PromptRunAuditGroupKind> {
        Self.defaultExpandedGroups
    }

    var visibleGroupKinds: [PromptRunAuditGroupKind] {
        PromptRunAuditGroupKind.allCases.filter { !group(for: $0).runs.isEmpty }
    }

    init(runs: [PromptRun]) {
        failed = runs.filter { $0.error?.isEmpty == false }
        successful = runs.filter { $0.error?.isEmpty != false }
    }

    func group(for kind: PromptRunAuditGroupKind) -> PromptRunAuditGroup {
        switch kind {
        case .failed:
            return PromptRunAuditGroup(kind: kind, title: kind.title, runs: failed)
        case .successful:
            return PromptRunAuditGroup(kind: kind, title: kind.title, runs: successful)
        }
    }
}

private struct PromptRunAuditGroupSection: View {
    let group: PromptRunAuditGroup
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    Image(systemName: group.kind.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(group.kind == .failed ? DS.caution : DS.success)
                        .frame(width: 18)

                    Text(group.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.ink)

                    Text("\(group.runs.count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(DS.mutedInk)

                    Spacer(minLength: 8)

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                        .frame(width: 12)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(group.runs) { run in
                        PromptRunAuditRow(run: run)
                    }
                }
            }
        }
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
        .padding(10)
        .background(DS.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
    }
}

private struct PromptRunAuditRow: View {
    let run: PromptRun

    private var promptName: String {
        PromptID(rawValue: run.promptId)?.displayName ?? run.promptId
    }

    private var isFailure: Bool {
        run.error?.isEmpty == false
    }

    private var referenceCount: Int {
        let sourceIds = Set(run.sourceRecordIds)
        return run.contextRecordIds.filter { !sourceIds.contains($0) }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(promptName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                    .lineLimit(1)
                Text(runStatusTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isFailure ? DS.caution : DS.success)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        (isFailure ? DS.caution : DS.success).opacity(0.10),
                        in: Capsule()
                    )
                Spacer(minLength: 8)
                Text(run.createdAt.mingsiShortDate)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
            }

            Text("\(run.modelName) · \(run.sessionMode) · v\(run.promptVersion)")
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .lineLimit(1)

            Text("source \(run.sourceRecordIds.count) · reference \(referenceCount)")
                .font(.caption)
                .foregroundStyle(DS.mutedInk)

            if let error = run.error, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(DS.caution)
                    .lineLimit(2)
            } else if !run.requestSummary.isEmpty {
                Text(run.requestSummary)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .lineLimit(2)
            }

            Text(run.auditOutcomeLine)
                .font(.caption)
                .foregroundStyle(DS.mutedInk.opacity(0.7))
        }
        .padding(12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                .stroke(isFailure ? DS.caution.opacity(0.18) : Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private var runStatusTitle: String {
        isFailure ? "失败" : "成功"
    }
}

private struct HistoryPromptRepairRow: View {
    let run: PromptRun

    private var promptName: String {
        PromptID(rawValue: run.promptId)?.displayName ?? run.promptId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(promptName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.ink)
                Text("待补跑")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(DS.caution)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(DS.caution.opacity(0.10), in: Capsule())
                Spacer(minLength: 8)
                Text(run.createdAt.mingsiShortDate)
                    .font(.caption2)
                    .foregroundStyle(DS.mutedInk)
            }

            Text(run.error?.isEmpty == false ? run.error ?? "" : run.requestSummary)
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .lineLimit(2)
        }
        .padding(10)
        .background(DS.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                .stroke(DS.caution.opacity(0.16), lineWidth: 1)
        )
    }
}

struct HistoryRepairCardPreview: Equatable {
    var type: String
    var title: String
    var body: String
    var priority: String
    var sensitivity: String

    static func decode(from candidatePayloadJSON: String?) -> [HistoryRepairCardPreview] {
        guard let candidatePayloadJSON,
              let data = candidatePayloadJSON.data(using: .utf8)
        else { return [] }

        do {
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            return payload.cards.map {
                HistoryRepairCardPreview(
                    type: $0.type,
                    title: $0.title,
                    body: $0.body,
                    priority: $0.priority,
                    sensitivity: $0.sensitivity
                )
            }
        } catch {
            return []
        }
    }

    private struct Payload: Decodable {
        var cards: [Card]
    }

    private struct Card: Decodable {
        var type: String
        var title: String
        var body: String
        var priority: String
        var sensitivity: String
    }
}

extension HistoricalRetryCandidateStatus {
    var historyRepairTitle: String {
        switch self {
        case .pending: return "待处理"
        case .retrying: return "生成中"
        case .candidateReady: return "候选已生成"
        case .accepted: return "已接受"
        case .dismissed: return "已忽略"
        case .blocked: return "已阻断"
        case .failed: return "重试失败"
        }
    }

    var historyRepairDetail: String {
        switch self {
        case .pending: return "等待后台生成候选卡片"
        case .retrying: return "正在重新调用 AI 生成候选"
        case .candidateReady: return "候选已生成，可查看并决定是否接受"
        case .accepted: return "候选已接受，作为本次历史修复审计结果保留"
        case .dismissed: return "已忽略本次候选结果"
        case .blocked: return "因已有确认卡片或下游证据，候选被安全阻断"
        case .failed: return "本次重试生成失败，失败原因已保留"
        }
    }
}

enum PromptRunAuditOutcome {
    case success
    case repairableFromHistory
    case auditOnlyFailure
}

extension PromptRun {
    var auditOutcome: PromptRunAuditOutcome {
        let hasError = error?.isEmpty == false
        guard hasError else { return .success }
        if HistoryRepairPromptSupport.canStartHistoricalRetry(promptId: promptId),
           !sourceRecordIds.isEmpty {
            return .repairableFromHistory
        }
        return .auditOnlyFailure
    }

    var auditOutcomeLine: String {
        switch auditOutcome {
        case .success:
            return "调用成功，审计证据已保留"
        case .repairableFromHistory:
            return "失败 · 可从对应历史日期修复"
        case .auditOnlyFailure:
            return "失败 · 仅审计记录，暂不支持历史修复"
        }
    }
}

struct HistoryRepairSummary {
    var unresolvedCount: Int
    var reviewableCount: Int
    var completedCount: Int
    var problemCount: Int

    var summaryLine: String? {
        guard unresolvedCount + reviewableCount + completedCount + problemCount > 0 else {
            return nil
        }
        var parts: [String] = []
        if unresolvedCount > 0 {
            parts.append("\(unresolvedCount) 待生成候选")
        }
        if reviewableCount > 0 {
            parts.append("\(reviewableCount) 待审阅")
        }
        if completedCount > 0 {
            parts.append("\(completedCount) 已完成")
        }
        if problemCount > 0 {
            parts.append("\(problemCount) 异常")
        }
        return parts.joined(separator: " · ")
    }
}

enum HistoryRepairPromptSupport {
    static func canStartHistoricalRetry(promptId: String) -> Bool {
        PromptID(rawValue: promptId) == .organizeCards
    }
}

private extension Date {
    var mingsiDisplayDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        return formatter.string(from: self)
    }

    var mingsiShortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M.d"
        return formatter.string(from: self)
    }

    var mingsiMonthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: self)
    }

    var mingsiDayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: self)
    }

    var mingsiWeekday: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "E"
        return formatter.string(from: self)
    }
}

struct ProjectCandidateReviewRow: View {
    let candidate: ProjectCandidate
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.dashed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.accent)
                Text(candidate.suggestedName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                Spacer()
                Text(String(format: "%.0f%%", candidate.confidence * 100))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DS.mutedInk)
            }

            Text(candidate.reason)
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            if !candidate.sourceRefs.isEmpty {
                Text("来源：\(candidate.sourceRefs.prefix(2).map { String($0.prefix(8)) }.joined(separator: ", "))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(DS.mutedInk.opacity(0.7))
            }

            HStack(spacing: 12) {
                Button("接受") { onAccept() }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(DS.accent)
                    .controlSize(.small)
                Button("忽略") { onDismiss() }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(DS.accent.opacity(0.04), in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(DS.accent.opacity(0.12), lineWidth: 1)
        )
    }
}

struct ProjectMergeCandidateReviewRow: View {
    let candidate: ProjectMergeCandidate
    let sourceName: String
    let targetName: String
    let onAccept: () -> Void
    let onReject: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "arrow.triangle.merge")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.accent)
                Text(sourceName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                    .lineLimit(1)
                Image(systemName: "arrow.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(DS.mutedInk)
                Text(targetName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(candidate.overlappingEvidenceRefs.count) 证据")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DS.mutedInk)
            }

            Text(candidate.reason)
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            if !candidate.overlappingEvidenceRefs.isEmpty {
                Text("重叠证据：\(candidate.overlappingEvidenceRefs.prefix(3).map { String($0.prefix(8)) }.joined(separator: ", "))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(DS.mutedInk.opacity(0.7))
            }

            HStack(spacing: 10) {
                Button("合并") { onAccept() }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(DS.accent)
                    .controlSize(.small)
                Button("不合并") { onReject() }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("稍后") { onDismiss() }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderless)
                    .foregroundStyle(DS.mutedInk)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
    }
}

struct ProjectLinkCandidateRow: View {
    let candidate: ProjectLinkCandidate
    let projectName: String?
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "link.badge.plus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.accent)
                Text(projectName ?? candidate.candidateProjectName ?? "未命名项目")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                Spacer()
                Text(candidate.linkType.title)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
            }

            Text(candidate.reason)
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            Text("来源：\(candidate.sourceType.title) \(candidate.sourceId.prefix(8))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(DS.mutedInk.opacity(0.7))

            HStack(spacing: 12) {
                Button("确认关联") { onAccept() }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(DS.accent)
                    .controlSize(.small)
                Button("忽略") { onDismiss() }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(DS.accent.opacity(0.04), in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(DS.accent.opacity(0.12), lineWidth: 1)
        )
    }
}
