import SwiftUI
import GRDB

struct MentorHomeView: View {
    @EnvironmentObject private var app: AppStore
    @ObservedObject var feature: MentorFeatureStore
    @State private var showsConversation = false
    @State private var showsToday = false
    @State private var showsHistory = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("忙了一天，也可以从一句话开始。")
                        .font(.title2.weight(.semibold))
                    Text("不用先想清楚。回看一个片段，或者听一个新视角。")
                        .foregroundStyle(DS.mutedInk)
                    VStack(alignment: .leading, spacing: 12) {
                        if let recent = feature.state.latestUnfinishedSession {
                            entry("继续这次交流", symbol: "arrow.turn.down.right", primary: true) {
                                feature.continueSession(id: recent.id)
                                showsConversation = true
                            }
                        } else {
                            entry("带我回看", symbol: "arrow.counterclockwise", primary: true) { start("review") }
                        }
                        entry("听一个新视角", symbol: "book") { start("listen") }
                        entry("我有一件事", symbol: "square.and.pencil") { start("discuss") }
                    }
                    .disabled(feature.state.isTransitioningSession || feature.state.isLoadingHistory)
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
        }
        .sheet(isPresented: $showsHistory, onDismiss: { feature.loadRecentSessions() }) {
            MentorHistoryView(feature: feature).environmentObject(app)
        }
        .sheet(isPresented: $showsToday) {
            TodayView().environmentObject(app).accessibilityIdentifier("mentor.legacy-today")
        }
    }

    @ViewBuilder
    private func entry(_ title: String, symbol: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        let button = Button(action: action) {
            Label(title, systemImage: symbol)
                .foregroundStyle(primary ? DS.background : DS.accentInk)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }.controlSize(.large)
        if primary { button.buttonStyle(.borderedProminent) }
        else { button.buttonStyle(.bordered) }
    }

    private func start(_ entry: String) {
        feature.start(entry: entry)
        showsConversation = true
    }
}

