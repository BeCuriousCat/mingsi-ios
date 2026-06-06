# Subtask 064 Progress: Today Debug Stage Seed

Status: CODEX_ACCEPTED

Owner: Codex manager
Delegated implementer: not delegated

PRD: `docs/subtasks/064-today-debug-stage-seed-prd.md`
Claude prompt: none
Event log: none
Raw log: none

## Manager Setup

- Timestamp: 2026-06-06
- Source state: Subtask 063 committed in `618e63c Record today post-card walkthrough blocker`.
- Reason: Subtask 063 proved ReviewCards is reachable but rendered card confirmation cannot be reliably driven through host Simulator automation.
- Implementation path: direct Codex TDD implementation and simulator verification.

## Planned Verification

Commands:

```bash
git status --short
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_selectLensSeedsConfirmedFallbackCards -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_withoutInputDoesNothing -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_readsSimctlChildStage -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_answerQuestionsSeedsLensQuestions -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_reviewQuestsSeedsAnsweredQuestionsAndQuests -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_extractPrincipleSeedsQuestsAndPrinciple test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Checkpoints

- RED: focused 064 tests fail because stage seed currently leaves Today at `capture`
- IMPLEMENTED: `AppStore.applyVisualQATodaySeed` now supports Debug-only stage seeding through existing local fallback helpers
- TARGETED_VERIFIED: focused 064 tests and full `AppStoreStateMachineTests` passed
- SCREENSHOT_VERIFIED: real iPhone 17 simulator screenshots captured for SelectLens, AnswerQuestions, ReviewQuests, and ExtractPrinciple
- CODEX_ACCEPTED: accepted by Codex after tests, Debug/Release builds, diff check, and screenshot review

## Notes

- No Claude Code worker is launched for this slice.
- Stage seed must remain Debug-only and must not alter Release launch behavior.

## RED Evidence

Command:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_selectLensSeedsConfirmedFallbackCards -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_withoutInputDoesNothing -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_readsSimctlChildStage -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_answerQuestionsSeedsLensQuestions -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_reviewQuestsSeedsAnsweredQuestionsAndQuests -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_extractPrincipleSeedsQuestsAndPrinciple test
```

Result:

- 6 tests executed.
- 1 passed: stage without input does nothing.
- 5 failed because `applyVisualQATodaySeed` kept `todayDraft.state == .capture`, with no seeded cards/questions/quests/principle.
- This is the expected RED state before implementation.

## Implementation

- Added Debug-only `VisualQATodayStage` and `resolveVisualQATodayStage`.
- `MINGSI_VISUAL_QA_TODAY_STAGE` / `SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_STAGE` now accept:
  - `capture`
  - `review_cards`
  - `review_cards_confirmed`
  - `select_lens`
  - `answer_questions`
  - `review_quests`
  - `extract_principle`
- Stage seed is effective only when a non-empty Today seed input exists.
- Later stages reuse the existing local fallback generation helpers:
  - `generateLocalCards`
  - `generateLocalQuestions`
  - `generateLocalQuests`
  - `generateLocalPrinciple`
- The visible Today message says this is Debug visual verification using local fallback and is not recorded as AI success.
- No `MingSiApp` wiring change was needed because Subtask 062 already calls `applyVisualQATodaySeed()` in Debug launch paths.

## Verification

Commands:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_selectLensSeedsConfirmedFallbackCards -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_withoutInputDoesNothing -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_readsSimctlChildStage -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_answerQuestionsSeedsLensQuestions -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_reviewQuestsSeedsAnsweredQuestionsAndQuests -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_extractPrincipleSeedsQuestsAndPrinciple test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project MingSi.xcodeproj -scheme MingSi -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl uninstall booted com.codex.mingsi
xcrun simctl install booted /Users/chenzewei/Library/Developer/Xcode/DerivedData/MingSi-erjzdsaapaoobtcrmiwnfyqrwdqr/Build/Products/Debug-iphonesimulator/MingSi.app
SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_INPUT='今天要把会议目标拆成一个可以明天验证的行动，并沉淀一个可复用原则。' SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_MODE=standard SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_STAGE=<stage> SIMCTL_CHILD_MINGSI_VISUAL_QA_TAB=today xcrun simctl launch --terminate-running-process booted com.codex.mingsi
xcrun simctl io booted screenshot docs/subtasks/screenshots/064-today-debug-stage-seed/<stage>.png
```

Results:

- Focused 064 tests: 6 tests, 0 failures.
- Full `AppStoreStateMachineTests`: 172 tests, 0 failures.
- `git diff --check`: passed.
- Debug iPhone 17 simulator build: `BUILD SUCCEEDED`.
- Release iPhone 17 simulator build: `BUILD SUCCEEDED`.
- Real iPhone 17 simulator screenshots show seeded:
  - `select_lens`
  - `answer_questions`
  - `review_quests`
  - `extract_principle`

## Screenshot Evidence

- `docs/subtasks/screenshots/064-today-debug-stage-seed/select_lens.png`
- `docs/subtasks/screenshots/064-today-debug-stage-seed/answer_questions.png`
- `docs/subtasks/screenshots/064-today-debug-stage-seed/review_quests.png`
- `docs/subtasks/screenshots/064-today-debug-stage-seed/extract_principle.png`

## Residual Risk

- This is a Debug-only rendered walkthrough accelerator. It does not prove live GLM success.
- It does not persist a completed History/Projects/Growth evidence chain by itself.
- The next product verification step should use this harness to capture/operate the later Today states and then continue toward full History evidence archival.
