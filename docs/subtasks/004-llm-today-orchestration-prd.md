# Subtask 004: LLM Today Orchestration PRD

## Owner

Worker agent: Today LLM orchestration.

## Context

The app now has:

- state-aware Today loop
- `LocalPromptProvider`
- `DirectGLMClient`
- `MockLLMClient`
- persistence wiring

The next goal is to route Today generation steps through a use-case layer that can use GLM when available and deterministic mock/local fallback when unavailable.

## Scope

Allowed write scope:

- `Sources/App/AppStore.swift`
- new files under `Sources/Services/` for response parsing/use-case orchestration
- new files under `Sources/Domain/` for response DTO/domain mapping if needed

Do not edit:

- `Sources/Features/Today/TodayView.swift`
- `Sources/Features/FeatureTabs.swift`
- `Sources/Services/PersistenceCore.swift`
- `Sources/Services/DirectGLMClient.swift` except tiny compatibility fixes
- `Vendor/GRDB.swift`

## Requirements

1. Introduce a small Today AI orchestration boundary, for example `TodayAIService` or `DailyLoopAIService`.
2. It must depend on `PromptProvider` and `LLMClient`, not on SwiftUI or GRDB.
3. Support at least these operations:
   - organize cards
   - generate questions
   - generate quests
   - extract principle
4. Parse `MockLLMClient` JSON into domain models.
5. In `AppStore`, generation should try the injected AI service first and fall back to existing deterministic local generation if parsing/network fails.
6. `AppStore.live()` should create:
   - `DirectGLMClient` only when a Keychain API Key exists
   - otherwise `MockLLMClient`
7. The UI must continue to complete a full loop without a real API Key.
8. Do not put prompt text or GLM DTOs in `AppStore`.
9. Any model-output parsing should be defensive: unknown enum values should not crash the full loop.

## Architecture Constraints

- The orchestration service is allowed to return domain models, not UI view models.
- `PromptProvider` remains swappable for future remote prompt migration.
- `LLMClient` remains swappable for future proxy/server migration.
- Persistence remains outside the AI service.

## Acceptance Criteria

- Build succeeds.
- With no API Key, Today loop still works via mock data.
- With an API Key present, `AppStore.live()` attempts to use `DirectGLMClient`.
- If GLM returns malformed JSON or network fails, the user sees a concise message and local fallback data is used.
- No SwiftUI view imports or calls `LLMClient`, `PromptProvider`, or GLM DTOs.

## Final Response Required

List:

- files changed
- AI orchestration shape
- fallback behavior
- commands run and pass/fail
- remaining risks
