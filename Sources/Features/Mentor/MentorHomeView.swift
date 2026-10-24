import SwiftUI
import GRDB

enum MentorAutomationID {
    static let quickCaptureAction = "mentor.quick-capture.open-action"
}

struct MentorHomeView: View {
    @EnvironmentObject private var app: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var feature: MentorFeatureStore
    @State private var showsConversation = false
    @State private var showsToday = false
    @State private var showsHistory = false
    @State private var showsQuickCapture = false
    @State private var opensCapturedConversation = false
    @State private var showsSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("忙了一天，也可以从一句话开始。")
                        .font(.title2.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text("不用先想清楚。回看一个片段，或者听一个新视角。")
                        .foregroundStyle(DS.mutedInk)
                    VStack(alignment: .leading, spacing: 12) {
                        if let recent = feature.state.latestUnfinishedSession {
                            entry("继续这次交流", symbol: "arrow.turn.down.right", primary: true) {
                                feature.continueSession(id: recent.id)
                                showsConversation = true
                            }
                            entry("开始新的回看", symbol: "arrow.counterclockwise") { start("review") }
                        } else {
                            entry("带我回看", symbol: "arrow.counterclockwise", primary: true) { start("review") }
                        }
                        entry("听一个新视角", symbol: "book", subtitle: feature.hasLessonCatalog ? "离线阅读，不需要配置模型" : nil,
                              disabled: !feature.hasLessonCatalog) { start("listen") }
                        entry("我有一件事", symbol: "square.and.pencil") { start("discuss") }
                    }
                    .disabled(feature.state.isTransitioningSession || feature.state.isLoadingHistory)
                    if !app.apiKeyConfigured {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("闪念、阅读和写下理解都可离线使用；在线交流需要配置模型。")
                                .font(.subheadline)
                                .foregroundStyle(DS.mutedInk)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("配置在线交流") { showsSettings = true }
                                .frame(minHeight: DS.minimumTapTarget)
                                .accessibilityIdentifier("mentor.home.model-settings")
                        }
                    .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("mentor.home.offline-capabilities")
                    }
                    if !feature.hasLessonCatalog {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("新视角内容暂不可用", systemImage: "book.closed")
                                .font(.subheadline.weight(.semibold))
                            Text("当前版本没有可用的已审核教材。你仍可以输入一件事，或查看已有交流。")
                                .font(.caption)
                                .foregroundStyle(DS.mutedInk)
                        }
                        .foregroundStyle(DS.caution)
                        .accessibilityIdentifier("mentor.lesson.catalog-unavailable")
                    }
                    Button {
                        showsQuickCapture = true
                    } label: {
                        Label("先记一条闪念", systemImage: "bolt")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier(MentorAutomationID.quickCaptureAction)
                    LifeGuidanceSection(guidance: app.lifeGuidanceStore)
                    if !feature.state.recentSessions.isEmpty {
                        Text("最近交流").font(.headline).accessibilityAddTraits(.isHeader)
                        ForEach(feature.state.recentSessions) { session in
                            Button {
                                feature.viewSession(id: session.id)
                                showsConversation = true
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(session.preview.isEmpty ? "还没说完的交流" : session.preview).lineLimit(2)
                                    Text(session.activityAt, style: .date)
                                        .font(.subheadline).foregroundStyle(DS.mutedInk)
                                }
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if feature.state.historyError != nil {
                        Text("最近交流暂时没能读取，请重试。")
                        Button("重新读取") { feature.loadRecentSessions() }
                            .controlSize(.large).buttonStyle(.bordered)
                    }
                    Button("查看全部交流") { showsHistory = true }
                        .controlSize(.large).buttonStyle(.bordered)
                        .frame(minHeight: 44)
                    Divider()
                    Button { showsToday = true } label: {
                        Label("今日整理", systemImage: "list.bullet.rectangle")
                            .frame(minHeight: 44)
                    }
                    Text("原来的完整训练仍在这里。")
                        .font(.subheadline).foregroundStyle(DS.mutedInk)
                }
                .frame(maxWidth: 640, alignment: .leading)
                .padding(DS.pagePadding)
                .frame(maxWidth: .infinity)
            }
            .background(DS.background)
            .foregroundStyle(DS.ink)
            .navigationTitle("明思")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DS.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(DS.accent)
        .task { feature.loadRecentSessions() }
        .sheet(isPresented: $showsConversation, onDismiss: { feature.loadRecentSessions() }) {
            MentorConversationView(feature: feature)
                .environmentObject(app)
                .dynamicTypeSize(dynamicTypeSize)
        }
        .sheet(isPresented: $showsHistory, onDismiss: { feature.loadRecentSessions() }) {
            MentorHistoryView(feature: feature).environmentObject(app)
        }
        .sheet(isPresented: $showsQuickCapture, onDismiss: {
            if opensCapturedConversation {
                opensCapturedConversation = false
                showsConversation = true
            }
        }) {
            QuickCaptureSheet(onDiscuss: { captureID in
                guard await feature.startCaptureSession(from: captureID) else { return false }
                opensCapturedConversation = true
                showsQuickCapture = false
                return true
            })
                .environmentObject(app)
                .dynamicTypeSize(dynamicTypeSize)
        }
        .onReceive(NotificationCenter.default.publisher(for: .mingsiOpenTodayCapture)) { _ in
            showsQuickCapture = true
        }
        .sheet(isPresented: $showsToday) {
            TodayView(mentorFeature: feature)
                .environmentObject(app)
                .accessibilityIdentifier("mentor.legacy-today")
        }
        .sheet(isPresented: $showsSettings) { SettingsView().environmentObject(app) }
    }

    @ViewBuilder
    private func entry(_ title: String, symbol: String, subtitle: String? = nil, primary: Bool = false, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        let button = Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: symbol)
                if let subtitle {
                    Text(subtitle).font(.caption).fixedSize(horizontal: false, vertical: true)
                }
            }
                .multilineTextAlignment(.leading)
                .padding(.vertical, 6)
                .foregroundStyle(primary ? DS.onAccent : DS.accentInk)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "")
        .controlSize(.large)
        .disabled(disabled)
        if primary { button.buttonStyle(.borderedProminent) }
        else { button.buttonStyle(.bordered) }
    }

    private func start(_ entry: String) {
        // A zero-material review can ask the model for a concrete recall
        // starting point. Without a configured model, keep the local editor
        // available so the entry never turns into a dead end.
        feature.start(entry: entry, automaticallyOpenReview: entry != "review" || app.apiKeyConfigured)
        showsConversation = true
    }
}

struct QuickCaptureSheet: View {
    var onDiscuss: ((UUID) async -> Bool)? = nil
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    private let initialText: String
    private var text: String { store.captureInputDraft.text }
    @State private var isSaving = false
    @State private var inputFocused = false
    @State private var isDiscussing = false
    @State private var discussionError: String?
    @State private var discussionCaptureID: UUID?
    @State private var hasPendingSpeech = false
    @State private var confirmsDiscard = false

    private var hasUnsavedInput: Bool {
        !store.captureInputDraft.isEmpty || hasPendingSpeech
    }

    init(initialText: String = "", onDiscuss: ((UUID) async -> Bool)? = nil) {
        self.onDiscuss = onDiscuss
        self.initialText = initialText
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("先把想法留下，稍后再决定是否整理。")
                        .font(.subheadline)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)

                    PushToTalkInput(
                        text: Binding(get: { text }, set: { value in
                            var next = store.captureInputDraft
                            next.text = value
                            store.updateCaptureInputDraft(next)
                        }),
                        placeholder: "此刻想到什么？",
                        accessibilityIdentifier: TodayAutomationID.capturesInput,
                        focusBinding: $inputFocused,
                        pendingSpeechBinding: $hasPendingSpeech,
                        speechPreviewBinding: Binding(get: { store.captureInputDraft.speechPreview }, set: { value in
                            guard store.captureInputDraft.speechPreview != value else { return }
                            var next = store.captureInputDraft
                            next.speechPreview = value
                            store.updateCaptureInputDraft(next)
                        }),
                        onAcceptSpeech: { store.acceptCaptureSpeech($0) },
                        usesTextEditor: true,
                        autofocus: true
                    )
                    .disabled(isSaving || isDiscussing || !store.captureDraftCanEdit)
                    .frame(minHeight: 132, alignment: .top)
                    .padding(8)
                    .background(DS.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(DS.hairline, lineWidth: 1)
                    }
                    .accessibilityElement(children: .contain)

