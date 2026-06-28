import SwiftUI
import UIKit

enum TodayAutomationID {
    static let primaryAction = "today.primary-action"
    static let primaryActionHint = "today.primary-action-hint"
    static let previousAction = "today.previous-action"
    static let supplementCaptureAction = "today.supplement-capture-action"
    static let returnToReviewForJudgmentAction = "today.return-to-review-for-judgment-action"
    static let retryCurrentStepAction = "today.retry-current-step-action"
    static let skipPrincipleAction = "today.skip-principle-action"
    static let resetAction = "today.reset-action"
    static let cardConfirmAction = "today.card.confirm-action"
    static let cardExcludeAction = "today.card.exclude-action"
    static let trainingPrescriptionAcceptAction = "today.training-prescription.accept-action"
    static let trainingPrescriptionSkipAction = "today.training-prescription.skip-action"
    static let trainingPrescriptionOverrideAudit = "today.training-prescription.override-audit"
    static let trainingPrescriptionDecisionOverrideAudit = "today.training-prescription.decision-override-audit"
    static let coachDiagnosisAcceptAction = "today.coach-diagnosis.accept-action"
    static let coachDiagnosisSlowDownAction = "today.coach-diagnosis.slow-down-action"
    static let coachDiagnosisOverrideProgressAction = "today.coach-diagnosis.override-progress-action"
    static let questionAnswerField = "today.question.answer-field"
    static let questEditAction = "today.quest.edit-action"
    static let questTrainingPrinciplePicker = "today.quest.training-principle-picker"
    static let principleFeedbackNoteField = "today.principle.feedback.note-field"
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

private struct LoopBoundaryCopy {
    let title: String
    let body: String
    let icon: String
    let tint: Color
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
                        loopBoundaryHint

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

    private var loopBoundaryHint: some View {
        let boundary = currentLoopBoundary
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: boundary.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(boundary.tint)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(boundary.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(boundary.tint)
                Text(boundary.body)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(boundary.tint.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(boundary.tint.opacity(0.12), lineWidth: 1)
        )
    }

    private var currentLoopBoundary: LoopBoundaryCopy {
        switch store.todayDraft.state {
        case .verifyYesterday:
            return LoopBoundaryCopy(
                title: "闭环二：结果校准",
                body: "只回看昨天设计的验证行动：做没做、有没有价值、判断如何更新；完成后才进入今天内容。",
                icon: "scope",
                tint: DS.caution
            )
        case .reviewQuests, .extractPrinciple, .sessionComplete:
            return LoopBoundaryCopy(
                title: "闭环二：明日验证与结果校准",
                body: "把今日复盘后的一个判断变成明天的验证行动；明天回来只校准结果，不继续写今天复盘。",
                icon: "flag.checkered",
                tint: DS.success
            )
        case .capture, .organizing, .reviewCards, .selectMode, .selectLens, .answerQuestions:
            return LoopBoundaryCopy(
                title: "闭环一：今天内容与今日复盘",
                body: "先把今天发生了什么、你怎么做、你怎么想讲清楚；这里只完成理解，不设计明天行动。",
                icon: "person.text.rectangle",
                tint: DS.brick
            )
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
        VStack(alignment: .leading, spacing: 10) {
            loopProgressGroup(
                title: "今日理解闭环",
                route: "今天内容 → 今日复盘",
                states: [.capture, .organizing, .reviewCards, .selectMode, .selectLens, .answerQuestions],
                tint: DS.brick,
                scrollToTop: scrollToTop
            )

            loopProgressGroup(
                title: "行动验证闭环",
                route: "明日验证 → 结果校准",
                states: [.reviewQuests, .extractPrinciple, .sessionComplete, .verifyYesterday],
                tint: DS.success,
                scrollToTop: scrollToTop
            )

            Text(progressCaption)
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
        }
        .padding(.top, 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: scrollToTop)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("今日流程进度")
        .accessibilityHint("点按返回今日顶部")
    }

    private func loopProgressGroup(
        title: String,
        route: String,
        states: [DailyLoopState],
        tint: Color,
        scrollToTop: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                Text(route)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                ForEach(states) { state in
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
                            .frame(height: 7)
                            .opacity(store.canNavigateTodayLoop(to: state) || state == store.todayDraft.state ? 1 : 0.5)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("回到\(state.title)")
                    .accessibilityHint(store.canNavigateTodayLoop(to: state) ? "点按回到该步骤编辑" : "该步骤暂不可返回")
                }
            }
        }
    }

    // MARK: - Verify Yesterday

    // Purpose: Close yesterday's loop before starting fresh
    // Design: Warm, reflective - not a form, a moment of honesty
    private var verifyYesterdaySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            phaseBoundaryCard(
                title: "结果校准",
                body: "先校准昨天的明日验证，再开始收集今天的新材料。",
                icon: "scope",
                tint: DS.caution
            )
            BriefRow(
                title: "本页只校准昨天结果",
                body: "只检查做没做、有没有实际价值、昨天判断要不要更新；新的今日内容在下一段填写。",
                accent: DS.caution
            )

            stepLabel("校准昨日验证", subtitle: "用一个真实结果校准昨天的判断。")

