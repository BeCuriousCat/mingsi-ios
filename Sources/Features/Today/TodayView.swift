import SwiftUI
import UIKit
import Combine

enum TodayAutomationID {
    static let primaryAction = "today.primary-action"
    static let primaryActionHint = "today.primary-action-hint"
    static let previousAction = "today.previous-action"
    static let supplementCaptureAction = "today.supplement-capture-action"
    static let returnToReviewForJudgmentAction = "today.return-to-review-for-judgment-action"
    static let retryCurrentStepAction = "today.retry-current-step-action"
    static let retryMessageAction = "today.retry-message-action"
    static let centralModelKeySettingsAction = "today.central-model-key.settings-action"
    static let skipPrincipleAction = "today.skip-principle-action"
    static let resetAction = "today.reset-action"
    static let moreActions = "today.more-actions"
    static let cancelCurrentAIAction = "today.cancel-current-ai-action"
    static let captureMaterialEvent = "today.capture.material-guide.event"
    static let captureMaterialAction = "today.capture.material-guide.action"
    static let captureMaterialThought = "today.capture.material-guide.thought"
    static let cardConfirmAction = "today.card.confirm-action"
    static let cardExcludeAction = "today.card.exclude-action"
    static let trainingPrescriptionAcceptAction = "today.training-prescription.accept-action"
    static let trainingPrescriptionSkipAction = "today.training-prescription.skip-action"
    static let trainingPrescriptionOverrideAudit = "today.training-prescription.override-audit"
    static let trainingPrescriptionDecisionOverrideAudit = "today.training-prescription.decision-override-audit"
    static let trainingPrescriptionTeachingToggle = "today.training-prescription.teaching-toggle"
    static let coachDiagnosisAcceptAction = "today.coach-diagnosis.accept-action"
    static let coachDiagnosisSlowDownAction = "today.coach-diagnosis.slow-down-action"
    static let coachDiagnosisOverrideProgressAction = "today.coach-diagnosis.override-progress-action"
    static let answerQuestionsOverrideGapAction = "today.answer.override-gap-action"
    static let answerDiagnosisToggle = "today.answer.diagnosis-toggle"
    static let answerTrainingToolsToggle = "today.answer.training-tools-toggle"
    static let coachReferenceSuggestion = "today.answer.coach-reference-suggestion"
    static let trainingTermsAction = "today.training-terms-action"
    static let trainingTermsSheet = "today.training-terms-sheet"
    static let captureTrainingToolsToggle = "today.capture.training-tools-toggle"
    static let questionCoachBasisToggle = "today.question.coach-basis-toggle"
    static let questionAnswerField = "today.question.answer-field"
    static let captureRawTextField = "today.capture.raw-text-field"
    static let loopBoundaryToggle = "today.loop-boundary-toggle"
    static let captureGuidanceToggle = "today.capture.guidance-toggle"
    static let reviewQuestsGuidanceToggle = "today.review-quests.guidance-toggle"
    static let activeGuidanceToggle = "today.active-guidance-toggle"
    static let sideQuestEnableAction = "today.side-quest.enable-action"
    static let sideQuestAcceptAction = "today.side-quest.accept-action"
    static let sideQuestSkipAction = "today.side-quest.skip-action"
    static let sideQuestCompleteAction = "today.side-quest.complete-action"
    static let sideQuestCard = "today.side-quest.card"
    static let sideQuestCurrentSceneMenu = "today.side-quest.current-scene-menu"
    static let sideQuestRationale = "today.side-quest.rationale"
    static func overviewCaseAction(_ caseId: UUID) -> String {
        "today.overview.case.\(caseId.uuidString).action"
    }
    static func questionAnswerField(questionId: String) -> String {
        "today.question.answer-field.\(questionId)"
    }
    static let questEditAction = "today.quest.edit-action"
    static let questDetailsToggle = "today.quest.details-toggle"
    static let questTrainingPrinciplePicker = "today.quest.training-principle-picker"
    static func questValidationCheck(_ dimension: QuestValidationDimension) -> String {
        "today.quest.validation.\(dimension.rawValue)"
    }
    static let principleFeedbackNoteField = "today.principle.feedback.note-field"
    static let principleFeedbackHelpfulAction = "today.principle.feedback.helpful-action"
    static let principleFeedbackAdaptedAction = "today.principle.feedback.adapted-action"
    static let principleFeedbackNotApplicableAction = "today.principle.feedback.not-applicable-action"
    static let principleFeedbackMisrecalledAction = "today.principle.feedback.misrecalled-action"
    static let lensGenerateAction = "today.lens.generate-action"
    static let lensCustomAction = "today.lens.custom-action"
    static let customLensSheet = "today.custom-lens.sheet"
    static let customLensTitleField = "today.custom-lens.title-field"
    static let customLensMethodField = "today.custom-lens.method-field"
    static let customLensQuestionField = "today.custom-lens.question-field"
    static let customLensSaveAction = "today.custom-lens.save-action"
    static let capturesOpenAction = "today.captures.open-action"
    static let capturesSheet = "today.captures.sheet"
    static let capturesInput = "today.captures.input"
    static let capturesSaveAction = "today.captures.save-action"
    static let capturesDigestAction = "today.captures.digest-action"
    static let dailyLifeGuidanceCard = "today.life-guidance.daily-card"
    static let reviewLifeGuidanceCard = "today.life-guidance.review-card"
    static let lifeGuidanceDetails = "today.life-guidance.details"
    static let singleNudgeSection = "today.single-nudge.section"
    static let singleNudgeInput = "today.single-nudge.input"
    static let singleNudgeStartAction = "today.single-nudge.start-action"
    static let singleNudgeQuestion = "today.single-nudge.question"
    static let singleNudgeAnswer = "today.single-nudge.answer"
    static let singleNudgeReviewAction = "today.single-nudge.review-action"
    static let singleNudgeRetryReviewAction = "today.single-nudge.retry-review-action"
    static let singleNudgeHelpfulAction = "today.single-nudge.helpful-action"
    static let singleNudgeNotHelpfulAction = "today.single-nudge.not-helpful-action"
    static let singleNudgeAlternateAngleAction = "today.single-nudge.alternate-angle-action"
    static let singleNudgeDeeperAction = "today.single-nudge.deeper-action"
    static let singleNudgeFinishAction = "today.single-nudge.finish-action"
    static let singleNudgeAnotherAction = "today.single-nudge.another-action"
    static let singleNudgeOpenAction = "today.single-nudge.open-action"
    static let singleNudgeSurface = "today.single-nudge.surface"
    static let singleNudgeTransitionAction = "today.single-nudge.transition-action"

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
        case .reviewWithoutAction: stateID = "review_without_action"
        case .extractPrinciple: stateID = "extract_principle"
        case .sessionComplete: stateID = "session_complete"
        }
        return "today.state.\(stateID)"
    }

    static func lensAction(_ item: LensCatalogItem) -> String {
        "today.lens.\(item.id)-action"
    }
}

private enum TodayVisibleStage: Int, CaseIterable, Identifiable {
    case clarifyToday
    case examineJudgment
    case defineValidation

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .clarifyToday: return "讲清今天"
        case .examineJudgment: return "找出判断"
        case .defineValidation: return "行动验证"
        }
    }

    var states: [DailyLoopState] {
        switch self {
        case .clarifyToday:
            return [.capture, .organizing, .reviewCards, .selectMode]
        case .examineJudgment:
            return [.selectLens, .answerQuestions]
        case .defineValidation:
            return [.reviewQuests, .reviewWithoutAction, .extractPrinciple, .sessionComplete]
        }
    }

    var entryState: DailyLoopState {
        switch self {
        case .clarifyToday: return .capture
        case .examineJudgment: return .selectLens
        case .defineValidation: return .reviewQuests
        }
    }

    var automationID: String {
        switch self {
        case .clarifyToday: return "today.visible-stage.clarify-today"
        case .examineJudgment: return "today.visible-stage.examine-judgment"
        case .defineValidation: return "today.visible-stage.define-validation"
        }
    }
}

private enum TodayVisibleStageStatus {
    case completed
    case current
    case upcoming

    var accessibilityLabel: String {
        switch self {
        case .completed: return "已完成"
        case .current: return "进行中"
        case .upcoming: return "待开始"
        }
    }
}

func todayHeaderDateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy年M月d日"
    return formatter.string(from: date)
}

private struct TodayVisibleStageButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct TodayPrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? DS.background : DS.mutedInk)
            .background(
                isEnabled ? DS.accent : DS.surfaceStrong,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                if !isEnabled {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(DS.hairline, lineWidth: 1)
                }
            }
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

private struct TodayCaseOverviewCardStyle: ButtonStyle {
    let isEmphasized: Bool
    let statusTint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
        configuration.label
            .background {
                ZStack {
                    shape
                        .fill(statusTint.opacity(isEmphasized ? 0.14 : 0.055))
                        .overlay(shape.stroke(DS.hairline, lineWidth: 1))
                        .scaleEffect(0.972, anchor: .top)
                        .offset(y: 6)

                    shape
                        .fill(statusTint.opacity(isEmphasized ? 0.08 : 0.035))
                        .overlay(shape.stroke(DS.hairline.opacity(0.72), lineWidth: 1))
                        .scaleEffect(0.986, anchor: .top)
                        .offset(y: 3)

                    shape.fill(
                        isEmphasized
                            ? statusTint.opacity(configuration.isPressed ? 0.11 : 0.07)
                            : DS.cardBackground
                    )
                }
            }
            .overlay {
                shape.stroke(
                    configuration.isPressed
                        ? statusTint.opacity(0.62)
                        : (isEmphasized ? statusTint.opacity(0.30) : DS.hairline),
                    lineWidth: isEmphasized ? 1.25 : 1
                )
            }
            .shadow(
                color: isEmphasized ? statusTint.opacity(configuration.isPressed ? 0.05 : 0.12) : .black.opacity(0.025),
                radius: configuration.isPressed ? 2 : (isEmphasized ? 5 : 1.5),
                y: configuration.isPressed ? 0 : (isEmphasized ? 2 : 1)
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

private struct KeepScreenAwakeWhileTextEditing: ViewModifier {
    let keepsScreenAwakeWhile: Bool
    @State private var isTextEditing = false

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { _ in
                isTextEditing = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UITextView.textDidBeginEditingNotification)) { _ in
                isTextEditing = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidEndEditingNotification)) { _ in
                isTextEditing = false
            }
            .onReceive(NotificationCenter.default.publisher(for: UITextView.textDidEndEditingNotification)) { _ in
                isTextEditing = false
            }
            .onChange(of: isTextEditing) { _, _ in
                updateIdleTimer()
            }
            .onChange(of: keepsScreenAwakeWhile) { _, _ in
                updateIdleTimer()
            }
            .onAppear {
                updateIdleTimer()
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = isTextEditing || keepsScreenAwakeWhile
    }
}