struct MentorConversationView: View {
    @EnvironmentObject private var app: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var feature: MentorFeatureStore
    @FocusState private var inputFocused: Bool
    @State private var wantsClose = false
    @State private var showsSettings = false
    @State private var needsConfiguration = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var inputHeight = 120.0
    @StateObject private var readingPosition = MentorReadingPositionCoordinator()
    @StateObject private var readingGeometry = MentorReadingGeometry()
    @State private var showsDeleteConfirmation = false
    @State private var sourceSelection: MentorSourceSelection?

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
                    .scrollDismissesKeyboard(.interactively)
                    .task(id: "\(feature.state.lesson?.id.uuidString ?? "")/\(feature.state.isTransitioningSession)") {
                        guard !feature.state.isTransitioningSession, let lesson = feature.state.lesson else { return }
                        await Task.yield()
                        guard !Task.isCancelled else { return }
                        readingPosition.revealIfNeeded(itemID: lesson.id) {
                            scroll.scrollTo(lesson.id, anchor: .top)
                        }
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
                        .disabled(feature.state.isTransitioningSession)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if feature.state.isViewingHistory {
                        Menu {
                            Button("删除这次交流", role: .destructive) { showsDeleteConfirmation = true }
                        } label: {
                            Label("交流操作", systemImage: "ellipsis.circle")
                        }
                        .disabled(feature.state.isTransitioningSession)
                    } else {
                        Button("到这里") { leave(ending: true) }
                            .disabled(feature.state.isTransitioningSession)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("收起键盘") { inputFocused = false }
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
        .sheet(isPresented: $showsSettings) { SettingsView().environmentObject(app) }
        .sheet(item: $sourceSelection) { selection in
            MentorSourceDetailView(feature: feature, references: selection.references)
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
            if !feature.state.inputText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("保留的输入").font(.headline)
                    Text(feature.state.inputText).textSelection(.enabled)
                }
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
                            Text("你说").font(.subheadline).foregroundStyle(DS.mutedInk)
                            Text(text).textSelection(.enabled)
                        }
                    } else if item.kind == .lesson, let saved = decodeLesson(item.payloadJSON) {
                        lesson(saved, itemID: item.id)
                    } else if item.kind == .assistant,
                              let response = try? JSONDecoder().decode(MentorTurnResponse.self, from: Data(item.payloadJSON.utf8)) {
                        VStack(alignment: .leading, spacing: 12) {
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
        status
        if feature.state.isViewingHistory || feature.state.phase == .paused || feature.state.phase == .ended {
            Button("继续这件事") {
                if let id = feature.state.session?.id { feature.continueSession(id: id) }
            }.buttonStyle(.bordered).controlSize(.large)
        } else if feature.state.session != nil {
            input
        }
    }

    @ViewBuilder private func lesson(_ lesson: MentorLesson, itemID: UUID) -> some View {
            VStack(alignment: .leading, spacing: 16) {
                Text(lesson.title).font(.title2.weight(.semibold))
                    .modifier(MentorReadingSectionMarker(itemID: itemID, section: .title, geometry: readingGeometry))
                Text(lesson.claim)
                    .modifier(MentorReadingSectionMarker(itemID: itemID, section: .claim, geometry: readingGeometry))
                Text(lesson.example)
                    .modifier(MentorReadingSectionMarker(itemID: itemID, section: .example, geometry: readingGeometry))
                VStack(alignment: .leading, spacing: 8) {
                    Text("适用边界").font(.headline)
                    Text(lesson.boundary)
                }.modifier(MentorReadingSectionMarker(itemID: itemID, section: .boundary, geometry: readingGeometry))
                if let observation = lesson.observation {
                    Text(observation).modifier(MentorReadingSectionMarker(itemID: itemID, section: .observation, geometry: readingGeometry))
                }
                Text(lesson.sourceType == .teachingExample ? "教学示例" : "外部参考")
                    .font(.subheadline).foregroundStyle(DS.mutedInk)
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

    @ViewBuilder private var status: some View {
        if feature.state.phase == .submitting { ProgressView("正在回应…") }
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
            Text("这一步没有完成。已保存的内容仍在，可以重试或稍后继续。")
                .foregroundStyle(DS.caution)
        }
        if feature.state.phase == .lessonExhausted {
            Text("暂时没有新的内容，可以回看这次交流，或自己写一句理解。")
        }
        if feature.state.draftSaveError != nil {
            Text("输入尚未保存，请重试后再离开。").foregroundStyle(DS.caution)
            Button("重试保存输入") { Task { _ = await feature.flushPendingEdits() } }
                .buttonStyle(.bordered).controlSize(.large)
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

    private var input: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("你想说的话").font(.headline)
            TextEditor(text: Binding(get: { feature.state.inputText }, set: { feature.updateInputText($0) }))
                .frame(height: inputHeight).padding(8)
                .scrollContentBackground(.hidden)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.cornerRadius))
                .focused($inputFocused)
                .accessibilityLabel("你想说的话")
            Button {
                inputFocused = false
                online { feature.submit() }
            } label: {
                Text("发送").foregroundStyle(DS.background).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(![.editing, .reading, .showingResponse].contains(feature.state.phase) || app.isAIRunning ||
                      feature.state.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                      (feature.state.phase == .showingResponse && feature.state.acknowledgedResponseItemID != feature.state.responseItemID))
            ForEach(feature.state.response?.availableSuggestedActions.filter { $0 == .explain || $0 == .anotherLesson } ?? [], id: \.self) { action in
                Button(action == .explain ? "直接讲讲这个视角" : "换一个视角") {
                    if action == .explain { online { feature.submit(intent: action.rawValue) } }
                    else {
                        flushReadingPosition()
                        feature.submit(intent: action.rawValue)
                    }
                }.buttonStyle(.bordered).controlSize(.large)
            }
        }
    }

    private func online(_ action: () -> Void) {
        guard app.apiKeyConfigured else { needsConfiguration = true; return }
        guard !app.isAIRunning else { return }
        needsConfiguration = false
        action()
    }

    private func flushReadingPosition() {
        readingGeometry.flush()
        readingPosition.flush()
    }

    private func leave(ending: Bool) {
        inputFocused = false
        flushReadingPosition()
        if feature.state.isViewingHistory || feature.state.session == nil || feature.state.phase == .ended { dismiss(); return }
        wantsClose = true
        if ending { feature.finish() } else { feature.pause() }
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
    var body: some View {
        Group {
            if let feature {
                if ProcessInfo.processInfo.arguments.contains("--mentor-preferences-fixture") {
                    NavigationStack { MentorLessonPreferencesView(feature: feature).padding().navigationTitle("听讲偏好") }
                } else { MentorHomeView(feature: feature) }
            }
            else if let error { Text(error) }
            else { ProgressView("准备测试交流…") }
        }.task {
            guard feature == nil else { return }
            do {
                let database = try AppDatabase(dbQueue: GRDB.DatabaseQueue())
                let repository = SQLiteMentorRepository(database: database)
                if ProcessInfo.processInfo.arguments.contains("--mentor-history-fixture") {
                    for index in 1...45 {
                        try await repository.createSession(MentorSession(id: UUID(), initialEntry: "discuss", lifecycle: .ended,
                            draftText: String(format: "History record %02d", index), draftRevision: 1,
                            activityAt: Date(timeIntervalSince1970: Double(100000 - index * 100))))
                    }
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
                feature = MentorFeatureStore(repository: repository, transport: MentorUIOfflineTransport(), catalog: catalog)
                app.apiKeyConfigured = false
            } catch { self.error = String(describing: error) }
        }
    }
}
private struct MentorUIOfflineTransport: MentorTransport {
    func complete(_ request: LLMRequest) async throws -> Data { throw LLMClientError.missingAPIKey }
}
#endif
