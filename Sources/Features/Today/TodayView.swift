import SwiftUI
import UIKit

enum TodayAutomationID {
    static let primaryAction = "today.primary-action"
    static let primaryActionHint = "today.primary-action-hint"
    static let previousAction = "today.previous-action"
    static let supplementCaptureAction = "today.supplement-capture-action"
    static let retryCurrentStepAction = "today.retry-current-step-action"
    static let skipPrincipleAction = "today.skip-principle-action"
    static let resetAction = "today.reset-action"
    static let cardConfirmAction = "today.card.confirm-action"
    static let cardExcludeAction = "today.card.exclude-action"
    static let questionAnswerField = "today.question.answer-field"
    static let questEditAction = "today.quest.edit-action"
    static let principleFeedbackHelpfulAction = "today.principle.feedback.helpful-action"
    static let principleFeedbackNotApplicableAction = "today.principle.feedback.not-applicable-action"
    static let principleFeedbackMisrecalledAction = "today.principle.feedback.misrecalled-action"
    static let lensGenerateAction = "today.lens.generate-action"
    static let lensCustomAction = "today.lens.custom-action"
    static let customLensSheet = "today.custom-lens.sheet"
    static let customLensTitleField = "today.custom-lens.title-field"
    static let customLensMethodField = "today.custom-lens.method-field"
    static let customLensQuestionField = "today.custom-lens.question-field"
    static let customLensSaveAction = "today.custom-lens.save-action"

    static func state(_ state: DailyLoopState) -> String {
        let stateID: String
        switch state {
        case .verifyYesterday: stateID = "verify_yesterday"
        case .capture: stateID = "capture"
        case .organizing: stateID = "organizing"
        case .reviewCards: stateID = "review_cards"
        case .selectMode: stateID = "select_mode"
        case .selectLens: stateID = "select_lens"
        case .answerQuestions: stateID = "answer_questions"
        case .reviewQuests: stateID = "review_quests"
        case .extractPrinciple: stateID = "extract_principle"
        case .sessionComplete: stateID = "session_complete"
        }
        return "today.state.\(stateID)"
    }