private struct SideQuestPhotoMemoryThumbnail: View {
    let memory: SideQuestPhotoMemory
    let markUnavailable: () -> Void
    @State private var image: UIImage?
    @State private var didAttemptLoad = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                VStack(spacing: 5) {
                    Image(systemName: memory.unavailable ? "photo.slash" : "photo")
                    Text(memory.unavailable ? "照片不可用" : "读取照片")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(DS.mutedInk)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DS.mutedInk.opacity(0.08))
            }
        }
        .frame(width: 76, height: 76)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        }
        .task(id: memory.id) {
            guard !memory.unavailable, !didAttemptLoad else { return }
            didAttemptLoad = true
            let service = PhotoMemoryMediaService()
            image = await service.thumbnail(for: memory.assetLocalIdentifier, targetSize: CGSize(width: 152, height: 152))
            if image == nil {
                markUnavailable()
            }
        }
        .accessibilityLabel(memory.unavailable ? "奇遇照片不可用" : "奇遇照片")
    }
}

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    /// The modern Mentor coordinator is passed by the compatibility host when
    /// Today is presented from the Mentor home. Keeping it explicit avoids a
    /// second, stale coordinator lookup through AppStore in test and preview
    /// hosts.
    var mentorFeature: MentorFeatureStore?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var caseTransitionNamespace
    @State private var isCaptureFocused = false
    @State private var isCustomLensSheetPresented = false
    @State private var inspectedLens: LensCatalogItem?
    @State private var customLensTitle = ""
    @State private var customLensMethodLine = ""
    @State private var customLensQuestion = ""
    @State private var isAnswerTrainingToolsExpanded = false
    @State private var isCaptureTrainingToolsExpanded = false
    @State private var isTrainingPrescriptionTeachingExpanded = false
    @State private var isTrainingTermsPresented = false
    @State private var isActiveGuidanceExpanded = false
    @State private var newCaseTitle = ""
    @State private var isSideQuestCompletionPresented = false
    @State private var isSideQuestCorrectionPresented = false
    @State private var sideQuestCorrectionKind: SideQuestCorrectionKind = .notHere
    @State private var sideQuestCorrectionNote = ""
    @State private var sideQuestReflection = ""
    @State private var isPhotoMemoryLibraryPickerPresented = false
    @State private var isPhotoMemoryCameraPickerPresented = false
    @State private var photoMemoryPermissionMessage = ""
    @State private var isCaptureSheetPresented = false
    @State private var isSingleNudgeSheetPresented = false
    @State private var isMentorConversationPresented = false

    init(mentorFeature: MentorFeatureStore? = nil) {
        self.mentorFeature = mentorFeature
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.sectionSpacing) {
                        singleNudgeEntryRow
                        header
                            .id(TodayScrollAnchor.top)
                        if isVNextOverview {
                            todayOverviewSection
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        } else {
                            loopProgress {
                                withAnimation(.easeInOut(duration: 0.24)) {
                                    proxy.scrollTo(TodayScrollAnchor.top, anchor: .top)
                                }
                            }

                            guidanceSection

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
                            case .reviewWithoutAction:
                                reviewWithoutActionSection
                            case .extractPrinciple:
                                extractPrincipleSection
                            case .sessionComplete:
                                sessionCompleteSection
                            }

                            coachTurnFeedbackSection
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .opacity
                                ))
                            if usesScrollableReviewActions {
                                actionRow
                                    .padding(.horizontal, -DS.pagePadding)
                            }
                        }
                    }
                    .padding(.horizontal, DS.pagePadding)
                    .padding(.top, DS.primaryScrollTopPadding)
                    .padding(.bottom, todayScrollBottomReserve)
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 0.22),
                        value: isVNextOverview
                    )
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        dismissKeyboard()
                    }
                )
                .pageBackground()
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if !isVNextOverview && !usesScrollableReviewActions {
                        actionRow
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("today.fixed-action-bar")
                    }
                }
            }
        }
        .topSafeAreaScrim()
        .sheet(item: $inspectedLens) { item in
            LensGuideSheet(item: item) {
                selectLensItem(item)
                inspectedLens = nil
            }
            .dynamicTypeSize(dynamicTypeSize)
        }
        .sheet(isPresented: $isCustomLensSheetPresented) {
            customLensSheet
        }
        .sheet(isPresented: $isCaptureSheetPresented) {
            QuickCaptureSheet()
                .dynamicTypeSize(dynamicTypeSize)
        }
        .sheet(isPresented: $isSingleNudgeSheetPresented) {
            SingleNudgeSheet(isPresented: $isSingleNudgeSheetPresented)
        }
        .sheet(isPresented: $isMentorConversationPresented) {
            if let feature = activeMentorFeature {
                MentorConversationView(feature: feature)
                    .environmentObject(store)
                    .dynamicTypeSize(dynamicTypeSize)
            }
        }
        .onChange(of: store.activeGuidance?.hintId) { _, _ in
            isActiveGuidanceExpanded = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .mingsiOpenTodayCapture)) { _ in
            isCaptureSheetPresented = true
        }
        .task {
            await store.loadSingleNudge()
        }
        .task(id: store.todayDraft.state) {
            await store.recommendLifeGuidanceForTodayReview()
        }
        .sheet(isPresented: $isTrainingTermsPresented) {
            TrainingTermsSheet()
        }
        .sheet(isPresented: $isSideQuestCompletionPresented) {
            sideQuestCompletionSheet
        }
        .sheet(isPresented: $isPhotoMemoryLibraryPickerPresented) {
            PhotoMemoryLibraryPicker(
                onSelect: { identifier in
                    isPhotoMemoryLibraryPickerPresented = false
                    Task { await store.attachPhotoMemoryToCurrentSideQuest(assetLocalIdentifier: identifier) }
                },
                onCancel: { isPhotoMemoryLibraryPickerPresented = false }
            )
        }
        .sheet(isPresented: $isPhotoMemoryCameraPickerPresented) {
            PhotoMemoryCameraPicker(
                onCapture: { image in
                    isPhotoMemoryCameraPickerPresented = false
                    Task { await saveCapturedPhotoMemory(image) }
                },
                onCancel: { isPhotoMemoryCameraPickerPresented = false }
            )
        }
        .sheet(isPresented: $isSideQuestCorrectionPresented) {
            sideQuestCorrectionSheet
        }
        .onAppear {
            presentVisualQACustomLensSheetIfNeeded()
        }
        .onChange(of: store.todayDraft.state) { _, _ in
            presentVisualQACustomLensSheetIfNeeded()
        }
        .modifier(KeepScreenAwakeWhileTextEditing(keepsScreenAwakeWhile: store.isAIRunning))
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    // MARK: - Header

    /// Compact, always-discoverable entry. It never expands inline, so Today's
    /// active training card and central CTA keep their position.
    private var singleNudgeEntryRow: some View {
        Button {
            if let feature = activeMentorFeature {
                // Today is a compatibility surface, but its quick entry must
                // use the same multi-turn Mentor contract as the main home.
                feature.start(entry: "discuss")
                isMentorConversationPresented = true
            } else {
                // Keep the old flow available only when the Mentor feature is
                // unavailable (for example, an older/read-only store).
                isSingleNudgeSheetPresented = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: store.singleNudgeSession == nil ? "sparkle" : "sparkle.leadinghalf.filled")
                    .foregroundStyle(DS.accent)
                    .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
                VStack(alignment: .leading, spacing: 3) {
                    Text("明思一下")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.ink)
                    Text(singleNudgeEntrySubtitle)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                if store.isSingleNudgeGenerating {
                    ProgressView()
                        .accessibilityLabel("明思一下生成中")
                }
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(DS.mutedInk)
                    .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(TodayAutomationID.singleNudgeOpenAction)
        .accessibilityLabel(singleNudgeEntryAccessibilityLabel)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var singleNudgeEntrySubtitle: String {
        if activeMentorFeature != nil {
            return "一件卡住的事，先说清一个关键角度"
        }
        guard let session = store.singleNudgeSession else {
            return "一件卡住的事，一个问题，先想一步"
        }
        switch session.lifecycle {
        case .completed:
            return "这次明思已收好"
        case .receiptPresented, .feedbackRecorded:
            return "有一份点拨等待查看"
        default:
            return "继续未完成的一次明思"
        }
    }

    private var singleNudgeEntryAccessibilityLabel: String {
        if activeMentorFeature != nil { return "明思一下，开始一段多轮交流" }
        return store.singleNudgeSession == nil ? "明思一下，开始一次单问单答" : "继续明思一下"
    }

    private var activeMentorFeature: MentorFeatureStore? {
        mentorFeature ?? store.mentorFeatureStore
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(todayHeaderDateText(store.todayDraft.date))
                .font(.caption)
                .foregroundStyle(DS.mutedInk)

            if usesStackedHeaderActions {
                HStack(alignment: .firstTextBaseline) {
                    headerTitleContent
                    Spacer(minLength: 0)
                }
                HStack {
                    Spacer(minLength: 0)
                    headerActions
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    headerTitleContent
                    Spacer(minLength: 0)
                    headerActions
                }
            }

            if let activeCase = store.activeTrainingCase, !isVNextOverview {
                activeCaseHeader(activeCase)
            } else if !isVNextOverview {
                Text("现在 · \(store.currentStateTitle)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
                    .accessibilityIdentifier(TodayAutomationID.state(store.todayDraft.state))
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
                            Label(store.todayAIRetryActionTitle, systemImage: "arrow.clockwise")
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier(TodayAutomationID.retryMessageAction)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private func activeCaseHeader(_ trainingCase: TrainingCase) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: trainingCaseStatusSymbol(trainingCase.status))
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.accent)
            Text(trainingCase.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.accent)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(DS.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DS.accent.opacity(0.18), lineWidth: 1)
        }
        .matchedGeometryEffect(
            id: trainingCaseTransitionID(trainingCase.id),
            in: caseTransitionNamespace,
            properties: .frame,
            anchor: .center,
            isSource: false
        )
        .transaction { transaction in
            if reduceMotion { transaction.animation = nil }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("当前事项：\(trainingCase.title)")
    }

    private func trainingCaseTransitionID(_ id: UUID) -> String {
        "today.training-case.\(id.uuidString)"
    }

    private var usesStackedHeaderActions: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    @ViewBuilder
    private var headerTitleContent: some View {
        if store.activeTrainingCase != nil && !isVNextOverview {
            Button {
                Task { await store.returnToTodayOverview() }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DS.ink)
            .accessibilityLabel("返回今日概览")
        }

        Text(isVNextOverview ? "今日概览" : currentVisibleStageTitle)
            .font(.system(.largeTitle, design: .rounded).weight(.bold))
            .foregroundStyle(DS.ink)
    }

    private var headerActions: some View {
        HStack(spacing: 8) {
            Button {
                isTrainingTermsPresented = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DS.mutedInk)
            .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
            .accessibilityLabel("查看训练术语")
            .accessibilityIdentifier(TodayAutomationID.trainingTermsAction)

            if store.todayDraft.hasSelectedSessionMode {
                Text(store.todayDraft.sessionMode.badgeTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(DS.accent.opacity(0.08), in: Capsule())
            }
        }
    }

    private var isVNextOverview: Bool {
        store.trainingCasesVNextEnabled && store.isTodayOverviewPresented
    }

    private var todayOverviewSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let settlement = store.latestGrowthSettlement {
                growthSettlementView(settlement)
            }
            captureSummarySection
            LifeGuidanceSection(guidance: store.lifeGuidanceStore)
            if store.hasPendingCaseConfirmation {
                VStack(alignment: .leading, spacing: 8) {
                    Label("AI 已整理出事项，确认后再逐件推进。", systemImage: "checklist")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DS.ink)
                    Button {
                        store.resumeTrainingCaseConfirmation()
                    } label: {
                        Label("继续确认事项", systemImage: "arrow.right.circle")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.accent)
                    .accessibilityIdentifier("today.case-confirmation.resume-action")
                }
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) { Divider() }
            }

            if store.hasTodayOverload {
                Label("今天待推进或待验证的内容较多，先选一件最值得推进的事。", systemImage: "gauge.with.dots.needle.33percent")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DS.caution)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) { Divider() }
            }

            if !store.dueVerificationQuests.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    todaySectionLabel("到期验证")
                    ForEach(store.dueVerificationQuests) { quest in
                        VStack(alignment: .leading, spacing: 9) {
                            Text(quest.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DS.ink)
                            Text(quest.completionCriteria)
                                .font(.caption)
                                .foregroundStyle(DS.mutedInk)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 10) {
                                Button {
                                    Task { await store.beginVerification(quest) }
                                } label: {
                                    Label("验证", systemImage: "checkmark.circle")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .tint(DS.accent)

                                Button {
                                    Task { await store.deferVerification(quest) }
                                } label: {
                                    Label("稍后", systemImage: "clock.arrow.circlepath")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 8)
                        Divider()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                todaySectionLabel(store.trainingCases.isEmpty ? "记录今天" : "补充记录")
                PushToTalkInput(
                    text: Binding(
                        get: { store.todayDraft.rawText },
                        set: { store.updateTodayCapture($0) }
                    ),
                    placeholder: "补充今天的记录",
                    accessibilityIdentifier: TodayAutomationID.captureRawTextField,
                    focusBinding: $isCaptureFocused,
                    usesTextEditor: true
                )
                .frame(height: overviewCaptureHeight)
                .background(DS.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(DS.hairline, lineWidth: 1)
                )

                if store.trainingCases.isEmpty {
                    if store.isVNextModelLed && !store.apiKeyConfigured {
                        Button {
                            store.selectedTab = .settings
                        } label: {
                            Label("配置中央模型后整理", systemImage: "gearshape")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DS.accent)
                        .accessibilityIdentifier(TodayAutomationID.centralModelKeySettingsAction)
                    } else {
                        Button {
                            store.organizeOverviewCapture()
                        } label: {
                            Label("整理成事项", systemImage: "sparkles.rectangle.stack")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DS.accent)
                        .disabled(store.todayDraft.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } else {
                    Text("补充内容会保留在今天的原始记录中；需要单独推进时，在下方新增事项。")
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    todaySectionLabel("今日事项")
                    Spacer()
                    Text("\(store.trainingCases.filter { $0.status != .merged }.count) 件")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(DS.mutedInk)
                }

                if store.trainingCases.isEmpty {
                    Text("整理原始输入后，事项会出现在这里。")
                        .font(.subheadline)
                        .foregroundStyle(DS.mutedInk)
                } else {
                    ForEach(store.trainingCases) { trainingCase in
                        trainingCaseOverviewRow(trainingCase)
                    }
                }

                HStack(spacing: 10) {
                    PushToTalkInput(
                        text: $newCaseTitle,
                        placeholder: "手动新增事项",
                        accessibilityIdentifier: "today.training-case.new-title"
                    )
                    Button {
                        let title = newCaseTitle
                        newCaseTitle = ""
                        Task { await store.addManualTrainingCase(title: title) }
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                            .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("新增事项")
                    .disabled(newCaseTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if !store.trainingCaseMerges.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    todaySectionLabel("合并记录")
                    ForEach(store.trainingCaseMerges) { merge in
                        HStack {
                            Text("已合并事项")
                                .font(.caption)
                                .foregroundStyle(DS.mutedInk)
                            Spacer()
                            Button("撤销") {
                                Task { await store.undoTrainingCaseMerge(merge.id) }
                            }
                            .font(.caption.weight(.semibold))
                        }
                    }
                }
            }

            sideQuestSection
        }
    }


    private var captureSummarySection: some View {
        Button {
            isCaptureSheetPresented = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: store.todayCaptureDigest == nil ? "bolt" : "bolt.fill")
                    .foregroundStyle(DS.accent)
                    .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
                VStack(alignment: .leading, spacing: 3) {
                    Text("今日闪念")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.ink)
                    Text(captureSummaryStatus)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(DS.mutedInk)
                    .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("打开今日闪念")
        .accessibilityIdentifier(TodayAutomationID.capturesOpenAction)
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var captureSummaryStatus: String {
        let count = store.todayCaptureFragments.count
        guard count > 0 else { return "还没有记录" }
        return "\(count) 条 · \(store.todayCaptureFragments.contains { $0.status == .pending } ? "待整理" : "已整理")"
    }

    @ViewBuilder
    private var sideQuestSection: some View {
        if let run = store.sideQuestRun {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    todaySectionLabel("今日奇遇")
                        .accessibilityIdentifier(TodayAutomationID.sideQuestCard)
                    Spacer()
                    if store.sideQuestPreference.isEnabled {
                        Menu {
                            ForEach([
                                SideQuestContextSnapshot.Scene.home,
                                .work,
                                .familiarPlace,
                                .unknown
                            ], id: \.self) { scene in
                                Button {
                                    store.setSideQuestManualScene(scene)
                                } label: {
                                    Label(
                                        scene.manualSelectionTitle,
                                        systemImage: scene == (store.sideQuestManualSceneContext?.scene ?? .unknown)
                                            ? "checkmark"
                                            : "circle"
                                    )
                                }
                            }
                            if store.sideQuestManualSceneContext != nil {
                                Divider()
                                Button("清除当前情境") {
                                    store.setSideQuestManualScene(nil)
                                }
                            }
                        } label: {
                            Label(
                                store.sideQuestManualSceneContext?.scene.manualSelectionTitle ?? "当前情境",
                                systemImage: "location"
                            )
                            .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(DS.mutedInk)
                        .accessibilityIdentifier(TodayAutomationID.sideQuestCurrentSceneMenu)
                        .accessibilityLabel("设置当前粗粒度情境")
                    }
                    Text("可选")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: sideQuestSymbol(for: run.status))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(sideQuestTint(for: run.status))
                            .frame(width: 30, height: 30)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(run.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(DS.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(run.origin == .aiGenerated ? "为你遇见 · " : "")\(run.category.title) · 不必完成")
                                .font(.caption)
                                .foregroundStyle(DS.mutedInk)
                            if let season = store.activeSideQuestSeason, run.seasonId == season.id {
                                Text("探索季：\(season.title) · 完成 \(season.completedCount) · 跳过 \(season.skippedCount)")
                                    .font(.caption)
                                    .foregroundStyle(DS.mutedInk)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 4)
                        sideQuestOptions(for: run)
                    }

                    Text(run.invitation)
                        .font(.subheadline)
                        .foregroundStyle(DS.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    if let rationale = sideQuestRationaleDisplayText(for: run) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("为什么现在推荐")
                                    .font(.caption.weight(.semibold))
                                Text(rationale)
                                    .font(.caption)
                            }
                        } icon: {
                            Image(systemName: "lightbulb")
                        }
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier(TodayAutomationID.sideQuestRationale)
                        .accessibilityLabel("为什么现在推荐：\(rationale)")
                    }

                    sideQuestActionRow(for: run)

                    if !store.sideQuestPhotoMemories.isEmpty {
                        sideQuestPhotoMemories
                    }

                    if run.status == .offered && !store.sideQuestPreference.notificationsEnabled {
                        Button {
                            Task { await store.setSideQuestNotificationsEnabled(true) }
                        } label: {
                            Label("开启系统提醒", systemImage: "bell.badge")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(DS.accent)
                        .disabled(store.isSideQuestActionInFlight)
                        .accessibilityLabel("开启生活奇遇系统提醒")
                    }

                    if !store.sideQuestMessage.isEmpty {
                        Text(store.sideQuestMessage)
                            .font(.caption)
                            .foregroundStyle(DS.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(DS.cardInnerPadding)
                .background(DS.cardBackground, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                        .stroke(sideQuestTint(for: run.status).opacity(0.22), lineWidth: 1)
                )
                .accessibilityElement(children: .contain)
                .accessibilityLabel("今日奇遇：\(run.title)，\(sideQuestStatusText(for: run.status))")
            }
            .padding(.top, 2)
        } else if store.sideQuestPreference.consentStatus == .notAsked {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "location.north.circle")
                    .font(.title3)
                    .foregroundStyle(DS.note)
                    .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("开启生活奇遇")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.ink)
                    Text("明思会偶尔结合你的记录发出一件可跳过的生活邀请。")
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 6) {
                    Button {
                        Task { await store.enableSideQuestInvitations() }
                    } label: {
                        Text("开启")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(DS.accent)
                    .accessibilityIdentifier(TodayAutomationID.sideQuestEnableAction)
                    .accessibilityLabel("开启今日奇遇")

                    Button("暂不开启") {
                        Task { await store.setSideQuestInvitationsEnabled(false) }
                    }
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .accessibilityIdentifier("today.side-quest.decline-consent-action")
                }
                .disabled(store.isSideQuestActionInFlight)
            }
            .padding(.vertical, 8)
            .overlay(alignment: .top) { Divider() }
        } else if !store.sideQuestPreference.isEnabled {
            EmptyView()
        } else if !store.sideQuestMessage.isEmpty {
            Text(store.sideQuestMessage)
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    @ViewBuilder
    private func sideQuestOptions(for run: SideQuestRun) -> some View {
        if run.status.occupiesInvitationSlot {
            Menu {
                Section("告诉明思") {
                    ForEach(SideQuestCorrectionKind.allCases.filter { $0 != .note }) { kind in
                        Button(kind.title) {
                            sideQuestCorrectionKind = kind
                            sideQuestCorrectionNote = ""
                            isSideQuestCorrectionPresented = true
                        }
                    }
                }
                Divider()
                Button("关闭“\(run.category.title)”类奇遇", role: .destructive) {
                    Task { await store.disableCurrentSideQuestCategory() }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DS.mutedInk)
            .disabled(store.isSideQuestActionInFlight)
            .accessibilityLabel("更多今日奇遇选项")
        }
    }

    private var sideQuestCorrectionSheet: some View {
        NavigationStack {
            Form {
                Section("反馈类型") {
                    Picker("反馈类型", selection: $sideQuestCorrectionKind) {
                        ForEach(SideQuestCorrectionKind.allCases.filter { $0 != .note }) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                }
                Section("补充说明（可选）") {
                    PushToTalkInput(
                        text: $sideQuestCorrectionNote,
                        placeholder: "补充说明（可选）",
                        accessibilityIdentifier: "today.side-quest-correction.input",
                        usesTextEditor: true
                    )
                    .frame(minHeight: 100)
                }
            }
            .navigationTitle("调整奇遇").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isSideQuestCorrectionPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("提交") {
                        let note = sideQuestCorrectionNote
                        isSideQuestCorrectionPresented = false
                        Task { await store.recordSideQuestCorrection(sideQuestCorrectionKind, note: note) }
                    }
                    .disabled(store.isSideQuestActionInFlight)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func sideQuestActionRow(for run: SideQuestRun) -> some View {
        switch run.status {
        case .offered:
            HStack(spacing: 10) {
                Button {
                    Task { await store.acceptCurrentSideQuest() }
                } label: {
                    Label("去看看", systemImage: "sparkle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.accent)
                .disabled(store.isSideQuestActionInFlight)
                .accessibilityIdentifier(TodayAutomationID.sideQuestAcceptAction)

                Button {
                    Task { await store.moveCurrentSideQuestToNextTime() }
                } label: {
                    Text("留到下次")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(store.isSideQuestActionInFlight)
                .accessibilityIdentifier(TodayAutomationID.sideQuestSkipAction)
            }
        case .accepted, .deferred:
            HStack(spacing: 10) {
                Label("已留意", systemImage: "checkmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.success)
                Spacer()
                Button {
                    sideQuestReflection = ""
                    isSideQuestCompletionPresented = true
                } label: {
                    Label("记下这一刻", systemImage: "bookmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.success)
                .disabled(store.isSideQuestActionInFlight)
                .accessibilityIdentifier(TodayAutomationID.sideQuestCompleteAction)
            }
        case .completed:
            if store.latestSideQuestExperience != nil {
                Label(
                    "这一刻已被收下",
                    systemImage: "bookmark.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.success)
            } else {
                Label("这一刻已被收下", systemImage: "bookmark.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.success)
            }
        case .declined, .expired:
            EmptyView()
        }
    }

    private var sideQuestCompletionSheet: some View {
        NavigationStack {
            Form {
                if let run = store.sideQuestRun {
                    Section("留住这次遇见") {
                        Text(run.title)
                            .font(.headline)
                        Text(run.evidencePrompt)
                            .font(.subheadline)
                            .foregroundStyle(DS.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Section {
                    PushToTalkInput(
                        text: $sideQuestReflection,
                        placeholder: "写一句感觉、细节或意外都可以",
                        accessibilityIdentifier: "today.side-quest-reflection.input",
                        usesTextEditor: true
                    )
                    .frame(minHeight: 112)
                    .accessibilityLabel("这次奇遇的观察")
                } header: {
                    Text("若它留下了什么（可选）")
                } footer: {
                    Text("写一句感觉、细节或意外都可以；什么都不写也没关系。")
                }

                Section("留下一张照片（可选）") {
                    Button {
                        photoMemoryPermissionMessage = ""
                        isPhotoMemoryLibraryPickerPresented = true
                    } label: {
                        Label("从相册选择", systemImage: "photo.on.rectangle")
                    }

                    Button {
                        Task { await presentPhotoMemoryCamera() }
                    } label: {
                        Label("现在拍一张", systemImage: "camera")
                    }
                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

                    if !photoMemoryPermissionMessage.isEmpty {
                        Text(photoMemoryPermissionMessage)
                            .font(.caption)
                            .foregroundStyle(DS.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .navigationTitle("收下这一刻")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isSideQuestCompletionPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("收下") {
                        let reflection = sideQuestReflection
                        isSideQuestCompletionPresented = false
                        Task { await store.completeCurrentSideQuest(reflection: reflection) }
                    }
                    .disabled(store.isSideQuestActionInFlight || store.sideQuestRun?.status.canComplete != true)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var sideQuestPhotoMemories: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("留住的照片")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.mutedInk)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(store.sideQuestPhotoMemories) { memory in
                        SideQuestPhotoMemoryThumbnail(memory: memory) {
                            Task { await store.markSideQuestPhotoMemoryUnavailable(id: memory.id) }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func presentPhotoMemoryCamera() async {
        let service = PhotoMemoryMediaService()
        let cameraStatus = await service.requestCameraPermission()
        guard cameraStatus.permitsPhotoSelection else {
            photoMemoryPermissionMessage = "请在系统设置中允许使用相机后，再拍下这一刻。"
            return
        }
        photoMemoryPermissionMessage = ""
        isPhotoMemoryCameraPickerPresented = true
    }

    private func saveCapturedPhotoMemory(_ image: UIImage) async {
        do {
            let identifier = try await PhotoMemoryMediaService().saveCapturedImage(image)
            await store.attachPhotoMemoryToCurrentSideQuest(
                assetLocalIdentifier: identifier,
                addToSharedAlbum: false
            )
        } catch {
            photoMemoryPermissionMessage = error.localizedDescription
        }
    }

    private func sideQuestSymbol(for status: SideQuestRunStatus) -> String {
        switch status {
        case .offered: return "location.north.circle"
        case .accepted, .deferred: return "figure.walk.motion"
        case .completed: return "checkmark.seal.fill"
        case .declined, .expired: return "circle"
        }
    }

    private func sideQuestTint(for status: SideQuestRunStatus) -> Color {
        switch status {
        case .offered: return DS.note
        case .accepted, .deferred: return DS.accent
        case .completed: return DS.success
        case .declined, .expired: return DS.mutedInk
        }
    }

    private func sideQuestStatusText(for status: SideQuestRunStatus) -> String {
        switch status {
        case .offered: return "可自行决定是否去看看"
        case .accepted: return "已留意"
        case .deferred: return "已暂存"
        case .completed: return "这一刻已被收下"
        case .declined: return "留到下次"
        case .expired: return "已结束"
        }
    }

    private func trainingCaseOverviewRow(_ trainingCase: TrainingCase) -> some View {
        let canOpenCase = [.ready, .inProgress].contains(trainingCase.status)
        return Group {
            if canOpenCase {
                Button {
                    Task { await store.openTrainingCase(trainingCase.id) }
                } label: {
                    trainingCaseOverviewCardContent(trainingCase, isActionable: true)
                }
                .buttonStyle(
                    TodayCaseOverviewCardStyle(
                        isEmphasized: trainingCase.status == .inProgress,
                        statusTint: trainingCaseStatusTint(trainingCase.status)
                    )
                )
                .matchedGeometryEffect(
                    id: trainingCaseTransitionID(trainingCase.id),
                    in: caseTransitionNamespace,
                    properties: .frame,
                    anchor: .center,
                    isSource: true
                )
                .transaction { transaction in
                    if reduceMotion { transaction.animation = nil }
                }
                .accessibilityLabel("推进事项：\(trainingCase.title)，\(trainingCase.status.title)")
                .accessibilityIdentifier(TodayAutomationID.overviewCaseAction(trainingCase.id))
            } else {
                trainingCaseOverviewCardContent(trainingCase, isActionable: false)
                    .background(DS.cardBackground, in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                            .stroke(DS.hairline, lineWidth: 1)
                    )
            }
        }
        .opacity(trainingCase.status == .merged ? 0.55 : 1)
    }

    private func trainingCaseOverviewCardContent(
        _ trainingCase: TrainingCase,
        isActionable: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: trainingCaseStatusSymbol(trainingCase.status))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(trainingCase.status == .inProgress ? DS.accent : DS.mutedInk)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 5) {
                Text(trainingCase.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DS.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(trainingCase.status.title)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
            }

            Spacer(minLength: 8)

            if isActionable {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(DS.accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(trainingCaseStatusTint(trainingCase.status))
                .frame(width: 3)
                .padding(.vertical, 12)
        }
    }

    private func trainingCaseStatusTint(_ status: TrainingCaseStatus) -> Color {
        switch status {
        case .pendingConfirmation:
            return DS.note
        case .ready:
            return DS.mutedInk.opacity(0.55)
        case .inProgress:
            return DS.accent
        case .awaitingVerification:
            return DS.caution
        case .completed:
            return DS.success
        case .merged:
            return DS.graphite
        }
    }

    private func trainingCaseStatusSymbol(_ status: TrainingCaseStatus) -> String {
        switch status {
        case .pendingConfirmation: return "questionmark.circle"
        case .ready: return "circle"
        case .inProgress: return "play.circle"
        case .awaitingVerification: return "clock.badge.checkmark"
        case .completed: return "checkmark.circle.fill"
        case .merged: return "arrow.triangle.merge"
        }
    }

    private var overviewCaptureHeight: CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return store.trainingCases.isEmpty ? 220 : 156
        }
        return store.trainingCases.isEmpty ? 180 : 112
    }

    private func todaySectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(DS.mutedInk)
            .textCase(.uppercase)
    }

    private func growthSettlementView(_ settlement: GrowthSettlement) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                todaySectionLabel("本次结果回顾")
                Spacer()
                Button {
                    store.dismissLatestGrowthSettlement()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭结果回顾")
                .accessibilityIdentifier("today.result-review.dismiss")
            }
            ResultCalibrationSummary(
                assessment: settlement.calibrationAssessment,
                note: settlement.calibrationNote,
                recommendation: settlement.recommendation
            )
            DisclosureGroup("查看原判断、结果与自评") {
                VStack(alignment: .leading, spacing: 10) {
                    BriefRow(title: "原判断", body: settlement.originalJudgment, accent: DS.graphite)
                    BriefRow(title: "你记录的结果", body: settlement.actualResult, accent: DS.accent)
                    BriefRow(title: "你的判断自评", body: settlement.judgmentUpdate.title, accent: DS.graphite)
                    ForEach(settlement.evidenceItems) { item in
                        Label(item.title, systemImage: "link")
                            .font(.subheadline)
                            .foregroundStyle(DS.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 8)
            }
            .font(.subheadline)
            .accessibilityIdentifier("today.result-review.details")
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Divider() }
    }

    @ViewBuilder
    private var guidanceSection: some View {
        if let guidance = store.activeGuidance {
            DisclosureGroup(isExpanded: $isActiveGuidanceExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(guidance.explanation)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                    let actionsLayout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                        : AnyLayout(HStackLayout(spacing: 12))
                    actionsLayout {
                        Button { Task { await store.snoozeActiveGuidance() } } label: {
                            Text("暂不显示").frame(minWidth: 44, minHeight: 44, alignment: .leading)
                        }
                        Button { Task { await store.markActiveGuidanceMastered() } } label: {
                            Text("我已掌握").frame(minWidth: 44, minHeight: 44, alignment: .leading)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(.top, 8)
            } label: {
                Label(guidance.copy, systemImage: "lightbulb.min")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier(TodayAutomationID.activeGuidanceToggle)
            .task(id: store.activeGuidanceOfferID) {
                if let offerID = store.activeGuidanceOfferID {
                    await store.recordActiveGuidancePresentation(offerID: offerID)
                }
            }
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) { Divider() }
        }
    }

    @ViewBuilder
    private var coachTurnFeedbackSection: some View {
        if store.activeTrainingCase != nil,
           [.selectLens, .answerQuestions, .reviewQuests].contains(store.todayDraft.state) {
            HStack {
                Text("这次教练建议")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                Spacer()
                Menu {
                    ForEach(CoachTurnFeedbackValue.allCases) { value in
                        Button(value.title) {
                            Task { await store.recordCoachTurnFeedback(value) }
                        }
                    }
                } label: {
                    Label("反馈", systemImage: "hand.thumbsup")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private func loopProgress(scrollToTop: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.todayDraft.state == .verifyYesterday {
                Label("开始前 · 回看昨天", systemImage: "arrow.counterclockwise")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.caution)
            }

            HStack(alignment: .top, spacing: 0) {
                ForEach(TodayVisibleStage.allCases) { stage in
                    visibleStageButton(stage, scrollToTop: scrollToTop)
                }
            }
        }
        .padding(.top, 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("今日流程进度")
    }

    private func visibleStageButton(
        _ stage: TodayVisibleStage,
        scrollToTop: @escaping () -> Void
    ) -> some View {
        let status = visibleStageStatus(for: stage)
        let canNavigate = canNavigate(to: stage)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                store.navigateTodayLoop(to: stage.entryState)
                scrollToTop()
            }
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 0) {
                    visibleStageMarker(stage, status: status)

                    if stage != .defineValidation {
                        Rectangle()
                            .fill(visibleStageConnectorColor(after: stage))
                            .frame(height: 1)
                            .padding(.horizontal, 7)
                    }
                }

                Text(stage.title)
                    .font(.caption.weight(status == .current ? .bold : .semibold))
                    .foregroundStyle(status == .upcoming ? DS.mutedInk : DS.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(TodayVisibleStageButtonStyle())
        .disabled(!canNavigate)
        .accessibilityIdentifier(stage.automationID)
        .accessibilityLabel("\(stage.title)，\(status.accessibilityLabel)")
        .accessibilityHint(canNavigate ? "点按回到这一阶段重新开始" : "")
    }

    private func visibleStageMarker(
        _ stage: TodayVisibleStage,
        status: TodayVisibleStageStatus
    ) -> some View {
        ZStack {
            Circle()
                .fill(status == .current ? DS.accent : Color.clear)
            Circle()
                .stroke(
                    status == .upcoming ? DS.mutedInk.opacity(0.35) : DS.accent,
                    lineWidth: status == .current ? 0 : 1
                )

            if status == .completed {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DS.accent)
            } else {
                Text("\(stage.rawValue + 1)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(status == .current ? DS.surfaceStrong : DS.mutedInk)
            }
        }
        .frame(width: 22, height: 22)
    }

    private func visibleStageConnectorColor(after stage: TodayVisibleStage) -> Color {
        guard let currentVisibleStage else { return DS.hairline }
        return stage.rawValue < currentVisibleStage.rawValue ? DS.accent.opacity(0.45) : DS.hairline
    }

    // MARK: - Verify Yesterday

    // Purpose: Close yesterday's loop before starting fresh
    // Design: Warm, reflective - not a form, a moment of honesty
    private var verifyYesterdaySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepLabel("回顾实际结果", subtitle: "先记录发生了什么，再看判断是否需要更新。")

            if let quest = store.mainQuest ?? store.quests.first {
                VStack(alignment: .leading, spacing: 6) {
                    Text("昨日验证行动")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(quest.title)
                        .font(.body.weight(.medium))
                    if let judgment = quest.calibrationTarget, !judgment.isEmpty {
                        Text("原判断：\(judgment)")
                            .font(.subheadline)
                    }
                    Text("原验收标准：\(quest.completionCriteria)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .questSurface(isMain: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("实际发生了什么？")
                    .accessibilityIdentifier("today.verification.result-label")
                    .font(.subheadline.weight(.medium))
                PushToTalkInput(
                    text: Binding(
                        get: { store.todayDraft.yesterdayEvidence },
                        set: { store.updateYesterdayEvidence($0) }
                    ),
                    placeholder: "写下观察到的结果；没有观察、出现反例或记录冲突也可以。",
                    accessibilityIdentifier: "today.yesterday-evidence.input"
                )
                .background(DS.cardBackground, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("完成了吗？")
                    .font(.subheadline.weight(.medium))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 280 : 140), alignment: .leading)], alignment: .leading, spacing: 10) {
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
                Text("你觉得这次行动有价值吗？")
                    .font(.subheadline.weight(.medium))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 280 : 140), alignment: .leading)], alignment: .leading, spacing: 10) {
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
                Text("你的判断自评")
                    .font(.subheadline.weight(.medium))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 280 : 140), alignment: .leading)], alignment: .leading, spacing: 10) {
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
        .disabled(store.isSavingTodayCompletion)
    }

    // MARK: - Capture

    // Purpose: Raw dump of today's messy thoughts
    // Design: Generous text area, inviting, feels like opening a notebook
    private var captureSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepLabel("今天发生了什么？", subtitle: "从一个你想聊的片段开始，不用先写完整。")

            CaptureMaterialGuide()

            PushToTalkInput(
                text: Binding(
                    get: { store.todayDraft.rawText },
                    set: { store.updateTodayCapture($0) }
                ),
                placeholder: "今天发生了什么？",
                accessibilityIdentifier: TodayAutomationID.captureRawTextField,
                focusBinding: $isCaptureFocused,
                usesTextEditor: true
            )
            .frame(minHeight: 220)
            .background(DS.cardBackground, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    .allowsHitTesting(false)
            )

            if let captureTrainingFeedback = store.coachCaptureMaterialTrainingFeedback {
                captureTrainingFeedbackView(captureTrainingFeedback)
            }

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

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 10) {
                    BriefRow(
                        title: "按需参考",
                        body: "下面只是可选提示；写你现在知道和想讨论的部分，不确定或不想补充的可以留空。",
                        accent: DS.accent
                    )
                    reviewScaffoldView
                }
                .padding(.top, 8)
            } label: {
                Label("查看输入参考（可选）", systemImage: "list.bullet.clipboard")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
            }
            .accessibilityIdentifier(TodayAutomationID.captureGuidanceToggle)

            VStack(alignment: .leading, spacing: 10) {
                Text("思考方式")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                modeCard(mode: .quick, icon: "bolt", description: "简短回应，聚焦当前最有用的一点。")
                modeCard(mode: .standard, icon: "book", description: "结合当前材料，说明判断依据与限制。")
                modeCard(mode: .deep, icon: "brain.head.profile", description: "更仔细检查假设和其他解释，不增加提问数量。")
            }
            .padding(.top, 2)

            starterPills
        }
    }

    private var reviewScaffoldView: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text("从一个角度开始")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
                    .textCase(.uppercase)
                Text("只选对当前困惑有用的一项，不必逐项填写。")
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

            BriefRow(title: "发生了什么", body: "可以从一个记得的片段说起，不必补齐所有背景。", accent: DS.accent)
            BriefRow(title: "我怎么做", body: "如果相关，可以说说当时的动作或选择。", accent: DS.brick)
            BriefRow(title: "我怎么想", body: "可以说出在意的目标、取舍或仍不确定的解释。", accent: DS.caution)
            BriefRow(title: "问题类型", body: "无需先分类；可以直接告诉明思，你想理解、比较还是获得建议。", accent: DS.graphite)
            BriefRow(title: "复盘问题", body: "也可以只说现在想获得什么帮助，不必自己准备问题。", accent: DS.success)

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
            stepLabel(
                store.isVNextModelLed
                    ? (store.apiKeyConfigured ? "正在整理" : "等待中央模型")
                    : (store.apiKeyConfigured ? "正在整理" : "本地整理中"),
                subtitle: "整理成可确认、可排除、可继续追问的卡片。"
            )

            if store.isVNextModelLed && !store.apiKeyConfigured {
                centralModelKeyRequiredSection
            } else {
                AIGenerationProgressView(
                    isUsingAI: store.apiKeyConfigured,
                    isModelLed: store.isVNextModelLed,
                    cardCount: store.thinkingCards.count,
                    streamingCards: store.streamingCards,
                    statusText: store.streamingStatusText,
                    activityStatus: store.aiActivityStatus,
                    failureMessage: store.lastAIFailureMessage,
                    canRetry: store.canRetryCurrentAI,
                    retry: { store.retryCurrentAIStep() }
                )
            }
        }
    }

    private var centralModelKeyRequiredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("需要配置中央模型", systemImage: "key.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.ink)
            Text("整理成事项需要中央模型 API Key。当前原始记录已保留，不会改用本地整理；配置完成后返回今日，再重试整理。")
                .font(.subheadline)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                store.selectedTab = .settings
            } label: {
                Label("进入设置", systemImage: "gearshape")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.accent)
            .accessibilityIdentifier(TodayAutomationID.centralModelKeySettingsAction)
        }
        .padding(14)
        .summarySurface()
    }

    // MARK: - Review Cards

    // Purpose: User reviews AI-extracted cards, confirms what's real
    // Design: Cards stacked with type color dot, minimal chrome, focus on content
    @ViewBuilder
    private var reviewCardsSection: some View {
        if store.showsTrainingCaseConfirmation {
            trainingCaseConfirmationSection
        } else {
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
    }

    private var trainingCaseConfirmationSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepLabel("确认事项", subtitle: "调整名称和卡片归属后，再逐件推进。")

            ForEach(store.trainingCases.filter { $0.status != .merged }) { trainingCase in
                VStack(alignment: .leading, spacing: 10) {
                    PushToTalkInput(
                        text: Binding(
                            get: {
                                store.trainingCases.first(where: { $0.id == trainingCase.id })?.title
                                    ?? trainingCase.title
                            },
                            set: { value in
                                Task { await store.updateTrainingCaseTitle(trainingCase.id, title: value) }
                            }
                        ),
                        placeholder: "事项名称",
                        accessibilityIdentifier: "today.training-case.\(trainingCase.id.uuidString).title"
                    )
                    .font(.headline)

                    ForEach(store.thinkingCards.filter { $0.trainingCaseId == trainingCase.id }) { card in
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

                        if store.trainingCases.count > 1 {
                            Menu {
                                ForEach(store.trainingCases.filter { $0.id != trainingCase.id && $0.status != .merged }) { target in
                                    Button(target.title) {
                                        Task { await store.moveCard(card.id, to: target.id) }
                                    }
                                }
                            } label: {
                                Label("调整归属", systemImage: "arrowshape.turn.up.right")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    if store.trainingCases.count > 1 {
                        Menu {
                            ForEach(store.trainingCases.filter { $0.id != trainingCase.id && $0.status != .merged }) { target in
                                Button("合并到「\(target.title)」") {
                                    Task { await store.mergeTrainingCase(trainingCase.id, into: target.id) }
                                }
                            }
                        } label: {
                            Label("合并事项", systemImage: "arrow.triangle.merge")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) { Divider() }
            }

            HStack(spacing: 10) {
                PushToTalkInput(
                    text: $newCaseTitle,
                    placeholder: "新增一个拆分事项",
                    accessibilityIdentifier: "today.training-case.split-title"
                )
                Button {
                    let title = newCaseTitle
                    newCaseTitle = ""
                    Task { await store.addManualTrainingCase(title: title) }
                } label: {
                    Image(systemName: "plus")
                        .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
                }
                .buttonStyle(.bordered)
                .disabled(newCaseTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("新增拆分事项")
            }
        }
    }

    // MARK: - Select Mode

    // Purpose: Choose thinking depth
    // Design: Three clear options, selected state is obvious but calm
    private var selectModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepLabel("训练模式", subtitle: "今天需要多深，就选择多深。")

            modeCard(mode: .quick, icon: "bolt", description: "简短回应，聚焦当前最有用的一点。")
            modeCard(mode: .standard, icon: "book", description: "结合当前材料，说明判断依据与限制。")
            modeCard(mode: .deep, icon: "brain.head.profile", description: "更仔细检查假设和其他解释，不增加提问数量。")
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

        return VStack(alignment: .leading, spacing: 14) {
            stepLabel("选择一个视角（可跳过）", subtitle: "透镜只是看问题的角度；也可以直接根据已确认材料继续。")

            if store.presentsLocalCoachPreview {
                todayLensCoreCard(confirmedCount: confirmedCards.count)
            }

            if let diagnosis = store.coachDiagnosis {
                coachDiagnosisCard(diagnosis, turnState: store.coachTurnState)
            }

            if let prescription, let recommendedItem {
                trainingPrescriptionCard(
                    prescription,
                    item: recommendedItem,
                    teachingPlan: store.coachTurnState.flatMap { turn -> CoachTeachingPlan? in
                        guard store.coachDiagnosis?.policyVersion.hasPrefix("coach-decision.llm") != true else { return nil }
                        return CoachTeachingPolicy().makePlan(turn: turn, prescription: prescription)
                    }
                )
            }

            Button {
                store.continueTodayWithoutLens()
            } label: {
                Label("只按今天材料继续", systemImage: "arrow.right.circle")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(DS.accent)
            .disabled(!store.canContinueTodayWithoutLens)
            .accessibilityIdentifier("today.select-lens.continue-without-lens")


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

            ForEach(LensGroup.allCases) { group in
                VStack(alignment: .leading, spacing: DS.cardSpacing) {
                    Text(group.title)
                        .font(.headline)
                        .foregroundStyle(DS.ink)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, DS.cardSpacing)
                    VStack(spacing: 0) {
                        ForEach(Array(group.lenses.enumerated()), id: \.element.id) { index, lens in
                            if index > 0 { Divider().padding(.horizontal, DS.cardInnerPadding) }
                            lensMethodTile(lens.catalogItem, isRecommended: lens.id == prescription?.recommendedLensId)
                        }
                    }
                    .background(DS.cardBackground, in: RoundedRectangle(cornerRadius: DS.cornerRadius))
                    .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: DS.cornerRadius).stroke(DS.hairline, lineWidth: 1)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .transaction { $0.animation = nil }
                }
            }

            DisclosureGroup("创建自己的透镜") {
            VStack(spacing: DS.cardSpacing) {
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

                .padding(.top, DS.cardSpacing)
            }
            .font(.subheadline)
            .padding(.vertical, DS.cardSpacing)
        }
    }

    // MARK: - Answer Questions

    // Purpose: Answer coaching questions to sharpen thinking
    // Design: Each question is a card with answer field, inviting not interrogating
    private var answerQuestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepLabel(
                store.coachAnswerTrainingFeedback?.hasStopped == true ? "今天先到这里" : (store.coachExplanation != nil ? "换个角度理解" : (store.questions.isEmpty ? "这轮没有追加问题" : "教练追问")),
                subtitle: store.coachAnswerTrainingFeedback?.hasStopped == true
                    ? "保留已经说的内容，也允许暂时没有答案。"
                    : (store.questions.isEmpty
                        ? "可以保留已有记录，再决定是否需要下一步行动。"
                        : (store.isVNextModelLed ? "按已有信息回答，不确定的地方也可以照实写。" : "先补一处没讲清的地方。"))
            )

            if store.hasUnansweredRepairQuestion {
                Label("有一条可选追问；也可以先保存已有回答。", systemImage: "arrow.turn.down.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DS.accent)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("today.answer.repair-follow-up-hint")
            }

            if let explanation = store.coachExplanation {
                VStack(alignment: .leading, spacing: 12) {
                    Label("明思的讲解 · AI 生成", systemImage: "text.book.closed")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                    Text(explanation.text)
                        .font(.body)
                        .foregroundStyle(DS.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("today.answer.explanation")
                    Text("基于：" + explanation.sourceCardTitles.joined(separator: "、"))
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.cardInnerPadding)
                .background(DS.cardBackground, in: RoundedRectangle(cornerRadius: DS.cornerRadius))
            } else if store.questions.isEmpty {
                Text("没有追加问题不代表原因已经确定。可以先保存当前理解，保留仍未知的部分。")
                    .font(.subheadline)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("today.answer.no-questions")
            }

            ForEach(Array(store.questions.enumerated()), id: \.element.id) { index, question in
                QuestionCardView(
                    question: question,
                    answer: bindingForQuestion(questionID: question.id, fallbackIndex: index),
                    isPrimaryAnswerField: index == 0,
                    isModelLed: store.isVNextModelLed
                )
            }

            if let feedback = store.coachAnswerTrainingFeedback {
                answerFeedbackPreviewView(
                    feedback,
                    answerMaterialObservation: store.coachAnswerMaterialObservation,
                    includesTeachingRoute: false
                )
            }

            if store.canChooseAnswerValidation {
                Button {
                    store.continueAnswerQuestionsWithCoachGapOverride()
                } label: {
                    Label("另行设计一个验证行动", systemImage: "arrow.right.circle")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: DS.minimumTapTarget)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.bordered)
                .tint(DS.accent)
                .accessibilityIdentifier(TodayAutomationID.answerQuestionsOverrideGapAction)
            }

            if store.isVNextModelLed,
               store.hasAnsweredReflectionQuestion,
               store.coachAnswerTrainingFeedback == nil {
                Text("提交后，明思会基于当前事项复盘一次你的回答。")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let suggestion = store.coachReferenceSuggestion {
                coachReferenceSuggestionView(suggestion)
            }

            if !store.referencedPrinciples.isEmpty {
                ReferencedPrinciplesView(
                    principles: store.referencedPrinciples,
                    retrievalReason: store.referencedPrincipleRetrievalReason,
                    retrievalSignalText: store.referencedPrincipleRetrievalSignalText,
                    onFeedback: recordReferencedPrincipleFeedback
                )
            }

            if !store.isVNextModelLed, store.coachAnswerTrainingFeedback?.hasStopped != true {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        BriefRow(
                            title: "本页只复盘今天",
                            body: "这里只修补今天材料里的讲述、证据和判断缺口；明天的验证行动会在明日验证里设计。",
                            accent: DS.brick
                        )
                        observationTrainingFrame(
                            CoachObservationPolicy().observe(cards: store.thinkingCards)
                        )

                        if let feedback = store.coachAnswerTrainingFeedback {
                            answerFeedbackDetailView(feedback)
                            teachingRouteView(feedback.teachingPlan)
                        } else if let teachingPlan = store.coachTurnState.map({
                            CoachTeachingPolicy().makePlan(
                                turn: $0,
                                prescription: store.trainingPrescription
                            )
                        }) {
                            teachingRouteView(teachingPlan)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Label(
                        "看明思为什么这样问",
                        systemImage: "list.bullet.clipboard"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
                }
                .accessibilityIdentifier(TodayAutomationID.answerDiagnosisToggle)
            }
        }
    }

    private func observationTrainingFrame(_ observation: CoachObservation) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            BriefRow(
                title: "这次主要练",
                body: "本轮主练：\(observation.trainingAbility.trainingTitle)。\(observation.trainingAbility.coachingMeaning)",
                accent: DS.accent
            )
            BriefRow(
                title: "先把材料分开",
                body: "事实、感受、解释、判断、行动",
                accent: DS.caution
            )
            BriefRow(title: "讲清楚训练", body: observation.narrativeTrainingLine, accent: DS.accent)
            if !observation.secondaryTrainingLine.isEmpty {
                BriefRow(title: "顺手留意", body: observation.secondaryTrainingLine, accent: DS.graphite)
            }
            materialInventoryRows(for: observation)
            BriefRow(title: "什么时候继续", body: observation.feedback.proceedWhen, accent: DS.success)
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

    private func captureTrainingFeedbackView(_ feedback: CoachMaterialTrainingFeedback) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            BriefRow(
                title: "本句观察",
                body: feedback.observationLine,
                accent: DS.accent
            )
            BriefRow(
                title: "建议补充",
                body: feedback.nextSentenceLine,
                accent: DS.brick
            )
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isCaptureTrainingToolsExpanded.toggle()
                }
            } label: {
                Label(
                    isCaptureTrainingToolsExpanded ? "收起训练标准" : "查看训练标准",
                    systemImage: isCaptureTrainingToolsExpanded ? "chevron.up.circle" : "wrench.and.screwdriver"
                )
                .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(DS.graphite)
            .accessibilityIdentifier(TodayAutomationID.captureTrainingToolsToggle)
            .accessibilityLabel(isCaptureTrainingToolsExpanded ? "收起训练标准" : "查看训练标准")

            if isCaptureTrainingToolsExpanded {
                VStack(alignment: .leading, spacing: 9) {
                    BriefRow(
                        title: "这次练什么",
                        body: feedback.trainingTargetLine,
                        accent: DS.caution
                    )
                    BriefRow(
                        title: "怎么算讲清楚",
                        body: feedback.selfCheckLine,
                        accent: DS.success
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func answerFeedbackPreviewView(
        _ feedback: CoachAnswerTrainingFeedback,
        answerMaterialObservation: String? = nil,
        includesTeachingRoute: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            BriefRow(
                title: "明思听完以后",
                body: feedback.coachCritiqueLine,
                accent: DS.success
            )
            if feedback.nextRepairQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                BriefRow(
                    title: feedback.hasStopped ? "今天先到这里" : "下一步",
                    body: feedback.proceedLine,
                    accent: DS.success
                )
            } else {
                BriefRow(
                    title: "建议补充",
                    body: feedback.nextRepairQuestion,
                    accent: DS.brick
                )
            }
            if !feedback.hasStopped && feedback.hasOptionalGuidance {
                answerTrainingToolsDisclosure(feedback, answerMaterialObservation: answerMaterialObservation)
                if includesTeachingRoute {
                    teachingRouteView(feedback.teachingPlan)
                }
            }
        }
        .accessibilityIdentifier("today.answer.review-feedback")
    }

    private func coachReferenceSuggestionView(_ suggestion: CoachReferenceSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BriefRow(title: "教练建议", body: suggestion.guidance, accent: DS.accent)
            if !suggestion.workedExample.isEmpty {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(suggestion.workedExample)
                            .font(.subheadline)
                            .foregroundStyle(DS.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(suggestion.caveat)
                            .font(.caption)
                            .foregroundStyle(DS.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 6)
                } label: {
                    Label("查看对照写法", systemImage: "checklist")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.accent)
                }
                .tint(DS.accent)
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier(TodayAutomationID.coachReferenceSuggestion)
    }

    private func answerTrainingToolsDisclosure(
        _ feedback: CoachAnswerTrainingFeedback,
        answerMaterialObservation: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isAnswerTrainingToolsExpanded.toggle()
                }
            } label: {
                Label(
                    isAnswerTrainingToolsExpanded ? "收起训练标准" : "查看训练标准",
                    systemImage: isAnswerTrainingToolsExpanded ? "chevron.up.circle" : "wrench.and.screwdriver"
                )
                .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(DS.graphite)
            .accessibilityIdentifier(TodayAutomationID.answerTrainingToolsToggle)
            .accessibilityLabel(isAnswerTrainingToolsExpanded ? "收起训练标准" : "查看训练标准")

            if isAnswerTrainingToolsExpanded {
                VStack(alignment: .leading, spacing: 9) {
                    if !feedback.repairedLine.isEmpty {
                        BriefRow(
                            title: "你刚补上",
                            body: feedback.repairedLine,
                            accent: feedback.canProceedToValidation ? DS.success : DS.caution
                        )
                    }
                    if let answerMaterialObservation {
                        BriefRow(
                            title: "本句观察",
                            body: answerMaterialObservation,
                            accent: DS.accent
                        )
                    }
                    if !feedback.abilityGapLine.isEmpty {
                        BriefRow(
                            title: "还缺什么",
                            body: feedback.abilityGapLine,
                            accent: DS.accent
                        )
                    }
                    if !feedback.trainingOutputLine.isEmpty {
                        BriefRow(
                            title: "别人能不能复述",
                            body: feedback.trainingOutputLine,
                            accent: DS.success
                        )
                    }
                    if !feedback.selfCheckLine.isEmpty {
                        BriefRow(
                            title: "怎么算讲清楚",
                            body: feedback.selfCheckLine,
                            accent: DS.accent
                        )
                    }
                    if !feedback.trainingTargetLine.isEmpty {
                        BriefRow(
                            title: "这次练什么",
                            body: feedback.trainingTargetLine,
                            accent: DS.caution
                        )
                    }
                    if !feedback.judgmentSentencePrompt.isEmpty {
                        BriefRow(
                            title: "把判断说完整",
                            body: feedback.judgmentSentencePrompt,
                            accent: DS.success
                        )
                    }
                    if !feedback.experienceReplayPrompt.isEmpty {
                        BriefRow(
                            title: "想想以前类似情况",
                            body: "\(feedback.experienceReplayDecisionLine)\n\(feedback.experienceReplayPrompt)",
                            accent: DS.graphite
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func answerFeedbackDetailView(_ feedback: CoachAnswerTrainingFeedback) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            BriefRow(title: "已修补", body: feedback.repairedLine, accent: DS.success)
            BriefRow(
                title: "现在能继续吗",
                body: feedback.proceedLine,
                accent: feedback.canProceedToValidation ? DS.success : DS.caution
            )
        }
    }

    // MARK: - Review Quests

    private var reviewWithoutActionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepLabel("这次先不安排行动", subtitle: "可以保存这段回顾，以后有新材料时再继续。")
            Text("本轮没有生成验证行动。尚不清楚的部分可以保留，不需要为了完成复盘再安排任务。")
                .font(.body)
                .foregroundStyle(DS.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("today.no-action.explanation")
            Text("以前保存的行动仍可在历史或待验证中查看。")
                .font(.footnote)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            Button("回到复盘，查看或补充材料") {
                store.navigateTodayLoop(to: .answerQuestions)
            }
            .buttonStyle(.bordered)
            .tint(DS.accent)
            .accessibilityIdentifier("today.no-action.return-to-review")
        }
        .disabled(store.isSavingTodayCompletion)
    }

    // Purpose: Review tomorrow's action plan
    // Design: Quest cards feel actionable, main quest is visually prominent
    private var reviewQuestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepLabel("设计验证行动", subtitle: "选一个愿意做的小行动，看看结果能说明什么。")

            Text("先看行动和观察结果，再决定是否保存。")
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            reviewQuestJudgmentAnchor

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

            if !store.referencedPrinciples.isEmpty {
                ReferencedPrinciplesView(
                    principles: store.referencedPrinciples,
                    retrievalReason: store.referencedPrincipleRetrievalReason,
                    retrievalSignalText: store.referencedPrincipleRetrievalSignalText,
                    onFeedback: recordReferencedPrincipleFeedback
                )
            }

        }
        .disabled(store.isSavingTodayCompletion)
    }

    private var reviewQuestJudgmentAnchor: some View {
        let target = mainQuestCalibrationTarget
        return VStack(alignment: .leading, spacing: 7) {
            Label(target == nil ? "先补一个判断" : "今天要验证", systemImage: "scope")
                .font(.caption.weight(.bold))
                .foregroundStyle(target == nil ? DS.caution : DS.accent)

            Text(target ?? "还没有明确的待验证判断。请回到今日复盘，把一个判断写成明天能观察的信号。")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.ink)
                .fixedSize(horizontal: false, vertical: true)

            if target != nil {
                Text("没有机会尝试或证据不足时，可以暂不能判断。")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
            }

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
        .padding(.vertical, 4)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DS.hairline)
                .frame(height: 1)
        }
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
            stepLabel("原则候选", subtitle: "这只是建议，保存后才进入你的原则库。")

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
            stepLabel("今日完成", subtitle: store.quests.isEmpty
                ? "回顾已保存，这次没有安排行动。"
                : "今天的输入已经转成可验证的动作。")

            if let mainQuest = store.quests.first(where: { $0.type == .main }) {
                completionCard(icon: "flag.checkered", title: "明日验证行动", body: mainQuest.title)
            }

            if let principle = store.principles.first {
                completionCard(icon: "lightbulb", title: "今日沉淀", body: principle.title)
            }

            if !store.quests.isEmpty {
                completionCard(icon: "chart.line.uptrend.xyaxis", title: "成长快照", body: store.growthSnapshot.summary)
            }

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
            .buttonStyle(TodayPrimaryActionButtonStyle())
            .disabled(store.isTodayPrimaryActionDisabled)
            .accessibilityIdentifier(TodayAutomationID.primaryAction)

            if store.todayDraft.state == .answerQuestions && !store.answerReviewPrimaryActionSaves {
                Button {
                    Task { await store.saveAnswerReviewAndReturn() }
                } label: {
                    Text("先保存，返回今日")
                        .font(.footnote)
                        .frame(maxWidth: .infinity, minHeight: DS.minimumTapTarget)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.accent)
                .disabled(!store.canSaveAnswerReview)
                .accessibilityIdentifier("today.answer.save-return")
            }

            if store.todayDraft.state == .reviewQuests, !store.isAIRunning {
                Button {
                    store.saveValidationAndReviewPrinciple()
                } label: {
                    Label("保存并整理原则候选", systemImage: "text.badge.plus")
                        .font(.footnote)
                        .frame(maxWidth: .infinity, minHeight: DS.minimumTapTarget)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.accent)
                .disabled(store.isTodayPrimaryActionDisabled)
                .accessibilityIdentifier("today.review-quests.optional-principle-action")
            }

            if store.isAIRunning {
                Text(store.aiActivityStatus)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(TodayAutomationID.primaryActionHint)

                Button {
                    store.cancelCurrentAIRequest()
                } label: {
                    Label(store.todayDraft.state == .verifyYesterday ? "取消结果回顾"
                          : store.todayDraft.state == .answerQuestions ? "取消本次复盘" : "取消本次生成", systemImage: "xmark")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .tint(DS.caution)
                .accessibilityIdentifier(TodayAutomationID.cancelCurrentAIAction)
            } else if store.todayDraft.state != .answerQuestions,
                      let blocker = store.todayPrimaryActionBlocker,
                      !store.canContinueAnswerQuestionsWithCoachGapOverride {
                Text(blocker)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(TodayAutomationID.primaryActionHint)
            }

            if store.canContinueAnswerQuestionsWithCoachGapOverride,
               store.todayDraft.state != .answerQuestions {
                Button {
                    store.continueAnswerQuestionsWithCoachGapOverride()
                } label: {
                    Label("带着缺口继续", systemImage: "arrow.right.circle")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(DS.accent)
                .accessibilityIdentifier(TodayAutomationID.answerQuestionsOverrideGapAction)
            }

            // The answer editor uses the fixed action bar as its primary
            // navigation surface. Removing the secondary row for that step
            // keeps the first answer field above the bar on compact screens.
            if store.todayDraft.state != .answerQuestions {
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

                Menu {
                    Button("重置今日", role: .destructive) {
                        store.resetTodayLoop()
                    }
                    .accessibilityIdentifier(TodayAutomationID.resetAction)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                }
                .foregroundStyle(DS.mutedInk)
                .accessibilityLabel("更多操作")
                .accessibilityIdentifier(TodayAutomationID.moreActions)
                .disabled(store.isSavingTodayCompletion)
                }
            }
        }
        .padding(.horizontal, DS.pagePadding)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(DS.background)
        .disabled(store.isSavingTodayCompletion && store.todayDraft.state != .verifyYesterday)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)
        }
    }

    private var primaryActionTitle: String {
        if store.isSavingTodayCompletion {
            return store.isAIRunning ? "正在回顾结果…" : "正在保存…"
        }
        if store.isAIRunning {
            return store.aiActivityMessage.isEmpty ? "明思训练中" : store.aiActivityMessage
        }

        switch store.todayDraft.state {
        case .verifyYesterday: return "保存结果回顾"
        case .capture:
            guard store.todayDraft.hasSelectedSessionMode else { return "选择复盘方式" }
            switch store.todayDraft.sessionMode {
            case .quick: return "快速整理成卡片"
            case .standard: return "整理成卡片"
            case .deep: return "深入整理成卡片"
            }
        case .organizing: return "查看卡片"
        case .reviewCards: return store.showsTrainingCaseConfirmation ? "确认事项" : "确认卡片"
        case .selectMode: return "确认模式"
        case .selectLens: return "进入今日复盘"
        case .answerQuestions:
            if store.coachAnswerTrainingFeedback?.hasStopped == true {
                return "先到这里，返回今日"
            }
            if store.answerReviewPrimaryActionSaves {
                return "先保存，返回今日"
            }
            if store.hasUnansweredRepairQuestion {
                return "回答这条追问"
            }
            if store.isVNextModelLed,
               store.hasAnsweredReflectionQuestion,
               store.coachAnswerTrainingFeedback == nil {
                return "提交回答复盘"
            }
            return store.canContinueAnswerQuestionsWithCoachGapOverride ? "先修补追问" : "设计明日验证"
        case .reviewQuests: return "保存验证，今天先到这里"
        case .reviewWithoutAction: return "保存回顾，今天先到这里"
        case .extractPrinciple: return "保存为我的原则"
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
        case .sessionComplete:
            return store.canNavigateTodayLoop(to: .extractPrinciple)
        case .selectLens, .answerQuestions, .reviewQuests, .reviewWithoutAction, .extractPrinciple:
            return true
        case .verifyYesterday, .capture, .organizing, .selectMode:
            return previousState != nil
        }
    }

    private var canSupplementCapture: Bool {
        switch store.todayDraft.state {
        case .reviewCards, .selectMode, .selectLens, .answerQuestions, .reviewQuests, .reviewWithoutAction, .extractPrinciple:
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

    private var currentVisibleStage: TodayVisibleStage? {
        TodayVisibleStage.allCases.first { $0.states.contains(store.todayDraft.state) }
    }

    private var currentVisibleStageTitle: String {
        currentVisibleStage?.title ?? "回看昨天"
    }

    private func visibleStageStatus(for stage: TodayVisibleStage) -> TodayVisibleStageStatus {
        guard let currentVisibleStage else { return .upcoming }
        if stage.rawValue < currentVisibleStage.rawValue {
            return .completed
        }
        if stage == currentVisibleStage {
            return .current
        }
        return .upcoming
    }

    private func canNavigate(to stage: TodayVisibleStage) -> Bool {
        store.todayDraft.state != stage.entryState && store.canNavigateTodayLoop(to: stage.entryState)
    }

    private var usesScrollableReviewActions: Bool {
        [.selectLens, .reviewQuests, .reviewWithoutAction].contains(store.todayDraft.state) && dynamicTypeSize.isAccessibilitySize
    }

    private var todayScrollBottomReserve: CGFloat {
        if usesScrollableReviewActions { return 24 }
        if store.todayDraft.state == .answerQuestions {
            return DS.primaryScrollBottomReserve
        }
        return DS.todayScrollBottomReserve
    }

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
                .foregroundStyle(isSelected ? DS.onAccent : DS.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(minHeight: DS.minimumTapTarget)
                .background(isSelected ? DS.accent : Color(.systemBackground), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func modeCard(mode: SessionMode, icon: String, description: String) -> some View {
        Button(action: { store.selectTodayMode(mode) }) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DS.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayTitle)
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
                Text("教练观察")
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
                Spacer()
                Text("\(store.todayDraft.sessionMode.displayTitle) · \(confirmedCount) 已确认")
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
                BriefRow(title: "你已经说了什么", body: "先从已确认卡片里看事实、判断、目标、约束和行动是否齐全。", accent: DS.accent)
                BriefRow(title: "先补哪里", body: "只抓一个当前最该补的漏想点，避免把训练变成泛泛提问。", accent: DS.brick)
                BriefRow(title: "推荐怎么练", body: "透镜只是练法；主线是补上没想清的部分，并保留你的改选权。", accent: DS.success)
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
                Text("可选视角")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.accentInk)
                Spacer()
                Image(systemName: isLensItemSelected(item) ? "checkmark.circle.fill" : "sparkles")
                    .foregroundStyle(isLensItemSelected(item) ? lensTint(for: item) : DS.mutedInk.opacity(0.62))
            }

            Text(item.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(DS.ink)

            // A model recommendation normally repeats the diagnosis reason.
            // Present that reason once while retaining distinct explanations.
            if prescription.recommendationReason.trimmingCharacters(in: .whitespacesAndNewlines)
                != store.coachDiagnosis?.reason.trimmingCharacters(in: .whitespacesAndNewlines) {
                Text(prescription.recommendationReason)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(item.methodLine)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.accentInk)
                .fixedSize(horizontal: false, vertical: true)

            Text("思考方向：\(prescription.primaryTrainingDimension.displayTitle)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.ink)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .fixedSize(horizontal: false, vertical: true)
                .background(lensTint(for: item).opacity(0.10), in: RoundedRectangle(cornerRadius: DS.smallRadius))

            if let teachingPlan {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isTrainingPrescriptionTeachingExpanded.toggle()
                    }
                } label: {
                    Label(
                        isTrainingPrescriptionTeachingExpanded ? "收起怎么练" : "查看怎么练",
                        systemImage: isTrainingPrescriptionTeachingExpanded ? "chevron.up.circle" : "map"
                    )
                    .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 6)
                        .frame(minHeight: DS.minimumTapTarget)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(DS.graphite)
                .accessibilityIdentifier(TodayAutomationID.trainingPrescriptionTeachingToggle)
                .accessibilityLabel(isTrainingPrescriptionTeachingExpanded ? "收起怎么练" : "查看怎么练")

                if isTrainingPrescriptionTeachingExpanded {
                    teachingRouteView(teachingPlan)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            if !prescription.baselineChecks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("基础检查")
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
                    Text("改选记录")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.accentInk)
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

            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))) {
                Button(action: { store.acceptTrainingPrescription() }) {
                    Label("接受推荐", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 6)
                        .frame(minHeight: DS.minimumTapTarget)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityIdentifier(TodayAutomationID.trainingPrescriptionAcceptAction)
                .foregroundStyle(DS.onAccent)

                Button(action: { store.skipTrainingPrescription() }) {
                    Label("跳过", systemImage: "forward.end")
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 6)
                        .frame(minHeight: DS.minimumTapTarget)
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
        .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(isLensItemSelected(item) ? lensTint(for: item).opacity(0.42) : lensTint(for: item).opacity(0.22), lineWidth: isLensItemSelected(item) ? 1.25 : 1)
        )
    }

    private func teachingRouteView(_ plan: CoachTeachingPlan) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            BriefRow(title: "哪里没想全", body: plan.missingMoveTitle, accent: DS.brick)
            BriefRow(title: "这次练什么", body: plan.trainingTargetLine, accent: DS.accent)
            BriefRow(title: "为什么先不直接给答案", body: plan.whyNotAnswer, accent: DS.caution)
            BriefRow(title: "什么时候继续", body: plan.proceedStandard, accent: DS.success)
            BriefRow(title: "建议补充", body: plan.repairQuestion, accent: DS.brick)
            BriefRow(title: "想想以前类似情况", body: plan.experienceReplayPrompt, accent: DS.graphite)
            experienceReplayDecisionView()

            VStack(alignment: .leading, spacing: 6) {
                Text("怎么练")
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
            Text("以前有没有类似情况")
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
        let isModelDecision = diagnosis.policyVersion.hasPrefix("coach-decision.llm")
        return VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                Text("当前材料的暂定理解")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DS.brick)
                Spacer()
                Image(systemName: coachDiagnosisIcon(for: diagnosis))
                    .foregroundStyle(DS.brick)
            }

            if !isModelDecision {
                Text("当前阶段：\(diagnosis.phase.displayTitle)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)

                Text("建议：\(diagnosis.recommendedMove.displayRecommendation)")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(DS.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let turnState, !turnState.openEvidenceGaps.isEmpty {
                Text("缺口：\(turnState.openEvidenceGaps.map(\.displayTitle).joined(separator: "、"))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.brick)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("today.coach-decision.material-gap")
            }

            Text(diagnosis.reason)
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("today.coach-decision.reason")

            if let turnState, !isModelDecision {
                Text("轮次：\(turnState.turnSummary)")
                    .font(.caption2)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !isModelDecision {
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
                    Text("透镜 \(String(format: "%02d", item.methodIndex)) · 推荐")
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                Button(action: { selectLensItem(item) }) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: isLensItemSelected(item) ? "checkmark.circle.fill" : item.symbolName)
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(isLensItemSelected(item) ? DS.accent : DS.mutedInk)
                            .frame(width: 24).frame(minHeight: 24)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.headline)
                                .foregroundStyle(DS.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(item.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(DS.mutedInk)
                                .fixedSize(horizontal: false, vertical: true)
                            if isRecommended {
                                Text("建议视角")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(DS.accentInk)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(DS.cardInnerPadding)
                    .frame(maxWidth: .infinity, minHeight: DS.minimumTapTarget, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(TodayAutomationID.lensAction(item))
                .accessibilityLabel(item.title)
                .accessibilityValue(isLensItemSelected(item) ? "已选择。" + lensMethodTileAccessibilityValue(item) : lensMethodTileAccessibilityValue(item))
                .accessibilityAddTraits(isLensItemSelected(item) ? .isSelected : [])

                Button { inspectedLens = item } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20, weight: .regular))
                        .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.accent)
                .accessibilityLabel("了解" + item.title)
                .accessibilityIdentifier("today.lens." + item.id + ".guide")
                .padding(.trailing, 6)
            }
            .fixedSize(horizontal: false, vertical: true)
            .background(isLensItemSelected(item) ? DS.accent.opacity(0.06) : .clear)

            if let overrideAuditText = lensDecisionOverrideAuditText(for: item) {
                Text(overrideAuditText)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(DS.cardInnerPadding)
                    .accessibilityIdentifier(TodayAutomationID.trainingPrescriptionDecisionOverrideAudit)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
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

            PushToTalkInput(
                text: text,
                placeholder: placeholder,
                accessibilityIdentifier: automationID,
                usesTextEditor: minHeight > 60
            )
                .font(.subheadline)
                .foregroundStyle(DS.ink)
                .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                        .stroke(DS.hairline, lineWidth: 1)
                )
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
        return "你已改选为「\(finalTitle)」；教练推荐「\(recommendedTitle)」仍保留记录，后续问题以改选透镜为主，同时继续做基础检查。"
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

func sideQuestRationaleDisplayText(for run: SideQuestRun) -> String? {
    guard run.origin == .aiGenerated,
          let rationale = run.decisionRationale?.trimmingCharacters(in: .whitespacesAndNewlines),
          !rationale.isEmpty,
          !rationale.contains("{")
    else {
        return nil
    }
    let prohibitedFragments = ["grounding_", "scene_", "availability_", "context_", "constraint_"]
    guard !prohibitedFragments.contains(where: { rationale.localizedCaseInsensitiveContains($0) }) else {
        return nil
    }
    return String(rationale.prefix(160))
}

// MARK: - Card Sub-Views

private enum TodayScrollAnchor {
    static let top = "today-top"
}

private struct LensGuideSheet: View {
    let item: LensCatalogItem
    let onSelect: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    guideSection("帮你练哪一步", text: item.purpose)
                    guideSection("适合什么时候", text: item.applicability)
                    guideSection("这次可以怎么想", text: item.questionSeeds.first ?? item.methodLine)
                    guideSection("使用边界", text: item.disableConditions.joined(separator: "\n\n"))
                    Text("一次只看一个角度。想清一处、保留未知或决定暂时不行动，都可以结束。")
                        .font(.subheadline)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(action: onSelect) {
                        Text("用这个视角")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.cardInnerPadding)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, minHeight: DS.minimumTapTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(DS.onAccent)
                    .accessibilityIdentifier("today.lens.guide.select")
                }
                .padding(DS.pagePadding)
            }
            .background(DS.background)
            .foregroundStyle(DS.ink)
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .tint(DS.accent)
        .accessibilityIdentifier("today.lens.guide.sheet")
    }

    private func guideSection(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            Text(text).font(.body).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
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
    let isModelLed: Bool
    let cardCount: Int
    let streamingCards: [StreamingCardDraft]
    let statusText: String
    let activityStatus: String
    let failureMessage: String?
    let canRetry: Bool
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ThreePetalSpiralLoadingMark()
                        .frame(width: 56, height: 56)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(organizingProgressTitle(isUsingOnlineModel: isUsingAI || isModelLed))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.ink)
                        Text(currentStatusText)
                            .font(.caption)
                            .foregroundStyle(DS.mutedInk)
                    }
                    Spacer()
                }

                ProgressView(value: progressValue)
                    .tint(DS.accent)
                    .progressViewStyle(.linear)

                Text("生成时会保持屏幕常亮。短暂切到后台会尝试完成，但 iOS 仍可能中断长连接。")
                    .font(.caption2)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
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
                    title: organizingProgressSourceStepCopy(isUsingOnlineModel: isUsingAI || isModelLed).title,
                    subtitle: organizingProgressSourceStepCopy(isUsingOnlineModel: isUsingAI || isModelLed).subtitle,
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
                    Label(
                        isModelLed ? "中央模型未完成" : organizingProgressLocalDraftLabel,
                        systemImage: "exclamationmark.triangle"
                    )
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
        organizingProgressFallbackStatusText(isUsingOnlineModel: isUsingAI)
    }

    private var currentStatusText: String {
        statusText.isEmpty ? activityStatus : "\(statusText) · \(activityStatus)"
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

func organizingProgressTitle(isUsingOnlineModel: Bool) -> String {
    isUsingOnlineModel ? "明思正在整理训练材料" : "明思正在准备本地训练草稿"
}

func organizingProgressFallbackStatusText(isUsingOnlineModel: Bool) -> String {
    isUsingOnlineModel ? "等待第一张候选卡片。" : "暂时使用本地训练草稿，你可以先继续确认材料。"
}

func organizingProgressSourceStepCopy(isUsingOnlineModel: Bool) -> (title: String, subtitle: String) {
    if isUsingOnlineModel {
        return (
            title: "整理输入材料",
            subtitle: "明思把原始输入拆成可确认的训练卡片。"
        )
    }
    return (
        title: "整理输入材料",
        subtitle: "暂时使用本地规则，先保留可编辑的训练卡片。"
    )
}

let organizingProgressLocalDraftLabel = "本次使用本地训练草稿"

let organizingStreamingConnectingStatusText = "明思正在整理训练材料。"

let organizingStreamingLocalDraftStatusText = "整理未完成，已使用本地训练草稿。"

func organizingStreamingInterruptedStatusText(closedCount: Int) -> String {
    "整理中断，已保留 \(closedCount) 张闭合卡片。"
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
    var isPrimaryAnswerField: Bool = false
    var isModelLed: Bool = false
    @State private var showsCoachBasis = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "scope")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.accent)
                Text(question.isRepairQuestion ? "继续追问" : (isModelLed ? "这一个问题" : "透镜追问"))
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
            }

            Text(question.question)
                .font(.headline.weight(.semibold))
                .foregroundStyle(DS.ink)
                .fixedSize(horizontal: false, vertical: true)

            if isModelLed {
                if let reason = trimmed(question.whyNow) ?? trimmed(question.whyItMatters) {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("today.question.reason")
                }
            } else {
                Text(compactRepairCue)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PushToTalkInput(text: $answer,
                placeholder: isModelLed ? "写下你的回答" : question.answerTrainingPrompt,
                accessibilityIdentifier: answerFieldAutomationID)
                .font(.subheadline)
                .frame(minHeight: 78, alignment: .topLeading)

            if hasCoachBasis {
                DisclosureGroup(isExpanded: $showsCoachBasis) {
                    if isModelLed {
                        materialExplanationView.padding(.top, 8)
                    } else {
                        coachBasisView.padding(.top, 8)
                    }
                } label: {
                    Label(isModelLed ? "为什么问这个问题" : "教练依据", systemImage: "list.bullet.clipboard")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                }
                .accessibilityIdentifier(TodayAutomationID.questionCoachBasisToggle)
            }
        }
        .questionSurface()
    }

    private var answerFieldAutomationID: String {
        isPrimaryAnswerField
            ? TodayAutomationID.questionAnswerField
            : TodayAutomationID.questionAnswerField(questionId: question.id.uuidString)
    }

    private var hasTeachingCue: Bool {
        question.lensMove != nil ||
            teachingGapTitle != nil ||
            trimmed(question.whyNow) != nil ||
            trimmed(question.expectedUpdate) != nil ||
            trimmed(question.proceedWhen) != nil
    }

    private var hasCoachBasis: Bool {
        if isModelLed {
            return (trimmed(question.whyItMatters) != nil && trimmed(question.whyItMatters) != trimmed(question.whyNow)) ||
                trimmed(question.expectedUpdate) != nil || trimmed(question.proceedWhen) != nil ||
                !question.sourceCardTitles.isEmpty || trimmed(question.calibrationTarget) != nil
        }
        return hasTeachingCue ||
            trimmed(question.whyItMatters) != nil ||
            !question.sourceCardTitles.isEmpty ||
            trimmed(question.calibrationTarget) != nil
    }

    private var compactRepairCue: String {
        if let gapTitle = teachingGapTitle {
            return "先补：\(gapTitle)"
        }
        if let proceedWhen = trimmed(question.proceedWhen) {
            return "先写到可以推进：\(proceedWhen)"
        }
        return trimmed(question.whyItMatters) ?? question.answerTrainingPrompt
    }

    /// Display the supplied question rationale, never a diagnosis reconstructed
    /// from a gap enum or a generic task inferred from its answer-use label.
    private var materialExplanationView: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let matters = trimmed(question.whyItMatters), matters != trimmed(question.whyNow) {
                BriefRow(title: "为什么值得想", body: matters, accent: DS.accent)
            }
            if let update = trimmed(question.expectedUpdate) {
                BriefRow(title: "回答能澄清什么", body: update, accent: DS.accent)
                    .accessibilityIdentifier("today.question.expected-update")
            }
            if let sufficient = trimmed(question.proceedWhen) {
                BriefRow(title: "回答到什么程度", body: sufficient, accent: DS.accent)
                    .accessibilityIdentifier("today.question.sufficient-answer")
            }
            if let target = trimmed(question.calibrationTarget) {
                BriefRow(title: "这次讨论的判断", body: target, accent: DS.mutedInk)
            }
            if !question.sourceCardTitles.isEmpty {
                BriefRow(title: "依据的材料", body: question.sourceCardTitles.joined(separator: "、"), accent: DS.mutedInk)
            }
        }
    }

    private var coachBasisView: some View {
        VStack(alignment: .leading, spacing: 7) {
            BriefRow(title: "教练判断", body: coachDecisionLine, accent: DS.accent)
            BriefRow(title: "先补一句", body: coachRepairLine, accent: DS.brick)
            if let lensMove = question.lensMove {
                BriefRow(title: "本题练法", body: lensMove.displayTitle, accent: DS.success)
            }
            if let answerUse = question.answerUse {
                BriefRow(title: "答案去向", body: answerUse.displayTitle, accent: DS.mutedInk)
            }
            if let coachPracticeReason {
                BriefRow(title: "为什么这样练", body: coachPracticeReason, accent: DS.success)
            }
        }
    }

    private var coachDecisionLine: String {
        if let gapTitle = teachingGapTitle {
            return "你现在先补\(gapTitle)，否则后面的回答容易变成泛泛判断。"
        }
        if let whyItMatters = trimmed(question.whyItMatters) {
            return whyItMatters
        }
        if let calibrationTarget = trimmed(question.calibrationTarget) {
            return "这题用来校准：\(calibrationTarget)"
        }
        return "这题不是让 AI 替你给答案，而是帮你把当前讲述补清楚。"
    }

    private var coachRepairLine: String {
        if let lensMove = question.lensMove {
            return "用\(lensMove.displayTitle)来回答：\(question.answerTrainingPrompt)"
        }
        return question.answerTrainingPrompt
    }

    private var coachPracticeReason: String? {
        if let whyNow = trimmed(question.whyNow) {
            return whyNow
        }
        if let expectedUpdate = trimmed(question.expectedUpdate) {
            return trainingUpdateCopy(expectedUpdate)
        }
        if let proceedWhen = trimmed(question.proceedWhen) {
            return "答到这里再继续：\(proceedWhen)"
        }
        return nil
    }

    private var teachingGapTitle: String? {
        guard let evidenceGapType = question.evidenceGapType else { return nil }
        if evidenceGapType == .none {
            return "取舍或框架问题"
        }
        return evidenceGapType.displayTitle
    }

    private func trainingUpdateCopy(_ text: String) -> String {
        text
            .replacingOccurrences(of: "答案会", with: "这次作答会")
            .replacingOccurrences(of: "答案应", with: "这次作答应")
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
    @State private var showsDetails = false
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
                Text(quest.type == .main ? "准备怎么做" : "辅助准备")
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
                    BriefRow(title: "完成证据", body: executionFeedback.evidenceLine, accent: quest.type == .main ? DS.accent : DS.mutedInk)
                    BriefRow(title: "校准问题", body: quest.reflectionQuestion, accent: DS.success)
                }

                DisclosureGroup(isExpanded: $showsDetails) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("内容检查（仅检查是否填写）")
                            .font(.caption)
                            .foregroundStyle(DS.mutedInk)
                        validationChecksView
                        BriefRow(title: "为什么重要", body: quest.whyItMatters, accent: quest.type == .main ? DS.accent : DS.mutedInk)
                        BriefRow(title: "阻力预案", body: executionFeedback.resistanceLine, accent: DS.caution)
                        BriefRow(title: "训练说明", body: executionFeedback.contractLine, accent: DS.success)
                        Text(executionFeedback.trainingLine)
                            .font(.caption)
                            .foregroundStyle(DS.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                        if let trainingTarget {
                            BriefRow(
                                title: "本次沿用的旧原则",
                                body: trainingTarget.principleTitle,
                                accent: DS.accent
                            )
                            Text("匹配依据：\(trainingTarget.matchSignal)。它只用于训练记录，不会替你改变明天要做的事。")
                                .font(.caption)
                                .foregroundStyle(DS.mutedInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !trainingPrinciples.isEmpty {
                            questTrainingPrinciplePicker
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Label("练习设置（可选）", systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                }
                .accessibilityIdentifier(TodayAutomationID.questDetailsToggle)
            }
        }
        .questSurface(isMain: quest.type == .main)
    }

    private var validationChecksView: some View {
        let checks = validationSummary.checks
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 12) {
                validationCheckView(checks[0])
                validationCheckView(checks[1])
            }
            HStack(spacing: 12) {
                validationCheckView(checks[2])
                validationCheckView(checks[3])
            }
        }
        .padding(.vertical, 2)
    }

    private func validationCheckView(_ check: QuestValidationCheck) -> some View {
        HStack(spacing: 5) {
            Image(
                systemName: check.isSatisfied
                    ? "checkmark.circle.fill"
                    : "exclamationmark.circle"
            )
            .font(.caption2.weight(.semibold))
            Text(check.dimension.title)
                .font(.caption2.weight(.semibold))
                .accessibilityIdentifier(TodayAutomationID.questValidationCheck(check.dimension))
        }
        .foregroundStyle(check.isSatisfied ? DS.success : DS.caution)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var validationSummary: QuestValidationSummary {
        QuestValidationPolicy().evaluate(quest)
    }

    private var questTrainingPrinciplePicker: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("手动指定旧原则")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.mutedInk)
            Picker(
                "复现原则",
                selection: Binding<PrincipleAsset.ID?>(
                    get: { quest.trainingPrincipleId },
                    set: { selectTrainingPrinciple($0) }
                )
            ) {
                Text("按内容匹配").tag(Optional<PrincipleAsset.ID>.none)
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
                Button(isEditing ? "完成编辑" : "编辑") {
                    if isEditing {
                        update(draftTitle, draftSummary, draftTrigger, draftActions, draftCriteria, draftExceptions)
                    }
                    isEditing.toggle()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .accessibilityIdentifier("today.principle.edit-action")
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
                ForEach(Array(principle.actions.enumerated()), id: \.offset) { index, action in
                    Text("\(index + 1). \(action)")
                        .font(.subheadline)
                }
                Text("成功标准：\(principle.successCriteria)")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                Text("例外条件：\(principle.exceptions.isEmpty ? "尚未说明，使用时保留判断。" : principle.exceptions)")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
            }
        }
        .onChange(of: [draftTitle, draftSummary, draftTrigger, draftActions, draftCriteria, draftExceptions]) { _, _ in
            guard isEditing else { return }
            update(draftTitle, draftSummary, draftTrigger, draftActions, draftCriteria, draftExceptions)
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
            PushToTalkInput(
                text: $text,
                placeholder: title,
                accessibilityIdentifier: "today.editable-field.\(title)",
                usesTextEditor: axis == .vertical
            )
                .font(.subheadline)
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

private struct CaptureMaterialGuide: View {
    private struct Item: Identifiable {
        let id: String
        let title: String
        let symbol: String
    }

    private let items = [
        Item(id: TodayAutomationID.captureMaterialEvent, title: "发生了什么", symbol: "text.bubble"),
        Item(id: TodayAutomationID.captureMaterialAction, title: "我怎么做", symbol: "figure.walk"),
        Item(id: TodayAutomationID.captureMaterialThought, title: "我怎么想", symbol: "brain.head.profile")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 5) {
                    Image(systemName: item.symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.accent)
                    Text(item.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .accessibilityIdentifier(item.id)
                }
                .frame(maxWidth: .infinity)

                if index < items.count - 1 {
                    Rectangle()
                        .fill(DS.hairline)
                        .frame(width: 1, height: 16)
                        .padding(.horizontal, 7)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("记录提示")
    }
}

private struct TrainingTerm: Identifiable {
    let title: String
    let meaning: String

    var id: String { title }
}

private struct TrainingTermsSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let cardTerms = [
        TrainingTerm(title: "事实", meaning: "已经发生或可以观察、核对的记录，不等于你的解释。"),
        TrainingTerm(title: "问题卡", meaning: "尚未看清、值得澄清的阻碍或缺口，不是在给你下结论。"),
        TrainingTerm(title: "决策", meaning: "你当前的取舍或判断，之后要用结果校准。"),
        TrainingTerm(title: "风险", meaning: "可能影响结果、但还没有被证实的担忧。"),
        TrainingTerm(title: "想法", meaning: "尚未验证的假设或可能路径。"),
        TrainingTerm(title: "沟通", meaning: "信息、责任或理解是否对齐的信号。"),
        TrainingTerm(title: "任务卡", meaning: "你输入里已经出现的行动或待办，不等同于明日验证。")
    ]

    private let trainingTerms = [
        TrainingTerm(title: "教练追问", meaning: "明思问你的问题，用来补一处材料；不是说你本身有问题。"),
        TrainingTerm(title: "验证任务", meaning: "从当前判断推出的明日小行动，要留下可观察结果，不是普通待办清单。"),
        TrainingTerm(title: "原则", meaning: "从多次证据中沉淀的可复用做法，之后仍要用反馈校正。"),
        TrainingTerm(title: "对照写法", meaning: "你回答后，明思基于现有事实给出的参考结构；它不是标准答案，也不替代事实结论。")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("这些词说明明思正在处理哪一种材料，不评价你这个人。")
                        .font(.subheadline)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)

                    termSection(
                        title: "思考卡片",
                        summary: "先确认或排除候选材料，再进入后续训练。",
                        terms: cardTerms
                    )

                    termSection(
                        title: "训练过程",
                        summary: "从材料到判断，再到可验证的下一步。",
                        terms: trainingTerms
                    )
                }
                .padding(.horizontal, DS.pagePadding)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .background(DS.background.ignoresSafeArea())
            .navigationTitle("训练术语")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier(TodayAutomationID.trainingTermsSheet)
    }

    private func termSection(title: String, summary: String, terms: [TrainingTerm]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DS.accent)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
            }
            .padding(.bottom, 8)

            ForEach(terms) { term in
                VStack(alignment: .leading, spacing: 4) {
                    Text(term.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.ink)
                    Text(term.meaning)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 11)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DS.hairline)
                        .frame(height: 1)
                }
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
                    Text("想想以前类似情况")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.ink)
                    Spacer()
                    Text("先判断如何迁移")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.mutedInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DS.surface, in: Capsule())
                }

                Text("这次先判断：复现、调整，还是否定；旧经验不能直接当成答案，先写出条件差异。")
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
                        PushToTalkInput(
                            text: Binding(
                                get: { feedbackNotes[principle.id, default: ""] },
                                set: { feedbackNotes[principle.id] = $0 }
                            ),
                            placeholder: "可选：为什么复现、调整或不复现？",
                            accessibilityIdentifier: TodayAutomationID.principleFeedbackNoteField
                        )
                        .font(.caption)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 118), spacing: 8)],
                            alignment: .leading,
                            spacing: 8
                        ) {
                            Button {
                                endEditing()
                                onFeedback(principle, .helpful, feedbackNotes[principle.id, default: ""])
                            } label: {
                                Label("适用，今天要复现", systemImage: "hand.thumbsup")
                            }
                            .accessibilityIdentifier(TodayAutomationID.principleFeedbackHelpfulAction)

                            Button {
                                endEditing()
                                onFeedback(principle, .adapted, feedbackNotes[principle.id, default: ""])
                            } label: {
                                Label("适用，但要调整", systemImage: "slider.horizontal.3")
                            }
                            .accessibilityIdentifier(TodayAutomationID.principleFeedbackAdaptedAction)

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
