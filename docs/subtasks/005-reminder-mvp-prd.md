# Subtask 005: Reminder MVP PRD

## Owner

Worker agent: local reminders.

## Context

MVP needs optional local notification reminders for tomorrow's main quest. Calendar/Reminders sync is explicitly future scope. `LocalNotificationReminder` already exists but is not wired into the product flow.

## Scope

Allowed write scope:

- `Sources/App/AppStore.swift`
- `Sources/Services/CoreProtocols.swift`
- new files under `Sources/Services/` for notification permission/helper types
- `Sources/Features/Today/TodayView.swift` only for minimal reminder time controls if needed
- `Sources/Features/FeatureTabs.swift` only for settings display if needed

Do not edit:

- persistence internals unless a tiny reminder id field mapping is required
- GLM files
- vendor code

## Requirements

1. Add reminder scheduling after the main quest is saved.
2. Ask notification permission before scheduling.
3. Default reminder time: tomorrow 09:00 local time.
4. Allow user to disable scheduling for the current quest if UI scope stays small.
5. Store enough in memory/domain to avoid duplicate reminder scheduling during the same session.
6. Use `ReminderService` protocol from AppStore; do not call `UNUserNotificationCenter` from SwiftUI views.
7. Handle permission denied gracefully with a visible settings/today message.
8. Keep Apple Calendar/Reminders sync out of MVP.

## Architecture Constraints

- Notification implementation stays behind `ReminderService`.
- Future `AppleRemindersSync` or `CalendarSync` should be adapter additions, not Today UI rewrites.
- Do not make notification permission a hard blocker for completing Today loop.

## Acceptance Criteria

- Build succeeds.
- Saving a main quest attempts to schedule one local notification.
- Denied permissions do not crash or block completing the loop.
- Today UI or Settings exposes whether reminders are active/configurable at a minimal level.

## Final Response Required

List:

- files changed
- reminder scheduling flow
- permission behavior
- commands run and pass/fail
- remaining risks
