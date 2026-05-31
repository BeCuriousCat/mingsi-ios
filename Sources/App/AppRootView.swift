import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            TodayView()
                .tag(AppTab.today)
                .tabItem {
                    Label(AppTab.today.title, systemImage: "sun.max")
                }

            HistoryView()
                .tag(AppTab.history)
                .tabItem {
                    Label(AppTab.history.title, systemImage: "clock.arrow.circlepath")
                }

            ProjectsView()
                .tag(AppTab.projects)
                .tabItem {
                    Label(AppTab.projects.title, systemImage: "tray.full")
                }

            GrowthView()
                .tag(AppTab.growth)
                .tabItem {
                    Label(AppTab.growth.title, systemImage: "chart.line.uptrend.xyaxis")
                }

            SettingsView()
                .tag(AppTab.settings)
                .tabItem {
                    Label(AppTab.settings.title, systemImage: "gearshape")
                }
        }
        .tint(DS.accent)
    }
}
