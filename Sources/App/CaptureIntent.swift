import AppIntents
import Foundation

extension Notification.Name {
    static let mingsiOpenTodayCapture = Notification.Name("mingsi.openTodayCapture")
}

enum CaptureShortcutBridge {
    static let pendingKey = "mingsi.pendingOpenTodayCapture"

    static func requestOpen() {
        UserDefaults.standard.set(true, forKey: pendingKey)
        NotificationCenter.default.post(name: .mingsiOpenTodayCapture, object: nil)
    }

    static func consumePendingRequest() -> Bool {
        guard UserDefaults.standard.bool(forKey: pendingKey) else { return false }
        UserDefaults.standard.removeObject(forKey: pendingKey)
        return true
    }
}

struct OpenTodayCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "打开今日闪念"
    static let description = IntentDescription("打开明思并直接进入今日闪念输入界面。")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        CaptureShortcutBridge.requestOpen()
        return .result()
    }
}

struct RecordToMingSiIntent: AppIntent {
    static let title: LocalizedStringResource = "记录到明思"
    static let description = IntentDescription("将一条闪念直接保存到明思。")
    static let openAppWhenRun = false
    @Parameter(title: "闪念") var text: String

    init() {}
    init(text: String) { self.text = text }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let database = try AppDatabase(url: try AppDatabase.defaultURL())
        let saver = CaptureIntentSaver(repository: SQLiteCaptureFragmentRepository(database: database))
        try await saver.saveIntentCapture(text)
        return .result(dialog: "已保存到明思")
    }
}

struct MingSiAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: RecordToMingSiIntent(), phrases: ["记录到\(.applicationName)", "用\(.applicationName)记录闪念"], shortTitle: "记录到明思", systemImageName: "bolt.fill")
        AppShortcut(intent: OpenTodayCaptureIntent(), phrases: ["打开\(.applicationName)今日闪念", "在\(.applicationName)里记一条闪念"], shortTitle: "打开今日闪念", systemImageName: "square.and.pencil")
    }
}
