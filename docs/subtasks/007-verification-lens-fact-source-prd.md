# Subtask 007: Verification And Lens Fact Source PRD

## Goal

Make yesterday verification and lens questions durable evidence, not transient `DailyEntryDraft` fields.

This is the foundation for Growth attribution and History drilldown.

## Write Scope

- `Sources/Domain/Models.swift`
- `Sources/Services/PersistenceCore.swift`
- `Sources/App/AppStore.swift`
- `Sources/Services/TodayAIService.swift`
- `Sources/Services/TodayAIResponseParser.swift`
- `Sources/Features/Today/TodayView.swift` only if needed for small wiring

Do not edit Projects/Growth UI in this subtask.

## Requirements

- Add `Verification` domain model.
- Add `LensSession` persistence if the model already exists, otherwise add it.
- Persist `ReflectionQuestion` and answers.
- Add GRDB migrations and repository methods.
- On app launch, decide VerifyYesterday from the last active main quest, not preview data.
- `saveYesterdayVerification` must create a quest-linked `Verification`.
- If GLM verify prompt is available, store calibration note; if not, store local fallback note.
- History loading must be able to include verification and lens evidence.

## Acceptance Criteria

- A completed main quest can be verified the next day and saved as a `Verification`.
- Restarting the app does not lose selected lens, questions, answers, or verification.
- No preview quest is treated as real user evidence.
- Build succeeds.