                    if !store.captureDraftMessage.isEmpty {
                        Text(store.captureDraftMessage)
                            .font(.footnote)
                            .foregroundStyle(store.captureDraftWriteFailed ? DS.caution : DS.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("today.captures.draft-status")
                        if store.captureDraftWriteFailed {
                            Button("重试草稿存储") {
                                if store.captureDraftCanEdit { store.persistCaptureInputDraft() }
                                else { store.loadCaptureInputDraft(initialText: initialText) }
                            }
                            .frame(minHeight: DS.minimumTapTarget)
                        }
                    }

                    Button {
                        isSaving = true
                        Task {
                            if store.saveCaptureInputDraft() { await store.refreshTodayCaptures() }
                            isSaving = false
                        }
                    } label: {
                        Label(isSaving ? "正在保存" : "保存闪念", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity, minHeight: DS.minimumTapTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.accent)
                    .foregroundStyle(DS.onAccent)
                    .disabled(isSaving || isDiscussing || !store.captureDraftCanEdit || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier(TodayAutomationID.capturesSaveAction)

                    if !store.captureDigestMessage.isEmpty {
                        Text(store.captureDigestMessage)
                            .font(.footnote)
                            .foregroundStyle(DS.mutedInk)
                    }

                    if store.todayCaptureFragments.isEmpty {
                        Text("今天还没有其他闪念。")
                            .font(.subheadline)
                            .foregroundStyle(DS.mutedInk)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("今天的闪念")
                                .font(.headline)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(store.todayCaptureFragments) { fragment in
                                HStack(alignment: .top, spacing: 10) {
                                    Text(fragment.rawText)
                                        .font(.body)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                    if fragment.status == .pending {
                                        Button {
                                            Task { await store.archiveCaptureFragment(fragment.id) }
                                        } label: {
                                            Image(systemName: "archivebox")
                                                .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("归档闪念")
                                    } else {
                                        Text(fragment.status == .included ? "已整理" : "已归档")
                                            .font(.caption)
                                            .foregroundStyle(DS.mutedInk)
                                    }
                                }
                                if let onDiscuss {
                                    Button {
                                        isDiscussing = true
                                        discussionError = nil
                                        discussionCaptureID = fragment.id
                                        inputFocused = false
                                        Task {
                                            let opened = await onDiscuss(fragment.id)
                                            if !opened { discussionError = "暂时没能开始交流，闪念仍保留。请重试。" }
                                            isDiscussing = false
                                        }
                                    } label: {
                                        Label("聊聊这条闪念", systemImage: "bubble.left")
                                            .frame(minHeight: DS.minimumTapTarget)
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isDiscussing || isSaving || hasUnsavedInput)
                                    .accessibilityIdentifier("mentor.capture.discuss.\(fragment.id.uuidString)")
                                    .accessibilityHint("把这条原文带入新的交流，保留原闪念")
                                    if discussionCaptureID == fragment.id {
                                        if isDiscussing { ProgressView("正在带入闪念…") }
                                        if let discussionError {
                                            Text(discussionError).foregroundStyle(DS.caution)
                                                .fixedSize(horizontal: false, vertical: true)
                                                .accessibilityIdentifier("mentor.capture.discussion-error")
                                        }
                                    }
                                }
                                if fragment.id != store.todayCaptureFragments.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }

                    if onDiscuss != nil, !store.todayCaptureFragments.isEmpty,
                       !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("先保存当前闪念，再选择一条开始交流。")
                            .font(.footnote).foregroundStyle(DS.mutedInk)
                    }

                    if store.todayCaptureFragments.filter({ $0.status == .pending }).count >= 2 {
                        Button {
                            Task { await store.generateTodayCaptureDigest() }
                        } label: {
                            Label(store.isGeneratingCaptureDigest ? "正在整理" : "整理今天的闪念", systemImage: "sparkles")
                                .frame(maxWidth: .infinity, minHeight: DS.minimumTapTarget)
                        }
                        .buttonStyle(.bordered)
                        .tint(DS.accent)
                        .disabled(store.isGeneratingCaptureDigest)
                        .accessibilityIdentifier(TodayAutomationID.capturesDigestAction)
                    }

                    if let digest = store.todayCaptureDigest {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(digest.summary)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                            if !digest.themes.isEmpty {
                                Text(digest.themes.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(DS.accent)
                            }
                            if let question = digest.recommendedQuestion {
                                Text(question)
                                    .font(.footnote)
                                    .foregroundStyle(DS.mutedInk)
                            }
                            HStack {
                                Button("带入今日整理") {
                                    Task { await store.acceptTodayCaptureDigest() }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(DS.accent)
                                Button("暂不处理") {
                                    Task { await store.ignoreTodayCaptureDigest() }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(12)
                        .background(DS.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(DS.pagePadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(DS.background)
            .foregroundStyle(DS.ink)
            .navigationTitle("今日闪念")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier(TodayAutomationID.capturesSheet)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        inputFocused = false
                        if hasUnsavedInput { confirmsDiscard = true }
                        else { dismiss() }
                    }
                        .frame(minWidth: 44, minHeight: 44)
                        .disabled(isSaving || isDiscussing)
                        .accessibilityIdentifier("today.captures.close-action")
                }
            }
        }
        .tint(DS.accent)
        .interactiveDismissDisabled(hasUnsavedInput || isSaving || isDiscussing)
        .alert("丢弃未保存的闪念？", isPresented: $confirmsDiscard) {
            Button("丢弃并关闭", role: .destructive) {
                if store.discardCaptureInputDraft() { dismiss() }
            }
            Button("保留草稿并关闭") {
                if store.persistCaptureInputDraft() { dismiss() }
            }
            Button("继续编辑", role: .cancel) {}
        } message: {
            Text("可保留本机草稿，下次继续；丢弃会删除文字和待确认的识别结果。")
        }
        .onAppear {
            store.loadCaptureInputDraft(initialText: initialText)
            _ = CaptureShortcutBridge.consumePendingRequest()
        }
        .onReceive(NotificationCenter.default.publisher(for: .mingsiOpenTodayCapture)) { _ in
            // A repeated quick action while this editor is already mounted is
            // fulfilled here; it must not reopen capture on the next launch.
            _ = CaptureShortcutBridge.consumePendingRequest()
        }
        .task {
            await store.refreshTodayCaptures()
        }
    }
}

/// The legacy Today single-question flow, kept within its compatibility entry.
struct SingleNudgeSheet: View {
    @EnvironmentObject private var store: AppStore
    @Binding var isPresented: Bool
    @State private var input = ""
    @State private var answer = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                interaction
                    .padding(DS.pagePadding)
            }
            .navigationTitle("明思一下")
            .accessibilityIdentifier(TodayAutomationID.singleNudgeSurface)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { isPresented = false }
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
        .tint(DS.accent)
        .onAppear { restoreFields() }
        .onChange(of: store.singleNudgeSession?.id) { _, _ in restoreFields() }
        .onChange(of: store.singleNudgeSession?.lifecycle) { _, _ in restoreFields() }
    }

    private var interaction: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("明思一下").font(.headline)
                    if store.singleNudgeSession == nil {
                        Text("输入一件现在卡住你的事，只问一个关键问题。")
                            .font(.subheadline)
                            .foregroundStyle(DS.mutedInk)
                    }
                }
                Spacer()
                if store.isSingleNudgeGenerating {
                    ProgressView().accessibilityLabel("明思一下生成中")
                    Button("取消") { store.cancelSingleNudgeRequest() }
                        .buttonStyle(.borderless)
                        .frame(minHeight: 44)
                }
            }
            if let session = store.singleNudgeSession, let question = session.question {
                Text(question)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(TodayAutomationID.singleNudgeQuestion)
                if session.lifecycle == .receiptPresented || session.lifecycle == .feedbackRecorded || session.lifecycle == .completed,
                   let diagnosis = session.diagnosis {
                    receipt(diagnosis, session: session)
                } else {
                    PushToTalkInput(text: $answer, placeholder: "用自己的话重新表达", accessibilityIdentifier: TodayAutomationID.singleNudgeAnswer, autofocus: true)
                        .padding(8)
                        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
                    Button("看看刚才的想法") { Task { await store.submitSingleNudgeAnswer(answer) } }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier(TodayAutomationID.singleNudgeReviewAction)
                        .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isSingleNudgeGenerating)
                    if !store.singleNudgeMessage.isEmpty {
                        Text(store.singleNudgeMessage).font(.caption).foregroundStyle(DS.mutedInk)
                    }
                    if session.after != nil && session.diagnosis == nil {
                        Button("再试一次") { Task { await store.retrySingleNudgeReview() } }
                            .buttonStyle(.bordered)
                            .frame(minHeight: 44)
                            .accessibilityIdentifier(TodayAutomationID.singleNudgeRetryReviewAction)
                    }
                }
            } else if let session = store.singleNudgeSession,
                      session.lifecycle == .draft || session.lifecycle == .generatingQuestion {
                inputEditor(isGenerating: session.lifecycle == .generatingQuestion, sessionInput: session.input)
            } else {
                inputEditor(isGenerating: false, sessionInput: nil)
            }
        }
    }

    @ViewBuilder
    private func inputEditor(isGenerating: Bool, sessionInput: String?) -> some View {
        PushToTalkInput(text: $input, placeholder: "现在什么事情卡住你了？", accessibilityIdentifier: TodayAutomationID.singleNudgeInput, autofocus: true)
            .padding(8)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
        Button(isGenerating ? "生成中…" : "开始明思") {
            let cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
            if sessionInput != cleaned {
                guard store.startSingleNudge(input: cleaned) else { return }
            }
            Task { await store.generateSingleNudgeQuestion() }
        }
        .buttonStyle(.borderedProminent)
        .frame(minHeight: 44)
        .accessibilityIdentifier(TodayAutomationID.singleNudgeStartAction)
        .disabled(isGenerating || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        if !store.singleNudgeMessage.isEmpty {
            Text(store.singleNudgeMessage).font(.caption).foregroundStyle(DS.mutedInk)
        }
    }

    @ViewBuilder
    private func receipt(_ diagnosis: String, session: SingleNudgeSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(diagnosis).font(.body).fixedSize(horizontal: false, vertical: true)
            if let shift = session.cognitiveShift { detail("刚刚发生的变化", shift) }
            if let action = session.thinkingAction { detail("此刻可以继续想", action) }
            if let uncertainty = session.unresolvedUncertainty { detail("还没确定", uncertainty, muted: true) }
        }
        switch session.lifecycle {
        case .receiptPresented:
            VStack(spacing: 8) {
                Button("点到了") { store.chooseSingleNudgeFeedback(.helpful) }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier(TodayAutomationID.singleNudgeHelpfulAction)
                Button("没点到") { store.chooseSingleNudgeFeedback(.notHelpful) }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier(TodayAutomationID.singleNudgeNotHelpfulAction)
            }
        case .feedbackRecorded:
            if session.feedback == .notHelpful {
                VStack(spacing: 8) {
                    Button("换个角度") { Task { await store.tryAnotherSingleNudgeAngle() } }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier(TodayAutomationID.singleNudgeAlternateAngleAction)
                    finishButton
                }
            } else if session.feedback == .helpful {
                VStack(spacing: 8) {
                    Button("继续想一层") { Task { await store.continueSingleNudgeOneLayer() } }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier(TodayAutomationID.singleNudgeDeeperAction)
                    finishButton
                    if session.transitionToVerification == true {
                        Button("带入行动验证") {
                            isPresented = false
                            store.finishSingleNudge(atVerification: true)
                        }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .accessibilityIdentifier(TodayAutomationID.singleNudgeTransitionAction)
                    }
                }
            } else {
                finishButton
            }
        case .completed:
            Button("再明思一件") {
                input = ""
                answer = ""
                store.prepareAnotherSingleNudge()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityIdentifier(TodayAutomationID.singleNudgeAnotherAction)
        default:
            EmptyView()
        }
    }

    private var finishButton: some View {
        Button("到这里") { store.finishSingleNudge() }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityIdentifier(TodayAutomationID.singleNudgeFinishAction)
    }

    private func detail(_ label: String, _ value: String, muted: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption.weight(.semibold))
            Text(value).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(muted ? DS.mutedInk : DS.ink)
    }

    private func restoreFields() {
        guard let session = store.singleNudgeSession else { return }
        input = session.input
        answer = session.after ?? ""
    }
}

