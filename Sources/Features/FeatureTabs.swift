import SwiftUI
import UIKit

enum SettingsAutomationID {
    static let advancedToolsAction = "settings.advanced-tools.action"
    static let assetPackManifestCard = "settings.asset-pack-manifest.card"
    static let assetPackManifestImportField = "settings.asset-pack-manifest.import-field"
    static let assetPackManifestPasteAction = "settings.asset-pack-manifest.paste-action"
    static let assetPackManifestInstallAction = "settings.asset-pack-manifest.install-action"
    static let assetPackManifestRemoteURLField = "settings.asset-pack-manifest.remote-url-field"
    static let assetPackManifestRemoteInstallAction = "settings.asset-pack-manifest.remote-install-action"
    static let assetPackRegistryCatalogURLField = "settings.asset-pack-registry.catalog-url-field"
    static let assetPackRegistryCatalogFetchAction = "settings.asset-pack-registry.catalog-fetch-action"
    static let assetPackRegistrySubscriptionNameField = "settings.asset-pack-registry.subscription-name-field"
    static let assetPackRegistrySubscriptionURLField = "settings.asset-pack-registry.subscription-url-field"
    static let assetPackRegistrySubscriptionSaveAction = "settings.asset-pack-registry.subscription-save-action"
    static let assetPackRegistrySubscriptionSyncAction = "settings.asset-pack-registry.subscription-sync-action"
    static let assetPackManifestMessage = "settings.asset-pack-manifest.message"
    static let promptAssetQualitySection = "settings.prompt-asset-quality.section"
    static let lensPackCard = "settings.lens-pack.card"
    static let lensPackRefreshAction = "settings.lens-pack.refresh-action"
    static let lensPackImportField = "settings.lens-pack.import-field"
    static let lensPackPasteAction = "settings.lens-pack.paste-action"
    static let lensPackImportAction = "settings.lens-pack.import-action"
    static let promptPackCard = "settings.prompt-pack.card"
    static let promptPackRefreshAction = "settings.prompt-pack.refresh-action"
    static let promptPackImportField = "settings.prompt-pack.import-field"
    static let promptPackPasteAction = "settings.prompt-pack.paste-action"
    static let promptPackImportAction = "settings.prompt-pack.import-action"
    static let sideQuestAction = "settings.side-quest.action"
    static let sideQuestSettingsCard = "settings.side-quest.card"
    static let sideQuestTrialReadoutCard = "settings.side-quest.trial-readout.card"
    static let sideQuestEnabledToggle = "settings.side-quest.enabled-toggle"
    static let sideQuestNotificationsToggle = "settings.side-quest.notifications-toggle"
    static let sideQuestLifeContextCard = "settings.side-quest.life-context.card"
    static let sideQuestTransitionWindows = "settings.side-quest.transition-windows"
    static let sideQuestSeasonCard = "settings.side-quest.season.card"
    static let sideQuestSeasonStartAction = "settings.side-quest.season.start-action"
    static let sideQuestSeasonEndAction = "settings.side-quest.season.end-action"

    static func sideQuestFloorField(_ place: SideQuestPracticalPlace) -> String {
        "settings.side-quest.practical-place.\(place.rawValue).floor-field"
    }

    static func sideQuestStairsPicker(_ place: SideQuestPracticalPlace) -> String {
        "settings.side-quest.practical-place.\(place.rawValue).stairs-picker"
    }

    static func lensPackToggleAction(packId: String) -> String {
        "settings.lens-pack.\(sanitized(packId)).toggle-action"
    }

    static func promptPackToggleAction(packId: String) -> String {
        "settings.prompt-pack.\(sanitized(packId)).toggle-action"
    }

    static func assetPackRegistryCatalogEntryInstallAction(entryId: String) -> String {
        "settings.asset-pack-registry.\(sanitized(entryId)).install-action"
    }

    static func assetPackRegistrySubscriptionToggleAction(subscriptionId: String) -> String {
        "settings.asset-pack-registry.\(sanitized(subscriptionId)).subscription-toggle-action"
    }

    static func promptAssetQualityRow(
        promptPackId: String,
        promptId: String,
        promptVersion: String
    ) -> String {
        "settings.prompt-asset-quality.\(sanitized(promptPackId)).\(sanitized(promptId)).\(sanitized(promptVersion))"
    }

    private static func sanitized(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return value.unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "_" }
            .reduce(into: "") { $0.append($1) }
    }
}

enum GrowthAutomationID {
    static let weeklyGuidanceGenerateAction = "growth.weekly-guidance.generate-action"

    static func principleDetailsToggle(principleId: String) -> String {
        "growth.principle.\(sanitized(principleId)).details-toggle"
    }

    static func disputeLatestPracticeEvidenceAction(evidenceId: String) -> String {
        "growth.principle-practice.\(sanitized(evidenceId)).dispute-action"
    }

    static func disputedPracticeEvidenceAudit(evidenceId: String) -> String {
        "growth.principle-practice.\(sanitized(evidenceId)).disputed-audit"
    }

    static func negativeRecallFeedbackAudit(feedbackId: String) -> String {
        "growth.principle-recall.\(sanitized(feedbackId)).negative-audit"
    }

    private static func sanitized(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return value.unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "_" }
            .reduce(into: "") { $0.append($1) }
    }
}

enum ProjectsAutomationID {
    static let emptyStateTodayAction = "projects.empty-state.today-action"

    static func statusFilter(_ status: ProjectStatus?) -> String {
        "projects.status-filter.\(status?.rawValue ?? "all")"
    }
}

enum HistoryAutomationID {
    static let aiRepairDisclosure = "history.ai-repair.disclosure"

    static func caseSettlementEvidence(caseId: UUID, settlementId: UUID) -> String {
        "history.case.\(sanitized(caseId.uuidString)).settlement.\(sanitized(settlementId.uuidString))"
    }

    private static func sanitized(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return value.unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "_" }
            .reduce(into: "") { $0.append($1) }
    }
}

private struct HistoryRecordLeadEvidence {
    let label: String
    let title: String
    let detail: String?
    let systemImage: String
    let tint: Color
}

private func historyRecordLeadEvidence(_ record: HistoryRecord) -> HistoryRecordLeadEvidence {
    if let card = record.cards.first(where: \.isConfirmed) {
        return HistoryRecordLeadEvidence(
            label: card.type.title,
            title: card.title,
            detail: card.body,
            systemImage: "rectangle.stack",
            tint: card.type.color
        )
    }
    if let quest = record.mainQuest {
        return HistoryRecordLeadEvidence(
            label: "下一次验证",
            title: quest.title,
            detail: quest.completionCriteria,
            systemImage: quest.type.systemImage,
            tint: quest.type.tint
        )
    }
    if let verification = record.verification {
        return HistoryRecordLeadEvidence(
            label: "验证反馈",
            title: verification.completion.title,
            detail: verification.calibrationNote,
            systemImage: "checkmark.seal",
            tint: DS.caution
        )
    }
    if !record.draft.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return HistoryRecordLeadEvidence(
            label: "原始记录",
            title: record.draft.rawText,
            detail: nil,
            systemImage: "text.quote",
            tint: DS.mutedInk
        )
    }
    return HistoryRecordLeadEvidence(
        label: "复盘记录",
        title: "这一天还没有可追溯的证据。",
        detail: nil,
        systemImage: "tray",
        tint: DS.mutedInk
    )
}

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedDate = Date()
    @State private var isCalendarPresented = false
    @State private var isRawInputExpanded = false
    @State private var highlightedSourceId: String?
    @State private var searchText = ""
    @State private var isSearchExpanded = false
    @State private var isAIRepairSectionExpanded = false
    @State private var evidenceFilter: HistoryEvidenceFilter = .all
    @State private var selectedProjectFilter: UUID?
    @State private var selectedLensFilter: ThinkingLens?
    @State private var selectedCardTypeFilter: ThinkingCardType?
    @State private var selectedQuestStatusFilter: QuestStatus?
    @State private var highlightedDeepLink: HistoryDeepLink?
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
        let growthContributions = normalizedHistoryGrowthContributions(visibleRecord.growthContributions)
        if !growthContributions.isEmpty { parts.append("\(growthContributions.count) 成长") }
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
            VStack(alignment: .leading, spacing: 16) {
                if store.hasResumeableLoop && !store.isResumeBannerDismissed {
                    ResumeTodayRow()
                }

                historyEvidenceLead
                historyControls

                if selectedRecord == nil {
                    EmptyStateLine(text: historyQuery.isActive ? "没有匹配的历史证据。试试换一个关键词或证据类型。" : "这一天还没有复盘记录。打开日历可以往前查看一周、一个月或一年。")
                } else {
                    highlightNotice
                    historyEvidenceDetails
                    aiRepairSection
                }
            }
        }
        .task {
            await store.loadHistoryRecords()
            if let link = store.historyDeepLink {
                receiveHistoryDeepLink(link)
            } else if highlightedDeepLink == nil, let latest = records.first?.draft.date {
                selectedDate = latest
            }
            await loadRepairablePromptRunsForVisibleRecord()
        }
        .onChange(of: store.historyDeepLink) { _, newLink in
            if let newLink {
                receiveHistoryDeepLink(newLink)
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

    @ViewBuilder
    private var historyEvidenceLead: some View {
        if selectedRecord == nil {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(selectedDate.mingsiDayNumber)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(DS.mutedInk)
                    .frame(width: 44, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("没有匹配记录")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.ink)
                    Text(selectedDate.mingsiDisplayDate)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                }

                Spacer(minLength: 8)

                Text(historyQuery.isActive ? "\(visibleRecords.count) 条匹配" : "暂无证据")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .multilineTextAlignment(.trailing)
            }
        } else {
            let record = visibleRecord
            let lead = historyRecordLeadEvidence(record)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(record.draft.date.mingsiDayNumber)
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundStyle(DS.accent)
                        .frame(width: 44, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.draft.date.mingsiDisplayDate)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.mutedInk)
                        Text(lead.label)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(lead.tint)
                    }
                    Spacer(minLength: 8)
                    Text(historyQuery.isActive ? "\(visibleRecords.count) 条匹配" : evidenceCounts)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .multilineTextAlignment(.trailing)
                }

                Label(lead.title, systemImage: lead.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    historyEvidenceCount(record.cards.count, title: "卡片", systemImage: "square.on.square")
                    historyEvidenceCount(record.quests.count, title: "验证", systemImage: "scope")
                    historyEvidenceCount(record.principles.count, title: "原则", systemImage: "bookmark")
                    historyEvidenceCount(
                        normalizedHistoryGrowthContributions(record.growthContributions).count,
                        title: "成长",
                        systemImage: "chart.line.uptrend.xyaxis"
                    )
                }
            }
        }
    }

    private func historyEvidenceCount(_ count: Int, title: String, systemImage: String) -> some View {
        Label("\(count) \(title)", systemImage: systemImage)
            .font(.caption.monospacedDigit())
            .foregroundStyle(count == 0 ? DS.mutedInk.opacity(0.7) : DS.accentInk)
    }

    @ViewBuilder
    private var historyEvidenceDetails: some View {
        let growthContributions = normalizedHistoryGrowthContributions(visibleRecord.growthContributions)
        let hasCaseEvidence = visibleRecord.caseRecords.contains { caseRecord in
            !caseRecord.cards.isEmpty ||
                caseRecord.lensSession != nil ||
                !caseRecord.quests.isEmpty ||
                !caseRecord.verifications.isEmpty ||
                !caseRecord.growthSettlements.isEmpty
        }
        let hasDerivedEvidence = !visibleRecord.cards.isEmpty || visibleRecord.lensSession != nil || !visibleRecord.quests.isEmpty || visibleRecord.verification != nil || !visibleRecord.principles.isEmpty || !visibleRecord.projectLinks.isEmpty || !growthContributions.isEmpty || hasCaseEvidence

        if !visibleRecord.draft.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rawInputSection
        }
        if !visibleRecord.caseRecords.isEmpty {
            trainingCaseRecordsSection
        } else {
            if !visibleRecord.cards.isEmpty {
                cardsSection
            }
            if visibleRecord.lensSession != nil {
                lensAndQuestionsSection
            }
            if !visibleRecord.quests.isEmpty {
                questsSection
            }
            if visibleRecord.verification != nil {
                verificationSection
            }
        }
        if !visibleRecord.principles.isEmpty {
            principlesSection
        }
        if !visibleRecord.projectLinks.isEmpty {
            projectEvidenceSection
        }
        if !growthContributions.isEmpty {
            HistoryGrowthContributionsSection(
                contributions: growthContributions,
                caseRecords: visibleRecord.caseRecords
            )
        }
        if !hasDerivedEvidence {
            Label("这一天只留下了原始记录", systemImage: "circle.dotted")
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .padding(.top, 2)
        }
    }

    private var trainingCaseRecordsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("事项证据链")
            ForEach(visibleRecord.caseRecords) { caseRecord in
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text(caseRecord.trainingCase.title)
                            .font(.headline)
                            .foregroundStyle(DS.ink)
                        Spacer()
                        Text(caseRecord.trainingCase.status.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.mutedInk)
                    }

                    ForEach(caseRecord.cards.filter { $0.isConfirmed && !$0.isExcludedFromModel }) { card in
                        Label(card.title, systemImage: "square.on.square")
                            .font(.subheadline)
                            .foregroundStyle(isHighlighted(card.id) ? DS.accent : DS.ink)
                    }

                    if let lensSession = caseRecord.lensSession {
                        Label(lensSession.selectedLens.title, systemImage: "scope")
                            .font(.subheadline)
                            .foregroundStyle(DS.mutedInk)
                    }

                    ForEach(caseRecord.quests) { quest in
                        VStack(alignment: .leading, spacing: 3) {
                            Label(quest.title, systemImage: "flag")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isHighlighted(quest.id) ? DS.accent : DS.ink)
                            Text(quest.completionCriteria)
                                .font(.caption)
                                .foregroundStyle(DS.mutedInk)
                        }
                    }

                    ForEach(caseRecord.verifications) { verification in
                        VStack(alignment: .leading, spacing: 3) {
                            Label("结果记录", systemImage: "doc.text")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(DS.success)
                            Text(verification.evidenceText)
                                .font(.subheadline)
                                .foregroundStyle(DS.ink)
                        }
                    }

                    ForEach(caseRecord.growthSettlements) { settlement in
                        VStack(alignment: .leading, spacing: 4) {
                            Label("你的判断自评 · \(settlement.judgmentUpdate.title)", systemImage: "person.crop.circle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(DS.accentInk)
                            ResultCalibrationSummary(
                                assessment: settlement.calibrationAssessment,
                                note: settlement.calibrationNote,
                                recommendation: settlement.recommendation
                            )
                            Text("原判断：\(settlement.originalJudgment)")
                                .font(.subheadline)
                                .foregroundStyle(DS.ink)
                            Text("实际结果：\(settlement.actualResult)")
                                .font(.subheadline)
                                .foregroundStyle(DS.ink)
                        }
                        .accessibilityIdentifier(
                            HistoryAutomationID.caseSettlementEvidence(
                                caseId: caseRecord.trainingCase.id,
                                settlementId: settlement.id
                            )
                        )
                    }
                }
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) { Divider() }
            }
        }
    }

    private var historyControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        isSearchExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isSearchExpanded ? "xmark" : "magnifyingglass")
                        .font(.caption.weight(.bold))
                        .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
                        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                                .stroke(DS.hairline, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.accent)
                .accessibilityLabel(isSearchExpanded ? "收起历史搜索" : "搜索历史证据")

                historyFilterMenuButton

                Spacer(minLength: 0)

                Button {
                    isCalendarPresented = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.caption.weight(.bold))
                        .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
                        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                                .stroke(DS.hairline, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.accent)
                .accessibilityLabel("打开历史日历")
            }

            if isSearchExpanded || !searchText.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                    PushToTalkInput(
                        text: $searchText,
                        placeholder: "搜索历史证据",
                        accessibilityIdentifier: "history.search-input"
                    )
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
                                .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("清除搜索")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                        .stroke(DS.hairline, lineWidth: 1)
                )
            }
        }
    }

    private var historyFilterMenuButton: some View {
        Menu {
            Section("证据类型") {
                ForEach(HistoryEvidenceFilter.allCases) { filter in
                    Button {
                        evidenceFilter = filter
                    } label: {
                        Label(filter.title, systemImage: filter.systemImage)
                    }
                }
            }

            Section("进一步筛选") {
                Menu("项目") {
                    Button("全部项目") { selectedProjectFilter = nil }
                    ForEach(projectFilterOptions, id: \.id) { option in
                        Button(option.name) { selectedProjectFilter = option.id }
                    }
                }
                .disabled(projectFilterOptions.isEmpty)

                Menu("透镜") {
                    Button("全部透镜") { selectedLensFilter = nil }
                    ForEach(lensFilterOptions) { lens in
                        Button(lens.title) { selectedLensFilter = lens }
                    }
                }
                .disabled(lensFilterOptions.isEmpty)

                Menu("卡片类型") {
                    Button("全部卡片") { selectedCardTypeFilter = nil }
                    ForEach(cardTypeFilterOptions) { cardType in
                        Button(cardType.title) { selectedCardTypeFilter = cardType }
                    }
                }
                .disabled(cardTypeFilterOptions.isEmpty)

                Menu("任务状态") {
                    Button("全部状态") { selectedQuestStatusFilter = nil }
                    ForEach(questStatusFilterOptions) { status in
                        Button(status.historyTitle) { selectedQuestStatusFilter = status }
                    }
                }
                .disabled(questStatusFilterOptions.isEmpty)
            }

            if historyQuery.isActive {
                Button("清除全部筛选", role: .destructive) {
                    evidenceFilter = .all
                    clearAdvancedFilters()
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.caption.weight(.bold))
                .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                        .stroke(DS.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(historyQuery.isActive ? DS.accent : DS.mutedInk)
        .accessibilityLabel("筛选历史证据")
    }

    private func clearAdvancedFilters() {
        selectedProjectFilter = nil
        selectedLensFilter = nil
        selectedCardTypeFilter = nil
        selectedQuestStatusFilter = nil
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
        historyDeepLinkIsLocated(highlightedDeepLink, in: visibleRecord)
    }

    private func receiveHistoryDeepLink(_ link: HistoryDeepLink) {
        highlightedDeepLink = link
        highlightedSourceId = link.sourceId
        if let linkedRecord = records.first(where: { $0.draft.id == link.dailyEntryId }) {
            selectedDate = linkedRecord.draft.date
        }
        store.historyDeepLink = nil
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
        let activeCandidates = historicalRetryCandidates.filter { $0.status.needsHistoryRepairAttention }
        let repairCount = unresolvedRuns.count + activeCandidates.count

        if !isLoadingRepairablePromptRuns && repairCount > 0 {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isAIRepairSectionExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(DS.caution)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("历史 AI 修复")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DS.ink)
                            Text("\(repairCount) 项候选，展开后查看操作；不会改写原记录")
                                .font(.caption)
                                .foregroundStyle(DS.mutedInk)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: isAIRepairSectionExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.mutedInk)
                            .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isAIRepairSectionExpanded ? "收起历史 AI 修复" : "查看历史 AI 修复")
                .accessibilityValue("\(repairCount) 项")
                .accessibilityIdentifier(HistoryAutomationID.aiRepairDisclosure)

                if isAIRepairSectionExpanded {
                    VStack(spacing: 8) {
                        ForEach(unresolvedRuns) { run in
                            historyRepairableRunRow(run: run)
                        }
                    }

                    ForEach(activeCandidates) { candidate in
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
            }
            .summarySurface()
        }
    }

    @ViewBuilder
    private func historyRepairableRunRow(run: PromptRun) -> some View {
        let promptName = PromptID(rawValue: run.promptId)?.displayName ?? run.promptId

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(promptName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.ink)
                Text("待生成")
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

            Text("可重新生成候选卡片；查看或保留候选都不会改动原记录。")
                .font(.caption)
                .foregroundStyle(DS.mutedInk.opacity(0.7))

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
        }
        .padding(10)
        .background(DS.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                .stroke(DS.caution.opacity(0.16), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func historicalCandidateRow(candidate: HistoricalRetryCandidate) -> some View {
        let previews = HistoryRepairCardPreview.decode(from: candidate.candidatePayloadJSON)

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(candidate.status == .accepted ? "已保留候选（未写回）" : candidate.status.historyRepairTitle)
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
                    Text("该记录已有已确认卡片或下游证据，候选只能作为审计记录保留。")
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
                        Label("保留候选记录", systemImage: "checkmark.circle")
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
            SectionLabel("明日验证")
            if visibleRecord.quests.isEmpty {
                EmptyStateLine(text: "这一天没有设计明日验证。")
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
                        Label("完成自评：\(verification.completion.title)", systemImage: verification.completion.title == "完成" ? "checkmark.circle" : "circle")
                            .font(.subheadline)
                            .foregroundStyle(DS.ink)
                        Label("价值自评：\(verification.valueRating.title)", systemImage: "star")
                            .font(.subheadline)
                            .foregroundStyle(DS.ink)
                        Spacer()
                    }
                    if !verification.evidenceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("记录的事实")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(DS.mutedInk)
                            Text(verification.evidenceText)
                                .font(.subheadline)
                                .foregroundStyle(DS.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Text("你的判断自评：\(verification.judgmentUpdate.title)")
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                    ResultCalibrationSummary(
                        assessment: verification.calibrationAssessment,
                        note: verification.calibrationNote,
                        recommendation: nil
                    )
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
            projectNames: store.projectNames,
            highlightedSourceId: highlightedSourceId
        )
    }

    // MARK: - Growth Contributions

    private var growthContributionSection: some View {
        HistoryGrowthContributionsSection(
            contributions: normalizedHistoryGrowthContributions(visibleRecord.growthContributions),
            caseRecords: visibleRecord.caseRecords
        )
    }

}

/// History can be assembled from persisted rows or an in-memory fixture. Both
/// paths may contain superseded contribution revisions, so the timeline must
/// apply the same evidence-level normalization before rendering or counting.
func normalizedHistoryGrowthContributions(_ contributions: [MetricContribution]) -> [MetricContribution] {
    MetricContribution.latestVersionsForHistory(contributions)
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
    let highlightedSourceId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("项目证据")
            if links.isEmpty {
                EmptyStateLine(text: "这一天没有关联的项目证据。")
            } else {
                ProjectLinkListContent(
                    links: links,
                    projectNames: projectNames,
                    highlightedSourceId: highlightedSourceId
                )
            }
        }
    }
}

