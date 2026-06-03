# Subtask 027 Progress: History Repair UI

Status: CODEX_PARTIAL_HELPERS

## Checkpoints

- START: not reached
- RED: not reached
- IMPLEMENTED: not reached
- TARGETED_VERIFIED: not reached
- HANDOFF: not reached

## Worker Notes

Claude Code must update this file at each checkpoint using exactly:

- `START`
- `RED`
- `IMPLEMENTED`
- `TARGETED_VERIFIED`
- `HANDOFF`

At HANDOFF, include one final status token:

- `DONE`
- `DONE_WITH_CONCERNS`
- `NEEDS_CONTEXT`
- `BLOCKED`

## Manager Constraints

- Keep the diff scoped to the expected write set in `027-history-repair-ui-prd.md`.
- Do not change migrations, prompt strategy, LLM clients, or persistence schema.
- Do not make SwiftUI import GRDB.
- Do not call LLMClient from SwiftUI.
- Do not fabricate candidate cards or fake history.

## Event Log

- 2026-06-03 Codex manager added and verified local helper coverage only:
  - `HistoryRepairCardPreview.decode(from:)`
  - `HistoricalRetryCandidateStatus.historyRepairTitle`
  - `HistoryRepairPromptSupport.canStartHistoricalRetry(promptId:)`
- This was done to recover the current worktree from RED test compile failures and does not complete the Subtask 027 History repair UI.
- Verified helper tests as part of:
  - `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test`
- 2026-06-03 Codex manager refreshed the Claude prompt for a second delegation attempt:
  - Worker should preserve existing helpers.
  - Remaining target is History UI integration plus the fixed AppStore read-only candidate query if needed.
  - No schema, prompt, LLM, migration, or persistence changes are allowed.
