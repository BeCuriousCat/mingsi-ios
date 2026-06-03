# Subtask 019 Progress: Project Merge Review

Status: implemented_verified_reviewed

## Todo

- [x] Define bounded PRD.
- [x] Prepare Claude Code delegation prompt.
- [x] Claude Code starts and updates this file.
- [x] Add failing tests.
- [x] Implement ProjectAIService merge method.
- [x] Implement AppStore merge generation and feedback.
- [x] Implement Projects UI merge review section.
- [x] Run targeted tests.
- [x] Codex review and verification.
- [x] Run full test suite.
- [x] Update delegation log.

## Start Checkpoint (2026-06-02)

Planned file changes:
1. Sources/Services/CoreProtocols.swift - add PromptID.suggestProjectMerges
2. Sources/Services/LocalPromptProvider.swift - add prompt template
3. Sources/Services/ProjectAIService.swift - add suggestProjectMerges method
4. Sources/App/AppStore.swift - inject repository, add state and actions
5. Sources/Features/Projects/ProjectsView.swift - add merge review section
6. Tests/Services/ProjectAIServiceContextTests.swift - add context test
7. Tests/App/AppStoreStateMachineTests.swift - add merge behavior tests
8. docs/agent-delegation-log.md - update with completion status

## RED Tests Checkpoint

Failing tests added to:
- Tests/Services/ProjectAIServiceContextTests.swift
  - testSuggestProjectMerges_sendsTypedProjectContextWithSourceAndContextRefs
  - testSuggestProjectMerges_responseContainsCandidatesWithSourceRefs

- Tests/App/AppStoreStateMachineTests.swift
  - Added InMemoryProjectMergeCandidateRepository
  - testSuggestProjectMerges_generatesCandidatesAndUpdatesState
  - testSuggestProjectMerges_dropsInvalidCandidatesWithUnknownProjectIds
  - testSuggestProjectMerges_dropsInvalidCandidatesWithUnresolvedEvidenceRefs
  - testAcceptProjectMergeCandidate_archivesSourceAndUpdatesTargetMergeHistory
  - testRejectProjectMergeCandidate_doesNotAlterProjects
  - testDismissProjectMergeCandidate_doesNotAlterProjects

Expected failures: Tests will fail because:
- PromptID.suggestProjectMerges case does not exist
- ProjectMergeSuggestionContext struct does not exist
- ProjectAIService.suggestProjectMerges method does not exist
- AppStore merge properties and methods do not exist
- CapturingProjectLLMClient needs to support project merge responses

Next: Implement production code to pass tests (GREEN phase).

## Progress Update - Codex Takeover And Review

**Timestamp:** 2026-06-02 04:26 CST

Claude Code reached RED tests and partial implementation, but Codex stopped it because the diff was broad and the implementation was not verified. Codex reviewed the partial output, repaired it, and completed the slice directly.

Root-cause fixes:

- Added missing `PromptID.suggestProjectMerges` handling in `TodayAIService.basePayload`.
- Repaired tests that compared UUID fields to strings and referenced a private test helper across files.
- Changed `AppStore.suggestProjectMerges` to accept an injected `ProjectAIService?`; injected services no longer require Keychain API state, preserving testability and future server migration.
- Added Projects UI merge review section in the current `FeatureTabs.swift` structure instead of a nonexistent separate Projects file.
- Added loading of pending merge candidates on app load and Projects tab load.
- Updated AppStore in-memory `projectsById`/`projectNames` after accepting a merge so UI state matches persistence.

Implemented behavior:

- `ProjectAIService.suggestProjectMerges(context:)` builds source refs, project context refs, prompt payload, and parses strict merge candidates.
- `AppStore` saves generated candidates only when source/target projects are active and all overlap refs belong to confirmed links.
- Accepting a candidate archives the source project, preserves the target project, appends a readable merge audit line to `mergeHistory`, marks the candidate accepted, and refreshes pending UI state.
- Rejecting and dismissing only update candidate status and leave projects unchanged.
- Projects tab shows a compact evidence-backed “议题治理” section with generate, accept, reject, and dismiss actions.

Verification:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/ProjectAIServiceContextTests -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/ProjectAIServiceContextTests -only-testing:MingSiTests/AppStoreStateMachineTests -only-testing:MingSiTests/TodayAIResponseParserTests -only-testing:MingSiTests/PersistenceCoreTests test
```

Result:

- Targeted AppStore + ProjectAIService suite passed: 88 tests, 0 failures.
- Related AppStore / ProjectAIService / Parser / Persistence suite passed: 182 tests, 0 failures.
- Full suite passed: 233 tests, 0 failures.

## Progress Protocol For Claude Code

Claude Code must update this file at these checkpoints:

- Start: mark "Claude Code starts" with timestamp and planned file list.
- After RED tests: list failing test command and expected failure.
- After implementation: list changed files and design notes.
- After targeted verification: list exact command and result.
- Final handoff: summarize behavior, tests, and unresolved risks.

## Notes

- Do not add migrations.
- Do not let SwiftUI call GLM or repositories directly.
- Do not move ProjectLink rows during merge in this slice.
- Do not hard-delete projects or merge candidates.
- Use existing design system and keep Projects evidence-backed.
