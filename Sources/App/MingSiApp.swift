import SwiftUI

@main
struct MingSiApp: App {
    @StateObject private var store: AppStore

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
        _store = StateObject(wrappedValue: storeInstance)
#else
        _store = StateObject(wrappedValue: AppStore.live())
#endif
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(store)
                .task {
                    #if DEBUG
                    if AppStore.shouldUseVisualQAProjectDetailFixture() {
                        store.applyVisualQAProjectDetailFixture()
                        store.applyVisualQATabOverride()
                        return
                    }
                    store.applyVisualQATodaySeed()
                    guard store.loadsPersistedStateOnLaunch else { return }
                    #endif
                    await store.loadPersistedState()
                }
        }
    }
}
