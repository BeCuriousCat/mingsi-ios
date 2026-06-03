# Subtask 027: History Repair UI For Historical OrganizeCards Retry

Date: 2026-06-03

Owner: Codex manager

## Goal

Expose the historical `organizeCards` retry capability inside History day detail without changing persistence schema, prompt strategy, or AppStore retry semantics.

The user should be able to open a History day with an unresolved card-organization failure, see why it failed, generate candidate cards, review candidate status, and dismiss or attempt acceptance through existing AppStore actions.

## Source Documents

- `docs/mvp-current-goal.md`
- `docs/mvp-stage-progress.md`
- `docs/subtasks/026-historical-ai-retry-candidate-review-prd.md`
- `docs/agent-delegation-log.md`

## Fixed Product Contract

History is an evidence archive. Historical repair UI must present repair output as a candidate, not as confirmed truth.

The UI must distinguish:

- repairable `organizeCards` failures;
- unsupported failures that remain audit-visible but action-disabled;
- retrying / candidate ready / accepted / dismissed / blocked / failed candidate states.

## In Scope

- Update History day detail repair section in `Sources/Features/FeatureTabs.swift`.
- Add a small read-only AppStore query if needed:
  - `historicalRetryCandidates(for dailyEntryId: UUID) async -> [HistoricalRetryCandidate]`
- Add local UI decoding of `HistoricalRetryCandidate.candidatePayloadJSON` for candidate card preview.
- Add History feature tests for local formatting/view-model helpers where possible.
- Keep View calls behind AppStore. SwiftUI must not import GRDB or call `LLMClient`.

## Out Of Scope

- No schema or migration changes.
- No direct repository access from SwiftUI views.
- No prompt or context-engineering changes.
- No GLM protocol changes.
- No new retry prompts beyond `organizeCards`.
- No automatic overwrite of confirmed evidence.
- No broad visual redesign of History.
- No complex animations.

## Required UI Behavior

### History Repair Section

For a visible History day:

1. Load unresolved failures with existing `store.repairablePromptRuns(for:)`.
2. Load candidates with the fixed AppStore query.
3. Show a section titled `历史 AI 修复`.
4. If loading, show a small progress row.
5. If there are no repairable runs and no candidates, hide the section.
6. For `organizeCards` unresolved failures, show:
   - prompt display name;
   - error summary;
   - created time;
   - action: `生成候选卡片`.
7. The action calls `await store.startHistoricalOrganizeCardsRetry(failedPromptRunId:)`, then reloads repair runs and candidates.
8. Unsupported prompt failures are visible but disabled with copy equivalent to: `暂不支持此类历史修复`.

### Candidate Preview

For each candidate:

1. Show status label:
   - `retrying`: `生成中`
   - `candidate_ready`: `候选已生成`
   - `accepted`: `已接受`
   - `dismissed`: `已忽略`
   - `blocked`: `已阻断`
   - `failed`: `重试失败`
   - `pending`: `待处理`
2. Show `reconstructedInputSummary`.
3. If `candidatePayloadJSON` contains cards, show compact candidate card previews:
   - type;
   - title;
   - body;
   - priority;
   - sensitivity.
4. Candidate cards must look like review objects, not confirmed facts.
5. If status is `candidateReady`, show:
   - `接受候选`;
   - `忽略本次结果`.
6. `接受候选` calls `await store.acceptHistoricalRetryCandidate(candidate.id)`, then reloads candidates.
7. `忽略本次结果` calls `await store.dismissHistoricalRetryCandidate(candidate.id)`, then reloads candidates.
8. If the visible record already has confirmed cards or downstream evidence, the UI should warn that acceptance may be blocked. Do not hide the candidate preview.

## Visual Requirements

- Calm evidence style consistent with current History.
- Warm paper / ink / graphite / green tone via existing `DS` tokens.
- Avoid AI purple, neon blue, and centered oversized card walls.
- Preserve tab safe area.
- Dark mode must remain readable.
- Use compact rows and small chips rather than full-screen result panels.

## Acceptance Tests

The worker should add tests where local helpers are extracted. Minimum expected test coverage:

- Decoding candidate payload JSON returns card preview rows with title/type/body.
- Invalid candidate payload JSON produces no preview cards and does not crash.
- Status label mapping covers `candidateReady`, `blocked`, `failed`, and `dismissed`.
- History repair support helper marks only `PromptID.organizeCards` as active retry-supported for this slice.

Also run existing tests:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

## Expected Write Set

- `Sources/Features/FeatureTabs.swift`
- `Sources/App/AppStore.swift` only for the fixed read-only candidate query if needed
- `Tests/Features/HistoryFeatureTests.swift`
- `docs/subtasks/027-history-repair-ui-progress.md`

Do not modify other files unless the build forces a narrow supporting edit. Report any extra file before changing it.

## Handoff Requirements

At HANDOFF, report:

- changed files;
- whether the AppStore read-only query was added;
- tests run and exact result;
- any candidate status or UI behavior not implemented;
- final token: `DONE`, `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, or `BLOCKED`.