    static func lensAction(_ item: LensCatalogItem) -> String {
        "today.lens.\(item.id)-action"
    }
}

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @State private var isCaptureFocused = false
    @State private var isCustomLensSheetPresented = false
    @State private var customLensTitle = ""
    @State private var customLensMethodLine = ""
    @State private var customLensQuestion = ""

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.sectionSpacing) {
                        header
                            .id(TodayScrollAnchor.top)
                        loopProgress {
                            withAnimation(.easeInOut(duration: 0.24)) {
                                proxy.scrollTo(TodayScrollAnchor.top, anchor: .top)
                            }
                        }

                        switch store.todayDraft.state {
                        case .verifyYesterday:
                            verifyYesterdaySection
                        case .capture:
                            captureSection
                        case .organizing:
                            organizingSection
                        case .reviewCards:
                            reviewCardsSection
                        case .selectMode:
                            selectModeSection
                        case .selectLens:
                            selectLensSection
                        case .answerQuestions:
                            answerQuestionsSection
                        case .reviewQuests:
                            reviewQuestsSection
                        case .extractPrinciple:
                            extractPrincipleSection
                        case .sessionComplete:
                            sessionCompleteSection
                        }
                    }
                    .padding(.horizontal, DS.pagePadding)
                    .padding(.top, DS.primaryScrollTopPadding)
                    .padding(.bottom, DS.todayScrollBottomReserve)
                }
                .scrollIndicators(.hidden)
                .pageBackground()
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    actionRow
                }
            }
        }
        .topSafeAreaScrim()
        .sheet(isPresented: $isCustomLensSheetPresented) {
            customLensSheet
        }
        .onAppear {
            presentVisualQACustomLensSheetIfNeeded()
        }
        .onChange(of: store.todayDraft.state) { _, _ in
            presentVisualQACustomLensSheetIfNeeded()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.todayDraft.date, style: .date)
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline) {
                Text(store.currentStateTitle)
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.ink)
                    .accessibilityIdentifier(TodayAutomationID.state(store.todayDraft.state))

                Spacer()

                if store.todayDraft.hasSelectedSessionMode {
                    Text(store.todayDraft.sessionMode.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(DS.accent.opacity(0.08), in: Capsule())
                }
            }

            if !store.todayLoopMessage.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.todayLoopMessage)
                        .font(.footnote)
                        .foregroundStyle(DS.caution)
                    if store.canRetryCurrentAI {
                        Button {
                            store.retryCurrentAIStep()
                        } label: {
                            Label("重试 AI", systemImage: "arrow.clockwise")
                        }
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private func loopProgress(scrollToTop: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(DailyLoopState.allCases) { state in
                    Button {
                        if store.canNavigateTodayLoop(to: state) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                store.navigateTodayLoop(to: state)
                                scrollToTop()
                            }
                        } else {
                            scrollToTop()
                        }
                    } label: {
                        Capsule()
                            .fill(progressColor(for: state))
                            .frame(height: 8)
                            .opacity(store.canNavigateTodayLoop(to: state) || state == store.todayDraft.state ? 1 : 0.55)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("回到\(state.title)")
                    .accessibilityHint(store.canNavigateTodayLoop(to: state) ? "点按回到该步骤编辑" : "该步骤暂不可返回")
                }
            }

            Text(progressCaption)
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
        }
        .padding(.top, 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: scrollToTop)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("今日流程进度")
        .accessibilityHint("点按返回今日顶部")
    }

    // MARK: - Verify Yesterday

    // Purpose: Close yesterday's loop before starting fresh
    // Design: Warm, reflective - not a form, a moment of honesty
    private var verifyYesterdaySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepLabel("先回看昨天", subtitle: "用一个真实结果校准昨天的判断。")

            if let quest = store.mainQuest ?? store.quests.first {
                VStack(alignment: .leading, spacing: 6) {
                    Text("昨日主线任务")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(quest.title)
                        .font(.body.weight(.medium))
                }
                .questSurface(isMain: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("完成了吗？")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 10) {
                    ForEach(YesterdayCompletion.allCases) { completion in
                        choiceChip(
                            title: completion.title,
                            isSelected: store.todayDraft.yesterdayCompletion == completion,
                            action: { store.selectYesterdayCompletion(completion) }
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("实际价值？")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 10) {
                    ForEach(YesterdayValueRating.allCases) { rating in
                        choiceChip(
                            title: rating.title,
                            isSelected: store.todayDraft.yesterdayValueRating == rating,
                            action: { store.selectYesterdayValueRating(rating) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Capture

    // Purpose: Raw dump of today's messy thoughts
    // Design: Generous text area, inviting, feels like opening a notebook
    private var captureSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepLabel("今天发生了什么？", subtitle: "先收集原始材料，不急着写成文章。")

            CaptureTextView(text: Binding(
                get: { store.todayDraft.rawText },
                set: { store.updateTodayCapture($0) }
            ), isFocused: $isCaptureFocused)
            .frame(minHeight: 220)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    .allowsHitTesting(false)
            )

            HStack(spacing: 10) {
                Button {
                    pasteClipboardIntoCapture()
                } label: {
                    Label("粘贴剪贴板", systemImage: "doc.on.clipboard")
                }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.bordered)

                Button {
                    isCaptureFocused = true
                } label: {
                    Label("开始输入", systemImage: "keyboard")
                }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.bordered)
            }

            HStack(spacing: 8) {
                Image(systemName: "hand.raised")
                    .font(.caption2)
                Text("不要输入公司敏感资料、代码、客户信息或内部数据。")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("训练深度")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                modeCard(mode: .quick, icon: "bolt", description: "最短路径，只收敛最关键的动作。")
                modeCard(mode: .standard, icon: "book", description: "默认完整流程，平衡速度和深度。")
                modeCard(mode: .deep, icon: "brain.head.profile", description: "追问更深，适合重要事件和周复盘。")
            }
            .padding(.top, 2)

            starterPills
        }
    }

    // MARK: - Organizing

    // Purpose: AI is working, give feedback
    // Design: Quiet progress, not a loading spinner spectacle
    private var organizingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepLabel(store.apiKeyConfigured ? "正在整理" : "本地整理中", subtitle: "整理成可确认、可排除、可继续追问的卡片。")

            AIGenerationProgressView(
                isUsingAI: store.apiKeyConfigured,
                cardCount: store.thinkingCards.count,
                streamingCards: store.streamingCards,
                statusText: store.streamingStatusText,
                failureMessage: store.lastAIFailureMessage,
                canRetry: store.canRetryCurrentAI,
                retry: { store.retryCurrentAIStep() }
            )
        }
    }

    // MARK: - Review Cards

    // Purpose: User reviews AI-extracted cards, confirms what's real
    // Design: Cards stacked with type color dot, minimal chrome, focus on content
    private var reviewCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepLabel("思考卡片", subtitle: "先确认哪些材料是真的、重要的、值得继续追问。")

            ForEach(store.thinkingCards) { card in
                ThinkingCardRow(
                    card: card,
                    update: { type, title, body, priority, sensitivity in
                        store.updateCard(
                            card.id,
                            type: type,
                            title: title,
                            body: body,
                            priority: priority,
                            sensitivity: sensitivity
                        )
                    },
                    confirm: { store.confirmCard(card.id) },
                    exclude: { store.excludeCard(card.id) },
                    delete: { store.deleteCard(card.id) }
                )
            }
        }
    }

    // MARK: - Select Mode

    // Purpose: Choose thinking depth
    // Design: Three clear options, selected state is obvious but calm
    private var selectModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepLabel("训练模式", subtitle: "今天需要多深，就选择多深。")

            modeCard(mode: .quick, icon: "bolt", description: "最短路径，只收敛最关键的动作。")
            modeCard(mode: .standard, icon: "book", description: "默认完整流程，平衡速度和深度。")
            modeCard(mode: .deep, icon: "brain.head.profile", description: "追问更深，适合重要事件和周复盘。")
        }
    }

    // MARK: - Select Lens

    // Purpose: Pick, generate, or write a thinking lens to challenge assumptions
    // Design: Today-core method board; recommendation is the anchor, custom entry is visible
    private var selectLensSection: some View {
        let confirmedCards = store.thinkingCards.filter(\.isConfirmed)
        let recommendedItem = BuiltinLensCatalog.library.recommendedItem(
            for: confirmedCards,
            mode: store.todayDraft.sessionMode
        )
        let builtInItems = ThinkingLens.allCases
            .sorted { $0.catalogItem.methodIndex < $1.catalogItem.methodIndex }
            .map(\.catalogItem)

        return VStack(alignment: .leading, spacing: 14) {
            stepLabel("思考透镜", subtitle: "先选方法，再回答问题。")

            todayLensCoreCard(confirmedCount: confirmedCards.count)

            if let recommendedItem {
                recommendedLensCard(recommendedItem)
            }

            HStack(spacing: 10) {
                lensActionCard(
                    icon: "wand.and.stars",
                    title: "主动生成透镜",
                    body: "基于已确认卡片生成本次专属方法卡。",
                    tint: DS.brick
                ) {
                    let item = store.generateCustomLensFromConfirmedCards()
                    store.selectCustomLens(item.id)
                }
                .accessibilityIdentifier(TodayAutomationID.lensGenerateAction)

                lensActionCard(
                    icon: "square.and.pencil",
                    title: "自定义透镜",
                    body: "手写标题、方法线和第一问。",
                    tint: DS.success
                ) {
                    openCustomLensSheet()
                }
                .accessibilityIdentifier(TodayAutomationID.lensCustomAction)
            }

            if !store.customLensItems.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    Text("我的透镜")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                        .textCase(.uppercase)
                    ForEach(store.customLensItems, id: \.id) { item in
                        customLensCard(item)
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 10)], spacing: 10) {
                ForEach(builtInItems, id: \.id) { item in
                    lensMethodTile(item, isRecommended: item.id == recommendedItem?.id)
                }
            }
        }
    }

    // MARK: - Answer Questions

    // Purpose: Answer coaching questions to sharpen thinking
    // Design: Each question is a card with answer field, inviting not interrogating
    private var answerQuestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepLabel("回答问题", subtitle: "至少回答一个，训练不是让 AI 替你下结论。")

            if !store.referencedPrinciples.isEmpty {
                ReferencedPrinciplesView(
                    principles: store.referencedPrinciples,
                    onFeedback: recordReferencedPrincipleFeedback
                )
            }

            ForEach(Array(store.questions.enumerated()), id: \.element.id) { index, question in
                QuestionCardView(question: question, answer: bindingForQuestion(questionID: question.id, fallbackIndex: index))
            }
        }
    }

    // MARK: - Review Quests

    // Purpose: Review tomorrow's action plan
    // Design: Quest cards feel actionable, main quest is visually prominent
    private var reviewQuestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepLabel("明日任务", subtitle: "主线任务必须有明确完成标准。")

            if !store.referencedPrinciples.isEmpty {
                ReferencedPrinciplesView(
                    principles: store.referencedPrinciples,
                    onFeedback: recordReferencedPrincipleFeedback
                )
            }

            ForEach(store.quests) { quest in
                QuestCardView(
                    quest: quest,
                    update: { title, whyItMatters, completionCriteria, expectedResistance, reflectionQuestion in
                        store.updateQuest(
                            quest.id,
                            title: title,
                            whyItMatters: whyItMatters,
                            completionCriteria: completionCriteria,
                            expectedResistance: expectedResistance,
                            reflectionQuestion: reflectionQuestion
                        )
                    }
                )
            }
        }
    }

    // MARK: - Extract Principle

    // Purpose: Distill a reusable rule from today
    // Design: Feels like saving a permanent insight, not just another card
    private var extractPrincipleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepLabel("原则候选", subtitle: "只沉淀可复用的行为规则。")

            if let principle = store.principles.first {
                PrincipleCardView(
                    principle: principle,
                    update: { title, summary, triggerContext, actionsText, successCriteria, exceptions in
                        store.updatePrinciple(
                            principle.id,
                            title: title,
                            summary: summary,
                            triggerContext: triggerContext,
                            actionsText: actionsText,
                            successCriteria: successCriteria,
                            exceptions: exceptions
                        )
                    }
                )
            } else {
                EmptyStateCard(text: "这次复盘还没有稳定到值得沉淀为原则。")
            }
        }
    }

    // MARK: - Session Complete

    // Purpose: Summary of what was accomplished
    // Design: Clean summary, feels like closing a notebook
    private var sessionCompleteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepLabel("今日完成", subtitle: "今天的输入已经转成明天可验证的动作。")

            if let mainQuest = store.quests.first(where: { $0.type == .main }) {
                completionCard(icon: "flag.checkered", title: "明日主线任务", body: mainQuest.title)
            }

            if let principle = store.principles.first {
                completionCard(icon: "lightbulb", title: "今日沉淀", body: principle.title)
            }

            completionCard(icon: "chart.line.uptrend.xyaxis", title: "成长快照", body: store.growthSnapshot.summary)

            if store.hasEnoughEvidenceForProjectSuggestions && !store.isGeneratingProjectSuggestions {
                Button {
                    Task {
                        await store.suggestProjectsForToday()
                    }
                } label: {
                    Label("建议长期议题", systemImage: "link.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(DS.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if store.isGeneratingProjectSuggestions {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("正在生成项目建议...")
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                }
            }

            if !store.projectSuggestionMessage.isEmpty {
                Text(store.projectSuggestionMessage)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
            }

            todayProjectCandidatesSection
        }
    }

    @ViewBuilder
    private var todayProjectCandidatesSection: some View {
        let pending = store.projectCandidates.filter { $0.status == .pending }
        let linkPending = store.projectLinkCandidates
        if !pending.isEmpty || !linkPending.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("项目候选")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
                    .textCase(.uppercase)
                    .tracking(0.5)
                ForEach(pending) { candidate in
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
                ForEach(linkPending) { link in
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

    // MARK: - Action Row

    private var actionRow: some View {
        VStack(spacing: 10) {
            Button {
                store.submitTodayStep()
            } label: {
                Text(primaryActionTitle)
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.accent)
            .disabled(store.todayPrimaryActionBlocker != nil)
            .accessibilityIdentifier(TodayAutomationID.primaryAction)

            if let blocker = store.todayPrimaryActionBlocker {
                Text(blocker)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(TodayAutomationID.primaryActionHint)
            }

            HStack(spacing: 18) {
                if canNavigateToPreviousUserStep {
                    Button("上一步") {
                        store.navigateTodayLoopToPreviousUserStep()
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
                    .accessibilityIdentifier(TodayAutomationID.previousAction)
                }

                if canSupplementCapture {
                    Button("补充材料") {
                        store.navigateTodayLoop(to: .capture)
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DS.accent)
                    .accessibilityIdentifier(TodayAutomationID.supplementCaptureAction)
                }

                if store.canRetryCurrentAI {
                    Button("重试当前步骤") {
                        store.retryCurrentAIStep()
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DS.accent)
                    .accessibilityIdentifier(TodayAutomationID.retryCurrentStepAction)
                }

                if store.todayDraft.state == .extractPrinciple {
                    Button("跳过原则") {
                        store.skipPrinciple()
                    }
                    .font(.subheadline)
                    .accessibilityIdentifier(TodayAutomationID.skipPrincipleAction)
                }

                Button("重置今日") {
                    store.resetTodayLoop()
                }
                .font(.footnote)
                .foregroundStyle(DS.mutedInk)
                .accessibilityIdentifier(TodayAutomationID.resetAction)
            }
        }
        .padding(.horizontal, DS.pagePadding)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)
        }
    }

    private var primaryActionTitle: String {
        if store.isAIRunning {
            return store.aiActivityMessage.isEmpty ? "AI 生成中" : store.aiActivityMessage
        }

        switch store.todayDraft.state {
        case .verifyYesterday: return "保存验证"
        case .capture:
            let mode = store.todayDraft.hasSelectedSessionMode ? store.todayDraft.sessionMode.title : "选择模式"
            return "\(mode) 整理成卡片"
        case .organizing: return "查看卡片"
        case .reviewCards: return "确认卡片"
        case .selectMode: return "确认模式"
        case .selectLens: return "回答问题"
        case .answerQuestions: return "生成任务"
        case .reviewQuests: return "保存任务"
        case .extractPrinciple: return "保存原则"
        case .sessionComplete: return "开始新一天"
        }
    }

    private var previousState: DailyLoopState? {
        guard
            let currentIndex = DailyLoopState.allCases.firstIndex(of: store.todayDraft.state),
            currentIndex > 0
        else { return nil }
        let candidate = DailyLoopState.allCases[currentIndex - 1]
        return store.canNavigateTodayLoop(to: candidate) ? candidate : nil
    }

    private var canNavigateToPreviousUserStep: Bool {
        switch store.todayDraft.state {
        case .reviewCards:
            return store.canNavigateTodayLoop(to: .capture)
        case .selectLens, .answerQuestions, .reviewQuests, .extractPrinciple, .sessionComplete:
            return true
        case .verifyYesterday, .capture, .organizing, .selectMode:
            return previousState != nil
        }
    }

    private var progressCaption: String {
        switch store.todayDraft.state {
        case .verifyYesterday: return "1/10 校准昨天"
        case .capture: return "2/10 收集输入并选择训练深度"
        case .organizing: return "3/10 按训练深度整理卡片"
        case .reviewCards: return "4/10 确认事实和问题"
        case .selectMode: return "5/10 确认训练深度"
        case .selectLens: return "6/10 选择思考透镜"
        case .answerQuestions: return "7/10 自己回答关键问题"
        case .reviewQuests: return "8/10 形成明日任务"
        case .extractPrinciple: return "9/10 沉淀行动准则"
        case .sessionComplete: return "10/10 今日闭环完成"
        }
    }

    private var canSupplementCapture: Bool {
        switch store.todayDraft.state {
        case .reviewCards, .selectMode, .selectLens, .answerQuestions, .reviewQuests, .extractPrinciple:
            return store.canNavigateTodayLoop(to: .capture)
        case .verifyYesterday, .capture, .organizing, .sessionComplete:
            return false
        }
    }

    private var starterPills: some View {
        FlowPills(items: [
            "今天真正推进了什么？",
            "哪件事让我感觉不清楚？",
            "我是否回避了一个关键判断？",
            "明天最不能忽略什么？"
        ])
    }

    // MARK: - Helpers

    private func stepLabel(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(DS.ink)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(DS.mutedInk)
        }
    }

    private func progressColor(for state: DailyLoopState) -> Color {
        let states = DailyLoopState.allCases
        guard
            let currentIndex = states.firstIndex(of: store.todayDraft.state),
            let stateIndex = states.firstIndex(of: state)
        else {
            return Color.primary.opacity(0.08)
        }
        if stateIndex < currentIndex {
            return DS.accent.opacity(0.55)
        }
        if stateIndex == currentIndex {
            return DS.accent
        }
        return Color.primary.opacity(0.08)
    }

    private func bindingForQuestion(questionID: ReflectionQuestion.ID, fallbackIndex index: Int) -> Binding<String> {
        Binding(
            get: {
                store.questions.first(where: { $0.id == questionID })?.answer ??
                    store.questions[safe: index]?.answer ??
                    ""
            },
            set: { store.updateQuestionAnswer(questionID: questionID, answer: $0) }
        )
    }

    private func pasteClipboardIntoCapture() {
        guard let pastedText = UIPasteboard.general.string, !pastedText.isEmpty else {
            isCaptureFocused = true
            return
        }

        let existing = store.todayDraft.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextText = existing.isEmpty ? pastedText : "\(store.todayDraft.rawText)\n\(pastedText)"
        store.updateTodayCapture(nextText)
        isCaptureFocused = true
    }

    private func choiceChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : DS.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? DS.accent : Color(.systemBackground), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func modeCard(mode: SessionMode, icon: String, description: String) -> some View {
        Button(action: { store.selectTodayMode(mode) }) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DS.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                }

                Spacer()

                if store.todayDraft.hasSelectedSessionMode && store.todayDraft.sessionMode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modeSurface(isSelected: store.todayDraft.hasSelectedSessionMode && store.todayDraft.sessionMode == mode)
    }

    private func todayLensCoreCard(confirmedCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today Core Card")
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
                    .textCase(.uppercase)
                Spacer()
                Text("\(store.todayDraft.sessionMode.title) · \(confirmedCount) 已确认")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
            }

            Text(lensCoreTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(DS.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("透镜会决定下一组追问的角度。推荐可以直接选，也可以生成或手写一个本次专属方法卡。")
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.cardInnerPadding)
        .background(DS.surfaceStrong, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
    }

    private var lensCoreTitle: String {
        guard let first = store.thinkingCards.first(where: \.isConfirmed) else {
            return "先选择看问题的方法。"
        }
        return "围绕「\(first.title)」换一个角度看。"
    }

    private func recommendedLensCard(_ item: LensCatalogItem) -> some View {
        Button(action: { selectLensItem(item) }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("METHOD \(String(format: "%02d", item.methodIndex)) · 推荐")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(lensTint(for: item))
                    Spacer()
                    Image(systemName: isLensItemSelected(item) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isLensItemSelected(item) ? lensTint(for: item) : DS.mutedInk.opacity(0.45))
                }

                Text(item.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DS.ink)

                Text(item.recommendedReason)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.methodLine)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(lensTint(for: item))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(DS.hairline)
                            .frame(height: 1)
                    }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(TodayAutomationID.lensAction(item))
        .padding(DS.cardInnerPadding)
        .background(DS.cardBackground, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(lensTint(for: item))
                .frame(width: 5)
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(isLensItemSelected(item) ? lensTint(for: item).opacity(0.42) : lensTint(for: item).opacity(0.22), lineWidth: isLensItemSelected(item) ? 1.25 : 1)
        )
    }

    private func lensActionCard(
        icon: String,
        title: String,
        body: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(tint.opacity(0.38), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DS.ink)
                    Text(body)
                        .font(.caption2)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }

    private func customLensCard(_ item: LensCatalogItem) -> some View {
        Button(action: { selectLensItem(item) }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.brick)
                    .frame(width: 34, height: 34)
                    .background(DS.brick.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(DS.ink)
                        Text(item.shortLabel)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(DS.brick)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DS.brick.opacity(0.08), in: Capsule())
                    }
                    Text(item.methodLine)
                        .font(.caption)
                        .foregroundStyle(DS.brick)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(item.subtitle)
                        .font(.caption2)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
                Image(systemName: isLensItemSelected(item) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isLensItemSelected(item) ? DS.brick : DS.mutedInk.opacity(0.42))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(12)
        .background(DS.brick.opacity(isLensItemSelected(item) ? 0.08 : 0.04), in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(DS.brick.opacity(isLensItemSelected(item) ? 0.34 : 0.16), lineWidth: 1)
        )
    }

    private func lensMethodTile(_ item: LensCatalogItem, isRecommended: Bool) -> some View {
        Button(action: { selectLensItem(item) }) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(String(format: "%02d", item.methodIndex))
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(lensTint(for: item))
                    Spacer()
                    if isRecommended {
                        Text("推荐")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(DS.accentInk)
                    }
                }

                Text(item.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(DS.ink)
                    .lineLimit(1)

                Text(item.questionSeeds.first ?? item.methodLine)
                    .font(.caption2)
                    .foregroundStyle(DS.mutedInk)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(TodayAutomationID.lensAction(item))
        .padding(12)
        .background(isLensItemSelected(item) ? lensTint(for: item).opacity(0.07) : Color(.systemBackground), in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(isLensItemSelected(item) ? lensTint(for: item).opacity(0.34) : Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var customLensSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "square.and.pencil")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(DS.success)
                                .frame(width: 38, height: 38)
                                .background(DS.success.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("自定义透镜")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(DS.ink)
                                Text("把你自己的思考方法写成一张 Today 方法卡。保存后会出现在「我的透镜」。")
                                    .font(.caption)
                                    .foregroundStyle(DS.mutedInk)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Text("Custom Lens Card")
                            .font(.caption2.monospaced().weight(.semibold))
                            .foregroundStyle(DS.mutedInk)
                            .textCase(.uppercase)
                    }
                    .padding(DS.cardInnerPadding)
                    .background(DS.surfaceStrong, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                            .stroke(DS.hairline, lineWidth: 1)
                    )

                    customLensFieldCard(
                        title: "标题",
                        hint: "给这个透镜一个短名字。",
                        placeholder: "我的透镜",
                        text: $customLensTitle,
                        minHeight: 46,
                        automationID: TodayAutomationID.customLensTitleField
                    )

                    customLensFieldCard(
                        title: "方法线",
                        hint: "写清楚它如何迫使你换角度。",
                        placeholder: "先问：这件事最需要被换个角度看的是什么？",
                        text: $customLensMethodLine,
                        minHeight: 82,
                        automationID: TodayAutomationID.customLensMethodField
                    )

                    customLensFieldCard(
                        title: "第一问",
                        hint: "进入透镜后最先回答的问题。",
                        placeholder: "这件事最需要被换个角度看的是什么？",
                        text: $customLensQuestion,
                        minHeight: 82,
                        automationID: TodayAutomationID.customLensQuestionField
                    )

                    Button {
                        saveCustomLens()
                    } label: {
                        Label("保存并选择", systemImage: "checkmark.circle.fill")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.success)
                    .controlSize(.regular)
                    .accessibilityIdentifier(TodayAutomationID.customLensSaveAction)
                }
                .padding(.horizontal, DS.pagePadding)
                .padding(.top, DS.primaryScrollTopPadding)
                .padding(.bottom, 28)
            }
            .pageBackground()
            .navigationTitle("自定义透镜")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isCustomLensSheetPresented = false
                    }
                }
            }
        }
        .accessibilityIdentifier(TodayAutomationID.customLensSheet)
    }

    private func customLensFieldCard(
        title: String,
        hint: String,
        placeholder: String,
        text: Binding<String>,
        minHeight: CGFloat,
        automationID: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DS.ink)
                Spacer()
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(DS.mutedInk)
            }

            TextField(placeholder, text: text, axis: .vertical)
                .font(.subheadline)
                .foregroundStyle(DS.ink)
                .lineLimit(1...4)
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                        .stroke(DS.hairline, lineWidth: 1)
                )
                .accessibilityIdentifier(automationID)
        }
        .padding(DS.cardInnerPadding)
        .background(DS.cardBackground, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private func openCustomLensSheet() {
        customLensTitle = "我的透镜"
        customLensMethodLine = "先问：这件事最需要被换个角度看的是什么？"
        customLensQuestion = "这件事最需要被换个角度看的是什么？"
        isCustomLensSheetPresented = true
    }

    private func presentVisualQACustomLensSheetIfNeeded() {
#if DEBUG
        guard store.todayDraft.state == .selectLens,
              AppStore.shouldPresentVisualQACustomLensSheet(),
              !isCustomLensSheetPresented else { return }
        openCustomLensSheet()
#endif
    }

    private func recordReferencedPrincipleFeedback(
        principle: PrincipleAsset,
        feedback: PrincipleRecallFeedbackValue
    ) {
        Task {
            await store.recordReferencedPrincipleFeedback(
                for: principle.id,
                feedback: feedback
            )
        }
    }

    private func saveCustomLens() {
        let item = store.upsertCustomLens(
            title: customLensTitle,
            subtitle: "手写方法卡，服务于当前 Today。",
            shortLabel: "自定",
            methodLine: customLensMethodLine,
            promptGuidance: "Use the user's manually written lens to generate concrete reflection questions.",
            firstQuestion: customLensQuestion
        )
        store.selectCustomLens(item.id)
        isCustomLensSheetPresented = false
    }

    private func selectLensItem(_ item: LensCatalogItem) {
        if let lens = ThinkingLens(rawValue: item.id) {
            store.selectThinkingLens(lens)
        } else {
            store.selectCustomLens(item.id)
        }
    }

    private func isLensItemSelected(_ item: LensCatalogItem) -> Bool {
        store.todayDraft.selectedLens?.rawValue == item.id || store.todayDraft.selectedCustomLensId == item.id
    }

    private func lensTint(for item: LensCatalogItem) -> Color {
        switch item.accentRole {
        case .graphite: return DS.graphite
        case .brick: return DS.brick
        case .accent: return DS.accent
        case .principle: return DS.note
        }
    }

    private func completionCard(icon: String, title: String, body: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(DS.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(body)
                    .font(.subheadline.weight(.medium))
            }
        }
        .summarySurface()
    }
}

