# Subtask 035 Progress: Prompt Inspector Read-Only View

Status: CODEX_ACCEPTED
Final status token: DONE

Owner: Codex manager
Delegated implementer: Claude Code

Required PRD: `docs/subtasks/035-prompt-inspector-readonly-prd.md`
Required prompt: `docs/subtasks/035-prompt-inspector-readonly-claude-prompt.md`

## Scope

- Add a read-only Prompt inspector in Settings.
- Preserve PromptProvider / LLM / persistence boundaries.
- Do not change prompt strategy, prompt text, parser behavior, Keychain, migrations, or retry semantics.

## Checkpoints

### START

- Timestamp: 2026-06-04
- Planned files:
  - `Tests/Services/LocalPromptProviderTests.swift`
  - `Sources/Features/FeatureTabs.swift`
- Worker assumption:
  - `LocalPromptProvider()` is stateless and can be instantiated directly in `SettingsView`.
  - `PromptID.allCases` and `SessionMode.allCases` provide picker options.
  - Existing `DS` tokens and `cardSurface()` match Settings visual language.

### RED

- Command: `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/LocalPromptProviderTests/testEveryPromptID_everySessionMode_returnsNonEmptyTemplate test`
- Result: test succeeded.
- Interpretation:
  - The new inventory test passed immediately because `LocalPromptProvider` already returns non-empty templates for every prompt/mode pair.
  - RED was accepted as a gap-confirmation step: template inventory was covered before UI implementation, and the missing behavior was the Settings inspector.

### IMPLEMENTED

- Worker changed:
  - `Tests/Services/LocalPromptProviderTests.swift`
    - Added `testEveryPromptID_everySessionMode_returnsNonEmptyTemplate`.
  - `Sources/Features/FeatureTabs.swift`
    - Added a collapsed read-only `Prompt 模板` Settings card.
    - Added prompt and mode pickers.
    - Added metadata display for display name, raw id, version, output schema version, and mode.
    - Added collapsible System Text and User Text blocks with selectable text.
    - Kept the view read-only and did not expose API keys or raw user input.

### TARGETED_VERIFIED

- Worker-reported verification:
  - `xcodebuild ... -only-testing:MingSiTests/LocalPromptProviderTests test`: passed, 7 tests, 0 failures.
  - `git diff --check`: clean.
  - iPhone 17 simulator build: succeeded.

### HANDOFF

Status: DONE

Worker changed files:

- `Sources/Features/FeatureTabs.swift`
- `Tests/Services/LocalPromptProviderTests.swift`

Worker handoff notes:

- `Prompt 模板` appears below the AI audit card.
- The card is collapsed by default; System Text and User Text are separately collapsed inside it.
- No model request is sent by the inspector.
- The worker created an empty `Vendor/GRDB.swift/Tests/` directory inside the worker worktree only to unblock package resolution there.

## Codex Acceptance

Decision: accepted with manager fix.

Accepted:

- The Settings UI direction.
- The local picker state and collapsed-by-default behavior.
- The template inventory regression test.
- The read-only/no-request/no-secret contract.

Manager fix:

- Rejected direct `LocalPromptProvider()` construction inside `SettingsView` as a boundary leak.
- Added `PromptProvider` dependency storage in `AppStore`.
- Added `AppStore.promptTemplate(for:mode:)` so Settings reads templates through the app boundary instead of owning provider construction.

Codex changed files after worker handoff:

- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/Services/LocalPromptProviderTests.swift`

Verification to complete before commit:

- `git diff --check`
- `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/LocalPromptProviderTests test`
- `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build`

## Manager Notes

- Codex consumes this progress file first.
- Event/raw flow logs live under `docs/subtasks/logs/035-prompt-inspector-readonly-*`.
- Raw/event logs should be opened only if progress stalls, handoff is missing, or acceptance fails.
- No partial worker diff was accepted before `HANDOFF`.

## Expected Worker Verification

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/LocalPromptProviderTests test
git diff --check
```

If AppStore tests are modified, the worker must also run the touched focused AppStore test.
