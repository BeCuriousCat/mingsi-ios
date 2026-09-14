import SwiftUI

struct MentorHistoryView: View {
    @EnvironmentObject private var app: AppStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var feature: MentorFeatureStore
    @StateObject private var history: MentorHistoryStore
    @State private var showsConversation = false
    @State private var visibleSessionID: UUID?
    @State private var returnSessionID: UUID?
    @State private var returnIndex = 0

    init(feature: MentorFeatureStore) {
        self.feature = feature
        _history = StateObject(wrappedValue: feature.makeHistoryStore())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(history.sessions) { session in
                        Button {
                            returnSessionID = visibleSessionID ?? session.id
                            returnIndex = history.sessions.firstIndex(where: { $0.id == returnSessionID }) ?? 0
                            feature.viewSession(id: session.id)
                            showsConversation = true
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(session.preview.isEmpty ? "还没说完的交流" : session.preview)
                                    .lineLimit(3).foregroundStyle(DS.ink)
                                HStack {
                                    Text(session.activityAt, style: .date)
                                    Text(session.lifecycle == .ended ? "已结束" : "未结束")
                                }
                                .font(.subheadline).foregroundStyle(DS.mutedInk)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .disabled(feature.state.isTransitioningSession)
                        .id(session.id)
                    }
                    if history.isLoading { ProgressView("正在读取交流…") }
                    if let error = history.error {
                        Text(error).foregroundStyle(DS.caution)
                        Button("重新读取") { history.refresh() }
                            .buttonStyle(.bordered).controlSize(.large)
                    } else if history.hasMore {
                        Button("加载更多交流") { history.loadMore() }
                            .buttonStyle(.bordered).controlSize(.large)
                            .disabled(history.isLoading)
                    } else if history.sessions.isEmpty && !history.isLoading {
                        Text("还没有交流记录。回到首页，从一件事开始。")
                            .foregroundStyle(DS.mutedInk)
                    }
                }
                .scrollTargetLayout()
                .frame(maxWidth: 640, alignment: .leading)
                .padding(DS.pagePadding)
                .frame(maxWidth: .infinity)
            }
            .scrollPosition(id: $visibleSessionID, anchor: .top)
            .background(DS.background)
            .foregroundStyle(DS.ink)
            .navigationTitle("全部交流")
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
        .task { history.refresh() }
        .onChange(of: history.isLoading) { _, loading in
            guard !loading, let target = returnSessionID else { return }
            if history.sessions.contains(where: { $0.id == target }) {
                visibleSessionID = target
            } else if !history.sessions.isEmpty {
                visibleSessionID = history.sessions[min(returnIndex, history.sessions.count - 1)].id
            }
            returnSessionID = nil
        }
        .sheet(isPresented: $showsConversation, onDismiss: { history.refresh() }) {
            MentorConversationView(feature: feature).environmentObject(app)
        }
    }
}