// MARK: - Card Sub-Views

private enum TodayScrollAnchor {
    static let top = "today-top"
}

private struct LensGlyph: View {
    let lens: ThinkingLens
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isSelected ? lens.tint : lens.tint.opacity(0.12))
                .frame(width: 38, height: 38)
            Image(systemName: lens.symbolName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isSelected ? .white : lens.tint)
        }
    }
}

private struct AIGenerationProgressView: View {
    let isUsingAI: Bool
    let cardCount: Int
    let streamingCards: [StreamingCardDraft]
    let statusText: String
    let failureMessage: String?
    let canRetry: Bool
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(DS.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isUsingAI ? "正在流式整理" : "使用本地规则生成")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.ink)
                        Text(statusText.isEmpty ? fallbackStatusText : statusText)
                            .font(.caption)
                            .foregroundStyle(DS.mutedInk)
                    }
                    Spacer()
                }

                ProgressView(value: progressValue)
                    .tint(DS.accent)
                    .progressViewStyle(.linear)
            }
            .summarySurface()

            if !streamingCards.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(streamingCards) { card in
                        StreamingCardPreview(card: card)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                    }
                }
                .animation(.easeOut(duration: 0.18), value: streamingCards)
            }

            VStack(alignment: .leading, spacing: 10) {
                generationStep(
                    title: "连接模型流",
                    subtitle: isUsingAI ? "接收受控卡片标签，不展示聊天流。" : "未配置可用 API 时使用本地 fallback。",
                    state: streamingCards.isEmpty && cardCount == 0 ? .active : .done
                )
                generationStep(
                    title: "闭合候选卡片",
                    subtitle: closedCount > 0 ? "已闭合 \(closedCount) 张候选卡片。" : "等待第一张卡片闭合。",
                    state: closedCount > 0 ? .done : .active
                )
                generationStep(
                    title: "等待你确认",
                    subtitle: "确认后的卡片才会进入追问、任务和历史证据。",
                    state: cardCount > 0 ? .active : .pending
                )
            }

            if let failureMessage, !failureMessage.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("本次使用了 fallback", systemImage: "exclamationmark.triangle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.caution)
                    Text(failureMessage)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                    if canRetry {
                        Button {
                            retry()
                        } label: {
                            Label("重试当前步骤", systemImage: "arrow.clockwise")
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .summarySurface()
            }
        }
    }

    private var progressValue: Double {
        if cardCount > 0 { return 0.86 }
        if closedCount > 0 { return 0.68 }
        if !streamingCards.isEmpty { return 0.48 }
        return 0.28
    }

    private var closedCount: Int {
        streamingCards.compactMap(\.domainCard).count
    }

    private var fallbackStatusText: String {
        isUsingAI ? "等待第一张候选卡片。" : "未配置可用 API 时，先给出可编辑的本地卡片。"
    }

    private func generationStep(title: String, subtitle: String, state: AIGenerationStepState) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: state.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(state.color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
            }
        }
    }
}

