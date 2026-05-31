# Subtask 001: Persistence Wiring PRD

## Owner

Worker agent: Persistence and AppStore wiring.

## Context

The app already has a buildable SwiftUI scaffold, vendored GRDB, repository protocols, migration definitions, and initial SQLite repository implementations. The next goal is to make persistence actually support the running app without coupling UI views to GRDB.

After subtask 003, `DailyEntryDraft` now includes loop-critical fields:

- `hasSelectedSessionMode`
- `selectedLens`
- `yesterdayCompletion`
- `yesterdayValueRating`
- `state`
- `rawText`
- `sessionMode`

These are semantic product data, not presentation state. They must survive app restart.

## Scope

Allowed write scope:

- `Sources/App/AppStore.swift`
- `Sources/App/MingSiApp.swift`
- `Sources/Services/PersistenceCore.swift`
- small protocol additions in `Sources/Services/CoreProtocols.swift` only if needed

Do not edit:

- `Sources/Features/Today/TodayView.swift`
- `Sources/Features/FeatureTabs.swift`
- `Sources/DesignSystem/Theme.swift`
- `Vendor/GRDB.swift`
- product docs except delegation log

## Requirements

1. Initialize `AppDatabase` once during app startup.
2. Inject repository implementations into `AppStore`.
3. Load the latest draft on startup.
4. Save `todayDraft` when the user advances state or edits significant data through existing store methods.
5. Provide a safe fallback if database initialization fails: app should still open with preview/local in-memory data and expose a settings/status message.
6. Keep `AppStore` as the UI-facing state object. SwiftUI views must not import GRDB or call repositories directly.
7. Do not persist presentation-only state such as selected tab.
8. Preserve raw user input exactly in storage.
9. Persist and reload all loop-critical `DailyEntryDraft` fields listed above.
10. Persist generated/confirmed `ThinkingCard`, `Quest`, and `PrincipleAsset` records when the user reaches the corresponding state.
11. Use an explicit migration for new daily loop columns if needed. Do not assume a developer simulator database is empty.
12. Preserve `created_at` where practical on upsert; updating `updated_at` is expected.

## Architecture Constraints

- Repository protocols are the boundary.
- Database row structs stay private to `PersistenceCore.swift`.
- Use semantic domain models as AppStore state.
- Do not add a service locator or global mutable database singleton.
- Keep future server migration possible: prompt and LLM state must remain outside persistence wiring.
- It is acceptable for `AppStore` to call repositories as MVP orchestration, but SwiftUI views must remain repository-free.
- If repository methods need small additions, update protocols and implementations together.

## Acceptance Criteria

- `xcodegen generate` succeeds.
- Simulator build succeeds:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
```

- Closing/reopening AppStore in code can load the latest `DailyEntryDraft` from SQLite.
- Reloaded `DailyEntryDraft` includes selected mode, selected lens, yesterday verification choices, raw text, and loop state.
- Saving cards/quests/principles through store methods writes to SQLite using the active draft id.
- API key remains Keychain-only.
- No SwiftUI view imports GRDB.

## Final Response Required

List:

- files changed
- important implementation decisions
- commands run and whether they passed
- any risks left for Codex review