private struct ProjectLinkListContent: View {
    let links: [ProjectLink]
    let projectNames: [UUID: String]
    let highlightedSourceId: String?

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
        .evidenceSurface(isHighlighted: isProjectLinkHighlighted(link, highlightedSourceId: highlightedSourceId))
    }
}

private struct HistoryGrowthContributionsSection: View {
    let contributions: [MetricContribution]
    let caseRecords: [TrainingCaseRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("成长贡献")
            if contributions.isEmpty {
                EmptyStateLine(text: "这一天没有关联的成长贡献。")
            } else {
                GrowthContributionListContent(contributions: contributions, caseRecords: caseRecords)
            }
        }
    }
}

private struct GrowthContributionListContent: View {
    let contributions: [MetricContribution]
    let caseRecords: [TrainingCaseRecord]

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
                    if let caseTitle = caseTitle(for: contribution) {
                        Text("事项：\(caseTitle)")
                            .font(.caption)
                            .foregroundStyle(DS.mutedInk)
                            .lineLimit(1)
                    }
                    if let sourceTitle = sourceTitle(for: contribution) {
                        Text(sourceTitle)
                            .font(.caption)
                            .foregroundStyle(DS.mutedInk)
                            .lineLimit(1)
                    }
                    Text(String(format: "%+.2f", contribution.delta))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(contribution.direction == .positive ? DS.success : DS.brick)
                }
            }
            Spacer()
        }
        .summarySurface()
    }

    private func caseTitle(for contribution: MetricContribution) -> String? {
        guard let caseId = contribution.sourceCaseId else { return nil }
        return caseRecords.first(where: { $0.trainingCase.id == caseId })?.trainingCase.title
    }

    private func sourceTitle(for contribution: MetricContribution) -> String? {
        switch contribution.sourceType {
        case .quest:
            return caseRecords
                .flatMap(\.quests)
                .first(where: { $0.id.uuidString == contribution.sourceId })
                .map { "验证：\($0.title)" }
        case .verification:
            return caseRecords
                .flatMap(\.verifications)
                .first(where: { $0.id.uuidString == contribution.sourceId })
                .map { "结果：\($0.questTitle)" }
        default:
            return nil
        }
    }
}

