# Subtask 018 Progress: Project Insight Review

Status: implemented_verified_reviewed

## Todo

- [x] Define bounded PRD.
- [x] Prepare Claude Code delegation prompt.
- [x] Claude Code starts and updates this file.
- [x] Add failing tests.
- [x] Implement ProjectAIService insight method.
- [x] Implement AppStore insight generation and feedback.
- [x] Implement Project Detail insight UI.
- [x] Run targeted tests.
- [x] Codex review and verification.
- [x] Run full test suite.
- [x] Update delegation log.

## Progress Protocol For Claude Code

Claude Code must update this file at these checkpoints:

- Start: mark "Claude Code starts" with timestamp and planned file list.
- After RED tests: list failing test command and expected failure.
- After implementation: list changed files and design notes.
- After targeted verification: list exact command and result.
- Final handoff: summarize behavior, tests, and any unresolved risks.

## Notes

- Do not add migrations.
- Do not implement merge acceptance in this subtask.
- Do not let SwiftUI call GLM or repositories directly.
- Use existing design system and avoid placeholder/fake data.

## Progress Update - Start

**Timestamp:** 2025-06-02

**Planned files:**
1. `Sources/Services/ProjectAIService.swift` - Add `generateProjectInsights` method
2. `Sources/App/AppStore.swift` - Add insight generation/feedback/published state
3. `Sources/Features/Projects/ProjectDetailView.swift` - Add insight UI (needs verification)
4. Test files for service and AppStore

**Understanding:**
- `ProjectInsightRepository` already exists in `PersistenceCore.swift`
- `TodayAIResponseParser.parseProjectInsights` already exists
- `ProjectInsight` model exists with all required fields
- `PromptContextPayload.ProjectContext` already exists for project context
- Need to check if a specific prompt ID exists for project insights or use existing one

## Progress Update - Codex Takeover

**Timestamp:** 2026-06-02 03:57:28 CST

Claude Code started the task and produced partial code, but did not complete the required progress protocol or targeted verification. Codex treated the output as untrusted partial work and repaired it directly.

Root-cause findings:

- The initial sufficient-evidence AppStore test created confirmed `ProjectLink` rows but did not provide matching loaded `HistoryRecord` evidence, so AppStore correctly refused to build an evidence context.
- The mock AI response used random `project_id` values, so the new evidence guard correctly filtered every generated insight.
- The insufficient-evidence AppStore test omitted `ProjectLinkRepository`, so it only tested the local unavailable-data guard instead of the AI insufficient-evidence path.

Codex fixes:

- Updated the Project Insight prompt schema to match parser expectations: `project_insights`, `project_id`, `insight_type`, nested `before` / `after`, and `source_refs`.
- Added AppStore guards so generated insights are saved only when `projectId` matches the selected project and every `sourceRef` resolves to loaded confirmed project evidence.
- Added daily-entry support to project insight evidence context.
- Repaired AppStore tests to provide real project evidence through `historyRecords` and matching mock `project_id`.
- Added Project Detail UI for generating, reviewing, accepting, marking inaccurate, and dismissing project insights. SwiftUI still calls AppStore only; repositories and GLM remain behind the store/service boundary.

Verification:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/ProjectAIServiceContextTests -only-testing:MingSiTests/AppStoreStateMachineTests/testGenerateProjectInsights_withSufficientEvidence_savesCandidatesAndPublishesState -only-testing:MingSiTests/AppStoreStateMachineTests/testGenerateProjectInsights_withInsufficientEvidence_savesNoneAndShowsMessage -only-testing:MingSiTests/AppStoreStateMachineTests/testAcceptProjectInsight_updatesFeedbackToAcceptedAndKeepsVisible -only-testing:MingSiTests/AppStoreStateMachineTests/testMarkInaccurateProjectInsight_removesFromAcceptedNarrative -only-testing:MingSiTests/AppStoreStateMachineTests/testDismissProjectInsight_removesFromBothPendingAndAccepted test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/ProjectAIServiceContextTests -only-testing:MingSiTests/AppStoreStateMachineTests -only-testing:MingSiTests/TodayAIResponseParserTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Result:

- Targeted 018 tests passed: 10 tests, 0 failures.
- Related Project/AppStore/parser tests passed: 121 tests, 0 failures.
- Full suite passed: 222 tests, 0 failures.

## Progress Update - Review Fixes

**Timestamp:** 2026-06-02 04:06:37 CST

A read-only code review subagent found three valid gaps:

- `blocker_change` insights could be saved without before/after evidence even though the prompt contract treats them as change narratives.
- `blocker_change` before/after evidence was not rendered in Project Detail.
- AppStore tests did not lock rejection of wrong-project or unresolved-source model output.

Fixes:

- Parser now requires before/after evidence for both `thinking_change` and `blocker_change`.
- Persistence validation now rejects both `thinkingChange` and `blockerChange` without non-empty `beforeText` and `afterText`.
- Project Detail now renders before/after for both change insight types.
- Added AppStore regression coverage for wrong `project_id` and source refs outside confirmed evidence.

Verification:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIResponseParserTests/testParseProjectInsights_blockerChangeMissingBeforeOrAfter_skipsInvalidInsights -only-testing:MingSiTests/PersistenceCoreTests/testSaveProjectInsight_blockerChangeWithoutBeforeAfterThrowsValidation -only-testing:MingSiTests/AppStoreStateMachineTests/testGenerateProjectInsights_dropsWrongProjectAndUnresolvedSourceRefs test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/ProjectAIServiceContextTests -only-testing:MingSiTests/AppStoreStateMachineTests -only-testing:MingSiTests/TodayAIResponseParserTests -only-testing:MingSiTests/PersistenceCoreTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Result:

- New regression tests passed: 3 tests, 0 failures.
- Related suite passed: 174 tests, 0 failures.
- Full suite passed: 225 tests, 0 failures.
