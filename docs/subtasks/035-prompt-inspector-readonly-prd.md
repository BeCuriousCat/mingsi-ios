# Subtask 035 PRD: Prompt Inspector Read-Only View

Date: 2026-06-04

## Purpose

MingSi already records recent `PromptRun` audit rows in Settings, but the user still cannot inspect the first-party prompt templates that drive model calls. This weakens the MVP promise that AI behavior is visible, auditable, and not a black-box wrapper.

Add a restrained, read-only Prompt inspector in Settings.

## User Value

The alpha user can inspect:

- which Prompt IDs exist;
- which mode is being inspected: Quick / Standard / Deep;
- prompt version;
- output schema version;
- system text;
- user text;
- recent PromptRun metadata already recorded by the audit log.

This makes model behavior easier to reason about without exposing API keys or changing prompt strategy.

## Product Contract

- The inspector is read-only.
- It must not edit prompt text.
- It must not save prompt text to persistence.
- It must not expose the GLM API Key.
- It must not send any model request.
- It must not change PromptProvider, LLMClient, StreamingLLMClient, parser, Keychain, migration, or historical retry semantics.
- It may display first-party local template text from the current `PromptProvider` boundary.
- It may display existing `PromptRun.requestSummary`, `responseJSON`, `error`, ids, schema versions, source ref counts, and context ref counts.
- It must make clear that stored PromptRun rows contain audit summaries, not secret-bearing request payloads.

## Expected UX

In Settings, near the AI audit card:

- Add a collapsed card or section titled `Prompt 模板`.
- Provide a prompt picker for `PromptID.allCases`.
- Provide a mode picker for Quick / Standard / Deep.
- Show compact metadata:
  - prompt display name;
  - prompt id;
  - prompt version;
  - output schema version;
  - current mode.
- Show system text in a disclosure/collapsible block.
- Show user text in a disclosure/collapsible block.
- Use the existing `DS` visual language.
- Keep text selectable/copy-friendly if SwiftUI allows this without large complexity.
- Do not turn Settings into a long wall of text by default.

## Architecture Boundary

Preferred implementation:

- Add a small read-only helper in `AppStore` or a local Settings helper that obtains templates through `PromptProvider`.
- Settings may ask for a `PromptTemplate` or an immutable display summary, but it must not manually compose prompt text.
- `LocalPromptProvider` remains the current implementation source.

Do not:

- put prompt template literals in `FeatureTabs.swift`;
- add a new persistence table;
- add a migration;
- add remote prompt loading;
- add editable prompt overrides.

## Allowed Files

- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/Services/LocalPromptProviderTests.swift`
- `Tests/App/AppStoreStateMachineTests.swift` only if needed for a simple view-model/helper assertion
- `docs/subtasks/035-prompt-inspector-readonly-progress.md`

## Forbidden Files

- `Sources/Services/DirectGLMClient.swift`
- `Sources/Services/PersistenceCore.swift`
- Prompt parser files.
- Keychain code.
- Migration files.
- `docs/prompt-spec.md` unless Codex later decides a product-doc update is needed.

## Required Tests

Add or extend focused tests:

1. Every `PromptID` and every `SessionMode` returns a non-empty template with:
   - non-empty `systemText`;
   - non-empty `userText`;
   - non-empty version;
   - `outputSchemaVersion > 0`.
2. If a new display summary/helper is added, test that it exposes metadata without changing template text.

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/LocalPromptProviderTests test
```

If `AppStoreStateMachineTests` is touched, also run the focused new AppStore test.

## Acceptance Criteria

- Settings exposes a collapsed read-only Prompt inspector.
- Prompt and mode pickers work from local state.
- System/user prompt text is hidden by default but inspectable.
- No API key or user raw input is shown by this inspector.
- Existing Settings AI audit grouping remains intact.
- `LocalPromptProviderTests` pass.
- `git diff --check` passes.
- iPhone 17 simulator build passes after Codex acceptance.

## Manager Acceptance

Codex will accept only after:

- worker progress reaches `HANDOFF`;
- worker reports tests run;
- Codex reviews final diff against this PRD;
- Codex reruns targeted tests;
- Codex runs `git diff --check`;
- Codex runs an iPhone 17 simulator build if the UI diff is accepted.
