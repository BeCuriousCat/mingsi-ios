import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ZStack(alignment: .top) {
            DS.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if store.hasResumeableLoop && store.selectedTab != .today {
                    ResumeTodayBanner(
                        title: store.loopResumeText,
                        subtitle: "你还可以继续完成今日复盘，避免思路断掉。",
                        actionTitle: "继续今日复盘",
                        action: { store.selectedTab = .today }
                    )
                    .padding(.horizontal, DS.pagePadding)
                    .padding(.top, 8)
                }

                TabView(selection: $store.selectedTab) {
                    TodayView()
                        .tag(AppTab.today)
                        .tabItem { Label(AppTab.today.title, systemImage: "sun.max.fill") }

                    HistoryView()
                        .tag(AppTab.history)
                        .tabItem { Label(AppTab.history.title, systemImage: "clock.arrow.circlepath") }

                    ProjectsView()
                        .tag(AppTab.projects)
                        .tabItem { Label(AppTab.projects.title, systemImage: "tray.full") }

                    GrowthView()
                        .tag(AppTab.growth)
                        .tabItem { Label(AppTab.growth.title, systemImage: "chart.line.uptrend.xyaxis") }

                    SettingsView()
                        .tag(AppTab.settings)
                        .tabItem { Label(AppTab.settings.title, systemImage: "gearshape.fill") }
                }
            }
        }
    }
}

private struct ResumeTodayBanner: View {
    let title: String
    let subtitle: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(DS.accent)
        }
        .padding(14)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(DS.border, lineWidth: 1)
        )
    }
}
