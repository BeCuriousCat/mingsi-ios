import SwiftUI
import UIKit

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @State private var isCaptureFocused = false

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
                    .padding(.top, 12)
                    .padding(.bottom, 112)
                }
                .scrollIndicators(.hidden)
                .pageBackground()
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    actionRow
                }
            }
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

    // Purpose: Pick a thinking lens to challenge assumptions
    // Design: Lens name + one-line reason, feels like choosing a perspective
    private var selectLensSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepLabel("思考透镜", subtitle: "选择一个角度，让问题从另一面被看见。")

            ForEach(ThinkingLens.allCases) { lens in
                lensCard(lens)
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
                ReferencedPrinciplesView(principles: store.referencedPrinciples)
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
                ReferencedPrinciplesView(principles: store.referencedPrinciples)
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
            .disabled(store.isAIRunning)

            HStack(spacing: 18) {
                if let previousState {
                    Button("上一步") {
                        store.navigateTodayLoop(to: previousState)
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
                }

                if canSupplementCapture {
                    Button("补充材料") {
                        store.navigateTodayLoop(to: .capture)
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DS.accent)
                }

                if store.canRetryCurrentAI {
                    Button("重试当前步骤") {
                        store.retryCurrentAIStep()
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DS.accent)
                }

                if store.todayDraft.state == .extractPrinciple {
                    Button("跳过原则") {
                        store.skipPrinciple()
                    }
                    .font(.subheadline)
                }

                Button("重置今日") {
                    store.resetTodayLoop()
                }
                .font(.footnote)
                .foregroundStyle(DS.mutedInk)
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
                store.questions.first(where: { $0.id == questionID })?.answer ?? store.questions[index].answer
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

    private func lensCard(_ lens: ThinkingLens) -> some View {
        Button(action: { store.selectThinkingLens(lens) }) {
            HStack(alignment: .top, spacing: 13) {
                LensGlyph(lens: lens, isSelected: store.todayDraft.selectedLens == lens)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(lens.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(DS.ink)
                        Text(lens.shortLabel)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(lens.tint)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(lens.tint.opacity(0.10), in: Capsule())
                    }
                    Text(lens.subtitle)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(lens.methodLine)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(lens.tint)
                        .padding(.top, 2)
                }

                Spacer()

                if store.todayDraft.selectedLens == lens {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(DS.cardInnerPadding)
        .background(
            store.todayDraft.selectedLens == lens ? lens.tint.opacity(0.08) : Color(.systemBackground),
            in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(lens.tint)
                .frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(store.todayDraft.selectedLens == lens ? lens.tint.opacity(0.32) : Color.primary.opacity(0.05), lineWidth: 1)
        )
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
    var shortLabel: String {
        switch self {
        case .evidenceCheck: return "事实"
        case .opposingView: return "反证"
        case .leverageAnalysis: return "杠杆"
        }
    }

    var methodLine: String {
        switch self {
        case .evidenceCheck: return "先问：我知道什么，还是我以为什么？"
        case .opposingView: return "先问：如果我错了，证据会长什么样？"
        case .leverageAnalysis: return "先问：哪一步最能改变结果？"
        }
    }

    var symbolName: String {
        switch self {
        case .evidenceCheck: return "checklist"
        case .opposingView: return "arrow.left.arrow.right"
        case .leverageAnalysis: return "point.topleft.down.curvedto.point.bottomright.up"
        }
    }

    var tint: Color {
        switch self {
        case .evidenceCheck: return DS.graphite
        case .opposingView: return DS.brick
        case .leverageAnalysis: return DS.accent
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(card.type.color)
                    .frame(width: 8, height: 8)

                Text(card.type.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if card.isConfirmed {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(DS.success)
                }
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
                    .font(.subheadline.weight(.semibold))
                Text(card.body)
                    .font(.subheadline)
                    .foregroundStyle(DS.mutedInk)
            }

            HStack(spacing: 8) {
                Button(isEditing ? "保存编辑" : "编辑") {
                    if isEditing {
                        update(draftType, draftTitle, draftBody, draftPriority, draftSensitivity)
                    }
                    isEditing.toggle()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)

                Button("确认", action: confirm)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(DS.accent)
                Button(card.isExcludedFromModel ? "已排除" : "排除", action: exclude)
                    .font(.caption)
                    .buttonStyle(.bordered)
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
        VStack(alignment: .leading, spacing: 10) {
            Text(question.question)
                .font(.subheadline.weight(.semibold))
            Text(question.whyItMatters)
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
            TextField("在这里回答", text: $answer, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
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
            }

            if isEditing {
                EditableField(title: "任务标题", text: $draftTitle)
                EditableField(title: "为什么重要", text: $draftWhy, axis: .vertical)
                EditableField(title: "完成标准", text: $draftCriteria, axis: .vertical)
                EditableField(title: "预期阻力", text: $draftResistance, axis: .vertical)
                EditableField(title: "复盘问题", text: $draftQuestion, axis: .vertical)
            } else {
                Text(quest.title)
                    .font(.subheadline.weight(.semibold))

                VStack(alignment: .leading, spacing: 4) {
                    Text("完成标准")
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                    Text(quest.completionCriteria)
                        .font(.subheadline)
                }

                Text("阻力：\(quest.expectedResistance)")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text(principle.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.ink)
                        Text(principle.triggerContext)
                            .font(.caption)
                            .foregroundStyle(DS.mutedInk)
                            .lineLimit(2)
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
