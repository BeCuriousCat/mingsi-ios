# Subtask 065 PRD: Today Completion And History Archive Walkthrough

Date: 2026-06-06

## Goal

Use the Debug-only Today stage seed from Subtask 064 to continue rendered iPhone 17 verification from `ExtractPrinciple` into `SessionComplete`, then inspect whether History can show the resulting evidence archive.

This is a verification slice. Source changes are not planned.

## Scope

Allowed files:

- `docs/subtasks/065-today-completion-history-archive-walkthrough-prd.md`
- `docs/subtasks/065-today-completion-history-archive-walkthrough-progress.md`
- `docs/subtasks/screenshots/065-today-completion-history-archive-walkthrough/*.png`
- Process docs after acceptance

Do not modify:

- Swift source or tests unless this verification exposes a narrow follow-up that gets its own PRD.
- Persistence schema or migrations
- PromptProvider, prompt text, parser, LLM clients, Keychain
- History, Projects, Growth, Settings, or Today product semantics

## Acceptance Criteria

- Launch the Debug app on iPhone 17 simulator using `MINGSI_VISUAL_QA_TODAY_STAGE=extract_principle`.
- Capture rendered `ExtractPrinciple` before action.
- Drive the visible `保存原则` action if host Simulator automation can do so reliably.
- Capture rendered `SessionComplete` if reached.
- Navigate to History and capture whether the archive shows raw input and downstream evidence.
- If History evidence is missing or incomplete, record the exact gap and choose the next implementation slice.
- `git diff --check` passes before acceptance.

## Delegation Decision

Claude Code is not delegated.

Reason:

- This is manager-owned simulator/product verification.
- The output is screenshot evidence and acceptance judgment, not a coding task.