private struct StreamingCardPreview: View {
    let card: StreamingCardDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(typeColor)
                    .frame(width: 7, height: 7)
                Text(typeTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(typeColor)
                Spacer()
                statusLabel
            }

            Text(card.title.streamingPreviewTrimmed.streamingPreviewIfEmpty("正在生成标题..."))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.ink)
                .contentTransition(.opacity)

            Text(card.body.streamingPreviewTrimmed.streamingPreviewIfEmpty("正在接收正文..."))
                .font(.subheadline)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
        .thinkingCardSurface(type: card.previewType, isExcluded: false)
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch card.status {
        case .receiving:
            Label("接收中", systemImage: "dot.radiowaves.left.and.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DS.accent)
        case .closed:
            Label("已闭合", systemImage: "checkmark.circle.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DS.success)
        case .invalid:
            Label("未完成", systemImage: "exclamationmark.circle")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DS.caution)
        }
    }

    private var typeTitle: String {
        card.previewType.title
    }

    private var typeColor: Color {
        card.previewType.color
    }
}

private extension StreamingCardDraft {
    var previewType: ThinkingCardType {
        ThinkingCardType(rawValue: cardTypeNormalizedRawValue) ?? .idea
    }

    private var cardTypeNormalizedRawValue: String {
        cardTypeRawValue
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private var cardTypeRawValue: String {
        type.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    var streamingPreviewTrimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func streamingPreviewIfEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}

private enum AIGenerationStepState {
    case done
    case active
    case pending

    var symbolName: String {
        switch self {
        case .done: return "checkmark.circle.fill"
        case .active: return "circle.dotted"
        case .pending: return "circle"
        }
    }

    var color: Color {
        switch self {
        case .done: return DS.success
        case .active: return DS.accent
        case .pending: return DS.mutedInk.opacity(0.45)
        }
    }
}

private extension ThinkingLens {
    var shortLabel: String { catalogItem.shortLabel }
    var methodLine: String { catalogItem.methodLine }
    var symbolName: String { catalogItem.symbolName }

    var tint: Color {
        switch catalogItem.accentRole {
        case .graphite: return DS.graphite
        case .brick: return DS.brick
        case .accent: return DS.accent
        case .principle: return DS.graphite
        }
    }
}

private extension PriorityLevel {
    var displayTitle: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
}

private extension SensitivityLevel {
    var displayTitle: String {
        switch self {
        case .normal: return "普通"
        case .possiblySensitive: return "可能敏感"
        case .sensitive: return "敏感"
        }
    }
}

private struct BriefRow: View {
    let title: String
    private let text: String
    var accent: Color = DS.mutedInk

    init(title: String, body: String, accent: Color = DS.mutedInk) {
        self.title = title
        self.text = body
        self.accent = accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(DS.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CaptureTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textColor = UIColor.label
        textView.tintColor = UIColor(DS.accent)
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 14, left: 10, bottom: 14, right: 10)
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.markedTextRange == nil && textView.text != text {
            textView.text = text
        }

        if isFocused && !textView.isFirstResponder {
            textView.becomeFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding private var text: String
        @Binding private var isFocused: Bool

        init(text: Binding<String>, isFocused: Binding<Bool>) {
            _text = text
            _isFocused = isFocused
        }

        func textViewDidChange(_ textView: UITextView) {
            guard textView.markedTextRange == nil else { return }
            text = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.markedTextRange == nil {
                text = textView.text
            }
            isFocused = false
        }
    }
}

private struct ThinkingCardRow: View {
    let card: ThinkingCard
    let update: (ThinkingCardType, String, String, PriorityLevel, SensitivityLevel) -> Void
    let confirm: () -> Void
    let exclude: () -> Void
    let delete: () -> Void
    @State private var isEditing = false
    @State private var draftType: ThinkingCardType
    @State private var draftTitle: String
    @State private var draftBody: String
    @State private var draftPriority: PriorityLevel
    @State private var draftSensitivity: SensitivityLevel

    init(
        card: ThinkingCard,
        update: @escaping (ThinkingCardType, String, String, PriorityLevel, SensitivityLevel) -> Void,
        confirm: @escaping () -> Void,
        exclude: @escaping () -> Void,
        delete: @escaping () -> Void
    ) {
        self.card = card
        self.update = update
        self.confirm = confirm
        self.exclude = exclude
        self.delete = delete
        _draftType = State(initialValue: card.type)
        _draftTitle = State(initialValue: card.title)
        _draftBody = State(initialValue: card.body)
        _draftPriority = State(initialValue: card.priority)
        _draftSensitivity = State(initialValue: card.sensitivity)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(card.type.color)
                    .frame(width: 7, height: 7)

                Text(card.type.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(card.type.color)

                Text("重要性 \(card.priority.displayTitle)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(DS.surface, in: Capsule())

                if card.sensitivity != .normal {
                    Text(card.sensitivity.displayTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.caution)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(DS.caution.opacity(0.10), in: Capsule())
                }

                Spacer()

                Image(systemName: card.isConfirmed ? "checkmark.square.fill" : "square")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(card.isConfirmed ? DS.success : DS.mutedInk.opacity(0.55))
            }

            if isEditing {
                EditableField(title: "标题", text: $draftTitle)
                EditableField(title: "内容", text: $draftBody, axis: .vertical)
                Picker("类型", selection: $draftType) {
                    ForEach(ThinkingCardType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.menu)
                Picker("重要性", selection: $draftPriority) {
                    Text("低").tag(PriorityLevel.low)
                    Text("中").tag(PriorityLevel.medium)
                    Text("高").tag(PriorityLevel.high)
                }
                .pickerStyle(.segmented)
                Picker("敏感性", selection: $draftSensitivity) {
                    Text("普通").tag(SensitivityLevel.normal)
                    Text("可能敏感").tag(SensitivityLevel.possiblySensitive)
                    Text("敏感").tag(SensitivityLevel.sensitive)
                }
                .pickerStyle(.segmented)
            } else {
                Text(card.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(card.body)
                    .font(.subheadline)
                    .foregroundStyle(DS.mutedInk)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button(isEditing ? "保存编辑" : "编辑") {
                    if isEditing {
                        update(draftType, draftTitle, draftBody, draftPriority, draftSensitivity)
                    }
                    isEditing.toggle()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)

                Button(card.isConfirmed ? "已确认" : "确认", action: confirm)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(DS.accent)
                    .accessibilityIdentifier(TodayAutomationID.cardConfirmAction)
                Button(card.isExcludedFromModel ? "已排除" : "排除", action: exclude)
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(TodayAutomationID.cardExcludeAction)
                Button("删除", role: .destructive, action: delete)
                    .font(.caption)
                    .buttonStyle(.bordered)
            }
        }
        .thinkingCardSurface(type: card.type, isExcluded: card.isExcludedFromModel)
        .opacity(card.isExcludedFromModel ? 0.5 : 1)
    }
}

private struct QuestionCardView: View {
    let question: ReflectionQuestion
    @Binding var answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "scope")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.accent)
                Text("透镜追问")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.accentInk)
            }

            Text(question.question)
                .font(.headline.weight(.semibold))
                .foregroundStyle(DS.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(question.whyItMatters)
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            TextField("写下你的判断，不需要完整答案", text: $answer, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .padding(12)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
                .accessibilityIdentifier(TodayAutomationID.questionAnswerField)
        }
        .questionSurface()
    }
}

private struct QuestCardView: View {
    let quest: Quest
    let update: (String, String, String, String, String) -> Void
    @State private var isEditing = false
    @State private var draftTitle: String
    @State private var draftWhy: String
    @State private var draftCriteria: String
    @State private var draftResistance: String
    @State private var draftQuestion: String

