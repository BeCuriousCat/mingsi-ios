# Claude Code Task Prompt: Subtask 014 Project AI Candidate Review

You are implementing a bounded SwiftUI/iOS MVP slice in the local repo.

## Required Protocol

- Read `docs/subtasks/014-project-ai-candidate-review-prd.md` first.
- Update `docs/subtasks/014-project-ai-candidate-review-claude-progress.md` at task start and after each checklist step.
- Follow TDD for behavior changes: write failing tests first, then implement the minimum code needed.
- Keep changes scoped to Subtask 014.
- Do not auto-create Projects from AI output. User acceptance is required.
- Do not redesign the whole app. UI changes must be minimal, tasteful, and consistent with the current warm paper / graphite design.
- Do not touch Growth implementation unless required for compile compatibility.

## Implementation Target

Build the minimal Project AI candidate review flow:

1. Add a Project suggestion prompt boundary.
   - Add a new `PromptID`, e.g. `suggestProjectLinks`.
   - Add `LocalPromptProvider` template based on `docs/prompt-spec.md` Prompt 7.
   - Use existing `TodayAIResponseParser.parseProjectSuggestions(from:)`.

2. Add service boundary.
   - Add `ProjectAIService` or equivalent.
   - Use `PromptProvider` and `LLMClient`.
   - Build typed project context from confirmed daily evidence, existing active projects, and existing links.
   - Send typed `PromptContextPayload.project` or equivalent typed section plus legacy compatibility keys.

3. Wire AppStore.
   - Add `ProjectCandidateRepository` to live/init.
   - Add published review state for project link candidates and new project candidates.
   - Add intent methods for generating suggestions, accepting/dismissing ProjectCandidate, and accepting/dismissing ProjectLinkCandidate.
   - Accepting a ProjectCandidate creates a Project and confirmed ProjectLink from source evidence, then updates candidate status.
   - Accepting a ProjectLinkCandidate creates a confirmed ProjectLink to an existing Project.

4. Add minimal UI.
   - Projects tab should expose pending candidate review when pending candidates exist.
   - Today should expose a restrained “建议长期议题” action when there is enough confirmed evidence.
   - Candidate UI must show name/reason/source/confidence and accept/dismiss controls.

5. Tests.
   - Add service/context test for typed Project context and source ids.
   - Add AppStore tests for persist suggestions, accept new candidate, dismiss candidate, accept existing link candidate.
   - Run targeted tests and full suite.

## Verification

Run at least:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Record exact results in the progress file.

## Final Response Contract

When finished, report:

- Status: DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
- Changed files
- Tests run and exact result
- Any concerns or intentionally deferred items
