# Subtask 063 PRD: Today Rendered Post-Card Walkthrough

Date: 2026-06-06

## Goal

Use the Debug-only Today seed path from Subtask 062 to continue real iPhone 17 rendered walkthrough evidence after `思考卡片`.

The slice should verify how far the rendered app can proceed through:

```text
ReviewCards -> SelectLens -> AnswerQuestions -> ReviewQuests -> ExtractPrinciple
```

If the rendered flow cannot be driven reliably through coordinate automation, record the exact blocker and make the next implementation slice explicit.

## Scope

Allowed files:

- `docs/subtasks/063-today-rendered-post-card-walkthrough-prd.md`
- `docs/subtasks/063-today-rendered-post-card-walkthrough-progress.md`
- `docs/subtasks/screenshots/063-today-rendered-post-card-walkthrough/*.png`
- Process docs after acceptance

Source changes are not planned for this verification slice.

Do not modify:

- Persistence schema or migrations
- PromptProvider, prompt text, parser, LLM clients, Keychain
- AppStore product semantics
- Today UI behavior
- History, Projects, Growth, or Settings behavior

## Acceptance Criteria

- Build or install evidence identifies the Debug app under test.
- Seeded Today input reaches `思考卡片` using the Subtask 062 seed path.
- Screenshot evidence records each successfully reached rendered state after ReviewCards.
- If the flow blocks, progress records the exact rendered state, attempted action, and why it is not safe to claim full walkthrough completion.
- `git diff --check` passes before acceptance.

## Delegation Decision

Claude Code is not delegated for this slice.

Reason:

- This is a manager-owned simulator verification and product acceptance slice.
- The work is screenshot orchestration and final judgment, not bulk coding.
- If verification reveals a narrow source fix, that follow-up can be delegated or implemented separately after a new PRD.
