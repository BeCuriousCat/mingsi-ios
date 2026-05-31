import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            TodayView()
                .tag(AppTab.today)
                .tabItem {
                    VStack(spacing: 4) {
                        Image(systemName: "sun.max")
                        Text(AppTab.today.title)
                    }
                }

            HistoryView()
                .tag(AppTab.history)
                .tabItem {
                    VStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                        Text(AppTab.history.title)
                    }
                }

            ProjectsView()
                .tag(AppTab.projects)
                .tabItem {
                    VStack(spacing: 4) {
                        Image(systemName: "tray.full")
                        Text(AppTab.projects.title)
                    }
                }

            GrowthView()
                .tag(AppTab.growth)
                .tabItem {
                    VStack(spacing: 4) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                        Text(AppTab.growth.title)
                    }
                }

            SettingsView()
                .tag(AppTab.settings)
                .tabItem {
                    VStack(spacing: 4) {
                        Image(systemName: "gearshape")
                        Text(AppTab.settings.title)
                    }
                }
        }
        .tint(DS.accent)
        .overlay(alignment: .top) {
            if store.hasResumeableLoop && store.selectedTab != .today {
                ResumeTodayBanner(
                    title: store.loopResumeText,
                    subtitle: "你还可以继续完成今日复盘，避免思路断掉。",
                    actionTitle: "继续今日复盘",
                    action: { store.selectedTab = .today }
                )
                .padding(.horizontal, DS.pagePadding)
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.hasResumeableLoop)
    }
}

private struct ResumeTodayBanner: View {
    let title: String
    let subtitle: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.turn.down.right")
                .font(.body.weight(.semibold))
                .foregroundStyle(DS.accent)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button(actionTitle, action: action)
                .font(.footnote.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(DS.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(DS.accent.opacity(0.25), lineWidth: 1)
        )
    }
}
