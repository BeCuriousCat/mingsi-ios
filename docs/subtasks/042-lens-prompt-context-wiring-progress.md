# Subtask 042 Progress: Lens Prompt Context Wiring

Status: CODEX_ACCEPTED
Timestamp: 2026-06-05

Owner: Codex manager
Delegated implementer: Claude Code

Required PRD: `docs/subtasks/042-lens-prompt-context-wiring-prd.md`
Required prompt: `docs/subtasks/042-lens-prompt-context-wiring-claude-prompt.md`
Expected event log: `docs/subtasks/logs/042-lens-prompt-context-wiring-events.jsonl`
Expected raw log: `docs/subtasks/logs/042-lens-prompt-context-wiring-claude-run.jsonl`

## Scope

- Service-layer prompt/context boundary for Today lens metadata.
- Allowed source files:
  - `Sources/Services/CoreProtocols.swift`
  - `Sources/Services/TodayAIService.swift`
  - `Tests/Services/TodayAIServiceContextTests.swift`
- Allowed documentation file:
  - `docs/subtasks/042-lens-prompt-context-wiring-progress.md`
- No SwiftUI, AppStore, persistence, migrations, PromptProvider text, parser, LLM transport, Keychain, History, Projects, Growth, Settings, assets, or screenshots edits.

## Checkpoints

Claude Code must update this file at exactly:

- `START`
- `RED`
- `IMPLEMENTED`
- `TARGETED_VERIFIED`
- `HANDOFF`

At `HANDOFF`, include exactly one final status token:

- `DONE`
- `DONE_WITH_CONCERNS`
- `NEEDS_CONTEXT`
- `BLOCKED`

## Manager Notes

- Codex consumes this progress file first.
- Raw/event flow logs are diagnostic only.
- Codex will not inspect or accept partial worker diffs before `HANDOFF`.
- This is not a prompt-strategy rewrite. It only wires existing catalog metadata into existing request/context structures.

## START

Timestamp: 2026-06-05T10:00

Planned source files:
- `Sources/Services/CoreProtocols.swift` — add lens catalog metadata to PromptContextPayload
- `Sources/Services/TodayAIService.swift` — wire prompt-facing lens id into LLMRequest and inputSummary
- `Tests/Services/TodayAIServiceContextTests.swift` — TDD tests for required behaviors

Assumptions:
- Subtask 039 already added `BuiltinLensCatalog`, `LensCatalogItem`, `ThinkingLens.catalogItem` in `Sources/Domain/Models.swift` (read-only use).
- `ThinkingLens` enum has cases including `.firstPrinciples` and `.leverageAnalysis` with `catalogItem` providing `promptId`, `version`, `title`, `methodLine`.
- Existing `PromptContextPayload` has a `selectedLens` field of type `ThinkingLens?`.
- `LLMRequest.jsonPayload` is a `[String: Any]` dictionary built during request assembly.
- Commit permission: **no** (prompt says "Do not commit.").

Non-goals carried forward: no SwiftUI, no persistence, no PromptProvider text, no parser, no LLM transport, no AppStore changes.

## RED

Timestamp: 2026-06-05T10:05

Tests added to `Tests/Services/TodayAIServiceContextTests.swift`:
- `testGenerateQuestions_sendsPromptFacingLensId_forFirstPrinciples` — asserts `jsonPayload["selectedLens"] == "first_principles"` for `.firstPrinciples`
- `testGenerateQuests_sendsPromptFacingLensId_forLeverageAnalysis` — asserts `jsonPayload["selectedLens"] == "leverage_analysis"` for `.leverageAnalysis`
- `testStructuredContext_exposesLocalSelectedLens_forFirstPrinciples` — asserts `payload.selectedLens == .firstPrinciples` still works
- `testStructuredContext_exposesLensCatalogMetadata_forFirstPrinciples` — asserts catalog metadata with localId, promptId, version, title

Updated existing test:
- `testStructuredContextPayload_keepsLegacyJSONPayloadForDirectGLMCompatibility` — changed `selectedLens` assertion from `rawValue` (`evidenceCheck`) to prompt-facing id (`evidence_check`)

Expected failure: all 5 tests will fail because `jsonPayload["selectedLens"]` currently uses `rawValue` and `lensCatalog` does not exist on `UserChoice`.

## IMPLEMENTED

Timestamp: 2026-06-05T10:10

