import SwiftUI

@main
struct MingSiApp: App {
    @StateObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        DS.configureTabBarAppearance()
#if DEBUG
        let storeInstance: AppStore
        if AppStore.shouldUseVisualQAProjectDetailFixture() {
            storeInstance = AppStore.visualQAProjectDetail()
        } else {
            storeInstance = AppStore.live()
        }
        storeInstance.applyVisualQATabOverride()
        storeInstance.applyVisualQATodaySeed()
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
                    if AppStore.shouldUseVisualQAProjectDetailFixture() {
                        store.applyVisualQAProjectDetailFixture()
                        store.applyVisualQATabOverride()
                        return
                    }
                    store.applyVisualQATodaySeed()
                    store.applyVisualQASettingsAuditProof()
                    guard store.loadsPersistedStateOnLaunch else { return }
                    #endif
                    await store.loadPersistedState()
                }
        }
    }
}
