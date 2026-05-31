import SwiftUI

@main
struct MingSiApp: App {
    @StateObject private var store = AppStore.live()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(store)
                .task {
                    await store.loadPersistedState()
                }
        }
    }
}
