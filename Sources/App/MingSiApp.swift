import SwiftUI

@main
struct MingSiApp: App {
    @StateObject private var store: AppStore

    init() {
        DS.configureTabBarAppearance()
#if DEBUG
        let storeInstance: AppStore
        if AppStore.isVisualQAProjectDetailLaunch() {
            storeInstance = AppStore.visualQAProjectDetail()
        } else {
            storeInstance = AppStore.live()
        }
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
                    if AppStore.isVisualQAProjectDetailLaunch() {
                        store.applyVisualQAProjectDetailFixture()
                        return
                    }
                    guard store.loadsPersistedStateOnLaunch else { return }
                    #endif
                    await store.loadPersistedState()
                }
        }
    }
}