            if let quest = store.mainQuest ?? store.quests.first {
                VStack(alignment: .leading, spacing: 6) {
                    Text("昨日验证行动")
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

            VStack(alignment: .leading, spacing: 8) {
                Text("昨天判断怎么更新？")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 10) {
                    ForEach(YesterdayJudgmentUpdate.allCases) { update in
                        choiceChip(
                            title: update.title,
                            isSelected: store.todayDraft.yesterdayJudgmentUpdate == update,
                            action: { store.selectYesterdayJudgmentUpdate(update) }
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
            phaseBoundaryCard(
                title: "今天内容",
                body: "这里只收集今天内容：事实、动作、感受和想法；先不复盘，也不写明天。",
                icon: "text.bubble",
                tint: DS.accent
            )
            BriefRow(
                title: "本页只写今天内容",
                body: "把发生了什么、你怎么做、你怎么想先讲清楚；明思会在今日复盘里观察你漏掉了什么。",
                accent: DS.accent
            )

            stepLabel("今天发生了什么？", subtitle: "先收集原始材料，后面再由明思做教练观察。")

            reviewScaffoldView

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

    private var reviewScaffoldView: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text("基础能力训练")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
                    .textCase(.uppercase)
                Text("不是让 AI 替你总结，而是训练你把复杂事情说清、想清、安排清。")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                trainingPill("沟通力")
                trainingPill("思考力")
                trainingPill("执行力")
                Spacer(minLength: 0)
            }

            Text("讲清楚一件事")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.ink)

            BriefRow(title: "发生了什么", body: "先把背景、触发点、关键人物或对象讲清楚。", accent: DS.accent)
            BriefRow(title: "我怎么做", body: "写出你的动作、选择、沟通或没有做的事。", accent: DS.brick)
            BriefRow(title: "我怎么想", body: "说明当时基于哪些事实、假设、目标或取舍做判断。", accent: DS.caution)
            BriefRow(title: "问题类型", body: "先判断这是对象理解、目标不清、证据不足、协作断点、执行约束，还是反馈缺失。", accent: DS.graphite)
            BriefRow(title: "复盘问题", body: "最后写一个想追问自己的问题，让后续分析知道该从哪里切入。", accent: DS.success)

            VStack(alignment: .leading, spacing: 6) {
                Text("训练要点")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
                    .textCase(.uppercase)
                HStack(spacing: 6) {
                    trainingSkillTag("描述力")
                    trainingSkillTag("观察力")
                    trainingSkillTag("分析力")
                }
                HStack(spacing: 6) {
                    trainingSkillTag("判断力")
                    trainingSkillTag("执行力")
                    trainingSkillTag("校准力")
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
    }

    private func trainingPill(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(DS.accent)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(DS.accent.opacity(0.10), in: Capsule())
    }

    private func trainingSkillTag(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(DS.mutedInk)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.04), in: Capsule())
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
        let prescription = store.trainingPrescription
        let recommendedItem = prescription.flatMap { lensItem(for: $0.recommendedLensId) }
            ?? BuiltinLensCatalog.library.recommendedItem(
                for: confirmedCards,
                mode: store.todayDraft.sessionMode
            )
        let builtInItems = ThinkingLens.allCases
            .sorted { $0.catalogItem.methodIndex < $1.catalogItem.methodIndex }
            .map(\.catalogItem)

        return VStack(alignment: .leading, spacing: 14) {
            stepLabel("训练处方", subtitle: "先由明思判断主训练焦点，再接受、改选或跳过。")

            todayLensCoreCard(confirmedCount: confirmedCards.count)

            if let diagnosis = store.coachDiagnosis {
                coachDiagnosisCard(diagnosis, turnState: store.coachTurnState)
            }

            if let prescription, let recommendedItem {
                trainingPrescriptionCard(
                    prescription,
                    item: recommendedItem,
                    teachingPlan: store.coachTurnState.map {
                        CoachTeachingPolicy().makePlan(turn: $0, prescription: prescription)
                    }
                )
            }

            HStack(spacing: 10) {
                lensActionCard(
                    icon: "wand.and.stars",
                    title: "生成替代透镜",
                    body: "基于已确认卡片生成本次专属方法卡。",
                    tint: DS.brick
                ) {
                    let item = store.generateCustomLensFromConfirmedCards()
                    store.selectCustomLens(item.id)
                }
                .accessibilityIdentifier(TodayAutomationID.lensGenerateAction)

                lensActionCard(
                    icon: "square.and.pencil",
                    title: "手写替代透镜",
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
                    lensMethodTile(item, isRecommended: item.id == prescription?.recommendedLensId)
                }
            }
        }
    }

    // MARK: - Answer Questions

    // Purpose: Answer coaching questions to sharpen thinking
    // Design: Each question is a card with answer field, inviting not interrogating
    private var answerQuestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            phaseBoundaryCard(
                title: "今日复盘",
                body: "明思观察你怎么讲述、判断和跳步，再指出当前最该补的思考材料。",
                icon: "person.text.rectangle",
                tint: DS.brick
            )
            BriefRow(
                title: "本页只复盘今天",
                body: "这里只修补今天材料里的讲述、证据和判断缺口；明天的验证行动会在明日验证里设计。",
                accent: DS.brick
            )

            stepLabel("教练追问", subtitle: "至少回答一个，训练不是让 AI 替你下结论。")
            observationTrainingFrame(
                CoachObservationPolicy().observe(cards: store.thinkingCards)
            )

            if let feedback = store.coachAnswerTrainingFeedback {
                answerFeedbackPreviewView(feedback)
            } else if let teachingPlan = store.coachTurnState.map({
                CoachTeachingPolicy().makePlan(
                    turn: $0,
                    prescription: store.trainingPrescription
                )
            }) {
                teachingRouteView(teachingPlan)
            }

            if !store.referencedPrinciples.isEmpty {
                ReferencedPrinciplesView(
                    principles: store.referencedPrinciples,
                    retrievalReason: store.referencedPrincipleRetrievalReason,
                    retrievalSignalText: store.referencedPrincipleRetrievalSignalText,
                    onFeedback: recordReferencedPrincipleFeedback
                )
            }

            ForEach(Array(store.questions.enumerated()), id: \.element.id) { index, question in
                QuestionCardView(question: question, answer: bindingForQuestion(questionID: question.id, fallbackIndex: index))
            }
        }
    }

