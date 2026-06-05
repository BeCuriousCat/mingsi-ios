# Subtask 047 Progress: First Principles Lens Prompt Guidance

Status: CODEX_ACCEPTED
Timestamp: 2026-06-05

Owner: Codex manager
Delegated implementer: none

## Scope

- Keep `第一性原理` as an MVP built-in lens under the extensible lens library boundary.
- Add library-owned prompt guidance so lens behavior is not hard-coded in SwiftUI or prompt call sites.
- Wire the guidance through `PromptContextPayload` and legacy JSON payloads used by GLM-compatible calls.
- Add regression coverage for the Domain catalog item and Today AI request payload.

## Delegation Decision

- Claude Code was not delegated for this slice.
- Reason: the write set is small, the main decision is product/architecture semantics, and the local worker-launch pipeline had a recent unresolved 046 process blocker.
- Codex used the `claude-code-managed-delegation` skill as a readiness gate and chose direct implementation.

## Implementation

Changed files:

- `Sources/Domain/Models.swift`
- `Sources/Services/CoreProtocols.swift`
- `Sources/Services/TodayAIService.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Tests/Services/TodayAIServiceContextTests.swift`

Summary:

- Added `LensCatalogItem.promptGuidance`.
- Added first-party guidance for all built-in lenses, including `firstPrinciples`.
- Added `PromptContextPayload.LensCatalogContext.promptGuidance`.
- Added legacy payload keys:
  - `lensTitle`
  - `lensMethodLine`
  - `lensPromptGuidance`
- `DefaultContextAssembler` now reads guidance from `ThinkingLens.catalogItem`.
- Added tests proving First Principles guidance comes from the catalog and reaches `generateQuestions` requests.

## Verification

Codex ran:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests -only-testing:MingSiTests/AppStoreStateMachineTests/testFirstPrinciples_metadata test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

- Passed: 18 tests, 0 failures.
- `git diff --check` passed.
- iPhone 17 simulator build passed.

## Acceptance

Codex accepts this slice because:

- `第一性原理` remains normal built-in catalog data with local id `firstPrinciples` and prompt id `first_principles`.
- The reusable library boundary now carries both display metadata and prompt behavior metadata.
- Request assembly consumes the library through `ThinkingLens.catalogItem`, without adding lens-specific switch branches.
- No persistence, migration, PromptProvider text, LLM transport, parser, AppStore orchestration, Keychain, History, Projects, Growth, or Settings behavior changed.