Changed files:
- `Sources/Services/CoreProtocols.swift` — added `LensCatalogContext` struct; added `lensCatalog` field to `UserChoice`; updated `legacyKeyValues` to use prompt-facing id from catalog
- `Sources/Services/TodayAIService.swift` — updated `generateQuestions`/`generateQuests` payloads to use `catalogItem.promptId`; updated `inputSummary` to use prompt-facing id; wired `LensCatalogContext` in `structuredPayload`
- `Tests/Services/TodayAIServiceContextTests.swift` — added 4 new tests; updated 1 existing assertion for prompt-facing id

## TARGETED_VERIFIED

Timestamp: 2026-06-05T10:22

xcodebuild blocked by known GRDB package resolution error:
```
xcodebuild: error: Could not resolve package dependencies:
  invalid custom path 'Tests' for target 'GRDBTests'
```

`git diff --check`: passed (no output, clean).

Diff stats: 3 files changed, 115 insertions(+), 6 deletions(-).

All changes within allowed write set.

## HANDOFF

Status: DONE_WITH_CONCERNS

Changed files:
- `Sources/Services/CoreProtocols.swift`
- `Sources/Services/TodayAIService.swift`
- `Tests/Services/TodayAIServiceContextTests.swift`

Implementation summary:
1. Added `PromptContextPayload.LensCatalogContext` struct with `localId`, `promptId`, `version`, `title`, `methodLine`.
2. Added `lensCatalog: LensCatalogContext?` to `PromptContextPayload.UserChoice`.
3. Updated `legacyKeyValues` to emit prompt-facing id (`lensCatalog.promptId`) in `selectedLens` key, with fallback to raw local id.
4. Updated `generateQuestions` and `generateQuests` payloads to use `catalogItem.promptId`.
5. Updated `inputSummary` to use prompt-facing id.
6. Wired `LensCatalogContext` from `ThinkingLens.catalogItem` in `structuredPayload`.
7. `PromptContextPayload.selectedLens` still resolves to `ThinkingLens` via `userChoice.selectedLens` (local id preserved).

Tests:
- `testGenerateQuestions_sendsPromptFacingLensId_forFirstPrinciples` — `jsonPayload["selectedLens"] == "first_principles"`
- `testGenerateQuests_sendsPromptFacingLensId_forLeverageAnalysis` — `jsonPayload["selectedLens"] == "leverage_analysis"`
- `testStructuredContext_exposesLocalSelectedLens_forFirstPrinciples` — `payload.selectedLens == .firstPrinciples`
- `testStructuredContext_exposesLensCatalogMetadata_forFirstPrinciples` — catalog metadata assertions
- Updated `testStructuredContextPayload_keepsLegacyJSONPayloadForDirectGLMCompatibility` — expects `"evidence_check"` instead of rawValue

Verification:
- `xcodebuild -only-testing:MingSiTests/TodayAIServiceContextTests`: BLOCKED by GRDB package resolution (`invalid custom path 'Tests' for target 'GRDBTests'`)
- `git diff --check`: PASSED (clean)

Handoff notes:
- xcodebuild cannot run in worker worktree due to GRDB package resolution issue. Codex must rerun targeted tests on merge.
- No prompt text, persistence, parser, LLM transport, AppStore, or UI changes introduced.

## Codex Acceptance

Codex accepted:

- The service-layer request/context boundary change.
- Model-facing `selectedLens` now uses catalog prompt ids such as `first_principles`, `leverage_analysis`, and `evidence_check`.
- Local persisted lens identity remains `ThinkingLens.rawValue` through `PromptContextPayload.UserChoice.selectedLens`.
- Structured context now exposes selected lens catalog metadata for audit/debugging without SwiftUI styling fields.

Codex did not accept or add:

- Prompt text changes.
- Parser changes.
- Persistence or migration changes.
- LLM transport changes.
- AppStore orchestration changes.
- SwiftUI / History / Projects / Growth / Settings changes.

Codex verification in the main checkout:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

- `TodayAIServiceContextTests` passed: 16 tests, 0 failures.
- `git diff --check` passed.
- iPhone 17 simulator build passed.

Manager note:

- `scripts/claude_delegate.sh status` briefly showed only `START/RED` even after the worker had written `HANDOFF`; the Stop hook/raw result confirmed `DONE_WITH_CONCERNS`. This should be tracked as a delegation-wrapper follow-up, but it did not affect acceptance because Codex verified the progress file and reran tests in the main checkout.
