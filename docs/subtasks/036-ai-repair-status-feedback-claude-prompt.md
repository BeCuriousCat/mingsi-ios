# Claude Prompt: Subtask 036 AI Repair Status Feedback Polish

You are the bounded implementation worker for Codex.

Invoke and follow the Claude skill `codex-delegated-worker` if available.

## Read First

1. `docs/subtasks/036-ai-repair-status-feedback-prd.md`
2. `docs/subtasks/036-ai-repair-status-feedback-progress.md`

Immediately after reading those two files, update `docs/subtasks/036-ai-repair-status-feedback-progress.md` with `START`.

Do not inspect source code before `START`. Do not read huge Swift files end to end. After `START`, inspect only targeted source ranges with `rg` and `sed`.

Suggested targeted reads:

- `Sources/Features/FeatureTabs.swift` around:
  - `aiRepairSection`
  - `historyRepairableRunRow`
  - `historicalCandidateRow`
  - `PromptRunAuditRow`
  - `HistoricalRetryCandidateStatus.historyRepairTitle`
  - `HistoryRepairPromptSupport`
- `Tests/Features/HistoryFeatureTests.swift` around the Historical AI repair tests.

## Progress Contract

Update `docs/subtasks/036-ai-repair-status-feedback-progress.md` at exactly:

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

`START` must be the first file write after reading the PRD and progress file. If you need to inspect source first, record that plan under `START`, then inspect source.

## Hard Boundaries

Allowed files:

- `Sources/Features/FeatureTabs.swift`
- `Tests/Features/HistoryFeatureTests.swift`
- `docs/subtasks/036-ai-repair-status-feedback-progress.md`

Forbidden:

- `Sources/App/AppStore.swift`
- Persistence migrations.
- `Sources/Services/PersistenceCore.swift`
- Prompt text/provider/parser files.
- LLM clients.
- Keychain code.
- Historical retry behavior changes.
- Project/Growth domain code.
- Broad Settings or History redesign.

## Required Implementation

Implement exactly the PRD:

- Add pure display helper(s) for repair/audit status copy.
- History repair section:
  - add a compact summary of unresolved/candidate/completed/problem counts when repair content exists;
  - add a short status/next-step line to unresolved failed run rows;
  - add a short status/next-step line to every historical retry candidate row.
- Settings PromptRun audit rows:
  - add one compact outcome line for success, repairable historical failure, and audit-only failure.
- Keep current grouping and expand/collapse behavior.
- Keep existing actions and retry semantics unchanged.
- Use existing `DS` tokens and small, calm copy.

## TDD Requirement

Before production code, add focused tests in `Tests/Features/HistoryFeatureTests.swift` for the new helper behavior:

- `HistoricalRetryCandidateStatus` exposes non-empty detail copy for every status.
- PromptRun audit outcome distinguishes:
  - successful run;
  - failed `organizeCards` run with source ids as repairable from History;
  - failed unsupported prompt as audit-only.
- If you add a summary helper, test mixed count output.

Run the focused tests and record the failing result in `RED`.

If existing helper behavior makes the new tests pass before UI changes, record that in `RED` and explain why; otherwise expect RED to fail before implementation.

## Required Verification

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
git diff --check
```

## Final Handoff

Do not commit.

At `HANDOFF`, summarize:

- files changed;
- tests run and result;
- behavior implemented;
- any concerns or follow-up suggestions.