struct ProjectsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var statusFilter: ProjectStatus?
    @State private var navigationPath = NavigationPath()
    #if DEBUG
    @State private var hasPushedDirectEntry = false
    #endif

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
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    projectHeader

                    VStack(alignment: .leading, spacing: 16) {
                        if store.hasResumeableLoop && !store.isResumeBannerDismissed {
                            ResumeTodayRow()
                        }

                        projectBoard
                        projectsCandidateReviewSection
                        projectMergeReviewSection
                    }
                    .padding(.horizontal, DS.pagePadding)
                    .padding(.top, 18)
                    .padding(.bottom, DS.primaryScrollBottomReserve)
                }
            }
            .scrollIndicators(.hidden)
            .background(DS.background.ignoresSafeArea())
            .navigationDestination(for: ProjectDetailDirectEntryTarget.self) { target in
                if let item = projectItems.first(where: { $0.id == target.projectID }) {
                    ProjectDetailView(
                        item: item,
                        project: store.projectsById[target.projectID]
                    )
                }
            }
            .task {
                await store.loadHistoryRecords()
                await store.loadPendingProjectMergeCandidates()
                #if DEBUG
                pushDirectEntryIfAvailable()
                #endif
            }
        }
        .background(DS.background.ignoresSafeArea())
        .topSafeAreaScrim()
    }

    #if DEBUG
    private func pushDirectEntryIfAvailable() {
        guard !hasPushedDirectEntry,
              let directEntryID = store.visualQAProjectDetailDirectEntryProjectID,
              navigationPath.isEmpty,
              projectItems.contains(where: { $0.id == directEntryID }) else { return }
        hasPushedDirectEntry = true
        navigationPath.append(ProjectDetailDirectEntryTarget(projectID: directEntryID))
    }
    #endif

    private var projectHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("项目")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(DS.ink)
            Text("只保留有历史证据支撑的长期议题。")
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
        let filtered = statusFilter.map {
            projectStatusFilteredItems(projectItems, projectsById: store.projectsById, status: $0)
        } ?? projectItems.filter { store.projectsById[$0.id]?.status != .archived }
        VStack(alignment: .leading, spacing: 12) {
            projectStatusRail

            HStack(alignment: .firstTextBaseline) {
                SectionLabel(projectItems.isEmpty ? "长期议题" : "当前议题")
                Spacer()
                Text(projectBoardCountText(filteredCount: filtered.count, totalCount: projectItems.count, filterStatus: statusFilter))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DS.mutedInk)
            }

            if projectItems.isEmpty {
                ProjectEmptyEvidenceState(
                    title: store.mainQuest?.title,
                    detail: store.mainQuest?.completionCriteria,
                    canCreateProject: store.canCreateProjectFromCurrentFocus,
                    createProject: {
                        Task { await store.createProjectFromCurrentFocus() }
                    },
                    goToToday: {
                        store.selectedTab = .today
                    }
                )
            } else if filtered.isEmpty {
                Text("没有匹配「\(statusFilter?.chineseTitle ?? "")」状态的项目。")
                    .font(.subheadline)
                    .foregroundStyle(DS.mutedInk)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ForEach(filtered) { item in
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

    private var projectStatusRail: some View {
        let statuses = ProjectStatus.allCases
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                projectStatusRailButton(
                    title: "当前",
                    status: nil,
                    count: projectItems.filter { store.projectsById[$0.id]?.status != .archived }.count
                )
                ForEach(statuses) { status in
                    projectStatusRailButton(
                        title: status.chineseTitle,
                        status: status,
                        count: projectItems.filter { store.projectsById[$0.id]?.status == status }.count
                    )
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("项目状态筛选")
    }

    private func projectStatusRailButton(title: String, status: ProjectStatus?, count: Int) -> some View {
        let isSelected = statusFilter == status
        return Button {
            statusFilter = status
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(status?.tint ?? DS.accent)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                Text(String(count))
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(isSelected ? DS.accentInk : DS.mutedInk)
            }
            .foregroundStyle(isSelected ? DS.accentInk : DS.mutedInk)
            .padding(.horizontal, 11)
            .frame(minHeight: 34)
            .background(
                isSelected ? DS.accent.opacity(0.12) : DS.surface,
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isSelected ? DS.accent.opacity(0.25) : DS.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(ProjectsAutomationID.statusFilter(status))
        .accessibilityLabel("筛选项目：\(title)，\(count) 个")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
    @State private var principleRepairTarget: PrincipleAsset?

    var body: some View {
        FeatureContainer(title: "成长", subtitle: "用趋势和证据看见自己的变化。") {
            VStack(alignment: .leading, spacing: 16) {
                if store.hasResumeableLoop && !store.isResumeBannerDismissed {
                    ResumeTodayRow()
                }

                if !store.growthSettlements.isEmpty {
                    growthSettlementEvidenceSection
                }

                if store.growthSnapshot.canDisplayScores,
                   !store.growthSnapshot.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    GrowthSummaryPanel(snapshot: store.growthSnapshot)
                }

                GrowthReflectionTopicsPanel(
                    summary: reflectionTopicSummary,
                    onSelectSource: { source in
                        store.navigateToHistoryDeepLink(
                            HistoryDeepLink(
                                dailyEntryId: source.dailyEntryId,
                                sourceId: source.caseId?.uuidString ?? source.dailyEntryId.uuidString,
                                sourceType: source.caseId == nil ? .dailyEntry : nil
                            )
                        )
                    }
                )

                weeklyGuidanceSection
                sideQuestExperienceSection

                if !store.growthSnapshot.canDisplayScores {
                    GrowthEvidenceProgressPanel(snapshot: store.growthSnapshot,
                        completedRecordCount: store.historyRecords.filter { $0.draft.state == .sessionComplete }.count) {
                        store.selectedTab = .today
                    }
                } else {
                    GrowthReportReviewPanel(
                        snapshot: store.growthSnapshot,
                        contributions: store.growthReportReviewContributions,
                        onSelectMetric: { metric in
                            selectedMetric = metric
                        }
                    )

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

                    GrowthReportActionPanel(
                        isGenerating: store.isGeneratingGrowthReport,
                        message: store.growthReportMessage,
                        onWeekly: { Task { await store.generateWeeklyGrowthReport() } },
                        onMonthly: { Task { await store.generateMonthlyGrowthReport() } }
                    )
                }

                if store.growthSnapshot.canDisplayScores || !store.activePrinciples.isEmpty || !store.principleTrainingSummaries.isEmpty {
                    GrowthPrincipleAssetSection(
                        isPresentingAddPrinciple: $isPresentingAddPrinciple,
                        onRepairPrinciple: { principle in
                            principleRepairTarget = principle
                        }
                    )
                }
            }
        }
        .sheet(item: $selectedMetric) { metric in
                MetricDetailSheet(
                    snapshot: store.growthSnapshot,
                    metric: metric,
                    contributions: metricDetailContributions(for: metric),
                    onSelectContribution: { contribution in
                        selectedMetric = nil
                        store.navigateToHistoryDeepLink(
                        HistoryDeepLink(
                            dailyEntryId: contribution.sourceDailyEntryId,
                            sourceId: contribution.sourceCaseId?.uuidString ?? contribution.sourceId,
                            sourceType: contribution.sourceCaseId == nil ? contribution.sourceType : nil
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
        .sheet(item: $principleRepairTarget) { principle in
            ManualPrincipleFormSheet(repairing: principle)
        }
    }

    private func metricDetailContributions(for metric: GrowthMetric) -> [MetricContribution] {
        normalizedMetricDetailContributions(
            store.metricContributions + store.growthReportReviewContributions,
            metric: metric
        )
    }

    private var reflectionTopicSummary: ReflectionTopicSummary {
        ReflectionTopicSummaryPolicy().summarize(records: store.historyRecords, excluding: store.todayDraft.id)
    }

    private var weeklyGuidanceSection: some View {
        let readiness = store.weeklyGuidanceReviewReadiness
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("下周训练重点")
                Spacer()
                if store.isGeneratingGrowthReport {
                    ProgressView()
                        .controlSize(.small)
                } else if store.weeklyGuidanceReview == nil, readiness.isEligible {
                    Button {
                        Task { await store.generateWeeklyGrowthReport() }
                    } label: {
                        Label("生成", systemImage: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(DS.accent)
                    .accessibilityIdentifier(GrowthAutomationID.weeklyGuidanceGenerateAction)
                    .accessibilityLabel("生成下周训练重点")
                }
            }

            if let review = store.weeklyGuidanceReview {
                Text(review.trainingFocus)
                    .font(.subheadline)
                    .foregroundStyle(DS.ink)
                if let referenceCopy = weeklyGuidanceReferenceCopy(hintIDs: review.hintIds) {
                    Text("经验参考：\(referenceCopy)")
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                }
            } else if readiness.isEligible {
                Text("已满足生成条件。本周只会基于已验证证据生成一次。")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("最近 7 天：\(readiness.recentVerificationCount) / 3 次验证 · \(readiness.coveredDayCount) / 2 天")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                Text(weeklyGuidanceRequirementText(readiness))
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !store.growthReportMessage.isEmpty {
                Text(store.growthReportMessage)
                    .font(.caption)
                    .foregroundStyle(store.growthReportMessage.contains("失败") ? DS.caution : DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var sideQuestExperienceSection: some View {
        let summary = store.sideQuestExperienceSummary
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("生活经验")
                Spacer()
                Text("独立于训练指标")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
            }

            HStack(spacing: 10) {
                experienceValue(title: "累计", value: "\(summary.totalExperience)")
                experienceValue(title: "连续", value: "\(summary.currentStreak) 天")
                experienceValue(title: "最长", value: "\(summary.longestStreak) 天")
            }

            if !summary.experienceByTrack.isEmpty {
                Text(
                    summary.experienceByTrack
                        .sorted { $0.key.rawValue < $1.key.rawValue }
                        .map { "\($0.key.title) \($0.value)" }
                        .joined(separator: "  ·  ")
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("完成自愿接下的生活奇遇后，这里会记录你的经历与连续性。")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .summarySurface()
    }

    private func experienceValue(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(DS.ink)
            Text(title)
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func weeklyGuidanceRequirementText(_ readiness: WeeklyGuidanceReviewReadiness) -> String {
        var requirements: [String] = []
        if readiness.remainingVerificationCount > 0 {
            requirements.append("还需 \(readiness.remainingVerificationCount) 次验证")
        }
        if readiness.remainingDayCount > 0 {
            requirements.append("再覆盖 \(readiness.remainingDayCount) 天")
        }
        return "达到条件后，可以由你主动生成一次下周训练重点。\(requirements.joined(separator: "，"))。"
    }

    private var growthSettlementEvidenceSection: some View {
        let visibleSettlements = store.growthSettlements.filter {
            !$0.originalJudgment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !$0.actualResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return Group {
            if !visibleSettlements.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        SectionLabel("判断变化")
                        Spacer()
                        Text("Before / After")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.mutedInk)
                    }

                    ForEach(Array(visibleSettlements.prefix(8))) { settlement in
                        Button {
                            guard let caseId = settlement.caseId,
                                  let record = store.historyRecords.first(where: { history in
                                      history.caseRecords.contains { $0.trainingCase.id == caseId }
                                  })
                            else { return }
                            store.navigateToHistoryDeepLink(
                                HistoryDeepLink(
                                    dailyEntryId: record.draft.id,
                                    sourceId: caseId.uuidString,
                                    sourceType: nil
                                )
                            )
                        } label: {
                            GrowthBeforeAfterRow(
                                settlement: settlement,
                                identifierPrefix: "growth.before-after.\(settlement.id.uuidString)"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("growth.before-after.\(settlement.id.uuidString).row")
                        Divider()
                    }
                }
                .accessibilityIdentifier("growth.before-after.section")
            }
        }
    }
}

/// The model's assessment of reported evidence stays distinct from user ratings.
struct ResultCalibrationSummary: View {
    let assessment: CalibrationAssessment?
    let note: String
    let recommendation: String?
    var showsJudgmentTitle = true
    var showsEvidenceQuotes = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let assessment {
                if showsJudgmentTitle {
                    Text(assessment.judgmentStatus.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.ink)
                }
                Text("\(assessment.evidenceStatus.title) · \(assessment.criteriaStatus.title)")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(DS.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let recommendation, !recommendation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(recommendation)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if showsEvidenceQuotes, let assessment, !assessment.evidenceQuotes.isEmpty {
                DisclosureGroup("引用的记录") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(assessment.evidenceQuotes, id: \.self) { quote in
                            Text("“\(quote)”")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 6)
                }
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
            }
        }
    }
}

private struct GrowthBeforeAfterRow: View {
    let settlement: GrowthSettlement
    let identifierPrefix: String

    private var evidenceTitles: [String] {
        settlement.evidenceItems
            .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(settlement.calibrationAssessment?.judgmentStatus.title ?? "你的判断自评：\(settlement.judgmentUpdate.title)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DS.accent)
                Spacer(minLength: 8)
                Text(settlement.createdAt.mingsiShortDate)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DS.mutedInk)
            }

            ResultCalibrationSummary(
                assessment: settlement.calibrationAssessment,
                note: settlement.calibrationNote,
                recommendation: settlement.recommendation,
                showsJudgmentTitle: false,
                showsEvidenceQuotes: false
            )
            if settlement.calibrationAssessment != nil {
                Text("你的判断自评：\(settlement.judgmentUpdate.title)")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
            }

            comparisonBlock(
                label: "判断当时",
                text: settlement.originalJudgment,
                color: DS.mutedInk,
                identifier: "\(identifierPrefix).before"
            )

            Image(systemName: "arrow.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.hairline)
                .accessibilityHidden(true)

            comparisonBlock(
                label: "结果后来",
                text: settlement.actualResult,
                color: DS.ink,
                identifier: "\(identifierPrefix).after"
            )

            if !evidenceTitles.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("来源证据 \(settlement.evidenceItems.count) 条", systemImage: "link")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                    Text(evidenceTitles.joined(separator: " / "))
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityHint("打开历史中的验证来源")
    }

    private func comparisonBlock(label: String, text: String, color: Color, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(DS.mutedInk)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(identifier)
        }
    }
}

private struct GrowthPrincipleAssetSection: View {
    @EnvironmentObject private var store: AppStore
    @Binding var isPresentingAddPrinciple: Bool
    var onRepairPrinciple: (PrincipleAsset) -> Void

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

            if !store.todayLoopMessage.isEmpty {
                ProjectInsightNote(message: store.todayLoopMessage)
            }

            if !store.principleTrainingSummaries.isEmpty {
                ForEach(store.principleTrainingSummaries) { summary in
                    PrincipleArchiveRow(
                        principle: summary.principle,
                        trainingSummary: summary,
                        compact: true,
                        onRepair: summary.state == .needsReview ? {
                            onRepairPrinciple(summary.principle)
                        } : nil,
                        onArchive: {
                            Task {
                                await store.archivePrinciple(summary.principle.id)
                            }
                        },
                        onDisputeLatestPracticeEvidence: summary.latestPracticeEvidenceId.map { evidenceId in
                            {
                                Task {
                                    await store.disputePrinciplePracticeEvidence(
                                        evidenceId,
                                        note: "用户在 Growth 原则资产列表标记最近练习归因不准确。"
                                    )
                                }
                            }
                        },
                        onDelete: {
                            Task {
                                await store.deletePrinciple(summary.principle.id)
                            }
                        }
                    )
                }
            } else if store.activePrinciples.isEmpty {
                EmptyStateLine(text: "还没有原则资产。可以手工保存一条可复用的行为规则。")
            } else {
                ForEach(store.activePrinciples) { principle in
                    PrincipleArchiveRow(
                        principle: principle,
                        onArchive: {
                            Task {
                                await store.archivePrinciple(principle.id)
                            }
                        },
                        onDelete: {
                            Task {
                                await store.deletePrinciple(principle.id)
                            }
                        }
                    )
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
    private let repairing: PrincipleAsset?

    init(repairing: PrincipleAsset? = nil) {
        self.repairing = repairing
        _title = State(initialValue: repairing?.title ?? "")
        _summary = State(initialValue: repairing?.summary ?? "")
        _triggerContext = State(initialValue: repairing?.triggerContext ?? "")
        _actionsText = State(initialValue: repairing?.actions.joined(separator: "\n") ?? "")
        _successCriteria = State(initialValue: repairing?.successCriteria ?? "")
        _exceptions = State(initialValue: repairing?.exceptions ?? "")
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSaving
    }

    private var navigationTitle: String {
        repairing == nil ? "添加原则" : "复审原则"
    }

    private var saveButtonTitle: String {
        if isSaving { return "保存中" }
        return repairing == nil ? "保存" : "启用"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("必填") {
                    PushToTalkInput(text: $title, placeholder: "标题", accessibilityIdentifier: "principle.edit.title")
                    PushToTalkInput(text: $summary, placeholder: "摘要", accessibilityIdentifier: "principle.edit.summary", usesTextEditor: true)
                }

                Section("适用方式") {
                    PushToTalkInput(text: $triggerContext, placeholder: "触发场景", accessibilityIdentifier: "principle.edit.trigger-context", usesTextEditor: true)
                    PushToTalkInput(text: $actionsText, placeholder: "行动步骤（每行一个）", accessibilityIdentifier: "principle.edit.actions", usesTextEditor: true)
                    PushToTalkInput(text: $successCriteria, placeholder: "成功标准", accessibilityIdentifier: "principle.edit.success-criteria", usesTextEditor: true)
                    PushToTalkInput(text: $exceptions, placeholder: "例外情况", accessibilityIdentifier: "principle.edit.exceptions", usesTextEditor: true)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(DS.caution)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saveButtonTitle) {
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
        let didSave: Bool
        if let repairing {
            didSave = await store.repairPrinciple(
                repairing.id,
                title: title,
                summary: summary,
                triggerContext: triggerContext,
                actions: actions,
                successCriteria: successCriteria,
                exceptions: exceptions
            )
        } else {
            didSave = await store.addManualPrinciple(
                title: title,
                summary: summary,
                triggerContext: triggerContext,
                actions: actions,
                successCriteria: successCriteria,
                exceptions: exceptions
            )
        }
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

    private var reviewableContributions: [MetricContribution] {
        contributions.filter { contribution in
            contribution.candidateStatus != .rejected &&
            contribution.userFeedback != .inaccurate &&
            contribution.userFeedback != .dismissed &&
            !contribution.sourceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var positiveCount: Int {
        reviewableContributions.filter { $0.direction == .positive }.count
    }

    private var negativeCount: Int {
        reviewableContributions.filter { $0.direction == .negative }.count
    }

    private var groupedContributions: [(metric: GrowthMetric, contributions: [MetricContribution])] {
        GrowthMetric.allCases.compactMap { metric in
            let metricContributions = reviewableContributions.filter { $0.metric == metric }
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
                Text("暂未形成可审查的成长报告。复盘次数和自评不能替代实际结果依据。")
                    .font(.subheadline)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                reportLedger

                if groupedContributions.isEmpty {
                    Text("这份报告还没有可审查的贡献。重新生成报告或继续积累验证证据后再查看。")
                        .font(.subheadline)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: 8) {
                        ForEach(groupedContributions, id: \.metric) { group in
                            GrowthReportMetricEvidenceRow(
                                metric: group.metric,
                                metricReason: snapshot.metricReasons[group.metric.rawValue],
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
            GrowthReportLedgerChip(title: "复盘", value: "\(snapshot.completeLoopCount)")
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
    let metricReason: String?
    let contributions: [MetricContribution]
    let onTap: () -> Void

    private var positiveCount: Int {
        contributions.filter { $0.direction == .positive }.count
    }

    private var negativeCount: Int {
        contributions.filter { $0.direction == .negative }.count
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 3, height: 42)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(growthMetricDisplayTitle(metric))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.ink)
                        Text(growthContributionCountSummary(contributions))
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(DS.mutedInk)
                    }

                    if let leading = growthLeadingContribution(contributions) {
                        Text(leading.title)
                            .font(.caption)
                            .foregroundStyle(DS.mutedInk)
                            .lineLimit(2)
                    }

                    if let reason = growthMetricReasonDisplay(metricReason) ?? growthMetricFallbackReason(reason: metricReason, contributions: contributions) {
                        Text(reason)
                            .font(.caption2)
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
    @Environment(\.openURL) private var openURL
    @State private var apiKeyInput = ""
    @State private var baseURLInput = ""
    @State private var modelNameInput = ""
    @State private var modelProtocol: GLMClientConfiguration.ProtocolKind = .openAICompatible
    @State private var clipboardMessage = ""
    @State private var expandedPromptAuditGroups: Set<PromptRunAuditGroupKind> = PromptRunAuditSummary.defaultExpandedGroups
    @State private var promptTemplateExpanded = false
    @State private var selectedPromptID: PromptID = .organizeCards
    @State private var selectedSessionMode: SessionMode = .standard
    @State private var promptSystemTextExpanded = false
    @State private var promptUserTextExpanded = false
    @State private var isPreparingDataExport = false
    @State private var lensPackJSONInput = ""
    @State private var promptPackJSONInput = ""
    @State private var assetPackManifestJSONInput = AppStore.shouldUseVisualQASettingsAssetPackManifestFixture() ? "{" : ""
    @State private var assetPackManifestRemoteURLInput = AppStore.shouldUseVisualQASettingsAssetPackManifestFixture()
        ? "http://127.0.0.1:1/mingsi-asset-pack-manifest.json"
        : ""
    @State private var assetPackRegistryCatalogURLInput = AppStore.shouldUseVisualQASettingsAssetPackManifestFixture()
        ? "http://127.0.0.1:1/mingsi-asset-pack-catalog.json"
        : ""
    @State private var assetPackRegistrySubscriptionNameInput = ""
    @State private var assetPackRegistrySubscriptionURLInput = ""
    @State private var lifeContextHomeLabel = ""
    @State private var lifeContextWorkLabel = ""
    @State private var lifeContextHomeFloorLevel = ""
    @State private var lifeContextWorkplaceFloorLevel = ""
    @State private var lifeContextConstraints: [String] = []
    @State private var newLifeContextConstraint = ""
    @State private var sideQuestSeasonTheme = "城市漫游"
    @State private var sideQuestSeasonIntent = ""

    var body: some View {
        FeatureContainer(title: "设置", subtitle: "隐私、模型、通知和数据控制。") {
            VStack(spacing: DS.cardSpacing) {
                apiKeyCard
                dataExportCard
                if let feature = store.mentorFeatureStore {
                    MentorLessonPreferencesView(feature: feature)
                }
                buildIdentityRow
                sideQuestSettingsLink
                SettingRow(title: "API Key", value: store.apiKeyConfigured ? "已配置" : "未配置")
                SettingRow(title: "默认模式", value: store.todayDraft.sessionMode.displayTitle)
                SettingRow(title: "本地通知", value: store.reminderStatusMessage)
                advancedToolsLink
            }
        }
        .onAppear {
            modelProtocol = store.currentModelProtocol
            baseURLInput = store.currentBaseURL
            modelNameInput = store.currentModelName
            loadSideQuestLifeContextInputs()
        }
    }

    private var buildIdentityRow: some View {
        let identity = AppBuildIdentity.current
        return SettingRow(title: "应用版本", value: identity.summary)
            .accessibilityElement(children: .combine)
            .accessibilityValue(identity.copyDescription)
            .accessibilityHint("长按可复制完整构建信息")
            .accessibilityIdentifier("settings.build-identity")
            .contextMenu {
                Button("复制构建信息") { UIPasteboard.general.string = identity.copyDescription }
            }
            .accessibilityAction(named: Text("复制构建信息")) {
                UIPasteboard.general.string = identity.copyDescription
            }
    }

    private var sideQuestSettingsLink: some View {
        NavigationLink {
            sideQuestSettingsView
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DS.note)
                    .frame(width: 36, height: 36)
                    .background(DS.note.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("生活奇遇")
                        .font(.headline)
                        .foregroundStyle(DS.ink)
                    Text(sideQuestSettingsSummary)
                        .font(.footnote)
                        .foregroundStyle(DS.mutedInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cardSurface()
        .accessibilityIdentifier(SettingsAutomationID.sideQuestAction)
    }

    private var sideQuestSettingsSummary: String {
        let preference = store.sideQuestPreference
        guard preference.isEnabled else {
            return "可选，由模型判断是否出现 · 已暂停"
        }

        let notificationStatus: String
        if preference.notificationsEnabled {
            notificationStatus = SideQuestNotificationScheduleOption.all.first {
                $0.schedule == preference.notificationSchedule
            }.map { "通知 \($0.title)" } ?? "通知已开启"
        } else {
            notificationStatus = "通知关闭"
        }
        return "可选，由模型判断是否出现 · 已开启 · \(preference.frequency.title) · \(notificationStatus)"
    }

    private var sideQuestSettingsView: some View {
        ScrollView {
            VStack(spacing: DS.cardSpacing) {
                sideQuestSettingsCard
                sideQuestSeasonCard
                sideQuestTrialReadoutCard
                sideQuestPermissionsCard
                sideQuestLifeContextCard
            }
            .padding(.horizontal, DS.pagePadding)
            .padding(.top, DS.primaryScrollTopPadding)
            .padding(.bottom, DS.primaryScrollBottomReserve)
        }
        .scrollIndicators(.hidden)
        .background(DS.background.ignoresSafeArea())
        .navigationTitle("生活奇遇")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.refreshSideQuestPermissionStatuses() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            store.refreshSideQuestPermissionStatuses()
        }
    }

    private var sideQuestSettingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DS.note)
                    .frame(width: 36, height: 36)
                    .background(DS.note.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("生活奇遇")
                        .font(.headline)
                        .foregroundStyle(DS.ink)
                    Text("由模型判断是否值得出现；你始终可以跳过，不会影响训练指标。")
                        .font(.footnote)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            Toggle("接收偶发生活奇遇", isOn: Binding(
                get: { store.sideQuestPreference.isEnabled },
                set: { value in Task { await store.setSideQuestInvitationsEnabled(value) } }
            ))
            .tint(DS.accent)
            .accessibilityIdentifier(SettingsAutomationID.sideQuestEnabledToggle)

            if store.sideQuestPreference.isEnabled {
                Picker("出现频率", selection: Binding(
                    get: { store.sideQuestPreference.frequency },
                    set: { value in Task { await store.setSideQuestFrequency(value) } }
                )) {
                    ForEach(SideQuestOfferFrequency.allCases) { frequency in
                        Text(frequency.title).tag(frequency)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("希望遇见哪些方向")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.ink)
                    ForEach(SideQuestCategory.allCases) { category in
                        Toggle(category.title, isOn: Binding(
                            get: { store.sideQuestPreference.enabledCategories.contains(category) },
                            set: { value in Task { await store.setSideQuestCategory(category, isEnabled: value) } }
                        ))
                        .font(.subheadline)
                        .tint(DS.accent)
                    }
                }

                Divider()

                Toggle("允许生活奇遇通知", isOn: Binding(
                    get: { store.sideQuestPreference.notificationsEnabled },
                    set: { value in Task { await store.setSideQuestNotificationsEnabled(value) } }
                ))
                .tint(DS.accent)
                .accessibilityIdentifier(SettingsAutomationID.sideQuestNotificationsToggle)

                if store.sideQuestPreference.notificationsEnabled {
                    Picker("提醒时段", selection: Binding(
                        get: {
                            SideQuestNotificationScheduleOption.all.first {
                                $0.schedule == store.sideQuestPreference.notificationSchedule
                            } ?? SideQuestNotificationScheduleOption.default
                        },
                        set: { value in Task { await store.setSideQuestNotificationSchedule(value.schedule) } }
                    )) {
                        ForEach(SideQuestNotificationScheduleOption.all) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }
            }

            if !store.sideQuestMessage.isEmpty {
                Text(store.sideQuestMessage)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardSurface()
        .accessibilityIdentifier(SettingsAutomationID.sideQuestSettingsCard)
    }

    private var sideQuestTrialReadoutCard: some View {
        let metrics = store.sideQuestTrialMetrics
        let planningDecisions = metrics?.planningDecisions ?? 0
        let holds = metrics?.holds ?? 0
        let offers = metrics?.offers ?? 0
        let accepted = metrics?.accepted ?? 0
        let completed = metrics?.completed ?? 0
        let corrections = metrics?.correctionsByKind.values.reduce(0, +) ?? 0
        let acceptanceRate = metrics?.acceptanceRate ?? 0
        let completionRate = metrics?.completionRate ?? 0
        let holdRate = metrics?.holdRate ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("生活奇遇试用记录")
                    .font(.headline)
                    .foregroundStyle(DS.ink)
                Text("最近 7 天 · 仅本机记录")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
            }

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                GridRow {
                    sideQuestTrialMetric("模型判断", value: "\(planningDecisions)")
                    sideQuestTrialMetric("暂不出现", value: "\(holds)")
                }
                GridRow {
                    sideQuestTrialMetric("发出", value: "\(offers)")
                    sideQuestTrialMetric("接下", value: "\(accepted)")
                }
                GridRow {
                    sideQuestTrialMetric("完成", value: "\(completed)")
                    sideQuestTrialMetric("纠正", value: "\(corrections)")
                }
                GridRow {
                    sideQuestTrialMetric("暂不出现率", value: Self.sideQuestPercentage(holdRate))
                    sideQuestTrialMetric("接下率", value: Self.sideQuestPercentage(acceptanceRate))
                }
                GridRow {
                    sideQuestTrialMetric("完成率", value: Self.sideQuestPercentage(completionRate))
                    Color.clear
                }
            }

            Text("用于 vNext.1 的保留、调整或移除决策，不改变训练指标。")
                .font(.footnote)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardSurface()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "生活奇遇试用记录，最近 7 天，仅本机记录。模型判断 \(planningDecisions) 次，暂不出现 \(holds) 次，发出 \(offers) 个，接下 \(accepted) 个，完成 \(completed) 个，纠正 \(corrections) 次，暂不出现率 \(Self.sideQuestPercentage(holdRate))，接下率 \(Self.sideQuestPercentage(acceptanceRate))，完成率 \(Self.sideQuestPercentage(completionRate))。用于 vNext.1 的保留、调整或移除决策，不改变训练指标。"
        )
        .accessibilityIdentifier(SettingsAutomationID.sideQuestTrialReadoutCard)
    }

    private var sideQuestSeasonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("30 天探索季")
                    .font(.headline)
                    .foregroundStyle(DS.ink)
                    .accessibilityIdentifier(SettingsAutomationID.sideQuestSeasonCard)
                Text("给生活奇遇一个主题弧线，不是每日打卡；模型仍会判断何时出现或暂不出现。")
                    .font(.footnote)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let season = store.activeSideQuestSeason {
                Text(season.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                if let intent = season.intent {
                    Text(intent)
                        .font(.footnote)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                    GridRow {
                        sideQuestTrialMetric("完成", value: "\(season.completedCount)")
                        sideQuestTrialMetric("跳过", value: "\(season.skippedCount)")
                    }
                    GridRow {
                        sideQuestTrialMetric("接下", value: "\(season.acceptedCount)")
                        sideQuestTrialMetric("第几天", value: "\(season.currentDay)/\(season.maxDays)")
                    }
                }
                Button("结束探索季") {
                    Task { await store.closeSideQuestSeason(early: true) }
                }
                .buttonStyle(.bordered)
                .tint(DS.brick)
                .disabled(store.isSideQuestActionInFlight)
                .accessibilityIdentifier(SettingsAutomationID.sideQuestSeasonEndAction)
            } else if let season = store.sideQuestSeasonReview {
                Text("最近一季回顾：\(season.title)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                Text("完成 \(season.completedCount) · 跳过 \(season.skippedCount) · 接下 \(season.acceptedCount)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(DS.mutedInk)
                if !store.sideQuestSeasonCategories.isEmpty {
                    Text(store.sideQuestSeasonCategories
                        .sorted { $0.key.rawValue < $1.key.rawValue }
                        .map { "\($0.key.title) \($0.value)" }
                        .joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(DS.mutedInk)
                }
                Button("开启新的 30 天探索季") {
                    Task { await store.startSideQuestSeason(title: sideQuestSeasonTheme, intent: sideQuestSeasonIntent) }
                }
                .buttonStyle(.bordered)
                .tint(DS.accent)
                .disabled(store.isSideQuestActionInFlight)
                .accessibilityIdentifier(SettingsAutomationID.sideQuestSeasonStartAction)
            } else {
                Picker("探索主题", selection: $sideQuestSeasonTheme) {
                    Text("城市漫游").tag("城市漫游")
                    Text("重新连接").tag("重新连接")
                    Text("动手创作").tag("动手创作")
                    Text("照顾身体").tag("照顾身体")
                }
                PushToTalkInput(
                    text: $sideQuestSeasonIntent,
                    placeholder: "这一季想探索什么（可选）",
                    accessibilityIdentifier: "settings.side-quest-season.intent"
                )
                Button("开启 30 天探索季") {
                    Task { await store.startSideQuestSeason(title: sideQuestSeasonTheme, intent: sideQuestSeasonIntent) }
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.accent)
                .disabled(store.isSideQuestActionInFlight)
                .accessibilityIdentifier(SettingsAutomationID.sideQuestSeasonStartAction)
            }
        }
        .cardSurface()
    }

    private func sideQuestTrialMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(DS.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func sideQuestPercentage(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private var sideQuestPermissionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("系统情境权限")
                .font(.headline)
            Text("仅在你主动点击时请求；今日页面不会触发系统权限弹窗。")
                .font(.footnote)
                .foregroundStyle(DS.mutedInk)
            permissionRow("位置", kind: .location, status: store.sideQuestLocationAuthorizationStatus) {
                store.requestSideQuestLocationPermission()
            }
            Divider()
            permissionRow("日历", kind: .calendar, status: store.sideQuestCalendarAuthorizationStatus) {
                store.requestSideQuestCalendarPermission()
            }
            Divider()
            permissionRow("健康", kind: .health, status: store.sideQuestHealthAuthorizationStatus) {
                store.requestSideQuestHealthPermission()
            }
            Text("健康读取范围由系统管理；完成授权选择也不表示每一项都已允许。")
                .font(.footnote)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardSurface()
    }

    private func permissionRow(
        _ title: String,
        kind: SideQuestPermissionKind,
        status: SideQuestAuthorizationStatus,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .layoutPriority(1)
                Spacer(minLength: 8)
                Text(status.displayTitle)
                    .font(.footnote)
                    .foregroundStyle(DS.mutedInk)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.permission.\(kind.rawValue).status")
            }
            HStack(spacing: 12) {
                Button {
                    if [.authorized, .denied, .restricted].contains(status) { openPermissionSettings() }
                    else { action() }
                } label: {
                    Text(permissionActionTitle(status))
                        .frame(minHeight: 44)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.bordered)
                .disabled(status == .unavailable || store.sideQuestPermissionRequest != nil)
                .accessibilityLabel("\(title)：\(permissionActionTitle(status))")
                .accessibilityIdentifier("settings.permission.\(kind.rawValue).request")
                if status == .readAccessUnknown {
                    Button { openPermissionSettings() } label: {
                        Text("查看设置").frame(minHeight: 44)
                    }
                    .disabled(store.sideQuestPermissionRequest != nil)
                    .accessibilityIdentifier("settings.permission.\(kind.rawValue).settings")
                }
                if store.sideQuestPermissionRequest == kind {
                    ProgressView()
                        .accessibilityLabel("等待\(title)授权选择")
                }
            }
            if let message = store.sideQuestPermissionMessages[kind] {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.permission.\(kind.rawValue).message")
            }
        }
    }

    private func permissionActionTitle(_ status: SideQuestAuthorizationStatus) -> String {
        switch status {
        case .authorized, .denied, .restricted: return "查看设置"
        case .writeOnly: return "请求读取"
        case .readAccessUnknown: return "选择读取范围"
        case .unavailable: return "暂不可用"
        case .notDetermined: return "请求授权"
        }
    }

    private func openPermissionSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }

    private var sideQuestLifeContextCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("生活情境")
                    .font(.headline)
                    .foregroundStyle(DS.ink)
                    .accessibilityIdentifier(SettingsAutomationID.sideQuestLifeContextCard)
                Text("地点称呼只留在本机；模型只会看到家或工作地点及你选择的实际条件，不会收到称呼、定位、日历原文或健康样本。")
                    .font(.footnote)
                    .foregroundStyle(DS.mutedInk)
            }

            practicalPlaceFields(
                title: "家",
                labelPrompt: "家的称呼（仅本机保存，可选）",
                label: $lifeContextHomeLabel,
                floorLevel: $lifeContextHomeFloorLevel,
                place: .home
            )

            practicalPlaceFields(
                title: "工作地点",
                labelPrompt: "工作地点的称呼（仅本机保存，可选）",
                label: $lifeContextWorkLabel,
                floorLevel: $lifeContextWorkplaceFloorLevel,
                place: .workplace
            )

            transitionWindowMultiSelect

            contextMultiSelect(title: "通勤方式", values: SideQuestCommuteMode.allCases, selection: store.sideQuestLifeContextProfile.commuteModes) { value, isSelected in
                updateSideQuestLifeContext { profile in
                    if isSelected { profile.commuteModes.insert(value) } else { profile.commuteModes.remove(value) }
                }
            }

            Picker("活动范围", selection: Binding(
                get: { store.sideQuestLifeContextProfile.preferredActivityRadius },
                set: { radius in updateSideQuestLifeContext { $0.preferredActivityRadius = radius } }
            )) {
                Text("未设置").tag(SideQuestActivityRadius?.none)
                ForEach(SideQuestActivityRadius.allCases) { radius in
                    Text(radius.title).tag(Optional(radius))
                }
            }

            contextMultiSelect(title: "活动偏好", values: SideQuestMovementPreference.allCases, selection: store.sideQuestLifeContextProfile.movementPreferences) { value, isSelected in
                updateSideQuestLifeContext { profile in
                    if isSelected { profile.movementPreferences.insert(value) } else { profile.movementPreferences.remove(value) }
                }
            }

            contextMultiSelect(title: "不接受的奇遇类别", values: SideQuestCategory.allCases, selection: store.sideQuestLifeContextProfile.unavailableCategories) { value, isSelected in
                updateSideQuestLifeContext { profile in
                    if isSelected { profile.unavailableCategories.insert(value) } else { profile.unavailableCategories.remove(value) }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("明确限制")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                ForEach(Array(lifeContextConstraints.enumerated()), id: \.offset) { index, constraint in
                    HStack(spacing: 8) {
                        Text(constraint)
                            .font(.subheadline)
                            .foregroundStyle(DS.ink)
                        Spacer(minLength: 0)
                        Button {
                            lifeContextConstraints.remove(at: index)
                            persistSideQuestLifeContextInputs()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(DS.brick)
                        .accessibilityLabel("删除限制")
                    }
                }
                HStack(spacing: 8) {
                    PushToTalkInput(
                        text: $newLifeContextConstraint,
                        placeholder: "例如：不安排需要消费的活动",
                        accessibilityIdentifier: "settings.side-quest-life-context.new-constraint"
                    )
                    Button {
                        let normalized = newLifeContextConstraint.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !normalized.isEmpty else { return }
                        lifeContextConstraints.append(String(normalized.prefix(180)))
                        newLifeContextConstraint = ""
                        persistSideQuestLifeContextInputs()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(DS.accent)
                    .accessibilityLabel("添加限制")
                }
            }

            Button("保存生活情境") {
                persistSideQuestLifeContextInputs()
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.accent)
        }
        .cardSurface()
    }

    private func contextMultiSelect<Value: Identifiable & Hashable>(
        title: String,
        values: [Value],
        selection: Set<Value>,
        update: @escaping (Value, Bool) -> Void
    ) -> some View where Value.ID == String, Value: RawRepresentable, Value.RawValue == String {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.ink)
            ForEach(values) { value in
                Toggle(value.rawValue, isOn: Binding(
                    get: { selection.contains(value) },
                    set: { update(value, $0) }
                ))
                .font(.subheadline)
                .tint(DS.accent)
            }
        }
    }

    private func practicalPlaceFields(
        title: String,
        labelPrompt: String,
        label: Binding<String>,
        floorLevel: Binding<String>,
        place: SideQuestPracticalPlace
    ) -> some View {
        let practical = store.sideQuestLifeContextProfile.practicalContext(for: place)
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.ink)
            PushToTalkInput(
                text: label,
                placeholder: labelPrompt,
                accessibilityIdentifier: "settings.side-quest-place.\(place.rawValue).label"
            )
            .textInputAutocapitalization(.never)
            PushToTalkInput(
                text: floorLevel,
                placeholder: "所在楼层（可选）",
                accessibilityIdentifier: SettingsAutomationID.sideQuestFloorField(place)
            )
                .keyboardType(.numberPad)
                .accessibilityIdentifier(SettingsAutomationID.sideQuestFloorField(place))
            Picker("是否方便走楼梯", selection: Binding(
                get: { practical.stairsAvailable },
                set: { value in
                    updateSideQuestLifeContext { profile in
                        var updated = profile.practicalContext(for: place)
                        updated.stairsAvailable = value
                        profile.setPracticalContext(updated, for: place)
                    }
                }
            )) {
                Text("未设置").tag(Bool?.none)
                Text("可以").tag(Optional(true))
                Text("不方便或没有").tag(Optional(false))
            }
            .accessibilityIdentifier(SettingsAutomationID.sideQuestStairsPicker(place))
        }
        .padding(.vertical, 2)
    }

    private var transitionWindowMultiSelect: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("常见时段")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.ink)
                .accessibilityIdentifier(SettingsAutomationID.sideQuestTransitionWindows)
            ForEach(SideQuestTransitionWindow.allCases) { window in
                Toggle(window.title, isOn: Binding(
                    get: { store.sideQuestLifeContextProfile.transitionWindows.contains(window) },
                    set: { isSelected in
                        updateSideQuestLifeContext { profile in
                            if isSelected { profile.transitionWindows.insert(window) } else { profile.transitionWindows.remove(window) }
                        }
                    }
                ))
                .font(.subheadline)
                .tint(DS.accent)
            }
        }
    }

    private func loadSideQuestLifeContextInputs() {
        let profile = store.sideQuestLifeContextProfile
        lifeContextHomeLabel = profile.homeLabel ?? ""
        lifeContextWorkLabel = profile.workLabel ?? ""
        lifeContextHomeFloorLevel = profile.homePracticalContext.floorLevel.map(String.init) ?? ""
        lifeContextWorkplaceFloorLevel = profile.workplacePracticalContext.floorLevel.map(String.init) ?? ""
        lifeContextConstraints = profile.constraints
    }

    private func updateSideQuestLifeContext(_ update: @escaping (inout SideQuestLifeContextProfile) -> Void) {
        var profile = store.sideQuestLifeContextProfile
        update(&profile)
        Task { await store.saveSideQuestLifeContextProfile(profile) }
    }

    private func persistSideQuestLifeContextInputs() {
        var profile = store.sideQuestLifeContextProfile
        profile.homeLabel = SideQuestLifeContextProfile.normalized(lifeContextHomeLabel, maximumLength: 80)
        profile.workLabel = SideQuestLifeContextProfile.normalized(lifeContextWorkLabel, maximumLength: 80)
        profile.homePracticalContext.floorLevel = Int(lifeContextHomeFloorLevel)
        profile.workplacePracticalContext.floorLevel = Int(lifeContextWorkplaceFloorLevel)
        profile.constraints = lifeContextConstraints
        Task { await store.saveSideQuestLifeContextProfile(profile) }
    }

    private var advancedToolsLink: some View {
        NavigationLink {
            advancedToolsView
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DS.accent)
                    .frame(width: 36, height: 36)
                    .background(DS.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("高级工具")
                        .font(.headline)
                        .foregroundStyle(DS.ink)
                    Text("模型调用诊断、Prompt 评测与本地扩展")
                        .font(.footnote)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cardSurface()
        .accessibilityIdentifier(SettingsAutomationID.advancedToolsAction)
    }

    private var advancedToolsView: some View {
        ScrollView {
            VStack(spacing: DS.cardSpacing) {
                if AppStore.shouldUseVisualQASettingsAssetPackManifestFixture() {
                    assetPackInstallManifestCard
                }
                promptAuditCard
                promptEvalGateCard
                promptTemplateCard
                lensAssetPackCard
                promptAssetPackCard
                if !AppStore.shouldUseVisualQASettingsAssetPackManifestFixture() {
                    assetPackInstallManifestCard
                }
                SettingRow(title: "请求协议", value: store.currentModelProtocol.displayTitle)
            }
            .padding(.horizontal, DS.pagePadding)
            .padding(.top, DS.primaryScrollTopPadding)
            .padding(.bottom, DS.primaryScrollBottomReserve)
        }
        .scrollIndicators(.hidden)
        .background(DS.background.ignoresSafeArea())
        .navigationTitle("高级工具")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.loadRecentPromptRuns()
            await store.loadRecentPromptEvalRuns()
            await store.loadLensAssetPacks()
            await store.loadPromptAssetPacks()
            if AppStore.shouldUseVisualQASettingsAssetPackManifestFixture() {
                await store.loadAssetPackRegistrySubscriptions()
            }
        }
    }

    private var dataExportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "square.and.arrow.up")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DS.brick)
                    .frame(width: 36, height: 36)
                    .background(DS.brick.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text("数据导出")
                        .font(.headline)
                        .foregroundStyle(DS.ink)
                    Text("导出本机 SQLite 白名单数据为 JSON。会先等待当前草稿写入完成。")
                        .font(.footnote)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            if let export = store.preparedDataExport {
                Text(export.summary)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !store.dataExportMessage.isEmpty {
                Text(store.dataExportMessage)
                    .font(.footnote)
                    .foregroundStyle(store.dataExportMessage.contains("失败") || store.dataExportMessage.contains("不可用") ? DS.caution : DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Button {
                    prepareDataExport()
                } label: {
                    Label(isPreparingDataExport ? "准备中" : "生成导出文件", systemImage: isPreparingDataExport ? "hourglass" : "doc.badge.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.brick)
                .controlSize(.small)
                .disabled(isPreparingDataExport)

                if let export = store.preparedDataExport {
                    ShareLink(item: export.fileURL) {
                        Label("分享 JSON", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()
            }
            .font(.footnote.weight(.semibold))
        }
        .cardSurface()
    }

    private var lensAssetPackCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("透镜包")
                        .font(.headline)
                        .foregroundStyle(DS.ink)
                        .accessibilityIdentifier(SettingsAutomationID.lensPackCard)
                    Text("管理本机导入的角色卡和思维框架。")
                        .font(.footnote)
                        .foregroundStyle(DS.mutedInk)
                }
                Spacer()
                Button {
                    Task {
                        await store.loadLensAssetPacks()
                    }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(.footnote.weight(.semibold))
                .accessibilityIdentifier(SettingsAutomationID.lensPackRefreshAction)
            }

            if !store.lensAssetPackMessage.isEmpty {
                Text(store.lensAssetPackMessage)
                    .font(.footnote)
                    .foregroundStyle(store.lensAssetPackMessage.contains("失败") || store.lensAssetPackMessage.contains("不可用") ? DS.caution : DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if store.lensAssetPacks.isEmpty {
                Text("还没有本地透镜包。粘贴 JSON 后导入，会立即出现在 Today 的透镜选择里。")
                    .font(.footnote)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(store.lensAssetPacks, id: \.id) { pack in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Label(
                                    pack.displayName,
                                    systemImage: pack.isEnabled ? "checkmark.circle" : "pause.circle"
                                )
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(pack.isEnabled ? DS.ink : DS.mutedInk)

                                Spacer(minLength: 0)

                                Button {
                                    Task {
                                        await store.setLensAssetPack(pack.id, isEnabled: !pack.isEnabled)
                                    }
                                } label: {
                                    Label(pack.isEnabled ? "停用" : "启用", systemImage: pack.isEnabled ? "pause" : "play")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                .font(.caption.weight(.semibold))
                                .accessibilityIdentifier(SettingsAutomationID.lensPackToggleAction(packId: pack.id))
                            }

                            Text("\(pack.sourceKind.displayName) · v\(pack.version) · \(pack.items.count) 个透镜 · \(pack.id)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(DS.mutedInk)
                                .lineLimit(2)
                        }
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("导入 JSON")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)

                SettingsJSONTextView(
                    text: $lensPackJSONInput,
                    accessibilityIdentifier: SettingsAutomationID.lensPackImportField
                )
                    .frame(minHeight: 88)
                    .padding(6)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                HStack(spacing: 8) {
                    Button {
                        pasteLensPackJSON()
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier(SettingsAutomationID.lensPackPasteAction)

                    Button {
                        importLensPackJSON()
                    } label: {
                        Label("导入透镜包", systemImage: "tray.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.brick)
                    .controlSize(.small)
                    .disabled(lensPackJSONInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier(SettingsAutomationID.lensPackImportAction)

                    Spacer(minLength: 0)
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .cardSurface()
    }

    private var assetPackInstallManifestCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("资产包安装清单")
                        .font(.headline)
                        .foregroundStyle(DS.ink)
                        .accessibilityIdentifier(SettingsAutomationID.assetPackManifestCard)
                    Text("安装通过本地信任校验的 Prompt / 透镜包。")
                        .font(.footnote)
                        .foregroundStyle(DS.mutedInk)
                }

                Spacer(minLength: 0)
            }

            if !store.assetPackInstallMessage.isEmpty {
                Text(store.assetPackInstallMessage)
                    .font(.footnote)
                    .foregroundStyle(store.assetPackInstallMessage.contains("失败") || store.assetPackInstallMessage.contains("不可用") ? DS.caution : DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(SettingsAutomationID.assetPackManifestMessage)
            }

            if AppStore.shouldUseVisualQASettingsAssetPackManifestFixture() {
                VStack(alignment: .leading, spacing: 8) {
                    Text("远程目录 URL")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.ink)
                    Text("先获取目录，再选择其中的资产包条目安装。每个条目仍会走清单信任校验。")
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)

                    HStack(spacing: 8) {
                        SettingsTextField(
                            placeholder: "https://example.com/mingsi/asset-pack-catalog.json",
                            text: $assetPackRegistryCatalogURLInput,
                            keyboardType: .URL,
                            accessibilityIdentifier: SettingsAutomationID.assetPackRegistryCatalogURLField
                        )

                        Button {
                            fetchRemoteAssetPackRegistryCatalog()
                        } label: {
                            Label("获取目录", systemImage: "list.bullet.rectangle")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DS.accent)
                        .controlSize(.small)
                        .disabled(assetPackRegistryCatalogURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier(SettingsAutomationID.assetPackRegistryCatalogFetchAction)
                    }
                    .font(.footnote.weight(.semibold))
                }

                if !store.assetPackRegistryCatalogEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("远程目录条目")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.ink)

                        ForEach(store.assetPackRegistryCatalogEntries) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(entry.displayName)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(DS.ink)
                                        Text(entry.summary)
                                            .font(.caption)
                                            .foregroundStyle(DS.mutedInk)
                                            .lineLimit(2)
                                        if let publisherLine = assetPackRegistryCatalogPublisherLine(entry) {
                                            Text(publisherLine)
                                                .font(.caption2)
                                                .foregroundStyle(DS.mutedInk)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer(minLength: 0)

                                    Button {
                                        installAssetPackRegistryCatalogEntry(entry.id)
                                    } label: {
                                        Label("安装", systemImage: "arrow.down.circle")
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                    .font(.caption.weight(.semibold))
                                    .accessibilityIdentifier(SettingsAutomationID.assetPackRegistryCatalogEntryInstallAction(entryId: entry.id))
                                }

                                Text(entry.manifestURL.absoluteString)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(DS.mutedInk)
                                    .lineLimit(1)

                                if let trustPolicyLine = assetPackRegistryCatalogTrustPolicyLine(entry) {
                                    Text(trustPolicyLine)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(DS.mutedInk)
                                        .lineLimit(1)
                                }
                            }
                            .padding(10)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("目录订阅")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DS.ink)
                            Text("保存常用目录后，可统一同步并安装条目。")
                                .font(.caption)
                                .foregroundStyle(DS.mutedInk)
                        }

                        Spacer(minLength: 0)

                        Button {
                            syncAssetPackRegistrySubscriptions()
                        } label: {
                            Label("同步", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .font(.footnote.weight(.semibold))
                        .accessibilityIdentifier(SettingsAutomationID.assetPackRegistrySubscriptionSyncAction)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SettingsTextField(
                            placeholder: "MingSi Registry",
                            text: $assetPackRegistrySubscriptionNameInput,
                            accessibilityIdentifier: SettingsAutomationID.assetPackRegistrySubscriptionNameField
                        )

                        SettingsTextField(
                            placeholder: "https://example.com/mingsi/asset-pack-catalog.json",
                            text: $assetPackRegistrySubscriptionURLInput,
                            keyboardType: .URL,
                            accessibilityIdentifier: SettingsAutomationID.assetPackRegistrySubscriptionURLField
                        )

                        HStack(spacing: 8) {
                            Button {
                                saveAssetPackRegistrySubscription()
                            } label: {
                                Label("保存订阅", systemImage: "bookmark")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(DS.accent)
                            .controlSize(.small)
                            .disabled(
                                assetPackRegistrySubscriptionNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                    assetPackRegistrySubscriptionURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            )
                            .accessibilityIdentifier(SettingsAutomationID.assetPackRegistrySubscriptionSaveAction)

                            Spacer(minLength: 0)
                        }
                        .font(.footnote.weight(.semibold))
                    }

                    if store.assetPackRegistrySubscriptions.isEmpty {
                        Text("还没有保存的目录订阅。")
                            .font(.footnote)
                            .foregroundStyle(DS.mutedInk)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(store.assetPackRegistrySubscriptions) { subscription in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Label(
                                            subscription.displayName,
                                            systemImage: subscription.isEnabled ? "checkmark.circle" : "pause.circle"
                                        )
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(subscription.isEnabled ? DS.ink : DS.mutedInk)

                                        Spacer(minLength: 0)

                                        Button {
                                            toggleAssetPackRegistrySubscription(subscription)
                                        } label: {
                                            Label(subscription.isEnabled ? "停用" : "启用", systemImage: subscription.isEnabled ? "pause" : "play")
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)
                                        .font(.caption.weight(.semibold))
                                        .accessibilityIdentifier(SettingsAutomationID.assetPackRegistrySubscriptionToggleAction(subscriptionId: subscription.id))
                                    }

                                    Text(subscription.catalogURL.absoluteString)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(DS.mutedInk)
                                        .lineLimit(1)

                                    Text(assetPackRegistrySubscriptionStatusText(subscription))
                                        .font(.caption)
                                        .foregroundStyle(subscription.lastSyncStatus == .failed ? DS.caution : DS.mutedInk)
                                        .lineLimit(2)
                                }
                                .padding(10)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("远程清单 URL")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.ink)
                    Text("获取后仍会经过本地信任校验再安装。")
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)

                    HStack(spacing: 8) {
                        SettingsTextField(
                            placeholder: "https://example.com/mingsi/asset-pack-manifest.json",
                            text: $assetPackManifestRemoteURLInput,
                            keyboardType: .URL,
                            accessibilityIdentifier: SettingsAutomationID.assetPackManifestRemoteURLField
                        )

                        Button {
                            installRemoteAssetPackManifest()
                        } label: {
                            Label("获取安装", systemImage: "arrow.down.doc")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DS.accent)
                        .controlSize(.small)
                        .disabled(assetPackManifestRemoteURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier(SettingsAutomationID.assetPackManifestRemoteInstallAction)
                    }
                    .font(.footnote.weight(.semibold))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("清单 JSON")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)

                SettingsJSONTextView(
                    text: $assetPackManifestJSONInput,
                    accessibilityIdentifier: SettingsAutomationID.assetPackManifestImportField
                )
                    .frame(minHeight: 88)
                    .padding(6)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                HStack(spacing: 8) {
                    Button {
                        pasteAssetPackInstallManifestJSON()
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier(SettingsAutomationID.assetPackManifestPasteAction)

                    Button {
                        importAssetPackInstallManifestJSON()
                    } label: {
                        Label("安装清单", systemImage: "shippingbox.and.arrow.backward")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.brick)
                    .controlSize(.small)
                    .disabled(assetPackManifestJSONInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier(SettingsAutomationID.assetPackManifestInstallAction)

                    Spacer(minLength: 0)
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .cardSurface()
    }

    private var promptAssetPackCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prompt 包")
                        .font(.headline)
                        .foregroundStyle(DS.ink)
                        .accessibilityIdentifier(SettingsAutomationID.promptPackCard)
                    Text("管理本机导入的 Prompt 模板包。")
                        .font(.footnote)
                        .foregroundStyle(DS.mutedInk)
                }
                Spacer()
                Button {
                    Task {
                        await store.loadPromptAssetPacks()
                    }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(.footnote.weight(.semibold))
                .accessibilityIdentifier(SettingsAutomationID.promptPackRefreshAction)
            }

            if !store.promptAssetPackMessage.isEmpty {
                Text(store.promptAssetPackMessage)
                    .font(.footnote)
                    .foregroundStyle(store.promptAssetPackMessage.contains("失败") || store.promptAssetPackMessage.contains("不可用") ? DS.caution : DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if store.promptAssetPacks.isEmpty {
                Text("还没有本地 Prompt 包。粘贴 JSON 后导入，会立即参与当前 Prompt 模板选择。")
                    .font(.footnote)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(store.promptAssetPacks, id: \.id) { pack in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Label(
                                    pack.displayName,
                                    systemImage: pack.isEnabled ? "checkmark.circle" : "pause.circle"
                                )
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(pack.isEnabled ? DS.ink : DS.mutedInk)

                                Spacer(minLength: 0)

                                Button {
                                    Task {
                                        await store.setPromptAssetPack(pack.id, isEnabled: !pack.isEnabled)
                                    }
                                } label: {
                                    Label(pack.isEnabled ? "停用" : "启用", systemImage: pack.isEnabled ? "pause" : "play")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                .font(.caption.weight(.semibold))
                                .accessibilityIdentifier(SettingsAutomationID.promptPackToggleAction(packId: pack.id))
                            }

                            Text("\(pack.sourceKind.displayName) · v\(pack.version) · \(pack.templates.count) 个模板 · \(pack.id)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(DS.mutedInk)
                                .lineLimit(2)
                        }
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("导入 JSON")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)

                SettingsJSONTextView(
                    text: $promptPackJSONInput,
                    accessibilityIdentifier: SettingsAutomationID.promptPackImportField
                )
                    .frame(minHeight: 88)
                    .padding(6)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                HStack(spacing: 8) {
                    Button {
                        pastePromptPackJSON()
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier(SettingsAutomationID.promptPackPasteAction)

                    Button {
                        importPromptPackJSON()
                    } label: {
                        Label("导入 Prompt 包", systemImage: "tray.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.brick)
                    .controlSize(.small)
                    .disabled(promptPackJSONInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier(SettingsAutomationID.promptPackImportAction)

                    Spacer(minLength: 0)
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .cardSurface()
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
                            Text(mode.displayTitle).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 4) {
                        LabeledContent("模板名称", value: template.id.displayName)
                        LabeledContent("ID", value: template.id.rawValue)
                        LabeledContent("版本", value: template.version)
                        LabeledContent("输出 Schema 版本", value: "\(template.outputSchemaVersion)")
                        LabeledContent("模式", value: selectedSessionMode.displayTitle)
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

            Text("接口类型")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.ink)
            Menu {
                ForEach(GLMClientConfiguration.ProtocolKind.allCases, id: \.self) { kind in
                    Button(kind.displayTitle) {
                        store.selectModelProtocol(kind)
                        modelProtocol = store.currentModelProtocol
                        baseURLInput = store.currentBaseURL
                        modelNameInput = store.currentModelName
                        apiKeyInput = ""
                        clipboardMessage = ""
                    }
                }
            } label: {
                HStack(alignment: .center, spacing: 8) {
                    Text(modelProtocol.displayTitle)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down")
                        .accessibilityHidden(true)
                }
                .font(.body)
                .foregroundStyle(DS.accent)
                .frame(minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("接口类型，\(modelProtocol.displayTitle)")
            .accessibilityIdentifier("settings.model-protocol")
            Text("两种接口的 Key、地址和模型分别保存。切换后使用该接口已保存的配置。")
                .font(.caption)
                .foregroundStyle(DS.mutedInk)

            // API Key
            VStack(alignment: .leading, spacing: 6) {
                Text("API Key")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                HStack(spacing: 8) {
                    SettingsTextField(
                        placeholder: "输入服务商提供的 API Key",
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
                Text(modelProtocol == .responses ? "App 会自动拼接 /responses。" : "App 会自动拼接 /chat/completions。")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                HStack(spacing: 8) {
                    SettingsTextField(
                        placeholder: modelProtocol == .responses ? "https://ylscode.com/codex" : "https://open.bigmodel.cn/api/coding/paas/v4",
                        text: $baseURLInput,
                        accessibilityIdentifier: "settings.model-base-url"
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
                Text(modelProtocol == .responses ? "填写订阅配置中的模型名。" : "不填则使用默认模型。")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                SettingsTextField(
                    placeholder: modelProtocol == .responses ? "例如 gpt-6.1-sol" : "例如 glm-4.5-flash",
                    text: $modelNameInput,
                    accessibilityIdentifier: "settings.model-name"
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
                        .foregroundStyle(
                            store.settingsMessage.contains("失败") || store.settingsMessage.contains("不可用")
                                ? DS.caution
                                : DS.mutedInk
                        )
                        .fixedSize(horizontal: false, vertical: true)
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
                    Text(promptRunAuditStatsLine(summary: summary))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(DS.mutedInk)

                    if !store.promptAssetRunQualitySummaries.isEmpty {
                        PromptAssetQualitySummarySection(
                            summaries: Array(store.promptAssetRunQualitySummaries.prefix(3)),
                            gate: store.promptAssetQualityGate
                        )
                    }

                    if !store.coachPromptQualitySummaries.isEmpty {
                        CoachPromptQualitySummarySection(
                            summaries: Array(store.coachPromptQualitySummaries.prefix(5))
                        )
                    }

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

    private var promptEvalGateCard: some View {
        let gate = store.promptEvalReleaseGate

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prompt 固定评测")
                        .font(.headline)
                        .foregroundStyle(DS.ink)
                    Text("用本地固定 suite 校验当前 Prompt / Context / Schema / Eval 版本。")
                        .font(.footnote)
                        .foregroundStyle(DS.mutedInk)
                }
                Spacer()
                Button {
                    Task {
                        await store.runPromptEvalSuite()
                    }
                } label: {
                    Label("运行固定评测", systemImage: "checklist.checked")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(.footnote.weight(.semibold))
            }

            HStack(spacing: 8) {
                Label(
                    gate.status == .passed ? "可发布" : "阻塞",
                    systemImage: gate.status == .passed ? "checkmark.seal" : "exclamationmark.triangle"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(gate.status == .passed ? DS.success : DS.caution)

                Text("通过 \(gate.passedPromptCount)/\(gate.totalPromptCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DS.mutedInk)

                Spacer(minLength: 0)
            }

            Text("缺失 \(gate.missingPromptCount) · 过期 \(gate.stalePromptCount) · 失败 \(gate.failedPromptCount) · Runner \(gate.runnerMismatchCount)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(DS.mutedInk)

            if gate.status == .blocked {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("可回滚 \(gate.rollbackReadyCount) · 需人工处理 \(gate.manualReviewCount)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(gate.rollbackReadyCount > 0 ? DS.accent : DS.mutedInk)

                    Spacer(minLength: 0)

                    if let candidate = gate.rollbackCandidates.first {
                        Button {
                            Task {
                                await store.applyPromptRollback(candidate)
                            }
                        } label: {
                            Label("执行回滚", systemImage: "arrow.uturn.backward")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .font(.caption.weight(.semibold))
                    }
                }
            }

            if !store.promptEvalMessage.isEmpty {
                Text(store.promptEvalMessage)
                    .font(.footnote)
                    .foregroundStyle(gate.status == .passed ? DS.mutedInk : DS.caution)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !gate.blockingIssues.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(gate.blockingIssues.prefix(3)) { issue in
                        Text(issue.message)
                            .font(.caption)
                            .foregroundStyle(DS.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                        if let candidate = issue.rollbackCandidate {
                            Text("候选：\(candidate.currentVersion) → \(candidate.rollbackTargetVersion)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(DS.accent)
                        }
                    }
                }
            } else if !store.recentPromptEvalRuns.isEmpty {
                Text("最近评测 \(store.recentPromptEvalRuns.count) 条 · Runner \(PromptEvalRunner.currentRunnerVersion)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DS.mutedInk)
            }
        }
        .cardSurface()
    }

    private func promptRunAuditStatsLine(summary: PromptRunAuditSummary) -> String {
        guard let stats = store.promptRunStats, stats.totalCount > 0 else {
            return "最近 \(summary.totalCount) 次 · 失败 \(summary.failed.count) · 成功 \(summary.successful.count)"
        }

        return "最近 \(stats.totalCount) 次 · 失败率 \(Self.percent(stats.failureRate)) · 空结果率 \(Self.percent(stats.emptyResultRate)) · 用户否认率 \(Self.percent(stats.userDenialRate))"
    }

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
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

    private func prepareDataExport() {
        isPreparingDataExport = true
        Task {
            do {
                _ = try await store.prepareDataExport()
            } catch {
                store.dataExportMessage = "数据导出失败：\(error.localizedDescription)"
            }
            isPreparingDataExport = false
        }
    }

    private func pasteLensPackJSON() {
        guard let pastedText = currentClipboardString() else {
            store.lensAssetPackMessage = "剪贴板为空：请先复制透镜包 JSON。"
            return
        }
        lensPackJSONInput = pastedText
        store.lensAssetPackMessage = "已读取剪贴板，长度 \(pastedText.count) 个字符。"
    }

    private func importLensPackJSON() {
        let trimmed = lensPackJSONInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            store.lensAssetPackMessage = "导入透镜包失败：JSON 文本不是 UTF-8。"
            return
        }

        Task {
            do {
                _ = try await store.importLensAssetPack(from: data)
                lensPackJSONInput = ""
            } catch {
                if store.lensAssetPackMessage.isEmpty {
                    store.lensAssetPackMessage = "导入透镜包失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func pastePromptPackJSON() {
        guard let pastedText = currentClipboardString() else {
            store.promptAssetPackMessage = "剪贴板为空：请先复制 Prompt 包 JSON。"
            return
        }
        promptPackJSONInput = pastedText
        store.promptAssetPackMessage = "已读取剪贴板，长度 \(pastedText.count) 个字符。"
    }

    private func importPromptPackJSON() {
        let trimmed = promptPackJSONInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            store.promptAssetPackMessage = "导入 Prompt 包失败：JSON 文本不是 UTF-8。"
            return
        }

        Task {
            do {
                _ = try await store.importPromptAssetPack(from: data)
                promptPackJSONInput = ""
            } catch {
                if store.promptAssetPackMessage.isEmpty {
                    store.promptAssetPackMessage = "导入 Prompt 包失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func pasteAssetPackInstallManifestJSON() {
        guard let pastedText = currentClipboardString() else {
            store.assetPackInstallMessage = "剪贴板为空：请先复制资产包安装清单 JSON。"
            return
        }
        assetPackManifestJSONInput = pastedText
        store.assetPackInstallMessage = "已读取剪贴板，长度 \(pastedText.count) 个字符。"
    }

    private func importAssetPackInstallManifestJSON() {
        let trimmed = assetPackManifestJSONInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            store.assetPackInstallMessage = "安装资产包清单失败：JSON 文本不是 UTF-8。"
            return
        }

        Task {
            do {
                _ = try await store.importAssetPackInstallManifest(from: data)
                assetPackManifestJSONInput = ""
            } catch {
                if store.assetPackInstallMessage.isEmpty {
                    store.assetPackInstallMessage = "安装资产包清单失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func installRemoteAssetPackManifest() {
        let trimmed = assetPackManifestRemoteURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), !trimmed.isEmpty else {
            store.assetPackInstallMessage = "获取远程资产包清单失败：URL 格式不正确。"
            return
        }

        Task {
            do {
                _ = try await store.fetchAndInstallAssetPackInstallManifest(from: url)
            } catch {
                if store.assetPackInstallMessage.isEmpty {
                    store.assetPackInstallMessage = "获取远程资产包清单失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func assetPackRegistryCatalogPublisherLine(_ entry: AssetPackRegistryCatalogEntry) -> String? {
        var parts: [String] = []
        if let publisher = entry.publisherDisplayName ?? entry.publisherId {
            parts.append("发布方 \(publisher)")
        }
        if let requiredPolicy = entry.requiredVerificationPolicyVersion {
            parts.append("策略 \(requiredPolicy)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func assetPackRegistryCatalogTrustPolicyLine(_ entry: AssetPackRegistryCatalogEntry) -> String? {
        guard let trustPolicyURL = entry.trustPolicyURL else { return nil }
        return "信任策略 \(trustPolicyURL.relativeString)"
    }

    private func fetchRemoteAssetPackRegistryCatalog() {
        let trimmed = assetPackRegistryCatalogURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), !trimmed.isEmpty else {
            store.assetPackInstallMessage = "获取远程资产包目录失败：URL 格式不正确。"
            return
        }

        Task {
            do {
                _ = try await store.fetchAssetPackRegistryCatalog(from: url)
            } catch {
                if store.assetPackInstallMessage.isEmpty {
                    store.assetPackInstallMessage = "获取远程资产包目录失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func installAssetPackRegistryCatalogEntry(_ entryId: String) {
        Task {
            do {
                _ = try await store.installAssetPackRegistryCatalogEntry(entryId: entryId)
            } catch {
                if store.assetPackInstallMessage.isEmpty {
                    store.assetPackInstallMessage = "安装远程资产包条目失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func saveAssetPackRegistrySubscription() {
        let trimmedName = assetPackRegistrySubscriptionNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = assetPackRegistrySubscriptionURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURL), !trimmedURL.isEmpty else {
            store.assetPackInstallMessage = "保存资产包目录订阅失败：URL 格式不正确。"
            return
        }

        Task {
            do {
                _ = try await store.saveAssetPackRegistrySubscription(
                    displayName: trimmedName,
                    catalogURL: url
                )
                assetPackRegistrySubscriptionNameInput = ""
                assetPackRegistrySubscriptionURLInput = ""
            } catch {
                if store.assetPackInstallMessage.isEmpty {
                    store.assetPackInstallMessage = "保存资产包目录订阅失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func syncAssetPackRegistrySubscriptions() {
        Task {
            do {
                _ = try await store.syncAssetPackRegistrySubscriptions()
            } catch {
                if store.assetPackInstallMessage.isEmpty {
                    store.assetPackInstallMessage = "同步资产包目录订阅失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func toggleAssetPackRegistrySubscription(_ subscription: AssetPackRegistrySubscription) {
        Task {
            await store.setAssetPackRegistrySubscription(subscription.id, isEnabled: !subscription.isEnabled)
        }
    }

    private func assetPackRegistrySubscriptionStatusText(_ subscription: AssetPackRegistrySubscription) -> String {
        let statusText: String
        switch subscription.lastSyncStatus {
        case .neverSynced:
            statusText = "未同步"
        case .succeeded:
            statusText = "上次同步成功"
        case .failed:
            statusText = "上次同步失败"
        }

        if subscription.lastSyncMessage.isEmpty {
            return statusText
        }
        return "\(statusText)：\(subscription.lastSyncMessage)"
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

private extension LensAssetSourceKind {
    var displayName: String {
        switch self {
        case .builtin:
            return "内置"
        case .localCustom:
            return "本地自定义"
        case .imported:
            return "已导入"
        case .marketplace:
            return "Marketplace"
        }
    }
}

private extension PromptAssetSourceKind {
    var displayName: String {
        switch self {
        case .builtin:
            return "内置"
        case .localCustom:
            return "本地自定义"
        case .imported:
            return "已导入"
        case .marketplace:
            return "Marketplace"
        }
    }
}

private struct SettingsJSONTextView: UIViewRepresentable {
    @Binding var text: String
    let accessibilityIdentifier: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.adjustsFontForContentSizeCategory = true
        textView.textColor = UIColor.label
        textView.tintColor = UIColor(DS.accent)
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.keyboardType = .asciiCapable
        textView.returnKeyType = .default
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
        textView.textContainer.lineFragmentPadding = 0
        textView.accessibilityIdentifier = accessibilityIdentifier
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.accessibilityIdentifier != accessibilityIdentifier {
            textView.accessibilityIdentifier = accessibilityIdentifier
        }
        if textView.markedTextRange == nil && textView.text != text {
            textView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            guard textView.markedTextRange == nil else { return }
            text = textView.text
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.markedTextRange == nil {
                text = textView.text
            }
        }
    }
}

private struct SettingsTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .asciiCapable
    var accessibilityIdentifier: String?

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
        textField.keyboardType = keyboardType
        textField.returnKeyType = .done
        textField.clearButtonMode = .whileEditing
        textField.font = UIFont.preferredFont(forTextStyle: .subheadline)
        textField.adjustsFontForContentSizeCategory = true
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.accessibilityIdentifier = accessibilityIdentifier
        applyStyle(to: textField)
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        applyStyle(to: textField)
        if textField.keyboardType != keyboardType {
            textField.keyboardType = keyboardType
        }
        if textField.accessibilityIdentifier != accessibilityIdentifier {
            textField.accessibilityIdentifier = accessibilityIdentifier
        }
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
        ZStack {
            DS.background.ignoresSafeArea()
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.sectionSpacing) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.system(.largeTitle, design: .rounded).weight(.bold))
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
        }
        .topSafeAreaScrim()
    }
}

struct ResumeTodayRow: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.uturn.left")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(DS.accent)
                .frame(width: 34, height: 34)
                .background(DS.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))

            Text(store.loopResumeText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)

            Spacer(minLength: 4)

            Button {
                store.selectedTab = .today
            } label: {
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
                    .background(DS.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(DS.accent)
            .accessibilityLabel("回到今日继续复盘")

            Button {
                store.isResumeBannerDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DS.mutedInk)
            .accessibilityLabel("暂时隐藏继续今日")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(DS.accent.opacity(0.14), lineWidth: 1)
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
                                .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
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
                                .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
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
                    ForEach(Array(Calendar.current.veryShortWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
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
    var trainingSummary: PrincipleTrainingSummary?
    var compact = false
    var isHighlighted: Bool = false
    var onSaveProject: (() -> Void)?
    var onRepair: (() -> Void)?
    var onArchive: (() -> Void)?
    var onDisputeLatestPracticeEvidence: (() -> Void)?
    var onDelete: (() -> Void)?
    @State private var isCompactDetailExpanded = false

    var body: some View {
        Group {
            if compact {
                compactContent
            } else {
                detailedContent
            }
        }
    }

    private var detailedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(trainingSummary?.state.title ?? "原则")
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
            if let trainingSummary {
                HStack(spacing: 8) {
                    ProjectTinyChip(text: "实践 \(trainingSummary.practiceEvidenceCount)", systemImage: "checkmark.circle")
                    ProjectTinyChip(text: "负反馈 \(trainingSummary.negativeRecallFeedbackCount)", systemImage: "exclamationmark.triangle")
                }
                if let notice = trainingSummary.unassessedPracticeNotice {
                    Text(notice)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .accessibilityIdentifier("growth.principle.\(principle.id.uuidString).unassessed-practice")
                }
                if let latestSummary = trainingSummary.latestPracticeEvidenceSummary,
                   !latestSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if let role = trainingSummary.latestPracticeEvidenceRole {
                        ProjectTinyChip(text: role.title, systemImage: "scope")
                    }
                    Text("最近证据：\(latestSummary)")
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .lineLimit(2)
                    if let evidenceId = trainingSummary.latestPracticeEvidenceId,
                       let onDisputeLatestPracticeEvidence {
                        Button(action: onDisputeLatestPracticeEvidence) {
                            Label("归因不准确", systemImage: "xmark.octagon")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(DS.caution)
                        .accessibilityIdentifier(
                            GrowthAutomationID.disputeLatestPracticeEvidenceAction(
                                evidenceId: evidenceId.uuidString
                            )
                        )
                    }
                }
                if let disputedEvidenceId = trainingSummary.latestDisputedPracticeEvidenceId,
                   let disputedSummary = trainingSummary.latestDisputedPracticeEvidenceSummary,
                   !disputedSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(disputedPracticeEvidenceAuditText(
                        summary: disputedSummary,
                        note: trainingSummary.latestDisputedPracticeEvidenceNote
                    ))
                    .font(.caption)
                    .foregroundStyle(DS.caution)
                    .lineLimit(3)
                    .accessibilityIdentifier(
                        GrowthAutomationID.disputedPracticeEvidenceAudit(
                            evidenceId: disputedEvidenceId.uuidString
                        )
                    )
                }
                if let feedbackId = trainingSummary.latestNegativeRecallFeedbackId,
                   let feedbackValue = trainingSummary.latestNegativeRecallFeedbackValue,
                   let feedbackReason = trainingSummary.latestNegativeRecallFeedbackReason,
                   !feedbackReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(negativeRecallFeedbackAuditText(
                        value: feedbackValue,
                        signal: trainingSummary.latestNegativeRecallFeedbackSignal,
                        reason: feedbackReason,
                        note: trainingSummary.latestNegativeRecallFeedbackNote
                    ))
                    .font(.caption)
                    .foregroundStyle(DS.caution)
                    .lineLimit(3)
                    .accessibilityIdentifier(
                        GrowthAutomationID.negativeRecallFeedbackAudit(
                            feedbackId: feedbackId.uuidString
                        )
                    )
                }
            }
            if let onSaveProject {
                Button(action: onSaveProject) {
                    Label("保存为长期议题", systemImage: "plus.circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.accent)
            }
            if let onRepair {
                Button(action: onRepair) {
                    Label("复审并启用", systemImage: "checkmark.seal")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.accent)
            }
            if let onArchive {
                Button(action: onArchive) {
                    Label("归档", systemImage: "archivebox")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.caution)
            }
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.caution)
            }
        }
        .evidenceSurface(isHighlighted: isHighlighted, base: .principle)
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isCompactDetailExpanded.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle()
                        .fill(trainingStateTint)
                        .frame(width: 8, height: 8)
                    Text(principle.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.ink)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(trainingSummary?.state.title ?? "原则")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(trainingStateTint)
                    Image(systemName: isCompactDetailExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(DS.mutedInk)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(GrowthAutomationID.principleDetailsToggle(principleId: principle.id.uuidString))

            Text(principle.summary)
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .lineLimit(1)

            if let trainingSummary {
                HStack(spacing: 12) {
                    Label("\(trainingSummary.practiceEvidenceCount)", systemImage: "checkmark.circle")
                    Label("\(trainingSummary.negativeRecallFeedbackCount)", systemImage: "exclamationmark.triangle")
                    if let role = trainingSummary.latestPracticeEvidenceRole {
                        Label(role.title, systemImage: "scope")
                    }
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(DS.mutedInk)

                if isCompactDetailExpanded, let notice = trainingSummary.unassessedPracticeNotice {
                    Text(notice)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .accessibilityIdentifier("growth.principle.\(principle.id.uuidString).unassessed-practice")
                }
                if isCompactDetailExpanded,
                   let latestSummary = trainingSummary.latestPracticeEvidenceSummary,
                   !latestSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("最近证据：\(latestSummary)")
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                    if let evidenceId = trainingSummary.latestPracticeEvidenceId,
                       let onDisputeLatestPracticeEvidence {
                        Button(action: onDisputeLatestPracticeEvidence) {
                            Label("归因不准确", systemImage: "xmark.octagon")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(DS.caution)
                        .accessibilityIdentifier(
                            GrowthAutomationID.disputeLatestPracticeEvidenceAction(
                                evidenceId: evidenceId.uuidString
                            )
                        )
                    }
                }
                if isCompactDetailExpanded,
                   let disputedEvidenceId = trainingSummary.latestDisputedPracticeEvidenceId,
                   let disputedSummary = trainingSummary.latestDisputedPracticeEvidenceSummary,
                   !disputedSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(disputedPracticeEvidenceAuditText(
                        summary: disputedSummary,
                        note: trainingSummary.latestDisputedPracticeEvidenceNote
                    ))
                    .font(.caption)
                    .foregroundStyle(DS.caution)
                    .lineLimit(2)
                    .accessibilityIdentifier(
                        GrowthAutomationID.disputedPracticeEvidenceAudit(
                            evidenceId: disputedEvidenceId.uuidString
                        )
                    )
                }
                if isCompactDetailExpanded,
                   let feedbackId = trainingSummary.latestNegativeRecallFeedbackId,
                   let feedbackValue = trainingSummary.latestNegativeRecallFeedbackValue,
                   let feedbackReason = trainingSummary.latestNegativeRecallFeedbackReason,
                   !feedbackReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(negativeRecallFeedbackAuditText(
                        value: feedbackValue,
                        signal: trainingSummary.latestNegativeRecallFeedbackSignal,
                        reason: feedbackReason,
                        note: trainingSummary.latestNegativeRecallFeedbackNote
                    ))
                    .font(.caption)
                    .foregroundStyle(DS.caution)
                    .lineLimit(2)
                    .accessibilityIdentifier(
                        GrowthAutomationID.negativeRecallFeedbackAudit(
                            feedbackId: feedbackId.uuidString
                        )
                    )
                }
            }

            if isCompactDetailExpanded {
                HStack(spacing: 14) {
                    if let onRepair {
                        Button("复审", action: onRepair)
                            .foregroundStyle(DS.accent)
                    }
                    if let onArchive {
                        Button("归档", action: onArchive)
                            .foregroundStyle(DS.caution)
                    }
                    if let onDelete {
                        Button("删除", role: .destructive, action: onDelete)
                    }
                    if let onSaveProject {
                        Button("保存为议题", action: onSaveProject)
                            .foregroundStyle(DS.accent)
                    }
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DS.hairline)
                .frame(height: 1)
        }
        .background(isHighlighted ? DS.note.opacity(0.08) : Color.clear)
    }

    private var trainingStateTint: Color {
        switch trainingSummary?.state {
        case .consciouslyPracticed, .stablyInternalized:
            return DS.success
        case .needsReview:
            return DS.caution
        case .knownButUnused, .none:
            return DS.mutedInk
        }
    }

    private func disputedPracticeEvidenceAuditText(summary: String, note: String?) -> String {
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedNote.isEmpty else {
            return "已否认归因：\(summary)"
        }
        return "已否认归因：\(summary) 原因：\(trimmedNote)"
    }

    private func negativeRecallFeedbackAuditText(
        value: PrincipleRecallFeedbackValue,
        signal: String?,
        reason: String,
        note: String?
    ) -> String {
        let signalText = signal.flatMap(PrincipleRetrievalSignalDisplay.displayText(for:))
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let signalSegment = signalText.map { " · 命中信号：\($0)" } ?? ""
        guard !trimmedNote.isEmpty else {
            return "复审依据：\(value.displayTitle)\(signalSegment) · \(reason)"
        }
        return "复审依据：\(value.displayTitle)\(signalSegment) · \(reason) 备注：\(trimmedNote)"
    }
}

private struct ProjectDetailDirectEntryTarget: Hashable {
    let projectID: UUID
}

struct ProjectEvidenceBoardItem: Identifiable {
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

func projectStatusFilteredItems(
    _ items: [ProjectEvidenceBoardItem],
    projectsById: [UUID: Project],
    status: ProjectStatus?
) -> [ProjectEvidenceBoardItem] {
    guard let status else { return items }
    return items.filter { item in
        guard let project = projectsById[item.id] else { return false }
        return project.status == status
    }
}

func projectBoardCountText(filteredCount: Int, totalCount: Int, filterStatus: ProjectStatus?) -> String {
    if let filterStatus {
        return "\(filteredCount) / \(totalCount) 个\(filterStatus.chineseTitle)项目"
    }
    return totalCount == 0 ? "0 个证据项目" : "\(totalCount) 个证据项目"
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
    let title: String?
    let detail: String?
    let canCreateProject: Bool
    let createProject: () -> Void
    let goToToday: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "tray")
                .font(.caption.weight(.bold))
                .foregroundStyle(DS.accent)
                .frame(width: 28, height: 28)
                .background(DS.accent.opacity(0.08), in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text("尚无长期议题")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                if let title, let detail {
                    Text("当前可沉淀：\(title)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.accentInk)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .lineLimit(2)
                } else {
                    Text("完成复盘后，可从已有证据确认一个长期议题。")
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if canCreateProject {
                    Button(action: createProject) {
                        Label("保存为长期议题", systemImage: "plus.circle")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(DS.accent)
                    .padding(.top, 2)
                } else {
                    Button(action: goToToday) {
                        Label("去今日记录", systemImage: "square.and.pencil")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(DS.accent)
                    .padding(.top, 2)
                    .accessibilityIdentifier(ProjectsAutomationID.emptyStateTodayAction)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .summarySurface()
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
                            Text("下一步验证")
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
    @State private var isClosurePresented = false
    @State private var isProjectContextExpanded = false
    @State private var isProgressSignalsExpanded = false
    @State private var isEvidenceTimelineExpanded = false
    @State private var isProjectInsightExpanded = false
    @State private var isThinkingChangeExpanded = false

    private var digest: ProjectEvidenceDigest {
        item.digest
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                detailHeader
                projectFocusSection
                projectClosureSection
                evidenceTimeline
                projectContextSection
                projectInsightSection
                thinkingChangeSection
                principlesSection
                mergeAuditSection
            }
            .padding(.horizontal, DS.pagePadding)
            .padding(.top, 18)
            .padding(.bottom, DS.primaryScrollBottomReserve)
        }
        .background(DS.background.ignoresSafeArea())
        .navigationTitle("长期议题")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let currentProject {
                    HStack(spacing: 12) {
                        if currentProject.status == .archived {
                            Button {
                                Task { await store.restoreProject(currentProject.id) }
                            } label: {
                                Image(systemName: "arrow.uturn.backward.circle")
                            }
                            .accessibilityLabel("恢复项目")
                        } else {
                            Button {
                                isClosurePresented = true
                            } label: {
                                Image(systemName: "stop.circle")
                            }
                            .accessibilityLabel("结束项目")
                        }
                        Button {
                            isEditorPresented = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .accessibilityLabel("编辑项目")
                    }
                }
            }
        }
        .sheet(isPresented: $isEditorPresented) {
            if let currentProject {
                ProjectEditorSheet(project: currentProject)
                    .environmentObject(store)
            }
        }
        .sheet(isPresented: $isClosurePresented) {
            if let currentProject {
                ProjectClosureSheet(project: currentProject)
                    .environmentObject(store)
            }
        }
        .task(id: item.id) {
            await store.loadProjectInsights(for: item.id)
        }
    }

    private var currentProject: Project? {
        store.projectsById[item.id] ?? project
    }

    @ViewBuilder
    private var projectClosureSection: some View {
        if let review = store.projectClosureReviews[item.id] {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel("结束复盘")
                    Spacer()
                    Text(review.reason.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                }
                Text(review.outcome)
                    .font(.subheadline)
                    .foregroundStyle(DS.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let note = review.reviewNote, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Divider()
                HStack {
                    Text("结束总结")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                    Spacer()
                    Button {
                        Task { await store.generateProjectClosureSummary(for: review.projectId) }
                    } label: {
                        Image(systemName: "sparkle.magnifyingglass")
                            .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DS.accent)
                    .accessibilityLabel("生成项目结束总结")
                    .disabled(store.isGeneratingProjectClosureSummary)
                }
                if store.isGeneratingProjectClosureSummary {
                    ProgressView()
                        .controlSize(.small)
                } else if !store.projectClosureSummaryMessage.isEmpty {
                    Text(store.projectClosureSummaryMessage)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let summary = review.aiSummary, !summary.isEmpty {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(DS.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(review.principleCandidates) { candidate in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(candidate.title)
                            .font(.subheadline.weight(.semibold))
                        Text(candidate.summary)
                            .font(.caption)
                            .foregroundStyle(DS.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("依据 \(candidate.evidenceRefs.count) 条确认证据")
                            .font(.caption2)
                            .foregroundStyle(DS.mutedInk)
                        Button("确认原则") {
                            Task { await store.acceptProjectClosurePrinciple(candidate.id, projectId: review.projectId) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.top, 4)
                }
            }
            .projectDetailSurface()
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
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        ProjectTinyChip(text: projectDetailStatusChipText(for: project?.status), systemImage: "circle.dashed")
                        ProjectTinyChip(text: "\(item.evidenceCount) 条证据", systemImage: "number")
                        ProjectTinyChip(text: item.latestDate.mingsiShortDate, systemImage: "calendar")
                    }
                }
            }
        }
    }

    private var projectFocusSection: some View {
        let bottleneck = projectOverviewDisplayValue(project?.currentBottleneck)
        let nextBet = projectOverviewDisplayValue(digest.nextBet)
        let evidenceGap = projectOverviewDisplayValue(digest.evidenceGapMessage)
        let latestEvidence = item.sortedEntries.first

        return VStack(alignment: .leading, spacing: 12) {
            Text("当前路径")
                .font(.caption.weight(.bold))
                .foregroundStyle(DS.mutedInk)

            if let bottleneck {
                ProjectDetailFactLine(title: "当前阻碍", value: bottleneck, tint: DS.caution)
            }
            if let nextBet {
                ProjectDetailFactLine(title: "下一次验证", value: nextBet, tint: DS.accent)
            } else if let evidenceGap {
                ProjectDetailFactLine(title: "下一步", value: evidenceGap, tint: DS.caution)
            }

            if bottleneck == nil && nextBet == nil && evidenceGap == nil {
                Text("还没有足够证据判断阻碍或下一次验证。继续从历史记录中补充事实与行动结果。")
                    .font(.subheadline)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let latestEvidence {
                Button {
                    store.navigateToHistoryDeepLink(
                        HistoryDeepLink(
                            dailyEntryId: latestEvidence.record.draft.id,
                            sourceId: latestEvidence.link.sourceId,
                            sourceType: nil
                        )
                    )
                } label: {
                    Label("最新：\(projectEvidenceDisplayTitle(link: latestEvidence.link, record: latestEvidence.record))", systemImage: "arrow.up.right.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.accentInk)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看最新项目证据")
            }
        }
    }

    private var projectContextSection: some View {
        let factLines = projectContextFactLines(
            goal: project?.goal,
            successCriteria: project?.successCriteria,
            openQuestions: project?.openQuestions
        )
        if !factLines.isEmpty {
            return AnyView(
                DisclosureGroup(isExpanded: $isProjectContextExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(factLines, id: \.title) { line in
                            ProjectDetailFactLine(title: line.title, value: line.value)
                        }
                    }
                    .padding(.top, 10)
                } label: {
                    HStack {
                        SectionLabel("项目背景")
                        Spacer()
                        Text(isProjectContextExpanded ? "收起" : "查看目标与标准")
                            .font(.caption)
                            .foregroundStyle(DS.mutedInk)
                    }
                }
                .tint(DS.accent)
                .projectDetailSurface()
            )
        }
        return AnyView(EmptyView())
    }

    @ViewBuilder
    private var mergeAuditSection: some View {
        if let project, let lines = mergeAuditDisplayLinesIfNonEmpty(from: project.mergeHistory) {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("合并审计")
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .projectDetailSurface()
        }
    }

    private var projectInsightSection: some View {
        let accepted = store.acceptedProjectInsights.filter { $0.projectId == item.id }
        let pending = store.pendingProjectInsights.filter { $0.projectId == item.id }

        return DisclosureGroup(isExpanded: $isProjectInsightExpanded) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    Text("只从已确认历史证据生成，确认后才进入项目叙事。")
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Button {
                        Task { await store.generateProjectInsights(for: item.id) }
                    } label: {
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.caption.weight(.semibold))
                            .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DS.accent)
                    .accessibilityLabel(store.isGeneratingProjectInsights ? "正在生成项目洞察" : "生成项目洞察")
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
            .padding(.top, 8)
        } label: {
            HStack(spacing: 8) {
                SectionLabel("项目洞察")
                Text(projectInsightSummary(acceptedCount: accepted.count, pendingCount: pending.count))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DS.mutedInk)
            }
        }
        .tint(DS.accent)
    }

    @ViewBuilder
    private var progressSignalsSection: some View {
        let totalCount = digest.progressSignals.count
        let visibleCount = projectDetailTimelineVisibleCount(
            totalCount: totalCount,
            isExpanded: isProgressSignalsExpanded,
            collapsedLimit: 2
        )
        if totalCount > 0 {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("进展信号")
                ForEach(Array(digest.progressSignals.prefix(visibleCount))) { signal in
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
                if let toggleTitle = projectDetailProgressSignalsToggleTitle(
                    totalCount: totalCount,
                    isExpanded: isProgressSignalsExpanded,
                    collapsedLimit: 2
                ) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isProgressSignalsExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(toggleTitle)
                                .font(.caption.weight(.semibold))
                            Image(systemName: isProgressSignalsExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(DS.accent)
                        .padding(.top, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .projectDetailSurface()
        }
    }

    @ViewBuilder
    private var thinkingChangeSection: some View {
        let acceptedInsightCount = store.acceptedProjectInsights.filter { $0.projectId == item.id }.count
        if shouldShowProjectDetailThinkingChange(
            hasBeforeAfterEvidence: digest.hasBeforeAfterEvidence,
            acceptedInsightCount: acceptedInsightCount
        ) {
            DisclosureGroup(isExpanded: $isThinkingChangeExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(projectThinkingChangeHeadline(
                        hasBeforeAfterEvidence: digest.hasBeforeAfterEvidence,
                        acceptedInsightCount: acceptedInsightCount
                    ))
                        .font(.headline)
                        .foregroundStyle(DS.ink)
                    Text(projectThinkingChangeBody(
                        hasBeforeAfterEvidence: digest.hasBeforeAfterEvidence,
                        acceptedInsightCount: acceptedInsightCount
                    ))
                        .font(.subheadline)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 8)
            } label: {
                HStack(spacing: 8) {
                    SectionLabel("思考变化")
                    Text(acceptedInsightCount > 0 ? "已有确认" : "等待确认")
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                }
            }
            .tint(DS.accent)
        }
    }

    @ViewBuilder
    private var principlesSection: some View {
        let entries = projectPrincipleEvidenceEntries(from: item)
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("原则资产")
                Text("只展示已链接到历史原则资产的证据。")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(entries, id: \.link.id) { entry in
                    Button {
                        store.navigateToHistoryDeepLink(
                            HistoryDeepLink(
                                dailyEntryId: entry.record.draft.id,
                                sourceId: entry.link.sourceId,
                                sourceType: nil
                            )
                        )
                    } label: {
                        ProjectPrincipleEvidenceRow(link: entry.link, record: entry.record)
                    }
                    .buttonStyle(.plain)
                }
            }
            .projectDetailSurface()
        }
    }

    @ViewBuilder
    private var evidenceTimeline: some View {
        let totalCount = item.sortedEntries.count
        let visibleCount = projectDetailTimelineVisibleCount(
            totalCount: totalCount,
            isExpanded: isEvidenceTimelineExpanded
        )
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("证据时间线")
            ForEach(Array(item.sortedEntries.prefix(visibleCount)), id: \.link.id) { entry in
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
            if let toggleTitle = projectDetailTimelineToggleTitle(
                totalCount: totalCount,
                isExpanded: isEvidenceTimelineExpanded
            ) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isEvidenceTimelineExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(toggleTitle)
                            .font(.caption.weight(.semibold))
                        Image(systemName: isEvidenceTimelineExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(DS.accent)
                    .padding(.top, 2)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private extension View {
    func projectDetailSurface() -> some View {
        padding(DS.cardInnerPadding)
            .background(DS.cardBackground, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                    .stroke(DS.hairline, lineWidth: 1)
            )
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
        .padding(.vertical, 4)
    }
}

private struct ProjectClosureSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let project: Project

    @State private var reason: ProjectClosureReason = .achieved
    @State private var outcome = ""
    @State private var transferredItems = ""
    @State private var reviewNote = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("结束原因") {
                    Picker("", selection: $reason) {
                        ForEach(ProjectClosureReason.allCases) { reason in
                            Text(reason.title).tag(reason)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel("结束原因")
                    .pickerStyle(.inline)
                }

                Section("实际结果") {
                    PushToTalkInput(
                        text: $outcome,
                        placeholder: "项目最终产生了什么结果？",
                        accessibilityIdentifier: "project.close.outcome",
                        usesTextEditor: true
                    )
                }

                Section("可选补充") {
                    PushToTalkInput(
                        text: $transferredItems,
                        placeholder: "未完成事项如何处理",
                        accessibilityIdentifier: "project.close.transferred-items",
                        usesTextEditor: true
                    )
                    PushToTalkInput(
                        text: $reviewNote,
                        placeholder: "补充复盘",
                        accessibilityIdentifier: "project.close.review-note",
                        usesTextEditor: true
                    )
                }
            }
            .scrollContentBackground(.hidden)
            .background(DS.background.ignoresSafeArea())
            .navigationTitle("结束项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("结束") {
                        isSaving = true
                        Task {
                            let didClose = await store.closeProject(
                                project.id,
                                reason: reason,
                                outcome: outcome,
                                transferredItems: transferredItems,
                                reviewNote: reviewNote
                            )
                            isSaving = false
                            if didClose { dismiss() }
                        }
                    }
                    .disabled(isSaving || outcome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
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
                    PushToTalkInput(text: $name, placeholder: "名称", accessibilityIdentifier: "project.edit.name")
                    PushToTalkInput(text: $goal, placeholder: "目标", accessibilityIdentifier: "project.edit.goal", usesTextEditor: true)
                    PushToTalkInput(text: $successCriteria, placeholder: "成功标准", accessibilityIdentifier: "project.edit.success-criteria", usesTextEditor: true)
                    PushToTalkInput(text: $currentBottleneck, placeholder: "当前阻塞", accessibilityIdentifier: "project.edit.current-bottleneck", usesTextEditor: true)
                }

                Section {
                    PushToTalkInput(
                        text: $openQuestionsText,
                        placeholder: "每行一个问题",
                        accessibilityIdentifier: "project.edit.open-questions",
                        usesTextEditor: true
                    )
                } header: {
                    Text("开放问题")
                } footer: {
                    Text("编辑只更新项目元信息，不会删除历史证据或项目链接。")
                }

                Section("状态") {
                    HStack {
                        Text("当前状态")
                        Spacer()
                        Text(project.status == .archived ? "已结束" : project.status.title)
                            .foregroundStyle(DS.mutedInk)
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
    var tint: Color = DS.mutedInk

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
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
                        .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
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
                Text(projectEvidenceDisplayTitle(link: link, record: record))
                    .font(.subheadline)
                    .foregroundStyle(DS.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
    }

}

func projectEvidenceDisplayTitle(link: ProjectLink, record: HistoryRecord) -> String {
    switch link.sourceType {
    case .dailyEntry:
        return record.draft.rawText.isEmpty ? "当日复盘记录" : record.draft.rawText
    case .trainingCase:
        return record.caseRecords.first { $0.id.uuidString == link.sourceId }?.trainingCase.title ?? "事项"
    case .thinkingCard:
        return record.cards.first { $0.id.uuidString == link.sourceId }?.title ?? "思考卡片"
    case .quest:
        return record.quests.first { $0.id.uuidString == link.sourceId }?.title ?? "明日验证"
    case .verification:
        return record.allVerifications.first { $0.id.uuidString == link.sourceId }?.calibrationNote ?? "结果校准"
    case .principle:
        return record.principles.first { $0.id.uuidString == link.sourceId }?.title ?? "原则资产"
    }
}

func projectInsightSummary(acceptedCount: Int, pendingCount: Int) -> String {
    switch (acceptedCount, pendingCount) {
    case (0, 0):
        return "尚无叙事"
    case (_, 0):
        return "已确认 \(acceptedCount)"
    case (0, _):
        return "待判断 \(pendingCount)"
    default:
        return "已确认 \(acceptedCount) · 待判断 \(pendingCount)"
    }
}

private struct ProjectPrincipleEvidenceRow: View {
    let link: ProjectLink
    let record: HistoryRecord

    private var principle: PrincipleAsset? {
        record.principles.first { $0.id.uuidString == link.sourceId }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "seal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.note)
                .frame(width: 24, height: 24)
                .background(DS.note.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("原则")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.note)
                    Text(record.draft.date.mingsiShortDate)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(DS.mutedInk)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(DS.mutedInk.opacity(0.7))
                }

                Text(principle?.title ?? "原则资产")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let summary = projectOverviewDisplayValue(principle?.summary) {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(10)
        .background(DS.background.opacity(0.55), in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
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
        case .archived: return "已结束"
        }
    }

    var chineseTitle: String {
        switch self {
        case .active: return "活跃"
        case .watching: return "关注中"
        case .paused: return "暂停"
        case .archived: return "已结束"
        }
    }

    var tint: Color {
        switch self {
        case .active: return DS.accent
        case .watching: return DS.note
        case .paused: return DS.caution
        case .archived: return DS.mutedInk
        }
    }
}

private extension ProjectSourceType {
    var title: String {
        switch self {
        case .dailyEntry: return "日记"
        case .trainingCase: return "事项"
        case .thinkingCard: return "卡片"
        case .quest: return "任务"
        case .verification: return "验证"
        case .principle: return "原则"
        }
    }
}

private struct GrowthEvidenceProgressPanel: View {
    let snapshot: MetricSnapshot
    let completedRecordCount: Int
    let onContinue: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.title3)
                .foregroundStyle(DS.mutedInk)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text("成长依据待确认")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                Text(growthEvidenceProgressText(completeLoopCount: completedRecordCount))
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("growth.record-progress")
                Text(snapshot.summary)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("growth.evidence-status")
                Button(action: onContinue) {
                    Label("回到今日", systemImage: "arrow.right")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(DS.accent)
                .frame(minHeight: 44)
                .accessibilityIdentifier("growth.record-progress.continue")
            }
        }
        .padding(.vertical, 4)
    }
}

private struct GrowthSummaryPanel: View {
    let snapshot: MetricSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("周期概览")
                Spacer()
                Text(snapshot.period.uppercased())
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
            }
            Text(snapshot.summary)
                .font(.title3.weight(.semibold))
                .foregroundStyle(DS.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
        .accessibilityIdentifier("growth.summary")
    }
}

private struct GrowthReflectionTopicsPanel: View {
    let summary: ReflectionTopicSummary
    let onSelectSource: (ReflectionTopicSource) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("复盘中讨论过")
            if summary.topics.isEmpty {
                Text("当前记录中还没有可按主题对照的已回答问题。你仍可以在历史中回看原文。")
                    .font(.subheadline)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("按已回答问题的标签归类，方便对照当时的回答；不代表相同原因或能力短板。")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(summary.topics) { topic in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(topic.sources) { source in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(source.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundStyle(DS.mutedInk)
                                    if !source.title.isEmpty {
                                        Text(source.title)
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    Text("当时的问题")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(DS.mutedInk)
                                    Text(source.question.question)
                                        .font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("你的回答")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(DS.mutedInk)
                                    Text(source.question.answer)
                                        .font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .accessibilityIdentifier("growth.reflection-topic.answer.\(source.question.id)")
                                    Button {
                                        onSelectSource(source)
                                    } label: {
                                        Label("查看这次复盘", systemImage: "arrow.up.right")
                                            .font(.subheadline.weight(.semibold))
                                            .frame(minHeight: 44)
                                    }
                                    .accessibilityIdentifier("growth.reflection-topic.source.\(source.question.id)")
                                    .accessibilityLabel("查看\(source.date.mingsiShortDate)的复盘")
                                }
                                if source.id != topic.sources.last?.id { Divider() }
                            }
                        }
                        .padding(.top, 12)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(topic.title).font(.subheadline.weight(.semibold))
                            Text("\(topic.sources.count) 次复盘讨论过")
                                .font(.caption)
                                .foregroundStyle(DS.mutedInk)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 44, alignment: .leading)
                    }
                    .tint(DS.accent)
                }
            }
        }
        .foregroundStyle(DS.ink)
        .padding(18)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous).stroke(DS.hairline, lineWidth: 1))
    }
}

private struct TappableMetricRow: View {
    let title: String
    let value: Double
    let note: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                    .frame(width: 82, alignment: .leading)
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

                Text(String(format: "%.1f", value))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(DS.accentInk)
                    .frame(width: 30, alignment: .trailing)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(DS.mutedInk)
            }
            .accessibilityLabel("\(title) \(note) \(String(format: "%.1f", value))")
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
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
        growthMetricDisplayTitle(metric)
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
        if let displayReason = growthMetricReasonDisplay(reason) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("判断依据")
                Text(displayReason)
                    .font(.subheadline)
                    .foregroundStyle(DS.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .summarySurface()
        } else if let fallback = growthMetricFallbackReason(reason: reason, contributions: contributions) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("判断依据")
                Text(fallback)
                    .font(.subheadline)
                    .foregroundStyle(DS.mutedInk)
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
            .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
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

private struct PromptAssetQualitySummarySection: View {
    let summaries: [PromptAssetRunQualitySummary]
    let gate: PromptAssetQualityGate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Prompt 资产质量")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                    .accessibilityIdentifier(SettingsAutomationID.promptAssetQualitySection)

                Text("\(summaries.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(DS.mutedInk)

                Spacer(minLength: 8)
            }

            Label(gateStatusText, systemImage: gate.status == .passed ? "checkmark.seal" : "exclamationmark.triangle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(gate.status == .passed ? DS.success : DS.caution)

            if let issue = gate.issues.first {
                Text(issueMessage(issue))
                    .font(.caption)
                    .foregroundStyle(DS.caution)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("按 Prompt / Pack / Context / Eval 版本聚合最近调用，用于定位回滚或包版本问题。")
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(summaries) { summary in
                    PromptAssetQualitySummaryRow(summary: summary)
                }
            }
        }
        .padding(10)
        .background(DS.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
    }

    private var gateStatusText: String {
        switch gate.status {
        case .passed:
            return "运行质量通过"
        case .needsReview:
            var text = "运行质量需复查 \(gate.needsReviewAssetCount) 个资产 · \(gate.issueCount) 个信号"
            if gate.rollbackReadyAssetCount > 0 {
                text += " · 可回滚 \(gate.rollbackReadyAssetCount)"
            }
            if gate.manualReviewAssetCount > 0 {
                text += " · 需人工处理 \(gate.manualReviewAssetCount)"
            }
            return text
        }
    }

    private func issueMessage(_ issue: PromptAssetQualityGateIssue) -> String {
        guard let candidate = issue.rollbackCandidate else {
            return issue.message
        }
        return "\(issue.message) 可回滚到 \(candidate.rollbackTargetVersion)。"
    }
}

private struct CoachPromptQualitySummarySection: View {
    let summaries: [CoachPromptQualitySummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("教练呈现质量")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                Text("(summaries.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
                Spacer(minLength: 8)
            }

            Text("只统计实际显示给用户的追问和验证建议；无反馈样本显示为未知。")
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(summaries) { summary in
                    CoachPromptQualitySummaryRow(summary: summary)
                }
            }
        }
        .padding(10)
        .background(DS.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
    }
}

private struct CoachPromptQualitySummaryRow: View {
    let summary: CoachPromptQualitySummary

    private var promptName: String {
        PromptID(rawValue: summary.promptId)?.displayName ?? summary.promptId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(promptName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.ink)
                Text("v\(summary.promptVersion)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(DS.mutedInk)
                Spacer(minLength: 8)
                Text(summary.latestUpdatedAt.mingsiShortDate)
                    .font(.caption2)
                    .foregroundStyle(DS.mutedInk)
            }

            Text("已呈现 \(summary.presentedCount) · 失败 (summary.transportFailedCount + summary.parseRejectedCount + summary.qualityRejectedCount) · 丢弃 (summary.discardedCount) · 取消 (summary.cancelledCount)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(DS.mutedInk)

            HStack(spacing: 10) {
                Text("反馈覆盖 \(Self.percent(summary.feedbackCoverageRate))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(DS.mutedInk)
                if let rate = summary.ratedNegativeFeedbackRate {
                    Text("负向反馈 \(Self.percent(rate))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(rate > 0.35 ? DS.caution : DS.mutedInk)
                } else {
                    Text("负向反馈 未知")
                        .font(.caption2)
                        .foregroundStyle(DS.mutedInk)
                }
                Spacer(minLength: 0)
            }
            .accessibilityIdentifier("coachPromptQuality-\(summary.id)")
        }
        .padding(10)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

private struct PromptAssetQualitySummaryRow: View {
    let summary: PromptAssetRunQualitySummary

    private var promptName: String {
        PromptID(rawValue: summary.promptId)?.displayName ?? summary.promptId
    }

    private var qualityLine: String {
        "最近 \(summary.totalCount) 次 · 失败率 \(Self.percent(summary.failureRate)) · 空结果率 \(Self.percent(summary.emptyResultRate)) · 用户否认率 \(Self.percent(summary.userDenialRate))"
    }

    private var policyLine: String {
        "\(summary.promptPackDisplayName) · \(summary.promptPackVersion) · \(summary.promptSourceKind.rawValue)"
    }

    private var versionLine: String {
        "prompt v\(summary.promptVersion) · \(summary.contextPolicyVersion) · \(summary.evalSuiteVersion)"
    }

    private var rowIdentifier: String {
        SettingsAutomationID.promptAssetQualityRow(
            promptPackId: summary.promptPackId,
            promptId: summary.promptId,
            promptVersion: summary.promptVersion
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(promptName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(summary.latestRunCreatedAt.mingsiShortDate)
                    .font(.caption2)
                    .foregroundStyle(DS.mutedInk)
            }

            Text(qualityLine)
                .font(.caption.monospacedDigit())
                .foregroundStyle(summary.failureCount > 0 ? DS.caution : DS.mutedInk)
                .accessibilityIdentifier(rowIdentifier)

            Text(policyLine)
                .font(.caption2)
                .foregroundStyle(DS.mutedInk)
                .lineLimit(1)

            Text(versionLine)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(DS.mutedInk.opacity(0.82))
                .lineLimit(1)
        }
        .padding(10)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                .stroke(summary.failureCount > 0 ? DS.caution.opacity(0.18) : Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
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

            if let route = run.decisionRoute {
                Text("路由：\(route.title)")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .lineLimit(1)
            }

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
        case .candidateReady: return "候选已生成，可查看并保留为审计记录；不会改写原记录"
        case .accepted: return "候选已保留为审计记录，原历史内容未被改写"
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

func mergeAuditDisplayLines(from history: [String]) -> [String] {
    history.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

func candidateEvidenceSummary(_ candidate: ProjectMergeCandidate) -> String {
    let count = candidate.overlappingEvidenceRefs.count
    if count == 0 { return "\(count) 条证据" }
    let preview = candidate.overlappingEvidenceRefs.prefix(3)
        .map { String($0.prefix(8)) }
        .joined(separator: ", ")
    return "\(count) 条证据：\(preview)"
}

func candidateConsequenceLine() -> String {
    "目标议题保持活跃；源议题归档；已有证据链接保留。"
}

// MARK: - Growth report drilldown helpers

func growthEvidenceProgressText(completeLoopCount: Int) -> String {
    let completed = max(0, completeLoopCount)
    return "当前记录中有 \(completed) 次完整复盘。"
}

func growthMetricDisplayTitle(_ metric: GrowthMetric) -> String {
    switch metric {
    case .clarity: return "清晰度"
    case .valueJudgment: return "价值判断"
    case .executionReliability: return "执行可靠性"
    case .calibration: return "校准"
    case .reflectionDepth: return "反思深度"
    }
}

func growthContributionCountSummary(_ contributions: [MetricContribution]) -> String {
    let positive = contributions.filter { $0.direction == .positive }.count
    let negative = contributions.filter { $0.direction == .negative }.count
    return "+\(positive) / -\(negative)"
}

func growthLeadingContribution(_ contributions: [MetricContribution]) -> MetricContribution? {
    contributions.max { abs($0.delta) < abs($1.delta) }
}

func growthMetricReasonDisplay(_ reason: String?) -> String? {
    guard let reason else { return nil }
    let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

func growthMetricFallbackReason(reason: String?, contributions: [MetricContribution]) -> String? {
    guard growthMetricReasonDisplay(reason) == nil, !contributions.isEmpty else { return nil }
    return "根据已接受贡献归因，点击查看来源证据。"
}

func normalizedMetricDetailContributions(
    _ contributions: [MetricContribution],
    metric: GrowthMetric
) -> [MetricContribution] {
    MetricContribution.latestVersionsForHistory(
        contributions.filter { contribution in
            contribution.metric == metric &&
                contribution.candidateStatus != .rejected &&
                contribution.userFeedback != .inaccurate &&
                contribution.userFeedback != .dismissed &&
                !contribution.sourceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    )
}

func weeklyGuidanceReferenceCopy(hintIDs: [String]) -> String? {
    hintIDs.compactMap { hintID in
        BuiltinGuidanceCatalog.items.first(where: { $0.hintId == hintID })?.copy
    }.first
}

func historyRecordContainsDeepLinkSource(_ deepLink: HistoryDeepLink, in record: HistoryRecord) -> Bool {
    guard record.draft.id == deepLink.dailyEntryId, let sourceId = deepLink.sourceId else {
        return false
    }
    if deepLink.sourceType == .project {
        return record.projectLinks.contains { link in
            isProjectLinkHighlighted(link, highlightedSourceId: sourceId)
        }
    }
    return record.sourceIds.contains(sourceId)
}

func historyDeepLinkIsLocated(_ deepLink: HistoryDeepLink?, in record: HistoryRecord) -> Bool {
    guard let deepLink else { return false }
    return historyRecordContainsDeepLinkSource(deepLink, in: record)
}

func isProjectLinkHighlighted(_ link: ProjectLink, highlightedSourceId: String?) -> Bool {
    guard let highlightedSourceId, !highlightedSourceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return false
    }
    return link.projectId.uuidString == highlightedSourceId ||
        link.id.uuidString == highlightedSourceId ||
        link.sourceId == highlightedSourceId
}

func mergeAuditDisplayLinesIfNonEmpty(from history: [String]) -> [String]? {
    let lines = mergeAuditDisplayLines(from: history)
    return lines.isEmpty ? nil : lines
}

// MARK: - Project detail display helpers

struct ProjectOverviewFactLine: Hashable {
    let title: String
    let value: String
}

func projectOverviewFactLines(
    goal: String?,
    successCriteria: String?,
    currentBottleneck: String?,
    nextBet: String?,
    openQuestions: [String]?,
    evidenceGapMessage: String
) -> [ProjectOverviewFactLine] {
    var lines: [ProjectOverviewFactLine] = []

    if let goal = projectOverviewDisplayValue(goal) {
        lines.append(ProjectOverviewFactLine(title: "目标", value: goal))
    }
    if let successCriteria = projectOverviewDisplayValue(successCriteria) {
        lines.append(ProjectOverviewFactLine(title: "成功标准", value: successCriteria))
    }
    if let bottleneck = projectOverviewDisplayValue(currentBottleneck) {
        lines.append(ProjectOverviewFactLine(title: "当前阻塞", value: bottleneck))
    }
    if let nextBet = projectOverviewDisplayValue(nextBet) {
        lines.append(ProjectOverviewFactLine(title: "下一步押注", value: nextBet))
    }
    if let questions = openQuestions?.compactMap(projectOverviewDisplayValue), !questions.isEmpty {
        lines.append(ProjectOverviewFactLine(title: "开放问题", value: questions.joined(separator: "\n")))
    }
    if let evidenceGapMessage = projectOverviewDisplayValue(evidenceGapMessage) {
        lines.append(ProjectOverviewFactLine(title: "证据缺口", value: evidenceGapMessage))
    }

    return lines
}

func projectContextFactLines(
    goal: String?,
    successCriteria: String?,
    openQuestions: [String]?
) -> [ProjectOverviewFactLine] {
    var lines: [ProjectOverviewFactLine] = []

    if let goal = projectOverviewDisplayValue(goal) {
        lines.append(ProjectOverviewFactLine(title: "目标", value: goal))
    }
    if let successCriteria = projectOverviewDisplayValue(successCriteria) {
        lines.append(ProjectOverviewFactLine(title: "成功标准", value: successCriteria))
    }
    if let questions = openQuestions?.compactMap(projectOverviewDisplayValue), !questions.isEmpty {
        lines.append(ProjectOverviewFactLine(title: "开放问题", value: questions.joined(separator: "\n")))
    }

    return lines
}

func projectOverviewDisplayValue(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}

func projectPrincipleEvidenceEntries(
    from item: ProjectEvidenceBoardItem
) -> [(link: ProjectLink, record: HistoryRecord)] {
    item.sortedEntries.filter { entry in
        guard entry.link.sourceType == .principle else { return false }
        return entry.record.principles.contains { $0.id.uuidString == entry.link.sourceId }
    }
}

func projectThinkingChangeHeadline(hasBeforeAfterEvidence: Bool) -> String {
    hasBeforeAfterEvidence ? "等待确认洞察" : "证据不足"
}

func projectThinkingChangeBody(hasBeforeAfterEvidence: Bool) -> String {
    hasBeforeAfterEvidence
        ? "已有多条项目证据，可以生成候选洞察；在你确认之前，明思不会自动写入思考变化叙事。"
        : "当前只有零散项目证据。没有 before / after 来源时，不生成项目洞察，也不编造思考变化。"
}

func projectDetailStatusChipText(for status: ProjectStatus?) -> String {
    status?.chineseTitle ?? "活跃"
}

func shouldShowProjectDetailThinkingChange(hasBeforeAfterEvidence: Bool, acceptedInsightCount: Int) -> Bool {
    hasBeforeAfterEvidence || acceptedInsightCount > 0
}

func projectThinkingChangeHeadline(hasBeforeAfterEvidence: Bool, acceptedInsightCount: Int) -> String {
    if hasBeforeAfterEvidence {
        return "等待确认洞察"
    }
    return acceptedInsightCount > 0 ? "已确认洞察" : "证据不足"
}

func projectThinkingChangeBody(hasBeforeAfterEvidence: Bool, acceptedInsightCount: Int) -> String {
    if hasBeforeAfterEvidence {
        return "已有多条项目证据，可以生成候选洞察；在你确认之前，明思不会自动写入思考变化叙事。"
    }
    if acceptedInsightCount > 0 {
        return "已确认项目洞察保留在上方。没有 before / after 来源时，明思不会把它改写成思考变化叙事。"
    }
    return "当前只有零散项目证据。没有 before / after 来源时，不生成项目洞察，也不编造思考变化。"
}

func projectDetailTimelineVisibleCount(totalCount: Int, isExpanded: Bool, collapsedLimit: Int = 5) -> Int {
    guard totalCount > 0 else { return 0 }
    return isExpanded ? totalCount : min(totalCount, collapsedLimit)
}

func projectDetailTimelineToggleTitle(totalCount: Int, isExpanded: Bool, collapsedLimit: Int = 5) -> String? {
    guard totalCount > collapsedLimit else { return nil }
    return isExpanded ? "收起证据" : "查看全部 \(totalCount) 条证据"
}

func projectDetailProgressSignalsToggleTitle(totalCount: Int, isExpanded: Bool, collapsedLimit: Int = 2) -> String? {
    guard totalCount > collapsedLimit else { return nil }
    return isExpanded ? "收起进展" : "查看全部 \(totalCount) 条进展"
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
                Text(candidateEvidenceSummary(candidate))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DS.mutedInk)
            }

            Text(candidate.reason)
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            Text(candidateConsequenceLine())
                .font(.caption2)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

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
