# Subtask 042 PRD: Lens Prompt Context Wiring

Date: 2026-06-05

## Goal

Wire the built-in lens catalog into the AI prompt/context boundary so selecting `第一性原理` and other lenses affects model-facing request payloads through catalog metadata, not only local UI labels.

Subtask 039 added a lightweight `BuiltinLensCatalog` with durable local ids, prompt-facing ids, version, display copy, method guidance, and symbols. This slice must use that existing catalog boundary when assembling `LLMRequest` data for Today prompt calls.

## Product Principle

A thinking lens is a method asset. The app should keep two identities separate:

- durable local id: `ThinkingLens.rawValue`, used for persistence and local filters;
- prompt-facing id: `LensCatalogItem.promptId`, used when asking the model to generate lens-specific questions or quests.

The model should receive stable snake_case lens ids such as `first_principles`, not Swift/local persisted ids such as `firstPrinciples`.

## Scope

Allowed source files:

- `Sources/Services/CoreProtocols.swift`
- `Sources/Services/TodayAIService.swift`
- `Tests/Services/TodayAIServiceContextTests.swift`

Allowed documentation file:

- `docs/subtasks/042-lens-prompt-context-wiring-progress.md`

Do not edit:

- SwiftUI views
- AppStore orchestration
- Domain lens catalog definitions except by read-only use
- Persistence / migrations / GRDB repositories
- PromptProvider or prompt text
- Parser
- LLM transport clients
- Keychain
- History / Projects / Growth / Settings feature files
- Test fixtures outside the allowed test file

## Required Behavior

1. Keep local persisted ids stable:
   - `ThinkingLens.rawValue` must remain the durable local id.
   - `PromptContextPayload.selectedLens` compatibility should still resolve back to `ThinkingLens` for existing internal callers/tests.

2. Send prompt-facing lens ids to the model:
   - `LLMRequest.jsonPayload["selectedLens"]` should use `context.draft.selectedLens?.catalogItem.promptId`.
   - `inputSummary` lens field should use the prompt-facing id for audit readability.
   - This applies at minimum to `generateQuestions` and `generateQuests`.

3. Expose lens catalog metadata in structured context:
   - Add a small structured lens context under `PromptContextPayload.UserChoice` or an equivalent nearby structured location.
   - It should include enough metadata for audit/debugging without coupling to SwiftUI:
     - local id;
     - prompt-facing id;
     - version;
     - title;
     - method line.
   - Do not include color/tint or other SwiftUI-only styling.

4. Preserve compatibility:
   - Existing code that reads `PromptContextPayload.selectedLens` should still work.
   - Existing persistence and history lens filters must not change.
   - Existing prompt text can continue saying `selectedLens`; the request payload decides which id is supplied.

## Tests

Use focused tests in `Tests/Services/TodayAIServiceContextTests.swift`.

Required coverage:

- `generateQuestions` with `.firstPrinciples` sends `selectedLens == "first_principles"` in `jsonPayload`.
- Structured context still exposes local selected lens in a way that `payload.selectedLens == .firstPrinciples` passes.
- Structured context exposes lens catalog metadata with:
  - local id `firstPrinciples`;
  - prompt id `first_principles`;
  - version `builtin.v1`;
  - title `第一性原理`.
- `generateQuests` with `.leverageAnalysis` sends `selectedLens == "leverage_analysis"` in `jsonPayload`.
- Existing local raw value tests should be updated only where they are explicitly testing model-facing payload behavior.

## Non-Goals

- No new lens UI.
- No custom lens editor.
- No remote lens catalog.
- No prompt text rewrite.
- No parser changes.
- No model recommendation parser changes.
- No persistence migration.
- No AppStore state-machine changes.
- No changes to historical lens records.
- No fake data.

## Verification

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests test
git diff --check
```

If worker worktree `xcodebuild` is blocked by the known GRDB package resolution issue, report `DONE_WITH_CONCERNS` with the exact error and still run `git diff --check`.

## Handoff Criteria

Handoff is acceptable only when:

- Progress file reaches `HANDOFF`.
- Changed files stay inside the allowed write set.
- Required tests exist.
- Worker verification is run or the exact worker infrastructure blocker is recorded.
- No prompt strategy, persistence, parser, LLM transport, AppStore, or UI changes are introduced.
