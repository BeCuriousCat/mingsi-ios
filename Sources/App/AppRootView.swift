import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var store: AppStore

    private var usesMentorUIFixture: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--mentor-ui-test")
        #else
        false
        #endif
    }

    /// Visual QA seeds are built around the Today surface. They deliberately
    /// skip persisted mentor restoration, so the root must not replace the
    /// seeded Today screen with the normal mentor-preparation placeholder.
    private var usesTodayVisualFixture: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--today-lens-library-ui-fixture") ||
            ProcessInfo.processInfo.arguments.contains("--today-question-explanation-ui-fixture") ||
            ProcessInfo.processInfo.arguments.contains("--today-review-stop-ui-fixture") ||
            ProcessInfo.processInfo.arguments.contains("--today-loop-ui-fixture") ||
            ProcessInfo.processInfo.arguments.contains("--result-review-ui-fixture") ||
            AppStore.shouldSeedVisualQAVNextOverview() ||
            AppStore.shouldSeedVisualQALifeGuidanceReview() ||
            AppStore.shouldSeedVisualQASingleNudge()
        #else
        return false
        #endif
    }

#if DEBUG
    @Environment(\.dynamicTypeSize) private var systemDynamicTypeSize

    private var speechUITestDynamicTypeSize: DynamicTypeSize? {
        let arguments = ProcessInfo.processInfo.arguments
        guard (arguments.contains("--permission-ui-fixture") || arguments.contains("--growth-evidence-ui-fixture") || arguments.contains("--result-review-ui-fixture") || arguments.contains("--speech-ui-fixture") || arguments.contains("--life-guidance-ui-test") || arguments.contains("--mentor-startup-ui-test") || arguments.contains("--today-loop-ui-fixture") || arguments.contains("--principle-practice-ui-fixture")),
              let index = arguments.firstIndex(of: "-UIPreferredContentSizeCategory"),
              arguments.indices.contains(index + 1) else { return nil }
        switch arguments[index + 1] {
        case "UICTContentSizeCategoryAccessibilityXXXL": return .accessibility5
        case "UICTContentSizeCategoryL": return .large
        default: return nil
        }
    }

    private var speechUITestColorScheme: ColorScheme? {
        let arguments = ProcessInfo.processInfo.arguments
        guard (arguments.contains("--permission-ui-fixture") || arguments.contains("--growth-evidence-ui-fixture") || arguments.contains("--result-review-ui-fixture") || arguments.contains("--speech-ui-fixture") || arguments.contains("--life-guidance-ui-test") || arguments.contains("--mentor-startup-ui-test") || arguments.contains("--today-loop-ui-fixture") || arguments.contains("--principle-practice-ui-fixture")),
              let index = arguments.firstIndex(of: "-AppleInterfaceStyle"),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1] == "Dark" ? .dark : .light
    }
#endif

    var body: some View {
        TabView(selection: $store.selectedTab) {
            Group {
                if usesMentorUIFixture {
                    #if DEBUG
                    MentorUITestHarness()
                    #endif
                } else if usesTodayVisualFixture {
                    TodayView()
                } else if let mentor = store.mentorFeatureStore {
                    MentorHomeView(feature: mentor)
                } else if store.supportsMentorFeature {
                    MentorPreparationView()
                } else {
                    TodayView()
                }
            }
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
        .background(DS.background.ignoresSafeArea())
        .toolbarBackground(DS.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .background(TabBarSurfaceBridge().accessibilityHidden(true))
#if DEBUG
        .preferredColorScheme(speechUITestColorScheme)
        .dynamicTypeSize(speechUITestDynamicTypeSize ?? systemDynamicTypeSize)
#endif
        .onReceive(NotificationCenter.default.publisher(for: .mingsiOpenTodayCapture)) { _ in
            // A shortcut should always land on the capture surface even when
            // the app was last left on History, Projects, or another tab.
            store.selectedTab = .today
        }
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

private struct MentorPreparationView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsCapture = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let error = store.mentorPreparationError {
                        Text("暂时没能打开交流")
                            .font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                        Text(error).fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("mentor.startup.error")
                        Button("重新打开交流") {
                            Task { _ = await store.prepareMentorFeature() }
                        }
                        .buttonStyle(.borderedProminent).foregroundStyle(DS.onAccent)
                        .frame(minHeight: DS.minimumTapTarget)
                        .disabled(store.isPreparingMentorFeature)
                        .accessibilityIdentifier("mentor.startup.retry")
                        Button("先记一条闪念") { showsCapture = true }
                            .buttonStyle(.bordered).frame(minHeight: DS.minimumTapTarget)
                    } else {
                        ProgressView("正在恢复交流…")
                            .accessibilityIdentifier("mentor.startup.loading")
                    }
                }
                .frame(maxWidth: 640, alignment: .leading)
                .padding(DS.pagePadding).frame(maxWidth: .infinity)
            }
            .background(DS.background).foregroundStyle(DS.ink)
            .navigationTitle("明思").navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showsCapture) {
            QuickCaptureSheet().environmentObject(store).dynamicTypeSize(dynamicTypeSize)
        }
        .onReceive(NotificationCenter.default.publisher(for: .mingsiOpenTodayCapture)) { _ in
            showsCapture = true
        }
    }
}

func pendingTrainingRepairBannerText(isRunning: Bool, pendingCount: Int) -> String {
    if isRunning {
        return "明思正在重试当前训练，请等待"
    }
    return "有 \(pendingCount) 个本地训练结果可重试"
}
