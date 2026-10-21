import SwiftUI
import UIKit

final class MingSiApplicationDelegate: NSObject, UIApplicationDelegate {
    static let openTodayCaptureShortcutType = "com.codex.mingsi.open-today-capture"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.shortcutItems = [
            UIApplicationShortcutItem(
                type: Self.openTodayCaptureShortcutType,
                localizedTitle: "记录闪念",
                localizedSubtitle: "打开今日闪念输入",
                icon: UIApplicationShortcutIcon(systemImageName: "mic.fill")
            )
        ]

        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // With scenes, a cold shortcut launch arrives here instead of through
        // performActionFor. The bridge is consumed after the SwiftUI root is mounted.
        if let shortcutItem = options.shortcutItem {
            _ = handle(shortcutItem)
        }
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(handle(shortcutItem))
    }

    private func handle(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard shortcutItem.type == Self.openTodayCaptureShortcutType else { return false }
        CaptureShortcutBridge.requestOpen()
        return true
    }
}

@main
struct MingSiApp: App {
    @StateObject private var store: AppStore
    @UIApplicationDelegateAdaptor(MingSiApplicationDelegate.self) private var applicationDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        DS.configureTabBarAppearance()
#if DEBUG
        let storeInstance: AppStore
        if ProcessInfo.processInfo.arguments.contains("--growth-evidence-ui-fixture") {
            storeInstance = AppStore.growthEvidenceUIFixture()
        } else if ProcessInfo.processInfo.arguments.contains("--result-review-ui-fixture") {
            storeInstance = AppStore.resultReviewUIFixture()
        } else if ProcessInfo.processInfo.arguments.contains("--today-loop-ui-fixture"),
                  ProcessInfo.processInfo.arguments.contains("--verification-submission-delay") {
            storeInstance = AppStore.verificationSubmissionUIFixture()
        } else if ProcessInfo.processInfo.arguments.contains("--today-loop-ui-fixture"),
                  ProcessInfo.processInfo.arguments.contains("--guidance-presentation-ui-fixture") {
            storeInstance = AppStore.guidancePresentationUIFixture()
        } else if ProcessInfo.processInfo.arguments.contains("--today-loop-ui-fixture") {
            storeInstance = AppStore(todayAIService: TodayAIService(promptProvider: LocalPromptProvider(), llmClient: MockLLMClient()),
                refreshesAIServiceFromKeychain: false, trainingCasesVNextEnabled: false)
        } else if ProcessInfo.processInfo.arguments.contains("--mentor-startup-ui-test") {
            storeInstance = AppStore.mentorStartupUIFixture()
        } else if ProcessInfo.processInfo.arguments.contains("--life-guidance-ui-test") {
            storeInstance = AppStore.lifeGuidanceUIFixture()
        } else if ProcessInfo.processInfo.arguments.contains("--speech-ui-fixture") ||
            ProcessInfo.processInfo.arguments.contains("--mentor-capture-fixture") ||
            ProcessInfo.processInfo.arguments.contains("--mentor-ui-test") {
            storeInstance = AppStore.speechInputUIFixture()
        } else if AppStore.shouldUseVisualQASideQuestV2Fixture() {
            storeInstance = AppStore.visualQASideQuestV2()
        } else if AppStore.shouldUseVisualQAProjectDetailFixture() {
            storeInstance = AppStore.visualQAProjectDetail()
        } else if AppStore.shouldUseVisualQAHistoryCaseSettlementFixture() {
            storeInstance = AppStore.visualQAHistoryCaseSettlement()
        } else if AppStore.shouldSeedVisualQAVNextOverview() || AppStore.shouldSeedVisualQALifeGuidanceReview() {
            storeInstance = AppStore.visualQAVNextOverview()
        } else {
            storeInstance = AppStore.live()
        }
        storeInstance.applyVisualQATabOverride()
        storeInstance.applyVisualQATodaySeed()
        storeInstance.applyVisualQAVNextOverviewSeed()
        storeInstance.applyVisualQALifeGuidanceReviewSeed()
        storeInstance.applyVisualQASettingsAuditProof()
        _store = StateObject(wrappedValue: storeInstance)
#else
        _store = StateObject(wrappedValue: AppStore.live())
#endif
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(store)
                .onChange(of: scenePhase) { _, phase in
                    store.handleScenePhase(phase)
                }
                .task {
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--mentor-startup-ui-test"),
                       let database = store.mentorUITestDatabase {
                        do {
                            try await store.prepareStoppedReviewUIFixturePersistence()
                        } catch {
                            assertionFailure("Stopped review fixture persistence failed: \(error)")
                        }
                        // Exercise the production root and recovery transaction on an isolated file.
                        // The trigger fails the first recovery; removing it allows the UI retry.
                        if ProcessInfo.processInfo.arguments.contains("--mentor-startup-recovery-failure") {
                            do {
                                let repository = SQLiteMentorRepository(database: database)
                                let id = UUID()
                                try await repository.createSession(MentorSession(id: id, initialEntry: "discuss", lifecycle: .active,
                                    draftText: "启动失败仍保留的草稿", draftRevision: 1, activityAt: .now))
                                _ = try await repository.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id,
                                    text: "启动前已提交的原话", intent: "reply", contextSnapshotJSON: "{}"))
                                try await database.dbQueue.write {
                                    try $0.execute(sql: "CREATE TRIGGER fail_ui_startup BEFORE UPDATE OF state ON mentor_requests WHEN NEW.state = 'interrupted' BEGIN SELECT RAISE(ABORT, 'isolated startup fixture'); END")
                                }
                                _ = await store.prepareMentorFeature()
                                try await database.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_ui_startup") }
                            } catch { assertionFailure("Startup UI fixture setup failed: \(error)") }
                        } else {
                            _ = await store.prepareMentorFeature()
                        }
                        return
                    }
                    if ProcessInfo.processInfo.arguments.contains("--life-guidance-ui-test") {
                        _ = await store.prepareMentorFeature()
                        return
                    }
                    if AppStore.shouldUseVisualQASideQuestV2Fixture() {
                        return
                    }
                    if AppStore.shouldUseVisualQAProjectDetailFixture() {
                        store.applyVisualQAProjectDetailFixture()
                        store.applyVisualQATabOverride()
                        return
                    }
                    if AppStore.shouldUseVisualQAHistoryCaseSettlementFixture() {
                        return
                    }
                    if AppStore.shouldSeedVisualQAVNextOverview() {
                        return
                    }
                    if AppStore.shouldSeedVisualQALifeGuidanceReview() {
                        return
                    }
                    store.applyVisualQATodaySeed()
                    store.applyVisualQAVNextOverviewSeed()
                    store.applyVisualQALifeGuidanceReviewSeed()
                    store.applyVisualQASettingsAuditProof()
                    guard store.loadsPersistedStateOnLaunch else { return }
                    #endif
                    await store.loadPersistedState()
                    _ = await store.prepareMentorFeature()
                    // A cold App Shortcut may arrive before SwiftUI has mounted
                    // the final Today surface. Consume it only after the
                    // feature assembly completes, so the notification reaches
                    // either MentorHomeView or the legacy TodayView.
                    if CaptureShortcutBridge.consumePendingRequest() {
                        await Task.yield()
                        NotificationCenter.default.post(name: .mingsiOpenTodayCapture, object: nil)
                    }
                }
        }
    }
}
