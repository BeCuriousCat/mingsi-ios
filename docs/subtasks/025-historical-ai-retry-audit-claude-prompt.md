You are a bounded read-only audit worker for Codex. Codex owns architecture, implementation decisions, and final review.

Invoke and follow the Claude skill `codex-delegated-worker` if it is available.

## Workspace

`/Users/chenzewei/Documents/codex/2026-05-30/image-2`

## Read Before Writing

- `docs/subtasks/025-historical-ai-retry-audit-prd.md`
- `docs/subtasks/025-historical-ai-retry-audit-progress.md`
- `docs/mvp-current-goal.md`
- `docs/mvp-stage-progress.md`
- `docs/implementation-gap-audit.md`
- `docs/prd.md`
- `docs/ux-flow.md`
- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Sources/App/AppRootView.swift`
- `Sources/Features/Today/TodayView.swift`
- `Sources/Services/PersistenceCore.swift`
- `Sources/Services/CoreProtocols.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Tests/Services/PersistenceCoreTests.swift`

## Hard Constraints

- This is read-only audit plus documentation.
- Do not edit Swift source files, tests, project files, assets, or product docs.
- Allowed write files only:
  - `docs/subtasks/025-historical-ai-retry-audit-progress.md`
  - `docs/subtasks/025-historical-ai-retry-audit-findings.md`
- Do not commit.
- Do not run destructive git commands.
- Update the progress file at these checkpoints:
  - `START`
  - `RED`
  - `IMPLEMENTED`
  - `TARGETED_VERIFIED`
  - `HANDOFF`
- For an audit, use RED to record the current missing behavior or existing failing gap. If no test is run, write "not run - read-only audit" and describe the product gap.
- If blocked, write the blocker in `HANDOFF` with status `BLOCKED`.
- If more context is required, use status `NEEDS_CONTEXT`.

## Audit Requirements

Answer the PRD questions with concrete repo evidence:

1. Current-day AI retry paths.
2. Historical PromptRun failure discovery paths.
3. History UI currently shown for repairable old records.
4. Why cross-day direct retry is blocked or unsafe.
5. Repairable Prompt IDs and guards.
6. Data available to reconstruct a historical retry request.
7. Data missing for a safe historical retry request.
8. Correct output model for historical retry success: overwrite, candidate draft, or reviewable proposal.
9. Safest next bounded implementation slice.
10. Acceptance tests for that next slice.

## Required Output

Create `docs/subtasks/025-historical-ai-retry-audit-findings.md` with:

- Summary.
- Current implementation map with file/function/test references.
- Gap list ordered by severity.
- Recommended next bounded implementation slice.
- Proposed tests for that slice.
- Risks and non-goals.
- Final recommendation: delegate implementation, Codex-owned implementation, or document/product decision first.

## Required Verification

Run:

```bash
git diff --check -- docs/subtasks/025-historical-ai-retry-audit-progress.md docs/subtasks/025-historical-ai-retry-audit-findings.md
```

Do not claim success unless you ran and read the command output.

## Final Response Format

End with exactly one status token:

- `DONE`
- `DONE_WITH_CONCERNS`
- `NEEDS_CONTEXT`
- `BLOCKED`

Also summarize:

- files changed
- verification run and result
- any concerns
