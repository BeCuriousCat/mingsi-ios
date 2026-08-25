import SwiftUI

@main
struct MingSiApp: App {
    @StateObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        DS.configureTabBarAppearance()
#if DEBUG
        let storeInstance: AppStore
        if AppStore.shouldUseVisualQASideQuestV2Fixture() {
            storeInstance = AppStore.visualQASideQuestV2()
        } else if AppStore.shouldUseVisualQAProjectDetailFixture() {
            storeInstance = AppStore.visualQAProjectDetail()
        } else if AppStore.shouldUseVisualQAHistoryCaseSettlementFixture() {
            storeInstance = AppStore.visualQAHistoryCaseSettlement()
        } else if AppStore.shouldSeedVisualQAVNextOverview() {
            storeInstance = AppStore.visualQAVNextOverview()
        } else {
            storeInstance = AppStore.live()
        }
        storeInstance.applyVisualQATabOverride()
        storeInstance.applyVisualQATodaySeed()
        storeInstance.applyVisualQAVNextOverviewSeed()
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
                    store.applyVisualQATodaySeed()
                    store.applyVisualQAVNextOverviewSeed()
                    store.applyVisualQASettingsAuditProof()
                    guard store.loadsPersistedStateOnLaunch else { return }
                    #endif
                    await store.loadPersistedState()
                }
        }
    }
}