    init(
        quest: Quest,
        update: @escaping (String, String, String, String, String) -> Void
    ) {
        self.quest = quest
        self.update = update
        _draftTitle = State(initialValue: quest.title)
        _draftWhy = State(initialValue: quest.whyItMatters)
        _draftCriteria = State(initialValue: quest.completionCriteria)
        _draftResistance = State(initialValue: quest.expectedResistance)
        _draftQuestion = State(initialValue: quest.reflectionQuestion)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(quest.type.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(quest.type == .main ? DS.accent : .secondary)
                Spacer()
                Button(isEditing ? "保存" : "编辑") {
                    if isEditing {
                        update(draftTitle, draftWhy, draftCriteria, draftResistance, draftQuestion)
                    }
                    isEditing.toggle()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .accessibilityIdentifier(TodayAutomationID.questEditAction)
            }

            if isEditing {
                EditableField(title: "任务标题", text: $draftTitle)
                EditableField(title: "为什么重要", text: $draftWhy, axis: .vertical)
                EditableField(title: "完成标准", text: $draftCriteria, axis: .vertical)
                EditableField(title: "预期阻力", text: $draftResistance, axis: .vertical)
                EditableField(title: "复盘问题", text: $draftQuestion, axis: .vertical)
            } else {
                Text(quest.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    BriefRow(title: "为什么重要", body: quest.whyItMatters, accent: quest.type == .main ? DS.accent : DS.mutedInk)
                    BriefRow(title: "完成标准", body: quest.completionCriteria, accent: quest.type == .main ? DS.accent : DS.mutedInk)
                    BriefRow(title: "预期阻力", body: quest.expectedResistance, accent: DS.caution)
                    BriefRow(title: "回看问题", body: quest.reflectionQuestion, accent: DS.graphite)
                }
            }
        }
        .questSurface(isMain: quest.type == .main)
    }
}

private struct PrincipleCardView: View {
    let principle: PrincipleAsset
    let update: (String, String, String, String, String, String) -> Void
    @State private var isEditing = false
    @State private var draftTitle: String
    @State private var draftSummary: String
    @State private var draftTrigger: String
    @State private var draftActions: String
    @State private var draftCriteria: String
    @State private var draftExceptions: String

