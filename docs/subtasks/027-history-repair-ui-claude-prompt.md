# Claude Code Prompt: Subtask 027 History Repair UI

You are Claude Code working as a delegated implementation worker for Codex.

Codex remains the manager and final verifier. Do not expand scope.

## Required Reading

Read these files first:

- `docs/subtasks/027-history-repair-ui-prd.md`
- `docs/subtasks/027-history-repair-ui-progress.md`
- `docs/subtasks/026-historical-ai-retry-candidate-review-prd.md`
- `docs/mvp-current-goal.md`
- `Sources/Features/FeatureTabs.swift`
- `Sources/App/AppStore.swift`
- `Tests/Features/HistoryFeatureTests.swift`

## Skill / Workflow Requirements

- Use TDD for behavior changes.
- Keep the diff scoped.
- Update `docs/subtasks/027-history-repair-ui-progress.md` at these checkpoints:
  - `START`
  - `RED`
  - `IMPLEMENTED`
  - `TARGETED_VERIFIED`
  - `HANDOFF`
- Do not commit unless explicitly instructed by Codex.

## Task

Implement the fixed-contract History repair UI described in `docs/subtasks/027-history-repair-ui-prd.md`.

Allowed changes:

- `Sources/Features/FeatureTabs.swift`
- `Sources/App/AppStore.swift` only for a read-only candidate query:
  - `historicalRetryCandidates(for dailyEntryId: UUID) async -> [HistoricalRetryCandidate]`
- `Tests/Features/HistoryFeatureTests.swift`
- `docs/subtasks/027-history-repair-ui-progress.md`

Do not edit migrations, prompt specs, LLM clients, or data schema.

## Implementation Notes

- Current History uses local state `repairablePromptRuns` and `isLoadingRepairablePromptRuns`.
- Add local state for `HistoricalRetryCandidate` rows if needed.
- Load repairable prompt runs and candidates together whenever the visible record changes.
- For unresolved runs:
  - enable retry action only for `PromptID.organizeCards`;
  - unsupported prompts remain visible but action-disabled.
- For candidate payload preview:
  - decode `candidatePayloadJSON` locally into small view-model structs;
  - invalid JSON should produce no preview cards and no crash.
- Candidate cards are review objects, not confirmed facts.
- Use existing `DS` design tokens and History surface patterns.
- Preserve dark-mode readability.

## Required Tests

Add tests where practical for extracted helpers:

- candidate JSON decoding returns preview rows;
- invalid JSON returns empty preview rows;
- status title mapping covers candidate ready / blocked / failed / dismissed;
- support helper only enables `organizeCards`.

Then run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

## Handoff

At the end, update the progress file with HANDOFF and include:

- final status token;
- changed files;
- tests run and exact result;
- implementation summary;
- any concerns or incomplete items.
