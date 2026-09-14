import SwiftUI
import GRDB

struct MentorHomeView: View {
    @EnvironmentObject private var app: AppStore
    @ObservedObject var feature: MentorFeatureStore
    @State private var showsConversation = false
    @State private var showsToday = false

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
                        if feature.state.recentSessionsCursor != nil {
                            Button("查看更多交流") { feature.loadMoreRecentSessions() }
                                .controlSize(.large).buttonStyle(.bordered)
                                .disabled(feature.state.isLoadingHistory)
                        }
                    }
                    if feature.state.historyError != nil {
                        Text("最近交流暂时没能读取，请重试。")
                        Button("重新读取") { feature.loadRecentSessions() }
                            .controlSize(.large).buttonStyle(.bordered)
                    }
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

private struct MentorVisibleItems: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
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

    var body: some View {
        NavigationStack {
            GeometryReader { viewport in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        if feature.state.isTransitioningSession {
                            ProgressView("正在保存和打开交流…")
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
                }
                .onPreferenceChange(MentorVisibleItems.self) { frames in
                    guard !feature.state.isTransitioningSession else { return }
                    let visible = viewport.frame(in: .global)
                    for (id, frame) in frames where frame.intersects(visible) && frame.height > 0 {
                        if id == feature.state.responseItemID { feature.acknowledgeResponse(itemID: id) }
                        if id == feature.state.lesson?.id { feature.acknowledgeLesson() }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
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
                    if !feature.state.isViewingHistory {
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
        .sheet(isPresented: $showsSettings) { SettingsView().environmentObject(app) }
        .onChange(of: feature.state.isTransitioningSession) { _, transitioning in
            guard wantsClose, !transitioning else { return }
            wantsClose = false
            if feature.state.phase == .paused || feature.state.phase == .ended { dismiss() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, !feature.state.isTransitioningSession, !feature.state.isViewingHistory { feature.pause() }
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
        ForEach(feature.state.timeline, id: \.id) { item in
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
                }
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: MentorVisibleItems.self, value: [item.id: proxy.frame(in: .global)])
                })
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

    private func lesson(_ lesson: MentorLesson, itemID: UUID) -> some View {
            VStack(alignment: .leading, spacing: 16) {
                Text(lesson.title).font(.title2.weight(.semibold))
                Text(lesson.claim)
                Text(lesson.example)
                Text("适用边界").font(.headline)
                Text(lesson.boundary)
                if let observation = lesson.observation { Text(observation) }
                Text(lesson.sourceType == .teachingExample ? "教学示例" : "外部参考")
                    .font(.subheadline).foregroundStyle(DS.mutedInk)
                ForEach(lesson.citations, id: \.url) { citation in
                    if let url = URL(string: citation.url), ["https", "http"].contains(url.scheme) {
                        Link(citation.title, destination: url)
                    }
                }
            }
            .textSelection(.enabled)
            .background(GeometryReader { proxy in
                Color.clear.preference(key: MentorVisibleItems.self, value: [itemID: proxy.frame(in: .global)])
            })
        }

    private func decodeLesson(_ json: String) -> MentorLesson? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(MentorLesson.self, from: Data(json.utf8))
    }

    @ViewBuilder private var status: some View {
        if feature.state.phase == .submitting { ProgressView("正在回应…") }
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
                .frame(minHeight: 120).padding(8)
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
                    else { feature.submit(intent: action.rawValue) }
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

    private func leave(ending: Bool) {
        inputFocused = false
        if feature.state.isViewingHistory || feature.state.session == nil || feature.state.phase == .ended { dismiss(); return }
        wantsClose = true
        if ending { feature.finish() } else { feature.pause() }
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
            if let feature { MentorHomeView(feature: feature) }
            else if let error { Text(error) }
            else { ProgressView("准备测试交流…") }
        }.task {
            guard feature == nil else { return }
            do {
                let database = try AppDatabase(dbQueue: GRDB.DatabaseQueue())
                feature = MentorFeatureStore(repository: SQLiteMentorRepository(database: database), transport: MentorUIOfflineTransport())
                app.apiKeyConfigured = false
            } catch { self.error = String(describing: error) }
        }
    }
}
private struct MentorUIOfflineTransport: MentorTransport {
    func complete(_ request: LLMRequest) async throws -> Data { throw LLMClientError.missingAPIKey }
}
#endif