    init(
        principle: PrincipleAsset,
        update: @escaping (String, String, String, String, String, String) -> Void
    ) {
        self.principle = principle
        self.update = update
        _draftTitle = State(initialValue: principle.title)
        _draftSummary = State(initialValue: principle.summary)
        _draftTrigger = State(initialValue: principle.triggerContext)
        _draftActions = State(initialValue: principle.actions.joined(separator: "\n"))
        _draftCriteria = State(initialValue: principle.successCriteria)
        _draftExceptions = State(initialValue: principle.exceptions)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb")
                    .font(.caption)
                    .foregroundStyle(DS.accent)
                Text("原则候选")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                Spacer()
                Button(isEditing ? "保存" : "编辑") {
                    if isEditing {
                        update(draftTitle, draftSummary, draftTrigger, draftActions, draftCriteria, draftExceptions)
                    }
                    isEditing.toggle()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
            }

            if isEditing {
                EditableField(title: "标题", text: $draftTitle)
                EditableField(title: "摘要", text: $draftSummary, axis: .vertical)
                EditableField(title: "触发场景", text: $draftTrigger, axis: .vertical)
                EditableField(title: "行动步骤", text: $draftActions, axis: .vertical)
                EditableField(title: "成功标准", text: $draftCriteria, axis: .vertical)
                EditableField(title: "例外条件", text: $draftExceptions, axis: .vertical)
            } else {
                Text(principle.title)
                    .font(.subheadline.weight(.semibold))
                Text(principle.summary)
                    .font(.subheadline)
                    .foregroundStyle(DS.mutedInk)

                Text("适用场景：\(principle.triggerContext)")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
            }
        }
        .principleSurface()
    }
}