struct MentorConversationView: View {
    private struct RequestReveal: Hashable {
        let sessionID: UUID?
        let isSubmitting: Bool
        let latestItemID: UUID?
        let hasPreview: Bool
    }
    private struct ComposerHeight: PreferenceKey {
        static let defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
    }
    @EnvironmentObject private var app: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var feature: MentorFeatureStore
    @State private var inputFocused = false
    @State private var composerContentHeight: CGFloat = 180
    @State private var wantsClose = false
    @State private var pendingExitEnding = false
    @State private var showsDiscardUnsavedDraftConfirmation = false
    @State private var showsSettings = false
    @State private var needsConfiguration = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var readingPosition = MentorReadingPositionCoordinator()
    @StateObject private var readingGeometry = MentorReadingGeometry()
    @State private var showsDeleteConfirmation = false
    @State private var sourceSelection: MentorSourceSelection?
    @State private var correctionSelection: MentorCorrectionSelection?

    var body: some View {
        NavigationStack {
            GeometryReader { viewport in
                ScrollViewReader { scroll in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if feature.state.isTransitioningSession {
                                ProgressView(feature.state.isDeletingSession ? "正在删除交流…" : "正在保存和打开交流…")
                            } else {
                                content
                                if feature.state.session != nil {
                                    MentorUnderstandingSection(store: feature)
                                }
                            }
                        }
                        .frame(maxWidth: 640, alignment: .leading)
                        .padding(DS.pagePadding)
                        .frame(maxWidth: .infinity)
                        .background(MentorReadingScrollProbe(geometry: readingGeometry, coordinator: readingPosition,
                            lesson: feature.state.isTransitioningSession ? nil : feature.state.lesson,
                            layoutKey: "\(Int(viewport.size.width.rounded()))/\(dynamicTypeSize)",
                            canSave: !feature.state.isViewingHistory,
                            isActive: !feature.state.isTransitioningSession && !wantsClose && scenePhase != .background,
                            save: { [weak feature] position in
                                feature?.saveReadingPosition(itemID: position.itemID, section: position.section,
                                    offset: position.offset, layoutKey: position.layoutKey)
                            }, presented: { [weak feature] id in
                                guard let feature, !feature.state.isTransitioningSession else { return }
                                if id == feature.state.responseItemID { feature.acknowledgeResponse(itemID: id) }
                                if id == feature.state.lesson?.id { feature.acknowledgeLesson() }
                            }))
                    }
                    .onChange(of: feature.state.isTransitioningSession) { _, transitioning in
                        if transitioning { readingPosition.reset() }
                    }
                    .accessibilityIdentifier("mentor.conversation.reading-scroll")
                    .scrollDismissesKeyboard(.interactively)
                    .task(id: RequestReveal(sessionID: feature.state.session?.id,
                                            isSubmitting: feature.state.phase == .submitting,
                                            latestItemID: feature.state.timeline.last?.id,
                                            hasPreview: !feature.state.streamingPreview.isEmpty)) {
                        guard feature.state.phase == .submitting, !feature.state.isViewingHistory, !inputFocused else { return }
                        // Wait for the lazy timeline and new status to acquire
                        // their layout. This task restarts only at transitions,
                        // never for each streamed character or scroll offset.
                        do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
                        guard !Task.isCancelled, feature.state.phase == .submitting,
                              !feature.state.isViewingHistory, !inputFocused else { return }
                        scroll.scrollTo("mentor.conversation.request-start", anchor: .top)
                    }
                    .onChange(of: feature.state.responseItemID) { _, id in
                        guard let id, !feature.state.isViewingHistory else { return }
                        Task { @MainActor in
                            await Task.yield()
                            guard feature.state.responseItemID == id, !feature.state.isViewingHistory, !inputFocused else { return }
                            scroll.scrollTo(id, anchor: .top)
                        }
                    }
                    .task(id: "\(feature.state.lesson?.id.uuidString ?? "")/\(feature.state.isTransitioningSession)") {
                        guard !feature.state.isTransitioningSession, let lesson = feature.state.lesson else { return }
                        await Task.yield()
                        guard !Task.isCancelled else { return }
                        readingPosition.revealIfNeeded(itemID: lesson.id) {
                            scroll.scrollTo(lesson.id, anchor: .top)
                        }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if showsComposer {
                        conversationComposer(viewportHeight: viewport.size.height)
                    }
                }
            }
            .background(DS.background)
            .foregroundStyle(DS.ink)
            .navigationTitle("这次交流")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DS.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("返回") { leave(ending: false) }
                        .frame(minWidth: 44, minHeight: 44)
                        .disabled(feature.state.isTransitioningSession)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if feature.state.isViewingHistory {
                        Menu {
                            Button("删除这次交流", role: .destructive) { showsDeleteConfirmation = true }
                        } label: {
                            Label("交流操作", systemImage: "ellipsis.circle")
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .disabled(feature.state.isTransitioningSession)
                    } else {
                        Button("到这里") { leave(ending: true) }
                            .frame(minWidth: 44, minHeight: 44)
                            .disabled(feature.state.isTransitioningSession)
                    }
                }
            }
        }
        .tint(DS.accent)
        .interactiveDismissDisabled()
        .alert("删除这次交流？", isPresented: $showsDeleteConfirmation) {
            Button("删除整段交流", role: .destructive) {
                Task { @MainActor in
                    if await feature.deleteViewedSession() { dismiss() }
                }
            }
            Button("保留交流", role: .cancel) {}
        } message: {
            Text("这次交流的原话、草稿、理解和反馈会一起删除，无法撤销。引用的闪念与事项原始资料会保留。")
        }
        .alert("放弃未保存改动并返回？", isPresented: $showsDiscardUnsavedDraftConfirmation) {
            Button("放弃并返回", role: .destructive) {
                let ending = pendingExitEnding
                wantsClose = true
                Task { @MainActor in
                    _ = await feature.discardUnsavedDraftAndExit(ending: ending)
                }
            }
            Button("继续编辑", role: .cancel) {}
        } message: {
            Text("最近一次成功保存的草稿会保留，当前尚未保存的文字将丢失。")
        }
        .sheet(isPresented: $showsSettings) { SettingsView().environmentObject(app) }
        .sheet(item: $sourceSelection) { selection in
            MentorSourceDetailView(feature: feature, references: selection.references)
        }
        .sheet(item: $correctionSelection) { selection in
            MentorCorrectionEditor(feature: feature, selection: selection)
        }
        .onChange(of: app.aiConfigurationRevision) { _, _ in
            guard app.apiKeyConfigured else { return }
            // Settings is a detour from the same conversation. Once a valid
            // configuration is saved, return to the preserved input and draft.
            needsConfiguration = false
            showsSettings = false
        }
        .onChange(of: feature.state.isTransitioningSession) { _, transitioning in
            guard wantsClose, !transitioning else { return }
            wantsClose = false
            if feature.state.phase == .paused || feature.state.phase == .ended { dismiss() }
        }
        .onDisappear { flushReadingPosition(); readingGeometry.reset(); readingPosition.reset() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, !feature.state.isTransitioningSession, !feature.state.isViewingHistory {
                flushReadingPosition()
                feature.pause()
            }
        }
    }

    @ViewBuilder private var content: some View {
        if feature.state.isViewingHistory {
            Text(feature.state.session?.lifecycle == .ended ? "已结束的交流" : "历史交流 · 仅查看")
                .font(.subheadline).foregroundStyle(DS.mutedInk)
                .accessibilityAddTraits(.isHeader)
            if !feature.state.inputText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("保留的输入").font(.headline).accessibilityAddTraits(.isHeader)
                    Text(feature.state.inputText).textSelection(.enabled)
                }
            }
            if let chain = feature.state.legacyChain, !chain.canContinueAutomatically {
                legacyRecoverySection(chain)
            }
        }
        if !feature.state.isViewingHistory, feature.state.timeline.isEmpty && feature.state.lesson == nil {
            if feature.state.session?.initialEntry == "listen" {
                Text("暂时没有可读的新视角，可以先聊聊你手上的一件事。")
            } else {
            Text(feature.state.session?.initialEntry == "review" ?
                 "今天有没有一个让你停了一下的时刻？一个改动、一次沟通，都可以。" : "这件事，先从你最想说的地方开始。")
                .font(.title3.weight(.medium))
            }
        }
        LazyVStack(alignment: .leading, spacing: 24) {
            ForEach(feature.state.timeline, id: \.id) { item in
                // Keep one stable lazy row per item; conditional multiple children
                // make lazy layout and scroll-to identity depend on visibility.
                VStack(alignment: .leading, spacing: 24) {
                    if item.kind == .user,
                       let text = (try? JSONDecoder().decode([String: String].self, from: Data(item.payloadJSON.utf8)))?["text"] {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(feature.state.timeline.contains { $0.supersedesItemID == item.id } ? "更正前的原话 · 已保留" :
                                (item.supersedesItemID != nil ? "更正后的原话" :
                                    (feature.state.borrowedCaptureSources[item.id] == nil ? "你说" : "从闪念带入")))
                                .font(.subheadline).foregroundStyle(DS.mutedInk)
                                .accessibilityAddTraits(.isHeader)
                            MentorOriginalText(text: text)
                            if let references = feature.state.borrowedCaptureSources[item.id] {
                                sourceButton(references)
                            }
                            if feature.canCorrectUserItem(item.id) {
                                Button {
                                    inputFocused = false
                                    correctionSelection = MentorCorrectionSelection(id: item.id, text: text)
                                } label: {
                                    Label("更正这条原话", systemImage: "pencil")
                                        .frame(minHeight: 44)
                                }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("mentor.correction.open.\(item.id.uuidString)")
                                .accessibilityHint("保留原文，保存更正后的版本，停止基于旧原话的请求")
                            }
                        }
                    } else if item.kind == .lesson, let saved = decodeLesson(item.payloadJSON) {
                        lesson(saved, itemID: item.id)
                    } else if item.kind == .assistant,
                              let response = try? JSONDecoder().decode(MentorTurnResponse.self, from: Data(item.payloadJSON.utf8)) {
                        VStack(alignment: .leading, spacing: 12) {
                            if item.sequence < (feature.state.timeline.filter { $0.supersedesItemID != nil }.map(\.sequence).max() ?? 0) {
                                Label("更正之前的 AI 回应", systemImage: "clock.arrow.circlepath")
                                    .font(.subheadline).foregroundStyle(DS.mutedInk)
                            }
                            Text(response.body).textSelection(.enabled)
                            if let question = response.question { Text(question).fontWeight(.medium) }
                            if !response.sourceRefs.isEmpty {
                                sourceButton(response.sourceRefs)
                            }
                        }
                        .background(MentorReadingMarker(geometry: readingGeometry, itemID: item.id))
                    }
                }
                .id(item.id)
            }
        }
        Color.clear.frame(height: 1).id("mentor.conversation.request-start")
        VStack(alignment: .leading, spacing: 12) { status }
            .id("mentor.conversation.request-status")
        if feature.state.session?.initialEntry == "review", let sessionID = feature.state.session?.id {
            LifeGuidanceReviewSection(guidance: app.lifeGuidanceStore, reviewID: "mentor:" + sessionID.uuidString)
        }
        if feature.state.benefitFeedback != nil ||
            (!feature.state.isViewingHistory && (feature.state.responseItemID != nil || feature.state.lesson != nil)) {
            benefitFeedbackSection
        }
        if let chain = feature.state.legacyChain, !chain.canContinueAutomatically {
            EmptyView()
        } else if feature.state.isViewingHistory || feature.state.phase == .paused || feature.state.phase == .ended {
            Button("继续这件事") {
                if let id = feature.state.session?.id { feature.continueSession(id: id) }
            }.buttonStyle(.bordered).controlSize(.large)
        } else if feature.state.session != nil {
            input
        }
    }

    @ViewBuilder
    private func legacyRecoverySection(_ chain: LegacyNudgeChain) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("旧点拨的轮次关系不完整", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundStyle(DS.caution)
                .accessibilityIdentifier("mentor.legacy.lineage-warning")
            Text("这段历史仍可查看。为避免把缺失的轮次当成事实，请选择一条保留的记录，从它开启一段新的交流。")
                .font(.subheadline)
                .foregroundStyle(DS.mutedInk)
            ForEach(chain.rounds) { round in
                Button {
                    feature.startIndependentLegacySession(fromRoundID: round.id)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(round.session.input.isEmpty ? "从这条旧记录开始" : round.session.input)
                            .lineLimit(3)
                        if let question = round.session.question, !question.isEmpty {
                            Text(question)
                                .font(.caption)
                                .foregroundStyle(DS.mutedInk)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .disabled(feature.state.isTransitioningSession)
                .accessibilityIdentifier("mentor.legacy.recover.\(round.id.uuidString)")
            }
        }
        .padding(12)
        .background(DS.cardBackground, in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                .stroke(DS.caution.opacity(0.45), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var benefitFeedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("这次交流对你有帮助吗？")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if let saved = feature.state.benefitFeedback {
                Label("已记录：\(saved.kind.title)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(DS.accent)
                if let note = saved.note, !note.isEmpty {
                    Text(note)
                        .font(.callout)
                        .textSelection(.enabled)
                }
            }
            if !feature.state.isViewingHistory {
                Text("这是可选反馈。可以写下具体看清或改变了什么。")
                    .font(.subheadline)
                    .foregroundStyle(DS.mutedInk)
                PushToTalkInput(
                    text: Binding(
                        get: { feature.state.benefitFeedbackNote },
                        set: { feature.updateBenefitFeedbackNote($0) }
                    ),
                    placeholder: "具体看清或改变了什么（可选）",
                    accessibilityIdentifier: "mentor.benefit.note",
                    usesTextEditor: true
                )
                .frame(minHeight: 84, alignment: .top)
                .padding(8)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                        .stroke(DS.hairline, lineWidth: 1)
                }
                VStack(spacing: 8) {
                    ForEach(MentorBenefitFeedbackKind.allCases, id: \.self) { kind in
                        Button {
                            feature.recordBenefitFeedback(kind)
                        } label: {
                            HStack {
                                Text(kind.title)
                                Spacer(minLength: 8)
                                if feature.state.benefitFeedback?.kind == kind {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .tint(feature.state.benefitFeedback?.kind == kind ? DS.accent : DS.accentInk)
                        .disabled(feature.state.isSavingBenefitFeedback || feature.state.isTransitioningSession)
                        .accessibilityIdentifier("mentor.benefit.\(kind.rawValue)")
                    }
                }
                if feature.state.isSavingBenefitFeedback {
                    ProgressView("正在保存反馈…")
                        .accessibilityIdentifier("mentor.benefit.saving")
                }
                if feature.state.benefitFeedbackError != nil {
                    Text("反馈暂时没有保存成功。内容仍保留，可以再次尝试。")
                        .foregroundStyle(DS.caution)
                        .accessibilityIdentifier("mentor.benefit.error")
                }
            }
        }
        .padding(12)
        .background(DS.cardBackground, in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mentor.benefit.section")
    }

    @ViewBuilder private func lesson(_ lesson: MentorLesson, itemID: UUID) -> some View {
            VStack(alignment: .leading, spacing: 16) {
                    Text(lesson.title).font(.title2.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    .modifier(MentorReadingSectionMarker(itemID: itemID, section: .title, geometry: readingGeometry))
                Text(lesson.claim)
                    .modifier(MentorReadingSectionMarker(itemID: itemID, section: .claim, geometry: readingGeometry))
                Text(lesson.example)
                    .modifier(MentorReadingSectionMarker(itemID: itemID, section: .example, geometry: readingGeometry))
                VStack(alignment: .leading, spacing: 8) {
                    Text("适用边界").font(.headline).accessibilityAddTraits(.isHeader)
                    Text(lesson.boundary)
                }.modifier(MentorReadingSectionMarker(itemID: itemID, section: .boundary, geometry: readingGeometry))
                if let observation = lesson.observation {
                    Text(observation).modifier(MentorReadingSectionMarker(itemID: itemID, section: .observation, geometry: readingGeometry))
                }
                Text(lesson.sourceType == .teachingExample ? "教学示例" : "外部参考")
                    .font(.subheadline).foregroundStyle(DS.mutedInk)
                if lesson.review.reviewedBy?.contains("AI editor") == true {
                    Text("AI 编写与编辑审核，供个人探索。")
                        .font(.caption).foregroundStyle(DS.mutedInk)
                        .accessibilityIdentifier("mentor.lesson.editorial-identity")
                }
                if let reference = try? MentorSourceReference("lesson:\(lesson.id)@\(lesson.version)") {
                    sourceButton([reference])
                }
                ForEach(lesson.citations, id: \.url) { citation in
                    if let url = URL(string: citation.url), ["https", "http"].contains(url.scheme) {
                        Link(citation.title, destination: url)
                    }
                }
            }
            .textSelection(.enabled)
            .background(MentorReadingMarker(geometry: readingGeometry, itemID: itemID))
            if feature.state.lesson?.id == itemID && !feature.state.isViewingHistory {
                lessonActions
            }
        }

    private func sourceButton(_ references: [MentorSourceReference]) -> some View {
        Button {
            sourceSelection = MentorSourceSelection(references: references)
        } label: {
            Label("查看来源（\(references.count)）", systemImage: "doc.text.magnifyingglass")
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("mentor.sources.open")
    }

    private var lessonActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("换一个新视角") {
                flushReadingPosition()
                feature.selectAnotherLesson()
            }
                .buttonStyle(.bordered).controlSize(.large)
                .frame(minHeight: 44)
                .accessibilityIdentifier("mentor.lesson.another")
            Button("不相关") { feature.recordLessonFeedback(.notRelevant) }
                .frame(minHeight: 44)
                .accessibilityHint("只在这次交流中排除这个主题。")
                .accessibilityIdentifier("mentor.lesson.not-relevant")
            Button("已知道") { feature.recordLessonFeedback(.alreadyKnown) }
                .frame(minHeight: 44)
                .accessibilityHint("以后不再自动推荐这篇内容，已读记录会保留。")
                .accessibilityIdentifier("mentor.lesson.known")
            if feature.state.isSavingLessonFeedback { ProgressView("正在保存反馈…") }
            if let notice = feature.state.lessonFeedbackNotice {
                Text(notice).font(.subheadline).foregroundStyle(DS.mutedInk)
                    .accessibilityIdentifier("mentor.lesson.feedback-saved")
            }
            if feature.state.lessonFeedbackError != nil {
                Text("反馈暂时没有保存成功。内容仍在，可以再次选择反馈重试。")
                    .foregroundStyle(DS.caution)
            }
            if feature.state.lessonError != nil {
                Text("暂时没能换到新内容，可以稍后重试。")
                    .foregroundStyle(DS.caution)
            }
        }
        .disabled(feature.state.isTransitioningSession || feature.state.isSavingLessonFeedback ||
                  ![.reading, .showingResponse].contains(feature.state.phase))
    }

    private func decodeLesson(_ json: String) -> MentorLesson? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(MentorLesson.self, from: Data(json.utf8))
    }

    private var isInterruptedPreview: Bool {
        if case .failed = feature.state.phase { return true }
        return feature.state.understandingGenerationError != nil
    }

    @ViewBuilder private var status: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--mentor-material-selection-fixture"),
           feature.state.materialSelection == nil,
           feature.state.phase == .editing {
            Button("显示长材料选择") {
                feature.debugPresentMaterialSelectionForUITest()
            }
            .accessibilityIdentifier("mentor.material-selection.debug-open")
        }
        #endif
        if let selection = feature.state.materialSelection {
            materialSelectionSection(selection)
        }
        if !feature.state.streamingPreview.isEmpty,
           feature.state.phase == .submitting || feature.state.isGeneratingUnderstanding || isInterruptedPreview {
            VStack(alignment: .leading, spacing: 10) {
                Text(isInterruptedPreview ? "未完成的回应" : "正在生成 · 内容尚未确认")
                    .font(.caption.weight(.semibold)).foregroundStyle(DS.mutedInk)
                Text(feature.state.streamingPreview)
                    .font(.body).fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("mentor.request.stream-preview")
                if isInterruptedPreview {
                    Text("连接已停止。这段预览尚未保存为完整回应，可先复制保留；重试会重新生成。")
                        .font(.subheadline).foregroundStyle(DS.caution)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.cornerRadius))
        }
        if feature.state.phase == .submitting {
            ProgressView(!feature.state.streamingPreview.isEmpty ? "正在接收回应…" : feature.state.requestWaitingNotice ? "仍在等待回应…" : "正在回应…")
            if feature.state.requestWaitingNotice {
                Text("仍在等待新内容。持续生成时会继续接收，你也可以返回，当前输入会保留。")
                    .font(.subheadline)
                    .foregroundStyle(DS.mutedInk)
                    .accessibilityIdentifier("mentor.request.waiting")
            }
        }
        if feature.state.isGeneratingUnderstanding { ProgressView("正在整理你的理解…") }
        if let error = feature.state.understandingGenerationError {
            Text(error).foregroundStyle(DS.caution)
            Button("重试整理理解") { online { feature.generateUnderstanding() } }
                .buttonStyle(.bordered).controlSize(.large)
        }
        if feature.state.phase == .selectingLesson { ProgressView("正在准备下一个视角…") }
        if feature.state.readingPositionError != nil {
            Text("阅读位置暂时没能保存，内容仍可继续阅读。")
                .foregroundStyle(DS.caution)
            Button("重试保存阅读位置") { feature.retryReadingPositionSave() }
                .buttonStyle(.bordered).controlSize(.large)
                .disabled(feature.state.pendingReadingPositionSaves > 0 || feature.state.isViewingHistory)
        }
        if feature.state.deletionError != nil {
            Text("暂时没能删除，交流仍保留在这里。请稍后重试。")
                .foregroundStyle(DS.caution)
        }
        if case .failed = feature.state.phase {
            Text(feature.state.requestFailureMessage ?? "这一步没有完成。已保存的内容仍在，可以重试或稍后继续。")
                .foregroundStyle(DS.caution)
                .accessibilityIdentifier("mentor.request.failure")
        }
        if feature.state.phase == .lessonExhausted {
            Text("暂时没有新的内容，可以回看这次交流，或自己写一句理解。")
        }
        if feature.state.draftSaveError != nil {
            Text("输入尚未保存，请重试后再离开。").foregroundStyle(DS.caution)
            Button("重试保存输入") { Task { _ = await feature.flushPendingEdits() } }
                .buttonStyle(.bordered).controlSize(.large)
            Button("放弃未保存改动并返回") {
                showsDiscardUnsavedDraftConfirmation = true
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier("mentor.draft.discard-and-return")
        }
        if let error = feature.state.retryError { Text(error).foregroundStyle(DS.caution) }
        if feature.state.presentationError != nil {
            Text("阅读状态尚未保存，请重试。").foregroundStyle(DS.caution)
            Button("重试保存阅读状态") {
                if let id = feature.state.responseItemID { feature.acknowledgeResponse(itemID: id) }
                else { feature.acknowledgeLesson() }
            }.buttonStyle(.bordered).controlSize(.large)
        }
        if feature.state.actionError != nil { Text(feature.state.actionError ?? "").foregroundStyle(DS.caution) }
        if feature.state.canRetryResponseSave {
            Button("重试保存回应") { feature.retryResponseSave() }.buttonStyle(.bordered).controlSize(.large)
        } else if feature.state.canRetryRequestFinalization {
            Button("重试保存状态") { feature.retryRequestFinalization() }.buttonStyle(.bordered).controlSize(.large)
        } else if !feature.state.isViewingHistory, feature.state.retryableRequest != nil {
            Button("重新请求回应") { online { feature.retryLastRequest() } }.buttonStyle(.bordered).controlSize(.large)
        }
        if needsConfiguration {
            Text("在线交流需要先配置模型，输入会保留在这里。")
            Button("打开模型设置") { showsSettings = true }.buttonStyle(.bordered).controlSize(.large)
        }
        if app.isAIRunning { Text("今日整理正在处理，完成后再开始在线交流。") }
    }

    @ViewBuilder
    private func materialSelectionSection(_ selection: MentorMaterialSelectionState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("本轮材料较长", systemImage: "text.badge.ellipsis")
                .font(.headline)
            Text("全文保留在这次交流中；本轮只发送你选中的片段。可选原话，也可选老师回应来说明你指的是哪段话。")
                .font(.subheadline)
                .foregroundStyle(DS.mutedInk)
            if selection.currentUserSourceID != nil {
                Text("请至少选一段“本轮输入”；老师的回应仅作为上下文。")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("当前约 \(selection.characterCount) 字符，上限 \(selection.limit) 字符")
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
            if selection.candidates.isEmpty {
                Text("没有可供选择的片段，请取消后改写本轮输入。")
                    .foregroundStyle(DS.caution)
            } else {
                ForEach(selection.candidates) { candidate in
                    MentorMaterialFragmentRow(candidate: candidate,
                        selected: selection.selectedIDs.contains(candidate.id)) {
                        feature.toggleMaterialFragment(candidate.id)
                    }
                    Divider()
                }
            }
            if let error = selection.error {
                Text(error)
                    .foregroundStyle(DS.caution)
                    .accessibilityIdentifier("mentor.material-selection.error")
            }
            let actions = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
            actions {
                Button { feature.cancelMaterialSelection() } label: {
                    Text("取消本轮").frame(maxWidth: .infinity, minHeight: DS.minimumTapTarget)
                }
                    .buttonStyle(.bordered)
                Button { feature.submitMaterialSelection() } label: {
                    Text("发送选中的片段").frame(maxWidth: .infinity, minHeight: DS.minimumTapTarget)
                }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.accent)
                    .foregroundStyle(DS.onAccent)
                    .disabled(selection.selectedIDs.isEmpty)
                    .accessibilityIdentifier("mentor.material-selection.submit")
            }
            .padding(.top, 4)
        }
        .padding(DS.cardInnerPadding)
        .background(DS.cardBackground, in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                .stroke(DS.caution.opacity(0.45), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mentor.material-selection")
    }

    private var input: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("你想说的话").font(.headline).accessibilityAddTraits(.isHeader)
            Text("支持继续交流：每一轮只推进一个角度，你也可以随时点“到这里”。")
                .font(.footnote)
                .foregroundStyle(DS.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("mentor.conversation.multiturn-hint")
            ForEach(feature.state.response?.availableSuggestedActions.filter {
                $0 == .explain || $0 == .anotherLesson || $0 == .draftUnderstanding
            } ?? [], id: \.self) { action in
                Button {
                    switch action {
                    case .explain: online { feature.submit(intent: action.rawValue) }
                    case .anotherLesson:
                        flushReadingPosition()
                        feature.submit(intent: action.rawValue)
                    case .draftUnderstanding: online { feature.generateUnderstanding() }
                    default: break
                    }
                } label: {
                    Label(
                        action == .explain ? "直接讲讲这个视角" : (action == .anotherLesson ? "换一个视角" : "整理我的理解"),
                        systemImage: action == .draftUnderstanding ? "text.badge.checkmark" : (action == .anotherLesson ? "arrow.triangle.2.circlepath" : "text.bubble")
                    )
                }
                .buttonStyle(.bordered).controlSize(.large)
                .disabled(feature.state.materialSelection != nil || (action == .draftUnderstanding && feature.state.isGeneratingUnderstanding))
            }
            if feature.canContinueRecall {
                Button {
                    Task { @MainActor in
                        if await feature.continueRecall() { inputFocused = true }
                    }
                } label: {
                    Label("继续回忆", systemImage: "arrow.counterclockwise")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("mentor.recall.continue")
                .accessibilityHint("保留已有交流，继续输入另一段回忆")
            }
        }
    }

    private var showsComposer: Bool {
        !feature.state.isTransitioningSession && !feature.state.isViewingHistory &&
        feature.state.session != nil && feature.state.phase != .paused && feature.state.phase != .ended &&
        feature.state.legacyChain?.canContinueAutomatically != false
    }

    private func conversationComposer(viewportHeight: CGFloat) -> some View {
        VStack(spacing: 8) {
            // Recognition review can expand; only this input area scrolls,
            // while the submit action remains reachable above the keyboard.
            ScrollView {
                PushToTalkInput(
                    text: Binding(get: { feature.state.inputText }, set: { feature.updateInputText($0) }),
                    placeholder: "你想说的话",
                    focusBinding: Binding(get: { inputFocused }, set: { inputFocused = $0 }),
                    usesTextEditor: true,
                    textEditorHeight: dynamicTypeSize.isAccessibilitySize ? 140 : 88
                )
                .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.cornerRadius))
                .background {
                    GeometryReader { content in
                        Color.clear.preference(key: ComposerHeight.self, value: content.size.height)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.immediately)
            .frame(height: min(composerContentHeight, max(180, viewportHeight * 0.55)))
            .onPreferenceChange(ComposerHeight.self) { height in
                guard height.isFinite, height > 0, abs(height - composerContentHeight) > 0.5 else { return }
                composerContentHeight = height
            }
            .accessibilityIdentifier("mentor.conversation.composer-scroll")
            Button {
                inputFocused = false
                online { feature.submit() }
            } label: {
                Text(canDiscussCapture ? "聊聊这条闪念" : "发送")
                    .foregroundStyle(DS.onAccent).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(![.editing, .reading, .showingResponse].contains(feature.state.phase) || app.isAIRunning ||
                      feature.state.materialSelection != nil ||
                      (feature.state.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !canDiscussCapture) ||
                      (feature.state.phase == .showingResponse && feature.state.acknowledgedResponseItemID != feature.state.responseItemID))
        }
        .frame(maxWidth: 640)
        .padding(.horizontal, DS.pagePadding)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(DS.background)
        .overlay(alignment: .top) { Divider() }
    }

    private var canDiscussCapture: Bool {
        feature.state.session?.initialEntry == "capture" &&
        feature.state.phase == .editing && feature.state.response == nil &&
        feature.state.retryableRequest == nil && !feature.state.borrowedCaptureSources.isEmpty &&
        feature.state.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func online(_ action: () -> Void) {
        guard app.apiKeyConfigured else { needsConfiguration = true; return }
        guard !app.isAIRunning else { return }
        needsConfiguration = false
        action()
    }

    private func flushReadingPosition() {
        readingGeometry.flush()
        readingGeometry.suspend()
        readingPosition.flush()
    }

    private func leave(ending: Bool) {
        inputFocused = false
        flushReadingPosition()
        if feature.state.isViewingHistory {
            feature.pause()
            dismiss()
            return
        }
        if feature.state.session == nil || feature.state.phase == .ended { dismiss(); return }
        wantsClose = true
        pendingExitEnding = ending
        if ending { feature.finish() } else { feature.pause() }
    }
}

struct MentorCorrectionSelection: Identifiable {
    let id: UUID
    let text: String
}

struct MentorCorrectionEditor: View {
    @ObservedObject var feature: MentorFeatureStore
    let selection: MentorCorrectionSelection
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var isSaving = false
    @State private var failed = false

    init(feature: MentorFeatureStore, selection: MentorCorrectionSelection) {
        self.feature = feature
        self.selection = selection
        _text = State(initialValue: selection.text)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("原文会保留。保存更正后，基于旧原话的请求会停止；继续交流时会使用更正后的版本。")
                        .foregroundStyle(DS.mutedInk)
                    Text("更正后的原话").font(.headline).accessibilityAddTraits(.isHeader)
                    PushToTalkInput(text: $text, placeholder: "更正后的原话",
                        accessibilityIdentifier: "mentor.correction.input", usesTextEditor: true, autofocus: true)
                        .disabled(isSaving)
                    if failed {
                        Text(feature.state.correctionError ?? "更正尚未保存，文字仍在这里。请重试。")
                            .foregroundStyle(DS.caution)
                            .accessibilityIdentifier("mentor.correction.error")
                    }
                    Button {
                        isSaving = true
                        failed = false
                        Task { @MainActor in
                            let saved = await feature.correctUserItem(selection.id, text: text)
                            isSaving = false
                            if saved { dismiss() } else { failed = true }
                        }
                    } label: {
                        Text(isSaving ? "正在保存更正…" : "保存更正")
                            .foregroundStyle(DS.onAccent)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("mentor.correction.save")
                }
                .frame(maxWidth: 640, alignment: .leading)
                .padding(DS.pagePadding)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(DS.background)
            .foregroundStyle(DS.ink)
            .navigationTitle("更正原话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.frame(minWidth: 44, minHeight: 44)
                        .disabled(isSaving)
                }
            }
        }
        .tint(DS.accent)
        .interactiveDismissDisabled(isSaving)
    }
}

struct MentorSourceSelection: Identifiable {
    let id = UUID()
    let references: [MentorSourceReference]
}

struct MentorSourceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var feature: MentorFeatureStore
    let references: [MentorSourceReference]
    @State private var details: [MentorSourceDetail] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if isLoading {
                        ProgressView("正在读取来源…")
                    } else if details.isEmpty {
                        Text("这段内容没有可查看的来源。")
                            .foregroundStyle(DS.mutedInk)
                    } else {
                        ForEach(details) { detail in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(detail.title).font(.headline)
                                    Spacer()
                                    Text(detail.status.label).font(.subheadline).foregroundStyle(DS.mutedInk)
                                }
                                if let content = detail.content {
                                    Text(content).textSelection(.enabled)
                                }
                                if case .unavailable(let reason) = detail.status {
                                    Text(reason).foregroundStyle(DS.caution)
                                        .accessibilityIdentifier("mentor.sources.unavailable")
                                }
                                if case .deleted = detail.status {
                                    Text("这条来源已被删除，当前会话仍保留对它的引用记录。")
                                        .foregroundStyle(DS.caution)
                                }
                                ForEach(detail.externalLinks) { link in
                                    Link(link.title, destination: link.url)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: 640, alignment: .leading)
                .padding(DS.pagePadding)
                .frame(maxWidth: .infinity)
            }
            .background(DS.background)
            .foregroundStyle(DS.ink)
            .navigationTitle("来源详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DS.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("返回") { dismiss() }.frame(minWidth: 44, minHeight: 44)
                }
            }
        }
        .tint(DS.accent)
        .task {
            details = await feature.sourceDetails(for: references)
            isLoading = false
        }
    }
}

#if DEBUG
/// Isolated UI automation fixture; never uses the user's conversation database or model.
struct MentorUITestHarness: View {
    @EnvironmentObject private var app: AppStore
    @State private var feature: MentorFeatureStore?
    @State private var error: String?
    @State private var isFixtureReady = false
    var body: some View {
        Group {
            if let feature, isFixtureReady || !ProcessInfo.processInfo.arguments.contains("--mentor-material-selection-fixture") {
                if ProcessInfo.processInfo.arguments.contains("--mentor-preferences-fixture") {
                    NavigationStack { MentorLessonPreferencesView(feature: feature).padding().navigationTitle("听讲偏好") }
                } else { MentorHomeView(feature: feature) }
            }
            else if let error { Text(error) }
            else { ProgressView("准备测试交流…") }
        }.task {
            guard feature == nil else { return }
            do {
                let database = try app.mentorUITestDatabase ?? AppDatabase(dbQueue: GRDB.DatabaseQueue())
                let repository = SQLiteMentorRepository(database: database)
                if ProcessInfo.processInfo.arguments.contains("--mentor-capture-fixture") {
                    _ = try await SQLiteCaptureFragmentRepository(database: database).save(CaptureFragment(
                        id: UUID(uuidString: "CCCCCCCC-CCCC-4CCC-8CCC-CCCCCCCCCCCC")!,
                        rawText: "UI 闪念：会议结束后，我还不确定谁负责验收。", dayKey: CaptureDayKey.value(for: .now)))
                    if ProcessInfo.processInfo.arguments.contains("--mentor-capture-failure") {
                        try await database.dbQueue.write {
                            try $0.execute(sql: "CREATE TRIGGER fail_ui_capture_link BEFORE INSERT ON mentor_source_links BEGIN SELECT RAISE(ABORT, 'UI capture failure'); END")
                        }
                    }
                }
                if ProcessInfo.processInfo.arguments.contains("--mentor-history-fixture") {
                    for index in 1...45 {
                        try await repository.createSession(MentorSession(id: UUID(), initialEntry: "discuss", lifecycle: .ended,
                            draftText: String(format: "History record %02d", index), draftRevision: 1,
                            activityAt: Date(timeIntervalSince1970: Double(100000 - index * 100))))
                    }
                }
                if ProcessInfo.processInfo.arguments.contains("--mentor-mixed-history-fixture") ||
                    ProcessInfo.processInfo.arguments.contains("--mentor-legacy-history-fixture") {
                    let legacyOnly = ProcessInfo.processInfo.arguments.contains("--mentor-legacy-history-fixture")
                    let legacyRepository = SQLiteSingleNudgeSessionRepository(database: database)
                    for index in 1...45 {
                        let date = Date(timeIntervalSince1970: Double(100000 - index * 100))
                        if legacyOnly || !index.isMultiple(of: 2) {
                            try await legacyRepository.save(SingleNudgeSession(dayKey: "2026-10-03",
                                input: String(format: "Legacy record %02d", index), question: "当时的问题",
                                diagnosis: "当时的 AI 分析", lifecycle: .completed, result: .completed,
                                createdAt: date, updatedAt: date))
                        } else {
                            try await repository.createSession(MentorSession(id: UUID(), initialEntry: "discuss",
                                lifecycle: .ended, draftText: String(format: "History record %02d", index),
                                draftRevision: 1, activityAt: date))
                        }
                    }
                }
                if ProcessInfo.processInfo.arguments.contains("--mentor-broken-legacy-fixture") {
                    let legacyRepository = SQLiteSingleNudgeSessionRepository(database: database)
                    let rootID = UUID()
                    try await legacyRepository.save(SingleNudgeSession(id: rootID, dayKey: "2026-09-17",
                        input: "损坏旧点拨原话", question: "先看哪个事实？", diagnosis: "需要补证据",
                        after: "从一条事实开始", rootSessionID: rootID, lifecycle: .completed,
                        result: .completed, createdAt: Date(timeIntervalSince1970: 1000),
                        updatedAt: Date(timeIntervalSince1970: 1000)))
                    try await legacyRepository.save(SingleNudgeSession(id: UUID(), dayKey: "2026-09-17",
                        input: "孤立旧轮次", question: "孤立问题", diagnosis: "无法确认",
                        parentSessionID: UUID(), rootSessionID: rootID, lifecycle: .completed,
                        result: .completed, createdAt: Date(timeIntervalSince1970: 1001),
                        updatedAt: Date(timeIntervalSince1970: 1001)))
                }
                if ProcessInfo.processInfo.arguments.contains("--mentor-source-fixture") {
                    let sessionID = UUID(), userID = UUID(), missingID = UUID()
                    try await repository.createSession(MentorSession(id: sessionID, initialEntry: "discuss", lifecycle: .ended,
                        draftText: "", draftRevision: 0, activityAt: .now))
                    let userPayload = String(decoding: try JSONEncoder().encode(["text": "UI 来源原话：先检查实际效果。"]), as: UTF8.self)
                    try await repository.appendItem(MentorTimelineItem(id: userID, sessionID: sessionID, sequence: 1,
                        kind: .user, payloadJSON: userPayload))
                    let response: [String: Any] = [
                        "schema_version": "1.0.0", "action": "explain", "material_status": "usable",
                        "body": "这段回应明确引用了保存的原话。", "question": NSNull(), "question_purpose": NSNull(),
                        "source_refs": ["item:\(userID.uuidString)", "item:\(missingID.uuidString)"],
                        "lesson_ref": NSNull(), "suggested_actions": []
                    ]
                    let responsePayload = String(decoding: try JSONSerialization.data(withJSONObject: response), as: UTF8.self)
                    try await repository.appendItem(MentorTimelineItem(id: UUID(), sessionID: sessionID, sequence: 2,
                        kind: .assistant, payloadJSON: responsePayload))
                }
                if ProcessInfo.processInfo.arguments.contains("--mentor-correction-fixture") {
                    let sessionID = UUID()
                    try await repository.createSession(MentorSession(id: sessionID, initialEntry: "discuss", lifecycle: .active,
                        draftText: "尚未发送的下一句", draftRevision: 1, activityAt: .now))
                    let payload = try JSONEncoder().encode(["text": "UI 原话：所有人都失败了。"])
                    try await repository.appendItem(MentorTimelineItem(id: UUID(), sessionID: sessionID, sequence: 1,
                        kind: .user, payloadJSON: String(decoding: payload, as: UTF8.self)))
                    if ProcessInfo.processInfo.arguments.contains("--mentor-correction-failure") {
                        try await database.dbQueue.write {
                            try $0.execute(sql: "CREATE TRIGGER fail_ui_correction BEFORE INSERT ON mentor_corrections BEGIN SELECT RAISE(ABORT, 'UI correction failure'); END")
                        }
                    }
                }
                if ProcessInfo.processInfo.arguments.contains("--mentor-recall-exhausted-fixture") {
                    let sessionID = UUID(), userID = UUID()
                    try await repository.createSession(MentorSession(id: sessionID, initialEntry: "review", lifecycle: .active,
                        draftText: "保留尚未发送的片段", draftRevision: 1, activityAt: .now))
                    try await repository.appendItem(MentorTimelineItem(id: userID, sessionID: sessionID, sequence: 1,
                        kind: .user, payloadJSON: String(decoding: try JSONEncoder().encode(["text": "我想回看今天的接口改动。"]), as: UTF8.self)))
                    for question in ["你具体改动了哪一步？", "这一步前后有什么变化？"] {
                        let requestID = try await repository.submitTurn(MentorSubmitTurn(commandID: UUID(),
                            sessionID: sessionID, text: nil, intent: "reply", contextSnapshotJSON: "{}"))
                        let response = MentorTurnResponse(schemaVersion: "1.0.0", action: .clarify, materialStatus: .missing,
                            body: "先区分完成了改动和改动是否有效。", question: question, questionPurpose: .material,
                            sourceRefs: [try MentorSourceReference("item:\(userID.uuidString)")], lessonRef: nil, suggestedActions: [.finish])
                        let item = try await repository.commitResponse(sessionID: sessionID, requestID: requestID,
                            payloadJSON: String(decoding: try JSONEncoder().encode(response), as: UTF8.self))
                        try await repository.acknowledgePresentation(sessionID: sessionID, itemID: item.id, at: .now, timeZone: .current)
                    }
                }
                if ProcessInfo.processInfo.arguments.contains("--mentor-material-selection-fixture") {
                    try await database.dbQueue.write { db in
                        try db.execute(sql: "DELETE FROM mentor_sessions")
                    }
                    let sessionID = UUID()
                    let oversizedText = String(repeating: "UI 长材料事实。", count: 12_000)
                    try await repository.createSession(MentorSession(id: sessionID, initialEntry: "discuss", lifecycle: .active,
                        draftText: "", draftRevision: 0, activityAt: .now))
                    let payload = try JSONEncoder().encode(["text": oversizedText])
                    try await repository.appendItem(MentorTimelineItem(id: UUID(), sessionID: sessionID, sequence: 1,
                        kind: .user, payloadJSON: String(decoding: payload, as: UTF8.self)))
                }
                var catalog: MentorLessonCatalog?
                if ProcessInfo.processInfo.arguments.contains("--mentor-lesson-fixture") {
                    let lessons = (1...24).map { index in
                        let base = MentorLesson(id: String(format: "L%02d", index), version: "1.0", editorialOrder: index,
                            title: "测试视角 \(index)", theme: MentorLesson.Theme.allCases[(index - 1) / 4],
                            applicableContexts: ["UI fixture"],
                            claim: ProcessInfo.processInfo.arguments.contains("--mentor-long-lesson") ? String(repeating: "这段测试观点用来验证长内容阅读位置。\n", count: 8) : "这是隔离的界面测试内容。",
                            example: ProcessInfo.processInfo.arguments.contains("--mentor-long-lesson") ? String(repeating: "这个测试例子只用于检查分节滚动恢复。\n", count: 8) : "用于检查阅读和反馈按钮。",
                            boundary: ProcessInfo.processInfo.arguments.contains("--mentor-long-lesson") ? String(repeating: "这段适用边界不作为正式教材发布。\n", count: 8) : "不作为正式教材发布。", observation: nil, sourceType: .teachingExample, citations: [],
                            contentHash: "", review: .init(status: .approved, reviewedBy: "UI fixture", reviewedAt: .now, note: nil))
                        return MentorLesson(id: base.id, version: base.version, editorialOrder: base.editorialOrder,
                            title: base.title, theme: base.theme, applicableContexts: base.applicableContexts,
                            claim: base.claim, example: base.example, boundary: base.boundary, observation: nil,
                            sourceType: base.sourceType, citations: [], contentHash: MentorLessonCatalog.contentHash(for: base), review: base.review)
                    }
                    catalog = try MentorLessonCatalog(pack: MentorLessonPack(schemaVersion: "1.0.0", packID: "ui-fixture", version: "1.0", lessons: lessons))
                }
                if ProcessInfo.processInfo.arguments.contains("--mentor-reading-history-fixture"), let catalog {
                    let sessionID = UUID(), itemID = UUID()
                    try await repository.createSession(MentorSession(id: sessionID, initialEntry: "listen", lifecycle: .active,
                        draftText: "", draftRevision: 0, activityAt: .now))
                    for index in 1...40 {
                        let payload = try JSONEncoder().encode(["text": "较早交流 \(index)\n" + String(repeating: "保留长时间线中的原话。\n", count: 4)])
                        try await repository.appendItem(MentorTimelineItem(id: UUID(), sessionID: sessionID, sequence: index,
                            kind: .user, payloadJSON: String(decoding: payload, as: UTF8.self)))
                    }
                    _ = try await repository.selectNextLesson(sessionID: sessionID, itemID: itemID, expectedEpoch: 0,
                        catalog: catalog, at: .now, timeZone: .current)
                    try await repository.acknowledgePresentation(sessionID: sessionID, itemID: itemID, at: .now, timeZone: .current)
                    // Simulates a snapshot saved before this device's layout;
                    // opening it must find the distant lesson and its section.
                    try await repository.saveReadingPosition(sessionID: sessionID, itemID: itemID, revision: 1,
                        section: .boundary, offset: 80, layoutKey: "previous-device-layout")
                    // Leave enough later content to distinguish true section
                    // restoration from clamping at the end of a short page.
                    for index in 42...46 {
                        let payload = try JSONEncoder().encode(["text": "教材后的交流 \(index)\n" + String(repeating: "这一段保留教材之后的原话。\n", count: 4)])
                        try await repository.appendItem(MentorTimelineItem(id: UUID(), sessionID: sessionID, sequence: index,
                            kind: .user, payloadJSON: String(decoding: payload, as: UTF8.self)))
                    }
                    try await repository.suspendSession(id: sessionID, ending: true, draftRevision: 0, draftText: "")
                }
                let balanceFailure = ProcessInfo.processInfo.arguments.contains("--mentor-service-balance-fixture")
                feature = MentorFeatureStore(repository: repository, transport: MentorUIOfflineTransport(balanceFailure: balanceFailure),
                    legacyNudgeAdapter: LegacyNudgeAdapter(database: database), catalog: catalog)
                feature?.loadRecentSessions()
                if ProcessInfo.processInfo.arguments.contains("--mentor-material-selection-fixture") {
                    try await Task.sleep(for: .milliseconds(300))
                }
                isFixtureReady = true
                app.apiKeyConfigured = balanceFailure || ProcessInfo.processInfo.arguments.contains("--mentor-stream-ui-fixture") ||
                    ProcessInfo.processInfo.arguments.contains("--mentor-response-scroll-fixture")
            } catch { self.error = String(describing: error) }
        }
    }
}
private struct MentorUIOfflineTransport: MentorTransport {
    var balanceFailure = false
    func complete(_ request: LLMRequest) async throws -> Data {
        let replaySavedResponse = ProcessInfo.processInfo.arguments.contains("--mentor-response-scroll-fixture")
        if ProcessInfo.processInfo.arguments.contains("--mentor-stream-ui-fixture") || replaySavedResponse {
            let context = try JSONDecoder().decode(MentorContextPayload.self, from: Data(request.inputSummary.utf8))
            // Exact synthetic N01 response, replayed without accessing credentials or the network.
            let body = replaySavedResponse ? """
                这两个选择的关键取舍是：让已有知识更容易使用，还是增加一种新的做事手段。你目前没有紧急交付，因此不必按交付压力排序。

                整理笔记适合已有内容值得复用、但查找或理解起来不方便的情况。两小时可以集中整理一个主题，让它更便于调用；代价是暂缓接触新工具。

                学习新工具适合已有一个想用它解决的具体问题，或希望探索新做法的情况。两小时更适合体验一项核心功能，而不是追求熟练；代价是暂缓整理已有知识，而且工具是否值得继续学，可能仍不确定。
                """ : "完成一次尝试，和确认它有效，是两件事。可以先看实际结果改变了什么，再保留暂时无法判断的部分。"
            let object: [String: Any] = ["schema_version": "1.0.0", "action": "explain", "material_status": "usable",
                "body": body, "question": NSNull(), "question_purpose": NSNull(),
                "source_refs": context.latestUserSourceRef.map { [$0.value] } ?? [],
                "lesson_ref": NSNull(), "suggested_actions": ["finish"]]
            let payload = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            if replaySavedResponse { return payload }
            let raw = String(decoding: payload, as: UTF8.self)
            for character in raw {
                try Task.checkCancellation()
                try request.mentorStreamProgress?.receive(String(character))
                try await Task.sleep(for: .milliseconds(35))
            }
            if ProcessInfo.processInfo.arguments.contains("--mentor-stream-ui-failure") {
                throw LLMClientError.incompleteResponse
            }
            try await Task.sleep(for: .seconds(2))
            return payload
        }
        if balanceFailure {
            throw LLMClientError.httpStatus(429,
                Data(#"{"error":{"code":"1113","message":"synthetic provider diagnostic"}}"#.utf8))
        }
        throw LLMClientError.missingAPIKey
    }
}
#endif

private struct MentorMaterialFragmentRow: View {
    let candidate: MentorMaterialFragment
    let selected: Bool
    let toggle: () -> Void
    @State private var showsFullText = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: toggle) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? DS.accent : DS.mutedInk)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(candidate.label).font(.subheadline.weight(.semibold))
                        if !showsFullText {
                            Text(candidate.text.count > 180 ? String(candidate.text.prefix(180)) + "…" : candidate.text)
                                .font(.body)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(selected ? "已选择" : "未选择")
            .accessibilityIdentifier("mentor.material-selection.fragment.\(candidate.id.uuidString)")
            if candidate.text.count > 180 {
                DisclosureGroup(isExpanded: $showsFullText) {
                    Text(candidate.text)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("mentor.material-selection.full-text.\(candidate.id.uuidString)")
                        .padding(.vertical, 8)
                } label: {
                    Text(showsFullText ? "收起全文" : "查看本片段全文（\(candidate.text.count) 字）")
                        .font(.subheadline)
                        .frame(minHeight: 44, alignment: .leading)
                }
                .tint(DS.accent)
            }
        }
        .padding(.vertical, 8)
    }
}

/// Keep very long saved originals from dominating the current turn's scroll area.
/// Disclosure is explicit; persistence and the transmitted evidence are unaffected.
private struct MentorOriginalText: View {
    let text: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsFullText = false

    var body: some View {
        if text.count <= 900 {
            Text(text).textSelection(.enabled)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(text.prefix(180)) + "…")
                    .fixedSize(horizontal: false, vertical: true)
                Button { showsFullText = true } label: {
                    Text("查看原话全文（\(text.count) 字）")
                        .frame(minHeight: DS.minimumTapTarget, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }
            .sheet(isPresented: $showsFullText) {
                NavigationStack {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            // Bound each text layout while retaining every character.
                            let characters = Array(text)
                            ForEach(Array(stride(from: 0, to: characters.count, by: 900)), id: \.self) { start in
                                Text(String(characters[start..<min(start + 900, characters.count)]))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(DS.pagePadding)
                    }
                    .background(DS.background)
                    .foregroundStyle(DS.ink)
                    .navigationTitle("原话全文")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { showsFullText = false }
                    } }
                }
                .dynamicTypeSize(dynamicTypeSize)
            }
        }
    }
}
