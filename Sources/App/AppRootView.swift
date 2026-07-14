import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            TodayView()
                .tag(AppTab.today)
                .tabItem {
                    Label(AppTab.today.title, systemImage: "square.and.pencil")
                }

            HistoryView()
                .tag(AppTab.history)
                .tabItem {
                    Label(AppTab.history.title, systemImage: "rectangle.stack")
                }

            ProjectsView()
                .tag(AppTab.projects)
                .tabItem {
                    Label(AppTab.projects.title, systemImage: "folder")
                }

            GrowthView()
                .tag(AppTab.growth)
                .tabItem {
                    Label(AppTab.growth.title, systemImage: "gauge")
                }

            SettingsView()
                .tag(AppTab.settings)
                .tabItem {
                    Label(AppTab.settings.title, systemImage: "slider.horizontal.3")
                }
        }
        .tint(DS.accent)
        .safeAreaInset(edge: .top, spacing: 0) {
            if store.pendingAIRepairCount > 0 {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.caution)
                    Text(pendingTrainingRepairBannerText(
                        isRunning: store.isAIRunning,
                        pendingCount: store.pendingAIRepairCount
                    ))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.ink)
                    Spacer()
                    Button("查看") {
                        store.showPendingAIRepairGuidance()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(store.isAIRunning)
                    Button {
                        store.dismissPendingAIRepairs()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DS.mutedInk)
                }
                .padding(.horizontal, DS.pagePadding)
                .padding(.vertical, 8)
                .background(DS.background.opacity(0.97))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DS.hairline)
                        .frame(height: 1)
                }
            }
        }
    }
}

func pendingTrainingRepairBannerText(isRunning: Bool, pendingCount: Int) -> String {
    if isRunning {
        return "明思正在重试当前训练，请等待"
    }
    return "有 \(pendingCount) 个本地训练结果可重试"
}