private struct EditableField: View {
    let title: String
    @Binding var text: String
    var axis: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
            TextField(title, text: $text, axis: axis)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .padding(10)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
        }
    }
}

private struct FlowPills: View {
    let items: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DS.surface, in: Capsule())
            }
        }
    }
}

private struct EmptyStateCard: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(DS.mutedInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .summarySurface()
    }
}

private struct ReferencedPrinciplesView: View {
    let principles: [PrincipleAsset]
    let onFeedback: (PrincipleAsset, PrincipleRecallFeedbackValue) -> Void

    @ViewBuilder
    var body: some View {
        if !principles.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "quote.bubble")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.accent)
                    Text("本次参考的原则")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.ink)
                    Spacer()
                    Text("仅作对照")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DS.surface, in: Capsule())
                }

                ForEach(principles) { principle in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(principle.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.ink)
                        Text(principle.triggerContext)
                            .font(.caption)
                            .foregroundStyle(DS.mutedInk)
                            .lineLimit(2)
                        HStack(spacing: 8) {
                            Button {
                                onFeedback(principle, .helpful)
                            } label: {
                                Label("有帮助", systemImage: "hand.thumbsup")
                            }
                            .accessibilityIdentifier(TodayAutomationID.principleFeedbackHelpfulAction)

                            Button {
                                onFeedback(principle, .notApplicable)
                            } label: {
                                Label("不适用", systemImage: "xmark.circle")
                            }
                            .accessibilityIdentifier(TodayAutomationID.principleFeedbackNotApplicableAction)

                            Button {
                                onFeedback(principle, .misrecalled)
                            } label: {
                                Label("误召回", systemImage: "exclamationmark.bubble")
                            }
                            .accessibilityIdentifier(TodayAutomationID.principleFeedbackMisrecalledAction)
                        }
                        .font(.caption2.weight(.semibold))
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(14)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                    .stroke(DS.accent.opacity(0.14), lineWidth: 1)
            )
        }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