    private func observationTrainingFrame(_ observation: CoachObservation) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            BriefRow(
                title: "能力训练诊断",
                body: "本轮主练：\(observation.trainingAbility.trainingTitle)。\(observation.trainingAbility.coachingMeaning)",
                accent: DS.accent
            )
            BriefRow(
                title: "材料分离训练",
                body: "事实、感受、解释、判断、行动",
                accent: DS.caution
            )
            BriefRow(title: "讲述训练", body: observation.narrativeTrainingLine, accent: DS.accent)
            materialInventoryRows(for: observation)
            BriefRow(title: "我观察到", body: observation.feedback.observed, accent: DS.accent)
            BriefRow(title: "当前主要缺口", body: observation.feedback.diagnosis, accent: DS.brick)
            BriefRow(title: "本轮训练", body: observation.feedback.training, accent: DS.caution)
            BriefRow(title: "请你补充", body: observation.feedback.ask, accent: DS.accent)
            BriefRow(title: "推进标准", body: observation.feedback.proceedWhen, accent: DS.success)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func materialInventoryRows(for observation: CoachObservation) -> some View {
        BriefRow(
            title: "已说清",
            body: materialLine(for: observation.providedMaterials, fallback: "还没有足够材料"),
            accent: DS.success
        )
        BriefRow(
            title: "先补",
            body: materialLine(for: observation.missingMaterials, fallback: "暂无明确缺口"),
            accent: DS.brick
        )
    }

    private func materialLine(
        for materials: [CoachObservationMaterial],
        fallback: String
    ) -> String {
        let titles = materials
            .map(\.displayTitle)
            .filter { !$0.isEmpty }
        return titles.isEmpty ? fallback : titles.joined(separator: "、")
    }

    private func answerFeedbackPreviewView(_ feedback: CoachAnswerTrainingFeedback) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            BriefRow(
                title: "你刚补上",
                body: feedback.repairedLine,
                accent: DS.success
            )
            BriefRow(
                title: "当前仍缺",
                body: feedback.missingLine,
                accent: feedback.canProceedToValidation ? DS.success : DS.brick
            )
            BriefRow(
                title: "能否进入明日验证",
                body: feedback.proceedLine,
                accent: feedback.canProceedToValidation ? DS.success : DS.caution
            )
            BriefRow(
                title: "能力修补",
                body: feedback.trainingTargetLine,
                accent: DS.caution
            )
            BriefRow(title: "下一句修补", body: feedback.nextRepairQuestion, accent: DS.brick)
            BriefRow(title: "过往经验复现", body: feedback.experienceReplayPrompt, accent: DS.graphite)
            BriefRow(
                title: "判断句训练",
                body: feedback.judgmentSentencePrompt,
                accent: DS.success
            )
            teachingRouteView(feedback.teachingPlan)
        }
    }

    private func phaseBoundaryCard(title: String, body: String, icon: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(tint.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .textCase(.uppercase)
                Text(body)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        )
    }

    // MARK: - Review Quests

    // Purpose: Review tomorrow's action plan
    // Design: Quest cards feel actionable, main quest is visually prominent
    private var reviewQuestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            phaseBoundaryCard(
                title: "明日验证",
                body: "今日复盘已结束；下面把今天的判断转成明天可验证的行动，不是继续写总结。",
                icon: "flag.checkered",
                tint: DS.success
            )
            BriefRow(
                title: "明天怎么回看",
                body: "明天回到结果校准时，只检查做没做、有没有实际价值、判断要不要更新。",
                accent: DS.caution
            )
            BriefRow(
                title: "本页只设计明天的验证行动",
                body: "写明天能完成、能检查、能校准今天一个判断的一步；不要继续补今天的复盘。",
                accent: DS.success
            )
            BriefRow(
                title: "今日复盘交接点",
                body: "今天内容和今日复盘已经收束；这里不再补材料，只把一个待验证判断交给明天。",
                accent: DS.accent
            )

            reviewQuestJudgmentAnchor

            stepLabel("设计明日验证", subtitle: "验证行动必须验证今天的一个判断，并有明确完成标准。")

            if !store.referencedPrinciples.isEmpty {
                ReferencedPrinciplesView(
                    principles: store.referencedPrinciples,
                    retrievalReason: store.referencedPrincipleRetrievalReason,
                    retrievalSignalText: store.referencedPrincipleRetrievalSignalText,
                    onFeedback: recordReferencedPrincipleFeedback
                )
            }

            ForEach(store.quests) { quest in
                QuestCardView(
                    quest: quest,
                    trainingTarget: store.questTrainingTarget(for: quest.id),
                    trainingPrinciples: store.activePrinciples,
                    selectTrainingPrinciple: { principleID in
                        store.updateQuestTrainingPrinciple(principleID, for: quest.id)
                    },
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

    private var reviewQuestJudgmentAnchor: some View {
        let target = mainQuestCalibrationTarget
        return VStack(alignment: .leading, spacing: 9) {
            BriefRow(
                title: "今天待验证判断",
                body: target ?? "还没有明确的待验证判断。请回到今日复盘，把一个判断写成明天能观察的信号。",
                accent: target == nil ? DS.caution : DS.accent
            )
            BriefRow(
                title: "下面的验证行动只验证这个判断",
                body: "明日验证不是普通待办，也不是继续总结今天；它只负责让明天的结果能校准这条判断。",
                accent: DS.success
            )
            if target == nil {
                Button {
                    store.navigateTodayLoop(to: .answerQuestions)
                } label: {
                    Label("回到今日复盘补判断", systemImage: "arrow.uturn.backward")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(DS.caution)
                .accessibilityIdentifier(TodayAutomationID.returnToReviewForJudgmentAction)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke((target == nil ? DS.caution : DS.accent).opacity(0.16), lineWidth: 1)
        )
    }

    private var mainQuestCalibrationTarget: String? {
        let mainTarget = store.mainQuest?.calibrationTarget?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let mainTarget, !mainTarget.isEmpty {
            return mainTarget
        }

        return store.quests
            .compactMap { $0.calibrationTarget?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
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
                completionCard(icon: "flag.checkered", title: "明日验证行动", body: mainQuest.title)
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
        case .verifyYesterday: return "保存校准结果"
        case .capture:
            let mode = store.todayDraft.hasSelectedSessionMode ? store.todayDraft.sessionMode.title : "选择模式"
            return "\(mode) 整理成卡片"
        case .organizing: return "查看卡片"
        case .reviewCards: return "确认卡片"
        case .selectMode: return "确认模式"
        case .selectLens: return "进入今日复盘"
        case .answerQuestions: return "设计明日验证"
        case .reviewQuests: return "保存明日验证"
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
        case .verifyYesterday: return "当前：结果校准。只校准昨天验证行动，不补写今天复盘。"
        case .capture: return "当前：今天内容。先讲清发生了什么、怎么做、怎么想。"
        case .organizing: return "当前：材料整理。把输入拆成可确认的思考材料。"
        case .reviewCards: return "当前：材料确认。先确认真实材料，再让教练判断缺口。"
        case .selectMode: return "当前：训练深度。选择今天要练到什么程度。"
        case .selectLens: return "当前：训练处方。由明思判断本轮主训练焦点。"
        case .answerQuestions: return "当前：今日复盘。只修补理解、证据、判断和经验缺口。"
        case .reviewQuests: return "当前：明日验证。把今天一个判断变成明天可验证动作。"
        case .extractPrinciple: return "当前：原则沉淀。只保存可复用的行动准则。"
        case .sessionComplete: return "当前：今日闭环完成。明天回来先做结果校准。"
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
                Text("Coach Observation")
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

            Text("明思不是让你先挑一个滤镜，而是先看你讲述里哪些材料已经说清、哪些关键思考还跳过。")
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 7) {
                BriefRow(title: "明思观察了你的材料", body: "先从已确认卡片里看事实、判断、目标、约束和行动是否齐全。", accent: DS.accent)
                BriefRow(title: "诊断主要缺口", body: "只抓一个当前最该补的漏想点，避免把训练变成泛泛提问。", accent: DS.brick)
                BriefRow(title: "推荐训练处方", body: "透镜只是训练方式；主线是补上没想清的部分，并保留你的改选权。", accent: DS.success)
            }

            observationTrainingFrame(
                CoachObservationPolicy().observe(cards: store.thinkingCards)
            )
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
            return "先看你这次讲述漏掉了什么。"
        }
        return "围绕「\(first.title)」训练没想清的部分。"
    }

    private func trainingPrescriptionCard(
        _ prescription: TrainingPrescription,
        item: LensCatalogItem,
        teachingPlan: CoachTeachingPlan?
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("COACH · \(String(format: "%.0f%%", prescription.confidence * 100))")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(lensTint(for: item))
                Spacer()
                Image(systemName: isLensItemSelected(item) ? "checkmark.circle.fill" : "sparkles")
                    .foregroundStyle(isLensItemSelected(item) ? lensTint(for: item) : DS.mutedInk.opacity(0.62))
            }

            Text(item.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(DS.ink)

            Text(prescription.recommendationReason)
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.methodLine)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(lensTint(for: item))
                .fixedSize(horizontal: false, vertical: true)

            Text("主练：\(prescription.primaryTrainingDimension.displayTitle)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.ink)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(lensTint(for: item).opacity(0.10), in: Capsule())

            if let teachingPlan {
                teachingRouteView(teachingPlan)
            }

            if !prescription.baselineChecks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("底盘检查")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                        .textCase(.uppercase)
                    HStack(spacing: 6) {
                        ForEach(Array(prescription.baselineChecks.prefix(4)), id: \.self) { check in
                            Text(baselineCheckTitle(check))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(DS.mutedInk)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.04), in: Capsule())
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            if let overrideAuditText = trainingOverrideAuditText(prescription) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("改选审计")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(lensTint(for: item))
                        .textCase(.uppercase)

                    Text(overrideAuditText)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(TodayAutomationID.trainingPrescriptionOverrideAudit)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(lensTint(for: item).opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(lensTint(for: item).opacity(0.18), lineWidth: 1)
                )
            }

            HStack(spacing: 10) {
                Button(action: { store.acceptTrainingPrescription() }) {
                    Label("接受推荐", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityIdentifier(TodayAutomationID.trainingPrescriptionAcceptAction)

                Button(action: { store.skipTrainingPrescription() }) {
                    Label("跳过", systemImage: "forward.end")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier(TodayAutomationID.trainingPrescriptionSkipAction)
            }
            .padding(.top, 2)
        }
        .padding(DS.cardInnerPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func teachingRouteView(_ plan: CoachTeachingPlan) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            BriefRow(title: "本轮漏想点", body: plan.missingMoveTitle, accent: DS.brick)
            BriefRow(title: "训练目标", body: plan.trainingTargetTitle, accent: DS.accent)
            BriefRow(title: "为什么不是直接给答案", body: plan.whyNotAnswer, accent: DS.caution)
            BriefRow(title: "推进标准", body: plan.proceedStandard, accent: DS.success)
            BriefRow(title: "教练追问", body: plan.repairQuestion, accent: DS.brick)
            BriefRow(title: "过往经验复现", body: plan.experienceReplayPrompt, accent: DS.graphite)
            experienceReplayDecisionView()

            VStack(alignment: .leading, spacing: 6) {
                Text("训练路线")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
                    .textCase(.uppercase)
                ForEach(Array(plan.routeSteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("\(index + 1)")
                            .font(.caption2.monospacedDigit().weight(.bold))
                            .foregroundStyle(DS.accent)
                            .frame(width: 18, height: 18)
                            .background(DS.accent.opacity(0.10), in: Circle())
                        Text(step)
                            .font(.caption)
                            .foregroundStyle(DS.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let auditNote = plan.auditNote {
                Text(auditNote)
                    .font(.caption2)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
    }

    private func experienceReplayDecisionView() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("经验判断")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DS.mutedInk)
                .textCase(.uppercase)
            ForEach(ExperienceReplayTraining.decisionLines, id: \.self) { line in
                Text(line)
                    .font(.caption)
                    .foregroundStyle(DS.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func coachDiagnosisCard(
        _ diagnosis: CoachDiagnosis,
        turnState: CoachTurnState?
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                Text("教练判断")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DS.brick)
                Spacer()
                Image(systemName: coachDiagnosisIcon(for: diagnosis))
                    .foregroundStyle(DS.brick)
            }

            Text("当前阶段：\(diagnosis.phase.displayTitle)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.ink)

            Text("建议：\(diagnosis.recommendedMove.displayRecommendation)")
                .font(.footnote.weight(.medium))
                .foregroundStyle(DS.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let turnState, !turnState.openEvidenceGaps.isEmpty {
                Text("缺口：\(turnState.openEvidenceGaps.map(\.displayTitle).joined(separator: "、"))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.brick)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(diagnosis.reason)
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            if let turnState {
                Text("轮次：\(turnState.turnSummary)")
                    .font(.caption2)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Button(action: { store.acceptCoachDiagnosis() }) {
                    Label("接受", systemImage: "checkmark.circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier(TodayAutomationID.coachDiagnosisAcceptAction)

                Button(action: { store.slowDownCoachDiagnosis() }) {
                    Label("放慢", systemImage: "pause.circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier(TodayAutomationID.coachDiagnosisSlowDownAction)

                Button(action: { store.overrideCoachDiagnosisToProgress() }) {
                    Label("推进", systemImage: "arrow.right.circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier(TodayAutomationID.coachDiagnosisOverrideProgressAction)
            }
            .padding(.top, 2)
        }
        .padding(DS.cardInnerPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.surfaceStrong, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(DS.brick.opacity(0.24), lineWidth: 1)
        )
    }

    private func coachDiagnosisIcon(for diagnosis: CoachDiagnosis) -> String {
        switch diagnosis.recommendedMove {
        case .askClarifyingQuestion:
            return "questionmark.bubble"
        case .surfaceEvidenceGap:
            return "text.magnifyingglass"
        case .slowDownConvergence:
            return "hourglass"
        case .recommendTrainingLens:
            return "sparkles"
        case .generateQuest:
            return "arrow.right.circle"
        }
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
        VStack(alignment: .leading, spacing: 8) {
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel(item.title)
            .accessibilityValue(lensMethodTileAccessibilityValue(item))
            .padding(12)
            .background(isLensItemSelected(item) ? lensTint(for: item).opacity(0.07) : Color(.systemBackground), in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                    .stroke(isLensItemSelected(item) ? lensTint(for: item).opacity(0.34) : Color.primary.opacity(0.06), lineWidth: 1)
            )

            if let overrideAuditText = lensDecisionOverrideAuditText(for: item) {
                Text(overrideAuditText)
                    .font(.caption2)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(lensTint(for: item).opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(lensTint(for: item).opacity(0.18), lineWidth: 1)
                    )
                    .accessibilityIdentifier(TodayAutomationID.trainingPrescriptionDecisionOverrideAudit)
                    .accessibilityLabel("改选审计：\(overrideAuditText)")
            }
        }
    }

    private func lensMethodTileAccessibilityValue(_ item: LensCatalogItem) -> String {
        var parts = [item.questionSeeds.first ?? item.methodLine]
        if isLensItemSelected(item),
           let prescription = store.trainingPrescription,
           item.id == prescription.finalLensId,
           let overrideAuditText = trainingOverrideAuditText(prescription) {
            parts.append(overrideAuditText)
        }
        return parts.joined(separator: "，")
    }

    private func lensDecisionOverrideAuditText(for item: LensCatalogItem) -> String? {
        guard isLensItemSelected(item),
              let prescription = store.trainingPrescription,
              item.id == prescription.finalLensId
        else {
            return nil
        }
        return trainingOverrideAuditText(prescription)
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
        feedback: PrincipleRecallFeedbackValue,
        note: String
    ) {
        Task {
            await store.recordReferencedPrincipleFeedback(
                for: principle.id,
                feedback: feedback,
                note: note
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
        (hasAppliedTrainingPrescription && store.trainingPrescription?.finalLensId == item.id) ||
            store.todayDraft.selectedLens?.rawValue == item.id ||
            store.todayDraft.selectedCustomLensId == item.id
    }

    private var hasAppliedTrainingPrescription: Bool {
        store.todayDraft.selectedLens != nil || store.todayDraft.selectedCustomLensId != nil
    }

    private func lensItem(for id: String) -> LensCatalogItem? {
        if let lens = ThinkingLens(rawValue: id) {
            return lens.catalogItem
        }
        return store.availableLensChoices.first { $0.id == id || $0.lensId == id }
    }

    private func trainingOverrideAuditText(_ prescription: TrainingPrescription) -> String? {
        guard prescription.source == .userOverride,
              prescription.finalLensId != prescription.recommendedLensId
        else {
            return nil
        }

        let finalTitle = lensItem(for: prescription.finalLensId)?.title ?? prescription.finalLensId
        let recommendedTitle = lensItem(for: prescription.recommendedLensId)?.title ?? prescription.recommendedLensId
        return "你已改选为「\(finalTitle)」；教练推荐「\(recommendedTitle)」仍保留为审计，后续问题以改选透镜为主，同时继续执行底盘检查。"
    }

    private func baselineCheckTitle(_ check: BaselineThinkingCheck) -> String {
        switch check {
        case .factInterpretationSplit:
            return "事实/解释"
        case .evidenceGap:
            return "证据缺口"
        case .counterexample:
            return "反例"
        case .assumptionTest:
            return "假设检验"
        case .testableAction:
            return "可验证行动"
        case .feedbackSignal:
            return "反馈信号"
        case .judgmentUpdate:
            return "判断更新"
        }
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

private struct ThreePetalSpiralLoadingMark: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let phase = reduceMotion ? 0.18 : (elapsed.truncatingRemainder(dividingBy: 6.2) / 6.2)
                let pulse = reduceMotion ? 0.5 : 0.5 + sin((elapsed / 8.2) * .pi * 2 + 0.4) * 0.5
                let detailScale = 0.68 + pulse * 0.10
                let sample = ThreePetalSpiralGeometry.sample(detailScale: detailScale, size: size)
                let headDistance = sample.totalLength * phase
                let scale = min(size.width, size.height)

                context.stroke(
                    ThreePetalSpiralGeometry.path(from: sample.points),
                    with: .color(DS.accent.opacity(0.13)),
                    style: StrokeStyle(
                        lineWidth: max(1.0, scale / 32.0),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

                context.stroke(
                    ThreePetalSpiralGeometry.trailPath(sample: sample, headDistance: headDistance, ratio: 0.34, steps: 80),
                    with: .color(DS.accent.opacity(0.18)),
                    style: StrokeStyle(
                        lineWidth: max(1.15, scale / 28.0),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

                context.stroke(
                    ThreePetalSpiralGeometry.trailPath(sample: sample, headDistance: headDistance, ratio: 0.22, steps: 64),
                    with: .color(DS.accent.opacity(0.42)),
                    style: StrokeStyle(
                        lineWidth: max(1.35, scale / 24.0),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

                context.stroke(
                    ThreePetalSpiralGeometry.trailPath(sample: sample, headDistance: headDistance, ratio: 0.10, steps: 36),
                    with: .color(DS.accent.opacity(0.92)),
                    style: StrokeStyle(
                        lineWidth: max(1.6, scale / 21.0),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

                let head = ThreePetalSpiralGeometry.point(at: headDistance, in: sample)
                let dot = Path(ellipseIn: CGRect(
                    x: head.x - max(1.2, scale / 26.0),
                    y: head.y - max(1.2, scale / 26.0),
                    width: max(2.4, scale / 13.0),
                    height: max(2.4, scale / 13.0)
                ))
                context.fill(dot, with: .color(DS.accent.opacity(0.94)))
            }
        }
    }
}

private struct ThreePetalSpiralSample {
    let points: [CGPoint]
    let lengths: [CGFloat]
    let totalLength: CGFloat
}

private enum ThreePetalSpiralGeometry {
    static func sample(detailScale: Double, size: CGSize, steps: Int = 240) -> ThreePetalSpiralSample {
        var points: [CGPoint] = []
        var lengths: [CGFloat] = [0]
        var totalLength: CGFloat = 0

        points.reserveCapacity(steps + 1)
        lengths.reserveCapacity(steps + 1)

        for index in 0...steps {
            let point = point(progress: Double(index) / Double(steps), detailScale: detailScale, size: size)
            points.append(point)
            if index > 0 {
                let previous = points[index - 1]
                let segmentLength = hypot(point.x - previous.x, point.y - previous.y)
                totalLength += segmentLength
                lengths.append(totalLength)
            }
        }

        return ThreePetalSpiralSample(points: points, lengths: lengths, totalLength: totalLength)
    }

    static func path(from points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    static func trailPath(
        sample: ThreePetalSpiralSample,
        headDistance: CGFloat,
        ratio: CGFloat,
        steps: Int
    ) -> Path {
        let trailLength = sample.totalLength * ratio
        let points = (0...steps).map { index -> CGPoint in
            let local = CGFloat(index) / CGFloat(steps)
            let easedLocal = local * local * (3 - 2 * local)
            let distance = headDistance - trailLength + trailLength * easedLocal
            return point(at: distance, in: sample)
        }
        return path(from: points)
    }

    static func point(at distance: CGFloat, in sample: ThreePetalSpiralSample) -> CGPoint {
        guard sample.totalLength > 0,
              let first = sample.points.first
        else { return .zero }

        let target = normalizedDistance(distance, totalLength: sample.totalLength)
        if target <= 0 { return first }

        var low = 1
        var high = sample.lengths.count - 1
        while low < high {
            let mid = (low + high) / 2
            if sample.lengths[mid] < target {
                low = mid + 1
            } else {
                high = mid
            }
        }

        let index = low
        let startLength = sample.lengths[index - 1]
        let endLength = sample.lengths[index]
        let span = max(endLength - startLength, 0.0001)
        let ratio = (target - startLength) / span
        let start = sample.points[index - 1]
        let end = sample.points[index]

        return CGPoint(
            x: start.x + (end.x - start.x) * ratio,
            y: start.y + (end.y - start.y) * ratio
        )
    }

    private static func normalizedDistance(_ distance: CGFloat, totalLength: CGFloat) -> CGFloat {
        let remainder = distance.truncatingRemainder(dividingBy: totalLength)
        return remainder >= 0 ? remainder : remainder + totalLength
    }

    private static func point(progress: Double, detailScale: Double, size: CGSize) -> CGPoint {
        let t = normalizedProgress(progress) * .pi * 2
        let majorRadius = 3.0
        let minorRadius = 1.0
        let armLength = 2.72 + detailScale * 0.08
        let baseX = (majorRadius - minorRadius) * cos(t)
            + armLength * cos(((majorRadius - minorRadius) / minorRadius) * t)
        let baseY = (majorRadius - minorRadius) * sin(t)
            - armLength * sin(((majorRadius - minorRadius) / minorRadius) * t)
        let scale = 2.34 + detailScale * 0.10
        let viewBoxPoint = CGPoint(
            x: 50 + baseX * scale,
            y: 50 + baseY * scale
        )
        return CGPoint(
            x: viewBoxPoint.x / 100 * size.width,
            y: viewBoxPoint.y / 100 * size.height
        )
    }

    private static func normalizedProgress(_ progress: Double) -> Double {
        let remainder = progress.truncatingRemainder(dividingBy: 1)
        return remainder >= 0 ? remainder : remainder + 1
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
                    ThreePetalSpiralLoadingMark()
                        .frame(width: 42, height: 42)
                        .accessibilityHidden(true)
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

private extension CoachObservationMaterial {
    var displayTitle: String {
        switch self {
        case .background:
            return "背景"
        case .object:
            return "对象"
        case .trigger:
            return "触发点"
        case .action:
            return "行动"
        case .result:
            return "结果"
        case .feeling:
            return "感受"
        case .fact:
            return "事实"
        case .interpretation:
            return "解释"
        case .judgment:
            return "判断"
        case .assumption:
            return "假设"
        case .constraint:
            return "约束"
        case .goal:
            return "目标"
        case .standard:
            return "标准"
        case .openQuestion:
            return "问题"
        case .experience:
            return "经验"
        case .calibrationSignal:
            return "校准信号"
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

                if let evidenceGapType = question.evidenceGapType, evidenceGapType != .none {
                    Image(systemName: "magnifyingglass")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                    Text(evidenceGapType.displayTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                }

                if let answerUse = question.answerUse {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                    Text(answerUse.displayTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                }

                if let lensMove = question.lensMove {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                    Text(lensMove.displayTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                }
            }

            if !question.sourceCardTitles.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "link")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                    Text("来源：\(question.sourceCardTitles.prefix(2).joined(separator: " / "))")
                        .font(.caption2)
                        .foregroundStyle(DS.mutedInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let calibrationTarget = question.calibrationTarget,
               !calibrationTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "target")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                    Text("校准：\(calibrationTarget)")
                        .font(.caption2)
                        .foregroundStyle(DS.mutedInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
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

            if hasTeachingCue {
                VStack(alignment: .leading, spacing: 7) {
                    if let lensMove = question.lensMove {
                        BriefRow(title: "训练动作", body: lensMove.displayTitle, accent: DS.accent)
                    }
                    if let gapTitle = teachingGapTitle {
                        BriefRow(title: "补的缺口", body: gapTitle, accent: DS.brick)
                    }
                    if let whyNow = trimmed(question.whyNow) {
                        BriefRow(title: "为什么现在问", body: whyNow, accent: DS.caution)
                    }
                    if let expectedUpdate = trimmed(question.expectedUpdate) {
                        BriefRow(title: "答案会改变", body: expectedUpdate, accent: DS.accent)
                    }
                    if let proceedWhen = trimmed(question.proceedWhen) {
                        BriefRow(title: "推进标准", body: proceedWhen, accent: DS.success)
                    }
                }
                .padding(10)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(DS.hairline, lineWidth: 1)
                )
            }

            if hasTeachingCue {
                answerDrillView
            }

            BriefRow(title: "输入材料", body: question.answerTrainingPrompt, accent: DS.accent)

            TextField(question.answerTrainingPrompt, text: $answer, axis: .vertical)
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

    private var hasTeachingCue: Bool {
        question.lensMove != nil ||
            teachingGapTitle != nil ||
            trimmed(question.whyNow) != nil ||
            trimmed(question.expectedUpdate) != nil ||
            trimmed(question.proceedWhen) != nil
    }

    private var answerDrillView: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("作答训练")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DS.mutedInk)
                .textCase(.uppercase)
            BriefRow(
                title: "不是 AI 答案",
                body: "这一段训练你自己补上没想到的部分，明思只负责指出该补哪里。",
                accent: DS.accent
            )
            BriefRow(
                title: "补盲区",
                body: "先回答\(teachingGapTitle ?? "当前判断缺口")，不要急着给结论。",
                accent: DS.brick
            )
            BriefRow(
                title: "复现经验",
                body: "把召回经验判成复现、调整或否定，避免机械套用历史做法。",
                accent: DS.graphite
            )
            BriefRow(
                title: "安排执行",
                body: "写出\(question.answerUse?.displayTitle ?? "答案会改变什么")，再留一个明天能验证的结果信号。",
                accent: DS.success
            )
        }
        .padding(10)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
    }

    private var teachingGapTitle: String? {
        guard let evidenceGapType = question.evidenceGapType else { return nil }
        if evidenceGapType == .none {
            return "取舍或框架问题"
        }
        return evidenceGapType.displayTitle
    }

    private func trimmed(_ value: String?) -> String? {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }
}

private struct QuestCardView: View {
    let quest: Quest
    let trainingTarget: QuestTrainingTarget?
    let trainingPrinciples: [PrincipleAsset]
    let selectTrainingPrinciple: (PrincipleAsset.ID?) -> Void
    let update: (String, String, String, String, String) -> Void
    @State private var isEditing = false
    @State private var draftTitle: String
    @State private var draftWhy: String
    @State private var draftCriteria: String
    @State private var draftResistance: String
    @State private var draftQuestion: String
    private let executionFeedback: QuestExecutionTrainingFeedback

    init(
        quest: Quest,
        trainingTarget: QuestTrainingTarget? = nil,
        trainingPrinciples: [PrincipleAsset] = [],
        selectTrainingPrinciple: @escaping (PrincipleAsset.ID?) -> Void = { _ in },
        update: @escaping (String, String, String, String, String) -> Void
    ) {
        self.quest = quest
        self.trainingTarget = trainingTarget
        self.trainingPrinciples = trainingPrinciples
            .filter { $0.status == .active }
        self.selectTrainingPrinciple = selectTrainingPrinciple
        self.update = update
        self.executionFeedback = QuestExecutionTrainingPolicy().makeFeedback(for: quest)
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
                    BriefRow(title: "验证判断", body: executionFeedback.judgmentLine, accent: DS.accent)
                    BriefRow(title: "完成证据", body: executionFeedback.evidenceLine, accent: quest.type == .main ? DS.accent : DS.mutedInk)
                    BriefRow(title: "阻力预案", body: executionFeedback.resistanceLine, accent: DS.caution)
                    BriefRow(title: "结果校准信号", body: executionFeedback.calibrationLine, accent: DS.success)
                    BriefRow(title: "执行力训练", body: executionFeedback.trainingLine, accent: DS.graphite)
                    if let trainingTarget {
                        BriefRow(
                            title: "训练原则",
                            body: trainingTarget.principleTitle,
                            accent: DS.accent
                        )
                        Text("命中信号：\(trainingTarget.matchSignal)")
                            .font(.caption)
                            .foregroundStyle(DS.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !trainingPrinciples.isEmpty {
                        questTrainingPrinciplePicker
                    }
                }
            }
        }
        .questSurface(isMain: quest.type == .main)
    }

    private var questTrainingPrinciplePicker: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("校准训练")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.mutedInk)
            Picker(
                "训练原则",
                selection: Binding<PrincipleAsset.ID?>(
                    get: { quest.trainingPrincipleId },
                    set: { selectTrainingPrinciple($0) }
                )
            ) {
                Text("自动判断").tag(Optional<PrincipleAsset.ID>.none)
                ForEach(trainingPrinciples) { principle in
                    Text(principle.title).tag(Optional(principle.id))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .accessibilityIdentifier(TodayAutomationID.questTrainingPrinciplePicker)
            Spacer(minLength: 0)
        }
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
    let retrievalReason: (UUID) -> String?
    let retrievalSignalText: (UUID) -> String?
    let onFeedback: (PrincipleAsset, PrincipleRecallFeedbackValue, String) -> Void

    @State private var feedbackNotes: [UUID: String] = [:]

    @ViewBuilder
    var body: some View {
        if !principles.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "quote.bubble")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.accent)
                    Text("过往经验复现")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.ink)
                    Spacer()
                    Text("先判断是否适用")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DS.surface, in: Capsule())
                }

                Text("这次先判断：这些经验是否应该复现；如果不适用，就把原因标出来。")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(principles) { principle in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(principle.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.ink)
                        Text(principle.triggerContext)
                            .font(.caption)
                            .foregroundStyle(DS.mutedInk)
                            .lineLimit(2)
                        if let reason = retrievalReason(principle.id) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("召回依据")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(DS.accent)
                                if let signalText = retrievalSignalText(principle.id) {
                                    Text("命中信号：\(signalText)")
                                        .font(.caption)
                                        .foregroundStyle(DS.mutedInk)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Text(reason)
                                    .font(.caption)
                                    .foregroundStyle(DS.mutedInk)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.top, 2)
                        }
                        TextField(
                            "可选：为什么复现或不复现？",
                            text: Binding(
                                get: { feedbackNotes[principle.id, default: ""] },
                                set: { feedbackNotes[principle.id] = $0 }
                            )
                        )
                        .font(.caption)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .accessibilityIdentifier(TodayAutomationID.principleFeedbackNoteField)

                        HStack(spacing: 8) {
                            Button {
                                endEditing()
                                onFeedback(principle, .helpful, feedbackNotes[principle.id, default: ""])
                            } label: {
                                Label("适用，今天要复现", systemImage: "hand.thumbsup")
                            }
                            .accessibilityIdentifier(TodayAutomationID.principleFeedbackHelpfulAction)

                            Button {
                                endEditing()
                                onFeedback(principle, .notApplicable, feedbackNotes[principle.id, default: ""])
                            } label: {
                                Label("场景不同，不复现", systemImage: "xmark.circle")
                            }
                            .accessibilityIdentifier(TodayAutomationID.principleFeedbackNotApplicableAction)

                            Button {
                                endEditing()
                                onFeedback(principle, .misrecalled, feedbackNotes[principle.id, default: ""])
                            } label: {
                                Label("召回错了", systemImage: "exclamationmark.bubble")
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

    private func endEditing() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
